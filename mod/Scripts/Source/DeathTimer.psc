Scriptname DeathTimer Hidden
{Native functions from the DeathTimer SKSE plugin (SKSE\Plugins\DeathTimer.dll).}

; Protected on this one NPC in the world, not on their NPC record (unnamed NPCs share a record).
; Enemies leave a protected NPC alone; the player can still kill them.
Function SetDownedProtection(Actor akActor, Bool abProtected) global native
