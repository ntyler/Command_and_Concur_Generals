# Milestone 13 — Power Plants and power management

**Milestone 13: COMPLETE (2026-09-09).** All eight acceptance groups PASS. The single final fresh-copy matrix completed **74/74 executions, 9,711 checks, zero failures/native errors, exit 0**. Job continuity is verified: the original job completed legitimately, and the corrected fixture follows stable IDs through deployment and a separate mid-job power transition. No production-code correction was required. Historical interface and movement exceptions remain open; no human playtest occurred.

## Playable extension

Open [Power Assault](../scenes/power_assault.tscn) in the installed Godot 4.7.2 and press **F6**, or run from the repository root:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/power_assault.tscn
```

The player starts with the existing HQ, selected Bulldozer, three Rifles and 1000 credits, without a Power Plant, collectors or production buildings. Build a Supply Depot for 300 credits, produce a Collector for 200, and harvest through the existing loading, travel and deposit systems. A Barracks or Factory may be built before a plant; there is no power prerequisite. F5 and all earlier scenes keep their previous entry points and opt out of power penalties.

Select exactly one owned Bulldozer and choose **Build Power Plant**. Left-click valid ground to pay and assign construction. The free preview, travel and unfinished site generate nothing. X Stop or a ground Move pauses work; select a builder and right-click the owned unclaimed unfinished site to resume. Selecting the unfinished site exposes normal full-price cancellation. One unfinished site remains the limit. A completed plant cannot be cancelled, sold or refunded.

## Configuration and behavior

| Building | Construction cost / working time | Generated | Required |
| --- | --- | --- | --- |
| Power Plant | 500 credits / 10 simulated seconds | 10 | 0 |
| Barracks | Unchanged: 400 credits / 10 seconds | 0 | 2 |
| Vehicle Factory | Unchanged: 600 credits / 15 seconds | 0 | 4 |
| HQ | Unchanged | 0 | 0 |
| Supply Depot | Unchanged: 300 credits / 10 seconds | 0 | 0 |

Nominal power lives in the configurable [construction definitions](../scripts/construction_definition.gd) and their resources, including [Power Plant](../construction/power_plant.tres). Runtime totals are separate. Units consume no power. Plants use a 6×5 committed footprint, a distinct original twin-transformer primitive, and the ordinary navigation/weapon blocker. Completed plants inherit **450 HP** from the existing non-HQ assault-building convention. Partial damage does not reduce output. Unfinished sites retain the existing immunity and cancellation policy. Plants have no unit recipe/queue and are not victory objectives.

Generation greater than or equal to required power is **NORMAL**, including 0/0. Below demand is **LOW POWER**: every operational owned Barracks and Factory earns **50%** of normal training progress. Idle and blocked-complete producers still contribute full nominal demand. There are no priorities, partial allocation, power lines, stored energy, switches or upkeep.

The enemy retains its HQ, barracks, two collectors, separate 300-credit wallet, finite supplies and existing wave configuration. One explicit completed enemy plant occupies `Rect2(23, -6, 6, 5)`, centered at `(26, 0, -3.5)`. Its ordinary registration supplies 10 power against the enemy barracks' demand of 2. Destroying it slows the same paid enemy Rifle queue. No hidden generation or AI construction/rebuilding is added; wave timers are unchanged.

## Accounting, notifications and time boundary

[PowerGrid](../scripts/power_grid.gd) belongs to one field and derives coherent owner totals from that field's existing weak building registry. Eligibility requires current field membership/ancestry, operational completion, liveness, an unqueued building and unqueued ancestors. Duplicate registration is identity-based; removal cannot subtract twice or make negative totals. Every read rechecks eligibility, including supported internal ownership changes. No scene-tree scan, global account or save persistence is added.

Ownership/operational setters and registration/departure schedule refresh after existing lifecycle commits. The powered field also refreshes its registry at the start of its physics processing. Builder completion refreshes after the site, unfinished slot and builder release commit. Snapshots reconcile before returning; queued deletion is excluded immediately on read. All owner totals commit before the parameterless change notification. Listeners read current state; nested changes are committed and notified without replaying an older snapshot, including deletion by the last listener. Identical state produces no repeated notification. Same-field reparenting retains ordinary building/site identity and queues. Actual departure removes eligibility; supported re-entry restores eligible membership under the existing registration rules.

Each active [production job](../scripts/unit_production.gd) reads the current owner snapshot **immediately before its physics progress increment**. Construction runs at priority −100 before ordinary producers, so a completed plant applies to their later increments that tick. A death occurring after a producer's increment affects its next increment. If a synchronous rate-read listener changes the producer's owner, that increment is skipped and the next physics advance reads the new owner. Listener cancellation, producer loss, field removal or result freeze is checked again before progress.

The multiplier scales only accumulated training progress. Nominal recipe duration, payment, identity, queue order and existing progress remain intact. A completed job stays at 100%; its 0.25-second spawn-clearance retry uses unscaled simulated time. Normal cost/refund and exactly-once deployment commits remain authoritative. HQ Bulldozers, Depot Collectors, construction, harvesting, movement, combat and projectiles use their existing timing.

Result freeze continues to close gameplay admission and stop construction/production. Power notifications cannot enable gameplay. Teardown clears the old grid's totals and listeners; Restart creates a fresh field, restoring actual starting buildings and the local 0/0 NORMAL display. Retained old managers cannot contribute to the new scene.

## HUD

Credits remain separate from the local player's generated/required power display. A written LOW POWER warning explains the Barracks/Factory 50% rate. Selected plants show health and current generation; unfinished plants also retain construction/paused status. Selected consumers show nominal demand and current rate alongside unchanged queue, progress, Cancel and blocked-exit feedback. Recipe time is labelled as base time. The minimap adds **P** through the ordinary building registry. The ordinary panel does not reveal enemy wallets or a detailed enemy power budget.

## Recovered job-continuity finding

**Outcome B: normal completion followed by ordinary FIFO advancement.** The saved [job diagnostic](../validation-output/m8/m13-job-diagnostic-01/headless-power_ui_checks.log) completed, rather than remaining running: **171 checks, one failure, no native errors, Godot exit 1**. Its [wrapper invocation](../validation-output/m8/m13-job-diagnostic-01/headless-power_ui_checks.ps1), [results](../validation-output/m8/m13-job-diagnostic-01/results.json), [source manifest](../validation-output/m8/m13-job-diagnostic-01/source-hashes.json) and [tested assertion](../validation-output/m8/m13-job-diagnostic-01/project/tests/power_ui_checks.gd) remain unchanged.

The failed assertion, `visible power restoration preserves the existing paid active job and its progress`, required queue index zero to retain the same ID and increase elapsed work between plant work at 7.0166667 seconds and the post-completion observation. `POWER_UI_JOB_BEFORE` instead identifies job **1**, payer 1, captured **Rifle Unit / 5.0 seconds / 100 credits**, already at **4.4916667 elapsed training seconds**. `POWER_UI_JOB_AFTER` identifies job **2** at **1.0416667/5.0**, with jobs 3 and 4 still at zero. Production stores accumulated training seconds in `jobs().elapsed`; only `progress()` divides elapsed by duration. Comparing the two queue heads was not evidence of a reset.

The already-saved correction in [power_ui_checks.gd](../tests/power_ui_checks.gd) had completed both modes in [m13-ui-03](../validation-output/m8/m13-ui-03/results.json): **180 headless / 200 graphical checks, zero failures/native errors, phase exit 0**. Its complete 305-file snapshot matched source at recovery. Both [headless](../validation-output/m8/m13-ui-03/headless-power_ui_checks.log) and [graphical](../validation-output/m8/m13-ui-03/graphical-power_ui_checks.log) `POWER_UI_CONTINUITY` records establish:

| Observation | Stable identity and work | Time/accounting evidence |
| --- | --- | --- |
| Initial observation, physics tick 1675 | Job 1: 4.4916667/5.0 seconds | Plant work 7.0166667/10; shortage rate 0.5 |
| Deployment, tick 1736 | Job 1 deploys registered unit 11 exactly once; job 2 becomes head at zero | 61/60 simulated seconds at 0.5 adds 0.5083333, reaching exactly 5.0; plant work only 8.0333333 |
| Committed plant notification, tick 1854 | Job 2 still training at 0.975/5.0; jobs 3 and 4 remain at zero | 117 intervening half-rate producer increments; notification precedes this tick's increment |
| Post-completion observation, tick 1857 | Same job 2 at 1.0416667/5.0 | Four full-rate increments add 4/60 seconds |
| Following 60 physics ticks | Same job 2 at 2.0416667/5.0; paid 100, duration 5.0 | Exactly one further training second, no restart |

The corrected replay measures that observation interval as **182/60 = 3.0333333 simulated seconds**, long enough for job 1's remaining 0.5083333 training seconds to finish at half rate. It disappears from the queue only at deployment. The test checks the deployed unit remains registered, counts exactly one original-job deployment, and verifies later waiting jobs remain untrained. Five normal Train clicks deduct 500; one explicit cancellation of waiting job 5 refunds 100 before the observation. The wallet then remains **2700 = 4000 - 400 Barracks - 500 plant - 500 queued + 100 cancelled**. There is no cancellation of job 1, transition refund, extra charge or unrelated queue mutation in this interval.

**Correction scope: fixture/assertion logic only; no production-code correction.** The test now follows the original stable identity through completion and separately measures the still-active successor at the actual grid-notification boundary. It retains the continuity requirement. No construction time, recipe duration, cost, power value, FIFO/deployment implementation, private progress write or arbitrary additional sleep was introduced.

The independent [earned integration](../tests/power_integration_checks.gd) queues its paid Rifle after the builder has performed **seven actual seconds** of plant work. It checks 0.5 seconds of work over the next 60 physics ticks, the same still-training job at real plant completion, then 1.0 second of work over the following 60 ticks. Actual deployment, movement, Attack Move and the finite-cache spending/deposit ledger are checked. [Power mechanics](../tests/power_checks.gd) separately cover uninterrupted five/ten-second training, mid-job loss/restoration, repeated transitions and original refunds. Its blocked-exit case keeps a completed job at 100% during shortage and deploys the same ID within the unchanged 0.25-second clearance retry cadence.

## Preserved selection evidence

The earlier [pick diagnostic](../validation-output/m8/m13-pick-diagnostic-01/headless-power_ui_checks.log) completed with 79 checks / six failures / exit 1. `POWER_PICK_DIAGNOSTIC` records builder position `(-13.03663, 0, -0.975831)`, anchor `(-13.03663, 0.6, -0.975831)`, screen point `(466.9755, 344.8609)`, and the actual ray hit **BuiltBarracks1** at `(-12.4007, 2.600001, 0.593725)`. The completed Barracks correctly intercepted a click on its occluded builder.

The fixture recalls previously assigned group 2 through viewport input, issues an ordinary right-click Move to `(-19, 0, 0)`, waits for actual arrival, selects the Barracks, then visibly clicks the builder. Picking and selection implementation are unchanged; the test does not assign private selection or click through buildings. Invalid placement previews also return before a stale `last_result` can be reused. The corrected viewport sequence covers placement, pause/resume, selection/groups, cancellation, power display, destruction and Restart.

## Acceptance and validation

| Original acceptance requirement | Status and evidence |
| --- | --- |
| 1. Bulldozer-built Power Plant | **PASS.** Paid placement, ordinary travel, ten seconds of actual builder work, pause/resume, cancellation, replacement builder, footprint blocking and generation only after completion |
| 2. Correct per-owner generation and demand | **PASS.** Owner isolation, zero/equal-demand NORMAL, full idle/blocked-producer demand, duplicate membership, supported ownership/lifecycle changes and no stale generation |
| 3. Observable production slowdown and restoration | **PASS.** Normal/half-rate completion timing, stable-ID loss/restoration, FIFO, retained payment/duration/progress, exactly-once deployment, refunds and unscaled completed-job spawn retry |
| 4. Unaffected recovery economy, builders, and deployed units | **PASS.** HQ/Depot nominal production, real Collector deliveries during shortage, replacement-builder travel/work and produced-unit movement/Attack Move |
| 5. Destruction, callbacks, freeze, and Restart | **PASS.** Ordinary plant/consumer death, queued deletion, coherent callbacks, field removal, result gating, no stale work and fresh scene/grid/HUD after viewport Restart |
| 6. Real powered-base integration | **PASS.** Original builder and 1000 credits; paid Depot/Collector/Barracks/Plant/Rifle; late Rifle queue crosses actual plant completion, deploys and accepts commands; ledger reconciles |
| 7. Readable HUD and preserved earlier scenes | **PASS within the declared historical M12 exception.** Normal scene and full queue readable at both sizes, expanded/collapsed Help, viewport selection and controls; all current earlier-scene suites pass. This does not close M12 criterion 7 or its historical group-3 occurrence |
| 8. Accurate focused and regression validation | **PASS.** Completed source-matched focused/UI and full matrix results, fresh import/integration, original failed executions, reused evidence, all manifests, screenshots and final link/whitespace checks saved |

The final phase **m13-final-matrix-01** passed fresh-copy import (exit 0), all **37 headless + 37 graphical executions**, and the outer wrapper (exit 0). Totals: **4,798 headless + 4,913 graphical = 9,711 checks**, zero failures and zero native error/warning lines; total child time **859.577 seconds**. The six power executions contribute **829 checks**; the other 68 regression executions contribute **8,882 checks**. These subsets are included in the matrix total, not added to it.

The earned opening recorded the original builder 7, paid Collector 14 and deployed Rifle 21. Actual supplies loaded were 750, deposits 700, spending 1500, and final credits **1000 + 700 - 1500 = 200**. During shortage, 350 supplies loaded and 400 were deposited. The instance-only integrated fixture defers the first enemy wave to 600 seconds while keeping enemy economy active; the normal scene's 90-second schedule is independently verified after Restart. No free credits, injected cargo, teleports or private construction/production progress assignments substitute for that opening.

Every entry below has engine/wrapper **exit 0**. Cells show **checks / failures**.

| Suite | Headless | Graphical |
| --- | --- | --- |
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
| movement_stress_checks | 122 / 0 | 131 / 0 |
| base_assault_checks | 124 / 0 | 130 / 0 |
| vehicle_production_checks | 225 / 0 | 230 / 0 |
| combat_load | 7 / 0 | 7 / 0 |
| tactical_interface_checks | 126 / 0 | 138 / 0 |
| control_group_checks | 82 / 0 | 82 / 0 |

There are **no remaining M13 feature failures, demonstrated new regressions or new failures of unknown attribution** in final validation. All earlier failed M13 executions are retained and attributed below. The historical M12 group-3 occurrence remains open, cause unknown, with criterion 7 NOT VERIFIED under its accepted exception. Deferred movement findings and prior unknown-attribution movement failures remain separate; current passing movement runs do not close those records. No outstanding requirement blocks this M13 handoff.

### Commands and source correspondence

The continuation recovered commit `5f542031d96c8eea7f1c59cbbbc9d5fcae154075` with only `tests/power_ui_checks.gd` already modified. No applicable AGENTS.md files or active validation/Godot processes were present. One lead recovered the existing results, retained the already-tested correction, and ran the missing complete matrix once. No additional test or gameplay changes were necessary during this final recovery. README, roadmap and this report are the only newly changed tracked files.

From the repository root, the saved corrected UI phase and the final matrix use:

```powershell
& ./tools/validate-m8.ps1 -RunName m13-ui-03 -Modes @('headless', 'graphical') -Suites @('power_ui_checks')
& ./tools/validate-m13.ps1 -RunName m13-final-matrix-01
```

The first command describes the **already-completed reused phase**; it was not launched again during recovery. The second is the one newly executed full matrix. Both use the installed Godot 4.7.2 console executable shown under Playable extension, fixed 60 simulated FPS, a fresh copied project, and the existing external **240-second deadline per child process**. Graphical tests are serialized. The runner rejects native/script errors even when the engine's import exit is zero.

The final [plan](../validation-output/m8/m13-final-matrix-01/plan.json), [results](../validation-output/m8/m13-final-matrix-01/results.json), [summary](../validation-output/m8/m13-final-matrix-01/summary.json), [starting diff](../validation-output/m8/m13-final-matrix-01/starting-diff.patch) and [305-file SHA-256 manifest](../validation-output/m8/m13-final-matrix-01/source-hashes.json) retain exact commands, executable paths, timings, logs and tested source. For example, [headless UI](../validation-output/m8/m13-final-matrix-01/headless-power_ui_checks.ps1) and [graphical integration](../validation-output/m8/m13-final-matrix-01/graphical-power_integration_checks.ps1) contain the full wrapper/engine invocation. Fresh import uses `--headless --path <copied-project> --editor --import`; tests use `--path <copied-project> --fixed-fps 60 --script res://tests/<suite>.gd`, adding `--headless` for that mode. Gate checks additionally run `-- --avoidance`; `combat_load` runs combat checks with `-- --combat-load`.

Final acceptance uses the new matrix's feature and compatibility executions. The earlier `m13-focused-01` mechanics/integration passes remain supporting historical evidence: its only runtime difference is the plant-specific world-name/health-label height adjustment in `scripts/rts_building.gd`. The new matrix reruns those affected dependencies. Reused `m13-ui-03` differs from final source only in handoff documents; reused `m13-ui-02` images additionally predate only the UI-test continuity correction. No runtime or test source is edited after the final matrix snapshot, so no affected rerun or second matrix is required.

The final document/evidence check command is:

```powershell
& ./validation-output/m13/final-handoff-checks.ps1
git diff --check
```

The [check script](../validation-output/m13/final-handoff-checks.ps1) saves [link, snapshot, image and whitespace outcomes](../validation-output/m13/final-handoff-checks.json) separately from the earlier handoff-check artifact. **PASS, exit 0: 110 document links; nine retained phase manifests verified without mutation; 305 current source files compared; 20 reused screenshot dimensions/hashes recorded; git diff --check exit 0; zero check errors.** The final matrix differs from the handed-off source only in README, roadmap and this report. Runtime, resources, scenes, tests and tools remain byte-identical to the tested copy. The matrix's own end-of-run difference was only this report, which was being completed while it ran; the final check records all three document updates.

## Earlier executions retained

All earlier phase directories, logs, wrapper calls and tested copies remain intact. Counts below are historical observations, not additional unique final acceptance coverage. Headless and graphical counts are in that order.

| Phase | Completed checks / failures | Exit and disposition |
| --- | --- | --- |
| [m13-dev-01](../validation-output/m8/m13-dev-01/results.json) | Import only; 17 native error lines | Godot import exit 0, correctly rejected by validation (phase exit 1) for inferred `body` type/compile errors; saved implementation corrected typing |
| [m13-dev-02](../validation-output/m8/m13-dev-02/results.json) | Production 192 / 0 | Import and phase exit 0 |
| [m13-focused-01](../validation-output/m8/m13-focused-01/results.json) | Power 175/175 and integration 49/50 pass; UI does not execute assertions | Both UI scripts fail parsing an RTSBuilding passed where damage source requires RTSUnit, exit 1; phase exit 1. Saved test uses a real hostile unit |
| [m13-ui-01](../validation-output/m8/m13-ui-01/results.json) | UI 79/87 checks, six failures each | Both exit 1; occluded builder fixture and downstream interaction failures |
| [m13-pick-diagnostic-01](../validation-output/m8/m13-pick-diagnostic-01/results.json) | UI 79 / 6 | Exit 1; retained original ray evidence above |
| [m13-ui-02](../validation-output/m8/m13-ui-02/results.json) | UI 171/191 checks, one failure each | Both exit 1; corrected selection, invalid comparison across normal job completion |
| [m13-job-diagnostic-01](../validation-output/m8/m13-job-diagnostic-01/results.json) | UI 171 / 1 | Exit 1; before/after stable IDs prove queue turnover, resolved above |
| [m13-ui-03](../validation-output/m8/m13-ui-03/results.json) | UI 180/200 checks, zero failures | Both exit 0; corrected identity/completion and explicit mid-job rate checks |

## Rendered evidence

Existing **m13-ui-02** screenshots remain valid: current runtime, scenes and rendering dependencies are byte-identical; only the UI test's continuity observations changed. Reused normal-scene captures were inspected again during this handoff. They show the real Restart opening, 1000 credits, original builder and live configured 90-second enemy schedule. Help, power/credits, contextual controls, objective text and minimap fit without panel overlap at both sizes.

| View | 1280x720 | 1920x1080 |
| --- | --- | --- |
| Normal scene, Help closed | [Image](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_normal_opening_1280x720.png) | [Image](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_normal_opening_1920x1080.png) |
| Normal scene, Help expanded | [Image](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_normal_opening_help_1280x720.png) | [Image](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_normal_opening_help_1920x1080.png) |
| Full production queue, Help closed | [Image](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_shortage_queue_1280x720.png) | [Image](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_shortage_queue_1920x1080.png) |
| Full production queue, Help expanded | [Image](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_shortage_queue_help_1280x720.png) | [Image](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_shortage_queue_help_1920x1080.png) |

The queue captures are the explicitly funded interface fixture, not the normal opening or affordability proof. Further retained views show the [paused plant](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_paused_plant_1280x720.png), [completed plant](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_completed_plant_1280x720.png), and [destruction shortage](../validation-output/m8/m13-ui-02/artifacts/graphical-power_ui_checks/m13/screenshots/power_destroyed_shortage_1280x720.png). Final graphical checks also capture their own source-matched images. This is viewport automation and rendered-image inspection, not human playtesting.

## Preserved limitations

The [M12 acceptance with interface exception](milestone-12.md) remains unchanged: the historical group-3 occurrence is open, cause unknown, and M12 criterion 7 NOT VERIFIED. Current tests do not reconstruct or close that occurrence. [Movement findings](movement-issue-records.md) remain separately deferred and unresolved. No historical investigation or recorder campaign is part of this work. No human keyboard-and-mouse playtest has occurred; viewport automation and image inspection are reported as such.
