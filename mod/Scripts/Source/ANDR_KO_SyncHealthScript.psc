Scriptname ANDR_KO_SyncHealthScript extends activemagiceffect  

Actor EffectTargetActor
Float ActorCurrentHealth

Event OnEffectStart(Actor akTarget, Actor akCaster)
	EffectTargetActor = akTarget
	ActorCurrentHealth = EffectTargetActor.GetActorValue("Health")
	If ActorCurrentHealth > 0.5
		EffectTargetActor.DamageActorValue("Health", ActorCurrentHealth - 0.5)	
	EndIf
	If EffectTargetActor.IsInCombat()
		EffectTargetActor.StopCombat()
	EndIf			
	EffectTargetActor.SetNotShowOnStealthMeter(true)
EndEvent