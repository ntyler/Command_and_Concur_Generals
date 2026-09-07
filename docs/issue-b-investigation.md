# Issue B — targeted investigation after the Issue A repair

**Issue B: UNRESOLVED; Milestone 5: STILL BLOCKED.** The original log and source constraints establish that the final settled arrangement placed unit 4 beside a parked peer and would obstruct a direct retry. They do not establish that this arrangement existed before unit 4 failed. The historical reason for exhausting eight recovery attempts remains unknown. No production repair, acceptance waiver or new feature is proposed. The validated Issue A repair and its regressions remain byte-for-byte unchanged.

## Evidence and preservation

The authoritative observation is `validation-output/m5-final-stress-graphical.log`, **11,123 bytes**, SHA-256 `48232a61e259e2728091940229c24116cdfeba687fc3b3164532b59396c2aa43`. Its matching wrapper has SHA-256 `4476e214f2fe17344bf54ad0d69d6431c553dd4f3baa14b948e389325ec0c458`. The wrapper records PID 40872, the 240-second deadline and exit 1. Existing preserved copies of the failed log match. The identically named log under `m5-round1/` is an earlier **passing** execution, not another copy of the failure.

The original log records:

| Observation | Recorded value |
| --- | --- |
| Preceding 50-unit gate | All arrived; 16.283333 simulated seconds; seven total recoveries |
| Gate overlap / minimum settled separation | 65.9 pair-seconds / 1.24369609 |
| Cluster command | `(30,0,22)`; complete acceptance and fresh per-unit orders pass |
| Only non-arrived participant | Unit 4, FAILED, position `(31.41587,0,19.78682)`, assigned `(33,0,22)`, eight recoveries |
| Cluster total recoveries | 14; therefore the other 49 units collectively used six |
| Route completion | 36.0 simulated seconds; **not a recorded unit-4 failure timestamp** |
| Cluster overlap | 105.9 sampled pair-seconds; longest sampled pair run 27.2 seconds, pair identity unknown |
| Settling | Minimum pair separation 0.579999148845673; subsequent displacement zero |
| Navigation / static clearance | Original route assertion passes; navigation sampled at 10 Hz, obstacle clearance checked each route tick |

Only unit 4 has a `ROUTE_DETAIL` failure line. The unchanged harness prints every participant that fails the captured-version, unchanged-assignment, ARRIVED-state or distance predicate. Thus all other 49 passed those conditions. Source-derived unit/group versions remain inferences, not values printed by the original failed run.

No authentic failed 50-unit screenshot or neighbor/path/recovery history was found. The original harness only saved screenshots of the 30-unit routes. Generic metrics were overwritten after the failure: their gate overlap is 62.5, whereas the failed execution records 65.9. Existing successful M5.0.1 captures retain initial/command/final state but omit their intermediate history. These artifacts cannot recover the missing historical state.

Before this follow-up, **144 tracked/nonignored source files** were copied outside the workspace and SHA-256 verified. The path and hashes are in `m501b-before-path.txt` and `m501b-before-hashes.json`. **222 prior evidence files** were copied and hashed under `m501b-preserved/manifest.json`. Final auditing confirms both pristine sets are unchanged. HEAD remains `ebddeb3`; no staging, commits, dependencies or engine changes occurred.

## What can now be inferred

The original destination planner, TestField, original harness, scene and project configuration match the relevant `ebddeb3` source. For the complete 50-unit selection, fixed mesh and `(30,0,22)` command, slot generation is independent of unit positions: there are no unselected reservations. The deterministic slot set is corroborated by later captured commands, with **50 distinct slots and minimum spacing 1.5**. Unit-to-slot identities can differ; the historical neighbor identities are not reconstructed from later IDs.

The original generator's conservative spacing lower bound is 1.499. Two arrived units, each within the assertion's 0.23 tolerance, must therefore remain at least approximately **1.039** apart. Consequently, the original **0.579999** minimum necessarily involved **unit 4 and a parked peer**. It cannot have been a pair of the other 49 successfully arrived units.

Only two slot arrival disks can contain that contact peer:

| Possible parked assignment | Distance from historical unit-4 stop to slot center |
| --- | --- |
| `(31.5,0,19)` | 0.79130498 |
| `(31.5,0,20.5)` | 0.71812504 |

Both are within `0.58 + 0.23`; every other slot is too far away. This does not reveal which peer supplied the measured minimum, whether both were in contact, or when either parked.

There is a stronger geometric constraint on that **final arrangement**. The center of slot `(31.5,0,20.5)` is **0.34668630** from the straight segment between the historical stop and `(33,0,22)`. Allowing the full 0.23 arrival disk, a conservative 0.00001 error in each printed endpoint coordinate and an additional floating-point margin, that parked occupant's maximum possible clearance is **0.57670144**, below moving-plus-parked avoidance radii **0.58**. Its projection remains inside the segment under those bounds. Thus a direct retry from the recorded stop would encounter that parked obstacle under the source's avoidance contract.

The temporal distinction is essential: **the neighbor could have parked after unit 4 failed**. A moving peer approaching the already-FAILED unit would itself use the 0.24 moving radius against unit 4's restored 0.34 parked radius. That can also leave a final separation near 0.58. The final contact and obstructed retry therefore may be consequences of failure, rather than its cause. Neither the 36-second route completion time nor the unidentified 27.2-second pair overlap establishes when this neighbor parked relative to unit 4's failure.

The radius-2.2 neighborhood around the final stop lies east of the fixed cluster obstacle's expanded boundary: minimum x approximately 29.21587 versus obstacle clearance ending at x 27.85. This excludes a local solid wall from that final approach; it says nothing about earlier path-cache state, moving peers or obstacle delays. The original sampled navigation assertion likewise does not certify every navigation callback or cached path.

These constraints do **not** establish an Issue A recovery cycle. Both one-contact and two-contact parked arrangements satisfy the historical observations. The offline analysis includes explicit feasibility witnesses, labeled **hypothetical positions, not historical captures**. It does not run them as replacements for the missing failed state. Eight attempts may have been spent at the final obstruction or earlier on the route. The original record does not distinguish unsuitable candidate selection, premature detour completion, expiry, earlier congestion or an unobserved command/navigation fault.

The reproducible calculations, rounding bounds, source hashes and limitations are in ignored `m501b-geometry-analysis.ps1` and `m501b-geometry-analysis.json`. They use the later slot capture only to corroborate a source-derived slot set, never to claim historical neighbor identities or poses.

## Targeted capture and fixed experiment budget

Two new **test-only** scripts, `tests/issue_b_diagnostic_checks.gd` and `tests/issue_b_diagnostic_history.gd`, retain the unchanged original route assertions. They observe only `cluster_50`; the default invocation preserves the entire original suite sequence. Normal gameplay loads neither script. Existing Issue A and diagnostic scripts were not edited.

The observer records:

* Initial state and the accepted command batch, complete recipients, captured assignments, generations and per-unit versions.
* All 50 units at 4 Hz for the complete route and settling interval, plus state transitions and map/region iterations.
* Unit 4 and whichever unit actually receives `(33,0,22)` at 60 Hz: cached full navigation paths/index, requested/applied velocity, nearby peer poses, radii, priorities, movement state, membership and slide contacts.
* Avoidance callback values after the production listener, with callback frame/order/submitted-order labels and resulting position/velocity.
* Actual recovery targets, progress/stall/attempt state and selected navigation paths. Candidate projection, occupancy, ray, path-length and parked-clearance diagnostics are **recomputed after the transition** and explicitly labeled; they are not observations from the production branch that originally rejected a candidate, and are never test oracles.

The full capture is retained **even when the route passes**. Limits are 320 group samples, 4,800 focused frame records and 1,024 events, covering the unchanged 75-second route plus three-second settling interval. Overflow is explicit and fails the trace-completeness check. All state/velocity listeners are disconnected after each route. The observer does not call `get_next_path_position` or write movement state. Diagnostic neighborhood loops, path queries and allocations can perturb timing; these experiments are not hidden-state replays or performance benchmarks.

The six-run budget was fixed before execution:

1. Three graphical full original-sequence runs on historical M5 production source.
2. Two graphical and one headless replay of the **sole existing archived checkpoint that mapped unit 4 to `(33,0,22)`**, `m501-pair4-baseline-cluster_50.json`.

The replay uses all 50 genuinely arrived gate participants, recorded pre-command poses and counters, and verifies the entire captured assignment/generation map. This later checkpoint was selected for its identity/goal correspondence; it is **not** the missing historical checkpoint. It originated on the M4 comparison source, whose relevant generator/field geometry and movement behavior before Issue A match this scenario, and is replayed here on historical M5 source. There is no population reduction, tolerance change or synthetic failed-state injection.

Historical runs use a separate complete copy of the 136-file pre-repair snapshot, with only the two new diagnostic scripts/UIDs overlaid. All 136 original file hashes still match. The workspace's validated Issue A production source was never rolled back. The copied source and exact commands are identified in `m501b-historical-path.txt`, `m501b-targeted-runs.ps1` and `m501b-targeted-runs.csv`.

## Results and discriminating observations

All six cluster routes passed. This does **not** resolve Issue B.

| Historical-source case | Whole-run checks / failures / exit | Holder of `(33,0,22)` | Closest distance to old stop | Holder recoveries / arrival time |
| --- | --- | --- | --- | --- |
| Full graphical 1 | 132 / 0 / 0 | 32 | 0.207499 | 1 / 8.9000 s |
| Full graphical 2 | 132 / 0 / 0 | 4 | 0.123593 | 0 / 12.9500 s |
| Full graphical 3 | **132 / 2 / 1** | 22 | 0.993490 | 2 / 17.3167 s |
| Matched graphical 1 | 10 / 0 / 0 | 4 | 0.909616 | 1 / 11.9667 s |
| Matched graphical 2 | 10 / 0 / 0 | 4 | 0.921661 | 1 / 12.7167 s |
| Matched headless 1 | 10 / 0 / 0 | 4 | 0.317610 | 0 / 10.2833 s |

Full graphical 3 failed **earlier at `choke_50`**, with unit 10 FAILED at `(4.759132,0,0.024751)`, assigned `(5.5,0,-1.5)`, eight attempts. The arrival and dependent settling assertions failed; the later cluster passed. This is preserved as an ordinary failed execution, not an expected negative or successful run. Since the original Issue B gate passed, this run also fails that prerequisite correspondence. Its gate failure was not pursued or attributed to Issue B.

The closest matching identity/goal episode is full graphical 2. At **12.4 seconds**, unit 4 is `(31.484821,0,19.684248)`, within **0.123593** of the original failed stop. It is CONGESTED with stall history 1.5 seconds, but both applied speed and the nearby timestamped safe callback are approximately **2.97 units/s**. The parked occupants of `(31.5,0,20.5)` and `(31.5,0,19)` are approximately **0.673679** and **0.803963** away. It keeps moving and arrives without recovery. Similar goal/position is therefore insufficient to identify the historical deadlock.

The actual detours supply another discriminating control. Matched graphical 1 selects a detour at `(26.83161,0,19.87408)` whose recomputed path clearance from one parked peer is **0.551285**, below the 0.58 radius sum. Nevertheless it completes the detour in about **0.4 seconds** and arrives. That recovery is over 4.5 units west of the historical stop. Full graphical 3 has a successful detour with clearance 0.525078, but its different gate outcome limits its relevance. An additional intrusion near one millionth of a unit is contact roundoff, not evidence of a meaningful obstruction. A ray-clear path's avoidance-radius intrusion alone is thus **not sufficient proof** of the historical failure or a shared Issue A cause.

All focused recovery episodes in the six traces end after **0.4–0.75 seconds**; none reaches two-second expiry or repeats eight times. Focused versions remain 2; map/region iterations remain fixed within each cluster (full-sequence map 5, replay map 2, region 1); no suspension or physical slide contact is observed. These are observations about the new runs, not reconstructed historical state.

Input hashes, closest approaches, neighboring states and recovery episodes are retained in `m501b-trace-analysis.json`, generated by `m501b-analyze-traces.py`. All seven full trace files have a separate `m501b-trace-manifest.json`.

## Instrumentation validation and limits

Review identified a timestamp-basis gap in the first six captures: callback/event frames are relative, while inherited movement-frame counters are absolute, and trace version 1 omitted their offset. Those captures are preserved unchanged; the analysis does not equate the two clocks or claim same-tick movement-guard verification from them.

Final trace schema 2 stores `first_physics_frame`, callback `absolute_frame`, and the optional Issue A waypoint counter. One additional **headless matched-checkpoint run on the unchanged current workspace** validates the final diagnostic code: **10 checks / zero failures / exit 0**. Offline validation checks **1,092 timestamped callback samples**, all with a consistent relative/absolute offset, complete 50-recipient acceptance and no truncation. This is instrumentation validation, not another attempt to close the historical failure through a passing rerun.

Both editor imports return **0**. The complete execution ledger is **nine engine calls**: six targeted historical runs, one final diagnostic validation, and two imports. Functional totals are **436 checks, two failures**, with the ordinary failed gate run retained. Eight successful engine logs and matching wrapper transcripts contain no errors, warnings or leak diagnostics. The failed run contains the two gate assertion errors, with no additional native diagnostic. No intentional negative fixture was introduced.

`m501b-audit.ps1/.txt` verifies the pristine 144-file validated snapshot, all 136 historical execution source files, 222 preserved evidence files, protected Issue A source/regressions and the final timestamp schema. `git diff --check` passes, including separate whitespace checks for new files. No full acceptance matrix was rerun: production and existing regressions are unchanged, and this work is a scoped diagnosis. No human keyboard/mouse playtest, exact replay determinism or FPS guarantee is claimed.

Example final diagnostic invocation (use a new prefix for each execution):

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$prefix = 'D:/GitHub/Command_and_Concur_Generals/validation-output/new-issue-b'
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments @(
  '--path','.','--fixed-fps','60','--script','res://tests/issue_b_diagnostic_checks.gd',
  '--log-file',"$prefix.log",'--',"--diagnostic-prefix=$prefix")
# This is the complete original graphical suite, with cluster-only observation.
# Add --headless for the headless mode. For the explicit later-checkpoint mode,
# append --issue-b-checkpoint=<absolute captured JSON path> after --.
```

The precise remaining question is **where and why the historical mover spent its eight recovery attempts, and whether the final parked arrangement existed before it failed**. Its actual neighbor poses over time, candidate sequence, detour termination and earlier attempt expenditure are unavailable. The new evidence establishes constraints on the final geometry but neither a complete causal connection to Issue A nor a separately verified failure mechanism. **Issue B: UNRESOLVED; Milestone 5: STILL BLOCKED.** Work stops without changing acceptance requirements or starting a new feature.

## Recovery-budget audit follow-up — 2026-09-07

**Issue A: preserved and regression-tested. Issue B: UNRESOLVED. Milestone 5: STILL BLOCKED.** The audit found no duplicate charging path or demonstrated accounting defect. A synthesized enclosure/control verifies repeated fallback expenditure as a possible sequence, but the original eight-attempt history is still missing. No production change or acceptance correction was made. The earlier evidence and failures above remain part of the record.

The complete [transition table and eight accounting answers](issue-b-recovery-audit.md) cover historical/current source lines, counter/timer/target effects, callbacks, lifetime/order guards and existing test coverage. The [single selected hypothesis](issue-b-recovery-hypotheses.md) was written after source inspection and offline analysis of the existing six traces, before any new simulation.

### Source identity and execution controls

The starting validated workspace was copied and verified as **149 tracked/nonignored files** under the path recorded in `validation-output/m501c-before-path.txt`, with hashes in `m501c-before-hashes.json`. The movement file remains SHA-256 `9b26194e6a0ef505573b0f51a8a7cdb1c409fae24c9526ccae0284cef29bbe2b`; all Issue A regressions and fixtures remain unchanged.

The authentic retained M5 execution source is the complete clean copy addressed by `m5-clean-path.txt`, also corroborated by the complete 129-file first-M5.0.1 snapshot and its original manifest. All 129 first-snapshot hashes match; **127/129 also match the M5 clean copy**. Only README and `docs/milestone-5.md` differ because documentation was finalized after validation. Every executable source, scene, resource and project setting agrees. Historical movement SHA-256 is `1043b608167a411f040cb72151afedddd0d1fd86048f97286d5180226dadcc5c`. The older `m5-snapshot-path.txt` is M4 source and was not used. The original engine did not embed loaded-source hashes; this provenance rests on retained copies, manifests, the original validation driver and the documented clean-copy procedure.

The new historical execution directory was copied from the **complete M5 clean source**, with four test-only diagnostic scripts added. Its path is in `m501c-historical-path.txt`. No selective production rollback was performed. Both source variants and relevant source hashes are separated in the evidence package.

All new simulations used the installed **Godot 4.7.2.stable.official.ed1daf0bf**, executable SHA-256 `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`. Mechanism experiments ran graphically, Windows/OpenGL Compatibility, fixed FPS 60. Captured runtime settings: 60 physics ticks, maximum eight physics steps, jitter fix 0.5, time scale 1, project physics setting `DEFAULT`. Issue A suites ran in both graphical and headless modes. Every engine process ran serially through the unchanged `tools/run-godot.ps1`, external timeout **240 wall seconds**. The harness retained **180 wall seconds**, experiment route **75 simulated seconds**, and unit command **90 simulated seconds**. Each call has a distinct `m501c-*-invocation.json` containing project directory, full argument array, executable/movement hashes, start/end times and exit. The driver is `m501c-run.ps1`.

### Observation boundary

| Category | Supported statement and limit |
| --- | --- |
| Direct original record | Unit 4 prints `attempts=8`, FAILED, its final stop and accepted goal. This is a recorded counter value, not merely a configured maximum. It does not mean eight completed detours or eight rejected searches. |
| Source-derived original terminal cause | With the plain stress scene's fixed map and goal, its accepted fresh order and completion by 36 simulated seconds, the applicable failure path is the later eligible recovery-cap check. That exact terminal branch and unit failure time were not logged. |
| Distinct deadlines | Original command deadline is 90 simulated seconds; route deadline 75; harness deadline 180 wall seconds/exit 2; wrapper deadline 240 wall seconds/exit 124. Original exit 1 is an assertion failure, not either test timeout. |
| Dependent settling assertion | Arrival already failed. Settling additionally requires ARRIVED and minimum separation above 0.6. Original displacement is zero; this is not independent evidence of jitter. |
| Later recorded trajectories | Six cluster passes contain 33 recovery entries, each observed counter delta +1, including four actual final-goal fallbacks. The separately failed preceding gate remains separate. |
| Hypothesis | Persistent no-detour fallback could consume eight attempts; earlier successful recovery episodes could also have consumed some budget. Neither history is recorded for original B. |
| Unknown historical state | Original entry times/positions, candidate choices, progress samples, expiry/clear reasons, callback provenance, and whether final peers parked before or after FAILED. |

### Accounting and the six existing traces

There is **one production increment site**, at `_recover` entry before candidate selection (H line 468, C line 475). A search that finds no detour still spends one attempt and retries the final goal. Candidate dispatch, completion and Issue A's second waypoint do not add another attempt. Meaningful final-route progress clears stall/recovery but deliberately preserves the per-command counter; existing `movement_repair_checks.gd` explicitly tests this. A later eligible insufficient-progress sample fails when the retained count is eight. Extending or repeatedly resetting that budget would change the bounded-work contract without diagnosing B.

Offline extraction accounts for all **33 cluster RECOVERING entries** across the six earlier traces and matches every route's total. Source-attributed termination: **28 waypoint-tolerance clears, three meaningful-progress clears, two final arrivals, no expiry and no cluster failure**. These are attributions from recorded transition values and source, not explicit old branch tags. Five focused probes contain actual targets plus recomputed candidate diagnostics. Other entries have 4 Hz group context. The six bounded excerpts and extraction program are in the ZIP.

Full graphical 1's goal holder 32 spends one fallback attempt; all 12 recomputed rays reject, but its final-route baseline improves by **3.546073** after 0.75 seconds, recovery clears, and count stays one. Full graphical 3's goal holder 22 completes a detour, later earns **0.473358** meaningful progress, keeps count one, then spends attempt two during renewed congestion and eventually arrives. This verifies cumulative accounting across successful episodes, not original B's expenditure; that run also follows the separately failed gate.

The six old traces omit the actual final-goal path query return, signed progress, and `_progress_elapsed`. Cached agent-path length cannot replace that metric, especially after target changes. Their schema-1 relative event/callback frames cannot be equated with absolute movement frames without the omitted offset. These omissions remain explicit; later recordings do not repair historical data.

### One synthesized hypothesis, one control

H1 asks whether continuing local closure can spend repeated fallback attempts and fail at the cap, whereas an ordinary neighbor departure permits progress without a budget refund. The same original obstacle mesh and **50 normally created, registered units** are used. Actor ID4 starts at the printed B stop and receives one public `move_to(33,0,22)`. Ten peers park through public commands on a radius-1.4 ring; their center spacing exceeds the 0.86 body diameter. Thirty-nine spectators stay distant. No initial overlaps, population reduction, private counter/state writes, post-creation teleportation, budget/radius/tolerance changes, or replacement actor orders occur.

These are deliberately synthesized assignments and initialization. Actor version is **1**, group generation **0**, unlike original B's source-inferred version 2/group generation 4. Reusing ID4 and the printed endpoint does not recreate the historical identity or 49-peer slot arrangement. The enclosure's persistent crowd closure is an intentionally bounded outcome, not the original reachable-route acceptance fixture.

The control differs only by commanding the goal-facing neighbor outward after the first naturally observed admission. It remains in the field with collision and avoidance enabled. Parsed initial snapshots match in every field except user arguments; all 50 initial unit records match. The obstacle/navigation geometry is unchanged. The final-goal order remains authoritative throughout both runs.

| Execution | Recorded result | Interpretation |
| --- | --- | --- |
| `m501c-historical-hold-1` | Exit 1; 61 checks, two failed assertions plus native inspector errors. Eight fallbacks/eight expiries, FAILED at 27 s, displacement zero. | Invalid diagnostic validation: reused inspector was outside the tree; shared settling helper required ARRIVED for an intentionally FAILED fixture. Exact earlier harness/probe source and logs are preserved. |
| `m501c-historical-hold-2` | Exit 0; 61 checks. Eight admissions, each +1 and actual final-goal fallback; eight duration expiries; FAILED at 27 s; 180 subsequent ticks with zero displacement. | One specific repeat to repair capture/negative-fixture assertions. Setup, production and mechanism decisions are unchanged. |
| `m501c-historical-control-release-1` | Exit 0; 61 checks. One actual fallback, neighbor departure accepted after admission, actual arrival at 3.35 s with count one; 180 settled ticks, zero displacement. | Clearing the blockage permits progress without refunding or replacing the actor's command. |

The hold spends attempts at **3, 6, 9, 12, 15, 18, 21 and 24 seconds**. Each expires after two seconds of active simulation time; the subsequent eligible progress sample fails at 27 seconds. Actual production query returns show initial progress before the first attempt, then insufficient accumulated final-route progress at each admission. There is no duplicate increment or false progress from changing the temporary target in this fixture. The control's neighbor departs one physics frame after the first admission; actor arrival occurs before that neighbor finishes parking at its new destination.

This is a verified **possible accounting sequence**, not a demonstrated game defect or an Issue B reproduction. It supplies the persistence signature missing from the successful fallbacks, but no original evidence shows that B had such continuing closure. No additional candidate/history campaign, altered tuning, production patch or current/historical comparison was justified.

### New capture coverage and omissions

Only new test scripts `recovery_budget_checks.gd` and `recovery_budget_probe.gd` execute the added instrumentation. Existing diagnostics are reused without edits. A test subclass calls original `super` implementations and records the **actual return from each production final-goal path query**, avoiding duplicate metric queries or a copied progress algorithm. Before/after admission, recovery clear, target change and terminal events retain counter, final/temporary targets, progress timers, group/unit versions, navigation iteration, all registered unit records and physical contacts. State signals record neighbor parking before and during recovery. A bounded **120-movement-record recent buffer** and maximum **512 actor events** retain absolute callback/application frames, requested/safe velocities and actual displacement. Neither valid run truncates capture.

Candidate rejection reasons remain explicitly **recomputed after admission**. They are not original production branch logs. The complete registered-peer list does not reveal Godot's internal chosen RVO neighbors. The callback's visible request/target is recorded, but no engine submission serial exists to prove which request produced that callback. Current absolute frame fields allow alignment without schema-1's missing offset. Instrumentation can affect timing and is not a performance benchmark.

One inherited field needs particular care: **`last_safe_callback` in reused `record()` output is an unpopulated zero placeholder**, because the helper's continuous listeners are not enabled in these new experiments. It must not be read as a computed zero velocity. Actual actor callback inputs are in `recent_motion[].callback.safe`; peer safe velocities were not captured. Raw artifacts are preserved with this limitation rather than silently rewritten.

### Validation, preservation and review package

Issue A's unchanged three-unit reproducer (**14 checks**), distinguishing controls (**84**), and full captured 50-unit arrangement (**10**) each passed in both graphical and headless modes: **216 checks, zero failures**, all six exits 0. They verify actual arrival at accepted goals, bounded recovery, preserved command authority, unchanged parked neighbors and 180-tick settling. These are regression checks for the already validated Issue A repair, not post-fix acceptance evidence for B.

This follow-up used **11 engine calls**: two successful imports, three mechanism/harness executions including the retained invalid first run, and six successful Issue A suites. The valid diagnostic/control pair contributes 122 checks. No timeout self-test or expected exit-2 run is mixed into normal results. No full acceptance matrix was rerun because no supported production correction was made. No human keyboard/mouse playtest is claimed.

The evidence ZIP is at **`D:\GitHub\Command_and_Concur_Generals\validation-output\milestone-5.0.1-issue-b-budget-evidence.zip`**. It contains this updated report, audit/hypothesis tables, original B log/wrapper and relevant provenance, all six bounded excerpts, new event traces/logs including the harness failure, Issue A results, separated historical/current relevant source, diagnostic revisions, exact invocations and SHA-256 manifests. It excludes the engine, `.git`, `.godot`, unrelated project content and generated imports. It is a local archive, not an uploaded artifact.

**Remaining causal uncertainty:** original unit 4's eight admissions cannot be located or classified. The evidence does not establish repeated fallback, an Issue A detour cycle, earlier expenditure during successful progress, or a different mechanism, and does not establish that the final peers were already parked when failure occurred. **No separate production defect was demonstrated in this audit. Issue B: UNRESOLVED; Milestone 5: STILL BLOCKED.**
