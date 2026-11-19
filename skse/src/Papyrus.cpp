#include "Papyrus.h"

#include "Settings.h"
#include "Wisps.h"

namespace
{
	// Time Until Death from DeathTimer.ini
	float GetDeathTimerSeconds(RE::StaticFunctionTag*)
	{
		return Settings::DeathTimerSeconds();
	}

	// Protected on this one NPC in the world, not on their NPC record: unnamed NPCs share a record
	// (every "Whiterun Guard"), so protecting the record would protect all of them. The engine's own
	// "can this be killed" checks read this per-actor flag. Used while an NPC downed by this plugin
	// is dying, so enemies leave them alone and only the player (or the Death Timer) can kill them.
	void SetDownedProtection(RE::StaticFunctionTag*, RE::Actor* a_actor, bool a_protected)
	{
		if (!a_actor) {
			return;
		}
		auto& flags = a_actor->GetActorRuntimeData().boolFlags;
		if (a_protected) {
			flags.set(RE::Actor::BOOL_FLAGS::kProtected);
		} else {
			flags.reset(RE::Actor::BOOL_FLAGS::kProtected);
		}
	}

	// a_target takes the potion's effects as if it drank it, without equipping it: no drinking
	// animation, so animated-potion mods don't get involved. The target's own instant caster casts
	// the potion on itself (potions are self-delivered), blamed on a_source. The caller removes the
	// potion from whoever had it. Runs as an SKSE task, where changing an NPC is safe.
	void CastPotion(RE::StaticFunctionTag*, RE::Actor* a_source, RE::AlchemyItem* a_potion, RE::Actor* a_target)
	{
		if (!a_potion || !a_target) {
			return;
		}
		const auto targetHandle = a_target->GetHandle();
		const auto sourceHandle = a_source ? a_source->GetHandle() : RE::ActorHandle{};
		SKSE::GetTaskInterface()->AddTask([targetHandle, sourceHandle, a_potion]() {
			const auto target = targetHandle.get();
			if (!target) {
				return;
			}
			auto* caster = target->GetMagicCaster(RE::MagicSystem::CastingSource::kInstant);
			if (!caster) {
				logger::warn("CastPotion: {:08X} has no instant caster", target->GetFormID());
				return;
			}
			const auto source = sourceHandle.get();
			caster->CastSpellImmediate(a_potion, false, target.get(), 1.0f, false, 0.0f,
				source ? source.get() : target.get());
		});
	}

	// A downed named NPC's state for the wisp over them and the "DeathTimer_DownedState" mod event:
	// 1 knocked out, 2-4 dying (yellow, orange, red), 0 no longer down. Unnamed NPCs are ignored.
	void SetDownedState(RE::StaticFunctionTag*, RE::Actor* a_actor, std::int32_t a_state)
	{
		Wisps::SetState(a_actor, a_state);
	}
}

namespace Papyrus
{
	bool Register(RE::BSScript::IVirtualMachine* a_vm)
	{
		a_vm->RegisterFunction("SetDownedProtection", "DeathTimer", SetDownedProtection);
		a_vm->RegisterFunction("GetDeathTimerSeconds", "DeathTimer", GetDeathTimerSeconds);
		a_vm->RegisterFunction("CastPotion", "DeathTimer", CastPotion);
		a_vm->RegisterFunction("SetDownedState", "DeathTimer", SetDownedState);
		logger::info("Papyrus functions registered");
		return true;
	}
}
