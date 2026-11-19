#pragma once

// A glowing wisp over every downed named NPC, its colour showing how bad it is, and a mod event for each change
// so another mod (eXrim's compass) can show them too. Papyrus (ANDR_KO_RecoverAliasScript) says when someone is
// knocked out and when a dying NPC's timer reaches the next step; the plugin itself notices when they're no
// longer down (the knockout token leaves their inventory, or they die).
namespace Wisps
{
	// What a downed NPC's wisp shows. The numbers are what Papyrus passes and what the mod event carries.
	enum class State : std::int32_t
	{
		kGone = 0,        // up again, or dead: no wisp
		kKnockedOut = 1,  // pale blue: gets up on their own after some game hours
		kDying1 = 2,      // yellow: the Death Timer is running
		kDying2 = 3,      // orange
		kDying3 = 4,      // red: the last 20% of the time
	};

	// Forms and event sinks, needs kDataLoaded.
	void OnDataLoaded();

	// Co-save callbacks (registered in plugin.cpp).
	void Save(SKSE::SerializationInterface* a_intfc);
	void Load(SKSE::SerializationInterface* a_intfc);
	void Revert(SKSE::SerializationInterface* a_intfc);

	// kPostLoadGame: remove the wisps the save held and bring back the ones still needed.
	void OnGameLoaded();

	// From Papyrus (DeathTimer.SetDownedState). Safe from any thread: the work runs as an SKSE task.
	void SetState(RE::Actor* a_actor, std::int32_t a_state);
}
