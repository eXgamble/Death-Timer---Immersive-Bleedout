;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 6
Scriptname PRKF_ANDR_KO_TextReplacement_0100080C Extends Perk Hidden

;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akTargetRef, Actor akActor)
;BEGIN CODE
; UNUSED (perk entry disabled): Give Potion now runs through Modifier Key Framework (DeathTimer.json)
If ANDR_KO_PlayerAliasQuest == None
	ANDR_KO_PlayerAliasQuest = Game.GetFormFromFile(0x80B, "Death Timer - Immersive Bleedout.esp") As Quest
EndIf
(ANDR_KO_PlayerAliasQuest As ANDR_KO_QuestScript).AdministerPotion(akTargetRef As Actor)
;END CODE
EndFunction
;END FRAGMENT

;BEGIN FRAGMENT Fragment_2
Function Fragment_2(ObjectReference akTargetRef, Actor akActor)
;BEGIN CODE
; UNUSED (perk entry disabled): Give Potion now runs through Modifier Key Framework (DeathTimer.json)
If ANDR_KO_PlayerAliasQuest == None
	ANDR_KO_PlayerAliasQuest = Game.GetFormFromFile(0x80B, "Death Timer - Immersive Bleedout.esp") As Quest
EndIf
(ANDR_KO_PlayerAliasQuest As ANDR_KO_QuestScript).AdministerPotion(akTargetRef As Actor)
;END CODE
EndFunction
;END FRAGMENT

;BEGIN FRAGMENT Fragment_4
Function Fragment_4(ObjectReference akTargetRef, Actor akActor)
;BEGIN CODE
; Bleeding out or stuck, not knocked out by this mod: unstick and talk
If ANDR_KO_PlayerAliasQuest == None
	ANDR_KO_PlayerAliasQuest = Game.GetFormFromFile(0x80B, "Death Timer - Immersive Bleedout.esp") As Quest
EndIf
(ANDR_KO_PlayerAliasQuest As ANDR_KO_QuestScript).HelpUpStuckActor(akTargetRef As Actor)
;END CODE
EndFunction
;END FRAGMENT

;BEGIN FRAGMENT Fragment_5
Function Fragment_5(ObjectReference akTargetRef, Actor akActor)
;BEGIN CODE
; UNUSED (perk entry disabled): Search now runs through Modifier Key Framework (modifier key)
Utility.Wait(0.1)
(akTargetRef As Actor).OpenInventory(true)
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment

Message Property ANDR_KO_NPCMessageBox Auto

ReferenceAlias Property KOActor Auto

FormList Property WEHealingPotions Auto

Message Property ANDR_KO_KillMessageBox Auto

Actor Property PlayerRef Auto

MiscObject Property ANDR_KO_Token Auto

Quest Property ANDR_KO_PlayerAliasQuest Auto

Actor Property DLC1SeranaRef Auto

ReferenceAlias Property ResponsiveNPC_Essential Auto

Actor Property ANDR_KO_ACHR_DummyRef Auto
