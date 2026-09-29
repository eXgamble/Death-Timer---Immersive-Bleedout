Scriptname ANDR_KO_EnterBleedoutScript extends activemagiceffect  

MiscObject Property ANDR_KO_Token Auto

Keyword Property MagicRestoreHealth Auto
Keyword Property MagicAlchRestoreHealth Auto
Keyword Property MagicAlchFortifyHealRate Auto
Keyword Property MagicAlchFortifyHealth Auto		

GlobalVariable Property ANDR_KO_AllowNotifications Auto

Actor EffectTargetActor
Float ActorCurrentHealth
String EffectTargetActorName

Event OnEffectStart(Actor akTarget, Actor akCaster)
	EffectTargetActor = Self.GetTargetActor()
	If !EffectTargetActor.GetNoBleedoutRecovery()
		EffectTargetActor.SetNoBleedoutRecovery(true)
	EndIf
	If EffectTargetActor.GetItemCount(ANDR_KO_Token) == 0
		EffectTargetActor.AddItem(ANDR_KO_Token, 1)
		ANDR_KO_QuestScript KOQuest = Game.GetFormFromFile(0x80B, "Death Timer - Immersive Bleedout.esp") As ANDR_KO_QuestScript
		KOQuest.KnockDown(EffectTargetActor)
		EffectTargetActorName = EffectTargetActor.GetBaseObject().GetName()
		If ANDR_KO_AllowNotifications.GetValue() == 1
			If KOQuest.IsDeathTimerCandidate(EffectTargetActor)
				Debug.Notification("" + EffectTargetActorName + " has fallen unconscious and is dying.")
			Else
				Debug.Notification("" + EffectTargetActorName + " is knocked out.")
			EndIf
		EndIf
	EndIf
EndEvent