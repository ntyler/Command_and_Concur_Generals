# Milestone 10 — Enemy economy and repeat assaults

**Status: COMPLETE — all eight feature acceptance groups PASS (2026-09-08 local).** The completed regression matrix is **not clean: 59/60 executions passed, 7,393 assertions, three failures, phase exit 1**. The graphical `choke_30` movement failure has **unknown attribution** and remains unresolved. No required M10 feature check failed in the final matrix; no newly introduced regression has been demonstrated. Full movement/Milestone 5 acceptance remains unpassed. No human playtest occurred. Milestone 11 was not started.

## Playable scene and defaults

Open [scenes/economy_assault.tscn](../scenes/economy_assault.tscn) in Godot and press **F6**. F5 still opens the original movement field. From PowerShell:

```powershell
Set-Location 'D:\GitHub\Command_and_Concur_Generals'
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/economy_assault.tscn
```

Engine: `4.7.2.stable.official.ed1daf0bf`, graphical Compatibility renderer on the existing RTX 2070 SUPER. Engine, dependencies and project main-scene configuration were not changed. Destroy the enemy HQ while protecting yours. Existing player harvesting, construction, Rifle/Rocket production, minimap, control groups, Q Attack Move, X Stop and result/Restart controls remain available.

The new scene adds one completed enemy barracks, two coral enemy Collector Trucks and one finite neutral cache assigned to those collectors. It retains the original three enemy defenders and player forces/economy. Settings are in [scenarios/enemy_economy.tres](../scenarios/enemy_economy.tres) and [EnemyEconomyConfig](../scripts/enemy_economy_config.gd); runtime clocks, jobs and troop references belong to each scene's controller.

| Setting | Normal playable value |
| --- | --- |
| Enemy starting wallet / new cache | 300 credits / 2,000 supplies; no free replenishment |
| Player start | 1,000 credits; existing forces, two collectors and two 2,000-supply caches retained |
| Enemy harvesting | Two normal collectors: 100 cargo, 25 supplies per completed loading second, one-second unload, one credit per deposited supply; own HQ only |
| Rifle production | Existing recipe: 100 credits, five simulated seconds; FIFO, five jobs including active/completed-but-blocked head |
| Population | At most 12 living enemy armed units plus paid pending jobs; three initial defenders count, collectors do not |
| Planning | Every 0.5 simulated seconds; bounded enqueue attempts, no continuous order replacement |
| Staging | `(24, 0, 16)`, radius 3.2; separated ordinary rally slots, actual arrival required |
| Wave size | Preferred and maximum three normally produced, undispatched Rifles |
| Earliest first launch / repeat interval | 90 simulated seconds / at least 60 seconds between accepted launches |
| Partial wave | One/two assembled troops wait 30 seconds from assembly; no ready troops resets that wait; launch thresholds still apply |
| Attack-move approach | `(-14, 0, -7)`, outside the player HQ; existing movement, acquisition and weapons |
| Restart | Reloads `res://scenes/economy_assault.tscn`, restoring configured wallets/cache, controllers and clean input state |

**90 seconds is earliest eligibility, not a promise that a wave exists then.** Production, staging, population, blocked exits and available funds can delay launch. The HUD says “Earliest enemy assault,” then “Enemy reinforcements active.” Launch timing advances only on actual acceptance; rejected batches do not consume troops or reset the launch clock. Accepted troops receive their wave once. Losing the barracks stops production, refunds only paid undeployed jobs once, and preserves already deployed troops/orders. There are no rebuilds, free troops, free waves, strategic planning or tactical micromanagement. The older base-assault and combined-arms scenes retain their one-shot 90-second assault.

## Baseline, changes and source correspondence

Implementation began from clean commit `565b450b3528212b1c792faefd9e09128f833f48`. No applicable AGENTS.md was found in the repository or its ancestors. The [starting baseline](../validation-output/m10/starting-baseline.json) matched all 267 files in M9's corrected snapshot except its three completed handoff documents. M9's 50 reused executions / 6,277 checks and six post-layout executions / 855 checks remain historical baseline evidence, not part of the M10 acceptance total.

| Important files | Responsibility |
| --- | --- |
| [economy_assault.tscn](../scenes/economy_assault.tscn), [economy_assault_field.gd](../scripts/economy_assault_field.gd) | Separate combined-arms scenario, declared economy objects, owner wallet initialization, protected access/staging and objective text |
| [enemy_economy_controller.gd](../scripts/enemy_economy_controller.gd), [enemy_economy_config.gd](../scripts/enemy_economy_config.gd), [enemy_economy.tres](../scenarios/enemy_economy.tres) | Bounded harvesting/paid production coordinator, living-plus-pending population, assembled waves and scene-local lifecycle |
| [player_credits.gd](../scripts/player_credits.gd), [production_field.gd](../scripts/production_field.gd) | Per-owner initial balance and narrow wallet-creation override |
| [harvest_field.gd](../scripts/harvest_field.gd), [collector_harvest.gd](../scripts/collector_harvest.gd), [collector_truck.gd](../scripts/collector_truck.gd) | Owned-HQ resolution, explicit-owner harvest dispatch, owner-scoped feedback and team visuals |
| [test_field.gd](../scripts/test_field.gd), [attack_move_order.gd](../scripts/attack_move_order.gd) | Shared formation/validation/dispatch with explicit command owner, separate owner authority, retained owner across combat/resume |
| [base_assault_field.gd](../scripts/base_assault_field.gd) | Narrow one-shot-assault override; old scenes retain their defaults |
| [enemy_economy_checks.gd](../tests/enemy_economy_checks.gd), [enemy_economy_integration_checks.gd](../tests/enemy_economy_integration_checks.gd) | Focused fixtures and separate real zero-credit, paid-production, two-wave combat integration |
| [README](../README.md), [roadmap](roadmap.md), this report | Launch instructions, final acceptance, limitations and saved handoff |

The saved run contains its actual [tested project](../validation-output/m8/m10-final-matrix-01/project/project.godot), [SHA-256 source manifest](../validation-output/m8/m10-final-matrix-01/source-hashes.json), [revision](../validation-output/m8/m10-final-matrix-01/revision.txt), [starting status](../validation-output/m8/m10-final-matrix-01/starting-status.txt) and [tracked diff](../validation-output/m8/m10-final-matrix-01/starting-diff.patch). New untracked source is included in the snapshot/manifest even though the tracked diff alone does not contain it.

On recovery, **all 275 manifest files matched both the saved tested copy and current workspace; no source was missing or newly uncaptured**. The original summary also reports no source differences during the run. Final recovery changed only README, roadmap and this report. Runtime, tests, scenes, configuration and runner still match the matrix snapshot. The [final handoff checks](../validation-output/m10/final-handoff-checks.json) record the final correspondence and document-check outcomes.

**Reuse:** all 60 completed final-matrix executions are retained as final coverage, including the failed execution. No engine execution was missing or invalidated, and no runtime correction or post-recovery engine rerun was necessary. Earlier focused runs are execution history only; their repeated assertions and captures are not added again.

## Eight acceptance groups

| Acceptance group | Status | Final evidence and limits |
| --- | --- | --- |
| 1. Real enemy harvesting and owner-isolated credits | PASS | Opponent economy fixture earns all 75 finite supplies from zero; rejects unaffordable production; player wallet is unchanged. Integration earns 2,000 real credits through normal trips. Collector loss/depleted cache do not create income. |
| 2. Paid production with queue and population limits | PASS | Ordinary 100-credit/five-second FIFO jobs; pending jobs and blocked completed head count toward population. Five-slot queue, no duplicate payment/deployment and exact undeployed-job refunds. |
| 3. Correct staging and bounded repeat-wave timing | PASS | Normally produced troops physically assemble; timing fixture launches at 90/150 seconds. Separate one-unit fixture waits 30 seconds after assembly. Total rejection, partial acceptance and callback reentry retain accurate recipients/timing. |
| 4. Existing attack-move combat by normally produced troops | PASS | Real zero-credit integration launches distinct three-unit waves at 30/50 test seconds; all six paid recipients deal actual hostile damage. First-wave troops physically resume original travel after combat. |
| 5. Ownership, batch reporting and player-input isolation | PASS | Intended/accepted identities, synchronous departure/supersession, wrong-owner rejection and player Q/selection/orders/feedback preservation pass. Direct authority fixtures are explicitly separate from produced-wave evidence. |
| 6. Destruction, callbacks, freeze and clean Restart | PASS | Collector/barracks/HQ loss, producer ownership loss, callback spending/destruction, victory/defeat/draw, frozen direct callbacks and actual viewport Restart pass. Active troop orders survive barracks loss; teardown clears scene references. |
| 7. Earlier scenes and readable HUD | PASS for feature scope | Earlier harvesting, production, construction, combat, base-assault, vehicle, attack-move and HUD/UI suites pass both modes. Normal economy HUD is readable at 1280x720 and 1920x1080. One separate movement-stress execution fails with unknown attribution; broad movement acceptance is not claimed. |
| 8. Focused/integration validation and accurate failure reporting | PASS | Complete manifest/plan/results/log inventory, genuine zero-credit integration, retained failed phases, final source match, whitespace/link checks and saved report. The matrix's exit 1 is preserved. |

Opponent cases: [headless log](../validation-output/m8/m10-final-matrix-01/headless-enemy_economy_checks.log), [graphical log](../validation-output/m8/m10-final-matrix-01/graphical-enemy_economy_checks.log). Integration: [headless log](../validation-output/m8/m10-final-matrix-01/headless-enemy_economy_integration_checks.log), [graphical log](../validation-output/m8/m10-final-matrix-01/graphical-enemy_economy_integration_checks.log).

### Integration and fixture separation

Both real integration runs start the enemy at **zero credits**. Their only economy/schedule overrides are that initial wallet and **30-second first / 20-second repeat eligibility**. Normal cache amounts, harvesting travel/loading/deposits, five-second paid production, unit movement/weapons, staging, three-unit wave size and population limit remain intact. The inherited harness uses `--fixed-fps 60`, disables graphical VSync and camera edge scrolling, and waits real physics/process frames; it does not grant money after startup, spawn the wave troops directly, teleport them to staging or apply forced combat damage.

At **66.317 simulated seconds**, both modes record the same evidence:

| Wave | Accepted unit IDs | Cumulative actual hostile damage by each member |
| --- | --- | --- |
| First, 30 seconds | 11, 12, 13 | 450, 450, 420 |
| Second, 50 seconds | 14, 15, 16 | 12, 60, 132 |

Every recipient maps to a unique paid queue job. Nine normal Rifles deployed overall. **2,000 deposited − 900 spent = 1,100 enemy credits**; player credits remain **1,000**, cache and cargo both end at zero. First-wave resumed travel exceeds 4.28, 4.36 and 8.02 world units respectively. The old one-shot assault remains off and population never exceeds 12.

The separate scheduler fixture starts with 900 credits and no supplies and directs troops to a nearby noncombat approach `(24, 0, 21)` to isolate **normal 90/60 timing**. The partial-wave fixture uses 100 credits/no supplies and first eligibility zero to isolate the 30-second post-assembly wait. Other focused fixtures use small balances/caches, blockers or forced destruction to exercise individual boundaries. These fixtures do not substitute for real economy-to-combat evidence and do not modify the normal shared configuration.

## Completed validation and commands

The existing process **finished**, rather than being interrupted: the [wrapper log](../validation-output/m10/final-matrix-01-wrapper.log) ends in `PHASE_EXIT: 1`, [summary](../validation-output/m8/m10-final-matrix-01/summary.json) records 60 planned and 60 completed executions, and [results](../validation-output/m8/m10-final-matrix-01/results.json) contains import plus every planned test. No associated Godot/matrix process remained when recovered. No duplicate matrix was launched or unrelated process terminated.

The plan was saved at **2026-09-09 00:49:15 UTC**; the last graphical execution completed at approximately **01:01:10 UTC** (September 8 local). Recorded execution time totals **713.995 seconds**, including the successful fresh import.

| Coverage counted once | Executions | Assertions | Failed assertions | Execution exits |
| --- | --- | --- | --- | --- |
| Fresh import, separate from assertion totals | 1 | 0 | 0 | 0 |
| Headless matrix | 30/30 passed | 3,661 | 0 | All 0 |
| Graphical matrix | 29/30 passed | 3,732 | 3 | 29 × 0; movement stress 1 |
| **Final matrix total** | **59/60 passed; 60/60 complete** | **7,393** | **3** | **Phase 1** |
| M10 opponent + real integration, subset of matrix | 4/4 passed | 261 | 0 | All 0 |

The three reported native/error lines are the failed stress assertions' `push_error` reports, not three additional failures. All other executions, including M10, have zero native/error lines.

| Suite | Headless checks / exit | Graphical checks / exit |
| --- | --- | --- |
| enemy_economy_checks | 96 / 0 | 98 / 0 |
| enemy_economy_integration_checks | 33 / 0 | 34 / 0 |
| attack_move_checks | 124 / 0 | 124 / 0 |
| attack_move_batch_checks | 155 / 0 | 155 / 0 |
| attack_move_ui_checks | 91 / 0 | 94 / 0 |
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
| gate_movement_checks --avoidance | 39 / 0 | 39 / 0 |
| construction_checks | 267 / 0 | 270 / 0 |
| construction_cleanup_checks | 46 / 0 | 46 / 0 |
| harvesting_checks | 298 / 0 | 299 / 0 |
| production_checks | 192 / 0 | 193 / 0 |
| combat_checks | 183 / 0 | 191 / 0 |
| combat_repair_checks | 230 / 0 | 230 / 0 |
| line_of_fire_checks | 305 / 0 | 308 / 0 |
| spherical_projectile_checks | 140 / 0 | 141 / 0 |
| movement_stress_checks | 122 / 0 | **131 / 1; three failures** |
| base_assault_checks | 124 / 0 | 130 / 0 |
| vehicle_production_checks | 225 / 0 | 230 / 0 |
| combat_checks --combat-load | 7 / 0 | 7 / 0 |
| tactical_interface_checks | 126 / 0 | 138 / 0 |
| control_group_checks | 82 / 0 | 82 / 0 |

The exact per-execution shell commands, wrapper calls and Godot arguments are retained in [results.json](../validation-output/m8/m10-final-matrix-01/results.json); [plan.json](../validation-output/m8/m10-final-matrix-01/plan.json) contains the complete intended argument inventory. Each row's sibling `<label>.ps1`, `<label>.log`, `<label>.stdout.log` and `<label>.stderr.log` exists in the same run directory. These are the actual saved invocations, not inferred filenames for missing artifacts.

For example, the recorded import and headless opponent wrapper calls, expressed with their exact saved paths in variables:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$tested = 'D:\GitHub\Command_and_Concur_Generals\validation-output\m8\m10-final-matrix-01\project'
$wrapper = "$tested\tools\run-godot.ps1"
& $wrapper -GodotPath $godot -ProjectPath $tested -TimeoutSeconds 240 -GodotArguments @('--headless', '--path', $tested, '--editor', '--import')
# Recorded exit 0.
& $wrapper -GodotPath $godot -ProjectPath $tested -TimeoutSeconds 240 -GodotArguments @('--headless', '--path', $tested, '--fixed-fps', '60', '--script', 'res://tests/enemy_economy_checks.gd')
# Recorded exit 0, 96 checks.
```

The same wrapper/timeout/fixed FPS applies to every listed suite. Graphical arguments omit `--headless`. Integration uses `res://tests/enemy_economy_integration_checks.gd`; avoidance appends `-- --avoidance`; combat load uses `res://tests/combat_checks.gd -- --combat-load`. All generated wrappers were launched with the plan's existing shell:
`C:\Users\Tyler\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe -NoProfile -ExecutionPolicy Bypass -File <saved-label.ps1>`.

Equivalent existing-runner invocation reconstructed from the recorded plan, **documented only, not rerun during recovery**:

```powershell
$suites = @(
    'enemy_economy_checks', 'enemy_economy_integration_checks',
    'attack_move_checks', 'attack_move_batch_checks', 'attack_move_ui_checks',
    'hud_clarity_checks', 'milestone_checks', 'movement_repair_checks',
    'parked_deadlock_checks', 'parked_deadlock_controls', 'captured_parked_cluster_checks',
    'projection_step_checks', 'boundary_neighbor_checks', 'boundary_neighbor_controls',
    'gate_movement_checks', 'construction_checks', 'construction_cleanup_checks',
    'harvesting_checks', 'production_checks', 'combat_checks', 'combat_repair_checks',
    'line_of_fire_checks', 'spherical_projectile_checks', 'movement_stress_checks',
    'base_assault_checks', 'vehicle_production_checks', 'combat_load',
    'tactical_interface_checks', 'control_group_checks'
)
& .\tools\validate-m8.ps1 -RunName 'm10-final-matrix-01' -GodotPath $godot -TimeoutSeconds 240 -Modes @('headless', 'graphical') -Suites $suites
# Saved phase exit 1. The runner refuses to overwrite this retained phase.
```

The [existing runner](../tools/validate-m8.ps1) adds the avoidance variant in each mode, yielding 30 executions per mode from 29 supplied suite names.

## Preserved execution history and failure attribution

These results remain intact; earlier snapshots are not counted again in final acceptance.

| Phase | Actual outcome | Recorded interpretation/correction |
| --- | --- | --- |
| [m10-import-01](../validation-output/m8/m10-import-01/results.json) | Fresh import and three headless regressions PASS; 577 checks, no failures/error lines; phase 0 | Attack-move core/batch and harvesting exercised owner-aware paths. |
| [m10-focused-01](../validation-output/m8/m10-focused-01/results.json) | Import PASS; both new headless scripts failed before assertions, exits 1; five native error lines; phase 1 | M10 harness referenced a blocker helper outside its inheritance chain; replaced with an explicit physical blocker fixture. |
| [m10-focused-02](../validation-output/m8/m10-focused-02/results.json) | Core 82 checks / three failures; integration 33 / one failure; both exits 1; no native errors; phase 1 | Two timing comparisons needed the scheduler's one-microsecond tolerance (observed 29.9999999999996 and 89.999999999996). Two callback fixtures began already travelling; Stop before subscription forced the intended idle-to-travelling boundary. Real damage/accounting already passed. |
| [m10-focused-03](../validation-output/m8/m10-focused-03/results.json) | Fresh import and 12/12 tests PASS; 1,785 checks, no failures/error lines; phase 0 | Opponent 88/90, integration 33/34, attack-move 124/124, batch 155/155, harvesting 298/299, production 192/193. Three saved captures inspected. |
| [m10-final-matrix-01](../validation-output/m8/m10-final-matrix-01/results.json) | Fresh import PASS; 59/60 tests PASS; 7,393 checks, three stress failures/error lines; phase 1 | Final source includes owner-scoped rejected-harvest feedback plus expanded opponent assertions; all required M10 checks pass. Unknown stress failure retained without retry. |

After focused-03, the only runtime change was rejected internal harvesting using owner-scoped feedback instead of replacing the player's command line. Added focused assertions covered that path, active troop orders across barracks loss, callback spending, producer ownership loss and HQ destruction during enqueue. Those changes are covered by the completed final matrix. No HUD layout or ordinary unit movement change followed the inspected focused captures.

| Required failure category | Final status |
| --- | --- |
| Milestone 10 feature failures | None unresolved in final source. Earlier M10 harness/timing-fixture failures and their corrections remain above. |
| Demonstrated newly introduced regressions | None demonstrated by the saved evidence. This does not establish that every unknown failure is pre-existing. |
| Documented deferred movement findings | Existing [movement issue records](movement-issue-records.md) remain deferred and unresolved; this task does not close them. |
| Failures of unknown attribution | Final graphical `movement_stress_checks`: three `choke_30` arrival/traversal/settling assertions; exit 1. Relationship to prior movement cases or M10 changes is unknown. |

The [failed stress log](../validation-output/m8/m10-final-matrix-01/graphical-movement_stress_checks.log), [stderr](../validation-output/m8/m10-final-matrix-01/graphical-movement_stress_checks.stderr.log) and [metrics](../validation-output/m8/m10-final-matrix-01/artifacts/graphical-movement_stress_checks/stress-metrics.json) show unit **13** in FAILED at `(-2.849998, 0, -1.359336)`, assigned `(6, 0, -3)`, after **eight** recovery attempts. Failed assertions are “all units arrive within configured tolerance,” “entire group traverses the gate,” and “no arrival jitter or stationary total overlap for three seconds.” The matching headless stress run passed 122 checks. Similar historical gate symptoms do not prove this occurrence pre-existing; no historical campaign, clean-run retry or assertion weakening was performed.

## Current screenshots and visual evidence

These are actual retained viewports from the completed final matrix, with unscaled 1280x720 / 1920x1080 test windows. No replacement captures were needed.

| Capture | Resolution | Inspection/reuse |
| --- | --- | --- |
| [Normal economy scene](../validation-output/m8/m10-final-matrix-01/artifacts/graphical-enemy_economy_checks/m10/screenshots/normal_1280x720.png) | 1280x720 | Byte-identical to the already inspected focused-03 normal capture; reused |
| [Normal economy scene](../validation-output/m8/m10-final-matrix-01/artifacts/graphical-enemy_economy_checks/m10/screenshots/normal_1920x1080.png) | 1920x1080 | Saved final-matrix image inspected during recovery |
| [Real two-wave integration](../validation-output/m8/m10-final-matrix-01/artifacts/graphical-enemy_economy_integration_checks/m10/screenshots/two_waves_1280x720.png) | 1280x720 | Saved final-matrix image inspected during recovery; shortened test schedule |

The normal HUD keeps Help, player credits/build controls, objective and minimap legible without panel overlap. The integration capture shows the depleted cache, produced attackers and damaged player HQ; its damage/accounting claims come from the logs, not from the image alone. Final image dimensions and hashes are saved in the handoff checks.

## Final handoff checks and remaining limits

Documentation/source audit outcome is recorded after the final file edits in [final-handoff-checks.json](../validation-output/m10/final-handoff-checks.json). The [whitespace log](../validation-output/m10/git-diff-check.log) saves the actual `git diff --check` output and exit. Local Markdown destinations and Markdown anchors in README, roadmap and this report are checked against files on disk. These documentation checks do not turn the failed regression matrix into a pass.

Final outcomes: **git diff --check exit 0** (only informational Git line-ending notices); **96 local Markdown links and four Markdown anchors checked, zero broken, exit 0** across all three handoff documents. Explicit trailing-whitespace checks also pass for those documents, including this untracked report. All **61 saved execution logs** (import plus 60 tests) agree with their result rows, and the plan/summary inventory and actual phase exit agree. All **275 tested snapshot hashes** remain intact; final workspace differences are exactly the three handoff documents, with no uncaptured files. The handoff check exits **0** while preserving **matrix_passed=false / matrix_phase_exit=1**.

This task used one lead, made no recovery-time runtime edits, launched no new engine tests/reviewers and did not commit, tag, install dependencies, upgrade Godot or discard unrelated changes. The completed report, README and roadmap are saved before the chat response.

Remaining limits: this is a bounded finite-resource opponent with no economy rebuilding or general strategy; harvesting access failure can require a fresh command, and ordinary movement failure can prevent staging. First eligibility and repeat intervals do not guarantee successful arrivals or endless waves. Full historical movement reliability and the new unknown-attribution stress failure remain unresolved. Validation is automated, including graphical input and saved-image inspection; balance, subjective playability and a human playtest are not claimed. No required M10 acceptance group remains unverified within that scope.
