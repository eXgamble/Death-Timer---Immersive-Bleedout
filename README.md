# Death Timer - Immersive Bleedout

A Skyrim Special Edition (Anniversary Edition) mod: your followers can die, but you get a chance
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
  - *Dying*: followers (can be switched off in the MCM), and NPCs saved from death by the SKSE plugin. A real-time Death Timer
    (default 60 s, 10-300 s in the MCM). No escaping it by leaving the cell or waiting.
  - *Knocked out*: essential NPCs and protected non-followers. They get back up after a few
    in-game hours and never die.
- **Rescue**: activate a downed NPC to **Give Potion** (your cheapest healing potion; food, poisons
  and, for non-vampires, blood potions are skipped), or use any healing spell. The prompt reads
  `Give Potion +` with their name below; the `+` means a second action is available.
- **They thank you**, in their own voice, using Skyrim's shared "thanks" lines (39 voice types).
- **Search** a downed NPC: hold the Modifier Key Framework modifier key (Left Shift / Left Shoulder
  by default) and the prompt switches to `Search`; activate to open their inventory.
- **Finish them yourself**: a harmful hit from you on a downed NPC kills them (healing never does).
- **SKSE plugin**: named, friendly NPCs (and, with the MCM option, unnamed ones) that take a fatal
  hit from anyone but you go down dying instead of dying outright. Enemies leave them alone while
  they're down. Scripted and quest deaths are never touched.
- Built-in fixes: NPCs stuck in the bleedout animation can be helped up; NPCs who recover while
  you're away get up properly when you return.

### MCM

| Option | Default |
|---|---|
| Recover Hours: in-game hours before a knocked-out NPC recovers on their own (0 = never) | 6 |
| Follower Death Timer: followers go down dying (off: only knocked out, they recover on their own) | on |
| Time Until Death: seconds a dying NPC has before they die unless healed | 60 |
| Rescue Generic NPCs: unnamed friendly NPCs (guards, soldiers, travellers) can be saved too | off |
| Use Notifications | on |

## Requirements

- [SKSE64](https://www.nexusmods.com/skyrimspecialedition/mods/30379)
- [Address Library for SKSE Plugins](https://www.nexusmods.com/skyrimspecialedition/mods/32444)
  (v13 or newer for game version 1.7.104)
- [SkyUI](https://www.nexusmods.com/skyrimspecialedition/mods/12604)
- [MCM Helper](https://www.nexusmods.com/skyrimspecialedition/mods/53000)
- [powerofthree's Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854)
- [Spell Perk Item Distributor (SPID)](https://www.nexusmods.com/skyrimspecialedition/mods/36869)
- [Modifier Key Framework](https://www.nexusmods.com/skyrimspecialedition/mods/193566) (by eXgamble): the Give Potion / Search activation and the modifier key
- [Andrealletius' Papyrus Functions](https://www.nexusmods.com/skyrimspecialedition/mods/85252)
- Optional: [FormList Manipulator](https://www.nexusmods.com/skyrimspecialedition/mods/74037)
  (CACO blood potion and Vokrii compatibility)

The SKSE plugin supports **Anniversary Edition only** (1.6.x and 1.7.x). Do not use this together
with Andrealletius' Bleedout Revamp (this replaces it), Press E to Heal Followers or NPC Stuck in
Bleedout Fix (their features are built in).

## Repository layout

```
mod/              the mod exactly as installed (Data-shaped): plugin, scripts + source, MCM, SEQ, DLL
skse/             source of the SKSE plugin (DeathTimer.dll)
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
  the foundation of this mod (knockout system, recovery, healing detection), and Andrealletius'
  Papyrus Functions.
- **eXgamble**: Death Timer, the two-path system, rescue and dialogue changes, SKSE plugin.
- The CommonLibSSE-NG maintainers and contributors.

## License

- Mod files in `mod/` (except the DLL): same terms as ABR. See [LICENSE-MOD.md](LICENSE-MOD.md).
- SKSE plugin (`skse/` and `mod/SKSE/Plugins/DeathTimer.dll`): GPL-3.0-or-later, because it
  statically links CommonLibSSE-NG. See [skse/LICENSE](skse/LICENSE).
