# Milestone 6 — playable base assault

2026-09-07. The integrated base-assault scene is implemented. Its focused automated feature checks pass in headless and graphical modes. All 42 post-change test executions pass; detailed results are recorded below. **Movement limitations remain deferred and unresolved; full movement/Milestone 5 regression acceptance has not passed.**

## Play

Open `scenes/base_assault.tscn` in Godot and press **F6**. From the repository root, the exact installed engine can also launch it directly:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/base_assault.tscn
```

F5 still opens the original movement field. Earlier production, harvesting, construction and combat scenes retain their defaults, including invulnerable legacy buildings.

The mint player starts with an HQ, three Rifles, two collectors, 1000 credits and no barracks. Two caches each contain 2000 supplies. The coral side has an HQ and three Rifles. Both HQs have 1200 HP; completed barracks have 450 HP. After 90 simulated seconds, each surviving enemy Rifle receives one ordinary Attack order against the player's HQ. Failed or replaced orders are not continuously reset, and no enemy economy, waves or strategic AI are added.

The construction field's bounds, protected access corridors, caches and obstacles are reused. The enemy HQ occupies `Rect2(16.5, -15, 7, 6)`, centered at `(20, 0, -12)`. Ordinary barracks placements include `(-12, 0, 3)` and `(-3, 0, 16)` when their full clearance/exit areas are unoccupied.

| Control | Behavior |
| --- | --- |
| WASD/arrows/edges, wheel | Existing camera pan and zoom |
| Click/drag/Shift | Existing owned-unit selection |
| Select owned HQ → Build Barracks | Existing 400-credit, 10-second construction after navigation readiness |
| Left click valid preview / right click or Escape | Place the paid site / cancel free placement |
| Select unfinished site → Cancel construction | Existing full captured refund and serialized navigation cleanup |
| Collector + right click supplies / owned HQ | Automatic harvesting / manual return and deposit of carried supplies |
| Select completed barracks → Train / Cancel | Existing Rifle queue, 100 credits and five seconds per Rifle; cancel undeployed jobs |
| Selected barracks + right click ground | Existing rally point for future deployments |
| Combat units + right click hostile unit/HQ/completed barracks | Attack using existing pursuit, facing, cooldown and obstruction rules |
| Units + right click ground / X | Move / Stop; collectors keep undeposited cargo |
| Restart on result screen | Fresh scene with initial units, health, funds, supplies and empty work |

Enemy-HQ destruction produces **VICTORY**, player-HQ destruction **DEFEAT**, and destruction of both in the same physics tick **DRAW**. The result overlay stops gameplay and keeps Restart usable. Building identity and HP are presented together on separate text lines. Normal debugging remains off by default.

## Implementation and lifecycle

`BaseAssaultField` extends `ConstructionField`. It adds the enemy footprint before initial navigation generation and opts registered HQs/barracks into the existing `UnitHealth` authority. Unfinished sites retain immunity and their prior cancellation rules; completion enables damage without resetting health. Legacy buildings have no health component unless explicitly enabled.

Combat accepts a world actor target while retaining the existing unit-only `target_unit()` accessor; `target_actor()` serves both units and buildings. `TeamRules` still owns hostile membership/damage authorization, including live building membership in the same field. Friendly, dead, detached, freed and foreign-field targets reject. Collectors remain unarmed, and the owned-HQ input branch still deposits cargo. Existing all-or-rejected combat batch prevalidation and historical acceptance/supersession semantics remain intact.

Rifle lines and Rocket flight exclude only the intended building's RID. Attachment and launch-volume checks retain their original blocker policy, and intervening solids still obstruct both weapons. Ordinary line/sphere queries reset their exclusion arrays and continue to see that same building as an obstacle. Rockets retain their original point aim/arrival model, swept spherical world collision, lifetime and damage; no second damage implementation or weapon recipe was introduced. Building pursuit uses the existing center-based range and ordinary projected navigation path, which stays outside the supported HQ/barracks footprints.

Lethal health commits building unavailability, disabled collision and queued deletion before notifications. Destruction silently retires field membership/production, erases the authoritative construction-site or fixed-HQ rectangle, and requests the existing serialized navigation update before publishing producer/selection changes. Undeployed jobs use `UnitProduction.close(true)` to return their captured payment once; already deployed units survive and do not refund. Completed buildings never return their construction cost. Removing a completed site during another site's preparation updates the latter's navigation generation. A repeated damage/cleanup request cannot manufacture another loss or refund.

HQ loss is recorded before cleanup callbacks. A resolver at physics priority 1000 runs after the ordinary combat/projectile nodes and commits one result for that tick. It closes gameplay command/economy/damage admission, halts and disables actors, and presents the result. Only navigation cleanup already committed by destruction continues; construction timers, production, harvesting, combat, new commands and the match clock stop. The result notification occurs after state is coherent.

Restart uses Godot's normal `change_scene_to_file` lifecycle. Old wallets, producers and construction/navigation coordinators close during teardown; delayed calls on retained old coordinators cannot affect the replacement scene. There are no new autoloads or global match state.

## Requirement acceptance

These are automated feature results, not a claim of universal movement reliability or human playtesting.

| Saved requirement | Result | Evidence |
| --- | --- | --- |
| 1. Player base/collectors/supplies/small force without barracks; enemy HQ/force; earlier scenes available | PASS | Fresh-scene checks, actual scene load and rendered initial state; prior suites run unchanged |
| 2. Construction → harvesting/deposit → earned-credit Rifle production → deployment/rally/attack | PASS | Full loop uses default starting funds, real construction, real trips and real timed deployments |
| 3. Damageable HQs/completed barracks, readable HP, building input, collector/deposit behavior, safe rejection | PASS | Viewport hostile/owned-HQ clicks, real manual deposit, unfinished/legacy immunity, hostile membership/departure/freed-reference checks; captured UI inspected |
| 4. Rifle/Rocket targeting, obstruction and ordinary pursuit | PASS | Actual building damage with both weapons; intervening wall blocks Rifle and Rocket launches and intercepts an in-flight Rocket; default queries still see the target body |
| 5. Destruction, geometry/production cleanup, captured refunds, callbacks and navigation updates | PASS | One already deployed Rifle survives; one undeployed job refunds once; completed cost does not refund; another preparing site's map becomes ready; reentrant close and scene removal complete safely |
| 6. One scripted enemy assault | PASS | Configured 0.25-second preparation fixture issues three ordinary attacks and destroys the full-health player HQ; no repeated dispatch |
| 7. Victory/defeat/draw, gameplay stop and clean Restart | PASS | Actual earned-army victory, actual enemy-assault defeat, both same-tick damage orders yield one draw, frozen-state/API checks and viewport Restart |
| Human keyboard-and-mouse playtest | UNVERIFIED / NOT PERFORMED | Automated viewport input and captured-frame inspection only |

The integrated loop does **not** grant test credits, relocate actors, directly spawn the required army or set a result flag. It pays 400 for construction and trains six real Rifles using the remaining starting 600. A seventh request rejects at zero credits. A collector then travels, loads, returns and unloads; those earned credits buy and deploy the seventh Rifle. The seven produced units accept and complete a group staging move to `(12, 0, -5)`, then attack and destroy the enemy HQ. The earned-credit Rifle commits actual shots. The test verifies the visible result, stopped gameplay, restored HQ navigation and a real Restart-button click into the default fresh scene.

Separate weapon tests use explicitly positioned fixtures and an existing Rocket configuration; separate draw tests apply real lethal health damage through `TeamRules` in one tick. These focused fixtures are not substitutes for the full default-scene gameplay loop.

## Validation execution and evidence

Starting revision: `101370f`, with a clean working tree. No applicable `AGENTS.md` was found in the repository or its ancestors. The saved specification, README, roadmap and movement issue records were read. No commit/tag, engine upgrade or project dependency installation was performed. PowerShell 7 was initially unavailable on PATH/in the usual installation locations, while the session shell was Windows PowerShell 5.1. The user explicitly authorized installation. Following [Microsoft's installation instructions](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows), WinGet installed **PowerShell 7.6.5**, verified before baseline execution; Godot remains **4.7.2.stable.official.ed1daf0bf**. A broader filesystem search also returned a bundled runtime at `C:\Users\Tyler\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe`; that copy was not used. All recorded validation used the newly installed 7.6.5 runtime.

Both ordinary matrices run through the unchanged `tools/run-godot.ps1`, using isolated copies of the current source under `validation-output/m6/baseline/project` and `validation-output/m6/post/project`. Each phase retains its source hashes, starting diff/revision, individual `.ps1` invocation, wrapper log, exact argument arrays/exit/timing in `results.json`, and artifacts written by each execution. This keeps fixed test output paths away from earlier evidence. The task-local invocation list reuses the existing tests, wrapper and assertion harness; it adds no new recording or historical replay system.

The exact orchestration commands were:

```powershell
python validation-output\m6\run_matrix.py baseline 'C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.5.0_x64__8wekyb3d8bbwe\pwsh.exe'
python validation-output\m6\run_matrix.py feature-1 'C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.5.0_x64__8wekyb3d8bbwe\pwsh.exe' base_assault_checks
python validation-output\m6\run_matrix.py feature-2 'C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.5.0_x64__8wekyb3d8bbwe\pwsh.exe' base_assault_checks
python validation-output\m6\run_matrix.py post 'C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.5.0_x64__8wekyb3d8bbwe\pwsh.exe'
```

Every generated invocation calls the existing wrapper with `-ProjectPath` set to that copied project. For example, the post-change feature check is:

```powershell
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath 'D:\GitHub\Command_and_Concur_Generals\validation-output\m6\post\project' -GodotArguments @('--headless', '--path', 'D:\GitHub\Command_and_Concur_Generals\validation-output\m6\post\project', '--fixed-fps', '60', '--script', 'res://tests/base_assault_checks.gd')
```

The graphical command omits `--headless`. Each phase also imports with `--headless --path <copied-project> --editor --import`. Gate checks include both the default disabled-avoidance case and `-- --avoidance`; load checks use `combat_checks.gd -- --combat-load`. There are no closed historical replay/continuous-recorder runs. Complete executed commands are in [baseline results](../validation-output/m6/baseline/results.json), [first feature results](../validation-output/m6/feature-1/results.json), [expanded feature results](../validation-output/m6/feature-2/results.json) and [post-change results](../validation-output/m6/post/results.json).

Baseline completed 40 test executions: **39 passed, one failed**, plus a successful import. The failed graphical full movement sequence reports **131 checks / 3 failures**: unit 18 in `choke_30`, accepted destination `(6, 0, -1.5)`, stopped near `(-2.85, 0, -1.889122)` after eight recoveries. Arrival, group gate traversal and settling failed. The baseline contains 4,846 assertions and three failures. Its occurrence before M6 edits is established by the saved source; its relationship to earlier movement mechanisms is unknown. No retry was used to replace that result.

The first feature implementation passed **109 headless / 115 graphical** checks. Rendered inspection found overlapping building name/health labels; they were combined into separate lines in one label. Focused coverage was completed for Rocket world interception/blocked launches, owned-HQ viewport deposit and the distinction between deployed/undeployed destruction refunds. The updated feature suite passed **124 headless / 130 graphical** checks, with zero native errors/warnings; both feature phases also passed the existing combat-load checks.

An initial root editor import produced warnings about archived source/CSV evidence being scanned as assets. The following initial smoke run failed on duplicate global `RTSUnit` classes and consequential scene errors, even though Godot returned exit 0. This is a **failed validation execution**, not a pass. A local ignored `validation-output/.gdignore` now prevents evidence archives being imported as game assets; the files remain available on disk. Reimport and the next smoke run were clean. Logs `import-1.log`, `scene-smoke-1.log`, `import-2.log` and `scene-smoke-2.log` are retained under `validation-output/m6/`. A final root-source smoke also passed cleanly in `scene-smoke-final.log`. All three smoke invocations used `--headless --path . res://scenes/base_assault.tscn --quit-after 120` through the wrapper. No movement change or historical investigation was involved.

The outer post-matrix runner ended before writing its graphical harvesting result row. The child wrapper nevertheless completed with **299 checks / zero failures / exit 0**, retained in its original log. No engine process remained running. That completed result was recovered without rerunning it; exact outer start/timing for that row is unavailable and marked accordingly. `python validation-output\m6\finish_post.py` then executed only the eight remaining graphical commands, on the same frozen source copy through the same wrapper. Completed tests were not repeated or overwritten. The outer-runner interruption has no established cause and is not classified as a gameplay regression.

[Source preservation checks](../validation-output/m6/preservation-check.json) verify all **96** pre-existing tracked test/tool files and protected movement/group-assignment/construction-navigation files in that selected set are unchanged from baseline. All **187** gameplay/test/scene/config/tool files represented in the post snapshot match the final working implementation. `scripts/rts_unit.gd` remains SHA-256 `2f46d67b3267ab233405457f8c84e83ebc46b8f461e75deef46ee5c3f33b34d0`; no existing test assertion or validated mover/projection function was edited.

Post-change matrix: **42/42 test executions passed, plus a clean import; 5,100 assertions and zero failures.** The final feature checks pass **124 headless / 130 graphical**, with zero native errors/warnings. The ordinary movement stress sequence passes **122 headless / 131 graphical** in this matrix. This does not resolve the retained earlier baseline failure or establish full movement acceptance.

| Suite (checks / failures) | Baseline headless | Baseline graphical | Post headless | Post graphical |
| --- | ---: | ---: | ---: | ---: |
| `milestone_checks.gd` | 127 / 0 | 131 / 0 | 127 / 0 | 131 / 0 |
| `movement_repair_checks.gd` | 82 / 0 | 82 / 0 | 82 / 0 | 82 / 0 |
| `parked_deadlock_checks.gd` | 14 / 0 | 14 / 0 | 14 / 0 | 14 / 0 |
| `parked_deadlock_controls.gd` | 84 / 0 | 84 / 0 | 84 / 0 | 84 / 0 |
| `captured_parked_cluster_checks.gd` | 10 / 0 | 10 / 0 | 10 / 0 | 10 / 0 |
| `projection_step_checks.gd` | 32 / 0 | 32 / 0 | 32 / 0 | 32 / 0 |
| `boundary_neighbor_checks.gd` | 23 / 0 | 23 / 0 | 23 / 0 | 23 / 0 |
| `boundary_neighbor_controls.gd` | 193 / 0 | 193 / 0 | 193 / 0 | 193 / 0 |
| `gate_movement_checks.gd` | 14 / 0 | 14 / 0 | 14 / 0 | 14 / 0 |
| `gate_movement_checks.gd -- --avoidance` | 39 / 0 | 39 / 0 | 39 / 0 | 39 / 0 |
| `construction_checks.gd` | 267 / 0 | 270 / 0 | 267 / 0 | 270 / 0 |
| `construction_cleanup_checks.gd` | 46 / 0 | 46 / 0 | 46 / 0 | 46 / 0 |
| `harvesting_checks.gd` | 298 / 0 | 299 / 0 | 298 / 0 | 299 / 0 |
| `production_checks.gd` | 192 / 0 | 193 / 0 | 192 / 0 | 193 / 0 |
| `combat_checks.gd` | 183 / 0 | 191 / 0 | 183 / 0 | 191 / 0 |
| `combat_repair_checks.gd` | 230 / 0 | 230 / 0 | 230 / 0 | 230 / 0 |
| `line_of_fire_checks.gd` | 305 / 0 | 308 / 0 | 305 / 0 | 308 / 0 |
| `spherical_projectile_checks.gd` | 140 / 0 | 141 / 0 | 140 / 0 | 141 / 0 |
| `movement_stress_checks.gd` | 122 / 0 | 131 / 3 | 122 / 0 | 131 / 0 |
| `base_assault_checks.gd` | Not yet implemented | Not yet implemented | 124 / 0 | 130 / 0 |
| `combat_checks.gd -- --combat-load` | 7 / 0 | 7 / 0 | 7 / 0 | 7 / 0 |

`git diff --check` and local documentation-link validation pass. Final screenshots include initial state, deployed army, victory, defeat, draw and the restarted scene; representative captures were visually inspected. No human keyboard-and-mouse playtest occurred.

## Files and remaining limits

| Files | Change |
| --- | --- |
| `scenes/base_assault.tscn`, `scripts/base_assault_field.gd` | Scenario, enemy base, opt-in health/configuration, one assault, result resolver/HUD and Restart |
| `scripts/rts_building.gd`, `scripts/health.gd` | Opt-in building health/presentation, terminal destruction/departure and damage admission |
| `scripts/team_rules.gd`, `scripts/combat_controller.gd`, `scripts/weapon_emitter.gd`, `scripts/guided_projectile.gd`, `scripts/line_of_fire.gd` | Shared unit/building targeting, membership/damage rules and target-specific collision exclusion |
| `scripts/selection_controller.gd`, `scripts/test_field.gd` | Building Attack input and scene-local command admission |
| `scripts/production_field.gd`, `scripts/construction_field.gd`, `scripts/building_construction.gd`, `scripts/unit_production.gd`, `scripts/harvest_field.gd` | Destruction retirement/navigation, captured queue refunds and match-end work admission |
| `tests/base_assault_checks.gd` | Focused feature and actual integrated loop checks using the existing harness |
| README, roadmap, movement issue records and this report | Launch/controls, implementation status, retained baseline failure and acceptance evidence |

Known movement issues, including original Issue B/unit 4, historical unit 41, unit 13 causal questions, the earlier graphical unit-23 gate failure and this starting-source unit-18 failure, remain **deferred/unresolved**, separately recorded in [movement issue records](movement-issue-records.md). No movement investigation, historical comparison/replay, recorder expansion, solver tuning or movement repair was performed for M6.

Supported scope remains a small flat map, original primitive units/buildings, fixed building footprints, one unfinished site and bounded local movement/spawn/access behavior. Unfinished sites cannot be attacked, buildings cannot fire, and there is no automatic firing-position search, attack-move, strategic AI, builder unit, repair/capture/sale, new production recipe, power, technology, fog, multiplayer or persistence. The scenario has not received a human playtest, balance study, varied-terrain test or large-crowd guarantee. No Milestone 7 work follows this handoff.
