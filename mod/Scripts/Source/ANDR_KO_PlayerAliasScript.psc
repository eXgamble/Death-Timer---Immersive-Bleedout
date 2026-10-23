Scriptname ANDR_KO_PlayerAliasScript extends ReferenceAlias

Perk Property ANDR_KO_TextReplacementPerk Auto

Event OnInit()
	(Game.GetPlayer()).AddPerk(ANDR_KO_TextReplacementPerk)
EndEvent

Event OnPlayerLoadGame()
	(GetOwningQuest() As ANDR_KO_QuestScript).RegisterForDownedEvent()
EndEvent
