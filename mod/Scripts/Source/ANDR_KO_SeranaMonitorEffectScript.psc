scriptName ANDR_KO_SeranaMonitorEffectScript extends ActiveMagicEffect

Actor Property DLC1SeranaRef Auto

ReferenceAlias Property SeranaVampireAlias Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	SeranaVampireAlias.ForceRefTo(DLC1SeranaRef)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	SeranaVampireAlias.Clear()
EndEvent