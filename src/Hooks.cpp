#include "Hooks.h"

// Keep a named, friendly, non-essential, non-protected NPC alive when someone other than the
// player lands a fatal hit (HandleHealthDamage). KillImpl is only watched: it also serves
// scripted kills, so it must never block a death.

namespace
{
	RE::BGSKeyword* actorTypeNPC = nullptr;

	float GetHealth(RE::Actor* a_actor)
	{
		auto avOwner = a_actor->AsActorValueOwner();
		return avOwner ? avOwner->GetActorValue(RE::ActorValue::kHealth) : 0.0f;
	}

	const char* NameOf(RE::Actor* a_actor)
	{
		if (!a_actor) {
			return "<none>";
		}
		auto name = a_actor->GetDisplayFullName();
		return name && *name ? name : "<unnamed>";
	}

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

	// Hooks can run off the main thread; UI work goes through the task queue.
	void Notify(std::string a_message)
	{
		SKSE::GetTaskInterface()->AddTask([message = std::move(a_message)]() {
			RE::SendHUDMessage::ShowHUDMessage(message.c_str());
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

			// Step 2: keep them alive on a sliver of health. They are not knocked down yet (step 3).
			avOwner->RestoreActorValue(RE::ActorValue::kHealth, 1.0f - health);
			logger::info("Saved {} from death: hit by {} for {:.1f}, health {:.1f} -> {:.1f}",
				NameOf(a_this), NameOf(a_attacker), a_damage, health, GetHealth(a_this));
			Notify(std::format("[Death Timer] {} was saved from death.", NameOf(a_this)));
		}
		static inline REL::Relocation<decltype(thunk)> func;
	};

	struct KillImpl
	{
		static void thunk(RE::Actor* a_this, RE::Actor* a_attacker, float a_damage, bool a_sendEvent, bool a_ragdollInstant)
		{
			if (IsRescueCandidate(a_this, a_attacker)) {
				logger::info("KillImpl: {} killed by {} (damage {:.1f}, health {:.1f}, sendEvent={}, ragdollInstant={})",
					NameOf(a_this), NameOf(a_attacker), a_damage, GetHealth(a_this), a_sendEvent, a_ragdollInstant);
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
		if (actorTypeNPC) {
			logger::info("ActorTypeNPC keyword found");
		} else {
			logger::error("ActorTypeNPC keyword (Skyrim.esm 013794) not found, no NPC will qualify");
		}
	}
}
