# Issue B — full original-sequence capture

**Issue A: PRESERVED. Original-route diagnostic coverage: COMPLETE. Issue B: UNRESOLVED. Milestone 5: STILL BLOCKED.**

The stronger recorder now runs through the original complete stress sequence. Its first historical-source headless execution captured a cluster failure after a successful 50-unit gate: unit 13 exhausted eight recovery attempts while repeatedly selecting a detour that enters parked agents' avoidance clearance. This supplies actual neighbor, command, progress, recovery and movement chronology for a new failure. It does not recover the missing chronology of original Issue B, whose participant and accepted destination differ.

The existing Issue A filter rejects the observed problematic segments when its mathematical predicate is evaluated offline against the recorded geometry. Arrival with current code from this newly captured arrangement has not been executed or established. No production change, additional repair, acceptance waiver or new milestone was made.

## Evidence and unchanged scope

The authoritative original evidence remains [m5-final-stress-graphical.log](../validation-output/m5-final-stress-graphical.log), SHA-256 `48232a61e259e2728091940229c24116cdfeba687fc3b3164532b59396c2aa43`. It records a successful gate, fresh accepted cluster orders, and unit 4 ending FAILED near `(31.41587,0,19.78682)`, assigned `(33,0,22)`, with eight retained attempts. It does not record that unit's terminal frame, earlier recovery targets or neighbor chronology. The original final cleared target is not a waypoint to the origin, and whole-route duration is not its failure time.

The authentic clean M5 snapshot was already available at `C:/Users/Tyler/AppData/Local/Temp/fieldwork-m5-clean-7eb560b8ab974dc691529d21c97cf1d3`. Execution used a separate complete copy at `C:/Users/Tyler/AppData/Local/Temp/fieldwork-m501d-historical-50292613611447bd875432b3a1ed7661`. The [source and schema review](../validation-output/m501d-source-and-schema-review.md) independently rehashed all 129 historical source-comparison paths against the M5-clean column in both locations. The diagnostic copy adds only the five test scripts and their UIDs to the non-generated source inventory. It was not assembled by selectively reverting the current workspace or treating selected review-archive files as a complete project.

Relevant hashes:

| Artifact | SHA-256 |
| --- | --- |
| Historical movement | `1043b608167a411f040cb72151afedddd0d1fd86048f97286d5180226dadcc5c` |
| Current movement, including validated Issue A repair | `9b26194e6a0ef505573b0f51a8a7cdb1c409fae24c9526ccae0284cef29bbe2b` |
| Original stress runner | `ba9d0eb21a4ff9f0f0984f942c30849fe2451b13c77ee6db8f7987104905d3d8` |
| Godot 4.7.2 official console executable | `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643` |
| New full headless capture | `251d83cc59eb3952b356999c3b9354743081f55c01e7b05980e29889e992da82` |

The engine hash above is recorded in every invocation manifest; source and capture hashes are byte hashes of the preserved files. They do not recreate uncaptured original engine/RVO state. The exact engine hash in the manifests is authoritative.

All 155 baseline files match the preserved current snapshot in [m501d-before-hashes.json](../validation-output/m501d-before-hashes.json). They also matched the workspace before the investigation documentation update. Updating the existing investigation document accounts for the subsequent documentation-only baseline difference; current production and the unchanged Issue A test suites retain their original hashes. The new diagnostic scripts and this report are outside that pre-edit baseline. No commit, tag, engine upgrade or dependency installation occurred.

## Test-only wiring and recording scope

Five test-only scripts provide the observation seam:

- [full_sequence_field.gd](../tests/full_sequence_field.gd) delegates the existing unit factory and field registration/command methods. The derived script is installed before tree entry and inherited initialization; stable IDs, ownership, creation order, native name and position are preserved.
- [full_sequence_probe.gd](../tests/full_sequence_probe.gd) delegates inherited unit operations exactly once and records their actual inputs, returned values and resulting state.
- [full_sequence_recorder.gd](../tests/full_sequence_recorder.gd) owns shared event history, cached live membership and bounded recent-motion windows.
- [full_sequence_checks.gd](../tests/full_sequence_checks.gd) inherits the original stress runner and route assertions, changing only field construction and observation boundaries.
- [full_sequence_harness_checks.gd](../tests/full_sequence_harness_checks.gd) separately validates factory/configuration equivalence, command behavior, observations and teardown.

The full run retains the preceding 30-unit field and assignment checks, then `wide_30`, `choke_30`, `L_shape_30`, `cluster_30` and `boundary_30`. It creates the original fresh 50-unit field, executes its assignment checks—including the rejected/subgroup commands that affect command history—then runs `choke_50` and `cluster_50`. After capture closes, the unchanged private recovery fixtures and avoidance-disabled overlap baseline still run. This execution's 124 assertions comprise 122 inherited headless assertions plus two diagnostic completeness/listener checks. The original graphical log has 131 assertions because its nine screenshot-save assertions also execute; inherited `_capture` already returns immediately in headless mode. The instrumentation does not weaken or skip the original applicable assertions.

Only the normal 50-unit avoidance-enabled field is instrumented. Original geometry/navigation, selection, public group dispatch, command generation, movement/avoidance/collision parameters and deadlines remain intact. Production scenes do not load the new diagnostics. The harness compares configuration, registration and command results; it does not require identical avoidance trajectories.

Capture begins from each unit's ordinary creation, before registration and all relevant commands. A gate checkpoint is flushed after its three-second settling sample. The final flush follows cluster completion/deadline and its three-second settling sample. The recorder then closes before the original deliberately synthetic recovery fixtures, which continue unchanged. The runner also retains partial evidence at an incomplete finalization boundary. A hard crash or external process kill cannot guarantee that final flush; the prior checkpoint and manifest remain evidence of the last completed boundary.

## Predetermined budget and every execution

The [run plan](../validation-output/m501d-run-plan.md) was written before execution: validate the diagnostic harness; start with one historical full headless capture followed by one graphical capture; permit at most four further historical graphical captures only when coverage is sound and no fully captured relevant failure has occurred. Its explicit early-stop rule applies after a captured gate or cluster failure, once that original suite finishes.

The first full headless run produced such a failure and completed all later original assertions. The repetition batch stopped there. **No historical full graphical capture, additional full-sequence repetition or optional current full graphical control was run.** Current wiring validation and the unchanged Issue A regressions below are separate purposes.

All fourteen main invocations used the existing external wrapper serially. Their manifest UTC intervals do not overlap. The outer limit was 240 seconds, with the original 180-second wall watchdog, 75-second relevant route deadlines, 90-second movement-command deadline and 60 physics ticks per second unchanged. Exact arguments, source hashes, retained diagnostic source directory and UTC start/end are in each linked manifest.

“Complete” below means diagnostic capture completeness, not gameplay acceptance. “N/A” means that execution does not produce this full-sequence capture format.

| Execution / manifest | Checks | Failed | Exit | Coverage and outcome |
| --- | ---: | ---: | ---: | --- |
| [historical-import-1](../validation-output/m501d-historical-import-1-invocation.json) | N/A | N/A | 0 | N/A; import succeeded without reported errors/warnings. |
| [historical-harness-1](../validation-output/m501d-historical-harness-1-invocation.json) | No total | No total | 1 | Incomplete; harness parser/type-inference errors prevented entry. |
| [historical-harness-2](../validation-output/m501d-historical-harness-2-invocation.json) | No total; 25 PASS lines | No total | 2 | Incomplete; typed-array assignment aborted the coroutine, then the original watchdog expired. Accidental harness failure. |
| [historical-harness-3](../validation-output/m501d-historical-harness-3-invocation.json) | 72 | 2 | 1 | Complete raw capture; invalid harness operation attempted immediate deletion of a locked signal emitter. |
| [historical-harness-4](../validation-output/m501d-historical-harness-4-invocation.json) | 72 | 0 | 0 | Complete; corrected historical wiring, observation and teardown checks pass. |
| [historical-full-headless-1](../validation-output/m501d-historical-full-headless-1-invocation.json) | 124 | 2 | 1 | Complete; cluster arrival failure after a successful gate, plus dependent settling failure. |
| [current-import-1](../validation-output/m501d-current-import-1-invocation.json) | N/A | N/A | 0 | N/A; current import succeeds without reported errors/warnings. |
| [current-harness-1](../validation-output/m501d-current-harness-1-invocation.json) | 72 | 0 | 0 | Complete; current-source wiring and observation validation, including optional waypoint-field support. |
| [A-focused-headless-1](../validation-output/m501d-A-focused-headless-1-invocation.json) | 14 | 0 | 0 | N/A; unchanged focused Issue A suite. |
| [A-controls-headless-1](../validation-output/m501d-A-controls-headless-1-invocation.json) | 84 | 0 | 0 | N/A; unchanged movement/control regression suite. |
| [A-captured-headless-1](../validation-output/m501d-A-captured-headless-1-invocation.json) | 10 | 0 | 0 | N/A; unchanged captured Issue A regression. |
| [A-focused-graphical-1](../validation-output/m501d-A-focused-graphical-1-invocation.json) | 14 | 0 | 0 | N/A; unchanged focused Issue A suite. |
| [A-controls-graphical-1](../validation-output/m501d-A-controls-graphical-1-invocation.json) | 84 | 0 | 0 | N/A; unchanged movement/control regression suite. |
| [A-captured-graphical-1](../validation-output/m501d-A-captured-graphical-1-invocation.json) | 10 | 0 | 0 | N/A; unchanged captured Issue A regression. |

All six Issue A logs and wrappers report their stated totals and contain no engine/script errors, warnings or leak reports: 216 assertions, zero failures across both modes. Both successful harness logs/wrappers and both import logs/wrappers are also clean. The full stress log has exactly 122 PASS lines and the two cluster assertion failures shown below; no additional engine diagnostics were found.

Earlier diagnostic failures remain preserved. Harness 1 required explicit GDScript types for values returned through the recorder interface. Harness 2 required typed-array-compatible assignment for `required_routes`; its wrapper additionally records **two leaked GodotShape3D RID allocations**, absent from its engine log. Its exit 2 is an accidental failed validation, not an expected timeout fixture. Harness 3 attempted `free()` while its target was emitting a signal; Godot rejected the locked emitter. The corrected harness uses supported `queue_free()` and verifies subsequent removal. Passing harness 4 therefore validates deferred deletion and cleanup, not unsupported immediate freeing of a locked emitter. Retained source directories distinguish every attempt from the corrected code.

After the fourteen calls, the unchanged wrapper self-test ran four further engine children serially. Its parent reports **5 checks, 0 failures, exit 0** in the [self-test manifest](../validation-output/m501d-wrapper-self-tests.json) and [output](../validation-output/m501d-wrapper-self-tests.txt):

| Wrapper child | Purpose | Child exit | Interpretation |
| --- | --- | ---: | --- |
| `--version` | Preserve normal successful child exit | 0 | Normal validation. |
| Guarded blocking fixture without opt-in | Verify ordinary invocation is refused | 3 | Intentional negative; expected guard error. |
| Responsive runner with `--verify-timeout` | Verify inherited watchdog exit propagation | 2 | Intentional negative, isolated from normal validation. |
| Blocked fixture with two-second outer limit | Verify external process-tree termination | 124 | Intentional negative; wrapper also checks no child survives. |

The three pre-existing fixture logs were restored and independently rehashed against their recorded prior hashes. These four children bring the task's recorded engine-call total to eighteen; they are not stress reproductions or additional acceptance attempts.

## Full-capture coverage and schema

The canonical [capture](../validation-output/m501d-historical-full-headless-1-capture.json) is 75,618,833 bytes. Its [coverage receipt](../validation-output/m501d-historical-full-headless-1-coverage.json) and [offline analysis](../validation-output/m501d-historical-full-headless-1-analysis.md) independently agree on complete coverage. The [analysis JSON](../validation-output/m501d-historical-full-headless-1-analysis.json) contains detailed validation and canonical event/motion references; [m501d-analyze.py](../validation-output/m501d-analyze.py) performs only offline reads/arithmetic.

- All stable IDs 1–50 are watched once, in creation order, at absolute frame 3859, with order version zero and before field registration. Every observed unit command follows its watch. Field generation is 2; stable IDs are not cross-run instance identities.
- Gate dispatch begins at frame 3864. Cluster dispatch begins at frame 5011. Recording continues through frame 7261, including cluster settling. Run origin is frame 1.
- The capture holds 3,648 events, including 18 recovery admissions, 18 recovery clears, 100 preterminal requests and 100 terminal results. Exactly one preterminal request is FAILED: unit 13 in `cluster_50`.
- The recorder receives 170,050 motion records and archives 26,396 unique records at important boundaries. The archive contains 12,150 received avoidance callbacks with no movement-delegate call, and 14,246 movement-delegate calls; 1,512 of those record zero displacement. These are archive counts, not the whole-route callback population.
- All 1,267 recorded actual final-path query returns in this execution are finite. The failed unit's relevant order includes all 47 actual query records in the compact analysis, with no query or peer-transition truncation.
- Reported event, important-event, group-snapshot, recent-motion, archive and value-budget drops are all zero. Serialization errors, pending delegates and frame mismatches are zero. Independent validation also checks event identity/order, all frame-origin/seconds equations, group membership at important events, referenced motion identity/window bounds, observer-local callback continuity, and recorded displacement versus recorded positions.

Schema version 1 explicitly records absolute frame, run and route origins, relative frames and simulation seconds. The formula is `(absolute_frame - origin_frame) / physics_ticks_per_second`. Command elapsed is a separate production accumulator: unit 13's terminal event is at route time 34.483333 seconds while its command elapsed is approximately 34.5. Wall time and invocation UTC are separate domains. The route metric's 34.5 seconds is neither substituted for that event timestamp nor for original B's unknown terminal time.

The large capture embeds a **pre-write** coverage snapshot. The separate coverage receipt is authoritative for write success and final byte count. The [after-gate receipt](../validation-output/m501d-historical-full-headless-1-after-gate-coverage.json) is deliberately partial because the required cluster boundary had not yet occurred; it is not evidence of lost gate data.

Recording is bounded by 120 recent physics frames and 480 motion records per unit; 24,000 routine/30,000 total events; 1,500 important group snapshots; 120,000 archived motion records; 32,000,000 logical admission-value units; and 268,435,456 serialized bytes. Cached paths are limited to 512 points. The logical budget is an admission estimate, not measured RSS, and serialization does not charge retained data a second time. A limit violation reports loss and makes coverage incomplete. Routine motion older than the recent window expires intentionally unless an important event archived it; no claim is made that every physics frame of the full route remains in the archive.

The recorder reads cached unit/agent properties and actual delegated results. It adds no candidate, navigation-path or physics-space queries inside movement callbacks. Important events may read the agent's already cached path. An empty path immediately after target replacement is an invalidated cache, not evidence that a production query failed. Capture allocation, callback overhead and boundary serialization may perturb wall timing or avoidance scheduling; exact historical replay and observational equivalence are not claimed.

## Observed failure after the successful gate

The original gate route passes every assertion: 16.116667 movement seconds, six retained group recoveries, zero stationary displacement, then three seconds of settling. Its overlap metric is 58.1 pair-seconds. The cluster command result at event 2149 accepts all 50 recipients at generation 4; unit 13 receives order 2 and `(33,0,26.5)`. Cluster movement ends at 34.5 seconds, then the original settling sample completes. The two failed assertions are arrival within configured tolerance and the dependent combined settling/overlap assertion. Stationary maximum displacement is zero; this does not independently demonstrate continuous jitter.

Peer parking predates the failed actor's recovery:

| Peer | ARRIVED event / frame | Cluster seconds | Recorded parked position `(x,z)` |
| --- | --- | ---: | --- |
| 14 | 3387 / 5551 | 9.000000 | `(32.90470505,18.85585594)` |
| 6 | 3399 / 5574 | 9.383333 | `(31.49194145,19.19046402)` |
| 11 | 3408 / 5588 | 9.616667 | `(31.41828728,20.34441376)` |

These peers remain ARRIVED, stationary and avoidance-enabled in the subsequent important observations, with radius approximately 0.34. Unit 13 uses its normal settling radius approximately 0.24.

| Attempt | Admission event / frame | Cluster seconds | Actual selected target `(x,z)` | Clear event / observed recovery elapsed |
| --- | --- | ---: | --- | --- |
| 1 | 3445 / 5640 | 10.483333 | `(32.15862274,20.37711906)` | 3477 / 0.750000 s |
| 2 | 3532 / 5820 | 13.483333 | `(33.54990768,19.25868416)` | 3546 / 2.016667 s |
| 3 | 3553 / 6000 | 16.483333 | Same as attempt 2 | 3561 / 2.016667 s |
| 4 | 3568 / 6180 | 19.483333 | Same as attempt 2 | 3576 / 2.016667 s |
| 5 | 3583 / 6360 | 22.483333 | Same as attempt 2 | 3591 / 2.016667 s |
| 6 | 3598 / 6540 | 25.483333 | Same as attempt 2 | 3606 / 2.016667 s |
| 7 | 3613 / 6720 | 28.483333 | Same as attempt 2 | 3621 / 2.016667 s |
| 8 | 3628 / 6900 | 31.483333 | Same as attempt 2 | 3636 / 2.016667 s |

Each actual admission increments exactly once on the same order. Every selected target differs from the final destination; this sequence is not the earlier synthetic enclosure's repeated final-target retry.

Attempt 1 makes progress. Event 3475 observes remaining path approximately 6.94360399 against baseline 7.79693317, an input-derived reduction of 0.85332918. `_update_progress` clears recovery at event 3477 while the actor is still 1.01689911 from its waypoint. The source's normal meaningful-progress branch explains that clear; this observation alone does not establish a separate state-machine defect.

At attempt 2 the actor is at `(31.40883827,0,19.76447868)`. Subsequent event/motion observations retain that position. Attempts 2–8 select the same detour, and each clear records the `unit_physics` caller, approximately 2.016667 elapsed recovery seconds and 2.20000148 distance to the selected target. The unchanged historical duration guard explains expiry; the recorder leaves its internal executed-branch field unavailable.

For each of those seven attempts, the pre-clear recent window contains 119 actual callback/movement records with that active target. Every recorded movement delegate returns and advances its movement-frame stamp, yet displacement is zero and collision-result lists are empty. Requested speed is approximately 5; actual callback input is approximately `(-0.000028769675,0,0.000048673359)`, a tiny **nonzero** vector with magnitude about `0.00005654016`. This is actual observed callback data, not the old unpopulated zero placeholder. No-movement callbacks and movement calls yielding zero displacement remain separate cases.

Twenty-nine actual final-path samples from event 3530 through 3641 return approximately 6.92091370, with baseline 6.94360399 and signed difference 0.02269030, below the normal 0.3 progress threshold. Event 3642 requests FAILED at absolute frame 7080: eight attempts, stall 23.25 seconds, command elapsed 34.5 seconds and `_update_progress` caller. The source's attempt-cap guard explains the terminal outcome; the 90-second command timeout was not reached. The eighth recovery had already cleared at event 3636, so the preterminal zero recovery target does not erase the separately retained last active target or imply movement toward the origin. Terminal result and post-cleanup state are also captured.

The overlap metrics remain the original test's count of unordered unit pairs less than 0.6 apart, sampled at 10 Hz, adding 0.1 pair-seconds per overlapping pair per sample. They are not a continuous geometric-contact integral or average overlap percentage. The cluster's 88.7 pair-seconds and minimum settled distance approximately 0.57999915 are compatible with the recorded stationary failed actor between parked peers; the independent settling assertion also depends on successful arrival.

## Supported mechanism, existing repair and historical linkage

The [mechanism report](../validation-output/m501d-captured-mechanism.md) and [numerical evidence](../validation-output/m501d-captured-mechanism.json) distinguish recorded values from offline geometry and source-derived explanations. Historical recovery checks endpoint occupancy, a physical center ray and navigation/path-length constraints. They do not reject every path entering combined mover-plus-parked avoidance clearance.

Offline point-to-segment distances for the actual selected segments show this mismatch. Attempt 1 passes peers 6 and 11 at approximately 0.43748225 and 0.47031155. Attempts 2–8 pass peers 6 and 14 at approximately 0.53953242 and 0.54037380. These can clear the 0.43 physical ray radius while entering the relevant approximately 0.58 combined avoidance clearance. Subsequent recorded `next_waypoint` and requested direction support the commanded straight segment; the calculation is not a reconstruction of unobserved candidate rejection reasons or the engine's active neighbor constraints.

The current Issue A path filter rejects these segments under its source predicate, by margins approximately 0.039–0.142, much larger than numeric rounding. This connects the **newly captured failure mechanism** to the acceptance gap already addressed by Issue A at source/predicate level. It does not prove which replacement target current code would choose or that this new arrangement would arrive. The unchanged Issue A fixtures use different participants, goals and neighbor configurations; their passing regressions preserve that validated repair without serving as an exact current/historical comparison for unit 13.

A corrective-task handoff can therefore begin with a focused fixture derived from these captured pre-deadlock events, using ordinary initialization and public parking/move commands on authentic historical and current source. It should verify the existing repair against this arrangement before proposing another production change. Private timer/attempt injection, a new synthetic ring or a fresh passing full-suite rerun would not supply that comparison. That focused comparison was not executed in this diagnostic task.

Original B remains distinct. The new endpoint is approximately 0.02342178 from the rounded original endpoint and both runs have a successful gate and eight retained attempts. However, the new actor is 13 rather than 4, its accepted goal is `(33,0,26.5)` rather than `(33,0,22)`, and only the new run has recovery/neighbor chronology. The original final-state slot constraints permit a nearby arrangement but do not prove that those peers were parked while original unit 4 spent its attempts. A similar final position does not fill that missing history.

## Observation boundaries and conclusion

Actual observations include inherited path-query returns, accepted command results, unit/group versions, state/property changes, recovery admission counts and targets, pre-cleanup terminal intent, every received callback in retained recent windows, and invoked movement delegates with actual displacement. Signed differences and geometric distances are explicitly offline arithmetic over observed inputs. Clear/terminal explanations and current-filter rejection are source-derived. Candidate rejection branches, engine-native avoidance submission identities, RVO active constraints and original B's missing historical timeline remain unavailable. A transition's `before` state is its labelled last observer sample; its `after` state is observed at the signal before later listeners can replace it.

Detailed diagnostics remain test-only. The current production hashes and all unchanged Issue A regressions are preserved. The original full suite completed after the captured failure; the planned reproduction batch stopped. The evidence supports a new historical parked-clearance failure mechanism and complete diagnostic coverage, while original Issue B and full Milestone 5 acceptance remain unresolved. No human keyboard-and-mouse playtest, current-arrangement repair success, historical causal replay or conditional acceptance is claimed.

- **Issue A: PRESERVED**
- **Original-route diagnostic coverage: COMPLETE**
- **Issue B: UNRESOLVED**
- **Milestone 5: STILL BLOCKED**
