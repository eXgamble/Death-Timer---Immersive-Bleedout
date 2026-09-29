Scriptname ANDR_KO_RecoverScript extends activemagiceffect  

; ==== Filled Properties ====

MiscObject Property ANDR_KO_Token Auto

Keyword Property MagicRestoreHealth Auto
Keyword Property MagicAlchRestoreHealth Auto
Keyword Property MagicAlchFortifyHealRate Auto
Keyword Property MagicAlchFortifyHealth Auto		
Keyword Property ActorTypeUndead Auto
Keyword Property ActorTypeDaedra Auto
Keyword Property ActorTypeDwarven Auto
Keyword Property VampireKeyword Auto
Keyword Property ANDR_KO_AliasKeyword Auto

GlobalVariable Property ANDR_KO_RecoverHours Auto

FormList Property ANDR_KO_RestoreHealthEffectKeywords_List Auto
FormList Property ANDR_KO_VampireHealOnlyEffects_List Auto
FormList Property ANDR_KO_RecoverEffectExclusions_List Auto

Message Property ANDR_KO_HealFailMessageBox Auto

Quest Property ANDR_KO_PlayerAliasQuest Auto

; ==== Unfilled Properties ====

Actor Property EffectTargetActor Auto

ReferenceAlias Property RelevantAlias Auto

; ==== Variables ====

Float ActorCurrentHealth
Float ANDR_KO_RecoverHoursINT
String EffectTargetActorName

; ==== Imports ====

Import PO3_Events_AME

; ==== Events ====

Event OnEffectStart(Actor akTarget, Actor akCaster)
	EffectTargetActor = Self.GetTargetActor() 

	If ANDR_KO_PlayerAliasQuest == None						
		ANDR_KO_PlayerAliasQuest = Game.GetFormFromFile(0x80B, "Death Timer - Immersive Bleedout.esp") As Quest
	EndIf
	
	If ANDR_KO_RestoreHealthEffectKeywords_List == None						; when updating from an earlier version
		ANDR_KO_RestoreHealthEffectKeywords_List = Game.GetFormFromFile(0xD79, "Death Timer - Immersive Bleedout.esp") As FormList
	EndIf

	RegisterForMagicEffectApplyEx(Self, ANDR_KO_RestoreHealthEffectKeywords_List, true)		; requires po3 -> PO3_Events_AME

	If ANDR_KO_AliasKeyword == None
		ANDR_KO_AliasKeyword = Game.GetFormFromFile(0xE7B, "Death Timer - Immersive Bleedout.esp") As Keyword
	EndIf

	; check if EffectTargetActor has already been added to an alias -> keyword in alias!
	; If not, look for an empty alias, and start monitoring.
	If !EffectTargetActor.HasKeyword(ANDR_KO_AliasKeyword)		; look for empty alias to fill
		RelevantAlias = GetEmptyAlias()
		If RelevantAlias != None
			RelevantAlias.ForceRefTo(EffectTargetActor)
			(RelevantAlias As ANDR_KO_RecoverAliasScript).StartMonitorRecovery()
		Else
			; this means we ran out of aliases -> use old method instead, with drawback that NPC will only recover when player is in the loaded cell!
			ANDR_KO_RecoverHoursINT = ANDR_KO_RecoverHours.GetValue()
			If ANDR_KO_RecoverHoursINT > 0											; if global is set to 0 or lower, disable recovering over time!
				RegisterForSingleUpdateGameTime(ANDR_KO_RecoverHoursINT)	
			EndIf
		EndIf	
	Else														; else look for relevant alias	
		RelevantAlias = GetRelevantAlias()
	EndIf
EndEvent

Event OnMagicEffectApplyEx(ObjectReference akCaster, MagicEffect akEffect, Form akSource, bool abApplied)		; requires po3 -> PO3_Events_AME

	If ANDR_KO_VampireHealOnlyEffects_List == None
		ANDR_KO_VampireHealOnlyEffects_List = Game.GetFormFromFile(0xF7D, "Death Timer - Immersive Bleedout.esp") As FormList
	EndIf
	If ANDR_KO_HealFailMessageBox == None
		ANDR_KO_HealFailMessageBox = Game.GetFormFromFile(0xF7E, "Death Timer - Immersive Bleedout.esp") As Message
	EndIf
	If VampireKeyword == None
		VampireKeyword = Game.GetFormFromFile(0xA82BB, "Skyrim.esm") As Keyword
	EndIf
	If ANDR_KO_RecoverEffectExclusions_List == None
		ANDR_KO_RecoverEffectExclusions_List = Game.GetFormFromFile(0xF81, "Death Timer - Immersive Bleedout.esp") As FormList
	EndIf

	EffectTargetActor = Self.GetTargetActor()
	If !ANDR_KO_RecoverEffectExclusions_List.HasForm(akEffect)
		If abApplied
			RecoverActor(true)
		Else
			; If NPC consumed a potion but it had no effect, display a notification
			; This only covers the case of Vampire-specific potions
			If akEffect.HasKeyword(MagicAlchRestoreHealth) && (EffectTargetActor.HasKeyword(VampireKeyword) && ANDR_KO_VampireHealOnlyEffects_List.HasForm(akEffect))
				ANDR_KO_HealFailMessageBox.Show()
			EndIf
		EndIf
	EndIf
EndEvent

Event OnUpdateGameTime()
	EffectTargetActor = Self.GetTargetActor()  
	ActorCurrentHealth = EffectTargetActor.GetActorValue("Health")
	(ANDR_KO_PlayerAliasQuest As ANDR_KO_QuestScript).RecoverActor(EffectTargetActor, ActorCurrentHealth, False)	
EndEvent

; ======= Functions ======

Function RecoverActor(Bool UseDialogueLines = False)
	ActorCurrentHealth = EffectTargetActor.GetActorValue("Health")
	(ANDR_KO_PlayerAliasQuest As ANDR_KO_QuestScript).RecoverActor(EffectTargetActor, ActorCurrentHealth, UseDialogueLines)
	; get alias, interrupt monitor and clear
	(RelevantAlias As ANDR_KO_RecoverAliasScript).InterruptMonitorRecovery()
	RelevantAlias.Clear()
EndFunction

ReferenceAlias Function GetEmptyAlias()
	Int AliasIndexMax = 2047
	Int iIndex = 1
	While iIndex <= AliasIndexMax
		If (ANDR_KO_PlayerAliasQuest.GetAlias(iIndex) As ReferenceAlias).GetReference() == None
			Return (ANDR_KO_PlayerAliasQuest.GetAlias(iIndex) As ReferenceAlias)
		EndIf
		iIndex += 1
	EndWhile
	Return None
EndFunction	

ReferenceAlias Function GetRelevantAlias()
	EffectTargetActor = Self.GetTargetActor() 
	Int AliasIndexMax = 2047
	Int iIndex = 1
	While iIndex <= AliasIndexMax
		If EffectTargetActor == ((ANDR_KO_PlayerAliasQuest.GetAlias(iIndex) As ReferenceAlias).GetReference() As Actor)
			Return (ANDR_KO_PlayerAliasQuest.GetAlias(iIndex) As ReferenceAlias)
		EndIf
		iIndex += 1
	EndWhile
	Return None
EndFunction
