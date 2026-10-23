#include "Settings.h"

#include <SimpleIni.h>

// The mod's options, from an ini instead of a menu (no SkyUI / MCM Helper). The Papyrus side keeps
// reading its globals as before; this file only decides their values.

namespace
{
	constexpr auto INI_PATH = "Data/SKSE/Plugins/DeathTimer.ini";
	constexpr auto PLUGIN_NAME = "Death Timer - Immersive Bleedout.esp"sv;

	struct Global
	{
		RE::FormID     id;
		const char*    name;
		RE::TESGlobal* form = nullptr;
	};

	Global recoverHours{ 0x809, "ANDR_KO_GLOB_RecoverHours" };
	Global downHealthThreshold{ 0xD70, "ANDR_KO_GLOB_DownHealthTreshold" };
	Global allowNotifications{ 0xD71, "ANDR_KO_GLOB_AllowNotifications" };
	Global notOnlyTeamMates{ 0xD7A, "ANDR_KO_GLOB_NotOnlyTeamMates" };
	Global rescueGenericNPCs{ 0xFB7, "ANDR_KO_GLOB_RescueGenericNPCs" };
	Global followerDeathTimer{ 0xFB8, "ANDR_KO_GLOB_FollowerDeathTimer" };

	std::atomic<float> deathTimerSeconds{ 60.0f };  // read on the Papyrus VM's thread

	void Set(const Global& a_global, float a_value)
	{
		if (a_global.form) {
			a_global.form->value = a_value;
		}
	}
}

namespace Settings
{
	void OnDataLoaded()
	{
		const auto dataHandler = RE::TESDataHandler::GetSingleton();
		for (auto* global : { &recoverHours, &downHealthThreshold, &allowNotifications, &notOnlyTeamMates, &rescueGenericNPCs, &followerDeathTimer }) {
			global->form = dataHandler->LookupForm<RE::TESGlobal>(global->id, PLUGIN_NAME);
			if (!global->form) {
				logger::error("{} ({:06X}) not found in {}, its setting can't be applied", global->name, global->id, PLUGIN_NAME);
			}
		}
	}

	void LoadAndApply()
	{
		CSimpleIniA ini;
		ini.SetUnicode();
		if (ini.LoadFile(INI_PATH) < SI_OK) {
			logger::warn("{} not found, using defaults", INI_PATH);
		}
		const auto hours = std::max(0.0f, static_cast<float>(ini.GetDoubleValue("General", "fRecoverHours", 6.0)));
		const bool followers = ini.GetBoolValue("General", "bFollowerDeathTimer", true);
		auto       seconds = static_cast<float>(ini.GetDoubleValue("General", "fDeathTimerSeconds", 60.0));
		if (seconds < 10.0f) {
			logger::warn("fDeathTimerSeconds = {} is below 10, using 10", seconds);
			seconds = 10.0f;
		}
		const bool generic = ini.GetBoolValue("General", "bRescueGenericNPCs", false);
		const bool notifications = ini.GetBoolValue("General", "bAllowNotifications", true);

		deathTimerSeconds = seconds;
		Set(recoverHours, hours);
		Set(followerDeathTimer, followers ? 1.0f : 0.0f);
		Set(rescueGenericNPCs, generic ? 1.0f : 0.0f);
		Set(allowNotifications, notifications ? 1.0f : 0.0f);
		// No longer options, fixed (also resets saves where an old menu had changed them): non-followers are
		// always knocked out (the two-path design), and a knocked-out NPC's health may drift up to 10 before
		// it's pinned back to 0.5
		Set(notOnlyTeamMates, 1.0f);
		Set(downHealthThreshold, 10.0f);

		logger::info("Settings: recover hours {}, follower Death Timer {}, time until death {} s, rescue generic NPCs {}, notifications {}",
			hours, followers, seconds, generic, notifications);
	}

	float DeathTimerSeconds()
	{
		return deathTimerSeconds;
	}
}
