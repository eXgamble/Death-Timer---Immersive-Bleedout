# Death Timer - Immersive Bleedout

A Skyrim Special Edition / Anniversary Edition mod: your followers can die, but you get a chance
to save them first. When a follower goes down they are **unconscious and dying**, and a real-time
timer starts. Heal them in time and they get back up and thank you; let it run out and they are gone.

Essential characters and protected NPCs who aren't your followers are only **knocked out** and
recover on their own, so quests and story characters are never put at risk. With the included SKSE
plugin, named NPCs (and optionally unnamed ones, such as guards) who would have died outright to an
enemy go down dying instead, and can be saved the same way.

Built on [Andrealletius' Bleedout Revamp (ABR)](https://www.nexusmods.com/skyrimspecialedition/mods/49240)
by **Andrealletius**, reworked and expanded by **eXgamble**.

## Features

- **Two paths when an NPC falls**
  - *Dying*: followers (can be switched off in the settings), and NPCs saved from death by the SKSE plugin. A real-time Death Timer
    (default 60 s, set in the settings). No escaping it by leaving the cell or waiting.
  - *Knocked out*: essential NPCs and protected non-followers. They get back up after a few
    in-game hours and never die.
- **Rescue**: activate a downed NPC to **Give Potion** (your cheapest healing potion; food, poisons
  and, for non-vampires, blood potions are skipped), or use any healing spell.
- **They thank you**, in their own voice, using Skyrim's shared "thanks" lines (39 voice types).
- **Search** a downed NPC: hold the Modifier Key Framework modifier key (Left Shift / Left Shoulder
  by default) and the prompt switches to `Search`; activate to open their inventory.
- **Finish them yourself**: a harmful hit from you on a downed NPC kills them. It counts as your kill,
  followers included, so killing a follower is a crime, as in vanilla.
- **SKSE plugin**: named, friendly NPCs (and, with the settings option, unnamed ones) that take a fatal
  hit from anyone but you go down dying instead of dying outright. Enemies leave them alone while
  they're down. Scripted and quest deaths are never touched.
- **A wisp marks the fallen**: a glowing wisp hovers over every downed named NPC so you can find them in
  a big fight. Pale blue: knocked out. Yellow, then orange, then red (the last 20% of the time): dying.
  It has no collision, so arrows pass through and you can still reach the body. Gone once they're up
  or dead. Unnamed NPCs never get one.
- Built-in fixes: NPCs stuck in the bleedout animation can be helped up; NPCs who recover while
  you're away get up properly when you return.

### Settings

In `SKSE/Plugins/DeathTimer.ini` (no MCM needed). Read every time you load a save or start a new game:
edit the file, save it, then load.

| Setting | Default |
|---|---|
| `fRecoverHours`: in-game hours before a knocked-out NPC recovers on their own (0 = never) | 6 |
| `bFollowerDeathTimer`: followers go down dying (0: only knocked out, they recover on their own) | 1 |
| `fDeathTimerSeconds`: seconds a dying NPC has before they die unless healed (at least 10) | 60 |
| `bRescueGenericNPCs`: unnamed friendly NPCs (guards, soldiers, travellers) can be saved too | 0 |
| `bAllowNotifications`: knocked out, dying, died and potion messages | 1 |
| `bDownedWisp`: the glowing wisp over downed named NPCs | 1 |

To keep your changes safe from updates, put your copy of `DeathTimer.ini` in a separate mod that
loads after this one (MO2: lower in the left pane).

## Requirements

- [SKSE64](https://www.nexusmods.com/skyrimspecialedition/mods/30379)
- [Address Library for SKSE Plugins](https://www.nexusmods.com/skyrimspecialedition/mods/32444)
  (v13 or newer for game version 1.7.104)
- [powerofthree's Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854)
- [Spell Perk Item Distributor (SPID)](https://www.nexusmods.com/skyrimspecialedition/mods/36869)
- [Modifier Key Framework](https://www.nexusmods.com/skyrimspecialedition/mods/193566) 1.8.0 or newer (by eXgamble): the Give Potion / Search activation and the modifier key
- Optional: [FormList Manipulator](https://www.nexusmods.com/skyrimspecialedition/mods/74037)
  (CACO blood potion and Vokrii compatibility)

The SKSE plugin supports **Special Edition 1.5.97 and Anniversary Edition** (1.6.x and 1.7.x), one DLL for both
(SE 1.5.97 support is new). Do not use this together
with Andrealletius' Bleedout Revamp (this replaces it), Press E to Heal Followers or NPC Stuck in
Bleedout Fix (their features are built in).

### For other mods: the downed-state event

Whenever a downed named NPC's state changes, the SKSE plugin sends the mod event
`DeathTimer_DownedState` (sender = the NPC, `strArg` = the state, `numArg` = its number), and sends it
again after a load for everyone still down. It's sent whether or not the wisp is switched on.

| `numArg` | `strArg` | Meaning |
|---|---|---|
| 1 | `knocked_out` | knocked out, gets up on their own |
| 2 | `dying_1` | dying, the timer just started |
| 3 | `dying_2` | dying, 40% of the time gone |
| 4 | `dying_3` | dying, 80% of the time gone |
| 0 | `gone` | up again, or dead |

Papyrus: `RegisterForModEvent("DeathTimer_DownedState", "OnDownedState")`, then
`Event OnDownedState(String asEventName, String asState, Float afState, Form akNPC)`. SKSE plugins
can listen on `SKSE::GetModCallbackEventSource()`.

## Repository layout

```
mod/              the mod exactly as installed (Data-shaped): plugin, scripts + source, SEQ, DLL + its ini
skse/             source of the SKSE plugin (DeathTimer.dll)
tools/            make_wisps.py: builds the four wisp meshes and palettes from vanilla's Soul Cairn wisp
LICENSE-MOD.md    license for the mod files (ABR's terms)
skse/LICENSE      license for the SKSE plugin (GPL-3.0-or-later)
```

To install from this repository, copy the contents of `mod/` into a new mod in your mod manager
(or into `Data/`).

## Building the SKSE plugin

Requires Visual Studio 2022 or 2026 Build Tools (C++ desktop workload, which includes CMake, Ninja
and vcpkg) and Git. [CommonLibSSE-NG](https://github.com/alandtse/CommonLibSSE-NG) is a git
submodule, pinned to v10.0.0:

```
git clone --recursive <this repository>
cd skse
build.bat
```

`build.bat` opens the Visual Studio developer environment and runs `cmake --preset release` and
`cmake --build --preset release`. The first build compiles CommonLibSSE-NG and its dependencies
(10-20 minutes); after that, rebuilds take seconds. The paths to the Build Tools (in
`CMakePresets.json` and `build.bat`) and the MO2 deploy folder (`DEPLOY_DIR` in `CMakeLists.txt`)
are set for the author's machine; adjust them for yours.

## Development notes

`mod/` is the live mod: the author's MO2 mod folder is a directory junction to it
(`mklink /J "<MO2>\mods\Death Timer - Immersive Bleedout" "<repo>\mod"`), so the game runs straight
from the repository, compiled scripts and plugin builds land in it, and `git pull` updates the game.
MO2's own `mod/meta.ini` is ignored by git.

## Credits

- **Andrealletius**: [Andrealletius' Bleedout Revamp](https://www.nexusmods.com/skyrimspecialedition/mods/49240),
  the foundation of this mod (knockout system, recovery, healing detection). Giving a potion
  without the drinking animation follows the idea of Andrealletius' Papyrus Functions' CastPotion,
  now built into the SKSE plugin.
- **Bethesda**: the wisp is the Soul Cairn wisp from Dawnguard, recoloured.
- **eXgamble**: Death Timer, the two-path system, rescue and dialogue changes, SKSE plugin.
- The CommonLibSSE-NG maintainers and contributors.

## License

- Mod files in `mod/` (except the DLL): same terms as ABR. See [LICENSE-MOD.md](LICENSE-MOD.md).
- SKSE plugin (`skse/` and `mod/SKSE/Plugins/DeathTimer.dll`): GPL-3.0-or-later, because it
  statically links CommonLibSSE-NG. See [skse/LICENSE](skse/LICENSE).
