# Milestone 1.5.1 — movement correctness and validation repair

Completed on 2026-09-06 with Godot `4.7.2.stable.official.ed1daf0bf` and PowerShell 7.6.5 on Windows. **ACCEPT** for the existing flat, static fields and tested 30/50-unit configurations. Milestone 2 combat can begin within that scope; no combat or other later system was implemented here. No commit was made.

## Preflight and baseline

No applicable AGENTS.md existed in the repository or its ancestors. README, both prior milestone reports, the supplied review/corrective requirements, project configuration, both scenes, relevant scripts and the complete existing diff were inspected. The repository already contained the uncommitted Milestone 1.5 work over `f00ddb7`; that work was preserved. An ignored `validation-output/m151-before.zip` snapshot records the files before these corrections. The plan was to demonstrate the defects, repair command/state/lifecycle behavior, strengthen the harness and external timeout, then rerun existing validation and correct the documentation.

Pre-fix results were recorded separately:

| Baseline validation | Checks / failures | Exit | Log in `validation-output/` |
| --- | --- | --- | --- |
| Import and original scene launch | Clean | 0 each | `m151-pre-import.log`, `m151-pre-launch.log` |
| Original headless | 126 / 0 | 0 | `m151-pre-original.log` |
| Original graphical | 130 / 0 | 0 | `m151-pre-original-graphical.log` |
| Stress headless | 110 / 2 | 1 | `m151-pre-stress.log` |
| Stress graphical | 119 / 0 | 0 | `m151-pre-stress-graphical.log` |

The pre-existing headless failure was on the 50-unit gate: unit 39 exhausted eight recovery attempts at approximately `(6.237, 0, 1.404)` for slot `(10, 0, 3)`. It failed both arrival and settling assertions. This was not a parser failure or a regression introduced by this repair. Corrected headless, graphical and one additional headless stress run all subsequently completed; the repeat was justified by this intermittent baseline failure. These runs do not establish a statistical guarantee against all possible crowd deadlocks.

## Repairs, root causes and regression evidence

| Defect and root cause | Small correction | Focused verification | Before / after |
| --- | --- | --- | --- |
| Route false positive: retained `last_command_slots` and old ARRIVED units could look like acceptance | `issue_move()` returns a bool; route snapshots intended units and prior versions, requires one increment per unit, captures assignments by value and returns immediately on rejection | Complete a route, restrict radius to reject the next order, require rejection with zero elapsed physics frames, and verify the previous coherent order remains intact | Failed before; passes after |
| Signal reentrancy: `_recover()` emitted before finishing its writes; callers could continue an old transition after a listener replaced it | Complete state/priority/timers/targets before emission; capture recovery order version and guard callers after signal-producing operations; audit all five states and move the destination marker update before TRAVELLING | RECOVERING listener synchronously orders B; verify every target, version, timer and priority immediately and over subsequent ticks, bounded movement and arrival. Also audit all five states and replacement from CONGESTED/TRAVELLING | Core recovery test failed before; passes after. Additional state-audit cases were added after the first failing run |
| Crowd mode split: public branch flag and agent avoidance could disagree; stale callbacks could still move | Authoritative `crowd_enabled` setter synchronizes agent/velocity/submission state, callback checks mode, and a physics-frame guard prevents double displacement | Toggle only the public property both ways during movement; assert synchronization, reject a stale disabled callback, check every tick's speed bound, progress and arrival | Both directions exposed failures before; pass after |
| Departure leak: object validity did not imply owning-field membership | Field registration and `tree_exiting` cleanup; membership checks include tree presence, queued deletion and ancestry; tree entry restores internal reparent membership; selection uses the field list | Selected/unselected × detach/free, repeated commands at the former reservation, no detached order-version increment, prompt selection/list cleanup, internal reparent and clean logs | Detachment/reservation cases failed before; all four cases pass after. Existing free cases remain covered |
| Recovery cleanup mismatch: meaningful progress changed the state label while leaving recovery waypoint/priority/timing active | Reuse complete temporary-recovery cleanup before TRAVELLING; retain per-order attempt count and rate-limit history | Create a real recovery transition, supply deterministic progress beyond the configured threshold, observe coherent signal data immediately, then resume physics and arrive without restoring the detour | Failed before; passes after |
| Timeout gap: in-process `_process()` cannot interrupt a blocked main thread | Small external PowerShell launcher with configurable deadline, process-tree termination, preserved child codes and separate timeout result | Normal child 0, unarmed fixture 3, internal watchdog 2, externally killed blocking fixture 124; assert no launcher/engine PID survives | No previous external wrapper to run a failing test against; new isolated blocked-main-thread verification passes |
| Settling evidence gap: endpoints can match despite intermediate movement | Shared sampler checks every physics tick, tracks maximum displacement, movement state and velocity | Deliberately oscillate an idle fixture and return to its starting point; require sampler rejection | Added after the initial failing run; negative fixture correctly rejected and normal routes pass |

The first focused run, before production repairs, reported **66 checks, 24 failures, exit 1** in `m151-red-regressions.log`. It reproduced the five command/movement/lifecycle defects, including navigation errors caused by detached units receiving commands. Direct zero-unit, one-unit and mismatched slot-count checks already passed. The expanded final suite reports **73 checks, 0 failures, exit 0**. The counts differ because later checks cover additional signal states and the stationary negative fixture. A new assertion comparing Godot's stored priority with `0.65` was changed to `is_equal_approx` for engine float precision; movement tolerances, deadlines and existing acceptance assertions were not weakened.

The tests use actual scene instances, navigation, signals and motion. Internal fields are inspected where the requirement specifically concerns transition coherence; bounded displacement, progress, arrival, released reservations and rejected commands are also observed. The tests do not reimplement destination generation or recovery selection. Test-created signals are disconnected, detached fixtures are explicitly freed, and each fresh field frees its predecessor before the next fixture. No global reservation store was added.

## Important files and APIs

- `scripts/test_field.gd`: `issue_move(clicked: Vector3) -> bool` replaces the void return. Empty selection, capacity and reachability rejection return false; these pre-dispatch failures preserve the previous valid order. True means dispatch reached every intended member. `last_command_slots` remains diagnostic and is not acceptance evidence. `contains_unit()` and `register_unit()` provide field-local lifecycle handling; a newly added unit must be registered after entering the field.
- `scripts/selection_controller.gd`: owning `gameplay_field`, membership-aware selection and idempotent `forget_unit()`. `tree_exiting` removes selection promptly. An internal reparent restores membership and commandability but does not restore the former selection automatically.
- `scripts/rts_unit.gd`: synchronized public crowd setter, one movement application per physics frame, complete transitions before public signals, replacement-version guards, and immediate cleanup on meaningful progress. Recovery attempts still cap the whole order and reset only with a replacement order. FAILED units still accept new orders.
- `tests/movement_stress_checks.gd`: explicit dispatch/version checks and captured assignments for every route; public-only crowd configuration; stronger stationary sampling; `longest_sampled_overlap_seconds`, `overlap_sample_hz` and `stationary_max_displacement` metrics.
- `tests/milestone_checks.gd`: shared stationary sampler; all original assertions retained.
- `tests/movement_repair_checks.gd`: focused integration regressions above.
- `tools/run-godot.ps1`, `tests/validation_wrapper_checks.ps1`, `tests/blocking_fixture.gd`: external timeout and its isolated verification. New GDScript `.uid` sidecars are legitimate project metadata.
- `README.md`, `docs/milestone-1.5.md`, this report: current commands, corrected claims and separately identified historical data.

`scripts/group_destinations.gd`, `project.godot` and both scenes match the pre-repair snapshot. The camera, historical Milestone 1 report, license, ignore rules and unrelated content were preserved. No movement tuning changed: speed 5.0, arrival 0.22, recovery limit eight, order deadline 90 seconds, slot spacing 1.5, radius cap 18, candidate cap 1,600 and three assignment passes remain unchanged. Initializing the agent's current travel radius before a signal uses those existing values.

## Validation commands and exact results

Run from `D:\GitHub\Command_and_Concur_Generals` in PowerShell 7:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$run = @{ GodotPath = $godot; TimeoutSeconds = 240 }
```

Each row below is a separate `& .\tools\run-godot.ps1 @run -GodotArguments <array>` invocation. Read `$LASTEXITCODE` immediately; a shell/CI command ends with `exit $LASTEXITCODE` to retain the exact code. Log arguments are included to identify the recorded evidence.

| Godot argument array | Result | Exit |
| --- | --- | --- |
| `@('--headless','--path','.','--editor','--import','--log-file','validation-output/m151-import.log')` | Clean import | 0 |
| `@('--headless','--path','.','--quit-after','120','--log-file','validation-output/m151-launch-main.log')` | Main scene: 12 units / 3 obstacles | 0 |
| `@('--headless','--path','.','res://scenes/movement_stress.tscn','--quit-after','120','--log-file','validation-output/m151-launch-30.log')` | Alternate scene: 30 units / 7 obstacles | 0 |
| `@('--headless','--path','.','res://scenes/movement_stress.tscn','--quit-after','120','--log-file','validation-output/m151-launch-50.log','--','--units=50')` | Alternate scene: 50 units / 7 obstacles | 0 |
| `@('--headless','--path','.','--fixed-fps','60','--script','res://tests/milestone_checks.gd','--log-file','validation-output/m151-original.log')` | 126 checks / 0 failures | 0 |
| `@('--path','.','--fixed-fps','60','--script','res://tests/milestone_checks.gd','--log-file','validation-output/m151-original-graphical.log')` | 130 checks / 0 failures | 0 |
| `@('--headless','--path','.','--fixed-fps','60','--script','res://tests/movement_stress_checks.gd','--log-file','validation-output/m151-stress.log')` | 118 checks / 0 failures | 0 |
| `@('--path','.','--fixed-fps','60','--script','res://tests/movement_stress_checks.gd','--log-file','validation-output/m151-stress-graphical.log')` | 127 checks / 0 failures | 0 |
| `@('--headless','--path','.','--fixed-fps','60','--script','res://tests/movement_repair_checks.gd','--log-file','validation-output/m151-focused.log')` | 73 checks / 0 failures | 0 |
| `@('--headless','--path','.','--fixed-fps','60','--script','res://tests/movement_stress_checks.gd','--log-file','validation-output/m151-stress-repeat.log')` | Additional 118 checks / 0 failures | 0 |

`& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot` reports **5 checks, 0 failures, exit 0**. It executes:

| Wrapper arguments after `-GodotPath $godot` | Expected and observed exit |
| --- | --- |
| `-TimeoutSeconds 15 -GodotArguments @('--version')` | 0; engine version preserved and reported |
| `-TimeoutSeconds 15 -GodotArguments @('--headless','--path','.','--script','res://tests/blocking_fixture.gd','--log-file','validation-output/m151-fixture-guard.log')` | 3; fixture refuses accidental normal invocation |
| `-TimeoutSeconds 15 -GodotArguments @('--headless','--path','.','--script','res://tests/milestone_checks.gd','--log-file','validation-output/m151-internal-timeout.log','--','--verify-timeout')` | 2; responsive-loop `TEST_TIMEOUT` diagnostic |
| `-TimeoutSeconds 2 -GodotArguments @('--headless','--path','.','--script','res://tests/blocking_fixture.gd','--log-file','validation-output/m151-external-timeout.log','--','--verify-external-timeout')` | 124; blocked process tree terminated, no surviving reported PID |

The blocking fixture inherits the original watchdog, sets its deadline to 50 ms, then blocks synchronously without yielding. The external two-second deadline kills it despite the internal callback being unable to run. The wrapper allows up to ten additional seconds for process termination. It uses redirected asynchronous output reads to avoid filled-pipe deadlocks, prints `GODOT_EXIT` for normal completion, returns 124 on external expiry and 125 on launch/termination errors. The self-test checks completion within twelve seconds. Expected fixture/internal-timeout errors are isolated from ordinary logs and suites.

`git diff --check` passed with exit 0. The complete diff and new files were reviewed; successful final import, launch and test logs contain no parser, resource, navigation, signal or runtime errors. `.godot/` and `validation-output/` are ignored, including logs, captures, metrics and the pre-repair zip. No machine-specific generated file was added to source control. Graphical suites combine engine input playback, physics assertions and rendered captures; no human physical keyboard/mouse playtest is claimed.

The original totals remain **126 headless / 130 graphical**. Stress totals increase from **110/119 to 118/127** because eight successful routes each add the explicit new-order-version assertion. The other route assertions are retained and strengthened.

## Measurements and qualified claims

Destination assignment remains command-only **O(n log n + p·n²)** for fixed passes `p = 3`. No new per-frame all-pairs loop, full scene-tree search, verbose logging or enabled-by-default debugging was introduced. Field membership checks add ancestry checks to selection pruning; registration/list removal occurs on lifecycle events. The new movement-frame guard is constant work. Remaining-path queries still run at the existing progress interval, with bounded recovery queries only when recovery is requested. Pair comparisons are test instrumentation at 10 Hz.

| Run | Maximum generation / assignment | 50-unit gate seconds | Gate / cluster p95 physics interval | Enabled / disabled overlap pair-seconds | Reduction |
| --- | --- | --- | --- | --- | --- |
| Historical 1.5 graphical | 2.770 / 4.980 ms | 17.77 | 6.469 / 7.679 ms | 63.2 / 206.2 | 69.4% |
| Corrected primary headless | 4.074 / 4.067 ms | 18.43 | 2.128 / 1.934 ms | 74.7 / 206.2 | 63.8% |
| Corrected graphical | 2.705 / 3.763 ms | 23.27 | 5.251 / 6.982 ms | 66.4 / 206.2 | 67.8% |
| Additional corrected headless | 3.006 / 7.633 ms | 16.13 | 3.625 / 3.146 ms | 53.8 / 206.2 | 73.9% |

Every measured destination call stays below the unchanged 100 ms test ceiling. Some headless runs overlapped other validation processes. Graphical measurements use the RTX 2070 SUPER, OpenGL 3.3 Compatibility, NVIDIA 610.88, fixed 60 Hz simulation and VSync disabled only in the harness. They include rendering and instrumentation and are not isolated CPU timings or an FPS guarantee. These observations do not establish a causal performance improvement; trajectories and scheduling vary, and the graphical gate took longer than the historical run. No tuning adjustment was made to chase those results.

Corrected graphical route details:

| Route | Units | Simulated seconds | Recoveries across the whole group | Minimum settled center spacing |
| --- | --- | --- | --- | --- |
| Wide | 30 | 5.87 | 0 | 1.446 |
| Gate | 30 | 10.97 | 0 | 1.312 |
| L-shaped | 30 | 10.97 | 0 | 1.389 |
| Cluster | 30 | 15.35 | 2 | 1.391 |
| Boundary | 30 | 5.35 | 0 | 1.398 |
| Gate | 50 | 23.27 | 10 | 1.338 |
| Cluster | 50 | 12.65 | 4 | 1.168 |

The gate's ten recovery attempts are a group total, not a breach of the eight-attempt per-unit cap. Each route proves a new command and checks arrival against its captured assignments using the unchanged 0.22 stopping distance plus 0.01 harness allowance. All current stress routes recorded **zero maximum displacement across the full 180-tick settling interval**, with ARRIVED state, no movement and velocity below 0.001. A fixture that oscillates and returns to its starting position is correctly rejected by this sampler.

Overlap uses identical 50-unit spawns, target `(10, 0, 0)`, generation, assignment and movement/recovery defaults; the only gameplay configuration change is the public crowd flag. Every sixth physics tick at 60 Hz, each pair with center distance below 0.6 contributes 0.1 pair-seconds. The longest run is an estimate of consecutive overlapping samples; gaps shorter than the 0.1-second sample interval are not observed. The corrected graphical gate's longest sampled run is 4.2 seconds. This metric is neither continuous mathematical observation nor contact between exact mesh surfaces. Reduction is `100 * (1 - enabled / disabled)` and applies only to the measured fixed setup/run.

The archived `stress-metrics-graphical.json` still reproduces the historical 69.4% from 63.2/206.2. It remains explicitly historical; the corrected primary graphical result is 67.8%. Current primary evidence is in the named `m151-*.log` files, which include route JSON. `stress-metrics.json` is overwritten on rerun and currently describes the additional headless run. Capture filenames are also overwritten. Earlier route evidence is qualified rather than discarded: the old harness could accept stale state, whereas every current route independently proves acceptance and captured assignments.

## Complete acceptance checklist

| # | Required outcome | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Rejected command cannot pass using stale slots/ARRIVED | PASS | Negative route returns immediately; old order remains coherent |
| 2 | Every route proves explicit acceptance and new versions | PASS | Added assertion on all eight routes |
| 3 | Arrival uses an immutable assignment snapshot | PASS | Local copied values plus retained version checks |
| 4 | Synchronous RECOVERING replacement cannot be overwritten | PASS | Listener orders B; immediate/subsequent state and arrival checked |
| 5 | Emitted state is coherent | PASS | All five states observed; emit-last audit and caller guards |
| 6 | Public-only crowd toggles work without double movement | PASS | Both directions, stale callback, per-tick displacement and arrival |
| 7 | Agent avoidance agrees with public crowd mode | PASS | Before-ready setup and live setter/callback checks |
| 8 | Detached selected units leave selection | PASS | Immediate tree-exit and later selection assertions |
| 9 | Detached moving units release destinations | PASS | Remaining unit receives the former target in repeated commands |
| 10 | Freed units cause no invalid references | PASS | Selected/unselected free cases and clean final logs |
| 11 | Meaningful progress clears temporary recovery immediately | PASS | Signal-time fields, target, priority and subsequent movement |
| 12 | Recovery cap remains per-order and bounded | PASS | Progress retains count; existing enclosure fails at configured cap |
| 13 | External timeout kills blocked Godot | PASS | Exit 124; no launcher/engine PID survives |
| 14 | Internal watchdog diagnostics retained | PASS | Isolated TEST_TIMEOUT and preserved exit 2 |
| 15 | Stationary verification samples the full interval | PASS | 180 samples per route; oscillation negative fixture |
| 16 | Overlap and timeout wording is qualified correctly | PASS | README, corrected historical report and this methodology |
| 17 | All previous Milestone 1 tests pass | PASS | 126/130 checks, zero failures |
| 18 | All corrected Milestone 1.5 tests pass | PASS | 118/127 checks, zero failures; headless repeat also passes |
| 19 | 30/50 stress configurations complete | PASS | Separate launches plus complete routes in headless/graphical suites |
| 20 | No combat or later systems added | PASS | Complete scope/diff review |
| 21 | No unrelated content overwritten | PASS | Pre-repair snapshot comparison and final Git review |

## Remaining limits and verdict

**ACCEPT** Milestone 1.5 with these corrections. Milestone 2 combat can safely begin as scoped work on the tested flat/static foundation. It was not started.

Crowd avoidance still permits partial moving overlap and cannot guarantee passage through every congestion pattern. Simulation trajectories are not lockstep deterministic. Opposing traffic, varied terrain, dynamic navigation, more than 50 units, other platforms and physical input feel remain **NOT VERIFIED**. The baseline gate failure and subsequent varying successful timings remain recorded; these are bounded integration runs, not a soak-test reliability claim. A genuine permanent blockage ends safely in FAILED and a replacement order can resume movement. Assignment remains a bounded deterministic heuristic rather than global optimal path matching. Internal reparenting restores field participation; it deliberately does not implement a cross-field transfer system. External timeout tooling currently requires Windows/PowerShell 7. No later gameplay features, framework, dependencies or numeric tuning changes were added.
