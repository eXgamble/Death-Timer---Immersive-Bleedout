Scriptname DeathTimer Hidden
{Native functions from the DeathTimer SKSE plugin (SKSE\Plugins\DeathTimer.dll).}

; Protected on this one NPC in the world, not on their NPC record (unnamed NPCs share a record).
; Enemies leave a protected NPC alone; the player can still kill them.
Function SetDownedProtection(Actor akActor, Bool abProtected) global native

; Time Until Death (fDeathTimerSeconds in SKSE\Plugins\DeathTimer.ini): real-time seconds a dying NPC has.
Float Function GetDeathTimerSeconds() global native

; akTarget takes akPotion's effects as if it drank it, without the drinking animation (so
; animated-potion mods stay out of it), blamed on akSource. Does not move the potion: remove it first.
Function CastPotion(Actor akSource, Potion akPotion, Actor akTarget) global native

; A downed named NPC's state, for the glowing wisp over them (bDownedWisp in DeathTimer.ini) and the mod event
; "DeathTimer_DownedState" (sender = the NPC, strArg/numArg = the state): 1 knocked out, 2 dying (yellow),
; 3 dying (orange), 4 dying (red), 0 no longer down. The plugin notices rescue and death by itself. Unnamed NPCs are ignored.
Function SetDownedState(Actor akActor, Int aiState) global native
