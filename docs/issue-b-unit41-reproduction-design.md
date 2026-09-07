# Milestone 5.0.1 — unit 41 reproduction design from retained evidence

2026-09-07. **Reproduction design: INSUFFICIENT EVIDENCE.** The retained failure is well demonstrated, but its formation is not continuously recorded. The evidence identifies useful failure prerequisites without identifying a public-command condition that reliably creates them on the repaired source. No fixture or new baseline proposal is supported yet.

This task performed retained-file analysis and documentation only. **Zero Godot executions, zero native navigation queries, zero production/test/fixture changes.** All execution budgets remain closed. The projection repair and Issue A are unchanged, with no new runtime verification. Unit 41's stall and original Issue B remain unresolved; Milestone 5 remains blocked.

## Sources and shared inputs

The required investigation, unit 41 repair-attempt report, projection repair report, E unit41 analysis, F baseline review and G post review were read with their relevant capture/receipt/source/test references. No applicable `AGENTS.md` was found in the repository, its descendants or named ancestors.

E failing headless and both F baselines use movement SHA-256 `9b26194e6a0ef505573b0f51a8a7cdb1c409fae24c9526ccae0284cef29bbe2b`. Final G and the unchanged current file use `1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4`. G adds only the verified 11-line projection traversal rule. Recovery, Issue A's clearance guard, public-goal authority, avoidance/radii, movement parameters, duration, attempt cap and deadline remain identical.

All four complete intended wiring artifacts are byte-identical: SHA-256 `fcf629e7ae2d04a6e49f8e99cb724fb3dd97721dcf240017a40512d6547827c8`. The frozen 50-unit fixture remains `d56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307`. Normal creation, public parking, 180 parking-settling ticks, exact cluster assignments and synchronous public dispatch are the same. Unit 41 starts at `(12.84462738,0,1.60043442)` and accepts `(28.5,0,17.5)` on natural order 2 at frame 189. Field command generation is 0.

This inherited fixture omits the earlier 30-unit/gate trajectories and hidden navigation/RVO history. It does not restore runtime state. E uses the original recorder, F adds selector/clearance observation for unit41, and G adds movement/projection observations. These differences and engine timing can affect trajectories; the captures do not establish their causal contribution.

| Retained execution | Original checks / failures / exit | Unit41 terminal route seconds (command elapsed) | Peer49 ARRIVED route seconds | Unit41 recoveries |
|---|---:|---:|---:|---:|
| E current headless 1 | 29 / 3 / 1 | FAILED 33.733333 (33.75) | 5.000000 | 8 |
| F baseline headless 1 | 30 / 1 / 1 | ARRIVED 6.516667 (6.533333) | 12.466667 | 0 |
| F baseline headless 2 | 30 / 1 / 1 | ARRIVED 8.500000 (8.516667) | 10.983333 | 0 |
| G final post headless 2 | 32 / 0 / 0 | ARRIVED 6.533333 (6.55) | 5.483333 | 0 |

These are old outcomes, not new runs. Both F executions still fail the original step assertion. Their arrivals precede peer49 parking, so neither exercises E's parked-peer-before-stall condition. G does have earlier peer49 parking, but its approach differs: its nearest retained moving-41/parked-49 group sample is 2.290307 apart, versus E's 0.572733. Earlier parking alone is therefore insufficient to identify the target geometry. Sampled distances are not continuous minima or native RVO neighbor membership.

Exact terminal-intent/result references are F1 unit41 **1626/1628, frame580**, peer49 **2080/2082, frame937**; F2 unit41 **1924/1926, frame699**, peer49 **2093/2095, frame848**; G unit41 **1646/1648, frame581**, peer49 **1534/1536, frame518**. F1 peer49 spends two recovery attempts and F2 peer49 one before arriving. Those actual recovery histories distinguish the trajectories; they do not establish a changed public scheduling instruction or the first cause of the divergence.

## Earliest observable divergence precedes the blocker

At the first common progress-query sample, **frame 233, route .733333 seconds**, E event **788** already differs from F1/F2/G event **786**. All retain the same next waypoint `(12.99527168,0,7.15000010)` at this sample. Their positions and last actually received safe velocities differ:

| Capture | Unit41 x, z at query | Recorded safe callback at frame 232, x, z |
|---|---|---|
| E | 13.211290, 5.120924 | 1.956852, 4.601166 |
| F1 | 12.978419, 5.131104 | .333139, 4.776528 |
| F2 | 12.980383, 5.121680 | .596946, 4.270420 |
| G | 12.977532, 5.166005 | .669644, 4.954955 |

These are actual event/callback receipts. `last_safe_callback` does not recover the missing movement call, its contacts, or which engine submission produced it. The first retained difference is not necessarily the first real divergence. It occurs long before peer49 parks; no differing public command is recorded to explain it.

The cached next-waypoint differences become explicit later. At **frame413**, E heads toward `(18.849998,0,17.092323)` from `(17.465254,0,16.799002)`; F1 and G instead head toward approximately `(21.15,0,13.0133)` from the northern approach, while F2 heads toward `(16.85,0,15.2650)`. At **frame548**, F1 and G already request their final `(28.5,0,17.5)` goal from near `(28.7149,0,14.9791)` and `(28.0089,0,14.8230)`. E and F2 remain on different western/southern approach legs. These are cached waypoint/event observations, not reconstructed complete native path-query returns; exact values, query events and source references are in `m501h-success-table.json`.

E's later actual progress query snapshots trace its approach: event **1608/frame548** is at `(22.160154,0,18.941349)`, heading toward `(25.849998,0,18.849998)`; **1724/frame593** is at `(24.596218,0,19.539640)` with that waypoint; **1800/frame638**, route7.483333, is already at `(26.276672,0,18.849998)`, requesting east `(5,0,0)` toward `(26.849998,0,18.849998)`. The remaining-path native return at event1800 is 3.071657896.

F1 and G have no retained actor state on E's target boundary strip. F2 does retain a later boundary state at **event1867**, route8.233333, `(27.749577,0,18.849998)`, after passing east of E's stop while peer49 is still moving. Its closest retained actor state to E's stop is about .560742 away. These are observations about the available states, not proof of an unrecorded route segment. Raw cached-path snapshots, chronological queries and nearby-peer excerpts are in `m501h-success-chronology.json` and `m501h-success-excerpts.json`.

## What the E failure proves, and what is missing

Peer49's actual arrival **event1409/frame489**, route5.0, precedes the near-stop observation and all retries. It parks at `(26.830004,0,18.997255)`. Nearby peers48,23,47,44,27 and50 also park before first recovery; their actual transitions and repeated cached states remain in the unchanged E analysis. At **event1807/frame650**, route7.683333, unit41 is moving beside parked49 at sampled distance .572732698, with summed radii approximately .58. Native active neighbors and constraints are not recorded.

E unit41's **entire active movement archive begins at frame654**. Frames **189–653 inclusive, 465 frames**, are absent. This spans public dispatch, early divergence, peer49 parking and the approach to the already observed near-stop. Event snapshots survive, but continuous movement inputs/returns, initial cached-path changes and contemporaneous full neighbor motion do not.

Frame654 is the only retained movement before the exact final stop; frame655 is the first retained exact-stop zero call. That is an archive boundary, not a proven instant of stall onset. There are **1,550 retained exact-stop zero calls** across later windows, including **1,432 after first recovery admission**. Admission-frame callbacks and the terminal frame are not recovered merely because the coverage receipt is complete. F1 also omits active frames189–460, F2 omits189–579, and G omits189–218 plus339–406. E/F1 and E/G have no common archived active frames; E/F2 has45, already after their trajectories diverged.

The E retries remain fully supported: first admission **event1993/frame773**, route9.733333; eight final-goal admissions separated by three seconds; eight clears after approximately2.016667 active recovery seconds; final admission **2276/frame2033**, clear **2284/frame2153**, and FAILED intent **2290/frame2213**. All targets remain the authoritative final goal. Later actual path returns stay3.071812391 with no meaningful credited progress. The stable late actual avoidance input is approximately `(-.0000227179,0,-1.56606126)` while the requested direction is east. Each retained zero call returns once, advances its stamp and has no contacts.

The actual selector's individual candidate rejections were not captured in E. F's added selector/clearance seams never execute for unit41 because it never recovers; G also has no unit41 recovery. No retained run proves that a shorter escape is both navigable and avoidance-compatible. The old one-metre escape calculation remains a geometric hypothesis.

## Relevance of the verified projection repair

The final movement guard requires a changed projection **and projected displacement greater than the unchanged callback budget**. For E's stopped outward input, offline float32 arithmetic proposes approximately `(26.27651787,0,18.82389832)`. Nearest-point arithmetic on the captured rectangular navigation union returns the unchanged stop `(26.27651787,0,18.84999847)`. Projected distance is0, versus a positive callback budget near .026101. Therefore the repair's added path branch is inactive for **all1,550 retained exact-stop calls** under this offline/source calculation.

The observed zero movements are actual engine results. The nearest-point result and counterfactual branch decision above are offline calculations, not newly queried or intercepted native returns. This does not assert what a new execution would do with different hidden state.

G does record actual corrected projection movement for unit41 at **event1032/motion16891/frame338** and **event1540/motion26291/frame526**. Those observations establish that the repair affects this actor's approach on G's inputs. E's corresponding approach calls are absent, so they cannot establish that the same changes prevented E's stall. Successful G arrival and the verified step-size fix do not resolve the zero-displacement mechanism.

## Design decision and smallest next observation

Demonstrated prerequisites are: the accepted goal; a particular boundary approach beside peers that have already parked; actual outward avoidance velocity; cancelled movement; and exhausted final-goal retries. Missing is the **causally sufficient, controllable public-command condition** that forms that conjunction. The common fixture and commands alone have produced different approaches and parking orders. Delaying unit41 until49 parks, scheduling49 to reproduce a timestamp, restoring E's near-stop state, or injecting the hypothetical short leg would impose an unverified cause. None is proposed.

Accordingly, there is **no new reproduction fixture and no two-baseline execution proposal** in this task. The smallest next action needing authorization is **test-only instrumentation work** to close the identified observation gap:

1. Retain unit41 and peer49 actual callbacks and returned movement continuously from public cluster dispatch through the first boundary approach/cancellation and recovery entry. Include inputs, delta, start/end, frame stamps, contacts, command identity and cached path/waypoint changes. Preserve timestamped nearby-peer poses, moving/parked state and radii over the same interval.
2. Record actual selector/clearance returns at recovery entry through narrow seams. Mark unobserved inline rejection reasons explicitly; additional diagnostic queries must remain separate from production results.
3. Validate observer wiring, exact unchanged setup, capacity/overflow accounting and preservation of every assertion before any separately authorized, explicitly budgeted observation execution. Never force the approach or peer parking to satisfy an oracle.

This is an observation specification, not authorization for implementation, a new engine run, or a repetition campaign. Its purpose is to observe the missing transition at the first divergence, not to treat another passing run as proof. A later design decision would require an actual captured trigger that can be expressed through supported creation/public commands. No active RVO set or native submission identity is promised where the engine API does not expose it.

## Preservation and analytical execution record

The pre-task **183-file** source snapshot and **7,344 prior evidence files** are hash-audited. Only this new document and an append to the investigation are delivery source changes. Existing investigation bytes remain an exact prefix; production, tests, fixtures, acceptance requirements and original artifacts remain unchanged. No commit or staging occurred.

Final retained analyses pass **8 E chronology checks, 20 cross-capture checks, 8 projection-relevance checks and 36 supplemental query/terminal-table checks**. These are offline validation totals, not new gameplay assertions. Earlier attempts remain preserved: the cross-capture script's parse error; the E extractor's wrong `slide_contacts` key; and its wrapper's premature handling of Python stderr. The failed E script was retained and rerun unchanged solely to capture the complete traceback, then corrected to read the actual `contacts` field. The first wrapper's inner exit was not captured independently; its outer exit1 and original source remain, alongside the later complete same-source failure receipt. No missing output is fabricated. The projection reviewer also preserves its successful first analysis revision before clarifying the coverage limitation.

Exact analysis commands, retained script hashes, input hashes, outputs, exit codes and failed-attempt details are under `validation-output/m501h-*`. Every original engine command/result remains in its original invocation/log/receipt; H starts no engine. The compact archive is `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-unit41-reproduction-design-evidence.zip`, with actual SHA-256 in its companion `.sha256` and `m501h-package-result.json`. It contains the four raw E/F/G comparison captures, reference evidence, source mappings, analyses, failures and entry hashes.

- Reproduction design: **INSUFFICIENT EVIDENCE**
- Next authorization needed: **test-only continuous approach/peer/selection instrumentation; no runtime budget reopened**
- Projection step-size repair and Issue A: **unchanged; no new runtime verification**
- Unit 41 boundary stall: **UNRESOLVED**
- Original Issue B: **UNRESOLVED**
- Milestone 5: **STILL BLOCKED**
