Scriptname ANDR_KO_SyncParaScript extends activemagiceffect  

Actor EffectTargetActor

Event OnEffectStart(Actor akTarget, Actor akCaster)
	EffectTargetActor = akTarget
	If EffectTargetActor.GetActorValue("Paralysis") != 1
		EffectTargetActor.ForceActorValue("Paralysis", 1)		; set, not add: ANDR_KO_QuestScript.KnockDown may run at the same moment
		EffectTargetActor.PushActorAway(EffectTargetActor, 0.001)
	EndIf
	If EffectTargetActor.IsInCombat()
		EffectTargetActor.StopCombat()
	EndIf
	EffectTargetActor.SetNotShowOnStealthMeter(true)
EndEvent