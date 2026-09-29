#pragma once

namespace Hooks
{
	// Vtable hooks on Character (every NPC). Engine code only, safe to install during SKSEPlugin_Load.
	void Install();

	// Form lookups, needs kDataLoaded.
	void OnDataLoaded();
}
