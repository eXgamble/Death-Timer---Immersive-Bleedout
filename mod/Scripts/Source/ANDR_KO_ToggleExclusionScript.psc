scriptName ANDR_KO_ToggleExclusionScript extends ActiveMagicEffect

Faction Property ANDR_KO_FACT_IgnoreKnockdown Auto

Actor Caster

Event OnEffectStart(Actor akTarget, Actor akCaster)
	Caster = akCaster
	Caster.AddToFaction(ANDR_KO_FACT_IgnoreKnockdown)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	Caster.RemoveFromFaction(ANDR_KO_FACT_IgnoreKnockdown)
EndEvent