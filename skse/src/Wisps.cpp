#include "Wisps.h"

#include "Settings.h"

#include <functional>
#include <thread>
#include <unordered_set>

// How it works:
// - Papyrus calls SetState when a named NPC is knocked out (blue) or dying (yellow, then orange, then red as
//   the Death Timer runs; Papyrus owns that timer, so the colours follow the real one, saves included).
// - The wisps are placed objects (MSTT records 000FB9-FBC, no collision, glow only) set above the body once
//   the ragdoll has settled: the body's position is sampled a few times and the wisp goes up when it stops
//   moving. A dying NPC gets all three colours at once and only the current one is enabled, so a colour step
//   works even while the NPC's cell isn't loaded.
// - The plugin itself sees the end: the knockout token leaving their inventory (rescued, recovered, or the
//   kill code removing it first) or their death. Then the wisps are deleted.
// - Every change sends the mod event "DeathTimer_DownedState" (sender = the NPC, strArg = state name, numArg =
//   state number), re-sent after a load for everyone still down. Nobody has to listen.
// - Placed wisps are listed in the co-save and deleted after a load, then placed again for whoever is still
//   down, so an old save never keeps a stray wisp.
// No polling: a downed NPC costs a few samples while the body settles, then nothing until the next step.

namespace
{
	using Wisps::State;

	constexpr auto PLUGIN_NAME = "Death Timer - Immersive Bleedout.esp"sv;
	constexpr RE::FormID TOKEN_ID = 0x807;                                        // ANDR_KO_Token
	constexpr std::array<RE::FormID, 4> WISP_IDS{ 0xFB9, 0xFBA, 0xFBB, 0xFBC };  // blue, yellow, orange, red
	constexpr float HEIGHT_ABOVE_BODY = 40.0f;   // units above the chest of the lying body
	constexpr float SETTLED_DISTANCE = 4.0f;     // the body moved less than this between two samples
	constexpr auto  SETTLE_INTERVAL = 400ms;
	constexpr int   SETTLE_MAX_SAMPLES = 12;     // ~5 s, then the wisp goes up wherever the body is

	std::array<RE::TESBoundObject*, 4> wispForms{};
	RE::FormID tokenID = 0;

	struct Entry
	{
		RE::ActorHandle actor;
		State           state{ State::kGone };
		std::array<RE::ObjectRefHandle, 4> wisps{};  // by colour index, empty where not placed
		bool            settling{ false };
	};

	// Touched only from SKSE tasks and the co-save callbacks, both on the main thread.
	std::unordered_map<RE::FormID, Entry> entries;

	// Which actors are tracked, for the event sinks' quick filter (they can run on other threads).
	std::mutex                     trackedLock;
	std::unordered_set<RE::FormID> tracked;

	// From the save being loaded: wisps to delete, and who was down in which state.
	std::vector<RE::FormID>                               leftoverWisps;
	std::vector<std::pair<RE::FormID, State>>             savedStates;

	// Bumped on every load and new game, so a settle sample queued before it does nothing after it.
	std::atomic<std::uint32_t> generation{ 0 };

	void Track(RE::FormID a_id, bool a_on)
	{
		std::scoped_lock lock(trackedLock);
		if (a_on) {
			tracked.insert(a_id);
		} else {
			tracked.erase(a_id);
		}
	}

	bool IsTracked(RE::FormID a_id)
	{
		std::scoped_lock lock(trackedLock);
		return tracked.contains(a_id);
	}

	int ColourIndex(State a_state)
	{
		return static_cast<int>(a_state) - 1;  // blue 0, yellow 1, orange 2, red 3
	}

	std::string_view StateName(State a_state)
	{
		switch (a_state) {
		case State::kKnockedOut:
			return "knocked_out"sv;
		case State::kDying1:
			return "dying_1"sv;
		case State::kDying2:
			return "dying_2"sv;
		case State::kDying3:
			return "dying_3"sv;
		default:
			return "gone"sv;
		}
	}

	void SendEvent(RE::Actor* a_actor, State a_state)
	{
		SKSE::ModCallbackEvent event{ "DeathTimer_DownedState"sv, StateName(a_state), static_cast<float>(a_state), a_actor };
		SKSE::GetModCallbackEventSource()->SendEvent(&event);
	}

	// Run a_task as an SKSE task after a_delay. Bounded one-shot waits only (a settling body), never a loop.
	void Later(std::chrono::milliseconds a_delay, std::function<void()> a_task)
	{
		std::thread([a_delay, task = std::move(a_task)]() {  // skse-lint: ok one-shot bounded delay, ends after one sleep
			std::this_thread::sleep_for(a_delay);           // skse-lint: ok see above
			SKSE::GetTaskInterface()->AddTask(task);
		}).detach();
	}

	bool HasToken(RE::Actor* a_actor)
	{
		if (!tokenID) {
			return false;
		}
		const auto counts = a_actor->GetInventoryCounts([](RE::TESBoundObject& a_obj) { return a_obj.GetFormID() == tokenID; });
		for (const auto& [obj, count] : counts) {
			if (count > 0) {
				return true;
			}
		}
		return false;
	}

	// Chest of the body (it lies where the ragdoll left it, not where the reference stands), else the reference.
	RE::NiPoint3 BodyPosition(RE::Actor* a_actor)
	{
		static const RE::BSFixedString spine{ "NPC Spine2 [Spn2]" };
		if (auto root = a_actor->Get3D(false)) {
			if (auto node = root->GetObjectByName(spine)) {
				return node->world.translate;
			}
			return root->world.translate;
		}
		return a_actor->GetPosition();
	}

	void DeleteRef(RE::ObjectRefHandle& a_handle)
	{
		if (const auto ref = a_handle.get(); ref && !ref->IsDeleted()) {
			logger::info("Wisp: deleting {:08X}", ref->GetFormID());
			ref->Disable();
			ref->SetDelete(true);
		}
		a_handle.reset();
	}

	// Enable the current colour, disable the others. Places a missing colour if the body is there to place it at.
	void ShowColour(Entry& a_entry, RE::Actor* a_actor)
	{
		const int current = ColourIndex(a_entry.state);
		for (int i = 0; i < 4; ++i) {
			const auto ref = a_entry.wisps[i].get();
			if (!ref) {
				continue;
			}
			if (i == current) {
				if (ref->IsDisabled()) {
					ref->Enable(false);
				}
				if (a_actor->Is3DLoaded()) {  // the body may have been pushed since
					auto pos = BodyPosition(a_actor);
					pos.z += HEIGHT_ABOVE_BODY;
					ref->SetPosition(pos);
				}
			} else if (!ref->IsDisabled()) {
				ref->Disable();
			}
		}
	}

	void PlaceWisps(Entry& a_entry, RE::Actor* a_actor, RE::NiPoint3 a_bodyPos)
	{
		if (!Settings::DownedWisp()) {
			return;
		}
		auto* cell = a_actor->GetParentCell();
		if (!cell) {
			return;
		}
		const int current = ColourIndex(a_entry.state);
		// knocked out: only blue; dying: all three steps, so later steps only switch which one shows
		const int first = a_entry.state == State::kKnockedOut ? 0 : 1;
		const int last = a_entry.state == State::kKnockedOut ? 0 : 3;
		auto pos = a_bodyPos;
		pos.z += HEIGHT_ABOVE_BODY;
		for (int i = 0; i < 4; ++i) {
			if ((i < first || i > last) && i != current) {
				continue;
			}
			if (a_entry.wisps[i].get() || !wispForms[i]) {
				continue;
			}
			const auto handle = RE::TESDataHandler::GetSingleton()->CreateReferenceAtLocation(wispForms[i], pos, RE::NiPoint3{},
				cell, a_actor->GetWorldspace(), nullptr, nullptr, RE::ObjectRefHandle{}, false, true);
			const auto ref = handle.get();
			if (!ref) {
				logger::warn("Wisp: couldn't place colour {} for {:08X}", i, a_actor->GetFormID());
				continue;
			}
			if (i != current) {
				ref->Disable();
			}
			a_entry.wisps[i] = handle;
			logger::info("Wisp: colour {} is {:08X}", i, ref->GetFormID());
		}
		logger::info("Wisp: placed over {:08X} ({})", a_actor->GetFormID(), StateName(a_entry.state));
	}

	// Sample the body until it stops moving, then place. Ends by itself: placed, given up, or no longer needed.
	void Settle(RE::FormID a_id, std::uint32_t a_generation, int a_samples, RE::NiPoint3 a_last)
	{
		if (a_generation != generation) {
			return;
		}
		const auto it = entries.find(a_id);
		if (it == entries.end()) {
			return;
		}
		auto& entry = it->second;
		const auto actor = entry.actor.get();
		if (!actor || !actor->Is3DLoaded()) {
			entry.settling = false;  // placed when their 3D loads (TESObjectLoadedEvent)
			return;
		}
		const auto pos = BodyPosition(actor.get());
		const bool settled = a_samples > 0 && pos.GetDistance(a_last) < SETTLED_DISTANCE;
		if (!settled && a_samples < SETTLE_MAX_SAMPLES) {
			Later(SETTLE_INTERVAL, [a_id, a_generation, a_samples, pos]() { Settle(a_id, a_generation, a_samples + 1, pos); });
			return;
		}
		entry.settling = false;
		PlaceWisps(entry, actor.get(), pos);
	}

	void StartSettle(RE::FormID a_id, Entry& a_entry)
	{
		if (a_entry.settling || !Settings::DownedWisp()) {
			return;
		}
		a_entry.settling = true;
		Settle(a_id, generation, 0, {});
	}

	bool AllPlaced(const Entry& a_entry)
	{
		const int current = ColourIndex(a_entry.state);
		return current >= 0 && a_entry.wisps[current].get();
	}

	void Remove(RE::FormID a_id)
	{
		const auto it = entries.find(a_id);
		if (it == entries.end()) {
			return;
		}
		for (auto& wisp : it->second.wisps) {
			DeleteRef(wisp);
		}
		const auto actor = it->second.actor.get();
		entries.erase(it);
		Track(a_id, false);
		logger::info("Wisp: {:08X} no longer down", a_id);
		if (actor) {
			SendEvent(actor.get(), State::kGone);
		}
	}

	// Main thread (SKSE task): apply a new state.
	void Apply(RE::Actor* a_actor, State a_state)
	{
		const auto id = a_actor->GetFormID();
		if (a_state == State::kGone || a_actor->IsDead()) {
			Remove(id);
			return;
		}
		auto [it, added] = entries.try_emplace(id);
		auto& entry = it->second;
		const bool changed = added || entry.state != a_state;
		entry.actor = a_actor->GetHandle();
		entry.state = a_state;
		if (added) {
			Track(id, true);
		}
		if (changed) {
			logger::info("Wisp: {:08X} {}", id, StateName(a_state));
			SendEvent(a_actor, a_state);
		}
		if (!Settings::DownedWisp()) {
			return;
		}
		if (AllPlaced(entry)) {
			ShowColour(entry, a_actor);
		} else if (a_actor->Is3DLoaded()) {
			if (std::ranges::any_of(entry.wisps, [](const auto& h) { return static_cast<bool>(h.get()); })) {
				PlaceWisps(entry, a_actor, BodyPosition(a_actor));  // already lying still: a missing colour, add it
				ShowColour(entry, a_actor);
			} else {
				StartSettle(id, entry);
			}
		}
	}

	class EventSink final :
		public RE::BSTEventSink<RE::TESContainerChangedEvent>,
		public RE::BSTEventSink<RE::TESDeathEvent>,
		public RE::BSTEventSink<RE::TESObjectLoadedEvent>
	{
	public:
		static EventSink* Get()
		{
			static EventSink singleton;
			return &singleton;
		}

		// The token left a tracked NPC: rescued, recovered, or about to be killed.
		RE::BSEventNotifyControl ProcessEvent(const RE::TESContainerChangedEvent* a_event, RE::BSTEventSource<RE::TESContainerChangedEvent>*) override
		{
			if (a_event && a_event->baseObj == tokenID && tokenID && IsTracked(a_event->oldContainer)) {
				const auto id = a_event->oldContainer;
				SKSE::GetTaskInterface()->AddTask([id]() {
					const auto actor = RE::TESForm::LookupByID<RE::Actor>(id);
					if (!actor || actor->IsDead() || !HasToken(actor)) {  // a second token arriving is not an end
						Remove(id);
					}
				});
			}
			return RE::BSEventNotifyControl::kContinue;
		}

		RE::BSEventNotifyControl ProcessEvent(const RE::TESDeathEvent* a_event, RE::BSTEventSource<RE::TESDeathEvent>*) override
		{
			if (a_event && a_event->actorDying && IsTracked(a_event->actorDying->GetFormID())) {
				const auto id = a_event->actorDying->GetFormID();
				SKSE::GetTaskInterface()->AddTask([id]() { Remove(id); });
			}
			return RE::BSEventNotifyControl::kContinue;
		}

		// A tracked NPC's body came into view (walked back into their cell, or a load): place a missing wisp.
		RE::BSEventNotifyControl ProcessEvent(const RE::TESObjectLoadedEvent* a_event, RE::BSTEventSource<RE::TESObjectLoadedEvent>*) override
		{
			if (a_event && a_event->loaded && IsTracked(a_event->formID)) {
				const auto id = a_event->formID;
				SKSE::GetTaskInterface()->AddTask([id]() {
					const auto it = entries.find(id);
					if (it != entries.end() && !AllPlaced(it->second)) {
						StartSettle(id, it->second);
					}
				});
			}
			return RE::BSEventNotifyControl::kContinue;
		}
	};
}

namespace Wisps
{
	void OnDataLoaded()
	{
		auto* dataHandler = RE::TESDataHandler::GetSingleton();
		if (const auto token = dataHandler->LookupForm(TOKEN_ID, PLUGIN_NAME)) {
			tokenID = token->GetFormID();
		} else {
			logger::error("ANDR_KO_Token ({:06X}) not found in {}, wisps won't notice a rescue", TOKEN_ID, PLUGIN_NAME);
		}
		for (std::size_t i = 0; i < WISP_IDS.size(); ++i) {
			// a moveable static's TESForm part isn't at its start, so cast through its own type, then up
			if (const auto form = dataHandler->LookupForm(WISP_IDS[i], PLUGIN_NAME)) {
				if (const auto movable = form->As<RE::BGSMovableStatic>()) {
					wispForms[i] = movable;
				}
			}
			if (!wispForms[i]) {
				logger::error("Wisp record {:06X} not found in {}, that colour won't show", WISP_IDS[i], PLUGIN_NAME);
			}
		}
		auto* events = RE::ScriptEventSourceHolder::GetSingleton();
		events->AddEventSink<RE::TESContainerChangedEvent>(EventSink::Get());
		events->AddEventSink<RE::TESDeathEvent>(EventSink::Get());
		events->AddEventSink<RE::TESObjectLoadedEvent>(EventSink::Get());
	}

	void SetState(RE::Actor* a_actor, std::int32_t a_state)
	{
		if (!a_actor || a_state < 0 || a_state > static_cast<std::int32_t>(State::kDying3)) {
			return;
		}
		const auto base = a_actor->GetActorBase();
		if (!base || !base->IsUnique()) {  // named NPCs only, even with bRescueGenericNPCs on
			return;
		}
		SKSE::GetTaskInterface()->AddTask([handle = a_actor->GetHandle(), state = static_cast<State>(a_state)]() {
			if (const auto actor = handle.get()) {
				Apply(actor.get(), state);
			}
		});
	}

	void Save(SKSE::SerializationInterface* a_intfc)
	{
		if (!a_intfc->OpenRecord('WISP', 1)) {
			logger::error("Couldn't write the wisps to the co-save");
			return;
		}
		const auto count = static_cast<std::uint32_t>(entries.size());
		a_intfc->WriteRecordData(count);
		for (const auto& [id, entry] : entries) {
			a_intfc->WriteRecordData(id);
			a_intfc->WriteRecordData(static_cast<std::int32_t>(entry.state));
			for (const auto& wisp : entry.wisps) {
				const auto ref = wisp.get();
				const RE::FormID wispID = ref && !ref->IsDeleted() ? ref->GetFormID() : 0;
				a_intfc->WriteRecordData(wispID);
			}
		}
	}

	void Load(SKSE::SerializationInterface* a_intfc)
	{
		std::uint32_t type, version, length;
		while (a_intfc->GetNextRecordInfo(type, version, length)) {
			if (type != 'WISP' || version != 1) {
				continue;
			}
			std::uint32_t count = 0;
			a_intfc->ReadRecordData(count);
			for (std::uint32_t i = 0; i < count; ++i) {
				RE::FormID    id = 0, resolved = 0;
				std::int32_t  state = 0;
				a_intfc->ReadRecordData(id);
				a_intfc->ReadRecordData(state);
				if (a_intfc->ResolveFormID(id, resolved)) {
					savedStates.emplace_back(resolved, static_cast<State>(state));
				}
				for (int c = 0; c < 4; ++c) {
					RE::FormID wispID = 0, wispResolved = 0;
					a_intfc->ReadRecordData(wispID);
					if (wispID && a_intfc->ResolveFormID(wispID, wispResolved)) {
						leftoverWisps.push_back(wispResolved);
					}
				}
			}
		}
	}

	void Revert(SKSE::SerializationInterface*)
	{
		++generation;
		entries.clear();
		leftoverWisps.clear();
		savedStates.clear();
		std::scoped_lock lock(trackedLock);
		tracked.clear();
	}

	void OnGameLoaded()
	{
		SKSE::GetTaskInterface()->AddTask([]() {
			for (const auto id : std::exchange(leftoverWisps, {})) {
				const auto ref = RE::TESForm::LookupByID<RE::TESObjectREFR>(id);
				logger::info("Wisp: removing {:08X} kept in the save ({})", id, ref ? "found" : "not found");
				if (ref && !ref->IsDeleted()) {
					ref->Disable();
					ref->SetDelete(true);
				}
			}
			for (const auto& [id, state] : std::exchange(savedStates, {})) {
				const auto actor = RE::TESForm::LookupByID<RE::Actor>(id);
				if (!actor || actor->IsDead() || !HasToken(actor) || state == State::kGone) {
					continue;
				}
				Apply(actor, state);  // re-sends the event, and places the wisp now or when the body loads
			}
		});
	}
}
