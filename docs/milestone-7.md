# Milestone 7 — Vehicle Factory and Rocket Vehicle production

2026-09-07. Implements the user's saved Vehicle Factory scope on clean Milestone 6 commit `682c8c1`. Feature validation is reported below. Deferred movement failures remain **unresolved**; full movement/Milestone 5 acceptance has not passed.

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
| A. Factory placement, cost/time, single unfinished limit, cancellation, immunity, footprint and cleanup | Pending final matrix; focused headless passes |
| B. Recipe admission, captured FIFO accounting/capacity/refunds, independent factories and shared wallet | Pending final matrix; focused headless passes |
| C. Ordinary Rocket configuration, actual-shape safe spawn, blocked wait, current rally, Move/Attack/X and route around factory | Pending final matrix; focused headless passes |
| D. Delayed once-only unit/building damage, world interception, factory refunds and source/target lifetime | Pending final matrix; focused headless passes |
| E. Victory/defeat/draw, frozen work and clean scenario-specific Restart | Pending final matrix; focused headless passes |
| F. Viewport build/train/rally, contextual selection, UI consumption and stale producer controls | Pending final graphical validation |
| G. Zero-credit earned construction/production/combat/victory/Restart loop | Pending final matrix; focused headless passes |
| Human keyboard-and-mouse playtest | UNVERIFIED — none occurred |

## Validation provenance and results

No applicable AGENTS.md was found in the repository/ancestor scope. README, roadmap, movement records, M6 and relevant construction/harvesting/production/combat/projectile docs and source were read. Godot remains **4.7.2.stable.official.ed1daf0bf**. PowerShell 7 installed with the user's earlier M6 authorization was reused; no engine/dependency installation, staging, commit, tag or discarded work occurred for M7.

Validation uses `tools/run-godot.ps1` via the installed PowerShell 7 runtime, with fixed 60 FPS and the normal external deadline. Ignored `validation-output/m7/` retains isolated current-source copies, SHA-256 manifests, starting revision/diff, exact wrapper invocations, all logs and per-run artifacts. Existing `validation-output/.gdignore` prevents archived source evidence being imported as game assets; historical evidence remains untouched. These are current feature/regression runs, with no historical replay, recorder expansion or movement diagnostic campaign.

Baseline source was copied before gameplay edits and the relevant baseline suite executions started against that frozen source before edits. All **24/24 baseline test executions passed**, plus a clean import. The baseline includes M6, construction/cleanup, harvesting, production, combat/repair/load, line of fire, spherical projectiles, movement repairs and projection checks in both display modes. The baseline runner continued on its unchanged source copy while implementation proceeded.

Every failed execution is retained:

* `feature-1`: the new suite failed to parse in both modes because its test fixture treated `_box()`'s void return as a node. The fixture now creates its own removable StaticBody3D; no gameplay fix was required. Import and combat-load checks passed.
* `feature-2`: both new-suite modes failed their native-error assertion (203 headless / 207 graphical checks, one failure/native error each). A result test passed a freed player HQ to the old typed placement entry point after defeat. The partial result case did not establish full acceptance. This is a required M7 boundary failure discovered by a new test; no claim is made that baseline testing had demonstrated it. The entry point now lets existing validation reject stale references. Existing M6, production, construction and load tests passed in both modes. The earned loop itself completed in both modes, with 2000 earned / 1900 spent and real Rifle/Rocket HQ damage.

Final focused/matrix/fresh-copy results and exact commands are added after completion below.

## Changed files and remaining limits

| Files | Responsibility |
| --- | --- |
| `construction/vehicle_factory.tres`, `production/rocket_vehicle.tres`, `scenes/rocket_vehicle.tscn` | Factory defaults and composition/recipe for the existing Rocket Vehicle |
| `scenes/combined_arms_assault.tscn`, `scripts/base_assault_field.gd` | Opt-in scenario, contextual objective/controls and scene-specific Restart |
| `scripts/construction_definition.gd`, `scripts/construction_field.gd`, `scripts/building_construction.gd`, `scripts/building_placement.gd`, `scripts/construction_building.gd` | Shared type/definition placement and factory identity/visuals |
| `scripts/rts_building.gd`, `scripts/production_definition.gd`, `scripts/production_field.gd`, `scripts/unit_production.gd` | Producer eligibility, recipe configuration and captured collision dimensions for safe deployment |
| `scripts/construction_panel.gd`, `scripts/production_panel.gd` | Second HQ choice and readable contextual vehicle training control |
| `tests/vehicle_production_checks.gd`, README, roadmap, this report | Focused behavior/real loop coverage and handoff |

Known movement issues remain separately tracked in [movement issue records](movement-issue-records.md): original Issue B/unit 4, historical unit 41, unresolved unit 13 causal questions, graphical unit-23 gate failure and the recorded M6 starting-source unit-18 gate stall. These remain deferred and unresolved; passing feature/regression runs do not close them or establish full movement acceptance. No movement repair, solver tuning or investigation was performed for M7.

Scope remains the existing small flat map and bounded local placement, spawn, pursuit and movement behavior. There is no strategic AI, new unit combat type, steering, turret system, formation rewrite, power, technology, fog, multiplayer, human-playtest claim or general movement guarantee. Stop at Milestone 7; no Milestone 8 work is included.
