Scriptname ANDR_KO_GivePotionAliasScript extends ReferenceAlias  

Formlist Property WEHealingPotions Auto

Actor Property PlayerRef Auto

Keyword Property MagicAlchRestoreHealth Auto

Import Utility
Import Debug
Import Input

Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
	If UI.IsMenuOpen("GiftMenu")
		HoldKey(1)
		Wait(0.1)
		ReleaseKey(1)
	EndIf

	Actor SelfActor = Self.GetReference() As Actor
	String SelfActorName = SelfActor.GetBaseObject().GetName()
	String akBaseItemName = akBaseItem.GetName()

	If IsHealingPotion(akBaseItem as Potion)
		If aiItemCount > 1												
			; If more than 1 potion has been gifted, return all but one.
			Int ReturnAmountPotions = aiItemCount - 1
			SelfActor.RemoveItem(akBaseItem, ReturnAmountPotions, true, PlayerRef)
		EndIf
		; using Andrealphus' Papyrus Functions to bypass conflict of Ultimate Animated Potions.
		SelfActor.RemoveItem(akBaseItem, 1, true)
		ANDR_PapyrusFunctions.CastPotion(PlayerRef, akBaseItem as Potion, SelfActor)					; Function from Andrealphus' Papyrus Functions
		Notification("" + SelfActorName + " has consumed " + akBaseItemName + ".")
	Else
		SelfActor.RemoveItem(akBaseItem, aiItemCount, true, PlayerRef)
		Messagebox("This potion won't have any effect.")
	EndIf
	Self.Clear()
EndEvent

Bool Function IsHealingPotion(Potion PotionToCheck)
	int numEffects = PotionToCheck.GetNumEffects()
	int index = 0
	While index < numEffects
		MagicEffect effect = PotionToCheck.GetNthEffectMagicEffect(index)
		If	effect.HasKeyword(MagicAlchRestoreHealth)
			Return True
		EndIf
		index += 1
	EndWhile
	Return False
EndFunction	
