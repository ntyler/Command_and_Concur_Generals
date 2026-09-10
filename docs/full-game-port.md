# Full-game request and source inventory

The requested scope is the complete Generals/Zero Hour experience: original
commands and mouse interaction, economy and match rules, combat and defensive
behaviors, AI, upgrades/prerequisites/general abilities, entry menus, map selection
and skirmish setup. The home screen must also offer manual map building and
AI-prompt map generation. This is an expansion beyond the previous visual import.

**The full game has not been ported or verified.** The current Godot controllers
still implement the prototype's rules. Copying original INI, map and window files
does not make their C++ behaviors execute in Godot. The home screen, map editor,
AI generator and complete original rules are still outstanding.

## Runtime decision needed

Two substantially different implementations are possible. Keeping the installed
original engine for matches preserves its existing behavior; a new home screen
can connect to it and the original WorldBuilder. Keeping Godot requires porting
the original simulation, command handling, UI, AI and map semantics into that
runtime. The user has been asked which runtime to use; neither route has been
silently selected. The requested home screen and map tools remain part of both
options. Any real AI generator needs a configured local model or hosted provider;
a deterministic keyword generator must not be presented as AI.

The local original-engine checkout is `D:/GitHub/CnC_Generals_Zero_Hour`.
Its README lists legacy build dependencies and missing third-party libraries.
The installed games also contain `generals.exe` and `WorldBuilder.exe`; this
inventory has not launched or validated those executables. Original online/login
services have not been tested or recreated, and an offline profile must not be
presented as authenticated online access.

## Copied game data

`tools/copy-generals-game-data.py` now copies every entry in all 32 installed BIG
archives. The completed inventory is **26,260 entries / 2,233,635,412 bytes**,
including 321 INI definitions, 171 maps, 158 window layouts, 8,582 WAV files and
56 MP3 files. Counts include both editions and archive versions. Of these,
16,944 entries were already in the previous art copy; 9,316 additional entries
are now available. Existing different local bytes are never overwritten.

All entries were read from the archives and SHA-256 compared with the local
copy. Their manifest is `assets/generals_library/data/game-data-manifest.json`.
The older art manifest/catalog remain intact. The data directory remains ignored
by Git and Godot's automatic importer. Loose installation files, executables,
external SDKs and source-code dependencies are outside this archive copy.

One patch entry is literally named `data/*`. Its original name and bytes are
preserved in the manifest, with the Windows-compatible local path `data/%2A`.
The initial copy stopped on that filename; the corrected continuation verified
all previously copied files and completed the remaining archives. The original
failure log is retained under `validation-output/full-game-port/`.

```powershell
python tools/copy-generals-game-data.py '<Generals directory>' '<Zero Hour directory>'
```

## Where the behavior is defined

Paths below are relative to `GeneralsMD/Code/` in the original source checkout.
Corresponding installed INI files are now available in the copied `inizh` archive.

| Requested system | Original implementation/data |
| --- | --- |
| Mouse commands and intent | `GameEngine/Source/GameClient/MessageStream/GUICommandTranslator.cpp`, `GameClient/Input/Mouse.cpp`; `commandbutton.ini`, `commandset.ini` |
| Simulation and match rules | `GameEngine/Source/GameLogic/System/GameLogic.cpp`; `gamedata.ini`, object definitions, weapons and armor |
| AI offense/defense | `GameEngine/Source/GameLogic/AI/AIPlayer.cpp`, AI update/state modules and object behaviors |
| Research and unlocks | Upgrade/science implementations; `upgrade.ini`, `science.ini`, command sets and object prerequisites |
| Home and skirmish setup | `GameEngine/Source/GameClient/GUI/GUICallbacks/Menus/MainMenu.cpp`, `SkirmishGameOptionsMenu.cpp`; copied WND layouts |
| Manual map editing | `Tools/WorldBuilder/src/`, including height, water, object, waypoint, player, script, open/save and settings tools |
| AI map generation | New requested feature; must create validated editable maps for the chosen runtime |

## Battleships and aircraft carriers

The Object Library now has **Dozer**, **Battleship** and **Carrier** shortcuts.
The battleship uses `avbattlesh`, while `avbattship` is another available variant;
the carrier uses `psaircarrier`. These are existing copied previews, not newly
implemented playable naval units.

The installed `AmericaVehicleBattleShip` definition in `americamiscunit.ini`
uses two turrets, `FireWeaponPower`, `SpecialPowerBattleshipBombardment`, and
`Locomotor = SET_NORMAL None`. Its command set offers bombardment and Stop.
The installed `AmericaAircraftCarrier` in `factionbuilding.ini` is an immobile
structure with `FlightDeckBehavior`, two runways, launch/landing/taxi paths,
and `AmericaJetAircraftCarrierRaptor` as its replaceable payload. Its deck
behavior is implemented in
`GameEngine/Source/GameLogic/Object/Behavior/FlightDeckBehavior.cpp`.
Freely sailing/buildable versions would extend those original definitions.

Both shortcuts were rendered and captured at 1280×800 with the repository's
external Godot watchdog. The final capture loaded both models, exited 0, and
reported no script/native errors, warnings or shutdown resource diagnostics.
Actual screenshots and logs are under `validation-output/full-game-port/`.
An initial capture's typed-array error was corrected; that failed evidence is
retained in `capture-attempt-01/` and excluded from the clean result. This is
automated viewport validation, not human playtesting or naval combat acceptance.

The prior build-area/Pause, automatic-harvesting and art-import reports retain
their original scope and evidence. Historical movement exceptions and unfinished
Tempest/superweapon functionality are not resolved by this preparation work.
