#pragma once

namespace Settings
{
	// Form lookups (the plugin's globals), needs kDataLoaded.
	void OnDataLoaded();

	// Read SKSE\Plugins\DeathTimer.ini and put the values into the plugin's globals. Globals are saved
	// with the game, so this runs after every load and on a new game: the ini always wins, and an edit
	// takes effect on the next load.
	void LoadAndApply();

	// Time Until Death: real-time seconds a dying NPC has (read by Papyrus, DeathTimer.psc).
	float DeathTimerSeconds();
}
