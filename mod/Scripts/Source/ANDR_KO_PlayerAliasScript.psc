Scriptname ANDR_KO_PlayerAliasScript extends ReferenceAlias

Perk Property ANDR_KO_TextReplacementPerk Auto

Event OnInit()
	(Game.GetPlayer()).AddPerk(ANDR_KO_TextReplacementPerk)
EndEvent

Event OnPlayerLoadGame()
	(GetOwningQuest() As ANDR_KO_QuestScript).RegisterForDownedEvent()
	; The MCM quest has no player alias of its own, so its OnGameReload never fires: sync the menu
	; settings from here instead, on every load
	ANDR_KO_Quest_MCMScript MCMQuest = Game.GetFormFromFile(0xF89, "Death Timer - Immersive Bleedout.esp") As ANDR_KO_Quest_MCMScript
	If MCMQuest
		MCMQuest.LoadSettings()
	EndIf
EndEvent
