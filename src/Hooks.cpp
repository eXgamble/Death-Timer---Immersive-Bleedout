#include "Hooks.h"

// Keep a named, friendly, non-essential, non-protected NPC alive when someone other than the
// player lands a fatal hit: HandleHealthDamage lifts their health back above 0 and marks them,
// and KillImpl skips the death the engine had already committed to for a marked actor.
// KillImpl also serves scripted kills (quests, this mod's Death Timer), which are never marked.

namespace
{
	RE::BGSKeyword* actorTypeNPC = nullptr;

	// The NPCs this plugin is meant to rescue. Everyone else keeps vanilla (or the Papyrus
	// side's) behaviour: essential/protected NPCs are already knocked out by the mod, and the
	// player's own blows always kill.
	bool IsRescueCandidate(RE::Actor* a_actor, RE::Actor* a_attacker)
	{
		auto player = RE::PlayerCharacter::GetSingleton();
		if (!a_actor || !player || a_actor == player || a_attacker == player) {
			return false;
		}
		if (a_actor->IsDead() || a_actor->IsEssential() || a_actor->IsProtected()) {
			return false;
		}
		if (a_actor->IsSummoned() || a_actor->IsCommandedActor()) {
			return false;
		}
		auto base = a_actor->GetActorBase();
		if (!base || !base->IsUnique() || base->IsGhost()) {
			return false;
		}
		if (!actorTypeNPC || !a_actor->HasKeyword(actorTypeNPC)) {
			return false;
		}
		return !a_actor->IsHostileToActor(player);
	}

	// Actors HandleHealthDamage just saved. The engine commits to a death when the fatal damage
	// lands and carries it out in KillImpl a frame later, even with health back above 0, so
	// KillImpl has to skip the death for these. Scripted kills never follow a save, so they
	// are never in here.
	class JustSaved
	{
	public:
		static void Add(RE::FormID a_id)
		{
			std::scoped_lock lock(mutex);
			saved[a_id] = Clock::now();
		}

		// true (and forgets the entry) if a_id was saved within the last half second
		static bool Take(RE::FormID a_id)
		{
			std::scoped_lock lock(mutex);
			auto it = saved.find(a_id);
			if (it == saved.end()) {
				return false;
			}
			const bool recent = Clock::now() - it->second < 500ms;
			saved.erase(it);
			return recent;
		}

	private:
		using Clock = std::chrono::steady_clock;
		static inline std::mutex mutex;
		static inline std::unordered_map<RE::FormID, Clock::time_point> saved;
	};

	// Hand the actor to the Papyrus side (ANDR_KO_QuestScript.OnNPCDowned), which knocks them out
	// onto the Death Timer. Sent from the task queue: hooks can run off the main thread, and the
	// handle guards against the actor being unloaded in between.
	void SendDowned(RE::Actor* a_actor)
	{
		SKSE::GetTaskInterface()->AddTask([handle = a_actor->GetHandle()]() {
			auto ref = handle.get();
			if (!ref) {
				return;
			}
			SKSE::ModCallbackEvent event{ "DeathTimer_Downed"sv, ""sv, 0.0f, ref.get() };
			SKSE::GetModCallbackEventSource()->SendEvent(&event);
		});
	}

	// The health loss is already applied when this runs, but the death isn't: the engine kills
	// the actor a moment later (KillImpl) once it sees health at or below 0. Lifting a rescue
	// candidate's health back above 0 here keeps that from happening. Only real damage comes
	// through here, so scripted Kill() calls (quests, this mod's own Death Timer) are untouched.
	struct HandleHealthDamage
	{
		static void thunk(RE::Actor* a_this, RE::Actor* a_attacker, float a_damage)
		{
			const bool candidate = IsRescueCandidate(a_this, a_attacker);

			func(a_this, a_attacker, a_damage);

			if (!candidate || a_this->IsDead()) {
				return;
			}
			auto avOwner = a_this->AsActorValueOwner();
			const float health = avOwner ? avOwner->GetActorValue(RE::ActorValue::kHealth) : 1.0f;
			if (health > 0.0f) {
				return;
			}

			// Keep them alive on a sliver of health; KillImpl then skips the death and hands them
			// to the Death Timer. Hits while they're down land here too, so enemies can't finish them.
			avOwner->RestoreActorValue(RE::ActorValue::kHealth, 1.0f - health);
			JustSaved::Add(a_this->GetFormID());
		}
		static inline REL::Relocation<decltype(thunk)> func;
	};

	struct KillImpl
	{
		static void thunk(RE::Actor* a_this, RE::Actor* a_attacker, float a_damage, bool a_sendEvent, bool a_ragdollInstant)
		{
			// The death that follows a save: skip it. Everything else dies as normal, and a kill by
			// the player is never blocked (the mark is still consumed).
			const bool justSaved = a_this && JustSaved::Take(a_this->GetFormID());
			if (justSaved && a_attacker != RE::PlayerCharacter::GetSingleton()) {
				SendDowned(a_this);
				return;
			}
			func(a_this, a_attacker, a_damage, a_sendEvent, a_ragdollInstant);
		}
		static inline REL::Relocation<decltype(thunk)> func;
	};
}

namespace Hooks
{
	void Install()
	{
		static std::once_flag once;
		std::call_once(once, []() {
			REL::Relocation<std::uintptr_t> vtbl{ RE::VTABLE_Character[0] };
			HandleHealthDamage::func = REL::Relocation<decltype(HandleHealthDamage::thunk)>{ vtbl.write_vfunc(0x104, HandleHealthDamage::thunk) };
			KillImpl::func = REL::Relocation<decltype(KillImpl::thunk)>{ vtbl.write_vfunc(0x10E, KillImpl::thunk) };
			logger::info("Hooks installed: Character::HandleHealthDamage (0x104), Character::KillImpl (0x10E)");
		});
	}

	void OnDataLoaded()
	{
		actorTypeNPC = RE::TESForm::LookupByID<RE::BGSKeyword>(0x13794);  // ActorTypeNPC, Skyrim.esm
		if (!actorTypeNPC) {
			logger::error("ActorTypeNPC keyword (Skyrim.esm 013794) not found, no NPC will qualify");
		}
	}
}
