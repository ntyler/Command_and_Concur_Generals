# Milestone 11 — Supply Depots and Collector production

Status: implementation integrated; validation in progress. This saved report will be finalized after the required checks. No human playtest has occurred.

## Playable scene

Open [supply_depot_assault.tscn](../scenes/supply_depot_assault.tscn) in Godot 4.7.2 and press F6, or run the installed console executable with `--path . res://scenes/supply_depot_assault.tscn`. F5 retains the original main scene.

The scene inherits the economy assault composition. Select the owned HQ, choose Build Supply Depot, and place on clear ground. A completed depot receives cargo into the existing owner wallet and trains the existing unarmed Collector Truck. New collectors use ordinary ground rally and require a player supply assignment. The original enemy economy and HQ objective remain.

## Defaults and implementation

| Setting | Value |
| --- | --- |
| Depot cost / construction | 300 credits / 10 simulated seconds after navigation readiness |
| Depot footprint / height / completed health | 6 × 5 / 2 / existing 450 HP producer default |
| Collector production | 200 credits / 6 simulated seconds / five outstanding jobs |
| Collector configuration | Existing 150 HP, speed 4, capacity 100, loading 25 per second, unloading one second |
| Delivery / production access | Six bays on west/north/south; separate east production exit |
| Cancellation / destruction | Full captured payments refunded for undeployed jobs; no completed-building refund |

Drop-offs use field-local building membership, owner and operational checks. Automatic return chooses the shortest usable navigation polyline, with stable building identity for equivalent costs. Endpoint capsule clearance and interaction rays supplement navigation. A valid current delivery is retained; failure permits one evaluation excluding the failed building, then a safe cargo-retaining blocked state. Manual return never substitutes another building and idles after depositing. Destruction may wait for existing navigation synchronization before evaluating an alternative.

The existing silent wallet credit and cargo removal precede transfer notifications. Arrival, interaction geometry, identity, ownership, membership and match state are checked at commitment. Production, deployment, cancellation, health, topology cleanup, match freeze and Restart retain their shared implementations.

## Baseline and preservation

Started with a clean working tree at `b7ab26e9d8fafb5782ec926a4bdc66becc83486e`. No applicable AGENTS.md was found in the repository or ancestor scope. All 275 M10 snapshot files were compared with starting HEAD; after line-ending normalization only the three completed handoff documents differ. [Baseline audit](../validation-output/m11/starting-baseline.json).

Reuse preserves M10's **60 completed executions, 59 passing, 7,393 assertions, three failures, phase exit 1**. Its graphical `choke_30` failure remains of unknown attribution. Existing [movement limitations](movement-issue-records.md) remain deferred and unresolved. No historical movement investigation, engine/dependency change, commit, tag or discarded work is part of this task.

## Acceptance

| Required group | Status |
| --- | --- |
| 1. Buildable depot and preserved HQ compatibility | NOT VERIFIED |
| 2. Owner-correct, route-aware drop-off selection | NOT VERIFIED |
| 3. Exactly-once deposits and bounded invalidation | NOT VERIFIED |
| 4. Collector production and safe deployment | NOT VERIFIED |
| 5. Destruction, callbacks, freeze and Restart | NOT VERIFIED |
| 6. Real earned depot-to-collector-to-army integration | NOT VERIFIED |
| 7. Preserved enemy economy and existing interface | NOT VERIFIED |
| 8. Focused/integration validation and accurate reporting | NOT VERIFIED |

## Retained execution history

- [m11-core-01](../validation-output/m8/m11-core-01/results.json): import reported four recipe Boolean type-inference errors and dependent compile failures (11 error lines). No tests ran. Explicit Boolean types corrected the implementation.
- [m11-core-02](../validation-output/m8/m11-core-02/results.json): fresh import passed; production 192/0 passed. Harvesting 289/2 failed after removing departed collectors shifted historical starting indices. The live unit registry already governs membership; retaining the original collector-list indexing corrected this regression. Enemy economy hit its 180-second internal watchdog (exit 2, no final assertion summary), and integration stopped at 4 checks/1 failure after a new eager HUD type dependency caused a construction-resource loading cycle. The phase records 507,006 native/error lines, including the repeated compile cascade. The new dependency was replaced by a virtual field hint and recipe script resolution remains at runtime. All logs retained; no tests counted as passing from these incomplete paths.
- [m11-focused-01](../validation-output/m8/m11-focused-01/results.json): fresh import, earlier harvesting **298/0** and enemy economy **96/0** passed. Depot **252/3** failed two route-fixture assumptions and one new live-list count assertion; real construction, trips, invalidation, callbacks, freeze and UI cases passed. Integration **9/1** exposed use of the enemy cache's array index instead of the intended nearby player cache. No native errors. Fixture corrections are being verified without changing requirements or ordinary movement.

## Recovered integration and source correspondence

Recovery found six completed M11 phases, no active Godot/validation process and no full M11 regression matrix. The missing chat handoff was not an engine failure. Saved result rows, sibling invocation scripts, stdout/stderr logs and source hashes were inspected. The final two integration phases had already finished after the last transcript.

- [m11-focused-02](../validation-output/m8/m11-focused-02/results.json): depot **271 headless / 279 graphical**, both exits 0. Integration **64 / 65**, one failure in each mode, exits 1. Phase: **679 checks, two failures, zero native errors, exit 1**. The earned construction, collector deployment and Rifle funding already passed; the return-origin comparison failed.
- [m11-integration-final-01](../validation-output/m8/m11-integration-final-01/results.json): **80 / 81 checks**, two failures in each mode, exits 1; phase **161 checks, four failures, zero native errors, exit 1**. Loaded ordinary movement produced comparable origins and the shorter depot delivery passed, but the claimed unobstructed HQ segment bent around depot navigation clearance. The straight-route assertions correctly failed.
- [m11-integration-final-02](../validation-output/m8/m11-integration-final-02/results.json): fresh import and integration **80 / 81**, no failures/native errors, all exits 0; phase **161 checks, exit 0**. Moving the shared requested origin west to `(-10.5, 0, -13)` made both navigable segments unobstructed without changing geometry, speed or unload timing.

All runtime files, resources, scenes and integration dependencies match integration-final-02 exactly. Its only current file difference at recovery was the independent `tests/supply_depot_checks.gd`: four additional viewport captures and selecting the unfinished construction site before its capture. Focused-02's runtime also matches, but both test files have since changed. Its depot results and captures remain valid historical evidence; the final matrix reruns the affected depot suite. The passing targeted integration is reused as evidence of the completed correction and also included in the required full matrix, not added twice to final acceptance totals.

No gameplay or test edits were needed during this recovery. The final run uses the existing external wrapper and runner on a new source-hashed copy. Only README, roadmap and this handoff report are being changed after its snapshot. Ignored run artifacts and the saved progress note are retained on disk.

## Controlled return comparison and earned accounting

The original failing assertion was: **“controlled same-cache comparison observes a shorter valid depot route and shorter actual return without modified truck values.”** It included a requirement that actual return starts differ by at most 0.4 world units. Focused-02 began the depot return at `(-5.987401, 0, -13.00734)` and HQ return at `(-8.167737, 0, -12.94461)`, about 2.18 units apart. Using the same rally before gathering did not choose the same cache bay. The time advantage observed there did not establish the stated controlled comparison.

The saved correction retains the original assertion and adds explicit checks for comparable position, cargo, configuration, geometry, traffic clearance and unobstructed route queries. After each actual load, public Stop preserves cargo and ordinary ground Move takes the truck to the same requested return point; this preparation lies outside both measurements. The depot return uses the public automatic harvest command with a full load; the HQ return uses public manual deposit. Both immediately select the previously measured access point. No live collector teleport, granted supplies/credits, direct deposit, altered speed, disabled obstacle or engine trajectory matching is used in this integration.

Both modes in integration-final-02 recorded:

| Measurement | Depot automatic return | HQ manual return |
| --- | --- | --- |
| Actual return start | `(-10.32073, 0, -13.00029)` | `(-10.31937, 0, -12.99944)` |
| Target access / bay | `(-11.1, 0, -9.8)` / slot 4 | `(-15.7, 0, -8)` / slot 0 |
| Interaction dock | `(-11.1, 0, -8.6)` | `(-16.9, 0, -8)` |
| Valid navigation route | 3.293801 units | 7.344764 units |
| Other building's route from this actual start | HQ 7.344348 units | Depot 3.293295 units |
| Actual distance travelled | 3.133348 units | 7.133326 units |
| Start / unloading / deposit physics tick | 7280 / 7327 / 7387 | 8469 / 8576 / 8636 |
| Travel until valid unloading state | 47 ticks / 0.783333 s | 107 ticks / 1.783333 s |
| Unloading | 60 ticks / 1.000000 s | 60 ticks / 1.000000 s |
| Return command through committed delivery | 107 ticks / 1.783333 s | 167 ticks / 2.783333 s |

The same owner-1 collector #20 has 150 HP, no weapon, speed 4, capacity/cargo 100, 25 supplies loaded each one-second interval, one-second unloading and 0.22 stopping distance. Actual starts differ by approximately 0.0016 units; the preserved 0.4 comparison allowance covers ordinary stopping tolerance. Route distance reaches the queried endpoint; actual travel stops within the normal arrival tolerance, explaining their difference.

Navigation iteration is 4 for both returns, navigation suspension is false, and all ten obstacle rectangles are identical. These are the scene's eight initial rectangles plus the ordinarily built depot `Rect2(-13.1, -8.5, 6, 5)` and barracks `Rect2(-6, 13.5, 6, 5)`. Full geometry is retained in both [headless](../validation-output/m8/m11-integration-final-02/headless-supply_depot_integration_checks.log) and [graphical](../validation-output/m8/m11-integration-final-02/graphical-supply_depot_integration_checks.log) measurement dictionaries. Existing route queries verify both segments are straight within 0.05 units; live actor-to-segment checks throughout travel record nearest unrelated actor distance 21.011663 units. Original collectors are parked by ordinary movement. Enemy first-wave eligibility is deferred to 600 seconds in this fixture only; its economy and actors otherwise remain present. No assault occurs during the 143.917-second earned sequence.

Timing uses physics-frame differences divided by the runner's fixed 60 simulation FPS. Start is immediately after the accepted public return command; travel ends on entry to UNLOADING; delivery ends at the actual transfer event. Gathering, loaded preparation, prior construction and Rifle training are excluded. The test proves a shorter valid navigable return and a shorter measured delivery in these clear conditions. It does **not** establish universally higher income under congestion or include a complete repeated harvest cycle in the timed interval.

The ledger reconciles **1100 real supplies loaded and deposited, 1000 normally spent, 100 credits left and 900 supplies still in the cache**. Starting player funds are zero. Three existing-collector HQ deposits earn the depot's 300-credit cost; six later depot deposits earn 400 for ordinary barracks and 200 for one ordinary Collector queue job. The depot-produced truck's first 100-credit deposit is the only available money for the Rifle, which actually trains and deploys. Its subsequent manual HQ comparison deposit leaves the final 100 credits. Observer callbacks record transfers and conservation; they do not supply income. The normal playable scene still starts with 1000 player credits and the unchanged enemy schedule.

## Supported compatibility corrections

| Earlier issue | Saved correction and coverage |
| --- | --- |
| Recipe Boolean inference / resource loading cycle | Explicit Boolean types; specific collector script resolved at runtime; HUD calls a virtual field hint without introducing an eager construction-resource dependency. Fresh-copy import, production, harvesting, enemy economy and depot integration cover these paths. |
| Starting collector index shifted after departure | Preserve the historical starting-collector list; the existing live unit registry remains authoritative for membership. Harvesting departure/re-entry checks and depot deployment counts use live membership. |
| Intended cache selected by registration index | Depot fixtures resolve the declared western footprint and assert cache identity 1 (second fixture cache 2); earned integration also confirms it is not the enemy-assigned cache. No ownership rule was added: registered supplies remain neutral resources. |
| Route-inversion fixture overlapped older base access | Its western comparison depot moved from `(-16, 0, 0)` to clear `(-10, 0, 10)`; the real wall still makes the geometrically nearer eastern depot more expensive by navigation distance. No selector expectation was relaxed. |
| Depot deployment count used historical list size | Count live registered Collector Trucks before and after blockers leave, preserving configuration, clearance and exactly-one-deployment assertions. Added rejected-rally coverage retains the paid deployed unit with no duplicate or refund. |
| Return-origin and unobstructed-route assumptions | Ordinary loaded movement to the corrected shared origin; preserved shorter-route/time assertion plus stronger measurement checks described above. |

Owner-isolated enemy commands, feedback and wallet handling remain unchanged. Deposit commitment still verifies live owner/field/target/claim/geometry and full unloading before silent wallet credit and cargo removal; synchronous spending, replacement, removal and match-finish callbacks cannot replay it. Automatic invalidation excludes the failed building and consumes at most one alternative evaluation, waiting for existing navigation synchronization when necessary. A second failure retains cargo in a stable blocked state. Manual return does not substitute another building. Relevant depot cases and original harvesting/production/construction/lifecycle/enemy suites are all in the final matrix.

## Important changed files

- [Depot definition](../construction/supply_depot.tres), [Collector recipe](../production/collector_truck.tres), [Collector scene](../scenes/collector_truck.tscn) and [playable composition](../scenes/supply_depot_assault.tscn) provide the opt-in defaults.
- [RTSBuilding](../scripts/rts_building.gd), [ConstructionDefinition](../scripts/construction_definition.gd), [BuildingConstruction](../scripts/building_construction.gd), [ConstructionField](../scripts/construction_field.gd) and [ConstructionBuilding](../scripts/construction_building.gd) add depot capability, protected delivery geometry, normal paid construction and presentation.
- [HarvestField](../scripts/harvest_field.gd) and [CollectorHarvest](../scripts/collector_harvest.gd) provide route-aware owned drop-offs, access validation, commitment and bounded replacement while preserving neutral caches and HQ compatibility.
- [ProductionDefinition](../scripts/production_definition.gd) and [ProductionField](../scripts/production_field.gd) admit the exact existing Collector configuration through shared paid queues and safe deployment.
- [ConstructionPanel](../scripts/construction_panel.gd), [ProductionPanel](../scripts/production_panel.gd), [HarvestPanel](../scripts/harvest_panel.gd), [Help](../scripts/rts_help_panel.gd) and [minimap](../scripts/tactical_minimap.gd) expose priced construction, Collector queues, current cargo/drop-off and depot markers.
- [Focused checks](../tests/supply_depot_checks.gd) and [earned integration](../tests/supply_depot_integration_checks.gd) cover the feature and real economic chain using existing test infrastructure.

## Final validation in progress

The single final expanded matrix is running as [m11-final-matrix-01](../validation-output/m8/m11-final-matrix-01/plan.json): 31 suite names plus the existing gate-avoidance variant in each mode, **64 planned test executions**, preceded by fresh-copy import. It covers all 60 M10 regression executions plus four M11 executions. Every command uses the installed Godot 4.7.2, the existing `tools/run-godot.ps1` 240-second external timeout and fixed 60 simulation FPS; graphical commands omit `--headless`. No engine or dependency installation/upgrade occurred.

Exact launched PowerShell command from the repository root:

```powershell
& 'C:\Users\Tyler\AppData\Local\Microsoft\WindowsApps\pwsh.exe' -NoProfile -ExecutionPolicy Bypass -File 'validation-output\m11\run-final-matrix.ps1' *> 'validation-output\m11\final-matrix-wrapper.log'
```

The [saved invocation](../validation-output/m11/run-final-matrix.ps1) supplies the complete suite list to `tools/validate-m8.ps1 -RunName 'm11-final-matrix-01' -TimeoutSeconds 240 -Modes @('headless', 'graphical') -Suites $suites`. Its [plan](../validation-output/m8/m11-final-matrix-01/plan.json) records every actual engine argument; [results](../validation-output/m8/m11-final-matrix-01/results.json) record exact shell commands, wrapper calls, totals and exits. Each result's sibling `<label>.ps1`, `.log`, `.stdout.log` and `.stderr.log` is retained in that directory. [Outer wrapper log](../validation-output/m11/final-matrix-wrapper.log) and the brief [progress note](../validation-output/m11/progress.md) protect against another response disconnect. Final phase totals, source correspondence, screenshots, failure classification and handoff checks will be saved below when the run finishes.
