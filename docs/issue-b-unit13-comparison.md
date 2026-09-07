# Unit 13: frozen derived-cluster comparison

**The intended historical unit-13 failure was NOT REPRODUCED. Original Issue B: UNRESOLVED; Milestone 5: STILL BLOCKED.** Unit 13 arrived in all four prescribed executions. All four executions nevertheless failed at least one unchanged assertion in the new fixture runner. Current headless also captured a separate unit-41 failure. These results do not verify repair of the previously captured unit-13 mechanism, recover original unit-4 history, or justify acceptance.

The four-case mechanism budget is complete. No additional mechanism execution, fixture retuning, production change, threshold change, acceptance waiver, or feature work followed these outcomes. The validated Issue A repair and its existing tests remain intact.

## Fixed inputs and limits of reconstruction

The [pre-execution plan](../validation-output/m501e-run-plan.md), [independent source review](../validation-output/m501e-source-review.md), and [fixture-design evidence](../validation-output/m501e-fixture-design-evidence.md) define one derived cluster-only fixture. The authoritative previous capture is `m501d-historical-full-headless-1-capture.json`, SHA-256 `251d83cc59eb3952b356999c3b9354743081f55c01e7b05980e29889e992da82`.

Event **1947**, absolute frame **5011**, supplies a coherent snapshot of all 50 parked positions and prior gate goals after the successful gate and settling. Event **2149** supplies all 50 accepted cluster assignments. Actor 13 starts at `(6.81458569,0,-1.43630791)`, receives the old parking goal `(7,0,-1.5)`, then the exact cluster goal **`(33,0,26.5)`**. The [frozen fixture](../tests/fixtures/unit13_predeadlock.json) has SHA-256 `d56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307`.

Initial minimum center separation is **1.178749375**, greater than the 0.86 physical capsule diameter. Minimum center-to-solid distance is **1.874761604**, or **1.444761604** after subtracting body radius. All positions and old/new goals lie on the captured navigation polygons under the documented offline membership check. Later coherent snapshots nearer first recovery already contain runtime body overlaps, so none was converted into an initially overlapping spawn layout. These are offline geometry observations; the runner independently checks actual synchronized navigation and solid clearance during setup.

Each unit is created normally at its recorded position before tree entry. Public moves to old gate goals establish normal ARRIVED state and parked radius, followed by three frames and **180 settled physics ticks**. All exact cluster goals are then dispatched synchronously through public per-unit `move_to` calls in stable ID order. Orders naturally become parking order 1 and cluster order 2; field command generation remains **0**, rather than fabricating the previous group command's generation 4. No private timer, recovery counter, waypoint, velocity, parked state, or cached path is injected. Moving peers are never frozen, and their parking order emerges during simulation.

This deliberately omits preceding 30-unit/gate trajectories and starts fresh navigation/RVO objects. Public parking cannot recreate their hidden history. Matching intended setup is therefore narrower than replaying the prior full sequence. The fixture has its own `unit13_cluster` route; the absence of a gate in these captures is expected.

Historical movement SHA-256 is `1043b608167a411f040cb72151afedddd0d1fd86048f97286d5180226dadcc5c`; current validated movement is `9b26194e6a0ef505573b0f51a8a7cdb1c409fae24c9526ccae0284cef29bbe2b`. The eligible source difference is the already validated Issue A repair. Original geometry, default movement/recovery parameters and stress source are unchanged. Both use Godot **4.7.2**, executable SHA-256 `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`, at fixed 60 physics ticks per second. The route limit remains 75 seconds, command limit 90 seconds, in-run wall watchdog 180 seconds, and external wrapper limit 240 seconds. These are limits, not relaxed success tolerances.

The [source freeze](../validation-output/m501e-mechanism-source-freeze.json) preceded case 1. The eight retained diagnostic/fixture source hashes match in every mechanism invocation. The two valid wiring harnesses produced equal intended setup/command artifacts and ended at the dispatch frame before any cluster movement; see [harness comparison](../validation-output/m501e-harness-comparison.json). The first historical harness failed to parse at `tests/unit13_fixture_checks.gd:110` because `watched` lacked an explicit inferable type. That source and log are retained. Adding its explicit Boolean type repaired only the harness before the source freeze; its failed attempt is not hidden or counted as a mechanism run.

## Complete execution ledger

All rows are serial calls on **2026-09-07 UTC**. Each case links its exact invocation manifest; matching `.log`, `-wrapper.txt`, and retained source directory share its prefix. “Complete” means recorder receipt plus independent capture validation, not passing gameplay. Imports and unchanged Issue A suites do not use this recorder.

| Case | Start UTC | Wall seconds | Checks / failures | Exit | Capture / purpose |
| --- | --- | ---: | --- | ---: | --- |
| [H import](../validation-output/m501e-historical-import-1-invocation.json) | 05:45:59 | 5.429 | N/A | 0 | N/A; project import |
| [C import](../validation-output/m501e-current-import-1-invocation.json) | 05:46:14 | 6.255 | N/A | 0 | N/A; project import |
| [H harness attempt 1](../validation-output/m501e-historical-harness-1-invocation.json) | 05:46:29 | 0.526 | None reached | 1 | Unavailable; parse failure before entry |
| [H harness attempt 2](../validation-output/m501e-historical-harness-2-invocation.json) | 05:46:47 | 4.882 | 24 / 0 | 0 | Complete; no cluster physics steps |
| [C harness](../validation-output/m501e-current-harness-1-invocation.json) | 05:47:06 | 4.889 | 24 / 0 | 0 | Complete; no cluster physics steps |
| [H headless mechanism](../validation-output/m501e-historical-mechanism-headless-1-invocation.json) | 05:48:53 | 16.856 | 29 / 1 | 1 | Complete; added step assertion fails |
| [C headless mechanism](../validation-output/m501e-current-mechanism-headless-1-invocation.json) | 05:51:23 | 25.327 | 29 / 3 | 1 | Complete; unit 41, spacing, added step assertion |
| [H graphical mechanism](../validation-output/m501e-historical-mechanism-graphical-1-invocation.json) | 05:53:10 | 22.942 | 29 / 1 | 1 | Complete; added step assertion fails |
| [C graphical mechanism](../validation-output/m501e-current-mechanism-graphical-1-invocation.json) | 05:55:18 | 21.062 | 29 / 1 | 1 | Complete; added step assertion fails |
| [A focused headless](../validation-output/m501e-A-focused-headless-1-invocation.json) | 05:57:47 | 0.769 | 14 / 0 | 0 | N/A; unchanged regression |
| [A controls headless](../validation-output/m501e-A-controls-headless-1-invocation.json) | 05:57:56 | 1.241 | 84 / 0 | 0 | N/A; unchanged regression |
| [A captured headless](../validation-output/m501e-A-captured-headless-1-invocation.json) | 05:58:06 | 0.852 | 10 / 0 | 0 | N/A; unchanged regression |
| [A focused graphical](../validation-output/m501e-A-focused-graphical-1-invocation.json) | 05:58:14 | 2.819 | 14 / 0 | 0 | N/A; unchanged regression |
| [A controls graphical](../validation-output/m501e-A-controls-graphical-1-invocation.json) | 05:58:29 | 6.856 | 84 / 0 | 0 | N/A; unchanged regression |
| [A captured graphical](../validation-output/m501e-A-captured-graphical-1-invocation.json) | 05:58:52 | 4.024 | 10 / 0 | 0 | N/A; unchanged regression |

The six unchanged Issue A suites total **216 checks, 0 failures**, with all six exits 0. The [wrapper self-test receipt](../validation-output/m501e-wrapper-self-tests.json) records a subsequent parent run from 05:59:09.6779009 to 05:59:14.6743680 UTC: **5 checks, 0 failures, parent exit 0**. Its four serial engine children are separately accounted for:

| Wrapper child | Child exit | Limit | Interpretation |
| --- | ---: | ---: | --- |
| `--version` | 0 | 15 s | Ordinary successful child |
| Unguarded blocking-fixture request | 3 | 15 s | Intentional negative: fixture guard |
| `milestone_checks.gd --verify-timeout` | 2 | 15 s | Intentional negative: internal timeout |
| `blocking_fixture.gd --verify-external-timeout` | 124 | 2 s | Intentional negative: external watchdog |

Thus there are **15 dedicated invocation manifests plus 4 wrapper children = 19 engine calls**, including imports and the failed harness. Expected timeout exit 2 appears only in the explicit wrapper negative test, never as success for normal validation. The three previously existing generic wrapper logs were restored hash-identically; E-prefixed copies retain this execution's negative-test output.

## Outcomes and actor-13 chronology

All four runs retain the exact 50 goals and order 2 throughout the cluster order. “Route completion” below is the observer's stopping sample, before the additional 180 settling ticks; it is not actor 13's individual arrival time.

| Case | Route completion s | Actor 13 arrival event / frame / route s | Actor attempts | All arrived | Max sampled step | Final minimum separation | Overlap pair-seconds |
| --- | ---: | --- | ---: | --- | ---: | ---: | ---: |
| H headless | 13.216667 | 1966 / 765 / 9.600000 | 0 | Yes | 0.131343022 | 1.286303997 | 32.1 |
| C headless | 33.750000 | 2166 / 1053 / 14.400000 | 1 | No: 41 FAILED | 0.130014837 | 0.572740078 | 80.1 |
| H graphical | 14.450000 | 2115 / 909 / 12.000000 | 1 | Yes | 0.133596838 | 1.206834793 | 51.6 |
| C graphical | 13.816667 | 2034 / 1017 / 13.800000 | 1 | Yes | 0.133417636 | 1.223456621 | 39.2 |

Every listed arrival is the actual `terminal_requested` event **before cleanup**, with moving true and caller `unit_physics`, followed by the recorded ARRIVED result. Command elapsed is one physics tick greater than route event time because the production timer increments during that tick: actor values are respectively 9.616667, 14.416667, 12.016667 and 13.816667 seconds. All route origins are absolute frame **189**; run origin is frame **1**. Route time is `(absolute_frame - 189) / 60`, not the production elapsed timer. The route end adds exactly 180 settling ticks to the sampled completion. Wall duration is measured separately and is not simulation time.

The overlap metric counts **unordered pairs whose center distance is less than .6**, adding **.1 pair-seconds per 10 Hz sample**. It is a sampled overlap-duration sum, not a percentage, physical penetration depth, unique pair count, or continuous collision integral. Stationary displacement over the final 180 ticks was zero in every case. Current headless still fails the unchanged combined settling contract because unit 41 did not arrive and minimum separation is independently below .6; zero displacement does not demonstrate acceptable settling.

The previous full-sequence failure had peer parking order **14 → 6 → 11** at route 9.0, 9.383333 and 9.616667 seconds, before actor 13's first recovery. The derived executions record:

| Case | Peer ARRIVED events in actual order (ID: event / frame / route s) | Actor recovery |
| --- | --- | --- |
| H headless | 6: 1631 / 589 / 6.666667; 11: 1938 / 732 / 9.050000; 14: 1959 / 757 / 9.466667 | None |
| C headless | 6: 1837 / 677 / 8.133333; 11: 1904 / 686 / 8.283333; 14: 2052 / 838 / 10.816667 | Event 2116 / frame 953 / 12.733333 s; 0 → 1 |
| H graphical | 6: 1969 / 757 / 9.466667; 14: 2009 / 788 / 9.983333; 11: 2020 / 808 / 10.316667 | Event 2034 / frame 818 / 10.483333 s; 0 → 1 |
| C graphical | 14: 1863 / 701 / 8.533333; 6: 1941 / 774 / 9.750000; 11: 1945 / 795 / 10.100000 | Event 2003 / frame 908 / 11.983333 s; 0 → 1 |

Only C graphical preserves that peer order, with different times and poses. Neither historical run reproduces the intended failed episode.

H graphical selects the non-final target `(31.00530434,0,21.41875839)` from `(30.20139503,0,19.37089920)`. The retained active window contains **24 actual callbacks and movement delegates, all with nonzero displacement**. Clear event 2054 at frame 842/10.883333 s comes from `unit_physics`, observes target distance .288135618 and internal recovery elapsed .416666667, consistent with the normal waypoint-proximity clear. The target segment does not enter the recorded clearance of reference peers 6/11/14 under the offline predicate. This successful recovery is unlike the previous repeated unsuitable-target immobility.

Both current actor-13 admissions observe target equality with `(33,0,26.5)`. Target equality alone is not an instrumented internal fallback label or a reconstruction of all candidate rejections. Each active window retains **45 actual moving callbacks/delegates**, all with nonzero displacement. C headless query 2137 returns actual remaining length **4.749120712**, signed progress **+3.115534782**, before progress-context clear 2139 at frame 998/13.483333 s. C graphical query 2023 returns **5.194968700**, signed progress **+2.515888214**, before clear 2025 at frame 953/12.733333 s. These clears occur at internal active elapsed .75 seconds. No actor-13 attempt-cap failure occurs in any case. Final-path queries are production returns; signed differences are explicitly observer arithmetic from recorded baselines and returns.

## Separate failures retained

The added displacement assertion genuinely fails. Its bound is `5 / 60 + .001 = .0843333333` metres per observed tick. The [independent step analysis](../validation-output/m501e-step-analysis.md) establishes **10 retained single movement calls** over that bound in the first H headless run. Its largest archived example is unit 9, motion 32059, absolute frame 642, displacement **.1292624863**, with one returned delegate, delta 1/60 and no contacts. The exact actor/frame of the runner's larger aggregate .131343022 maximum is unavailable in retained windows and is not assigned to this example.

Offline float32 geometry predicts all 10 endpoints within `9.54e-7`: closest-navigation projection around a nonconvex clearance corner can enlarge displacement, and the shared `_move_on_navigation` does not clamp afterward. Actual native projection returns were not separately instrumented. The function is identical in H/current, and the earlier D full capture already contains 12 excess calls. This is pre-existing projection behavior newly checked by this fixture, not evidence of an Issue A regression. The detailed single-call analysis applies to that first run; the other three retain their own failed assertion and aggregate values. No threshold or source change discounts any failure.

Current headless unit 41 is a separate, fully captured remaining problem; see the [unit-41 report](../validation-output/m501e-unit41-analysis.md) and [bounded numerical excerpts](../validation-output/m501e-unit41-analysis.json). It retains goal `(28.5,0,17.5)` and order 2, stops near `(26.27651787,0,18.84999847)`, and requests FAILED at event **2290**, frame **2213**, route **33.733333 s**, command elapsed about **33.75 s**. It has eight attempts, stall 26.25 s, and caller `update_progress`, well before the 90-second command deadline.

All eight actual targets equal its final goal, with one waypoint each and no observed continuation. Admissions occur at route 9.733333, 12.733333, 15.733333, 18.733333, 21.733333, 24.733333, 27.733333 and 30.733333 seconds; each increments once and clears with active elapsed 2.016667 seconds. Its 46 actual final-path queries contain 45 progress samples. The last 35 return **3.071812391**, against baseline **3.071657896**, signed **−.000154495**. The attempt cap gives bounded termination; it does not explain the immobilization.

Peer 49 parks at route 5 seconds, only **.572740071** from the eventual stopped actor. The recorded final navigation path follows the z=18.849998 edge eastward into that parked neighbor's clearance. Across 1,432 retained callbacks in the report's bounded post-admission windows, requested velocity is `(5,0,0)`, actual safe callback approximately `(-.000022718,0,-1.566061258)`, and every returned movement call advances its frame stamp yet has **zero displacement and no slide contacts**. The callback points outside the local navigable side. Captured geometry plus production projection explains its cancellation; the actual internal projection return remains unavailable. The source selector permits an unchecked final-goal fallback. Goal distance 2.601224 exceeds the admitted candidate bound 2.55, supporting that fallback attribution in this particular state, while individual rejection reasons remain unknown.

This differs from the previous historical actor 13 repeatedly selecting a non-final path into parked clearance. The other three unit-41 arrivals do not erase its current headless failure or establish why trajectories diverged. No repair is implemented or verified. The separately documented shorter-first-leg idea is only a bounded proposal requiring another authorized reproduction and actual arrival/settling validation; it is not acceptance evidence.

## Capture validation and evidence boundaries

The [offline analyzer](../validation-output/m501e-analyze.py) writes E-prefixed analyses only and imports pure value/clock/log helpers from the retained [D analyzer](../validation-output/m501d-analyze.py). Per-case analyses preserve exact actor queries, admission/clear/terminal records, peer transitions, preterminal group states, bounded callback excerpts, hashes and independent checks:

| Case analysis | Events | Received callbacks | Archived callbacks | Actual final-path queries | Actor-13 queries / progress results |
| --- | ---: | ---: | ---: | ---: | ---: |
| [H headless](../validation-output/m501e-historical-mechanism-headless-1-analysis.json) | 2172 | 58050 | 18373 | 600 | 13 / 12 |
| [C headless](../validation-output/m501e-current-mechanism-headless-1-analysis.json) | 2396 | 119650 | 20243 | 662 | 20 / 19 |
| [H graphical](../validation-output/m501e-historical-mechanism-graphical-1-analysis.json) | 2261 | 61750 | 18950 | 621 | 17 / 16 |
| [C graphical](../validation-output/m501e-current-mechanism-graphical-1-analysis.json) | 2139 | 59850 | 18439 | 593 | 19 / 18 |

All listed actual queries are finite. Every valid harness/mechanism captures IDs 1–50 with fresh order 0 before all 100 public commands, exact fixture poses/goals and natural orders, complete pre-cleanup parking/terminal events, consistent absolute/run/route clocks, local callback continuity in retained windows, and correct group membership. Every mechanism has 100 preterminal and 100 terminal-result events, covering parking and the cluster order. Current headless alone has a FAILED preterminal, matching receipt failure ID 41. All 50 exits/unregistrations are retained; final live-unit and listener counts are zero. Receipts show no drops, missing delegate completion, serialization error or write failure. The separate receipt is authoritative for write completion; the embedded capture coverage snapshot precedes that write.

Complete bounded coverage does **not** mean every callback since launch remains in the archive: every receipt enters a bounded recent ring, and relevant event windows are retained. No-movement callbacks remain distinct from movement calls with zero displacement. Production callback, submitted order and actual movement stamps are checked separately. Candidate rejection reasons, native avoidance constraints, and projection returns are not invented. The optional current waypoint counter is null on historical source. State-transition `before` is the explicitly labeled prior observer sample; transition `after` and preterminal intent retain actual state before later cleanup/listeners.

The 29-check result JSON is written after recording `checks_before_result_write = 27`; the two successful artifact-write assertions account for the final printed 29. The analogous harness total is 24. This accounting is checked independently, rather than treating an early JSON count as the final suite total. Graphical outcomes come from the same assertions and event records, not screenshot inspection.

The original Issue B evidence still concerns **unit 4**, goal `(33,0,22)`, endpoint approximately `(31.41587,0,19.78682)`, eight attempts after a successful gate, with missing neighbor/command/progress/recovery chronology. Neither a nearby previous actor-13 endpoint nor this derived fixture establishes that missing connection. The current production source and all existing tests remain unchanged; the pre-investigation-append baseline contains 166 hash-recorded files, with the main investigation document subsequently appended separately. Prior capture artifacts remain immutable.

**Captured unit-13 mechanism in this fixture: NOT REPRODUCED. Existing repair verification for that mechanism: NOT ESTABLISHED. Original Issue B: UNRESOLVED; Milestone 5: STILL BLOCKED.**
