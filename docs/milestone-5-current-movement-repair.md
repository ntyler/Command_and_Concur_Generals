# Milestone 5 — current-build boundary/neighbor repair

2026-09-07. **The new controlled gameplay regression is repaired. Integration acceptance still fails at the gate.** Historical unit 41 and original Issue B remain unresolved.

This task used the newly authorized 90-minute limit, beginning19:49:55 UTC. It finished its engine validation by20:21 UTC. No applicable AGENTS.md was found. Production started with both existing repairs intact; no closed historical execution slot was used. One justified arrangement established the failure, so no fixture search followed. The [execution plan](../validation-output/m5-current-reliability/plan.md) fixed the repetitions before execution.

## Controlled behavior and usable route

The new five-unit fixture uses the original stress obstacles/navigation, normal creation and registration, and public commands. Mover1 starts at `(24,0,19.3)` and accepts `(28.5,0,17.5)`. Four neighbors publicly park at x26.8 and z19.05/20.15/21.25/22.35, then settle for180 ticks before the mover starts. Their1.1m spacing exceeds the0.86m body diameter, but cannot provide a passage requiring two0.58m moving/parked avoidance clearances. The fence joins the obstacle navigation boundary at z18.85; its far end remains open.

A separate public-command witness goes through `(24,0,23.6)` and `(29,0,23.6)` to the same final goal, with the same neighbors and settings. It arrives in **3.0167 total movement seconds across all three commands**. All178 actual movement calls are retained; offline measurement along those actual segments gives **1.1536m minimum mover/neighbor clearance**, above the0.86m body diameter. This proves route usability, not automatic recovery; resetting intermediate-order timers is not counted as the repair. The post-change witness also passes, including a new full-body-clearance assertion.

Simplifications are explicit: five fresh agents, deliberate stationary fence, no preceding full-group trajectories and no historical native state. This is neither a replay of historical unit41 nor original IssueB.

## Demonstrated defect and correction

Before production changes, the automatic single-order case fails **23 checks /3 failures, exit1**. It exhausts eight attempts and enters FAILED after27 seconds. Speed and navigation constraints pass; accepted goal/order and parked positions remain intact.

At frame367 the actual requested velocity is approximately `(4.904054,0,.974810)`; the actual avoidance callback is `(.00002129,0,-1.000171)`. One returned movement call has zero displacement, an advancing366→367 movement stamp and no contacts. At frame368 the selector starts from `(26.2619896,0,18.8499985)`. It selects an outward leg, then at frame392 selects a return toward the fence. Subsequent attempts repeat ineffective two-leg loops. The selector's locally clear legs are scored by geometric distance to the final goal, which does not represent the route around parked neighbors.

The correction in [rts_unit.gd](../scripts/rts_unit.gd) considers complete local escape routes before the existing ring fallback:

- At most eight candidate endpoints: parked-group bounds plus wider approaches perpendicular to the longer fence axis. Endpoints stay inside the existing5.2m local-neighbor horizon.
- At most two selected waypoints and56 ordered candidate pairs. Escape path length must fit movement speed times the remaining original two-second recovery duration; the full proposed route must also fit the remaining command deadline.
- Actual navigation paths, endpoint occupancy, physical center-ray checks and the unchanged Issue A clearance guard must approve the escape legs and the remaining final-goal path.
- A saved second leg is revalidated against current neighbors, navigation and accepted destination. Move, Stop, finish and recovery clearing discard it. Geometric goal progress cannot prematurely discard a still-needed escape.

The original2.2m candidate ring remains the fallback. Complete local routes can now extend beyond that ring, within the existing local horizon and time/speed bounds. No movement parameter, radius, tolerance, attempt limit, deadline, accepted destination or command-result semantic changed. The projection movement method, original selector and Issue A guard are byte-for-byte unchanged as functions.

The first implementation still failed: the actual Issue A guard rejected its tight first corner because the approach moved deeper into existing peer contact. That run is retained as an ordinary failure. Wider approach candidates fix this without relaxing the guard.

Final headless and graphical runs both pass **23/23**, reach the original goal in **5.8167 seconds**, and use **one attempt /two legs**. The actual plan is `(23.72,0,23.23)` then `(27.68,0,23.23)`. Its native escape paths total9.0242m, within the existing10m theoretical budget; actual recovery lasts1.7 seconds. Maximum actual step is approximately.08333413m, below5/60+.001. All five units settle for180 ticks; final minimum separation is1.10000038m.

The [independent mechanism review](../validation-output/m5-current-reliability/mechanism-review.json) establishes identical observed first-decision state and all four neighbor inputs before/after. Final event64/frame368 selects the plan, event73/frame426 advances it, event77/frame469 clears recovery, and event84/frame537 confirms arrival. This is demonstrated mechanism correspondence, not an inference from a passing rerun.

## Validation

The final eight-case control suite passes **193/193 in each mode**: clear route; occupied-goal bounded failure followed by replacement; first- and second-leg replacement Move; first- and second-leg viewport X Stop; a publicly departing neighbor; and a fence shifted+0.2m in x. The inaccessible case is a negative control and is never counted as successful arrival at its occupied goal. Stop is checked for180 stationary ticks, then a separate command proves replacement arrival. These are automated viewport tests, not a human keyboard-and-mouse playtest.

The complete selected existing gameplay matrix ran once in each mode after the final production correction:

| Existing suite | Headless checks/failures | Graphical checks/failures |
|---|---:|---:|
| Original full movement stress sequence | **122/12** | **131/12** |
| Issue A focused /controls /captured50 | 14/0;84/0;10/0 | 14/0;84/0;10/0 |
| Projection frozen fixture | 32/0 | 32/0 |
| Movement repair /replacement | 82/0 | 82/0 |
| Original milestone controls | 127/0 | 131/0 |
| Construction /cleanup | 267/0;46/0 | 270/0;46/0 |
| Harvesting | 298/0 | 299/0 |
| Production | 192/0 | 193/0 |
| Combat /combat repair | 183/0;230/0 | 191/0;230/0 |
| Line of fire | 305/0 | 308/0 |
| Spherical projectile | 140/0 | 141/0 |
| Combat load | 7/0 | 7/0 |

**30 of32 matrix executions pass:4,308 assertions,24 failures.** Both stress executions fail arrival/gate/settling predicates, with actors stuck near x−2.85,z±1.03. The avoidance-disabled control also fails. One attribution run against this task's saved starting source independently fails **122/12** at the gate. Thus the gate failure predates this local correction. Different actor identities/trajectories do not establish that every downstream outcome is unchanged. The logs do not identify the exact navigation calculation responsible; that remains the next technical observation needed.

Across the entire task: **45 engine invocations,5,114 assertions,42 failures in five ordinary failed runs** (baseline, first implementation, two final stress runs, starting-source stress attribution). Two parser checks have no assertions. No failed run was reclassified as passing. All40 exit-zero engine logs are free of native errors/warnings; all31 existing-recorder coverage receipts confirm complete writes. `git diff --check` passes. Exact commands, source/test hashes, logs and individual results are in [executed-commands.md](../validation-output/m5-current-reliability/executed-commands.md) and [integration-results.csv](../validation-output/m5-current-reliability/integration-results.csv).

## Limits and retained files

New tests are [boundary_neighbor_checks.gd](../tests/boundary_neighbor_checks.gd), [boundary_neighbor_controls.gd](../tests/boundary_neighbor_controls.gd) and [boundary_neighbor_probe.gd](../tests/boundary_neighbor_probe.gd). They reuse the existing bounded recorder and external wrapper. All existing tests remain unchanged. The current-task production-only diff is [production-correction.diff](../validation-output/m5-current-reliability/production-correction.diff).

Evidence is retained at `D:/GitHub/Command_and_Concur_Generals/validation-output/m5-current-reliability/`. No archive or new receipt/recording framework was built. Original fixed screenshot/metric files were restored and all34 hashes verified. Starting production SHA-256 is `1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4`; final is `9f329f34998832f19ce787b612bb25f9d4dfd98f7b633676050748faf5f68e7d`.

Recorder completeness does not mean a full timeline: final automatic captures retain288/348 movement calls, including the complete recovery through arrival; early frames189–248 aged out. First six-case control aggregate waypoint aliasing was corrected; its individual captures/details remain valid. These limitations and the failed implementation are preserved in the execution record.

The remaining blocker is actual gate traversal failure, now demonstrated on both starting and corrected source. No unrelated projection rewrite, acceptance waiver, commit or next milestone was undertaken. This small batch establishes the specified fixture's repair, not universal movement reliability.

- **Current behavioral regression: PASSING.**
- **Supported production correction: IMPLEMENTED.**
- **Existing integration validation: FAIL.** Issue A and projection regressions pass unchanged.
- **Historical unit41 and original IssueB: UNRESOLVED.**
- **Milestone5 acceptance: STILL BLOCKED.**
