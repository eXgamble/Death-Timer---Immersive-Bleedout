scriptName ANDR_KO_RecoverAliasScript extends ReferenceAlias

MiscObject Property ANDR_KO_Token Auto

GlobalVariable Property ANDR_KO_RecoverHours Auto

Event OnDeath(Actor akKiller)
	If ANDR_KO_Token == None
		ANDR_KO_Token = Game.GetFormFromFile(0x807, "Death Timer - Immersive Bleedout.esp") As MiscObject
	EndIf
    (Self.GetReference() As Actor).RemoveItem(ANDR_KO_Token, 999)
    DyingStep = 0
    UnregisterForUpdateGameTime()
    UnregisterForUpdate()
    Clear()
EndEvent

Function StartMonitorRecovery()
	If ANDR_KO_Token == None
		ANDR_KO_Token = Game.GetFormFromFile(0x807, "Death Timer - Immersive Bleedout.esp") As MiscObject
	EndIf
    If (Self.GetReference() As Actor).GetItemCount(ANDR_KO_Token) > 0
        Dying = False
        If ANDR_KO_RecoverHours == None
            ANDR_KO_RecoverHours = Game.GetFormFromFile(0x809, "Death Timer - Immersive Bleedout.esp") As GlobalVariable
        EndIf
        Actor SelfActor = Self.GetReference() As Actor
        If (GetOwningQuest() As ANDR_KO_QuestScript).IsDeathTimerCandidate(SelfActor)
            ; Death Timer (real time), no recovering over time. Run in three steps (40%, 40%, 20%) so the wisp
            ; over them turns yellow, orange, then red; OnUpdate kills them after the last step.
            TimerSeconds = GetDeathTimerSeconds()
            DyingStep = 2
            DeathTimer.SetDownedState(SelfActor, 2)
            RegisterForSingleUpdate(TimerSeconds * 0.4)
        Else
            DyingStep = 0
            DeathTimer.SetDownedState(SelfActor, 1)				; knocked out: pale blue wisp
            Float fRecoverHours = ANDR_KO_RecoverHours.GetValue()
            If fRecoverHours > 0										; if global is set to 0 or lower, disable recovering over time!
                RegisterForSingleUpdateGameTime(fRecoverHours)
            EndIf
        EndIf
    EndIf
EndFunction

; ==== Death Timer ====

; From DeathTimer.ini, through the SKSE plugin. Falls back to 60 without it.
Float Function GetDeathTimerSeconds()
    Float Seconds = DeathTimer.GetDeathTimerSeconds()
    If Seconds < 10.0
        Return 60.0
    EndIf
    Return Seconds
EndFunction

Bool Dying

; The Death Timer's step: 2 yellow, 3 orange, 4 red (DeathTimer.SetDownedState), 0 when not dying. A save made
; before the steps existed has 0 here and a single update for the whole time: that one simply kills.
Int DyingStep
Float TimerSeconds

Event OnUpdate()
    Actor SelfActor = Self.GetReference() As Actor
    If SelfActor && SelfActor.GetItemCount(ANDR_KO_Token) > 0		; still knocked out, nobody treated them
        If DyingStep == 2
            DyingStep = 3
            DeathTimer.SetDownedState(SelfActor, 3)
            RegisterForSingleUpdate(TimerSeconds * 0.4)
        ElseIf DyingStep == 3
            DyingStep = 4
            DeathTimer.SetDownedState(SelfActor, 4)
            RegisterForSingleUpdate(TimerSeconds * 0.2)
        Else
            DyingStep = 0
            Die(SelfActor)
        EndIf
    EndIf
EndEvent

; The player finishing off a knocked-out NPC. This mod holds them down at low health, which keeps
; the engine from ever killing them, so a hit that takes their health to 0 or below has to be
; turned into a real death here.
; Essential NPCs are never killed. Everyone else, followers included, dies as in vanilla with the
; player as their killer: only the Death Timer running out kills without one.
Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, bool abBashAttack, bool abHitBlocked)
    Actor SelfActor = Self.GetReference() As Actor
    If Dying || SelfActor == None || akAggressor != Game.GetPlayer()
        Return
    EndIf
    ; Give Potion and healing spells also arrive as a "hit" from the player, while a downed NPC's
    ; health is often still below 0 from the blow that dropped them: only harmful hits count.
    If !IsHarmful(akSource)
        Return
    EndIf
    If SelfActor.GetItemCount(ANDR_KO_Token) > 0 && !SelfActor.IsEssential() && SelfActor.GetActorValue("Health") <= 0
        Die(SelfActor, True)
    EndIf
EndEvent

; Weapons, bashes and anything unknown count as harmful. Potions and ingredients never do, and
; spells, enchantments and scrolls only if one of their effects is flagged hostile (0x1).
Bool Function IsHarmful(Form akSource)
    If akSource As Potion || akSource As Ingredient
        Return False
    EndIf
    Spell SpellSource = akSource As Spell
    If SpellSource
        Int i = SpellSource.GetNumEffects()
        While i
            i -= 1
            If SpellSource.GetNthEffectMagicEffect(i).IsEffectFlagSet(0x1)
                Return True
            EndIf
        EndWhile
        Return False
    EndIf
    Enchantment EnchantSource = akSource As Enchantment
    If EnchantSource
        Int i = EnchantSource.GetNumEffects()
        While i
            i -= 1
            If EnchantSource.GetNthEffectMagicEffect(i).IsEffectFlagSet(0x1)
                Return True
            EndIf
        EndWhile
        Return False
    EndIf
    Scroll ScrollSource = akSource As Scroll
    If ScrollSource
        Int i = ScrollSource.GetNumEffects()
        While i
            i -= 1
            If ScrollSource.GetNthEffectMagicEffect(i).IsEffectFlagSet(0x1)
                Return True
            EndIf
        EndWhile
        Return False
    EndIf
    Return True
EndFunction

Function Die(Actor akActor, Bool abKilledByPlayer = False)
    If Dying
        Return
    EndIf
    Dying = True
    DyingStep = 0
    UnregisterForUpdate()
    UnregisterForUpdateGameTime()									; no auto-recovery for the dead
    ANDR_KO_QuestScript KOQuest = GetOwningQuest() As ANDR_KO_QuestScript
    KOQuest.Notify(akActor.GetBaseObject().GetName() + " has died.")
    If abKilledByPlayer
        KOQuest.KillByPlayer(akActor)
    Else
        KOQuest.KillKnockedOutActor(akActor)
    EndIf
EndFunction

Function InterruptMonitorRecovery()
	If ANDR_KO_Token == None
		ANDR_KO_Token = Game.GetFormFromFile(0x807, "Death Timer - Immersive Bleedout.esp") As MiscObject
	EndIf
    If (Self.GetReference() As Actor).GetItemCount(ANDR_KO_Token) == 0
        DyingStep = 0
        UnregisterForUpdateGameTime()
        UnregisterForUpdate()										; healed in time: cancel the Death Timer
    EndIf
EndFunction

Event OnUpdateGameTime()
    Actor SelfActor = (Self.GetReference() As Actor)
	If ANDR_KO_Token == None
		ANDR_KO_Token = Game.GetFormFromFile(0x807, "Death Timer - Immersive Bleedout.esp") As MiscObject
	EndIf
    ANDR_KO_QuestScript KOQuest = GetOwningQuest() As ANDR_KO_QuestScript
    If SelfActor.GetItemCount(ANDR_KO_Token) > 0
        Float fHealth = SelfActor.GetActorValue("Health")
        Bool WasNearPlayer = SelfActor.Is3DLoaded() && SelfActor.GetDistance(Game.GetPlayer()) < 2048.0
        KOQuest.RecoverActor(SelfActor, fHealth, False)
        If !WasNearPlayer || KOQuest.IsBodyDown(SelfActor)
            ; Recovered away from the player: the stats are fixed, but the engine wasn't animating
            ; the body, so it never played its get-up and stays frozen lying down (even though every
            ; state reads normal). Wait until they're near the player, then make them get up.
            GotoState("AwaitingGetUp")
            RegisterForSingleUpdate(2.0)
            Return
        EndIf
    EndIf
    Clear()
EndEvent

Float WatchStartedAt

State AwaitingGetUp
    Event OnBeginState()
        WatchStartedAt = Utility.GetCurrentGameTime()
    EndEvent

    Event OnUpdate()
        Actor SelfActor = Self.GetReference() As Actor
        ANDR_KO_QuestScript KOQuest = GetOwningQuest() As ANDR_KO_QuestScript
        If SelfActor == None || SelfActor.IsDead()
            GotoState("")
            Clear()
            Return
        EndIf
        If SelfActor.GetItemCount(ANDR_KO_Token) > 0
            ; knocked out again while we were waiting: back to a normal recovery timer
            GotoState("")
            StartMonitorRecovery()
            Return
        EndIf
        If Utility.GetCurrentGameTime() - WatchStartedAt > 3.0
            GotoState("")
            Clear()
            Return
        EndIf
        If SelfActor.Is3DLoaded() && SelfActor.GetDistance(Game.GetPlayer()) < 2048.0
            ; The engine is animating them now. Their state can read "standing" while the body is
            ; frozen lying down, so don't trust it: always play a get-up.
            GotoState("")
            KOQuest.ForceGetUp(SelfActor)
            Clear()
            Return
        EndIf
        RegisterForSingleUpdate(3.0)
    EndEvent

    Event OnDeath(Actor akKiller)
        GotoState("")
        Clear()
    EndEvent
EndState
