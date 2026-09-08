# Milestone 7 — Vehicle Factory and Rocket Vehicle production

2026-09-07. Implements the user's saved Vehicle Factory scope on Milestone 6 commit `682c8c1`. The completion pass began with the feature already committed at `643099f` and a clean working tree; it audited that implementation and completed the unfinished validation handoff. **Milestone 7 feature checks pass headlessly and graphically.** Deferred movement failures remain **unresolved**; full movement/Milestone 5 acceptance has not passed.

## Play and configuration

Open `scenes/combined_arms_assault.tscn` in Godot and press **F6**, or launch from the repository root:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/combined_arms_assault.tscn
```

F5 and every earlier scene retain their defaults. The new scene configures the existing `BaseAssaultField`; it does not duplicate its map, economy, assault script or result controller. Initial state remains two 1200-HP HQs, three Rifles per side, two player collectors, two 2000-supply caches, 1000 player credits and no player production buildings. The original enemy assault dispatches once after 90 simulated seconds.

Select the owned HQ to choose **Build Barracks** or **Build Vehicle Factory**. A factory needs no barracks prerequisite. Left-click valid ground to pay/place; right-click or Escape cancels the free preview. Select an unfinished site to cancel for its original full construction payment. Only one unfinished building is allowed across both types, including navigation preparation and cancellation cleanup. The normal example centers `(-12, 0, 3)` and `(-3, 0, 16)` fit both structures when clear of units.

| Configuration | Barracks (unchanged) | Vehicle Factory |
| --- | --- | --- |
| Construction resource | `construction/barracks.tres` | `construction/vehicle_factory.tres` |
| Cost / simulated build duration | 400 / 10 seconds | 600 / 15 seconds |
| Footprint / height | 6 × 5 / 2.6 | 6 × 5 / 2.8 |
| Completed health in assault | 450 | 450; same existing `barracks_health` setting |
| Recipe | Rifle Unit | Rocket Vehicle |
| Production resource | `production/rifle.tres` | `production/rocket_vehicle.tres` |
| Cost / simulated training duration | 100 / 5 seconds | 250 / 8 seconds |
| Queue capacity / blocked retry | 5 / 0.25 seconds | 5 / 0.25 seconds |

The factory has a blue-gray body, broad garage door and raised gold roof rails. Its name, construction progress and completed HP use the normal building presentation. Select a completed building to train its supported type, inspect FIFO progress/queue, or cancel an undeployed job. Right-click ground with that building selected changes the rally for future deployments. **Exit blocked** holds a completed paid job at 100% until a bounded local retry finds safe space.

Collectors plus right-click supplies use actual harvesting/deposits. Select deployed units and right-click ground to Move or a hostile unit/building to Attack. **X** stops units; **S** remains camera pan. Existing click/drag/Shift selection, wheel zoom and GUI input consumption remain. Destroy the coral HQ and protect the mint HQ. HQ losses produce **VICTORY**, **DEFEAT**, or **DRAW** when both die in the same physics tick. The result freezes gameplay and **Restart** reloads a clean combined-arms match. Destroying a factory does not end the match.

## Shared systems and lifecycle

`ConstructionDefinition.kind` admits the two fixed-footprint production types. `ConstructionField.vehicle_factory_definition` is opt-in and null in earlier scenes. Placement captures the selected definition and uses the existing geometry, funds, navigation readiness, timing, single-site and cancellation path. The same site collider/footprint remains authoritative through completion. Construction creates the corresponding ordinary building/recipe before registration. There is no second construction or production coordinator.

`RTSBuilding.supports_recipe()` checks producer kind and recipe identity; `ProductionDefinition.is_valid()` checks the normal RTSUnit script, no extra child scripts, unit scale, speed, original weapon and health. Unsupported/cross-type recipes, invalid scene data, wrong ownership and unavailable producers cannot debit or mutate queues. A factory's ordinary `UnitProduction` captures payment, duration, scene, label and collision shape per accepted job. Shared definitions do not share mutable queue/progress state. Existing FIFO, cancellation, notification ordering, registration-before-exposure and exactly-once deployment commits remain.

`scenes/rocket_vehicle.tscn` composes the same RTSUnit and `weapons/rocket.tres` used by the earlier combat scene: 150 HP, speed 5, damage 32, range 11, cooldown 1.8 seconds, guided speed 9, lifetime 6 seconds and spherical projectile radius 0.1. No weapon resource, unit mover, combat controller, projectile, collision dimension or repair was retuned. Both supported RTSUnit configurations currently use the same physical capsule (radius 0.43, height 1.3); their visual silhouettes differ. At acceptance, deployment reads the produced scene's unit's authoritative `body_shape()` factory, which its ordinary `_ready()` also uses. Spawn queries and same-tick claims use that captured shape's dimensions. They do not infer collision from the Rifle visual. The supported body remains a capsule centered at half its height.

Deployment retains the existing six local candidates, exact on-nav points, direct local path requirement, full-volume world/unit overlap rejection and same-tick claims. No point is projected through a wall, and no blocker is moved. A blocked head includes a queue slot, does not retrain or debit, and prevents later jobs progressing. Current rally is captured only at deployment and uses ordinary movement; rejected rally leaves the paid unit idle. Existing selection/orders remain intact.

Completed factories use the M6 health/destruction path. Lethal damage immediately ends producer eligibility, removes selection/registration/collision and the authoritative footprint, requests existing navigation cleanup, then closes the queue. **All paid undeployed jobs, including completed-but-blocked jobs, receive their captured full payment exactly once. Completed construction cost never refunds.** Deployed units and already-fired projectiles remain independent of the factory; source/target death retains the original weak-reference flight rules.

M6 result handling freezes factory construction, training, deployment, units and projectiles through its existing gameplay/lifetime gates. `BaseAssaultField.restart_scene` defaults to the original scene; the new scene supplies its own path. Restart closes old wallets/coordinators/queues and destroys old factories, previews, projectiles and registries. Late callbacks cannot affect the replacement match. The placement entry point now accepts a stale HQ reference at its public boundary so existing `can_begin()` validation rejects it safely after defeat; no movement change was involved.

## Automated acceptance

`tests/vehicle_production_checks.gd` extends the existing M6/construction harness. It uses real physics, navigation, viewport input, the inherited wall watchdog and native-error probe. Isolated accounting, collision and death fixtures are separate from `_combined_loop()`.

The integrated fixture starts through supported configuration at **zero credits**, with the original units/resources. Its documented automated budget allows **600 seconds before the scripted assault**, at most **240 simulated seconds for earning/construction/production**, 25 seconds for staging and 45 seconds for final combat. This is a test-only configuration; playable defaults remain **1000 credits / 90 seconds**, separately verified by `_default_assault_timing()`, including actual enemy destruction of the undefended HQ. No credits, army, victory signal or result flags are injected into the integrated sequence.

The loop commands both existing collectors, earns construction funds, builds the factory via viewport input, constructs a barracks, and purchases four Rifles and two Rockets through actual UI-driven timed queues. Spending totals **1900 earned credits**: 600 + 400 + 4×100 + 2×250. Ordinary group movement stages the army; both types inflict real HQ damage, normal HQ death produces visible victory, and a viewport Restart restores the playable initial match. Supply/cargo/deposit accounting is observed through existing transfer signals; no cache is replenished.

| Requirement | Status / evidence |
| --- | --- |
| A. Factory placement, cost/time, single unfinished limit, cancellation, immunity, footprint and cleanup | PASS in both modes: `construction`, plus destruction checks in `weapons` |
| B. Recipe admission, captured FIFO accounting/capacity/refunds, independent factories and shared wallet | PASS in both modes: `queues` and blocked-capacity checks in `deployment` |
| C. Ordinary Rocket configuration, actual-shape safe spawn, blocked wait, current rally, Move/Attack/X and route around factory | PASS in both modes: `deployment` |
| D. Delayed once-only unit/building damage, world interception, factory refunds and source/target lifetime | PASS in both modes: `weapons`, plus unchanged spherical-projectile regressions |
| E. Victory/defeat/draw, frozen work and clean scenario-specific Restart | PASS in both modes: `results`; `timing` separately verifies the real 90-second assault |
| F. Viewport build/train/rally, contextual selection, UI consumption and stale producer controls | PASS: graphical viewport events in construction/deployment/weapons/results/loop; contextual controls captured |
| G. Zero-credit earned construction/production/combat/victory/Restart loop | PASS in both modes: `loop`; 2000 earned, 1900 spent, 752 Rifle damage and 448 Rocket damage to the hostile HQ |
| Human keyboard-and-mouse playtest | UNVERIFIED — none occurred |

## Validation provenance and results

No applicable AGENTS.md was found in the repository/ancestor scope. README, roadmap, movement records, M6 and relevant construction/harvesting/production/combat/projectile docs and source were read. Godot remains **4.7.2.stable.official.ed1daf0bf**. The installed PowerShell **7.6.5** was reused. This completion pass made documentation changes only: no engine/dependency installation, gameplay/test edits, staging, commit, tag or discarded work.

Validation uses `tools/run-godot.ps1` via the installed PowerShell 7 runtime, with fixed 60 FPS and the normal external deadline. Ignored `validation-output/m7/` retains isolated current-source copies, SHA-256 manifests, starting revision/diff, exact wrapper invocations, all logs and per-run artifacts. Existing `validation-output/.gdignore` prevents archived source evidence being imported as game assets; historical evidence remains untouched. These are current feature/regression runs, with no historical replay, recorder expansion or movement diagnostic campaign.

Baseline source was copied before gameplay edits and the relevant baseline suite executions started against that frozen source before edits. All **24/24 baseline test executions passed**, plus a clean import. The baseline includes M6, construction/cleanup, harvesting, production, combat/repair/load, line of fire, spherical projectiles, movement repairs and projection checks in both display modes. The baseline runner continued on its unchanged source copy while implementation proceeded.

Every failed execution is retained:

* `feature-1`: the new suite failed to parse in both modes because its test fixture treated `_box()`'s void return as a node. The fixture now creates its own removable StaticBody3D; no gameplay fix was required. Import and combat-load checks passed.
* `feature-2`: both new-suite modes failed their native-error assertion (203 headless / 207 graphical checks, one failure/native error each). A result test passed a freed player HQ to the old typed placement entry point after defeat. The partial result case did not establish full acceptance. This is a required M7 boundary failure discovered by a new test; no claim is made that baseline testing had demonstrated it. The entry point now lets existing validation reject stale references. Existing M6, production, construction and load tests passed in both modes. The earned loop itself completed in both modes, with 2000 earned / 1900 spent and real Rifle/Rocket HQ damage.
* `post`: the first complete M7 matrix failed **3 of 32 assertions** in headless `projection_step_checks.gd` (exit 1). Unit 41 stopped at `(26.258497, 0, 18.849998)` instead of its accepted `(28.5, 0, 17.5)`, natural order 2, after eight recoveries. All-participant arrival, settling/separation and that exact-goal arrival failed. The graphical invocation passed. The relationship to historical unit 41 and to M7 integration is **UNKNOWN**; neither a pre-existing cause nor a new regression was demonstrated. The [failed log](../validation-output/m7/post/headless-projection_step_checks.log) is retained and indexed in [movement issue records](movement-issue-records.md). No movement investigation, tuning or repair followed this failure.
* `verification-20260907`: the completion pass's single fresh complete matrix failed **2 of 131 assertions** in graphical `movement_stress_checks.gd` (exit 1). Unit 5 in `choke_50` exhausted eight recoveries at `(6.250617, 0, -1.463947)`, assigned `(5.5, 0, -3)`. Arrival and three-second settling/separation failed; the minimum settled distance was `0.5800001`. The [failed log](../validation-output/m7/verification-20260907/graphical-movement_stress_checks.log), metrics and screenshots remain intact. The headless stress invocation passed. Attribution to earlier stalls or the M7 implementation is **UNKNOWN**; unchanged movement source does not by itself prove a shared cause. No failing test was retried. The older post-matrix projection failure also remains unresolved despite both projection invocations passing in this fresh matrix.

The earlier report had stopped before incorporating completed logs. Auditing the retained `results.json`, individual logs and SHA-256 source manifests establishes:

| Retained phase | Test executions | Assertions / failures | Import |
| --- | ---: | ---: | --- |
| [M6 baseline before implementation](../validation-output/m7/baseline/results.json) | 24 / 24 passed | 3835 / 0 | PASS |
| [Final focused feature](../validation-output/m7/feature-3/results.json) | 4 / 4 passed | 469 / 0 | PASS |
| [Original complete M7 matrix](../validation-output/m7/post/results.json) | 43 / 44 passed | 5555 / 3 | PASS |
| [Original fresh-copy feature/base/load](../validation-output/m7/completion/results.json) | 6 / 6 passed | 723 / 0 | PASS |

The final focused suite contains **225 headless / 230 graphical assertions**, zero failures and zero native errors/warnings. M6 retains **124 headless / 130 graphical** passing assertions. Source manifests for `post` and `completion` match all 226 captured files in the starting `643099f` working tree. The 95 pre-existing test/tool files are unchanged from M6, as are `rts_unit.gd`, `test_field.gd`, `group_destinations.gd`, `construction_navigation.gd`, `combat_controller.gd`, `guided_projectile.gd`, and both weapon resources. The mover SHA-256 remains `2f46d67b3267ab233405457f8c84e83ebc46b8f461e75deef46ee5c3f33b34d0`.

From PowerShell 7 in the repository root, the focused commands are:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--editor', '--import')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/vehicle_production_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/vehicle_production_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/base_assault_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/base_assault_checks.gd')
git diff --check
```

Each invocation must have its exit code checked before continuing. The existing task-local [matrix runner](../validation-output/m7/run_matrix.py) records every exact wrapper command and exit without replacing earlier phase directories. It uses the existing bounded suites and wrapper; it introduces no new replay or recorder.

## Completion verification on the installed engine

The repeated implementation request arrived with M7 already present at `643099f`. After inspecting the actual shared systems and the tracked suite, no additional gameplay or test change was necessary. The remaining work was fresh bounded validation and completion of README, roadmap, this report and the movement issue index.

One complete current-source matrix ran on a **fresh source copy without an inherited `.godot` cache** in `validation-output/m7/verification-20260907/project`. Its import passed. The matrix includes fresh-copy Vehicle Production and Base Assault validation in both headless and graphical modes, all construction/harvesting/production/combat/lifecycle/projectile regressions, movement-repair checks and the ordinary stress suite. It finished in **413.418 wall seconds** across the import and 44 independently bounded test executions.

**43/44 test executions passed; 5555 assertions, 2 failures. Required M7 A–G feature behavior passed; the complete matrix did not pass.** The sole failed execution was the graphical unit-5 `choke_50` case recorded above. No test was rerun to replace a failure, and neither historical failure is closed. No demonstrated new gameplay regression was established; attribution of the movement failures remains unknown.

The exact orchestration command was:

```powershell
python validation-output/m7/run_matrix.py verification-20260907 'C:/Program Files/WindowsApps/Microsoft.PowerShell_7.6.5.0_x64__8wekyb3d8bbwe/pwsh.exe'
```

That completed phase name must not be reused: the runner refuses to overwrite its directory. [Results](../validation-output/m7/verification-20260907/results.json) contain each exact wrapper invocation, engine argument array, exit and duration. [Audit](../validation-output/m7/verification-20260907/audit.json) records assertion counts, errors and source comparison. The runner continues after suite failures and its own zero exit is not an acceptance result; individual wrapper exits and assertion summaries are authoritative.

| Suite | Headless checks / failures | Graphical checks / failures |
| --- | ---: | ---: |
| `milestone_checks` | 127 / 0 | 131 / 0 |
| `movement_repair_checks` | 82 / 0 | 82 / 0 |
| `parked_deadlock_checks` | 14 / 0 | 14 / 0 |
| `parked_deadlock_controls` | 84 / 0 | 84 / 0 |
| `captured_parked_cluster_checks` | 10 / 0 | 10 / 0 |
| `projection_step_checks` | 32 / 0 | 32 / 0 |
| `boundary_neighbor_checks` | 23 / 0 | 23 / 0 |
| `boundary_neighbor_controls` | 193 / 0 | 193 / 0 |
| `gate_movement_checks` | 14 / 0 | 14 / 0 |
| `gate_movement_checks-avoidance` | 39 / 0 | 39 / 0 |
| `construction_checks` | 267 / 0 | 270 / 0 |
| `construction_cleanup_checks` | 46 / 0 | 46 / 0 |
| `harvesting_checks` | 298 / 0 | 299 / 0 |
| `production_checks` | 192 / 0 | 193 / 0 |
| `combat_checks` | 183 / 0 | 191 / 0 |
| `combat_repair_checks` | 230 / 0 | 230 / 0 |
| `line_of_fire_checks` | 305 / 0 | 308 / 0 |
| `spherical_projectile_checks` | 140 / 0 | 141 / 0 |
| `movement_stress_checks` | 122 / 0 | 131 / 2 |
| `base_assault_checks` | 124 / 0 | 130 / 0 |
| `vehicle_production_checks` | 225 / 0 | 230 / 0 |
| `combat_load` | 7 / 0 | 7 / 0 |

Both fresh M7 runs completed the earned loop at **117.9 simulated seconds**, with 2000 earned, 1900 spent and actual hostile-HQ damage of 752 from produced Rifles and 448 from produced Rockets. Both report zero native errors/warnings. The separate default-timing case exercised the unmodified 90-second assault and resulting defeat. Graphical checks ran at **1280 × 800**, Compatibility/OpenGL on the installed RTX 2070 SUPER.

Captured [factory controls](../validation-output/m7/verification-20260907/artifacts/graphical-vehicle_production_checks/m7_factory_ready.png), [produced combined army](../validation-output/m7/verification-20260907/artifacts/graphical-vehicle_production_checks/m7_combined_army.png), [victory](../validation-output/m7/verification-20260907/artifacts/graphical-vehicle_production_checks/m7_victory.png) and [restarted HQ choices](../validation-output/m7/verification-20260907/artifacts/graphical-vehicle_production_checks/m7_restarted.png) were visually inspected. Factory identity, price/time and training controls are legible, and the result/Restart flow renders correctly. The existing unit labels overlap when the army is tightly grouped; no unit-label redesign was included. **No human keyboard-and-mouse playtest occurred.**

The fresh-copy source audit permits only the four documentation files changed in this pass; all gameplay, tests, scenes, resources and tools still match the tested snapshot. `git diff --check` and local-link checks pass. No commit/tag, dependency/engine change or Milestone 8 work was performed.

## Repeated request verification

The repeated implementation request started at existing M7 commit `643099f`, with **README, roadmap, this report and movement issue records already modified**. Those changes were preserved. Independent audits of shared production/lifecycle code and A–G test coverage found no required behavior gap warranting a gameplay or test edit. The installed engine and PowerShell versions remain those recorded above. This pass updates handoff documentation only; no dependencies, commits, tags or Milestone 8 work were introduced.

Before editing these documents, one complete current-source matrix ran through the existing wrapper on a new source copy without an inherited `.godot` cache:

```powershell
python validation-output/m7/run_matrix.py request-audit-20260907 'C:/Program Files/WindowsApps/Microsoft.PowerShell_7.6.5.0_x64__8wekyb3d8bbwe/pwsh.exe'
```

**Fresh import PASS; 44/44 test executions PASS; 5555 assertions, zero failures and zero native error/warning lines.** Total wrapper execution time was **536.602 wall seconds**. The matrix contains the same 22 cases in each mode listed above. Vehicle Production passed **225 headless / 230 graphical**, Base Assault **124 / 130**; construction/cleanup, harvesting, production, combat/lifecycle/load, line of fire, spherical projectiles, movement repairs and ordinary stress all passed. The [results](../validation-output/m7/request-audit-20260907/results.json) preserve each exact wrapper invocation, engine argument array, exit and duration; the [audit](../validation-output/m7/request-audit-20260907/audit.json) records counts, log checks and source comparison. The phase directory must not be reused or overwritten.

All **A–G requirement groups remain PASS** within their documented automated scope. Both zero-credit loops again finished at **117.900 simulated seconds**, earned **2000**, spent **1900**, and recorded **752 Rifle / 448 Rocket** damage to the hostile HQ before ordinary victory and viewport Restart. The separate timing test passed the unchanged **90-second** scripted assault and defeat. No gameplay state, credits or units were injected into the earned loop.

The captured [factory controls](../validation-output/m7/request-audit-20260907/artifacts/graphical-vehicle_production_checks/m7_factory_ready.png), [victory screen](../validation-output/m7/request-audit-20260907/artifacts/graphical-vehicle_production_checks/m7_victory.png) and [restarted HQ choices](../validation-output/m7/request-audit-20260907/artifacts/graphical-vehicle_production_checks/m7_restarted.png) were visually inspected. Controls and costs/durations are readable; existing crowded unit-label overlap remains. **Human keyboard-and-mouse playtesting remains UNVERIFIED / NOT PERFORMED.**

The source audit matched all **226 captured files** before this pass's documentation edits. Final comparison allows only README, roadmap and this report to differ; gameplay, tests, scenes, resources, tools and the pre-existing movement issue edits remain preserved. `git diff --check` and local documentation-link validation pass.

There were **no failed executions in this requested matrix**. The earlier M7 projection and graphical gate failures remain retained, unresolved and of **UNKNOWN attribution**. This single passing matrix does not establish their cause or full movement/Milestone 5 acceptance. No failing test was retried in this pass, and no historical replay, movement investigation or recorder expansion occurred.

## Changed files and remaining limits

| Files | Responsibility |
| --- | --- |
| `construction/vehicle_factory.tres`, `production/rocket_vehicle.tres`, `scenes/rocket_vehicle.tscn` | Factory defaults and composition/recipe for the existing Rocket Vehicle |
| `scenes/combined_arms_assault.tscn`, `scripts/base_assault_field.gd` | Opt-in scenario, contextual objective/controls and scene-specific Restart |
| `scripts/construction_definition.gd`, `scripts/construction_field.gd`, `scripts/building_construction.gd`, `scripts/building_placement.gd`, `scripts/construction_building.gd` | Shared type/definition placement and factory identity/visuals |
| `scripts/rts_building.gd`, `scripts/production_definition.gd`, `scripts/production_field.gd`, `scripts/unit_production.gd` | Producer eligibility, recipe configuration and captured collision dimensions for safe deployment |
| `scripts/construction_panel.gd`, `scripts/production_panel.gd` | Second HQ choice and readable contextual vehicle training control |
| `tests/vehicle_production_checks.gd`, README, roadmap, this report | Focused behavior/real loop coverage and handoff |

Known movement issues remain separately tracked in [movement issue records](movement-issue-records.md): original Issue B/unit 4, historical unit 41, unresolved unit 13 causal questions, graphical unit-23 gate failure, the recorded M6 starting-source unit-18 gate stall, the M7 post-matrix unit-41 projection-fixture failure and the fresh M7 graphical unit-5 gate failure. These remain unresolved; passing feature/regression runs do not close them or establish full movement acceptance. No movement repair, solver tuning or investigation was performed for M7.

Scope remains the existing small flat map and bounded local placement, spawn, pursuit and movement behavior. There is no strategic AI, new unit combat type, steering, turret system, formation rewrite, power, technology, fog, multiplayer, human-playtest claim or general movement guarantee. Stop at Milestone 7; no Milestone 8 work is included.
