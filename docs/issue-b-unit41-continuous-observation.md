# Milestone 5.0.1: single continuous unit 41 observation

The sole authorized moving observation completed with **33 native checks, zero failures, exit 0**, and a complete independently validated capture. All 50 participants arrived. **Unit 41's historical boundary stall was NOT REPRODUCED and remains unresolved. Original Issue B remains unresolved; Milestone 5 remains blocked.** No production repair, commit, or second observation followed.

This implements the approved next step after [recorder validation](issue-b-continuous-recorder.md): connect continuous capture to the unchanged frozen 50-unit fixture, validate before movement, execute exactly once, and inspect the full approach. It does not reopen the closed F/G budgets. J's separate one-observation authorization is now consumed and closed.

## Integration and unchanged acceptance

`tests/continuous_route_checks.gd` inherits `unit41_boundary_checks.gd`, which directly invokes the unchanged `unit13_fixture_checks.gd` cluster observer. Every original movement, accepted-goal/order, recovery-attempt, navigation/obstacle, actor13/all50 arrival, 75-second observation deadline, 180-tick settling and minimum separation > .6 predicate remains executable and unchanged. Unit41's exact `(28.5,0,17.5)` natural-order2 arrival is inherited. Actual-call displacement <= movement_speed*delta+.001 and complete returned observations for every participant remain additional assertions. The original per-frame step <= movement_speed/60+.001 assertion also remains intact.

The copied setup body differs only in test-only field/recorder injection and the initial continuous-observation hook. Its creation, selection, registration, topology checks and public parking chronology are mechanically compared with the original source. Original parking commands occur at frame6. The initial180-tick sampler returns at frame189, and cluster commands are dispatched immediately in that same physics-frame continuation. **No extra idle wait was inserted before cluster dispatch.** Final callbacks are drained only before synchronous teardown.

The completed J wiring artifact is byte-identical to E/F/G: SHA-256 `fcf629e7ae2d04a6e49f8e99cb724fb3dd97721dcf240017a40512d6547827c8`. Population, geometry, original creation positions, exact public parking/cluster goals and movement parameters are preserved. The existing fixture remains a derived cluster setup omitting the earlier30-unit/gate trajectories and hidden navigation/RVO history; this task adds no simplification or imposed neighbor schedule. It does not recreate original Issue B's full sequence.

`tests/continuous_route_recorder.gd` extends the unchanged I recorder, attaching the executed gameplay receipt before footer serialization and aggregating fully returned actual movement calls. It reuses I's all-participant probe and actual selector/clearance seams. The extra native projection diagnostic queries used by G are omitted from this observer; completed actual movement inputs/returns/stamps/contacts are retained. This is an observation-seam difference, not a removed gameplay predicate. No production navigation query or movement rule changes.

The new launch tool and PowerShell bridge require successful same-source parser and precluster receipts plus independent capture validation. They retain exact arguments and source copies, reserve `m501j-observation-slot.json` before observation launch, and refuse another attempt or bridge replay. Preparation failures cannot fall through into a simulation. The unchanged internal180-second wall watchdog and external240-second process-tree deadline remain.

## Predetermined budget and all execution outcomes

The plan was fixed in `validation-output/m501j-run-plan.md` before engine execution: at most2 parser checks, one precluster validation, one moving observation, and no observation retry. Actual usage:

| Execution | Actual result | Observation slots |
|---|---|---:|
| `m501j-parser-1` | Exit1: missing explicit type on a new adapter's `observed` variable | 0 |
| `m501j-parser-2` | Exit0 after the one-line explicit bool/int correction; no errors | 0 |
| `m501j-validate-1` | 19 checks / 0 failures / exit0; independent capture valid | 0 |
| `m501j-observe-1` | 33 checks / 0 failures / exit0; independent route capture valid | **1** |

The first parser failure, exact source, log and exit are retained. No production code changed to address it. The corrected adapter passes the same203 offline correspondence/preservation checks as its first revision. Offline suites also pass the unchanged I50 tests, J14 resource-profile tests and34 launch-guard tests. A PowerShell receipt helper failed to hash a nonexistent empty-stderr file after a successful syntax parse; that helper failure and original source are preserved, followed by a corrected complete receipt. The capacity reviewer also preserves its failed exploratory read. These are not unreported simulation attempts.

The precluster execution preserves all original setup checks and records frames1–189, all50 participants and9,450 completed idle callbacks. It has exactly50 accepted parking commands, zero movement calls or cluster commands, and successful teardown. Independent precluster chronology/receipt review passes16 checks. Its result/stream validity is a mandatory launch gate.

The final validation and observation use identical producer manifests. Across all four engine executions there are **52 completed-suite assertions and zero assertion failures**, plus the separately reported parser failure. Native final totals are printed after result-write assertions. The observation footer contains the30 gameplay/teardown checks already executed before finalization; the result contains31 before its two write checks; stdout reports the authoritative33. These different boundaries are labeled, not substituted for one another.

## Complete actual moving evidence

Independent route validation and217 supplemental integrity/source/slot checks pass:

- Frames **1–1967** are continuous, with all50 participant rows and **98,350 completed callbacks**.
- **25,389 actual movement calls** have matching advancing stamps, completed return observations and zero slide contacts. Every participant has actual movement observations.
- There are zero actual or sampled step-size excesses. Maximum actual displacement is approximately **.08333524**, below unchanged **5/60+.001**.
- All50 participants are recorded ARRIVED by frame1786; the original observer recognizes completion at1787. Its unchanged180-tick stationary sampler passes through1967, with zero displacement and settled minimum separation **1.165431023 > .6**. The continuous latest-observation rows therefore retain181 frames after first all-arrived observation; the original sampler still executes exactly180 ticks.
- Exactly100 public commands are recorded:50 parking commands at frame6 and50 cluster commands at frame189.
- All **297,911 observation-clock points** are unique and contiguous. Footer admission/completion counts match every participant; no record ages out, no delegate remains pending, and no capture error is hidden by gameplay success.

The capture is366,866,324 bytes, SHA-256 `2eac3d698cd36e9acc41eda885e8e46895e61938f9b51f9b79abc6bdb578ead9`. All data and its independent report remain in `validation-output/m501j-observe-1*`.

## Why this does not reproduce the historical stall

The [independent chronology](../validation-output/m501j-chronology-review.md) preserves exact events, observations and source references, with17 passing offline checks.

Unit41 accepts `(28.5,0,17.5)` on order2 at **seq857/frame189** and arrives at **terminal intent/result seq2840/2842, frame622**, command elapsed7.233333, recoveries0. Peer49 parks at **seq3588/3590, frame937**, command elapsed12.483333, after two recovery attempts. Thus J has **no interval with moving unit41 beside already-parked order2 peer49**. E instead has peer49 parked by frame489 before the stall and all eight failed retries.

Unit41 has **433 returned movement calls, zero zero-displacement calls, and no recovery/selector/clearance events**. It never enters E's captured boundary strip. Its nearest retained moving endpoint to E's exact stop is2.645212944 away. These are offline measurements of actual recorded states, not native solver constraints or continuous-segment minima.

J now retains the initial13-point cached path at **seq935/frame189**, through the northern z≈12.85–13.15 corridor. That nonempty point array remains the same while12 cached indices advance, then clears at arrival. E's initial cached path and active calls189–653 remain unavailable. J unit41 arrives before E's first retained active callback at654, so the new complete trace cannot supply the missing historical approach.

At the first common progress sample **J seq1129/frame233 versus E event788/frame233**, the cached next waypoint agrees, but positions already differ by.257367086 before peer49 parks. J's preceding actual callback232 and full returned call are retained; E retains only a last-safe callback observation at that point. J's requested velocity is approximately(.104747,0,4.998903), actual avoidance input(.375593,0,4.985873), with one returned movement, advancing stamp231→232 and empty contacts. E's last-safe observation is approximately(1.956852,0,4.601166). This is the earliest common observed difference, not a demonstrated first cause.

Peer49's **3 actual selector returns,11 actual clearance returns,2 recovery admissions and2 clears** are captured separately at frames638–865, after unit41 has already arrived. They include rejected supplied paths and subsequent selected nonfinal legs while preserving the attempt count. This verifies useful live recovery-observation paths. It is neither unit41 recovery evidence nor proof that a shorter escape would solve the historical failure. Earlier inline rejection reasons and the native RVO active-neighbor/constraint set remain unavailable.

## Capacity, preservation and limitations

Retained-size analysis projected1,068,110,737 bytes for a full-deadline frame history before moving progress/path/recovery events, leaving only5.6MB under I's1GiB ceiling. Separate source-derived event stress estimates needed further capacity. Before engines, J therefore declared a **4GiB evidence-storage limit**, retaining the10,000-frame hard limit and fail-closed/no-eviction behavior. A separate J validator module changes only that storage ceiling. Original I source and its1GiB behavior are untouched. No movement, separation, duration, attempt or acceptance threshold changed. Capacity estimates are offline calculations, not simulated trajectories or guarantees about arbitrary future traces.

The194-file starting source snapshot and8,179 prior evidence files are hash-audited. Production, all pre-existing tests/fixtures and prior documentation are unchanged except the append to the investigation. Production remains SHA-256 `1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4`; fixture remains `d56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307`. Issue A's regression source and previous validated results remain preserved; no separate Issue A suite ran in this bounded observation task.

The observation closes J's aged-history gap and validates moving/peer-recovery recording. It still establishes no controllable public-command condition that forms E's failed boundary approach. Observer timing may affect trajectories; neither those effects nor native solver constraints are identified causally by this run. No new fixture, forced delay, speculative recovery patch or automatic repetition is supported. The sole observation is finished; no further runtime was started.

Compact evidence ZIP: `D:/GitHub/Command_and_Concur_Generals/validation-output/milestone-5.0.1-continuous-observation-evidence.zip`, with actual SHA-256 in its companion checksum and `m501j-package-result.json`. It includes exact commands, sources/hashes, input fixtures, complete captures, failed attempts, logs, exits, independent analyses and entry hashes. Original evidence remains in place.

- Unit41 boundary stall: **NOT REPRODUCED; UNRESOLVED**
- Projection step-size repair: **PRESERVED; no excess in this observation**
- Issue A: **PRESERVED; no separate regression-suite rerun**
- Original Issue B: **UNRESOLVED**
- Milestone 5: **STILL BLOCKED**
