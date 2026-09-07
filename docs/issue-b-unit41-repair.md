# Unit 41 boundary stall: bounded repair attempt

**Unit 41 boundary stall: NOT REPRODUCED in the two authorized baselines. No production patch was made.** The earlier captured unit-41 failure remains valid and unresolved. Both new executions failed the preserved projection step-size assertion. Original Issue B remains unresolved and Milestone 5 remains blocked.

## Scope and fixed budget

The [pre-execution plan](../validation-output/m501f-run-plan.md) fixed at most two headless baselines, stopping after a qualifying failure, and at most two corresponding post-change mechanism runs only if a meaningful failing regression and supporting repair evidence existed. Both baseline slots were used; **zero post-change runs** were eligible or executed. No extra batch, fixture retuning, shorter-waypoint experiment, speculative patch, acceptance waiver, commit, or new milestone followed.

The target was the distinct failure in `m501e-current-mechanism-headless-1`, capture SHA-256 `7943c3b375c726152e5e98d8e5f72200e1cd00f5c1636207dffbf33d150cd825`. It retained unit 41's accepted goal `(28.5,0,17.5)`, peer 49 parked before the stall, an eastward boundary request, actual outward avoidance velocity, zero returned movement displacement, eight final-goal retries and expiry without progress, then FAILED. The [original unit-41 report](../validation-output/m501e-unit41-analysis.md) remains unchanged. Captured unit 13's different recovery failure and original Issue B unit 4 are not substituted for this target.

No applicable `AGENTS.md` was found at `D:/`, `D:/GitHub`, the repository root, or its relevant descendants. The required investigation, unit-13 comparison, unit-41 and step analyses, frozen fixtures, reference captures/receipts/manifests, and production/test source were reviewed. The [independent source review](../validation-output/m501f-source-review.md) verifies provenance and unchanged protected methods.

## Diagnostic patch and harness validation

Three new test-only scripts form the change:

- `tests/unit41_boundary_checks.gd` inherits every existing fixture assertion, including the step bound. It adds explicit actual unit-41 arrival at the exact accepted goal on natural order 2. Its setup body differs from the parent only in the field subclass installed before tree entry.
- `tests/unit41_boundary_field.gd` retains the existing normal factory and specializes only unit 41's observer before initialization.
- `tests/unit41_boundary_probe.gd` delegates each selector and Issue A clearance call exactly once, returning the unmodified result. It records the actual selected return and actual guard Boolean on the production-supplied path/neighbors. It introduces no copied selector or additional navigation/physics query.

The unchanged frozen fixture SHA-256 is `d56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307`. All 50 identities, positions, parking goals, exact cluster goals, geometry and public command order remain intact. Unit 41 is created at `(12.84462738,0,1.60043442)`, before its route, never at its failed stop. Public parking commands and 180 settled ticks establish ordinary parked state, followed by public exact-goal cluster commands. No private state injection, live teleport, mover freezing, parked-unit relocation or avoidance change occurs.

The fixture retains its documented simplifications: preceding 30-unit/gate trajectories are omitted; navigation/RVO instances are fresh; per-unit dispatch creates natural orders 1/2 and field generation 0. Neighbor parking chronology emerges naturally and is captured. Equal intended inputs do not restore hidden engine history or guarantee equal trajectories. Observer allocations can perturb timing.

Before baseline 1, the wiring harness passed **26 checks, zero failures, exit 0**, with teardown before any cluster movement tick. Its entire setup/command artifact equals the preserved E wiring. All **24 independent capture checks** passed. The offline mechanism classifier was checked against the prior captured unit-41 failure (positive) and its prior graphical arrival (negative): **2 checks, zero failures**. These read-only analyses started no engine. See the [validation receipt](../validation-output/m501f-harness-validation.json).

Actual candidate paths rejected before the Issue A guard still cannot be observed through these seams. Native projection returns also remain uninstrumented; geometry-based cancellation predictions are labeled offline. In the two new baselines, unit 41 never entered recovery, so **zero selection events and zero clearance-result events** occurred. No new candidate rejection, short-leg selection or avoidance-compatible traversal evidence exists. The proposed shorter leg remains a hypothesis.

## Complete execution outcomes

All engine calls used Godot 4.7.2, executable SHA-256 `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`. Mechanism calls used headless fixed FPS 60 with the original 75-second route, 90-second command, 180-second internal wall watchdog and 240-second external wrapper. The full source manifest was frozen before baseline 1 and is identical in both baselines. Movement source remains `9b26194e6a0ef505573b0f51a8a7cdb1c409fae24c9526ccae0284cef29bbe2b` throughout.

| Case | Checks / failures | Exit | Capture |
| --- | --- | --- | --- |
| Current import 1 | No assertions | 0 | Not applicable |
| Current wiring harness 1 | 26 / 0 | 0 | Complete |
| Baseline headless 1 | **30 / 1** | **1** | Complete |
| Baseline headless 2 | **30 / 1** | **1** | Complete |
| Issue A focused headless | 14 / 0 | 0 | Existing regression artifacts |
| Issue A controls headless | 84 / 0 | 0 | Existing regression log |
| Issue A captured headless | 10 / 0 | 0 | Existing regression artifacts |
| Issue A focused graphical | 14 / 0 | 0 | Existing regression artifacts |
| Issue A controls graphical | 84 / 0 | 0 | Existing regression log |
| Issue A captured graphical | 10 / 0 | 0 | Existing regression artifacts |

Total: **10 serial engine calls; 302 assertions, two failures**. The six unchanged Issue A suites account for **216 checks, zero failures**. The import emitted one nested retained-project discovery warning, preserved in its log/wrapper; it returned 0 without parser failure. Every successful gameplay/harness log is free of additional native errors, warnings or leaks. Both ordinary failed baselines remain failed runs.

Each distinct `m501f-<case>-invocation.json` retains the exact engine arguments/command, wrapper and engine hashes, source manifest and copy, UTC start/end and exit. Matching logs, wrapper transcripts, captures and receipts are retained. The [audit ledger](../validation-output/m501f-audit.json) records these individually. Before baseline 2, the ignored launcher stop check was corrected to use the classifier's actual field names; its earlier driver is retained as `m501f-run-before-field-correction.ps1`. This changed no simulation source or inputs and caused no extra execution.

| Baseline | Unit 41 actual arrival command seconds / attempts | Whole-route seconds | All 50 arrived | Minimum settled separation | Max sampled step |
| --- | --- | --- | --- | --- | --- |
| 1 | 6.533333 / 0 | 17.166667 | Yes | 1.271137238 | **0.132907867** |
| 2 | 8.516667 / 0 | 18.550000 | Yes | 1.163901687 | **0.130544767** |

All 50 actual pre-cleanup ARRIVED endpoints were within the unchanged 0.23 tolerance of their accepted goals, with retained order 2. Original navigation/obstacle assertions passed. Each route added exactly **180 settling ticks**, with zero maximum stationary displacement and separation above 0.6. These observations do not make either run pass while step size fails, and provide no before/after repair comparison. The [independent baseline review](../validation-output/m501f-baseline-review.md) preserves actual event/movement excerpts.

The separate unchanged bound is `5/60 + .001 = .08433333333333333`. Baseline 1 retains 14 actual single-call excesses; unit 33, motion 25983, frame 520 moves **.132907860055** in one returned 1/60-second call with no contacts. Baseline 2 retains 10; unit 9, motion 30309, frame 607 moves **.128904017798** in one such call. The larger runner-wide maximum for baseline 2 is not assigned to that excerpt. Projection code and its prior findings remain unchanged. This issue independently blocks acceptance.

All three new recorder captures have independent validation, all 50 watches before commands, no dropped records, no incomplete delegates or serialization failures, and zero remaining units/listeners. Bounded capture completeness does not mean every callback since launch is archived. The separate receipt certifies artifact write completion.

## Preservation and delivery

The complete **172-file** starting source snapshot and **2,670 prior evidence files** have verified SHA-256 manifests. Every original source/test/fixture remains unchanged except this investigation's append; prior investigation bytes remain an exact prefix. Existing Issue A clearance, final-goal authority, movement parameters, recovery duration, attempt cap, command deadline, avoidance/separation rules and projection assertion remain intact. No production diff exists.

The compact local package is `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-unit41-boundary-evidence.zip`. Its companion `.sha256` and `m501f-package-result.json` contain its actual final SHA-256. It includes new raw captures, receipts, every execution ledger/log, source identity and deduplicated source mapping, original target/fixture/step references, analyses and diagnostic patch. Engine binaries, caches and unrelated prior artifacts are omitted; all original evidence remains preserved locally. Nothing was uploaded. Work stops here.

**Unit 41 boundary stall: NOT REPRODUCED.**

**Issue A: PRESERVED.**

**Projection step-size issue: UNRESOLVED.**

**Original Issue B: UNRESOLVED.**

**Milestone 5: STILL BLOCKED.**
