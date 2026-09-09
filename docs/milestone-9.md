# Milestone 9 — Attack-move commands

**Status: COMPLETE (2026-09-08).** All eight acceptance groups pass automated validation. Final coverage is 50 reused matrix executions / 6,277 checks plus six post-layout executions / 855 checks: **56 executions / 7,132 passing checks**, zero failures or native error lines, all exits 0. The original complete matrix independently recorded 56 executions / 7,116 checks before the Help correction. Milestone 8.1 remains COMPLETE. No human keyboard-and-mouse playtest has occurred; Milestone 10 is not started.

## Scope and baseline

The user authorized attack-move for existing Rifle Units and Rocket Vehicles in `res://scenes/combined_arms_assault.tscn`. The original request is retained locally in Codex attachment `eec63ea2-903b-44a9-911b-2c9980c0ece6/pasted-text.txt`.

Work began on clean revision `f694f901d4ecb4fbf2a6fe754883516284bf1bbb`. No applicable AGENTS.md was found in the repository or directory ancestors. README, roadmap, M8/M8.1 reports, movement limitations and the actual command, combat, ownership, navigation, minimap, HUD and match lifecycle paths were read.

The [starting source comparison](../validation-output/m9/starting-baseline.json) checked all 261 entries of the corrected M8.1 snapshot. Only README and the final M8.1 report differ. All runtime, scenes, resources, tests, configuration and runners match. The accepted baseline is therefore the saved 18 post-fix executions / 3,146 passing checks plus four unchanged combat/line-of-fire executions / 987 passing checks. These are reused baseline evidence, not new M9 executions. The completed M8.1 review and its 12 captures were not repeated.

The installed engine and dependencies remain unchanged. No commit, tag, installation, upgrade or discarded work is part of this task. Movement issues stay [deferred and unresolved](movement-issue-records.md); their historical failures are not erased by this feature.

## Play, behavior and configuration

Open [scenes/combined_arms_assault.tscn](../scenes/combined_arms_assault.tscn) and press **F6**, or run from the repository root:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/combined_arms_assault.tscn
```

F5 still starts the original `scenes/test_field.tscn`; it is not the attack-move playable scene.

Attack Move uses a contextual button or Q (verified unused); A remains camera pan. Pending targeting accepts battlefield or minimap ground, cancels with right-click/Escape and replaces orders only after accepted dispatch. Ordinary Move, explicit Attack, Stop, control groups and collector work retain their existing semantics.

The coordinator retains the clicked destination, assigned final slot and parent identity while existing navigation and combat own motion and firing. It scans only for an active attack-move order and resumes final travel after a temporary engagement. No idle acquisition, stance, patrol, strategic AI, fog of war, flanking or movement rewrite is included.

| New setting | Default |
| --- | --- |
| Acquisition interval | 0.25 simulated seconds |
| Acquisition radius | 12 world units |
| Engagement leash from acquisition position | 16 world units |
| Continuous blocked-fire abandonment | 2 simulated seconds |
| Per-order temporary target ignore | 3 simulated seconds |

Q and the contextual **Attack Move · Q** button activate targeting only for eligible selections outside placement and frozen results. The panel shows a destination hint and right-click/Escape cancellation. Valid battlefield/minimap left-clicks use `TestField.issue_attack_move`; invalid terrain leaves targeting and prior orders intact. GUI/modal clicks, consumed or repeated keys, focus loss, ineligible selection and queued confirmations are covered by viewport tests. Open Help retains its existing Escape-close priority. F1 Help describes the new control and ordinary Move distinction. The default camera viewport remains 1280×800; required layout captures exercise actual unscaled windows at 1280×720 and 1920×1080.

Only living, registered, locally controlled combat-capable mobile actors participate. Mixed batches retain all intended mobile identities but assign slots and accepted identities only to eligible units; collectors preserve cargo, harvesting generation and movement orders. Nearest horizontal distance selects an initially unobstructed hostile, with stable identity breaking ties. Units and damageable registered buildings use the same ownership and weapon-clearance rules as manual combat. Acquisition can start outside weapon range; existing pursuit, facing, cooldowns, damage and projectiles remain authoritative.

Move, explicit Attack, X Stop and a replacement Attack Move take precedence after acceptance. Group recall changes selection without changing orders. An automatic engagement keeps its parent identity and reserved final slot, including when other units receive Move orders. Death/departure, leash escape, bounded pursuit failure and continuous obstruction release the engagement. Abandonment records a weak, per-order ignore entry; expiry or target departure cleans it. Final movement failure terminates the parent without claiming arrival or retrying indefinitely. Result freeze and Restart clear pending input, parents, targets, timers, ignores and old match references.

| Important changed files | Role |
| --- | --- |
| `scripts/attack_move_order.gd` | Parent intent, bounded acquisition, release/ignore state and final travel coordination |
| `scripts/test_field.gd` | Shared batch acceptance, eligibility, final-slot generation/reservation and supersession guards |
| `scripts/rts_unit.gd`, `scripts/combat_controller.gd` | Coordinator creation, internal/manual command distinction, source/target callback safety |
| `scripts/collector_truck.gd`, `tests/full_sequence_probe.gd` | Compatible forwarding movement signatures; existing work/diagnostic behavior retained |
| `scripts/selection_controller.gd`, `scripts/tactical_minimap.gd`, `project.godot` | Q/viewport/minimap input, cancellation and pending-input lifetime |
| `scripts/production_panel.gd`, `scripts/rts_help_panel.gd` | Contextual action, activity/hint text, Help and observer cleanup |
| `scripts/base_assault_field.gd`, `scenes/combined_arms_assault.tscn` | Playable opt-in and result/Restart integration |
| `tests/attack_move_checks.gd`, `tests/attack_move_batch_checks.gd`, `tests/attack_move_ui_checks.gd`, `tests/fixtures/attack_move_field.gd` | Real physics, batches/callbacks, viewport/paid production and a small dedicated fixture |

`move_to(destination, combat_pursuit = false, preserve_attack_move = false)` has matching base, collector and full-sequence diagnostic signatures. Existing one/two-argument callers retain their defaults. Collectors have no armed coordinator. Only internal initial/resumed final travel passes `(slot, false, true)`; combat pursuit keeps `(destination, true)` and its existing recovery history. Manual combat uses the normal default cancellation path. Projection, avoidance, collision, recovery budgets, weapon resources, production resources and starting forces were not changed.

## Acceptance record

| Requirement | Status | Evidence |
| --- | --- | --- |
| 1. Attack-move input and accurate batch acceptance | PASS | Original matrix core/batch suites in both modes; post-layout UI button/Q, battlefield/minimap confirmation, invalid input and cancellation. NONE/PARTIAL/COMPLETE, stable intended/accepted identities and synchronous supersession tested. |
| 2. Automatic eligible-target acquisition | PASS | Original core: units/buildings, shared ownership/registry, radius, clear line of fire, acquisition outside weapon range, nearest/stable tie-break and retained target; no idle scanning. |
| 3. Real engagement followed by resumed final travel | PASS | Original core Rifle/mixed engagements and empty routes; post-layout paid production records damage, physical resumed travel and original distinct slot arrival separately for both produced units. |
| 4. Leash, obstruction abandonment and bounded failure | PASS | Original core: 16-unit leash, 2-second continuous blockage, ignore/expiry, pursuit release and deliberately enclosed final travel failure under unchanged recovery limits. No false arrival or endless retry. |
| 5. Manual-command precedence and mixed-selection safety | PASS | Original core/batch: Move, explicit Attack, Stop and replacement parent; rejected replacements, collectors' cargo/work, reserved slots and callback guards. Post-layout UI preserves ordinary minimap/group behavior. |
| 6. Lifecycle, callbacks, freeze and Restart | PASS | Original core/batch death, immediate free, departure, ownership and newer-order callbacks; post-layout UI/HUD result freeze, pending scan/input, ignore state, old references and exact fresh-match defaults. |
| 7. Preserved HUD, minimap, groups and existing gameplay | PASS | Post-layout HUD/UI/tactical suites in both modes; expanded/collapsed Help at both required sizes, actual outer rectangles, input isolation, placement, focus, contextual controls and Restart. Unaffected normal regression results reused. |
| 8. Focused/integration validation and honest failure reporting | PASS | Completed original matrix and affected reruns, verified source hashes, saved logs/captures, retained earlier failures below, final whitespace/link audit. Human playtest is not claimed. |

## Validation provenance

One lead owned Godot execution through the existing `tools/validate-m8.ps1` and `tools/run-godot.ps1`: fresh source copies, SHA-256 manifests, 60 fixed physics steps per simulated second, saved per-execution commands/logs and 240-second external deadlines. The completed matrix contains the 48 normal regression executions plus six attack-move and two HUD executions. Actual totals below were read from `results.json`, reconciled against each plan and summary, and never inferred from suite names.

Final recovery found both the original matrix and later post-layout run completed, with no Godot/validation process remaining. No duplicate run, unrelated process termination, additional reviewer or historical movement investigation was needed. The last continuation changed only this report, README and roadmap, then ran the saved source/results/link audit.

### Implementation execution history (retained)

| Phase | Saved result | Attribution / correction |
| --- | --- | --- |
| [m9-focused-01](../validation-output/m8/m9-focused-01/results.json) | Import exited 0 but emitted 11 error lines; tests not run | New optional `move_to` argument required compatible forwarding signatures in CollectorTruck and the retained full-sequence probe. No harvesting logic, recorder capability or old assertion changed. |
| [m9-focused-02](../validation-output/m8/m9-focused-02/results.json) | Import PASS; batch 87/87 PASS; core test parse exit 1 / 2 error lines before checks | Test-only `weakref` local required explicit WeakRef type under warnings-as-errors. |
| [m9-focused-03](../validation-output/m8/m9-focused-03/results.json) | Both modes: core 124 checks / 2 failures each; UI 65 checks / 3 failures and 2 error lines each; all four test exits 1 | Blocked-release timing defect plus two isolated test-fixture defects, described below. All four failures remain saved. |
| [m9-focused-04](../validation-output/m8/m9-focused-04/results.json) | Fresh import PASS; headless core 124/124 PASS, no errors | Corrected scan/blocked-duration comparisons verified, including real damage/resume and deliberately unreachable travel. |
| [m9-focused-05](../validation-output/m8/m9-focused-05/results.json) | Fresh import PASS; core 124/124 in each mode; UI 85/85 headless and 87/87 graphical; batch 155 checks / 1 failure / 1 native error in each mode, exit 1 | Corrected produced-army and lifecycle fixtures passed. The added combat-callback test captured a deliberately freed target in a lambda; weak references now resolve only during the intended callback. Gameplay assertions were preserved. |
| [m9-focused-06](../validation-output/m8/m9-focused-06/results.json) | Fresh import PASS; all eight test executions PASS, 1,542 checks, no failures/errors, exit 0 | Batch 155/155 in each mode; HUD 193/193 headless and 205/205 graphical; combat 183/183 and 191/191; combat repair 230/230 in each mode. All 267 saved source hashes matched the recovered workspace. |

The initial scan comparison accumulated 15 fixed physics steps just below 0.25, effectively scanning every 16 ticks; blocked release missed the test's bounded deadline. A one-microsecond comparison tolerance now preserves the configured 0.25-second period and 2-second continuously observed blockage threshold. It changes no weapon or movement settings. Clearance is still sampled, so obstruction onset/release has bounded scan-interval observation latency.

The first UI lifecycle fixture placed its attacker inside a real supply-cache footprint, preventing the required clear firing line. Its isolated source/target positions were moved to clear southern ground. The first paid integration sent two produced units against three ordinary defenders; both dealt damage and resumed travel, but a produced unit died. Typed array predicates then tried to accept a freed object. The revised fixture uses the existing three starting Rifles as escorts through ordinary Move/group commands, preserves the requirement that both produced units inflict damage and reach their original slots, and checks validity before typed access. No units are spawned for that integration, and no health, weapon, movement, cost or timing values are changed. Its explicitly configured 2000-credit/600-second instance avoids repeating the separate harvesting campaign; normal playable defaults remain 1000 credits and 90 seconds.

Resume recovery on 2026-09-08 established that the exact `m9-focused-06` wrapper completed at 00:08:51 local time; its final summary, eight logs and tested-source copy exist, and no Godot/validation process remained. There were no later M9 runs. The older 87-check batch result does not describe the current 155-check test. The `m9-focused-05` source differs only in this report, the batch weak-reference correction and the pending-HUD feedback correction; its screenshots predate removal of the ordinary right-click command hint while targeting.

The resume strengthens only the existing produced-army fixture: each produced identity now separately records a real temporary engagement and more than 0.5 world units of subsequent physical travel, and both original final slots must remain separated by normal formation spacing. The existing damage, arrival, accounting, group, result and Restart assertions remain. A graphical produced-army arrival capture was added alongside the pending-target captures. No runtime, fixture positions, health, weapons, movement, production values or deadlines changed during this resume.

The interrupted transcript's running-matrix checkpoint is superseded by the completed results below. Its early headless progress and produced-unit observations remain consistent with the actual completed logs.

### Help correction and completed closure (2026-09-08)

Recovered the completed original matrix: 56/56 executions, 7,116 checks, zero failures/native errors; all per-execution exits 0. Its final summary was saved at 00:25:51 local time. No Godot/validation process remained and no later M9 run existed. SHA-256 comparison of all 267 captured files found only this report and the strengthened HUD assertion different; the runtime Help correction had not been saved. The original expanded 1280x720 capture confirms overlap at the objective outer edge, so the old HUD pass is insufficient for final acceptance.

The saved runtime correction reduces Help section spacing from 10 to 6 pixels while retaining all instructions and 14px text. Regression bounds use the actual outer PanelContainer and transform all rectangles into viewport coordinates after eight settling frames. Expanded Help must retain 12px clearance and fully enclosed, unclipped instructions. Attack-move UI checks explicitly cover body-click isolation, Close Help and two-stage Escape with pending targeting and an active parent. The produced-unit damage, physical post-engagement displacement and original distinct slot assertions remain unchanged. HUD, attack-move UI and tactical-interface suites completed once in each mode on a fresh snapshot; no unrelated combat/movement suite was rerun after this correction.

The [post-layout graphical HUD log](../validation-output/m8/m9-layout-final-01/graphical-hud_clarity_checks.log) records expanded Help at `(20,20)` with size `(441,586)`: its bottom is 606. The objective's outer panel starts at y=618 at 1280x720 and y=978 at 1920x1080, giving **12px and 372px clearance**. Collapsed Help is `(20,20,205,55)` at both sizes. Minimap, context and objective outer rectangles are fully inside the actual viewport and mutually clear. Placement/focus rules, released battlefield area after closing, result overlay and clickable Restart all pass. Eight current saved captures were visually inspected during final recovery (identified below); no new captures were needed.

### Source covered by each result

Both runs captured 267 source files from uncommitted M9 work on base revision `f694f901d4ecb4fbf2a6fe754883516284bf1bbb`; that base revision alone does not identify the tested feature. Use each immutable project copy and manifest:

| Run | Tested source and evidence | Relationship to final workspace |
| --- | --- | --- |
| `m9-final-matrix-01` | [Project](../validation-output/m8/m9-final-matrix-01/project), [hashes](../validation-output/m8/m9-final-matrix-01/source-hashes.json), [results](../validation-output/m8/m9-final-matrix-01/results.json), [summary](../validation-output/m8/m9-final-matrix-01/summary.json), [wrapper log](../validation-output/m9/final-matrix-01-wrapper.log) | Predates the section-spacing correction, outer-panel HUD assertions and four Help/targeting UI checks. All other runtime, scene, resource, configuration, tests and runners match. Documentation subsequently changed. |
| `m9-layout-final-01` | [Project](../validation-output/m8/m9-layout-final-01/project), [hashes](../validation-output/m8/m9-layout-final-01/source-hashes.json), [results](../validation-output/m8/m9-layout-final-01/results.json), [summary](../validation-output/m8/m9-layout-final-01/summary.json), [wrapper log](../validation-output/m9/layout-final-01-wrapper.log) | Contains the final runtime and strengthened tests exactly. Only README, roadmap and this completed report differ at handoff. |

The [final audit](../validation-output/m9/final-audit.json) verifies both captured copies against all saved hashes and checks for uncaptured source files. It also verifies that the produced-unit integration function is unchanged from the original matrix. Only Help's section spacing changed in runtime after that matrix; no movement, combat, production, batch authority, input handler or match-lifecycle dependency changed. Therefore the 50 executions outside HUD/UI/tactical remain valid. The six old HUD/UI/tactical results (839 checks) are retained as historical outcomes and replaced in final coverage by the six post-layout executions (855 checks). The original HUD pass did not detect its visual overlap and is not used to claim corrected layout acceptance.

### Actual complete matrix and affected reruns

The original matrix finished at **2026-09-08 00:25:51 America/Indianapolis**; the affected run finished at **00:32:56**. Each fresh import passed with exit 0 and no native errors. Imports are excluded from test-execution/check totals.

| Evidence set | Test executions | Checks | Failures / native error lines | Exit codes |
| --- | --- | --- | --- | --- |
| Original complete matrix | 56/56 PASS | 7,116 | 0 / 0 | All 0; phase 0 |
| Reused original results after dependency comparison | 50 PASS | 6,277 | 0 / 0 | All 0 |
| Post-layout affected run | 6/6 PASS | 855 | 0 / 0 | All 0; phase 0 |
| Final coverage (reuse + replacements, no double-counting) | 56 PASS | 7,132 | 0 / 0 | All 0 |

Post-layout executions:

| Suite | Headless checks / exit | Graphical checks / exit |
| --- | --- | --- |
| HUD clarity | 197 / 0 | 209 / 0 |
| Attack-move UI, including paid integration | 91 / 0 | 94 / 0 |
| Tactical interface | 126 / 0 | 138 / 0 |

Every post-layout execution has zero failed checks/native errors. There are **no unresolved M9 failures or unknown-attribution failures**. Earlier failed imports/tests remain in the implementation history and their original artifacts; they are not reclassified as deferred movement issues.

### Produced-unit evidence

The post-layout [headless UI log](../validation-output/m8/m9-layout-final-01/headless-attack_move_ui_checks.log) and [graphical UI log](../validation-output/m8/m9-layout-final-01/graphical-attack_move_ui_checks.log) independently record:

| Normally produced actor | Damage dealt in each mode | Physical travel after release, headless / graphical | Original final slot reached in each mode |
| --- | --- | --- | --- |
| Rifle, identity 9 | 100 HP | 10.2943 / 10.2711 world units | `(24.00001, 0, 6.499998)` |
| Rocket, identity 10 | 32 HP | 12.6538 / 12.6505 world units | `(25.50001, 0, 7.999998)` |

Both acquire real temporary targets, survive, return to their captured slots and stop; their slots remain separated by at least the normal 1.5-unit formation spacing. Three encountered hostiles die. Damage attribution counts only the two paid produced identities; each also has its own post-engagement displacement witness exceeding 0.5 units, so escorts or activity labels cannot satisfy the checks. The existing three starting Rifles accompany the produced pair through ordinary staging/group commands. Construction and queues spend exactly 1,350 credits, leaving 650 of the fixture's configured 2,000. The final HQ destruction uses the documented test damage call to exercise normal result/Restart paths; it is not claimed as an unaided campaign victory. Existing tactical/base-assault checks supply their separate full-health combat coverage.

### Current captures and tested sizes

These are saved captures from the final source in `m9-layout-final-01/artifacts`, not the user-supplied collapsed-Help screenshot or earlier M8.1 images. Rendering uses actual unscaled **1280x720 and 1920x1080** windows. The audit records dimensions and SHA-256 hashes for all 12 HUD and three M9 UI captures listed here. An asterisk denotes a capture visually inspected during this final recovery; all listed captures have successful automated save/dimension checks.

| View | 1280x720 capture | 1920x1080 capture |
| --- | --- | --- |
| Expanded Help | [help*](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/help_1280x720.png) | [help*](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/help_1920x1080.png) |
| Collapsed Help / initial HQ | [initial*](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/initial_1280x720.png) | [initial*](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/initial_1920x1080.png) |
| Help with placement | [placement](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/help_placement_1280x720.png) | Not separately captured |
| Mixed selection | [mixed](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/mixed_1280x720.png) | Not separately captured |
| Nine groups | [groups](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/nine_groups_1280x720.png) | [groups](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/nine_groups_1920x1080.png) |
| Production context | [production](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/production_1280x720.png) | [production](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/production_1920x1080.png) |
| Result / accessible Restart | [victory*](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/victory_1280x720.png) | Not separately captured |
| Fresh Restart | [restarted](../validation-output/m8/m9-layout-final-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/restarted_1280x720.png) | Not separately captured |
| Attack-move pending hint | [targeting*](../validation-output/m8/m9-layout-final-01/artifacts/graphical-attack_move_ui_checks/m9/screenshots/targeting_1280x720.png) | [targeting*](../validation-output/m8/m9-layout-final-01/artifacts/graphical-attack_move_ui_checks/m9/screenshots/targeting_1920x1080.png) |
| Produced Rifle/Rocket arrival | [produced army*](../validation-output/m8/m9-layout-final-01/artifacts/graphical-attack_move_ui_checks/m9/screenshots/produced_army_1280x720.png) | Not separately captured |

### Known limitations

Historical crowd/gate/projection movement issues remain [deferred and unresolved](movement-issue-records.md). Passing the normal M9 regression matrix does not establish full historical movement or Milestone 5 acceptance. Final destination failure remains bounded by existing navigation recovery; attack-move does not promise to solve all routes.

Acquisition uses the fully revealed field registry and existing static-blocker firing policy, with scan-interval observation latency and no reposition/flanking search. Its 16-unit leash is measured from the attacker at acquisition. HUD verification covers the two required unscaled sizes and existing theme/font; smaller windows, unusual DPI/UI scaling and localization expansion are not verified. Human keyboard-and-mouse playtesting is **NOT VERIFIED / not performed**; all eight required automated acceptance groups pass. The paid integration's configured credits/assault delay and final HQ damage call are fixture choices, not changes to playable defaults.

No commit/tag, engine/dependency change, unrelated work discard, M8.1 reopening or Milestone 10 work occurred.

### Original matrix execution inventory

These are the actual saved original results, including the six superseded layout/input executions. Each row has zero failures/native error lines in both modes. Headless and graphical counts differ where capture/render checks apply.

| Suite | Headless checks / exit | Graphical checks / exit | Final coverage |
| --- | --- | --- | --- |
| `attack_move_checks` | 124 / 0 | 124 / 0 | Reused |
| `attack_move_batch_checks` | 155 / 0 | 155 / 0 | Reused |
| `attack_move_ui_checks` | 87 / 0 | 90 / 0 | Replaced by post-layout results |
| `hud_clarity_checks` | 193 / 0 | 205 / 0 | Replaced by post-layout results |
| `milestone_checks` | 127 / 0 | 131 / 0 | Reused |
| `movement_repair_checks` | 82 / 0 | 82 / 0 | Reused |
| `parked_deadlock_checks` | 14 / 0 | 14 / 0 | Reused |
| `parked_deadlock_controls` | 84 / 0 | 84 / 0 | Reused |
| `captured_parked_cluster_checks` | 10 / 0 | 10 / 0 | Reused |
| `projection_step_checks` | 32 / 0 | 32 / 0 | Reused |
| `boundary_neighbor_checks` | 23 / 0 | 23 / 0 | Reused |
| `boundary_neighbor_controls` | 193 / 0 | 193 / 0 | Reused |
| `gate_movement_checks` | 14 / 0 | 14 / 0 | Reused |
| `gate_movement_checks-avoidance` | 39 / 0 | 39 / 0 | Reused |
| `construction_checks` | 267 / 0 | 270 / 0 | Reused |
| `construction_cleanup_checks` | 46 / 0 | 46 / 0 | Reused |
| `harvesting_checks` | 298 / 0 | 299 / 0 | Reused |
| `production_checks` | 192 / 0 | 193 / 0 | Reused |
| `combat_checks` | 183 / 0 | 191 / 0 | Reused |
| `combat_repair_checks` | 230 / 0 | 230 / 0 | Reused |
| `line_of_fire_checks` | 305 / 0 | 308 / 0 | Reused |
| `spherical_projectile_checks` | 140 / 0 | 141 / 0 | Reused |
| `movement_stress_checks` | 122 / 0 | 131 / 0 | Reused |
| `base_assault_checks` | 124 / 0 | 130 / 0 | Reused |
| `vehicle_production_checks` | 225 / 0 | 230 / 0 | Reused |
| `combat_load` | 7 / 0 | 7 / 0 | Reused |
| `tactical_interface_checks` | 126 / 0 | 138 / 0 | Replaced by post-layout results |
| `control_group_checks` | 82 / 0 | 82 / 0 | Reused |
| **Total** | **3,524 / all 0** | **3,592 / all 0** | **28 executions per mode** |

### Exact validation commands and final file checks

The commands below reconstruct the completed phase invocations from their saved plans; they were not rerun during the final documentation recovery. Existing phase directories are immutable and the runner refuses to overwrite them. The [original plan](../validation-output/m8/m9-final-matrix-01/plan.json) and [post-layout plan](../validation-output/m8/m9-layout-final-01/plan.json) retain every exact engine argument. Each execution also retains its exact `.ps1` wrapper next to its logs, for example the [original import command](../validation-output/m8/m9-final-matrix-01/import.ps1) and [final graphical UI command](../validation-output/m8/m9-layout-final-01/graphical-attack_move_ui_checks.ps1).

Working directory: `D:\GitHub\Command_and_Concur_Generals`; PowerShell 7, installed Godot 4.7.2. Both phase exits were 0. Fresh imports use `--headless --editor --import`; tests use `--fixed-fps 60`, adding `--headless` for that mode. The wrapper enforces a 240-second external deadline per process.

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$suites = @(
    'attack_move_checks', 'attack_move_batch_checks', 'attack_move_ui_checks',
    'hud_clarity_checks', 'milestone_checks', 'movement_repair_checks',
    'parked_deadlock_checks', 'parked_deadlock_controls', 'captured_parked_cluster_checks',
    'projection_step_checks', 'boundary_neighbor_checks', 'boundary_neighbor_controls',
    'gate_movement_checks', 'construction_checks', 'construction_cleanup_checks',
    'harvesting_checks', 'production_checks', 'combat_checks',
    'combat_repair_checks', 'line_of_fire_checks', 'spherical_projectile_checks',
    'movement_stress_checks', 'base_assault_checks', 'vehicle_production_checks',
    'combat_load', 'tactical_interface_checks', 'control_group_checks'
)
& .\tools\validate-m8.ps1 -RunName 'm9-final-matrix-01' -GodotPath $godot -TimeoutSeconds 240 -Modes @('headless', 'graphical') -Suites $suites
# $LASTEXITCODE = 0

$suites = @(
    'hud_clarity_checks', 'attack_move_ui_checks', 'tactical_interface_checks'
)
& .\tools\validate-m8.ps1 -RunName 'm9-layout-final-01' -GodotPath $godot -TimeoutSeconds 240 -Modes @('headless', 'graphical') -Suites $suites
# $LASTEXITCODE = 0

```

Final recovery ran the existing saved audit after completing README, roadmap and this report:

```powershell
python validation-output/m9/verify-handoff.py
# Exit 0. Internally runs git diff --check, also exit 0.
```

The [audit JSON](../validation-output/m9/final-audit.json) records source comparisons, computed matrix/reuse/rerun totals, capture hashes/dimensions and documentation-link counts for all three updated documents, including Markdown anchors. It reports no broken links, uncaptured source files, corrupt snapshot hashes or runtime/test differences from the final tested copy. The [whitespace-check log](../validation-output/m9/git-diff-check.log) records exit 0; Git line-ending notices are informational. Earlier implementation failures remain listed above. All required work is complete and saved before the chat handoff.
