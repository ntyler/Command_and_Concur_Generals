# Milestone 5 — current gate repair

The reproduced numerical gate-corner stall is repaired. The original full movement sequence now passes in both headless and graphical modes, and all36 selected integration executions pass. **Overall movement reliability and Milestone5 acceptance remain blocked:** one earlier graphical avoidance run on this same repair failed for unit23. Its movement mechanism was not captured, and subsequent passing runs do not resolve it.

This is the separately authorized gate task, following the current boundary/neighbor repair. It does not reopen historical budgets or claim historical unit41/original IssueB resolution. The task began at2026-09-07 20:52:11 UTC with a90-minute limit and20-minute validation reserve. The [predetermined plan](../validation-output/m5-gate-repair/plan.md) retains the initial execution limits and the later single observation of the newly encountered23 failure. No production changes preceded the qualifying baseline.

## Reproduction and actual mechanism

The new [gate regression](../tests/gate_movement_checks.gd) derives from the original stress test's fresh50-unit gate case. All50 units use normal creation/registration, original spawns, geometry, parameters, assignment algorithm and public group goal `(10,0,0)`. Disabled avoidance is the original negative-control mode, not a repair. The derived case omits preceding30-unit routes; enabled mode retains the original50-unit assignment checks. Initially only20 receives the existing test recorder. No live teleportation, private-state injection, frozen movers, manufactured corner contact or initialization at a failed stop is used.

Parser/wiring checks preceded the baseline. The unchanged-production disabled baseline fails **14 checks /3 failures**, exit1: all-participant arrival, entire-group gate traversal and180-tick settling/separation. Unit20 receives accepted destination `(4,0,1.5)` on its natural first order. It makes1,844 actual movement calls, including1,571 blocked calls. Eight additional diagnostic sets are retained; capture coverage is complete within the existing bounded-history contract.

The [independent retained-evidence analysis](../validation-output/m5-gate-repair/gate-mechanism-review.md) establishes the following exact correspondence:

| Actual movement observation | Baseline | Repaired disabled headless |
|---|---|---|
| Event /physics frame | 19 /280 | 19 /280 |
| Start | `(-2.84999990463257,0,1.03365671634674)` | identical |
| Supplied velocity | `(4.99946117401123,0,-0.0733752474188805)` | identical |
| Delta /movement stamp | `1/60`;279→280 | identical |
| Returned movement delegates /slide contacts | 1 /none | 1 /none |
| Actual displacement | **0** | **0.0833333134651m** |
| Actual end | unchanged | `(-2.84999990463257,0,0.950323402881622)` |

The cached agent path had advanced past the entry corner to the opposite gate edge while the actor remained about0.08366m from that corner. Projection switches the proposed step to the horizontal gate boundary and exceeds the supplied step budget. The existing projection repair therefore requests a native path and follows its first leg only if the returned start is within0.00001m of the actor.

**Additional native diagnostic queries after the failed call**, rather than intercepted production query returns, show the actor itself projects exactly to its current position, but the path starts about0.00003517m away. The existing start guard therefore rejects the first boundary leg. This causal attribution combines actual movement evidence, separately labeled diagnostic returns and source reasoning. Optimized and unoptimized query paths have the same shifted start; disabling optimization also adds a long portal detour and was rejected as a remedy. The query-only run never moves or commands the live actor.

## Production correction

Only `_move_on_navigation` changes, plus one helper in [rts_unit.gd](../scripts/rts_unit.gd). The [task-only diff](../validation-output/m5-gate-repair/production-correction.diff) preserves the original successful branch. When that branch rejects a path start, the fallback permits the bounded first-leg candidate only if its actual start and end lie within **one existing rectangular navigation cell**. It checks the active region/map/layers, suspension, exact flat height, four correctly ordered corners and nondegenerate dimensions. Inclusive exact bounds retain legal edges without increasing any tolerance. Because the cell is convex, the whole connecting segment is inside it. Unsupported geometry and chords across holes are rejected conservatively.

The original first corner and supplied step budget remain authoritative; the fallback does not clamp toward the projected endpoint across a bend. `move_and_slide` still handles physical contacts. Recorded-input geometry checks accept the legal boundary leg and reject the diagonal corner shortcut, a chord across the obstacle hole, and an off-plane start. Actual production-helper inputs/returns are captured in the repaired movement calls. Frame281 then moves only0.000323474m to the corner, after which traversal continues normally.

The [preservation audit](../validation-output/m5-gate-repair/preservation-check.json) verifies all32 other existing function bodies and all constants/parameters/state declarations are unchanged. IssueA's clearance guard, prior local escape repair, accepted-goal authority, avoidance parameters, recovery duration, attempt cap and command deadline remain intact. Every existing matrix test matches its previous source hash; all34 original fixed screenshot/metric artifacts were restored byte-for-byte.

## Validation and the remaining failure

The four predetermined focused runs are all retained:

| Current gate mode | Checks /failures | Result |
|---|---:|---|
| Disabled, headless | 14 /0 | All50 arrive in10.1833s; zero recoveries |
| Disabled, graphical | 14 /0 | Same actual unit20 mechanism and group result |
| Enabled, headless | 39 /0 | All50 arrive in14.8833s |
| Enabled, graphical | **39 /3** | Unit23 fails after8 attempts; ordinary failure |

Both disabled runs settle for180 ticks with zero displacement and minimum separation1.41295m. The enabled headless case settles with minimum separation1.32442m. Unit20 has no blocked calls in any of these four repaired runs; its observed maximum step remains below the unchanged `5/60 + .001` threshold.

The failing enabled graphical run reports unit23 approximately at `(-2.85,0,-1.918918)`, accepted goal `(8.5,0,0)`, after31.5167 simulated seconds. It fails all-participant arrival, gate traversal and settling predicates. Only20 was observed, so23's actual failed input, projection/path returns and helper decisions are unavailable. One specifically directed follow-up installed the existing observer on20+23 before normal creation/commands; wiring passed6/6. That run passes39/39:23 arrives atframe506 without recovery and produces no blocked-call or cell-fallback events. Its earliest retained movement calls start at387; earlier approach calls aged out. Sparse earlier state/callback records describe a passing interior approach. They establish no causal basis for another execution or speculative repair. The failed run remains unresolved.

After the correction, the unchanged original full movement sequence passes **122/122 headless and131/131 graphical**, including every30-unit route, enabled50 gate/cluster, disabled50 gate control, unchanged navigation/obstacle checks and180-tick settling/separation. The full36-run matrix passes **4,740 assertions with zero failures**: IssueA focused/controls/captured50, projection fixture, prior boundary/neighbor repair and controls, movement/replacement, milestone input, construction/cleanup, harvesting, production, combat/repair/load, line of fire and spherical projectiles. Automated graphical/viewport execution is not human keyboard-and-mouse playtesting.

Across the task, all48 engine invocations retain **4,929 assertions and6 failures in two ordinary failed runs**: the qualifying baseline and the later graphical23 failure. Two parser runs contain no assertions. Individual logs, exits, source hashes, coverage checks and command provenance are in the [execution record](../validation-output/m5-gate-repair/executed-commands.md) and [matrix CSV](../validation-output/m5-gate-repair/integration-results.csv). All12 exact manual PowerShell invocations and their ordered Godot arguments were recovered from narrowly selected records of this active task; the matrix driver directly retains its36 argument arrays and UTC times. Tool-dispatch timestamps are distinguished from unavailable exact native process start/end times for manual runs. Parser-only invocation test hashes were not independently captured. All46 exit-zero native logs contain no error/warning headers, and all30 recorder receipts confirm complete bounded writes. Failed analysis attempts, prior reconstructed command records and the exact-hash recovery of the query1 harness source are preserved.

Evidence directory: `D:/GitHub/Command_and_Concur_Generals/validation-output/m5-gate-repair/`. Starting production SHA256: `9f329f34998832f19ce787b612bb25f9d4dfd98f7b633676050748faf5f68e7d`; final: `2f46d67b3267ab233405457f8c84e83ebc46b8f461e75deef46ee5c3f33b34d0`. No engine upgrade, new recording framework, large archive, commit, acceptance waiver or next milestone was undertaken.

- **Reproduced numerical gate-corner stall: VERIFIED RESOLVED.**
- **Current gate reliability: UNRESOLVED**, because the graphical23 failure remains unclassified.
- **IssueA, projection step-size repair and prior boundary/neighbor repair: PRESERVED**, with unchanged regressions passing.
- **Historical unit41 and original IssueB: UNRESOLVED.**
- **Milestone5: STILL BLOCKED.** The next necessary evidence is an actual failed movement/recovery decision for the remaining current-build failure, obtained through failure-triggered observation during normal gameplay; this report authorizes no further execution batch.
