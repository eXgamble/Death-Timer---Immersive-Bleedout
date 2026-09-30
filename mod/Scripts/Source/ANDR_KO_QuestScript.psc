Scriptname ANDR_KO_QuestScript extends Quest  

MiscObject Property ANDR_KO_Token Auto

FormList Property ANDR_KO_PressEToHealFollower_List Auto		; unused, kept because the plugin still binds it

Topic Property ANDR_KO_ThankYouTopic Auto

GlobalVariable Property ANDR_KO_AllowNotifications Auto

; Notification that respects the "Use Notifications" setting
Function Notify(String asMessage)
	If ANDR_KO_AllowNotifications == None
		ANDR_KO_AllowNotifications = Game.GetFormFromFile(0xD71, "Death Timer - Immersive Bleedout.esp") As GlobalVariable
	EndIf
	If ANDR_KO_AllowNotifications.GetValue() == 1
		Debug.Notification(asMessage)
	EndIf
EndFunction

Function RecoverActor(Actor akActor, Float fHealth, bool UseDialogueLines = False)

	If ANDR_KO_Token == None
		ANDR_KO_Token = Game.GetFormFromFile(0x807, "Death Timer - Immersive Bleedout.esp") As MiscObject
	EndIf
	If akActor.GetItemCount(ANDR_KO_Token) > 0
		akActor.RemoveItem(ANDR_KO_Token, 999)
		If akActor.IsInFaction(GetDyingFaction())						; downed by the SKSE plugin: undo their temporary protection
			DeathTimer.SetDownedProtection(akActor, false)
			If akActor.GetActorBase().IsProtected()						; saves from before per-NPC protection set it on the record
				akActor.GetActorBase().SetProtected(false)
			EndIf
			akActor.RemoveFromFaction(GetDyingFaction())
		EndIf
		If fHealth < 0.5
			akActor.RestoreActorValue("Health", 0.5 - fHealth)		; was fHealth + 0.5, a no-op for negative health
		ElseIf fHealth > 0.5
			akActor.DamageActorValue("Health", fHealth - 0.5)				
		EndIf
		akActor.SetNotShowOnStealthMeter(false)	
		If akActor.IsUnconscious()
			akActor.SetUnconscious(false)
		EndIf
		If akActor.GetActorValue("Paralysis") > 0
			akActor.ForceActorValue("Paralysis", 0)
			Utility.Wait(0.25)
			akActor.QueueNiNodeUpdate() 							; Fix actor animation issues caused by paralysis
		EndIf
		akActor.SetNoBleedoutRecovery(false)						; undo EnterBleedout, back to vanilla behaviour
		akActor.EvaluatePackage()

		; Safety net: give the get-up animation time to play, then unstick if the graph is still in bleedout
		Utility.Wait(3.0)
		If !akActor.IsDead() && akActor.GetItemCount(ANDR_KO_Token) == 0 && akActor.GetAnimationVariableBool("IsBleedingOut")
			UnstickBleedout(akActor)
		EndIf

		; Rescued by healing (not waking up on their own): thank the player once they're back on their feet
		If UseDialogueLines
			SayThankYou(akActor)
		EndIf
	EndIf
EndFunction

; Generic vanilla "thanks" line for the actor's voice type (ANDR_KO_ThankYouTopic reuses the
; WISharedThanks lines). Voice types without one just say nothing.
Function SayThankYou(Actor akActor)
	If ANDR_KO_ThankYouTopic == None
		ANDR_KO_ThankYouTopic = Game.GetFormFromFile(0xF8E, "Death Timer - Immersive Bleedout.esp") As Topic
	EndIf
	Int Waited = 0
	While IsBodyDown(akActor) && Waited < 10					; wait up to 5s more for the get-up to finish
		Utility.Wait(0.5)
		Waited += 1
	EndWhile
	If !akActor.IsDead() && !IsBodyDown(akActor) && akActor.Is3DLoaded()
		akActor.Say(ANDR_KO_ThankYouTopic)
	EndIf
EndFunction

; ==== Death Timer ====

; Two paths once knocked out:
;  - dying, healed or dead, no game-time recovery: followers (player teammates) that aren't essential,
;    while the MCM "Follower Death Timer" option is on, and NPCs the DeathTimer SKSE plugin saved
;    from a fatal hit (in ANDR_KO_FACT_Dying)
;  - everyone else: knocked out, recovers over game time, never dies. That's essential NPCs (by any quest
;    alias too, e.g. Serana, story NPCs) and protected non-followers, who in vanilla only the player can kill
Bool Function IsDeathTimerCandidate(Actor akActor)
	If akActor.IsEssential()
		Return False
	EndIf
	If akActor.IsInFaction(GetDyingFaction())
		Return True
	EndIf
	Return akActor.IsPlayerTeammate() && GetFollowerDeathTimer().GetValue() != 0
EndFunction

GlobalVariable Property ANDR_KO_GLOB_FollowerDeathTimer Auto

; MCM "Follower Death Timer" (set from the menu on every load by ANDR_KO_Quest_MCMScript.LoadSettings)
GlobalVariable Function GetFollowerDeathTimer()
	If ANDR_KO_GLOB_FollowerDeathTimer == None
		ANDR_KO_GLOB_FollowerDeathTimer = Game.GetFormFromFile(0xFB8, "Death Timer - Immersive Bleedout.esp") As GlobalVariable
	EndIf
	Return ANDR_KO_GLOB_FollowerDeathTimer
EndFunction

Faction Property ANDR_KO_FACT_Dying Auto
Spell Property ANDR_KO_SPEL Auto

Faction Function GetDyingFaction()
	If ANDR_KO_FACT_Dying == None
		ANDR_KO_FACT_Dying = Game.GetFormFromFile(0xFB6, "Death Timer - Immersive Bleedout.esp") As Faction
	EndIf
	Return ANDR_KO_FACT_Dying
EndFunction

; ==== NPCs downed by the DeathTimer SKSE plugin ====

; Re-registered on every game load by ANDR_KO_PlayerAliasScript: mod event registrations don't survive a reload.
Function RegisterForDownedEvent()
	RegisterForModEvent("DeathTimer_Downed", "OnNPCDowned")
	; Activating a downed NPC, through Modifier Key Framework (rule file SKSE\Plugins\ModifierKeyFramework\DeathTimer.json)
	RegisterForModEvent("DeathTimer_GivePotion", "OnGivePotionActivated")
	RegisterForModEvent("DeathTimer_Search", "OnSearchActivated")
EndFunction

Event OnGivePotionActivated(String asEventName, String asStrArg, Float afNumArg, Form akSender)
	Actor akActor = akSender As Actor
	If akActor && !akActor.IsDead()
		AdministerPotion(akActor)
	EndIf
EndEvent

Event OnSearchActivated(String asEventName, String asStrArg, Float afNumArg, Form akSender)
	Actor akActor = akSender As Actor
	If akActor
		akActor.OpenInventory(true)
	EndIf
EndEvent

Event OnInit()
	RegisterForDownedEvent()
EndEvent

; The plugin kept a named, friendly, non-essential, non-protected NPC from dying to someone other
; than the player. Knock them out onto the Death Timer: the marker item starts the knockout effects
; (paralysis, unconscious, pinned health) and the recovery watcher, which arms the timer.
Event OnNPCDowned(String asEventName, String asStrArg, Float afNumArg, Form akSender)
	Actor akActor = akSender As Actor
	If akActor == None || akActor.IsDead()
		Return
	EndIf
	If ANDR_KO_Token == None
		ANDR_KO_Token = Game.GetFormFromFile(0x807, "Death Timer - Immersive Bleedout.esp") As MiscObject
	EndIf
	If akActor.GetItemCount(ANDR_KO_Token) > 0							; already down (hit again while dying)
		Return
	EndIf
	KnockDown(akActor)												; first: making them protected at 1 HP starts vanilla bleedout
	akActor.AddToFaction(GetDyingFaction())							; before the token, so the timer path is picked
	; Protected while down, like a follower: enemies stop attacking someone they can't kill, and the
	; player can still finish them. Set on this NPC only (native): unnamed NPCs share their NPC record.
	DeathTimer.SetDownedProtection(akActor, true)
	akActor.SetNoBleedoutRecovery(true)
	; SPID only gives the knockout ability to unique NPCs; a generic one downed by the plugin needs it
	; now, or nothing keeps them down, arms their timer or notices a potion
	If ANDR_KO_SPEL == None
		ANDR_KO_SPEL = Game.GetFormFromFile(0x808, "Death Timer - Immersive Bleedout.esp") As Spell
	EndIf
	If !akActor.HasSpell(ANDR_KO_SPEL)
		akActor.AddSpell(ANDR_KO_SPEL, false)
	EndIf
	akActor.AddItem(ANDR_KO_Token, 1, true)
	Notify(akActor.GetBaseObject().GetName() + " has fallen unconscious and is dying.")
EndEvent

; Collapse them right away. The knockout's paralysis effect (ANDR_KO_SyncParaScript) does the same
; once the game re-checks its conditions, which can leave them kneeling in vanilla bleedout for a
; moment first; doing it here closes that gap, and the effect then finds it already done.
; Force (set to 1), not Mod (add 1): the effect may run at the same moment, and two adds would
; leave paralysis at 2.
Function KnockDown(Actor akActor)
	If akActor.GetActorValue("Paralysis") != 1
		akActor.ForceActorValue("Paralysis", 1)
		akActor.PushActorAway(akActor, 0.001)
	EndIf
EndFunction

; ==== Kill (Death Timer) ====

Actor Property DLC1SeranaRef Auto
ReferenceAlias Property ResponsiveNPC_Essential Auto
Actor Property ANDR_KO_ACHR_DummyRef Auto

; Same steps as the original ABR menu Kill. The token has to go first, or this mod's own
; knockout effects keep re-applying paralysis/unconsciousness/pinned health against the kill.
Function KillKnockedOutActor(Actor akActor)
	If ANDR_KO_Token == None
		ANDR_KO_Token = Game.GetFormFromFile(0x807, "Death Timer - Immersive Bleedout.esp") As MiscObject
	EndIf
	akActor.RemoveItem(ANDR_KO_Token, 999)
	ActorBase KOVictim = akActor.GetActorBase()

	; Serana is kept essential by her Dawnguard alias: point that alias at a dummy actor instead
	If DLC1SeranaRef == None
		DLC1SeranaRef = Game.GetFormFromFile(0x2B74, "Dawnguard.esm") As Actor
	EndIf
	If akActor == DLC1SeranaRef
		If ResponsiveNPC_Essential == None
			Quest DLC1NPCMentalModel = Game.GetFormFromFile(0x2B6E, "Dawnguard.esm") As Quest
			ResponsiveNPC_Essential = DLC1NPCMentalModel.GetAlias(1) As ReferenceAlias
		EndIf
		If ANDR_KO_ACHR_DummyRef == None
			ANDR_KO_ACHR_DummyRef = Game.GetFormFromFile(0xF8A, "Death Timer - Immersive Bleedout.esp") As Actor
		EndIf
		ResponsiveNPC_Essential.ForceRefTo(ANDR_KO_ACHR_DummyRef)
		Utility.Wait(0.1)
	EndIf

	; Follower slots are flagged Protected (vanilla and Simple Follower Framework), which blocks
	; any kill not done by the player: take them out of their slot first
	ReleaseFromFollowerAliases(akActor)

	If KOVictim.IsEssential()
		KOVictim.SetEssential(false)
	EndIf
	If KOVictim.IsProtected()
		KOVictim.SetProtected(false)
	EndIf
	If KOVictim.IsInvulnerable()
		KOVictim.SetInvulnerable(false)
	EndIf
	If akActor.IsInFaction(GetDyingFaction())						; downed by the SKSE plugin: drop their temporary protection
		DeathTimer.SetDownedProtection(akActor, false)
	EndIf
	Utility.Wait(0.1)
	; No killer, so the player isn't blamed. Note: a protected actor can only be killed by the player,
	; and Simple Follower Framework flags its follower aliases Protected - that has to be off for this to work.
	akActor.Kill()
EndFunction

; The player finishing off a knocked-out protected non-follower: the same as killing them in vanilla,
; so the player is the killer (crime and all). Protected actors can always be killed by the player,
; so no flags need stripping, which would otherwise leak onto every NPC sharing their base record.
Function KillByPlayer(Actor akActor)
	If ANDR_KO_Token == None
		ANDR_KO_Token = Game.GetFormFromFile(0x807, "Death Timer - Immersive Bleedout.esp") As MiscObject
	EndIf
	akActor.RemoveItem(ANDR_KO_Token, 999)
	Utility.Wait(0.1)
	akActor.Kill(Game.GetPlayer())
EndFunction

; Empty every DialogueFollower slot holding akActor. Simple Follower Framework recounts its
; followers on load and before each recruit, so nothing else needs updating.
Function ReleaseFromFollowerAliases(Actor akActor)
	Quest DialogueFollower = Game.GetFormFromFile(0x750BA, "Skyrim.esm") As Quest
	Int i = DialogueFollower.GetNumAliases()
	While i
		i -= 1
		ReferenceAlias Slot = DialogueFollower.GetNthAlias(i) As ReferenceAlias
		If Slot && Slot.GetReference() == akActor
			Slot.Clear()
		EndIf
	EndWhile
EndFunction

; ==== Offscreen recovery ====

; Called when an actor who recovered while unloaded gets their 3D back (walked into their cell,
; or summoned by a follower mod). Plays the get-up the recovery couldn't play offscreen.
Function FinishOffscreenRecovery(Actor akActor)
	If akActor == None || akActor.IsDead()
		Return
	EndIf
	Utility.Wait(1.0)								; let the 3D and animation graph settle
	If !IsBodyDown(akActor)
		Return
	EndIf
	ForceGetUp(akActor)
EndFunction

; Make the engine play a get-up for a body lying on the ground, whatever state it's stuck in
Function ForceGetUp(Actor akActor)
	If akActor.IsUnconscious()
		akActor.SetUnconscious(false)
	EndIf
	; Replay this mod's knockdown -> release cycle so the engine runs the get-up
	akActor.ForceActorValue("Paralysis", 1)
	akActor.PushActorAway(akActor, 0.001)
	Utility.Wait(1.0)
	akActor.ForceActorValue("Paralysis", 0)
	; Let the get-up animation finish; interrupting it leaves the actor standing but unresponsive
	Int Waited = 0
	Utility.Wait(0.5)
	While PO3_SKSEFunctions.GetActorKnockState(akActor) != 0 && Waited < 16
		Utility.Wait(0.5)
		Waited += 1
	EndWhile
	; Re-sync AI and position, the same thing a teleport does, without moving them
	akActor.MoveTo(akActor)
	akActor.EvaluatePackage()
	If IsBodyDown(akActor)
		; Last resort: bleedout ends when health comes back (this mod blocks the natural regen),
		; so heal them up, then drop back to low health once they're on their feet
		akActor.RestoreActorValue("Health", 10000.0)
		Utility.Wait(2.0)
		Float CurrentHealth = akActor.GetActorValue("Health")
		If CurrentHealth > 1.0
			akActor.DamageActorValue("Health", CurrentHealth - 1.0)
		EndIf
		akActor.EvaluatePackage()
		Utility.Wait(2.0)
	EndIf
EndFunction

; Still lying down: bleeding out, unconscious, paralysed or ragdolled
Bool Function IsBodyDown(Actor akActor)
	If akActor.IsBleedingOut() || akActor.IsUnconscious() || akActor.GetActorValue("Paralysis") > 0
		Return True
	EndIf
	If akActor.GetAnimationVariableBool("IsBleedingOut")
		Return True
	EndIf
	Int LifeState = PO3_SKSEFunctions.GetActorState(akActor)		; 3 unconscious, 7 essential down, 8 bleedout
	If LifeState == 3 || LifeState == 7 || LifeState == 8
		Return True
	EndIf
	Int KnockState = PO3_SKSEFunctions.GetActorKnockState(akActor)	; 0 normal, 6 getting up
	Return KnockState != 0 && KnockState != 6
EndFunction

; ==== Stuck bleedout (replaces "NPC Stuck in Bleedout fix") ====

; Activated a bleeding-out or stuck NPC who isn't knocked out by this mod: unstick, then talk.
Function HelpUpStuckActor(Actor akTarget)
	akTarget.AllowBleedoutDialogue(true)
	UnstickBleedout(akTarget)
	akTarget.Activate(Game.GetPlayer(), true)		; default processing only, so this perk doesn't fire again
EndFunction

; An essential NPC whose animation is stuck in bleedout: knock them properly into bleedout and
; back out so the engine re-runs recovery. Otherwise nudge health so regen re-evaluates.
Function UnstickBleedout(Actor akActor)
	If !akActor.IsBleedingOut() && (akActor.IsEssential() || akActor.GetActorBase().IsProtected())
		Float CurrentHealth = akActor.GetActorValue("Health")
		akActor.DamageActorValue("Health", CurrentHealth + 1)
		akActor.RestoreActorValue("Health", CurrentHealth)
	EndIf
	If akActor.GetActorValue("Health") > 1
		akActor.DamageActorValue("Health", 0.01)
	EndIf
EndFunction

; ==== Give Potion (activate a knocked-out NPC) ====

Keyword Property MagicAlchRestoreHealth Auto
Keyword Property VampireKeyword Auto
FormList Property ANDR_KO_VampireHealOnlyEffects_List Auto

Function AdministerPotion(Actor akTarget)
	Actor Player = Game.GetPlayer()
	Potion HealthPotion = FindWeakestHealingPotion(Player, akTarget)
	If HealthPotion == None
		Debug.Notification("You have no healing potions to give.")		; always shown: feedback on the player's own action
		Return
	EndIf
	Player.RemoveItem(HealthPotion, 1, true)
	ANDR_PapyrusFunctions.CastPotion(Player, HealthPotion, akTarget)		; recovery is picked up by ANDR_KO_RecoverScript
	Notify("You gave " + HealthPotion.GetName() + " to " + akTarget.GetDisplayName() + ".")
EndFunction

; The cheapest (gold value) healing potion in akSource's inventory.
; Skips food and poisons, and blood potions unless the patient is a vampire.
Potion Function FindWeakestHealingPotion(Actor akSource, Actor akPatient)
	If MagicAlchRestoreHealth == None
		MagicAlchRestoreHealth = Game.GetFormFromFile(0x42503, "Skyrim.esm") As Keyword
	EndIf
	If VampireKeyword == None
		VampireKeyword = Game.GetFormFromFile(0xA82BB, "Skyrim.esm") As Keyword
	EndIf
	If ANDR_KO_VampireHealOnlyEffects_List == None
		ANDR_KO_VampireHealOnlyEffects_List = Game.GetFormFromFile(0xF7D, "Death Timer - Immersive Bleedout.esp") As FormList
	EndIf
	Bool PatientIsVampire = akPatient.HasKeyword(VampireKeyword)

	Potion Cheapest = None
	Int CheapestValue = 0
	Form[] Items = PO3_SKSEFunctions.AddItemsOfTypeToArray(akSource, 46)		; 46 = kAlchemyItem: potions, poisons, food only
	Int i = Items.Length
	While i
		i -= 1
		Potion p = Items[i] As Potion
		Int Value = p.GetGoldValue()
		; only look at the effects of a potion that would beat the current pick
		If (Cheapest == None || Value < CheapestValue) && !p.IsFood() && !p.IsPoison()
			Bool Heals = false
			Bool Usable = true
			Int n = p.GetNumEffects()
			While n && Usable
				n -= 1
				MagicEffect Effect = p.GetNthEffectMagicEffect(n)
				If !PatientIsVampire && ANDR_KO_VampireHealOnlyEffects_List.HasForm(Effect)
					Usable = false
				ElseIf Effect.HasKeyword(MagicAlchRestoreHealth)
					Heals = true
				EndIf
			EndWhile
			If Heals && Usable
				Cheapest = p
				CheapestValue = Value
			EndIf
		EndIf
	EndWhile
	Return Cheapest
EndFunction

Function LimitGiftToOne()
	RegisterForMenu("GiftMenu")
EndFunction

Event OnMenuOpen(String MenuName)
	If MenuName == "GiftMenu"
		UnregisterForMenu("GiftMenu")
		Utility.WaitMenuMode(0.1)
		UI.SetInt("GiftMenu", "_root.Menu_mc._quantityMinCount", -12878323)

		While UI.IsMenuOpen("GiftMenu")
			Utility.Wait(0.1)
		EndWhile
	EndIf
EndEvent