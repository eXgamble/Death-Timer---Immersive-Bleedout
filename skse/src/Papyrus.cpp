#include "Papyrus.h"

namespace
{
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
}

namespace Papyrus
{
	bool Register(RE::BSScript::IVirtualMachine* a_vm)
	{
		a_vm->RegisterFunction("SetDownedProtection", "DeathTimer", SetDownedProtection);
		logger::info("Papyrus functions registered");
		return true;
	}
}
