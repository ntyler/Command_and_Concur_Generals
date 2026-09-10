# Generals object library and gameplay visuals

The local library contains **16,944 copied archive entries (1,096,291,183 bytes)**:
9,000 W3D files, 7,111 DDS textures, 780 TGA textures and 53 object-definition INI
files. The definitions contain 2,997 Object/ChildObject records across both games;
these counts include variants and duplicate definitions, not 2,997 new playable
unit types. Every copied entry was read back and SHA-256 verified.

The source is the user's installed Generals and Zero Hour game data. The separate
`CnC_Generals_Zero_Hour` engine-source checkout contains no complete art library.
Game art retains its original provenance; this import does not relicense it.

## Browse the objects

Open `scenes/generals_asset_browser.tscn` in Godot and press **F6**, or run:

```powershell
& '<Godot executable>' --path . res://scenes/generals_asset_browser.tscn
```

Search by model name or original object name, select an entry, drag to orbit,
and scroll to zoom. The catalog includes **7,671 static 3D previews** and **1,230
source-only entries**. Enable the source-file checkbox to see standalone animation,
hierarchy and non-renderable files. Across archive versions there are 9,000 W3D
files; the catalog resolves these to 8,901 names, favoring Zero Hour, then patch
and language archives. Every original version remains in the source copy.

The bulk source and preview files live under `assets/generals_library/data/`.
They are local, ignored by Git and excluded from Godot's automatic import scan
and the repository's fresh-copy validation snapshots. The browser loads these
GLBs directly. The smaller gameplay selection, catalog and import tools belong
to the repository and work independently of that bulk source directory.

## Gameplay mapping

Only art is imported. Existing controllers still own production, prices, health,
movement, collision, selection, harvesting, construction, power and targeting.
The model roots contain no collision objects or gameplay scripts. Visuals are
fitted to existing dimensions. Team panels receive per-instance team materials.
The Ranger's texture-based team panel follows ownership too. Unit damage flashes
reach nested model meshes and restore the original materials after the flash.

| Existing object | Imported visual |
| --- | --- |
| Basic movement-test unit | US Crusader (`AVCrusader`) |
| Rifle unit | Included Ranger (`AIRngr_SKN`), first standing-animation frame |
| Rocket vehicle | US Tomahawk (`AVTomahawk`) |
| Collector truck | China supply truck (`NVSSUPPLYTK`), preserving ground collection |
| Bulldozer | Previously imported US dozer (`AVCONSTDOZ_A`), unchanged |
| Attack helicopter | US Comanche (`AVComanche`), with the existing main-rotor spin |
| Headquarters | US Command Center (`ABBtCmdHQ`) |
| Barracks | US Barracks (`ABBarracks`) |
| Vehicle factory | US War Factory (`ABWarFact`) |
| Supply depot | US Supply Center (`ABSupplyCT`) |
| Power plant | US power plant (`ABPwrPlant`) |
| Airfield | US Airfield (`ABArFrcCmd`) |
| Ground defense | China Gatling Cannon (`NBGattling`) |
| Air defense | US Patriot (`ABPatriot`) |
| Walls and gate panels/supports | US security-wall pieces (`ABSecWallY` / `ABSecWallX`) |
| Supply cache goods | Small supply pile (`ZBSmalPile`) |

The two defense models use the existing turret controllers and muzzle locations.
The gate's original security-wall panel follows the existing committed open/closed
state; it does not implement a new gate mechanic. Supply goods still disappear on
depletion while their collider remains. Recipe scenes still contain only their
controllers before initialization, preserving production admission.

## Conversion scope and source limitations

Previews retain geometry, normals, UVs, texture pixels, face materials and static
hierarchy/bone placement. Reflective models use their UV-mapped body texture;
the old environment-reflection pass is not used as their body skin. Alpha-tested
surfaces are retained. DDS/TGA images are embedded as PNGs in GLB files.

These are **static previews**, not a port of the W3D renderer or the original
object behaviors. Animations, particles, visibility-state changes, extra material
passes and texture-stage effects remain in the original files. Standalone effect
geometry has an explicit preview note. `prg01` contains no standalone visible
geometry, and five original files have unparseable chunk data; their byte-for-byte
copies remain available.

33 previews contained non-finite source UV coordinates. Those coordinates are
replaced with zero in the preview and flagged in the catalog; original files
remain unchanged.

**109 library previews reference textures absent from the installed archives**;
each affected entry lists the missing names. None of the 16 new gameplay models
has a missing-texture diagnostic. The installation's Ranger is the robot-style
variant using `ZHCA_AIRanger`; its appearance is preserved rather than replaced
with invented art. Most other skinned library models display their bind pose.

This import does not add all original units as playable recipes, restore original
animations or complete the Tempest/superweapon facility. Previous milestone and
build-area/Pause reports describe their own saved validation and remain separate.

## Rebuild

Python requires numpy and Pillow. No Blender installation is required.

```powershell
python tools/copy-generals-assets.py '<Generals directory>' '<Zero Hour directory>'
python tools/import-generals-library.py
```

The source folders must contain their original BIG archives. Copying refuses to
overwrite different local source bytes. The full manifest is
`assets/generals_library/data/manifest.json`; the browser catalog is
`assets/generals_library/catalog.json`. `assets/generals/source.json` records the
gameplay mappings, source/output hashes, bounds and conversion notes. The earlier
dozer retains its separate importer and provenance file.

## Saved validation

The accepted coverage is **26 executions, 4,749 checks, zero failures**:
13 headless executions / 2,358 checks and 13 graphical executions / 2,391 checks.
All accepted executions exited normally with no native errors, warnings, timeout,
or unresolved runtime resources reported at shutdown. These were automated
viewport tests, not human playtesting.

| Suite (`tests/<name>.gd`) | Headless checks | Graphical checks |
| --- | ---: | ---: |
| `generals_asset_checks` | 70 | 70 |
| `combat_checks` | 183 | 191 |
| `air_combat_checks` | 85 | 85 |
| `air_production_checks` | 96 | 96 |
| `builder_checks` | 316 | 325 |
| `pause_checks` | 135 | 139 |
| `production_checks` | 192 | 193 |
| `vehicle_production_checks` | 225 | 230 |
| `harvesting_checks` | 299 | 300 |
| `automatic_harvesting_checks` | 100 | 101 |
| `defense_checks` | 228 | 229 |
| `fortification_checks` | 158 | 158 |
| `construction_checks` | 271 | 274 |

Evidence lives in `validation-output/generals-library/validation-summary.json`.
It records every selected execution, log hash, source difference, exact changed
file, screenshot hash and earlier failed iteration. The first six suites above
use `validation-output/m8/generals-feedback-{headless,graphical}-20260909`:
12 executions / 1,791 checks on the final gameplay source. Only the subsequently
validated browser, documentation and newly generated UID sidecars differ.
The other seven suites retain 14 clean executions / 2,958 checks from
`generals-visuals-final-{headless,graphical}-20260909`. Those broader snapshots
predate the final rotor, material-lifecycle and feedback fixes; the first six
suites directly validate those changes. This is reconciled coverage across
saved snapshots, not a claim that one full matrix ran on identical final bytes.

The new 70-check asset regression covers all 16 model mappings, finite/fitted
bounds, absence of imported scripts/collision, isolated team materials,
construction tint restoration followed by immediate teardown, real defense
weapon initialization, the original helicopter rotor parts, nested damage and
ownership feedback, and existing production-recipe admission. Earlier iterations
exposed a typed-array initialization error and a native material-null error
on immediate teardown; both were corrected and their failing logs retained.
The browser's final capture also corrected an invalid selection API call; its
failed capture is retained separately under `browser-selection-failed/`.

The independent GLB audit checked **7,671 previews / 2,055,545 triangles** with
zero remaining binary, bounds, finite-attribute, material-reference or hash
errors. Final browser capture loaded seven distinct originals successfully:
the dozer, Ranger, Command Center, Comanche, War Factory, Palace and Propaganda
Center. Their actual 1280×800 viewport PNGs are in
`validation-output/generals-library/screenshots/`. Together with accepted
gameplay captures, the report contains **45 PNG files / 42 distinct images**.
The main-project editor import and final browser capture exited cleanly.

Local Markdown link/heading and text-whitespace checks passed, as did
`git diff --check`. Automatic-harvesting checks here guard compatibility of its
new truck visual; commit `4448e3c` and its gameplay behavior remain separate
baseline work. Historical movement exceptions and unfinished Tempest/superweapon
functionality are not claimed as fixed or completed by this import.
