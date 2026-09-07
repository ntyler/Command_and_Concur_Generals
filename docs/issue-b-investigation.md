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


## Original full-sequence recorder follow-up — 2026-09-07

**Issue A: PRESERVED. Original-route diagnostic coverage: COMPLETE. Issue B: UNRESOLVED. Milestone 5: STILL BLOCKED.** The stronger recorder now observes every participant from normal creation through the original successful gate, cluster termination and settling. The first historical headless execution captured a cluster failure. All inherited assertions finished before further repetitions stopped. This is a newly explained failure on historical source; its causal connection to the original unit 4 failure remains unestablished. No production correction or acceptance change was made.

The [full-sequence report](issue-b-full-sequence.md) contains the complete execution ledger, harness corrections, schema limits, exact observation boundaries and next corrective-task proposal. The ignored `validation-output/m501d-*` artifacts preserve raw observations, authoritative write receipts, independent offline completeness checks, source revisions and exact invocation arrays.

### Implementation and validated coverage

Five new test-only scripts use `TestField._create_unit` and the runner's `_fresh` seam. The original scene and production factory initialize units normally; subclass scripts are installed before tree entry. Production operations delegate once. The full original `_run`, assignment checks, route bodies, deadlines, recovery assertions and avoidance-disabled comparison remain inherited. The preceding 30-unit sequence remains intact; only the ordinary avoidance-enabled 50-unit field is instrumented. Production scenes do not reference these tests. No extra path/candidate/physics-space query was added to movement callbacks.

The corrected historical wiring harness passed **72 checks, zero failures, exit 0 before reproduction**. A current-source wiring harness also passed 72/0. Earlier diagnostic failures are preserved: parser/type inference prevented harness 1 from entering; harness 2 completed 25 PASS assertions before a typed-array error and accidental watchdog exit 2, with two leaked shape RIDs in its wrapper output; harness 3 completed 72 checks with two failures after attempting unsupported immediate freeing of a signal emitter. Harness 4 uses supported queued removal. These are harness failures, not production defects or successful negative tests.

The sole full execution is `m501d-historical-full-headless-1`: **124 checks, two failures, exit 1**. This comprises all 122 original assertions plus two recorder checks. The gate passed at 16.116667 simulated seconds, with all 50 accepted, six recoveries and successful settling. Cluster assignment also accepted all 50. Its arrival assertion failed and the dependent settling assertion failed; later inherited recovery and comparison assertions still completed. The mandatory stop rule ended the repetition batch after this execution. No historical full graphical run, additional four-run batch, ring repetition or optional current full control was performed.

The final receipt covers IDs **1–50**, all watched with order version zero before assignment/gate commands, field generation 2, absolute frames **3859–7261**. It records **3,648 events**, **164 important group snapshots**, **170,050 received callbacks**, and **26,396 archived callback records** in relevant recent windows. All dropped-event counters, serialization errors, pending delegates and frame mismatches are zero. The canonical capture is 75,618,833 bytes. Its separate `-coverage.json` receipt is authoritative for write success; embedded coverage predates the write. The earlier after-gate receipt is deliberately partial. An offline analyzer independently checks all-unit command coverage, clocks, references, callback continuity, displacement and source hashes.

### What this failure establishes

The failed actor is **unit 13**, order 2, group command generation 4, accepted goal **(33, 0, 26.5)**. Terminal intent was recorded before cleanup at absolute frame **7080**, cluster-frame time **34.483333 seconds**, position **(31.408838, 0, 19.764479)**, with eight retained attempts. The whole cluster route took 34.5 seconds; its duration and the actor's frame time are separate measurements. Post-route displacement was zero. The dependent settling failure does not demonstrate jitter.

All eight actual admissions and all 47 final-goal path query observations for that order are retained. The first detour began at 10.483333 seconds and cleared after meaningful final-route progress at 11.233333 seconds, retaining its spent attempt as specified. Attempts 2–8 began at 13.483333 seconds and then at three-second intervals. Each selected the same **non-final target (33.549908, 0, 19.258684)**. Each later clear recorded active elapsed time about 2.016667 seconds. Timer values and source support expiry attribution; the hidden internal branch was not directly instrumented.

Peers 6 and 11 were already ARRIVED before the first attempt, at 9.383333 and 9.616667 seconds. Subsequent important events preserve the complete 50-peer state. The later commanded straight segment passes parked peer 6 at approximately **0.539532** center distance and peer 14 at **0.540374**. Current Issue A's source-derived clearance thresholds for those recorded inputs are approximately **0.578999**. The recorded agent waypoint/request establishes that this segment was actually commanded; the clearance distances are offline arithmetic, not a second runtime navigation query. Peer 6/11 accepted-slot separation is 1.5 and arrival errors are within the existing 0.22 tolerance, unlike a synthetic enclosure with inadmissibly tight parked spacing.

Late retained callback windows show requests with magnitude 5, actual safe inputs with magnitude about **0.00005654**, movement delegates invoked with advancing movement-frame stamps, no reported slide contacts and exactly zero displacement. This is a tiny nonzero avoidance result, not an unpopulated zero placeholder. The last 29 actual remaining-path returns stay at 6.920913696; signed progress against the recorded baseline stays about 0.022690296. The record supports repeated unsuitable selected detours, avoidance suppression and bounded recovery exhaustion. It does not show repeated final-target fallback or duplicate budget charging. The first meaningful-progress clear is ordinary observed behavior, not a newly demonstrated accounting defect.

The current Issue A clearance guard would reject these particular recorded segments. That is a concrete source/geometry comparison, not an executed current-code arrival test. Existing Issue A regressions cover the same mechanism family using different initial arrangements. A later corrective task should first construct a focused normal-creation fixture from this capture's pre-deadlock events and compare historical/current behavior, preserving the public command and acceptance contracts. If current code resolves it, retain a regression; any additional gameplay patch requires evidence from a remaining violated invariant. No new patch is proposed merely to repeat the existing clearance repair.

### Original B linkage and evidence limits

Original B also follows a successful gate and records eight attempts with zero later displacement, but it concerns **unit 4 targeting (33, 0, 22)**. The newly captured endpoint is about 0.023422 units from that printed stop. Different actor, destination, preceding trajectory and rendering mode prevent this similarity from identifying the original cause. The original log still lacks its actual attempt/progress/neighbor chronology. Its final cleared target is not a waypoint to the origin, and its 36-second route duration is not an observed unit failure timestamp. **Original Issue B remains unresolved.**

Actual inherited query returns, callback inputs, commands, counters, timers, targets, movement applications, pre-cleanup terminal state and peer transitions are observations. Signed credit, geometric distances and source branch attributions are explicitly derived. Internal candidate rejection reasons, engine-native callback submission identity and hidden RVO neighbor selection remain unavailable; historical additional-waypoint state is null because that property does not exist. Callback sequence numbers are observer-local. Instrumentation and boundary serialization may perturb timing; neither exact replay nor observational equivalence is claimed. Routine motion outside the bounded recent windows is intentionally omitted, with complete separate command/recovery/terminal chronology.

### Preservation, validation and package

The validated 155-file starting workspace has a pristine verified copy and manifest. All production, scenes, project configuration, acceptance tests and Issue A regressions remain byte-identical. Only this existing investigation document was appended; the other 154 preexisting files remain unchanged. The full 129-file historical project copy matches authentic M5 clean source, with only test instrumentation added. Provenance retains the distinction between the M5 clean snapshot and the later first-M5.0.1 manifest's two documentation differences.

The three unchanged Issue A suites passed in both headless and graphical modes: **14, 84 and 10 checks per mode; 216 checks total, zero failures; all six exits 0**. Both editor imports passed. Wrapper self-tests passed five assertions; their four children returned **0, 3, 2 and 124**, with the last three explicitly intentional negatives. This is **18 engine calls total**: 14 recorded validation/reproduction calls and four wrapper children. Successful-run logs and wrappers are clean. Ordinary failed runs remain failures; the accidental harness-2 timeout is not relabeled as the deliberate watchdog self-test. Earlier generic wrapper logs were restored byte-for-byte after retaining this execution's separate copies.

The local evidence package is **`D:\GitHub\Command_and_Concur_Generals\validation-output\milestone-5.0.1-full-sequence-evidence.zip`**. It includes reports, all execution outcomes, exact commands, provenance, diagnostic revisions, canonical raw captures and receipts, source comparison, offline analysis, wrapper tests and unchanged Issue A results. Its entry manifest and companion SHA-256 file support integrity checks. Explicitly listed redundant intermediate captures remain locally preserved. Engine binaries, caches and unrelated content are excluded. The archive was not uploaded elsewhere. No full acceptance matrix, human keyboard/mouse playtest, acceptance waiver, commit or new milestone was performed by this task.

**Issue A: PRESERVED.**

**Original-route diagnostic coverage: COMPLETE.**

**Issue B: UNRESOLVED.**

**Milestone 5: STILL BLOCKED.**


## Unit 13 derived-fixture comparison — 2026-09-07

**Newly captured unit 13 mechanism: NOT REPRODUCED. Issue A: PRESERVED. Original Issue B: UNRESOLVED. Milestone 5: STILL BLOCKED.** The fixed four-execution comparison did not reproduce the historical actor-13 deadlock. Unit 13 arrived in every execution. This cannot establish that the existing repair resolves that captured failure. Current headless execution also exposed a separate unit-41 failure; no passing graphical outcome erases it. Production and every existing acceptance test remain unchanged.

The [unit-13 comparison report](issue-b-unit13-comparison.md) contains the complete execution ledger and source/observation qualifications. Raw captures, receipts, exact command manifests and offline analyses are under the distinct ignored `validation-output/m501e-*` prefix. Prior results above and all previous evidence remain preserved.

### One fixture, chosen before simulation

The canonical full-sequence capture's event **1947**, absolute frame **5011**, supplies a coherent 50-unit settled arrangement after the successful gate and before cluster dispatch. Event **2149** supplies the actual 50 accepted cluster assignments, including actor 13's **(33, 0, 26.5)**. The initial minimum center separation is **1.178749375**, with no physical capsule overlaps. The maximum old-gate-goal error is **0.217465204**, within the unchanged 0.22 stopping distance. Later pre-deadlock snapshots already contain legitimate runtime crowd overlaps and were rejected as fresh spawn layouts, rather than relocating or deleting participants to make them fit.

New test-only `unit13_fixture_field.gd` uses the existing recorded factory, setting only captured spawn positions before tree entry. `unit13_fixture_checks.gd` reuses the unchanged recorder/probe, setup inspector and settling helper. Public per-unit moves to the captured old gate goals establish ordinary parked state and radius, followed by 180 settled physics ticks. All 50 then receive their exact captured cluster goals synchronously through public `move_to`. Natural versions are 1 for parking and 2 for cluster; field command generation remains 0. No assignment generation, private timer/counter restoration, forced recovery, moving-peer freezing, final-failed-position initialization or synthetic ring is used.

This is explicitly a **derived cluster-only fixture**, not an exact replay or the original full stress sequence. It omits the earlier 30-unit and gate trajectories and creates fresh navigation/RVO objects. Critical peers 14, 6 and 11 continue through normal commands; their arrival order and parked geometry are observed rather than scheduled to match the earlier recording. Fixture SHA-256 is `d56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307`.

Both projects imported successfully. The first historical harness failed to parse a new inferred `watched` variable; its exact source and exit-1 log remain retained. An explicit Boolean type corrected that test-only error. Historical harness 2 and current harness 1 each passed **24 checks, zero failures, exit 0**. Their complete intended setup/command artifacts compare exactly equal; an independent 30-check comparison passes. Both observe all 50 before commands and free the field synchronously before any cluster physics step, so harness validation did not spend unreported mechanism attempts.

### The entire fixed mechanism budget

Fixture and diagnostic source hashes were frozen before the first mechanism execution. All four cases used identical intended inputs, Godot 4.7.2, 60 physics ticks, unchanged 75-second route/90-second command bounds, the inherited 180-second wall watchdog and unchanged 240-second wrapper. No source/fixture retuning or additional mechanism run followed any outcome.

| Execution | Checks / failures | Exit | Actual movement outcome | Capture |
| --- | --- | --- | --- | --- |
| Historical headless | 29 / 1 | 1 | All 50 ARRIVED; movement 13.216667 s; zero settled displacement | Complete |
| Current headless | 29 / 3 | 1 | Actor 13 ARRIVED; unit 41 FAILED; movement 33.75 s | Complete |
| Historical graphical | 29 / 1 | 1 | All 50 ARRIVED; movement 14.45 s; zero settled displacement | Complete |
| Current graphical | 29 / 1 | 1 | All 50 ARRIVED; movement 13.816667 s; zero settled displacement | Complete |

Every execution failed the added combined step-size/attempt-bound assertion because of step size; no excess recovery count was found. Current headless additionally failed all-unit arrival and the original combined settling/separation check. Thus none is relabeled a passing control. Complete coverage means all required observations serialized, not that gameplay assertions passed. Independent checks confirm all 50 precommand watches, actual query/command/terminal records, frame mappings, bounded callback continuity, source identity, zero drops/errors and listener cleanup in all four captures.

### Two separately supported findings

**Navigation projection can enlarge an actual step.** The runner's all-frame maxima are approximately 0.131343, 0.130015, 0.133597 and 0.133418 in the table's order, above the added `movement_speed / 60 + 0.001` threshold (about 0.084333). In historical headless, archived unit-9 motion record **32059**, frame **642**, directly records a single movement call with input speed about 5, delta 1/60, no contacts and one movement-frame advance, but displacement about **0.129262486**. The proposed position near an expanded obstacle corner projects to a different nearest boundary, increasing the net displacement. This is actual delegated movement, not merely a sampling artifact. The unchanged historical/current projection code explains it; the prior canonical full-sequence capture already contains comparable excess steps. This does not demonstrate a new Issue A regression or fixture teleportation. The exact actor/frame of each runner-wide maximum is not necessarily retained in bounded motion windows. The original full stress suite did not include this extra all-route step bound, and its existing predicates were not changed here.

**Current unit 41 exhibits a distinct boundary/fallback stall.** It retains accepted goal **(28.5, 0, 17.5)** and order 2, stops near **(26.276518, 0, 18.849998)**, and fails with eight attempts at command elapsed **33.75 seconds**. All eight actual selected targets equal the final goal, unlike the earlier actor-13 repeated non-final detours. Recorded expiry clears, insufficient actual path progress and pre-cleanup terminal state support bounded exhaustion. Peer 49 was already parked nearby; final separation is about **0.572740**, below the unchanged 0.6 requirement. Stationary displacement is zero, so this is not an independently demonstrated jitter defect.

Actual unit-41 callbacks request movement east along the cached navigation path but receive approximately **(-0.0000227, 0, -1.566061)**. Those inputs point outside the local walkable boundary. Recorded movement delegates advance their frame stamps yet apply zero displacement with no slide contacts. Source and offline polygon geometry explain projection canceling that movement. The current final-path retry remains blocked by parked peer 49, while the bounded detour selector found no selected alternative. Individual candidate rejection reasons and native RVO active constraints were not recorded; no unobserved rejection branch is presented as an actual event. The separate unit-41 report retains every admission/clear, neighboring state and relevant motion window, including explicit missing aged-frame counts.

These findings do not justify a patch in this task. A separate corrective task can use the unit-41 capture to test a navigable escape around the parked blocker within the existing recovery duration/attempt contract, first distinguishing whether a shorter legal detour is available. That is a candidate repair direction requiring actual validation, not a proven fix or permission to change tolerances/radii. The projection step excess separately warrants checking speed-bounded navigation traversal around corners rather than applying an unverified clamp that might leave a step off-mesh. Neither finding supplies original unit 4's missing chronology.

### Preservation and delivery

The current starting source has a verified **166-file** snapshot. Production, scenes, existing diagnostics, Issue A repair/regressions and acceptance predicates remain byte-identical; this existing investigation document is appended without changing its prior bytes. The authentic complete historical 129-file source remains isolated and unchanged. Across those common paths, only the existing Issue A movement implementation and two documentation files differ from current source. Each execution retains the actual diagnostic revision and invocation hashes.

All six unchanged Issue A regressions passed: **14, 84 and 10 checks in each mode; 216 checks, zero failures, six exits 0**. Wrapper self-tests passed five checks with parent exit 0; their four intentional/normal children returned **0, 3, 2, 124**. Prior generic wrapper logs were restored byte-for-byte. Total execution accounting is **19 engine children**: 15 import/harness/mechanism/regression calls and four wrapper children. The parser failure and four failed mechanism executions remain ordinary failures, separate from deliberate wrapper negatives. Successful dedicated logs/wrappers contain no errors, warnings or leaks.

The local archive is **`D:\GitHub\Command_and_Concur_Generals\validation-output\milestone-5.0.1-unit13-comparison-evidence.zip`**, with a companion SHA-256 file and verified per-entry manifest. It contains frozen fixture/test source, provenance, every execution outcome, canonical source observations, all new captures/receipts, failure analyses and updated conclusions. It excludes engine binaries, caches and unrelated content. No full stress rerun, extra mechanism batch, human playtest, production patch, commit, waiver or new feature was performed by this task.

**Newly captured unit 13 mechanism: NOT REPRODUCED.**

**Issue A: PRESERVED.**

**Original Issue B: UNRESOLVED.**

**Milestone 5: STILL BLOCKED.**

## Unit 41 targeted repair attempt — 2026-09-07

**Unit 41 boundary stall: NOT REPRODUCED in the two authorized baselines. No production patch was made.** The earlier captured failure remains valid and unresolved. The [bounded repair-attempt report](issue-b-unit41-repair.md) records the fixed budget, diagnostic patch, exact inputs, complete execution ledger and limitations.

The new test-only inherited runner preserves all 50 participants, frozen fixture bytes, normal creation/public commands, exact goals and all existing assertions. A narrow unit-41 probe delegates actual selector and Issue A clearance calls without adding native queries. Wiring passed 26/0 before any cluster movement; 24 independent capture checks and positive/negative offline classifier checks passed before baseline 1.

Both unchanged-source headless baselines ended **30 checks, one failure, exit 1**, with complete independently validated captures. Unit 41 arrived at (28.5,0,17.5) on natural order 2 without recovery at command times 6.533333 and 8.516667 seconds. All 50 arrived and passed original navigation/obstacle and 180-tick settling/separation predicates. Neither run enters unit-41 selection, so no new candidate rejection or shorter-leg traversal evidence exists. Both baseline slots are spent; no post-change run or new batch occurred.

The unchanged step assertion independently fails: maximum sampled displacements .132907867 and .130544767 exceed 5/60+.001. Actual single returned-call excesses are retained, including unit33 motion25983 (.132907860055) and unit9 motion30309 (.128904017798). The separate projection issue is not repaired, waived or relabeled as passing.

All six unchanged Issue A regressions pass **216 checks, zero failures**. The entire ledger contains **10 serial engine calls, 302 assertions and two failures**, including import and pre-movement wiring. Import's retained nested-project discovery warning is documented. All original production, fixtures and tests remain unchanged; all 2,670 prior evidence hashes remain preserved, and this section appends to the prior investigation without erasure.

The compact evidence archive is `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-unit41-boundary-evidence.zip`; its actual SHA-256 is in the companion `.sha256` and `m501f-package-result.json`. Source manifests, exact commands, exit codes, receipts, raw captures and separate failures remain inspectable. No acceptance waiver, commit, feature or new milestone occurred.

**Unit 41 boundary stall: NOT REPRODUCED. Issue A: PRESERVED. Projection step-size issue: UNRESOLVED. Original Issue B: UNRESOLVED. Milestone 5: STILL BLOCKED.**


## Navigation projection step-size repair — 2026-09-07

**Projection step-size issue: VERIFIED RESOLVED for the demonstrated mechanism on final source. Milestone 5 remains STILL BLOCKED.** The [projection repair report](issue-b-projection-repair.md) preserves the regression, both production revisions, all failures, execution budget and remaining limitations. The earlier unit 41 failure, its closed two-baseline budget, and original Issue B remain unresolved.

After validated test-only instrumentation, the first unchanged-production baseline failed **32 checks / 2 failures, exit 1**, with **34 actual single-call displacement excesses** and a complete capture. All 50 units arrived; the unchanged step predicates failed. No second baseline ran. Additional native queries and separately labeled offline geometry demonstrate projection switching across a nonconvex corner: the direct projected chord crosses excluded navigation, while a bounded first native path leg is available.

The final production change adds **11 lines only in `_move_on_navigation`**. When projection changes the proposed endpoint and enlarges the callback's step, it traverses at most the first navigable leg within that callback budget, stopping at the bend. It preserves Issue A's guard, avoidance, separation, accepted-goal authority, movement parameters, recovery duration, attempts and deadline. No threshold or existing assertion changes.

The initial candidate failed unchanged movement regressions **82/3**. Its missing-input diagnostic helper later errored after public cluster dispatch and was terminated **exit -1**, with 15 observed passes and no complete capture. Because live movement could continue, that failed helper conservatively consumed **post-change slot 1**. A corrected read-only query harness passed **34/0** with independently verified zero cluster ticks. Native queries exposed 118/256 strict-distance triggers with no actual projection correction, supporting the final changed-projection guard. Every failure and source revision remains retained; no missing trace is presented as complete.

The sole remaining final post run passed **32/0, exit 0**. All **23,652 actual movement calls** were bounded, and all **37** observed projection-excess opportunities actually followed the bounded first navigable leg. Maximum actual/sample step was **0.083335273**, below unchanged **5/60+.001**. All 50 arrived; unit 41 reached authoritative `(28.5,0,17.5)` on order 2. Original navigation/obstacle constraints and exactly **180 settling ticks** passed, with zero stationary displacement and minimum separation **1.261444330 > .6**. These arrivals do not reproduce or resolve the captured unit 41 stall.

All six unchanged Issue A regressions passed **216/0**. Final movement regressions passed **164/0** across headless/graphical modes. The complete ledger has **14 engine executions**, **591 completed-suite assertions / 5 retained failures**, plus the incomplete helper. The baseline/final 182-file comparison changes only production movement; the 179-file starting snapshot and 4,623 prior evidence files are hash-audited. This section appends without altering earlier bytes. No acceptance waiver, commit, feature or further milestone occurred.

Final movement SHA-256: `1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4`. Evidence archive: `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-projection-step-evidence.zip`, with actual SHA-256 in its companion checksum and `m501g-package-result.json`. Exact engine commands, source hashes, exits, captures, incomplete-execution limitations and failed offline reviews remain preserved.

**Projection step-size issue: VERIFIED RESOLVED. Issue A: PRESERVED. Unit 41 boundary stall: UNRESOLVED. Original Issue B: UNRESOLVED. Milestone 5: STILL BLOCKED.**


## Unit 41 retained-evidence reproduction design — 2026-09-07

**Reproduction design: INSUFFICIENT EVIDENCE.** The [retained-evidence design report](issue-b-unit41-reproduction-design.md) identifies meaningful prerequisites and the missing formation chronology. This task performs **zero Godot executions or native navigation queries**, changes no production/test/fixture/acceptance requirement, and reopens no execution budget. The verified projection repair and Issue A remain unchanged, without new runtime verification.

The E failure, F baselines1/2 and finalGpost2 have byte-identical intended wiring and exact public commands. Their first shared progress-query sample already differs at **frame233, route.733333**, before peer49 parks. E event788 and F/G event786 have different positions and actual last-received callback values, initially with the same next waypoint. Later cached approach waypoints differ. No distinct public scheduling input is observed to explain the initial divergence.

The F controls do not exercise E's parked-peer-before-stall prerequisite: unit41 arrives at route **6.516667/8.5** seconds, whereas peer49 parks at **12.466667/10.983333**. G peer49 parks at **5.483333**, before unit41 arrives at **6.533333**, but G follows a different approach; its closest retained moving-41/parked-49 group sample is **2.290307** apart versus E's **.572733**. These are actual sampled chronologies, not native solver membership or continuous minimum distances.

E's unit41 active movement archive omits **frames189–653 inclusive,465 frames**. It begins at654, after a separate event already observes the near-stop at638. Only one retained movement precedes the exact stopped state at655. The archive cannot recover the actual movement/path/neighbor sequence that formed the cancellation. Complete coverage receipts certify bounded capture integrity, not continuous historical motion. F/G also omit early active windows.

All **1,550 retained exact-stop zero calls**, including **1,432 after first recovery**, have source/offline geometry predicting that the final projection repair's extra branch remains inactive: projected displacement0 does not exceed the positive callback budget. This is not a new native projection query or runtime replay. G's actual unit41 approach corrections at **events1032/frame338 and1540/frame526** operate on different inputs; successful arrival does not demonstrate resolution of E's stall. Eight E final-goal retries, parked-peer chronology and the historical failure remain valid.

No new fixture or two-baseline proposal is supported. The smallest next action requiring separate authorization is **test-only continuous approach/peer/selection instrumentation** beginning at public cluster dispatch, retaining actual calls and cached path/neighbor changes through the first boundary transition and recovery. It must be validated before any separately authorized, fixed-budget observation run. Delayed actor commands, forced peer schedules, failed-stop initialization and hypothetical shorter escape legs are not justified by the retained comparisons.

The183-file starting source snapshot and7,344 prior evidence files are hash-audited. Prior investigation bytes remain intact. Final offline analyses pass8/20/8/36 checks; failed analytical attempts, exact scripts/commands/input hashes, outputs and exits remain preserved. The evidence ZIP is `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-unit41-reproduction-design-evidence.zip`, with actual SHA-256 in the companion checksum and `m501h-package-result.json`. No stage, commit, acceptance waiver or new milestone occurred.

**Reproduction design: INSUFFICIENT EVIDENCE. Projection step-size repair and Issue A: unchanged; no new runtime verification. Unit 41 boundary stall: UNRESOLVED. Original Issue B: UNRESOLVED. Milestone 5: STILL BLOCKED.**


## Continuous approach recorder implementation and validation — 2026-09-07

The [continuous recorder report](issue-b-continuous-recorder.md) delivers separate test-only instrumentation and bounded validation. **Unit 41 and original Issue B remain unresolved; Milestone 5 remains blocked.** The closed reproduction budgets were not reopened. Production, all existing tests, the frozen 50-unit fixture and all acceptance predicates remain unchanged.

The recorder retains every participant in every frame, starting with immutable initial states before public commands. It captures completed actual callback/direct-movement records, cached path/index changes, peer state, commands, and actual inherited selector/Issue A clearance returns. A common observation sequence orders nested events and delegate completion. It adds no diagnostic native navigation query. Hard frame/byte limits fail closed without aged-history eviction; missing frames, participants, unfinished delegates, write failures or absent footers cannot be reported complete.

The validation launcher has no cluster-dispatch path and validates exact inputs before starting the fixed runner. The predetermined parser/contract/parked allowance used **three engine calls: one parser, one synthetic contract, one parked wiring; zero engine reruns and zero reproduction slots**. Parser exited0. Synthetic contract passed13/0 with no live actors, including real writer capacity and unavailable-output controls. The parked execution passed6/0 using normal creation, all50 original public parking commands and the unchanged180tick stationary sampler, followed by synchronous field teardown.

Independent parked validation confirms frames1–189 inclusive,9,450 participant rows and9,450 completed avoidance callbacks,189 per participant. There are zero movement calls, advancing movement stamps, cluster commands or sampled displacement. All28,901 shared observation sequence values are contiguous and unique. Footer totals, initial-before-command ordering and teardown pass15 supplemental checks. This validates parked wiring, not moving-route or recovery behavior.

The first independent contract analysis failed with601 schema errors, exit2: Godot had serialized integral numeric fields as1.0 and the Python validator required lexical integers. That failure and source remain preserved. A narrow exact-integral numeric compatibility correction, including fractional/bool/unsafe-float negatives, validates the identical retained capture bytes without an engine rerun. Separate capacity/byte-limit streams correctly remain invalid, exit2. Final offline validator tests pass50/0, launcher non-launch tests6/0, and parser/contract receipt review22/0. Earlier successful test revisions and every rejected analysis remain retained.

No live moving callback, recovery selection or full-route capacity/overhead claim is established. The reserved route schema has no executable route adapter in this validation launcher. A future original-fixture observation requires separate authorization and a predetermined budget; no causal fixture, speculative repair, acceptance waiver or automatic batch follows this task. The missing E formation chronology is not reconstructed by parked validation.

The184-file starting source snapshot and7,422 prior evidence files are hash-audited. Prior investigation bytes remain intact. Production remains SHA256 `1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4`; no IssueA or moving-runtime regression rerun occurred. Exact commands, source/input hashes, outputs, exits, capture completeness, failures and review receipts are under `validation-output/m501i-*`. The compact archive is `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-continuous-recorder-evidence.zip`, with actual SHA256 in its companion checksum and `m501i-package-result.json`. No commit or new milestone occurred.

**Continuous recorder: VALIDATED for synthetic contract and parked wiring; moving integration unverified. Projection step-size repair and Issue A: unchanged; no new moving-runtime or Issue A regression verification. Unit 41 boundary stall: UNRESOLVED. Original Issue B: UNRESOLVED. Milestone 5: STILL BLOCKED.**


## Single continuous frozen-fixture observation — 2026-09-07

The [continuous observation report](issue-b-unit41-continuous-observation.md) completes the authorized test-only integration and exactly one moving observation. **Unit41 historical boundary stall: NOT REPRODUCED; still UNRESOLVED. Original Issue B: UNRESOLVED. Milestone5: STILL BLOCKED.** No production repair, commit or second observation follows.

The new runner inherits the unchanged unit41/unit13 cluster observer and180tick stationary sampler. Original population, normal creation, geometry, exact public goals, movement/attempt parameters, navigation/obstacle, step, arrival, settling/separation and deadlines remain unchanged. Cluster dispatch still occurs immediately in the original physics-frame continuation at189; only final teardown drains the last callbacks. J's actual wiring bytes equal E/F/G, SHA256 `fcf629e7ae2d04a6e49f8e99cb724fb3dd97721dcf240017a40512d6547827c8`.

The predetermined allowance used parser1 (exit1 for a missing type annotation in new test code), corrected parser2 (exit0), one precluster validation (19/0,exit0), and the sole moving observation (33/0,exit0). The parser failure and source remain preserved. The launch guard reserves its single slot before launching and refuses replay; all further observation attempts are closed. Offline checks pass203 source-correspondence/preservation assertions,98 validator/launcher tests,16 precluster review checks,217 final integrity/source/slot checks and17 chronology checks. Earlier failed offline helper/inspection attempts remain retained separately.

The actual moving stream is independently complete: frames1–1967,98,350 callbacks,25,389 returned movement calls with matching advancing stamps, no contacts and no step-size excess. Maximum actual/sample step is approximately.08333524, below5/60+.001. All50 are observed ARRIVED by1786; the original180tick sampler completes through1967 with zero stationary displacement and minimum separation1.165431023>.6. The181complete frames after the earliest recorded all-arrived observation reflect the existing sampling phase; no settling requirement changed. All297,911 observation-clock points are contiguous and unique.

Unit41 accepts its exact goal on order2 atseq857/frame189 and arrives atterminal seq2840/2842,frame622,elapsed7.233333,with0recoveries. Peer49 parks later atseq3588/3590,frame937,after2attempts. Unit41 has433actual movements, zero zero-displacement calls, no recovery/selection events, and no visit to E's boundary strip. Its complete13-point initial cached path is now retained atseq935/frame189, through the northern corridor. E's initial path and active frames189–653 remain missing. The first common progress sample at233 already differs by.257367086 with the same next waypoint; the source of that early divergence remains unknown.

Peer49's3actual selector returns and11actual clearance returns over2recovery attempts are captured after41arrives. They verify live recording of decision inputs/returns but are not unit41 recovery evidence or a proven shorter-escape solution. Source/offline measurements remain distinguished from actual native method returns and unavailable solver internals. No causally supported public-command trigger or new fixture is established by the passing observation.

Before engines, retained-size analysis showed1GiB would leave only5.6MB before additional moving events at full deadline. A separate J4GiB evidence-storage profile preserves the old I1GiB implementation and all gameplay thresholds; it retains hard limits and never evicts history. The actual capture is366,866,324bytes, SHA256 `2eac3d698cd36e9acc41eda885e8e46895e61938f9b51f9b79abc6bdb578ead9`.

The194-file starting source and8,179prior evidence files are hash-audited. Production remains `1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4`; all existing regressions/fixtures and prior investigation bytes are preserved. IssueA's separate regression suite was not rerun; its repair and prior validation remain unchanged. Exact commands, source/input hashes, totals, exits, captures, failures and analyses remain under `validation-output/m501j-*`. Archive: `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-continuous-observation-evidence.zip`, with actual SHA256 in its companion checksum and m501j-package-result.json. No further runtime or repair is started.

**Unit41 boundary stall: NOT REPRODUCED; UNRESOLVED. Projection step-size repair: PRESERVED, no excess in this observation. IssueA: PRESERVED, no separate regression rerun. Original IssueB: UNRESOLVED. Milestone5: STILL BLOCKED.**


## Current-build boundary/neighbor repair — 2026-09-07

The separately authorized current-build task established a new five-unit public-command regression on the existing stress geometry. A stationary fence has a usable route around its far end: the public detour witness arrives in3.0167 total seconds, whereas the unchanged single-command baseline fails after27 seconds and eight ineffective recoveries. This is a new behavioral fixture, not historical unit41 or original IssueB replay.

The supported production correction plans at most two clearance-checked local escape legs within the unchanged recovery duration, attempt count, movement parameters and command deadline. The first implementation was rejected by the unchanged IssueA guard and remained an ordinary failed run. The corrected wider approach passes the focused headless and graphical cases, reaches the accepted goal in5.8167 seconds with one attempt, and preserves180-tick settling/separation. Both final eight-case public-command control suites pass193 checks, including Move/X Stop during each planned recovery leg, neighbor departure, occupied-goal bounded failure/replacement and a nearby geometric variation.

The32-run existing gameplay matrix passes30 executions. Both original stress sequences fail at the gate (122/12 headless,131/12 graphical), including the avoidance-disabled control. One attribution run using this task's saved starting source also fails122/12 at the gate, so that failure predates the new local correction. No exact projection mechanism is inferred from endpoints. IssueA and projection regressions pass unchanged; integration acceptance remains FAIL. Across this task45 engine invocations retain5,114 assertions and42 failures; no failed result is waived.

See [current movement repair report](milestone-5-current-movement-repair.md) for the patch, exact before/after mechanism, complete execution records and limits. Evidence stays in `validation-output/m5-current-reliability/`; original fixed output hashes were restored. No historical execution budget, commit, acceptance waiver or new milestone was used.

**Current behavioral regression: PASSING. Supported production correction: IMPLEMENTED. Existing integration validation: FAIL. Historical unit41: UNRESOLVED. Original IssueB: UNRESOLVED. Milestone5: STILL BLOCKED.**

## Current gate repair — 2026-09-07

The separately authorized gate task reproduced the current numerical boundary stall before changing production. The original fresh50 disabled-avoidance gate setup, normal creation and public group goal(10,0,0) fail14 checks/3 failures. Actual unit20 event19/frame280 receives a bounded velocity, advances its movement stamp once and returns zero displacement without contacts. Additional post-call native queries show a path-start discrepancy of0.00003517m, exceeding the projection repair's unchanged0.00001m start guard. These are diagnostic queries, not intercepted production query returns. Disabling query optimization preserves the discrepancy and was rejected as a remedy.

The supported correction retains the bounded first path leg when both actual endpoints belong to one verified current rectangular navigation cell. Exact closed bounds and convexity establish the entire segment's legality; no speed, clearance or tolerance is increased. All32 other existing production function bodies, parameters, IssueA guard and prior boundary/neighbor repair remain unchanged. Baseline and repaired disabled headless event19/frame280 have identical actual start/input/delta/stamps; actual displacement changes from0 to0.083333313465m along the legal boundary, then the next call reaches the corner. Both disabled modes pass14/14; all50 arrive and settle for180 ticks with minimum separation1.41295m.

Enabled headless passes39/39. The planned enabled graphical run remains an ordinary39/3 failure: unit23 stops approximately at(-2.85,0,-1.918918), accepted destination(8.5,0,0), after8 attempts. Only20 was observed, so23's failed movement/decision is unavailable. One directed observation of20+23 passes39/39 with23 arriving without recovery; its older approach movements aged out, and retained events show a passing approach. This does not resolve the failed run or establish a causal basis for another automatic batch.

The original full movement sequence now passes122/122 headless and131/131 graphical. All36 final integration executions pass4,740 assertions, including unchanged IssueA, projection, prior boundary recovery/controls and existing gameplay checks. Across this task48 engine invocations preserve4,929 assertions and6 failures in the baseline and graphical23 run. All46 exit-zero native logs have no error/warning headers; all30 recorder receipts confirm complete bounded capture writes. All34 original fixed screenshot/metric files were restored. Passing matrix runs do not erase the unresolved graphical failure, satisfy human playtesting, or prove historical unit41/original IssueB resolution.

See [gate repair report](milestone-5-gate-repair.md), [mechanism analysis](../validation-output/m5-gate-repair/gate-mechanism-review.md) and [execution record](../validation-output/m5-gate-repair/executed-commands.md). Starting production SHA256 is `9f329f34998832f19ce787b612bb25f9d4dfd98f7b633676050748faf5f68e7d`; final is `2f46d67b3267ab233405457f8c84e83ebc46b8f461e75deef46ee5c3f33b34d0`. Evidence is retained under `validation-output/m5-gate-repair/`; command/source-retention limitations and failed analysis attempts are explicit. No engine upgrade, historical budget, large archive, commit, acceptance waiver or next milestone was used.

**Reproduced numerical gate-corner stall: VERIFIED RESOLVED. Current gate reliability: UNRESOLVED. IssueA/projection/prior boundary repair: PRESERVED. Historical unit41: UNRESOLVED. Original IssueB: UNRESOLVED. Milestone5: STILL BLOCKED.**
