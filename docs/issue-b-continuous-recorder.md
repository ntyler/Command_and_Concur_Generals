# Milestone 5.0.1: continuous recorder implementation and bounded validation

The test-only continuous recorder is implemented and validated for serialization and normal 50-unit parked wiring. It closes the previous recorder's aged-history retention gap by retaining every participant in every observed frame. **No moving route, new stall reproduction, or production repair was executed.** Unit 41 and original Issue B remain unresolved; Milestone 5 remains blocked.

The immediate authorization after the [reproduction design](issue-b-unit41-reproduction-design.md) covered instrumentation implementation and validation. The predetermined allowance in `validation-output/m501i-run-plan.md` was at most two parser checks, one synthetic contract execution plus one correction if invalid, and one parked wiring execution plus one correction if invalid. Actual use was **one parser, one contract, one parked execution; zero engine retries and zero reproduction slots**. No commit, acceptance waiver, new feature, or milestone followed.

## What changed and why

E's unit-41 archive omits active frames 189–653, including the approach that formed the historical stop. Its later zero-displacement calls establish the failure but cannot reveal that missing transition. Repeating the same fixture without retaining that interval would leave the causal question unanswered.

The new files are separate from all existing fixtures and regression tests:

- `tests/continuous_capture_recorder.gd` writes an append-only JSONL stream, including all 50 initial states before commands, every subsequent frame, cached path/index changes, command and state events, and complete callback/direct-movement receipts.
- `tests/continuous_capture_probe.gd` completes records only after the actual inherited delegate returns. Existing test-only selector and Issue A clearance seams apply to every participant. They record actual supplied inputs and returned results; inline rejection reasons remain explicitly unavailable.
- `tests/continuous_capture_field.gd` uses the normal factory and installs probes before the units enter the tree. The unchanged fixture supplies original creation positions. There is no live teleportation, frozen mover, forced parking chronology, or actor initialized at its failed stop.
- `tests/continuous_capture_checks.gd` exposes only synthetic-contract and parked-wiring validation. It does not inherit the old fixture runner's dispatch sequence and contains no cluster-goal dispatch path.
- `tools/run_continuous_validation.py` and `tools/continuous_validation_bridge.ps1` validate the exact fixture, production and engine identities, prepared data and output location before launching the fixed validation script. Preparation errors cannot fall through into a simulation. Existing `tools/run-godot.ps1` supplies its unchanged process-tree deadline handling.
- `tools/validate_continuous_capture.py` independently checks the raw byte digest, record and frame continuity, all-participant coverage, instance and command authority, completed delegates, motion receipts, movement stamps, contacts and step bounds. Its new offline tests and launcher tests preserve negative cases.

Callback admission, delegate completion, physics observations and inline events carry a common observation sequence. This orders observer points across the buffered frame records; serialized line order alone does not express nested delegate order. Rows describe each participant's latest completed observation, **not a simultaneous internal RVO snapshot**. Cached path reads do not advance navigation or add native path/projection queries. Raw requested/callback inputs, actual start/end positions, delta, movement stamps and contacts remain distinct from derived arithmetic.

The stream has hard limits of 10,000 frames and 1 GiB, and never evicts aged frames. A missing participant, frame gap, unfinished delegate, exhausted capacity or write error makes it incomplete and stops validation. A digest-checked footer records all 50 admission/completion totals and teardown state. A killed process or missing footer cannot be accepted as complete. Successful file writes and result flushes are checked; a capture failure cannot later become a success exit.

## Actual validation and preserved failure

| Execution | Result | Evidentiary scope |
|---|---|---|
| `m501i-parser-1` | Exit 0; no errors | Fixed validation script parses; no field |
| `m501i-contract-1` | 13 checks, 0 failures, exit 0 | Three synthetic frames, 150 rows, no live actors |
| First independent contract analysis | Exit 2, 601 schema errors | Retained failure: integral JSON values were written as `1.0` |
| Same contract, corrected independent analysis | Exit 0; complete | Identical capture bytes; two retained E callbacks and their two returned calls |
| Capacity and byte-limit controls | Independent exit 2, as required | Actual serializer failures remain incomplete; no eviction or false pass |
| `m501i-parked-1` | 6 checks, 0 failures, exit 0 | Normally created 50-unit frozen fixture and original public parking commands |
| Independent parked analysis | Exit 0; complete | Frames 1–189 inclusive, 9,450 participant rows and 9,450 completed callbacks |
| Final offline validator tests | 50 tests, 0 failures, exit 0 | Malformed, truncated, gapped, duplicate and contradictory evidence; gameplay failures; numeric boundary cases |
| Launcher tests | 6 tests, 0 failures, exit 0 | Missing/changed inputs, invalid mode, missing engine, preparation failure and reused prefix never launch the engine callable |
| Independent parser/contract receipt audit | 22 checks, 0 failures, exit 0 | Source copies, inputs, outputs and raw stream prefix digest |

The contract's unit-41 callbacks are copied **as test data** from E frames 654 and 655, alongside synthetic peer/frame rows. They validate serialization of retained actual returns, not a new native replay. Their original source identity and capture SHA are retained in the prepared inputs and source mappings. The new engine creates no contract actor. The contract also exercises actual frame-limit exhaustion, header byte-limit failure, unavailable output and safe finalization after failed open.

The first independent analysis rejected Godot's integer-valued floating JSON representation. The correction accepts finite, exact integral values within the safe float integer range, while still rejecting booleans, fractions, nonfinite values and ambiguous large floating identities. It changes no movement or acceptance predicate. The original rejected analysis, validator revision, output and exit remain retained. The same capture SHA `de4c60c099b561ad381af0a6461cb63456ee1db80124837177fec50e1a68c9aa` was revalidated; **no engine rerun manufactured a pass**.

The parked execution retains 189 callbacks received and completed for each participant, 50 publicly accepted original parking commands, zero direct movements, **zero movement calls or advancing movement stamps**, and zero sampled displacement. Its initial frame and 188 subsequent physics-phase frames are contiguous. The unchanged 180-tick stationary sampler passes. The runner waits until the last tick's unit callbacks finish, frees the field synchronously, then records successful teardown and zero connected listeners. It never dispatches the second/cluster commands. Capture SHA: `3cfc8f73bef2926e2332046eb8f0f5385f626a61981a61e435bc90d58406fcb8`.

All three engine executions ended normally with empty stderr. Together they contain **19 completed engine assertions, zero engine assertion failures**. Four successive offline validator revisions were compiled and tested as the schema was developed; all their test executions passed, and all versions are retained. The rejected independent contract analysis is reported separately from both those tests and gameplay failures.

## Limits and next authorization

This work validates live idle callback completion and continuous all-participant wiring. It does **not** runtime-validate moving callbacks, direct movements, recovery entry, selector execution, full-route capacity or observer overhead under crowd motion. The preserved E callback data supplies a serializer contract, not evidence that the new live probe has exercised those paths. The reserved `route` schema is not a runnable mode of this launcher. A future integration must supply the unchanged gameplay-suite receipt expected by that schema; the current validation-only runner does not implement that route adapter.

No new causal fixture or public scheduling condition is established. The first future live observation would still need separate authorization and a predetermined budget. Its purpose would be to retain the missing original-fixture approach continuously and inspect the first actual divergence, not to force E's stop or infer a repair from another arrival. It must preserve all original goal, arrival, navigation, obstacle, step-size, separation and 180-tick settling assertions. No such execution is authorized or started here.

## Preservation and delivery

The 184-file starting source snapshot and 7,422 prior evidence files are hash-audited. All pre-existing production, tests and fixture files are unchanged; the investigation changes only by appending this result. The final audit, full execution ledger, prepared inputs, exact argument arrays, source snapshots and hashes, stdout/stderr, exits, complete/negative streams, analytical failures and reviewer reports are under `validation-output/m501i-*`.

Production SHA-256 remains `1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4`. Fixture SHA-256 remains `d56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307`. The existing Issue A regressions were not rerun for this separate recorder addition; their source and prior validated results remain unchanged. The step-size repair receives no new moving-runtime verification in this task.

Compact evidence ZIP: `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-continuous-recorder-evidence.zip`. Its actual SHA-256 is in the companion `.sha256` and `m501i-package-result.json`. The archive includes new streams and all failed analyses, original E callback provenance, and deduplicated source copies with per-entry hashes. Original evidence remains in place.

- Continuous recorder: **VALIDATED for synthetic contract and parked wiring; moving-route integration unverified**
- Projection step-size repair and Issue A: **unchanged; no new moving-runtime or Issue A regression verification**
- Unit 41 boundary stall: **UNRESOLVED**
- Original Issue B: **UNRESOLVED**
- Milestone 5: **STILL BLOCKED**
