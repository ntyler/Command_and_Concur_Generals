# Milestone 14 — Powered Ground Defense Battery

**Milestone 14: COMPLETE (2026-09-09).** All eight feature acceptance groups PASS within the preserved historical interface exception. The saved final fresh-copy matrix completed **82/82 executions: 81 passing, 10,751 checks, five failures, aggregate exit 1**. All eight defense executions pass **1,040 checks**, with zero defense failures or native errors. The sole failed execution is graphical movement stress, with attribution **UNKNOWN**. Feature completion does not claim a clean regression matrix or full movement acceptance. No human keyboard-and-mouse playtest occurred.

The extension is a stationary, Bulldozer-built Ground Defense Battery in [Defense Assault](../scenes/defense_assault.tscn), using the existing construction, combat, power, lifecycle and match systems. Fixed defaults are 700 credits, 12 working seconds, 600 HP, 3 demand, zero generation; single-target hitscan damage 18, cooldown 0.75 simulated seconds, range 12, acquisition interval 0.25 simulated seconds, turret turn speed 3 radians/second and facing tolerance 8 degrees.

## Play and configuration

Open `scenes/defense_assault.tscn` in the installed Godot 4.7.2 and press **F6**, or run from the repository root:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/defense_assault.tscn
```

The player keeps the M13 HQ, selected original Bulldozer, three Rifles, 1000 credits and finite supplies, with no prebuilt player battery, generator or producer. A useful economic opening remains a 300-credit Depot and 200-credit Collector; real harvesting then funds defenses, power and armies. Selecting one owned Bulldozer exposes **Build Ground Defense**. Left-click valid placement pays 700; the same builder must physically travel and perform 12 simulated seconds of eligible work. X or Move pauses; select a builder and right-click the owned unclaimed unfinished site to resume. Site cancellation returns the captured 700 once; completed buildings cannot be sold or refunded.

Construction and operational values live in [the battery definition](../construction/ground_defense_battery.tres) and [its existing-mode weapon resource](../weapons/ground_defense.tres). The battery is a `ConstructionBuilding`/`StaticBody3D` subclass, not a mobile unit. Its 6×5 footprint drives navigation, collision, picking and weapon blocking. The primitive base remains fixed while a separate visible turret turns; the committed site remains immune and nonfiring under the existing construction policy. Completion enables the same body, adds demand, releases its builder and creates no production queue.

The new enemy battery occupies `Rect2(9, -8, 6, 5)`, center `(12, 0, -5.5)`, guarding the western central approach. Its existing plant supplies 10 power against Barracks 2 plus battery 3. The eastern route beyond x=24 and the northern approach leave practical access to the enemy plant outside battery range. Enemy credits, finite supply economy, production recipes, 90-second earliest wave, 60-second wave interval and population rules are inherited unchanged. No rebuilding or automatic flanking is added. HQ destruction remains the only match objective; F5 and earlier scenes retain their entry points.

## Defense authority and feedback

The completed battery always contributes its nominal 3 demand, including while idle, blocked or unpowered. Power shortage disables its firing and acquisition, clears its temporary target, and preserves the remaining cooldown. Active simulated time continues cooling that shot. Restoration resumes bounded acquisition and respects facing and cooldown; there is no accumulated burst. Barracks/Factory production keeps the M13 50%/100% rule; HQ/Depot production, construction, harvesting and deployed units keep their prior behavior.

The field's existing mobile registry supplies nearest eligible hostile ground targets, with stable unit identity breaking distance ties. Rifles, Rockets, Collectors and Bulldozers are eligible. Friendlies, buildings, supplies, decorations, unfinished previews and unavailable actors are rejected before geometry queries. A valid retained target is not replaced on every scan. Invalid, out-of-range or obstructed targets are released; the next scheduled acquisition chooses again. The battery never moves or pursues.

The shared emitter performs current source/owner/field-generation, ground eligibility, power, range, facing, cooldown and muzzle/attachment checks. Its final power read reconciles the existing grid without publishing callbacks after the geometry query. Source/target pose changes during a query reject the stale shot. Only the firing building's own RID is excluded from its attachment/shot; ordinary intervening blockers and the unchanged spherical Rocket path remain authoritative. A committed shot records cooldown/count before damage notification and is never applied twice.

Building selection shows identity, HP, demand and Ready/Engaging/Obstructed/No power status. The selected battery and relevant placement preview show range; ordinary play has no permanent acquisition lines or target IDs. The minimap uses a distinct **G** building marker. Help and written shortages explain the defense and affected producers. Building selection has no train/rally/Move/Q action and does not join mobile groups.

Lifecycle guards and weak target references prevent stale callbacks after death, field departure, ownership changes, result freeze or Restart. Preplaced batteries with no construction site use ordinary static-building navigation cleanup. Restart closes old grid listeners, removes old batteries and reconstructs actual starting demand and UI state.

## Preserved baseline

Preflight found a clean tree at `c347e9a` (`feat: complete milestone 13 with power management validation`), no applicable AGENTS.md in the workspace or its ancestor directories, and installed Godot 4.7.2. No dependency or engine changes, commits, tags or discarded changes are authorized or performed.

The [M13 final matrix](../validation-output/m8/m13-final-matrix-01/summary.json) completed 74/74 executions, 9,711 checks, zero failures/native errors, exit 0. Its 305-file manifest matches the starting runtime, scenes, resources, tests and tools; only README, roadmap and the completed M13 report differ. **The 829 M13 power checks are included in 9,711 and are not counted again.** This is reused baseline evidence, not M14 feature validation.

The [historical M12 interface exception](milestone-12.md#owner-authorized-interface-exception--2026-09-09) remains accepted for continued development, with the original group-3 occurrence OPEN, attribution UNKNOWN and M12 criterion 7 NOT VERIFIED. [Deferred movement findings](movement-issue-records.md) remain unresolved. Neither historical investigation is restarted by this milestone. No human keyboard-and-mouse playtest has occurred.

## Acceptance and integrated evidence

| Acceptance group | Status and final evidence |
| --- | --- |
| 1. Builder-created stationary battery | **PASS.** Exact 700-credit placement, actual builder travel and 12 working seconds; unfinished immunity and zero demand/scans/shots; X pause, cancellation/refund, builder death and normally purchased replacement; stationary 6×5 body, no mobile registration or producer. |
| 2. Correct nominal demand and power-gated firing | **PASS.** Three demand exactly once while idle, blocked and unpowered; current owner grid gates shots; shortage clears target and halts acquisition; cooldown continues, restoration neither resets it nor accumulates a burst; owner isolation and existing 50%/100% production remain correct. |
| 3. Valid ground targeting, facing and cooldown | **PASS.** Nearest eligible Rifle/Rocket/Collector/Bulldozer, stable tie-break and retained target; invalid/friendly/building rejection; bounded distance-first scans; actual turret rotation, 0.75-second shots, departure/reacquisition without pursuit. |
| 4. Real damage with authoritative obstruction checks | **PASS.** Real 18-damage hitscan, walls and invalid muzzle inhibit commitment; post-query power/owner/target/field changes reject stale shots without cooldown or success effects. Existing Rifle and spherical Rocket attacks damage the battery normally. |
| 5. Destruction, callbacks, freeze and Restart | **PASS.** Exactly-once committed damage survives power loss; immediate source/target/field deletion fixtures, queued ancestors, ownership and reparenting; constructed and preplaced footprint cleanup; match freeze and late calls remain gated; Restart clears old targets, cooldowns, grid listeners and HUD. |
| 6. Integrated power-and-defense gameplay | **PASS.** Earned Depot/Collector/Battery/Plant opening, real completion restores firing, six real battery hits kill a hostile, ordinary hostile Rifle destroys the paid generator, and a later eligible threat receives no defensive damage. |
| 7. Preserved earlier scenes and readable interface | **PASS within the historical M12 interface exception.** Normal live scene at 1280×720 and 1920×1080; selected battery/shortage/range, expanded Help and Restart; current builder, groups, Q/X, minimap and earlier gameplay suites pass. This does not close M12 criterion 7 or establish full movement reliability. |
| 8. Focused/integration validation and accurate failure reporting | **PASS.** Finished source-matched core, integration/UI and full matrix; fresh import, retained failed runs and commands, source audit, reused visual inspections and final documentation checks. The matrix's failed movement execution remains explicitly reported. |

The final [headless earned log](../validation-output/m8/m14-final-matrix-01/headless-defense_integration_checks.log) and [graphical earned log](../validation-output/m8/m14-final-matrix-01/graphical-defense_integration_checks.log) agree: **127.800 simulated seconds, six battery shots, 100 actual clamped damage**, followed by **38 ordinary Rifle hits / 450 damage** destroying the Power Plant. The ledger is **1000 initial + 1500 deposited − 1700 spent = 800 credits**. Spending is Depot 300, Collector 200, Battery 700 and Plant 500. Loaded supplies total 1600, leaving 100 cargo and 400 in the finite 2000-supply cache. During shortage the Collector loads 625 and deposits 700. All transfer ownership, conservation and wallet assertions pass. Enemy paid jobs and deployments both reach ten with normal harvesting still active.

[The integration suite](../tests/defense_integration_checks.gd) uses the original player wallet, builder and hostile Rifles. Production, loading, travel, deposits, builder access and construction completion are ordinary gameplay; it does not inject money/cargo/power, teleport actors, write construction progress or call damage to prove battery fire. Its explicitly labelled instance-only first-wave delay is **600 seconds**, and retaliation is disabled for the lane targets. These isolate the economic sequence; the shared enemy resource and playable scene retain **90/60-second** timing. A separate labelled four-Rifle combat fixture delivers 100 real hits / 1200 HQ damage, reaches Victory and clicks Restart. Those four fixture units are not represented as earned troops.

## Retained failures and supported corrections

All original snapshots and stdout/stderr remain under `validation-output/m8/m14-*`. A later passing result resolves the tested defect without deleting the earlier failure.

| Finding and first failure | Attribution and saved correction | Verification after correction |
| --- | --- | --- |
| Smoke 01 mechanics: Variant-inferred variables at original test lines 431/432 are warnings treated as parse errors; no checks execute. | **Fixture error.** Explicit `WeakRef` declarations replace ambiguous inference. | Final mechanics 228 headless / 229 graphical checks pass. |
| Smoke 01 acquisition callback: `Object is locked and can't be freed` at original boundary line 136; first assertion is `removed scanning source retires nominal demand exactly once`. | **Fixture error.** Queue the battery when it is itself emitting `status_changed`. Immediate source deletion remains covered during the target's damage signal. | Final boundary 92/92 checks; zero native errors. |
| Smoke 02 first native errors: target/field deletion also frees the health object currently emitting its signal (original mechanics lines 341/342). | **Fixture error.** Reparent only the emitting health node until notification returns and queue its cleanup, while immediately freeing the requested actor/field. Damage still comes from ordinary emission. | Final callback cases and boundary suites pass; shutdown has no leaks. |
| Smoke 02 first failed gameplay assertion: `completed battery participates through distinct minimap marker`. Later, `contains_building` rejects a previously freed typed argument at original line 377. | **Fixture errors.** Expect actual `ground_defense_battery`, and inspect saved identity/registry removal after deletion rather than pass a destroyed object to a typed API. The real marker/removal requirements remain. | Final mechanics lifecycle and both normal UI suites pass. |
| Smoke 01/02 shutdown: 100 leaked ObjectDB instances, 48 retained resources, PagedAllocator error. Smoke 02 boundary reports 82/82 and engine exit 0 but still fails the wrapper's native-error gate. | **M14 production dependency defect.** Saved diagnostic 04 isolates the concrete `BaseAssaultField` script reference in battery match-signal binding. Capability-based `has_signal("match_finished")` and an `int` callback retain the same signal behavior without the script retention edge. | Diagnostic 04: 82 checks, no assertion/native/shutdown errors, exit 0. Final source-matched mechanics/boundaries and all matrix executions have no corresponding leak. |
| Integration dev 01/02: `Could not resolve class "res://tests/defense_checks.gd"` at line 1 of both derived test scripts; zero checks run. | **Fixture inheritance error.** Shared helpers are saved in `tests/fixtures/defense_harness.gd`, independently inherited by mechanics, integration and UI. | Recovery integration/UI and final matrix import and execute all suites successfully. |
| Integration dev 03: `Lambda capture at index 0 was freed. Passed "null" instead`; the final native-error assertion fails in each mode. | **Fixture lifetime error.** Generator-death wait captures `plant_ref: WeakRef`, preserving actual Rifle destruction measurement after node deletion. | Dev 04 passes 137 checks; later recovery and final integration each pass 68/69 on the final runtime. |
| Recovery core 01: `replacement construction requires the registered builder's real arrived work position`. Actual travel and completion had succeeded. | **Fixture timing error.** One `await physics_frame` before the work-position query matches inherited `_builder_arrival`; physics authority intentionally rejects queries outside a physics step. | Core 02: 228 mechanics + 92 boundary = 320 checks, zero failures/native errors. Final both-mode mechanics also pass. |

The saved [shutdown diagnostic notes](../validation-output/m14/leak-diagnostic-notes.md) preserve diagnostic 01 (original leak), invalid diagnostic 02 (malformed externally passed PowerShell array; no accepted result), diagnostic 03 (changing only callback type did not fix the leak), and diagnostic 04 (successful capability-binding correction). These diagnostic runs are not added to acceptance totals. [Recovery notes](../validation-output/m14/recovery-core-notes.md) preserve the one-line physics-frame fixture correction.

Additional saved integration corrections are also present and verified: preplaced batteries with `site == null` take the existing static-obstacle destruction path; post-shot power loss keeps **No power** instead of overwriting it with Ready/Engaging; the final emitter rechecks the target after power publication; the selected range stays visible on completion and keeps its gold color; identity/health labels clear the raised turret. Dedicated current checks cover preplaced cleanup, committed-shot power loss, invalid targets and selected-site completion. These statements describe saved edits and their later verification, not invented earlier failing runs. **No production or test edit was needed during this final collection.**

## Completed phases and exact commands

The [M14 launcher](../tools/validate-m14.ps1) calls the existing [fresh-copy runner](../tools/validate-m8.ps1) and [external timeout wrapper](../tools/run-godot.ps1). Each child uses installed Godot **4.7.2.stable.official.ed1daf0bf**, a **240-second external deadline**, and fixed 60 FPS for tests. Forty listed suites plus the gate-avoidance variant produce 41 executions per mode. Each phase has a fresh `project/`, `source-hashes.json`, `plan.json`, `results.json`, per-child `.ps1` invocation, stdout, stderr and combined log. No failed phase directory was overwritten.

Every phase below finished fresh import with exit 0. Checks include failed assertions; native lines are the runner's error/warning count. Each phase name links to its complete result rows and exact wrapper/engine arguments.

| Phase | Passing / completed tests | Checks | Failures | Native lines | Aggregate exit |
| --- | ---: | ---: | ---: | ---: | ---: |
| [m14-smoke-01](../validation-output/m8/m14-smoke-01/results.json) | 0 / 2 | 63 | 2 | 8 | 1 |
| [m14-smoke-02](../validation-output/m8/m14-smoke-02/results.json) | 0 / 2 | 262 | 2 | 9 | 1 |
| [m14-integration-dev-01](../validation-output/m8/m14-integration-dev-01/results.json) | 0 / 4 | 0 | 0 | 8 | 1 |
| [m14-integration-dev-02](../validation-output/m8/m14-integration-dev-02/results.json) | 0 / 4 | 0 | 0 | 8 | 1 |
| [m14-affected-dev-01](../validation-output/m8/m14-affected-dev-01/results.json) | 11 / 11 | 2120 | 0 | 0 | 0 |
| [m14-integration-dev-03](../validation-output/m8/m14-integration-dev-03/results.json) | 2 / 4 | 399 | 2 | 2 | 1 |
| [m14-integration-dev-04](../validation-output/m8/m14-integration-dev-04/results.json) | 2 / 2 | 137 | 0 | 0 | 0 |
| [m14-recovery-core-01](../validation-output/m8/m14-recovery-core-01/results.json) | 1 / 2 | 320 | 1 | 0 | 1 |
| [m14-recovery-core-02](../validation-output/m8/m14-recovery-core-02/results.json) | 2 / 2 | 320 | 0 | 0 | 0 |
| [m14-recovery-integration-ui-01](../validation-output/m8/m14-recovery-integration-ui-01/results.json) | 4 / 4 | 399 | 0 | 0 | 0 |
| [m14-final-matrix-01](../validation-output/m8/m14-final-matrix-01/results.json) | 81 / 82 | 10751 | 5 | 5 | 1 |

The final-source focused executions and single matrix were launched with these commands in PowerShell 7+, from the repository root. They are retained execution records; existing run names are deliberately refused if reused.

```powershell
& .\tools\validate-m8.ps1 -RunName m14-recovery-core-02 -TimeoutSeconds 240 -Modes @('headless') -Suites @('defense_checks', 'defense_boundary_checks')
# exit 0: import plus 320 checks
& .\tools\validate-m8.ps1 -RunName m14-recovery-integration-ui-01 -TimeoutSeconds 240 -Modes @('headless', 'graphical') -Suites @('defense_integration_checks', 'defense_ui_checks')
# exit 0: import plus 399 checks
& .\tools\validate-m14.ps1 -RunName m14-final-matrix-01 -TimeoutSeconds 240
# aggregate exit 1: import passes; 82 tests, 10,751 checks, five stress failures
```

The [final plan](../validation-output/m8/m14-final-matrix-01/plan.json) records the resolved engine, shell and full fresh-copy paths. For example, [headless integration's actual invocation](../validation-output/m8/m14-final-matrix-01/headless-defense_integration_checks.ps1) uses `--headless --path <fresh-copy> --fixed-fps 60 --script res://tests/defense_integration_checks.gd`; graphical omits only `--headless`. Import uses `--headless --path <fresh-copy> --editor --import`. Gate variants append `-- --avoidance`, and combat load executes `combat_checks.gd -- --combat-load`.

### Final matrix results

The [final summary](../validation-output/m8/m14-final-matrix-01/summary.json) was saved at **16:43:49 UTC** on September 9. It completed **41 headless + 41 graphical** tests and fresh import in **894.317 seconds** of total child time. Counts are **5,308 headless + 5,443 graphical = 10,751**. Defense's **1,040** and the other 74 executions' **9,711** are subsets of this total. Earlier focused runs and the M13 baseline are not added again.

Cells below show **checks / failures**. All engine/wrapper exits are **0** except graphical `movement_stress_checks` (**1**).

| Suite | Headless | Graphical |
| --- | ---: | ---: |
| defense_checks | 228 / 0 | 229 / 0 |
| defense_integration_checks | 68 / 0 | 69 / 0 |
| defense_ui_checks | 122 / 0 | 140 / 0 |
| defense_boundary_checks | 92 / 0 | 92 / 0 |
| power_checks | 175 / 0 | 175 / 0 |
| power_integration_checks | 49 / 0 | 50 / 0 |
| power_ui_checks | 180 / 0 | 200 / 0 |
| builder_checks | 314 / 0 | 323 / 0 |
| builder_integration_checks | 45 / 0 | 46 / 0 |
| supply_depot_checks | 272 / 0 | 284 / 0 |
| supply_depot_integration_checks | 80 / 0 | 81 / 0 |
| enemy_economy_checks | 96 / 0 | 98 / 0 |
| enemy_economy_integration_checks | 33 / 0 | 34 / 0 |
| attack_move_checks | 124 / 0 | 124 / 0 |
| attack_move_batch_checks | 155 / 0 | 155 / 0 |
| attack_move_ui_checks | 113 / 0 | 116 / 0 |
| hud_clarity_checks | 197 / 0 | 209 / 0 |
| milestone_checks | 127 / 0 | 131 / 0 |
| movement_repair_checks | 82 / 0 | 82 / 0 |
| parked_deadlock_checks | 14 / 0 | 14 / 0 |
| parked_deadlock_controls | 84 / 0 | 84 / 0 |
| captured_parked_cluster_checks | 10 / 0 | 10 / 0 |
| projection_step_checks | 32 / 0 | 32 / 0 |
| boundary_neighbor_checks | 23 / 0 | 23 / 0 |
| boundary_neighbor_controls | 193 / 0 | 193 / 0 |
| gate_movement_checks | 14 / 0 | 14 / 0 |
| gate_movement_checks-avoidance | 39 / 0 | 39 / 0 |
| construction_checks | 267 / 0 | 270 / 0 |
| construction_cleanup_checks | 46 / 0 | 46 / 0 |
| harvesting_checks | 298 / 0 | 299 / 0 |
| production_checks | 192 / 0 | 193 / 0 |
| combat_checks | 183 / 0 | 191 / 0 |
| combat_repair_checks | 230 / 0 | 230 / 0 |
| line_of_fire_checks | 305 / 0 | 308 / 0 |
| spherical_projectile_checks | 140 / 0 | 141 / 0 |
| movement_stress_checks | 122 / 0 | 131 / 5 |
| base_assault_checks | 124 / 0 | 130 / 0 |
| vehicle_production_checks | 225 / 0 | 230 / 0 |
| combat_load | 7 / 0 | 7 / 0 |
| tactical_interface_checks | 126 / 0 | 138 / 0 |
| control_group_checks | 82 / 0 | 82 / 0 |

## Remaining failures and limitations

**Required M14 feature failures: none remaining. Demonstrated newly introduced regressions: none established by the saved results.** All affected construction, builder, power, combat, line-of-fire, spherical projectile, production, harvesting, enemy economy, match-result and UI suites pass in both modes.

**Unknown attribution — open:** [graphical movement stress](../validation-output/m8/m14-final-matrix-01/graphical-movement_stress_checks.log) reports **131 checks / five failures / engine and wrapper exit 1**. The first failed assertion is `choke_50: all units arrive within configured tolerance`; gate traversal and settling also fail. `cluster_50` then fails arrival and settling. Saved `ROUTE_DETAIL` identifies **unit 7**, state FAILED after eight recovery attempts, at `(-2.85, 0, -1.256918)` for both routes, with destinations `(7, 0, -3)` and `(24, 0, 23.5)`. The five native error lines are the same five assertions reported by `push_error`, not five additional independent failures. Headless stress passes 131/131. The source-matched passing M13 baseline does not establish this occurrence's cause; it is neither labelled pre-existing nor proven to be introduced by M14. The full matrix is **FAIL**, and this occurrence is preserved without retry or movement investigation.

**Accepted historical interface exception:** the original M12 group-3 occurrence remains OPEN / UNKNOWN and M12 criterion 7 NOT VERIFIED. Current M14 Attack Move UI, groups and battery-to-army checks passing do not repair that historical occurrence. **Deferred movement findings:** the existing records remain unresolved, separate from this newly recorded unknown-attribution execution. No historical acceptance is changed.

This remains a fully revealed primitive prototype with one ground-only hitscan defense. There is no aircraft/air defense, stance system, manual turret target, defense rebuilding AI, repair/sale, extra weapon mode or new strategic behavior. The integrated economic fixture isolates wave timing as disclosed above; normal-scene timing is independently checked. Automated viewport input and rendered inspection are not human keyboard-and-mouse playtesting.

## Source correspondence, reused evidence and visual handoff

The last disconnect did not stop the matrix. Recovery found its completed summary and every requested child result; no Godot or validation process remained running. No duplicate engine run was launched, unrelated terminals were left alone, and no process was terminated. [Saved progress checkpoints](../validation-output/m14/finalization-progress.md) record the collection and finalization.

At recovery the final matrix's **337-file manifest exactly matched all current tracked and untracked source files**. All 11 phase snapshots were independently rehashed against their saved manifests and are intact. After this handoff, differences from the final matrix are limited to **README.md, docs/roadmap.md and this report**. Runtime, scenes, resources, test fixtures/suites, runner scripts and UID sidecars remain the tested versions. The final [source manifest](../validation-output/m8/m14-final-matrix-01/source-hashes.json), [starting tracked diff](../validation-output/m8/m14-final-matrix-01/starting-diff.patch) and [starting status](../validation-output/m8/m14-final-matrix-01/starting-status.txt) preserve the implementation; new files are also present in the hashed snapshot.

**Reused:** the completed final matrix supplies acceptance without another run. Core 02 and recovery integration/UI also match final source, except the three documentation edits. Their 320 and 399 checks corroborate the corrections but are not extra unique coverage in the final total. Dev 04's earned pass predates a battery change; dev 03's UI pass also predates battery changes. Both remain development evidence superseded by final-source recovery/matrix results. Affected dev 01's 2120 checks predate battery/emitter/test changes and are not used to certify final dependencies. **Post-change verification:** the saved core 02 reran the corrected work-position assertion; recovery integration/UI and then the matrix tested the final integration. This collection made documentation changes only, requiring no further gameplay rerun.

The prior lead's saved inspection calls explicitly viewed the eight recovery captures linked below after the label/range corrections. That run's complete relevant source matches the final matrix, so those inspections are reused. No replacement visual inspection was needed during final collection. Both the recovery UI run and final matrix saved **18 normal-scene UI captures**: builder, placement preview, selected unpowered battery and restarted opening, each with Help collapsed/expanded at both sizes, plus result overlays at both sizes. The final [handoff audit](../validation-output/m14/final-handoff-checks.json) lists all 18 matrix PNG dimensions and SHA-256 values. Matrix captures are additional retained renders, not a claim of 18 new visual inspections.

| Reused inspected view | 1280×720 | 1920×1080 |
| --- | --- | --- |
| Selected completed battery, low-power panel and range | [720p](../validation-output/m8/m14-recovery-integration-ui-01/artifacts/graphical-defense_ui_checks/m14/screenshots/defense_normal_selected_no_power_1280x720.png) | [1080p](../validation-output/m8/m14-recovery-integration-ui-01/artifacts/graphical-defense_ui_checks/m14/screenshots/defense_normal_selected_no_power_1920x1080.png) |
| Selected battery with expanded Help | [720p](../validation-output/m8/m14-recovery-integration-ui-01/artifacts/graphical-defense_ui_checks/m14/screenshots/defense_normal_selected_no_power_help_1280x720.png) | [1080p](../validation-output/m8/m14-recovery-integration-ui-01/artifacts/graphical-defense_ui_checks/m14/screenshots/defense_normal_selected_no_power_help_1920x1080.png) |
| Builder choices with expanded Help | [720p](../validation-output/m8/m14-recovery-integration-ui-01/artifacts/graphical-defense_ui_checks/m14/screenshots/defense_normal_builder_help_1280x720.png) | Covered by automated layout checks |
| Actual placement preview and range | Covered by automated layout checks | [1080p](../validation-output/m8/m14-recovery-integration-ui-01/artifacts/graphical-defense_ui_checks/m14/screenshots/defense_normal_preview_1920x1080.png) |
| Victory and Restart button | [720p](../validation-output/m8/m14-recovery-integration-ui-01/artifacts/graphical-defense_ui_checks/m14/screenshots/defense_normal_result_1280x720.png) | Covered by automated layout checks |
| Restarted opening with expanded Help | Covered by automated layout checks | [1080p](../validation-output/m8/m14-recovery-integration-ui-01/artifacts/graphical-defense_ui_checks/m14/screenshots/defense_normal_restart_help_1920x1080.png) |

## Important files and final repository checks

- [GroundDefenseBattery](../scripts/ground_defense_battery.gd), [scene field](../scripts/defense_assault_field.gd), [scene](../scenes/defense_assault.tscn), [construction resource](../construction/ground_defense_battery.tres) and [weapon resource](../weapons/ground_defense.tres): stationary body, fixed configurable defaults, turret/acquisition/lifetime, and opt-in scenario.
- Existing construction definition/manager/field and RTSBuilding add paid battery construction, nonproducer registration and normal footprint cleanup. Existing power grid/production field provide binary current-power firing authority independently of producer slowdown.
- Existing team rules, weapon emitter, line of fire, feedback and combat controller accept the stationary source, preserve authoritative geometry/lifetime checks and normal incoming attacks/retaliation.
- Existing placement/construction/production panels, Help and minimap expose builder choice, temporary range, compact power feedback and the G marker.
- [Mechanics](../tests/defense_checks.gd), [callback boundaries](../tests/defense_boundary_checks.gd), [integration](../tests/defense_integration_checks.gd), [UI](../tests/defense_ui_checks.gd), [shared labelled fixtures](../tests/fixtures/defense_harness.gd) and [M14 runner](../tools/validate-m14.ps1) preserve focused regressions and the full matrix. Existing untracked UID sidecars are preserved.

Final documentation validation uses the already-saved checker:

```powershell
git diff --check
& .\validation-output\m14\final-handoff-checks.ps1
```

**Final checks: PASS, exit 0.** The [machine-readable audit](../validation-output/m14/final-handoff-checks.json) saves every local Markdown link/anchor result across the three handoff documents, git whitespace output/exit, all 11 immutable snapshot comparisons, current hashes, final-source differences, matrix totals and 18 PNG hashes/dimensions. Only the three handoff documents differ from the tested snapshot. No commits, tags, engine/dependency changes, discarded changes, new review wave or aircraft/air-defense work were performed. Validation artifacts remain in the existing ignored `validation-output/` tree and must be retained with this local handoff.
