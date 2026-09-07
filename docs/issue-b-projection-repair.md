# Milestone 5.0.1 — navigation projection step-size repair

2026-09-07. **Projection step-size issue: VERIFIED RESOLVED for the demonstrated mechanism and frozen case on the final source. Milestone 5: STILL BLOCKED.** No acceptance requirement was changed. This is not a resolution of the captured unit 41 stall, unit 13 recovery behavior, or original Issue B's unit 4.

## Failing regression before production changes

The original production SHA-256 was `9b26194e6a0ef505573b0f51a8a7cdb1c409fae24c9526ccae0284cef29bbe2b`. The fixture remains `tests/fixtures/unit13_predeadlock.json`, SHA-256 `d56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307`. Its canonical source is the retained D full-sequence capture's settled event 1947 and exact cluster assignments at event 2149.

All 50 participants are normally created at the retained pre-cluster poses. Public parking orders establish normal parked state and settle for 180 ticks; public cluster orders retain every exact goal and natural order 2. Geometry, movement parameters, population and neighbor chronology evolve normally. No actor starts at its failed stop, receives private state, teleports after creation, or is frozen. This inherited **derived cluster-only fixture** omits earlier 30-unit/gate trajectories and hidden navigation/RVO history; it is not an exact full-sequence replay.

Three new test-only scripts, `projection_step_checks.gd`, `projection_step_field.gd` and `projection_step_probe.gd`, inherit the original runner and recorder. Every original predicate remains. The probe delegates each actual movement exactly once, counts every applied call, and retains critical observations for every actual excess and every diagnostically projected callback-budget excess. Each retained event links to its actual returned avoidance callback, input, delta, start/end, advancing movement stamp and contacts. New assertions require explicit unit 41 arrival, bounded actual calls and complete per-participant observation.

Before the baseline, the wiring/native-query harness passed **31/0**, independently checked setup/source/capture passed **28/0**, and the classifier was checked against retained E/F positive and bounded negative calls. Read-only native queries on an old recorded input did not position or move a live actor. The 182-file mechanism source was frozen before execution.

The first unmodified-production baseline failed **32 checks / 2 failures, exit 1**, with complete validated capture. It recorded **34 actual single-call step excesses** among 24,743 movement calls and 36 diagnostic callback-budget excess opportunities. Both original sampled-step and added actual-call bounds failed; all 50 arrivals and original settling/separation passed. Baseline repetition stopped immediately after this qualifying reproduction; no second baseline was used.

For example, unit 26, motion 20676, frame 414, had one returned avoidance movement call, delta 1/60, speed-bounded input `(4.26588869,0,2.60810089)`, stamp 413→414 and no contacts. It moved from `(21.14999962,0,7.73960638)` to `(21.22109795,0,7.84999990)`: **0.131307663**, above the unchanged **5/60+.001 = 0.0843333333** limit. Its proposed step was approximately 0.083333325.

An additional native closest-point query, made after the actual delegate, returned that same projected endpoint. An additional native path query returned a route bending at the clearance corner, with a first leg longer than the supplied step budget. The direct projected chord crosses excluded navigation; following only 0.083333325 of the first path leg remains navigable. Another baseline event, unit 41 event 809, has a first leg shorter than its budget, establishing why movement must stop at a bend even with budget left.

Actual movement records, **additional diagnostic engine queries**, and **offline geometric containment calculations** remain separately labeled. Diagnostic queries do not intercept production's internal native calls or drive actors. All 36 projected-excess observations have independently checked native paths and off-mesh direct chords; only 34 exceed the global bound because two have smaller avoidance budgets. See `m501g-baseline-review.md/json` and the complete step analysis.

## Small production change and its refinement

Only `_move_on_navigation` in `scripts/rts_unit.gd` changes: **11 added lines, no removals**. When closest-point projection changes the proposed endpoint and the projected displacement exceeds the callback's unchanged distance budget, production obtains a navigation path to the projected point. It moves at most the supplied budget along the first nonzero leg, stopping at the first bend. It stays at the current position if no usable start-matching path is available. It does not clamp across the nonconvex chord.

The existing frame guard and single `move_and_slide` remain. All other production bytes are identical, including Issue A's clearance guard, avoidance, separation, accepted-goal authority, speed/radii, recovery duration, attempt cap and command deadline. The 1e-5 path-start match and 1e-6 nonzero-leg checks handle native path coordinates; they do not change any test threshold. No attempt refund, timeout increase, parked-unit movement or recovery rewrite was introduced.

The initial candidate, SHA-256 `68766586da56ca1f4ba7c07be8c9e94ff0920eb61c9a93dd41308219b90f0f88`, used the strict budget comparison without first requiring a changed projection. It failed the unchanged movement regression **82/3, exit 1**: arrival/settling of an open-field group failed, followed by a dependent coherent-order assertion. That suite lacks per-step branch capture; the precise internal cause of those failures is not claimed as observed.

The first attempt to prepare diagnostic input failed to find the requested D archive records. The shell nevertheless launched the helper with missing input. It errored after public cluster dispatch and was explicitly terminated: **exit -1, 15 observed passes, no final assertion total, no complete capture/receipt**. This is an ordinary harness failure. Because cluster physics could have continued after the error, it conservatively consumed **post-change slot 1**. Its exact engine invocation, source, partial log and wiring remain; unknown elapsed cluster movement is not reported as zero.

A corrected query-only harness validates its inputs before creation and proves teardown with **zero cluster physics ticks**. It passed **34/0, exit 0**. Its 256 exact retained baseline movement inputs produced 118 native-query cases where the strict distance comparison fired although `projected == proposed` exactly. Those are real no-correction queries, not reconstructed live movements. The final guard adds `navigable != proposed`, excluding these cases without a new epsilon. All 36 baseline projection opportunities still satisfy the final guard. This evidence supports the refinement; it does not retroactively provide the missing internal M-regression trace.

The plan records this mishap and amendment before the final run. The initial intention to keep one candidate across two planned post runs could not be maintained after the failed helper unexpectedly spent slot 1. The user's maximum remains respected: **one baseline; two post-change slots including the failed helper; no automatic batch or execution after slot 2**. Corrected query-only wiring and unchanged separate regressions do not supply extra mechanism runs.

Final production SHA-256: **`1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4`**. Both candidate patches and source revisions are retained.

## Actual final behavior and complete execution ledger

Final post slot 2 used exactly the same frozen fixture, instrumented runner, engine and public commands; the 182-file comparison differs only in the production method. It passed **32/0, exit 0**, with complete independently validated capture. All **23,652 actual movement calls** were observed, with **zero excesses**. Maximum actual and sampled displacement was **0.083335273**, below the unchanged 0.0843333333 threshold.

All **37/37** observed projected-excess corner opportunities have actual bounded movement on the diagnostic native path's first leg. Every event independently satisfies the actual callback, bounded input, one returned delegate, advancing stamp, delta and no-contact predicates. For unit 9, motion 32459, frame 650, additional projection would yield 0.129936218; actual movement was 0.083333969. Unit 44 event 807 instead actually stopped at its first bend after 0.069611029, leaving part of its 0.081349548 budget unused. Offline geometry checks each corrected segment inside captured navigation. This demonstrates mechanism correspondence, not merely a passing rerun or identical actor/frame replay.

All 50 units reached their authoritative accepted goals within the original arrival tolerance. Unit 41 reached its unchanged `(28.5,0,17.5)` assignment on order 2 after 6.55 seconds, with zero recoveries. Original navigation/obstacle constraints passed. Exactly **180 additional settling ticks** had zero stationary displacement and minimum separation **1.261444330 > .6**. These successful unit 41 arrivals do not reproduce or resolve its earlier stalled mechanism.

Every engine execution is listed below. `Complete` denotes validated frozen-fixture capture; other regression suites retain their normal logs and available diagnostics without claiming full movement captures.

| Case (all `m501g-` prefixes) | Production | Checks / failures | Exit | Capture |
|---|---|---:|---:|---|
| current-harness-1 | Original | 31 / 0 | 0 | Complete; zero cluster ticks |
| baseline-mechanism-headless-1 | Original | 32 / 2 | 1 | Complete |
| M-repair-headless-1 | Initial | 82 / 3 | 1 | Normal suite log |
| roundoff-query-harness-1 | Initial | No final total; 15 observed passes | -1 | Incomplete; post slot 1 |
| roundoff-query-harness-2 | Initial | 34 / 0 | 0 | Complete; zero cluster ticks |
| M-repair-headless-2 | Final | 82 / 0 | 0 | Normal suite log |
| post-mechanism-headless-2 | Final | 32 / 0 | 0 | Complete; final post slot 2 |
| A-focused-headless-1 | Final | 14 / 0 | 0 | Normal suite diagnostic |
| A-controls-headless-1 | Final | 84 / 0 | 0 | Normal suite log |
| A-captured-headless-1 | Final | 10 / 0 | 0 | Normal suite diagnostic |
| A-focused-graphical-1 | Final | 14 / 0 | 0 | Normal suite diagnostic |
| A-controls-graphical-1 | Final | 84 / 0 | 0 | Normal suite log |
| A-captured-graphical-1 | Final | 10 / 0 | 0 | Normal suite diagnostic |
| M-repair-graphical-1 | Final | 82 / 0 | 0 | Normal suite log |

There were **14 serial engine executions**, **591 completed-suite assertions with 5 retained failures**, plus the incomplete helper's 15 observed passes and two native/script errors. All six unchanged Issue A regressions passed **216/0**. Final movement regressions passed **164/0** across headless and graphical modes. Failed earlier executions remain failed; no result is waived or relabeled as passing.

Each invocation JSON preserves its exact engine command, Godot SHA-256, wrapper hash, UTC start/end, source manifest/copy and exit. Godot 4.7.2 runs at fixed 60, with original 75-second route, 90-second command, 180-second internal watchdog and 240-second wrapper. Final independent review passed 17 checks and native-query review 8. Shared capture validation passed 28 checks for each successful wiring harness and 31 for each baseline/final mechanism capture. The mechanism analyzer stayed frozen at SHA-256 `374c4b2259403d403adfe2e26946b9e8b28736617fc2220b044c863e881fe62e` across the source comparison.

## Preservation, limitations and delivery

The 179-file starting snapshot and all **4,623 prior evidence files** are hash-audited. All pre-existing source/tests/fixtures remain unchanged except the stated production addition and an append to the investigation. Existing Issue A and F results are retained verbatim. The three new observer scripts are test-only. No stage, commit, acceptance waiver, full-stress rerun, playtest, new feature or milestone occurred.

Failed offline work is also retained: the first input extractor; an initial review that mistakenly required all 36 callback-budget excesses to exceed the global limit; and the first query review that rejected a roughly 6e-18 JSON reference round-trip difference despite identical native float32 input bits. Corrected reviews preserve these artifacts and explain their errors. The first inline review lacks a standalone full-script hash; its available traceback, failed assertion and tool-execution reference are preserved explicitly. No missing receipt or exact source record is fabricated.

Only one complete final-candidate mechanism run remains after the interrupted helper consumed slot 1. Extra observer queries can perturb subsequent trajectories, and the derived fixture omits original hidden history. The repair targets displacement-enlarging projection and does not claim a general navigation rewrite, new frame-rate coverage or resolution of under-budget boundary behavior. No new unit 41 reproduction budget was opened. The unresolved captured unit 41 stall and original Issue B still block overall acceptance.

The compact archive is `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-projection-step-evidence.zip`. Its verified actual SHA-256 is in the companion `.sha256` and `m501g-package-result.json`. It includes raw captures/receipts, exact commands and per-execution source mapping, both patches, failures, independent analyses, prior reference captures, this report and an entry-hash manifest. Engine binaries, caches and duplicate source content are excluded.

- Projection step-size issue: **VERIFIED RESOLVED**
- Issue A: **PRESERVED**
- Unit 41 boundary stall: **UNRESOLVED**
- Original Issue B: **UNRESOLVED**
- Milestone 5: **STILL BLOCKED**
