# Milestone 1.5 — movement robustness

Implemented and validated on 2026-09-06 with **Godot `4.7.2.stable.official.ed1daf0bf`**. No engine change or third-party dependency was needed.

**Historical report, qualified by Milestone 1.5.1.** The commands, counts, measurements and original acceptance table below describe the recorded Milestone 1.5 runs. [The corrective report](milestone-1.5.1.md) contains current evidence, the separately recorded intermittent pre-fix gate failure, and repairs to command acceptance, signal reentrancy, live crowd mode, scene membership and recovery cleanup. Earlier routes remain useful evidence; the repaired harness now proves a newly accepted order and checks its captured assignments. The older endpoint-only settling check did not independently prove continuous motionlessness.

## Preflight and scope

The working tree was clean at `f00ddb7` (`feat: add RTS controls prototype with initial milestone features`). No applicable AGENTS.md files existed. README, the historical Milestone 1 report, project/main scene, camera, selection, movement, destination assignment and tests were inspected before editing. The existing headless runner passed **126 checks, 0 failures**, exit 0; its baseline log is `validation-output/m15-baseline.log`. There were no pre-existing failures.

The camera and selection implementations, original scene configuration, original obstacle layout and original twelve starting positions are preserved. The existing field builder now accepts an alternate layout instead of duplicating the camera, input or selection systems. No later gameplay systems, autoload managers or external assets were added. No unrelated changes were overwritten and no commits were made.

## Files and architecture

| File | Change |
| --- | --- |
| `scripts/rts_unit.gd` | Built-in avoidance, movement states, progress sampling, bounded recovery, order invalidation and debug indicators |
| `scripts/group_destinations.gd` | Compact bounded search, spatial duplicate/reservation checks and quadratic assignment |
| `scripts/test_field.gd` | Shared layout construction, 30/50-unit option, reservation collection and one debug switch |
| `scenes/movement_stress.tscn` | Clearly designated alternate stress scene, default 30 units |
| `project.godot` | Named F3 movement-debug action; original main scene unchanged |
| `tests/milestone_checks.gd` | All original assertions preserved; adds a watchdog and disables VSync during test playback |
| `tests/movement_stress_checks.gd` | Extends the existing harness with timed routes, measured overlap comparisons, recovery fixtures and timing checks |
| `README.md`, this report | Launch controls, configuration, methodology, evidence and limitations |

The stress layout has 72 × 56 units of ground, open western space, a north/south barrier with a 3.6-unit gate, an L-shaped obstacle in the northeast, and three clustered obstacles in the southeast. Navigation clearance leaves 1.9 units for agent centers across the gate. Units start in five columns at 1.8 spacing, with fixed IDs and fixed camera focus. Thirty and fifty units fit inside the western spawn area. Use the README commands or F6 on the alternate scene to choose it; F5 still runs the original field.

## Crowd and arrival behavior

The solution uses Godot's existing [NavigationAgent3D RVO avoidance](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html), with a short prediction horizon and bounded neighbor count. Navigation remains the global path planner. Safe velocities are speed-limited, projected back onto the clearance mesh, and applied through CharacterBody3D obstacle collision. There are no rigid-body impulses, per-unit scene searches, custom RVO solver or boids system.

Full-radius avoidance alone caused parked rows and obstacle corners to seal passages during development. Agents therefore use a smaller soft radius within eight units of their final slot, during congestion, or while following a recovery detour. This allows partial contact instead of indefinite blocking. Arrived agents have zero speed, higher avoidance priority and a fixed position; they never shuffle their slots to satisfy avoidance. Assigned destinations remain immutable until a new command.

The tested crowd behavior reduces overlap rather than guaranteeing physical separation throughout every frame. Actual unit picking/obstacle capsules have radius 0.43; the soft crowd radii are deliberately smaller. Final destination spacing and arrival tolerances keep resting units separated.

## Destination algorithm

1. Project the clicked point onto navigation.
2. Generate a lattice within a radius proportional to the square root of group size, capped by `maximum_radius` and `candidate_budget`.
3. Visit offsets by squared distance, then x/z ties. Project each candidate onto navigation and reject points beyond the radius cap.
4. Check neighboring spatial buckets to reject close projected duplicates and destinations reserved by unselected units. Check connectivity before accepting a slot.
5. Sort unit and slot indices by x/z, with original index as the final tie break. Pair corresponding ranks, then run a fixed number of strictly improving pair swaps.
6. Verify reachability for every unit before applying the whole command. Failure preserves the previous order.

For C candidate offsets, generation does O(C log C) ordering plus bounded local bucket checks and Godot navigation queries. C is proportional to group size until the hard radius/candidate cap. Assignment is **O(n log n + p·n²)**, where p is the configured fixed number of passes (default three), with O(n) auxiliary storage. There is no routine O(n³) all-pair search. This is a stable, reasonably short assignment, not a global optimal path-cost matching solver.

Reservations are collected once per command from the scene's unit list. No navigation mesh is rebuilt per order. No gameplay code performs per-frame all-pairs crowd comparisons; the overlap instrumentation deliberately does test-only pair comparisons at 10 Hz.

## Movement state and recovery

| State | Meaning |
| --- | --- |
| TRAVELLING | Following a navigation route with meaningful progress |
| CONGESTED | Progress fell below the configured window threshold |
| RECOVERING | A rate-limited local detour or repath was requested |
| ARRIVED | Within final tolerance; stopped and stable |
| FAILED | Recovery or command budget exhausted; stopped safely, ready for a replacement order |

Every 0.75 seconds, the unit queries remaining navigable path length to its final slot. A reduction of at least 0.3 units resets the stalled timer. This uses a best-progress reference so repeated sideways motion or forward/back motion cannot masquerade as progress. Slow positive progress can accumulate across samples. The remaining-distance query runs once per sample, not every physics tick.

After 2.25 seconds without meaningful progress, recovery checks at most twelve candidates on a 2.2-unit ring. Candidates must project close to their proposed point, avoid occupied endpoints and directly obstructed rays, and have a short valid navigation path. A suitable detour is travelled using the ordinary navigation/movement code; no position teleport is used. If none fits, the unit repaths toward its final slot and temporarily raises avoidance priority.

Attempts are separated by at least 2.5 seconds. A detour lasts at most two seconds or until its waypoint is reached. **Corrected in 1.5.1:** meaningful path progress also ends temporary recovery immediately, clears its waypoint and expiration timer, restores normal priority and the assigned navigation target, then reports TRAVELLING. The original implementation only changed the public state while allowing its detour to continue. Arrival clears congestion and the temporary target. At most eight recovery requests are allowed per order; progress cleanup preserves that count. An independent 90-second command deadline bounds even unusual recurrent behavior. Permanent blocking ends in FAILED, never a false ARRIVED signal.

Replacement orders increment an order version and clear submitted velocity, temporary target, attempts, sample history, timers and priority. Avoidance callbacks from an invalidated submission cannot apply obsolete movement. Recovery counters are diagnostic totals for the current order and reset on replacement.

## Configuration

Unit values are typed exports in `scripts/rts_unit.gd`; destination values are in `scripts/group_destinations.gd`. Defaults are the tested configuration.

| Configuration | Default | Purpose |
| --- | --- | --- |
| `movement_speed`, `stopping_distance` | 5.0, 0.22 | Existing speed and final arrival tolerance |
| `crowd_enabled` | true | Built-in avoidance; false is the comparison baseline; its 1.5.1 setter also synchronizes live changes |
| `avoidance_radius`, `settling_radius`, `parked_radius` | 0.36, 0.24, 0.34 | Soft local spacing for travel, congestion/settling and rest |
| `settling_distance` | 8.0 | Start allowing shoulder contact near final slots |
| `neighbor_distance`, `max_neighbors` | 3.0, 10 | Bounded local neighborhood |
| `avoidance_horizon` | 0.25 s | Short prediction horizon suitable for the gate |
| `progress_window`, `meaningful_progress` | 0.75 s, 0.3 | Path-distance progress sampling |
| `stuck_after` | 2.25 s | Sustained lack-of-progress threshold |
| `recovery_interval`, `recovery_duration` | 2.5 s, 2.0 s | Rate limit and temporary detour lifetime |
| `recovery_radius`, `recovery_candidates` | 2.2, 12 | Bounded local detour search |
| `recovery_projection_slack` | 0.35 | Maximum candidate projection displacement |
| `recovery_path_factor` | 1.8 | Maximum detour path length relative to search radius |
| `recovery_waypoint_tolerance` | 0.3 | Finish temporary waypoint |
| `recovery_priority` | 0.65 | Temporary priority; normal 0.5, parked 1.0 |
| `maximum_recoveries`, `command_timeout` | 8, 90 s | Safe termination budgets |
| `slot_spacing` | 1.5 | Minimum distinct destination spacing |
| `maximum_radius`, `radius_scale` | 18, 1.85 | Compactness/search envelope |
| `candidate_budget`, `improvement_passes` | 1600, 3 | Bounded search and assignment work |
| Scene `stress_unit_count` | 30 | CLI/Inspector range 30–50 |
| Scene `movement_debug` | false | F3 or `--movement-debug` toggles all visuals |

Debugging shows the final destination, current path waypoint, movement state, stalled time and recovery count. Labels refresh at 10 Hz when enabled. There is no per-frame console logging. The existing selection rings remain visible independently of movement debugging.

## Validation commands and results

Run from `D:\GitHub\Command_and_Concur_Generals`, with `$godot` set to the console executable in the README. Exact native exit codes are retained with `exit $LASTEXITCODE` in command wrappers. Successful logs are under ignored `validation-output/`.

| Command (optional `--log-file` omitted for readability) | Result | Exit |
| --- | --- | --- |
| `& $godot --version` | `4.7.2.stable.official.ed1daf0bf` | 0 |
| `& $godot --headless --path . --editor --import` | Clean parser/resource import | 0 |
| `& $godot --headless --path . --quit-after 120` | Original main scene launches | 0 |
| `& $godot --headless --path . res://scenes/movement_stress.tscn --quit-after 120` | Stress layout launches with 30 units | 0 |
| `& $godot --headless --path . res://scenes/movement_stress.tscn --quit-after 120 -- --units=50` | Stress layout launches with 50 units | 0 |
| `& $godot --headless --path . --fixed-fps 60 --script res://tests/milestone_checks.gd` | 126 checks, 0 failures | 0 |
| `& $godot --headless --path . --fixed-fps 60 --script res://tests/movement_stress_checks.gd` | 110 checks, 0 failures | 0 |
| `& $godot --path . --fixed-fps 60 --script res://tests/milestone_checks.gd` | 130 checks, 0 failures, including captured frames | 0 |
| `& $godot --path . --fixed-fps 60 --script res://tests/movement_stress_checks.gd` | 119 checks, 0 failures, including nine captures | 0 |
| `& $godot --path . res://scenes/movement_stress.tscn --quit-after 120 -- --units=50 --movement-debug` | Direct graphical stress launch with debug enabled | 0 |
| `& $godot --headless --path . --script res://tests/movement_stress_checks.gd -- --verify-timeout` | Expected `TEST_TIMEOUT` while the event loop remains responsive | **2, expected** |
| `git diff --check` | Clean whitespace check; full diff and new files reviewed | 0 |

The existing assertions were not weakened. All route loops have explicit simulation deadlines (45–75 seconds), and both runners have a 180-second in-process wall deadline. That watchdog requires a responsive event loop; its dedicated self-test intentionally reduces the deadline to 50 ms. Milestone 1.5.1 adds an external PowerShell process timeout that can terminate a blocked main thread, with exit 124 distinct from internal exit 2. Test-only fixture repositioning is clearly marked and is unrelated to production recovery.

The development runs exposed full-radius crowd deadlocks and a graphical oscillation case missed by displacement-only progress detection. Both were fixed. A dedicated oscillation regression now checks that side-to-side movement triggers recovery when navigation distance does not improve. Artificial enclosure tests cover activation threshold, rate limiting, bounded failure, no teleporting, replacement invalidation and resuming after the obstruction is removed. These were introduced during this milestone; baseline checks were clean.

## Historical measured observations

Machine: NVIDIA GeForce RTX 2070 SUPER, OpenGL 3.3 Compatibility, driver 610.88. The graphical stress runner uses fixed 60 Hz simulation with VSync disabled **only in the harness**. This includes rendering and test instrumentation, so it is a development observation, not a promised game FPS target.

| Recorded Milestone 1.5 graphical route | Units | Simulated seconds to complete | Recoveries across group | Minimum settled center spacing |
| --- | --- | --- | --- | --- |
| Wide route | 30 | 5.87 | 0 | 1.446 |
| Gate | 30 | 12.25 | 0 | 1.249 |
| L-shaped route | 30 | 10.55 | 2 | 1.345 |
| Cluster | 30 | 14.13 | 2 | 1.323 |
| Boundary | 30 | 5.18 | 0 | 1.286 |
| Gate | 50 | 17.77 | 7 | 1.167 |
| Cluster | 50 | 15.93 | 5 | 1.312 |

All units on these recorded routes passed the individual 0.22 arrival-tolerance check (with the harness's 0.01 numeric allowance). The old three-second settling check compared endpoints and did not exclude an excursion that returned to its starting point. Milestone 1.5.1 instead samples every physics tick, checks state and velocity, and records maximum displacement. The historical 50-unit routes' measured 95th-percentile physics-frame intervals were **6.47 ms** (gate) and **7.68 ms** (cluster), including rendering/test overhead; these are not isolated navigation CPU timings.

Generation/assignment timing uses `Time.get_ticks_usec()` around each function. Across the final graphical 30/50-unit target cases, generation peaked at **2.770 ms** and assignment at **4.980 ms**. The final headless run measured **3.538 ms** and **7.792 ms**, respectively, while the original regression runner also ran. Every measured call stayed under the explicit 100 ms test ceiling.

The overlap comparison uses the same 50 spawn positions, same target `(10, 0, 0)`, and same assignment algorithm with avoidance enabled/disabled. At 10 Hz, each sampled pair whose centers are less than 0.6 units apart contributes 0.1 pair-seconds. The archived graphical JSON still contains **206.2 pair-seconds disabled versus 63.2 enabled**; `100 * (1 - 63.2 / 206.2)` reproduces **69.4%** after rounding. This is a historical result for that fixed setup and run, not a repeatable percentage or a claim about other crowds. The longest consecutive sampled overlap for one pair on that gate route was an estimated 2.4 seconds; 10 Hz samples do not continuously observe contact. Resting units passed the separation check. The historical headless comparison measured a 66.6% reduction. The current corrected graphical comparison is **67.8%** (206.2 versus 66.4); see the corrective report for all current runs. Avoidance scheduling changes exact trajectories and timings; deterministic slot generation and assignment are tested separately for identical inputs.

Raw final logs: `m15-original.log`, `m15-original-graphical.log`, `m15-stress.log`, `m15-stress-graphical.log`, `m15-import.log`; watchdog output is deliberately separate in `m15-watchdog.log`. Snapshots of stress JSON metrics are `stress-metrics-headless.json` and `stress-metrics-graphical.json`. Subsequent runner executions write `stress-metrics.json` again.

Captured evidence includes `stress_initial_30.png`, `stress_choke_enter.png`, `stress_choke_exit.png`, `stress_cluster_moving.png`, and settled frames for the wide, gate, L, cluster and boundary routes. These filenames are overwritten by later graphical runs. Captured-frame inspection is combined with per-physics-tick obstacle assertions and sampled navigation/overlap/progress measurements. No physical keyboard-and-mouse playtest is claimed.

## Historical acceptance checklist

| # | Required outcome | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Existing Milestone 1 tests pass | PASS | 126 headless / 130 graphical checks; original assertions intact |
| 2 | Original field remains playable | PASS | Original main scene and controls preserved; regression playback and direct launch |
| 3 | Stress layout launches | PASS | Direct launches and graphical route runner |
| 4 | At least 30 stress units | PASS | 30-unit fixture and initial captured frame |
| 5 | 30/50 valid distinct assignments | PASS | Spacing, navigation, bijection, reservations and capacity checks |
| 6 | Deterministic generation | PASS | Exact repeated slot and assignment comparisons |
| 7 | Narrow-gate progress | PASS | Every unit in both groups crosses the exit plane and arrives |
| 8 | L-shaped and clustered routes | PASS | Complete arrivals and per-tick physical obstacle clearance checks |
| 9 | Reachable boundary destinations | PASS | 30/50 assignment cases plus 30-unit complete boundary route |
| 10 | Persistent total overlap reduced | PASS | Enabled/disabled measured comparison; stationary separation asserted |
| 11 | No continuous arrival jitter | QUALIFIED | Historical endpoint comparison alone was insufficient; 1.5.1 now samples all 180 ticks and passes |
| 12 | Progress-over-time stuck detection | PASS | Path-distance windows, brief-slowing and oscillation regression |
| 13 | Bounded, rate-limited recovery | PASS | Physical enclosure, measured attempt intervals, two-attempt fixture limit and watchdog |
| 14 | Replacement clears recovery | PASS | Version, counters, temporary target, stalled timer and agent target asserted immediately |
| 15 | No unbounded tested behavior/logging | PASS | All final routes complete; explicit deadlines; no per-frame gameplay logs |
| 16 | Debug visuals toggle cleanly | PASS | F3 enables/disables labels and waypoints; direct debug launch |
| 17 | Existing controls documented | PASS | README retains camera, selection, Shift, movement and cancellation controls |
| 18 | New configuration/testing documented | PASS | README launch commands and this configuration/validation report |
| 19 | No later gameplay systems | PASS | Complete source/diff scope review |
| 20 | No unrelated changes overwritten | PASS | Clean baseline; camera, selection, license and existing historical report preserved |

## Limits and next milestone

- Avoidance allows partial overlap in dense moving crowds. It is not rigid vehicle collision, and it is not a lockstep-deterministic simulation.
- Tested layouts are flat and static, with groups up to 50 and the documented tuning. Opposing gate traffic, dynamic navigation changes, slopes, arbitrary spacing/radius combinations and larger crowds are NOT VERIFIED.
- Recovery can fail safely on a genuine permanent blockage. A FAILED unit accepts a new order. This does not guarantee that every possible crowded layout can be solved.
- Physical input feel, high-DPI/multi-monitor behavior and other desktop platforms are NOT VERIFIED. Validation used engine input playback and rendered-frame inspection on Windows.
- Slot assignment is bounded and stable, but not globally optimal. Large spacing or a cramped target can be rejected rather than expanding beyond the configured radius.

The original recommendation was additional movement playtesting before combat. Following the passing Milestone 1.5.1 corrections, combat can begin within the validated flat/static scope; physical-input feel, opposing traffic and varied terrain remain unverified. Combat and all later game systems remain unimplemented.
