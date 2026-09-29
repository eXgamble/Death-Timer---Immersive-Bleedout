Scriptname ANDR_KO_SyncUnconScript extends activemagiceffect  

Actor EffectTargetActor

Event OnEffectStart(Actor akTarget, Actor akCaster)
	EffectTargetActor = akTarget
	If !EffectTargetActor.IsUnconscious()
		EffectTargetActor.SetUnconscious()
	EndIf
	If EffectTargetActor.IsInCombat()
		EffectTargetActor.StopCombat()
	EndIf
	EffectTargetActor.SetNotShowOnStealthMeter(true)			
EndEvent