# Milestone 16 — buildable walls, manual gates and basic breaching

**Milestone 16: INCOMPLETE.** The original matrix completed all 102 executions: 99 passed, with 12,829 checks, five assertion failures, three native error lines and aggregate exit 1. All ten M16 executions pass 1,073 checks, included in that total. The two construction preview failures were traced to an invalid fixture timing assumption; the corrected construction tests pass 545 checks in both modes. A separate graphical movement-stress failure remains of unknown attribution, so original acceptance group 7 is NOT VERIFIED. Groups 1–6 and 8 PASS. Historical interface and movement findings remain open; no new exception is assumed.

## Play and configuration

Open [Fortified Assault](../scenes/fortified_assault.tscn) in the installed Godot 4.7.2 and press **F6**, or run:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/fortified_assault.tscn
```

The scene inherits Air Assault's original HQ, selected Bulldozer, three Rifles, 1000 credits, finite resources, paid enemy economy, defenses and declared starting helicopter. It has no free player perimeter. A short enemy demonstration line at z=18 has an initially open gate centered at (6,18), between two wall sections. The inherited ground wave/sortie timing remains 90/120 simulated seconds. Earlier scenes retain their values and the original F5 main scene.

| Structure | Credits | Working seconds | HP | Footprint | Height | Power |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
| Wall | 100 | 4 | 400 | 4 × 0.6 | 2 | 0 |
| Gate | 250 | 8 | 700 | 8 × 0.6, 6 clear opening | 2 | 0 |

Values are configurable in [Wall](../construction/wall.tres) and [Gate](../construction/gate.tres). Select one owned Bulldozer and choose Wall or Gate. Barriers alone snap their centers to a one-unit grid. **R** or the orientation button rotates between **0° and 90°**. Align collinear ends to connect walls and gate outer supports exactly; the entire gate span stays reserved even when open. A useful southern player line uses a gate at (-14,15), with walls centered at (-20,15) and (-8,15). Live units and protected access can temporarily prevent those placements.

The ordinary single unfinished-site limit, payment, physical builder travel/work, X/Move pause, right-click site resume, cancellation and original full refund remain. Rejected placement spends nothing and preserves the builder's prior order. Completed barriers cannot be refunded and are neither producers, weapons nor victory objectives.

Select an owned completed gate for **Open Gate** or **Close Gate**, current status and health. Gates complete closed and require no power. Open gates allow both teams through while supports remain solid and damageable. Closing checks all live ground units against doorway plus existing clearance both at request and final commitment. An occupied gate stays open and reports **Gate obstructed**, without displacement, damage or an automatic later close. Safely elevated aircraft do not prevent closure.

The minimap uses W for walls, C for closed gates, O for open gates and ~ during updates. Help documents R and manual gate operation. Existing Q Attack Move, X Stop, group shortcuts, economy and aircraft controls remain.

## Runtime contract

Barrier placement validates the full rotated footprint and preserves ordinary building, resource, live-unit and protected-access clearance. Only exact aligned end connections receive a scoped collision exclusion. Open gates still reserve their full span against new construction. Builder work uses the existing bounded exterior candidates, synchronized navigation and physical arrival requirements.

[BarrierBuilding](../scripts/barrier_building.gd) uses the existing building health/ownership/lifecycle authority and original primitive box geometry. One body retains support collision and picking when its doorway leaf opens. Requested state, physical state, pending navigation and effective readiness are distinct. The existing serialized construction-navigation coordinator witnesses the intended mesh and emits a guarded synchronization boundary before resuming movers. The gate commits its physical leaf there, or requests an open-map rollback if closure became occupied. Generation and membership guards reject obsolete work; previews never request navigation updates. Existing movement goals, deadlines and recovery budgets remain governed by the unchanged ground mover.

Hitscan and spherical guided projectiles use the existing firing/impact authority. Intended barrier contact can apply normal damage; intervening barriers retain world-obstruction behavior without penetration or collateral damage. Open gates aim at exposed support geometry. Aircraft retain AIR eligibility, actual 3D collision and cruise altitude. Destruction removes membership/collision immediately and serialized navigation produces the usable breach; no completed construction refund or invisible wreckage is created.

The new scene alone enables a bounded enemy breach extension. It retains the paid ground wave's HQ approach after initial move rejection, without reporting successful movement. At a configurable **0.5 simulated second** reassessment interval it checks real route availability and at most **eight distinct first obstruction candidates**. A hostile blocking barrier must have an eligible reachable exterior firing position. Owner-aware normal combat commands retain partial acceptance and supersession; no player selection is changed. Active targets remain stable, failed attempts do not indefinitely restart recovery, and surviving recipients resume the retained approach only after navigation is ready. No reachable candidate produces a clear waiting outcome. This supports a single blocking barrier, with no general multilayer siege planning.

Freeze stops new construction/gate/breach commands and builder progress. Already required navigation cleanup can finish under existing match policy. Restart reloads the scenario, retiring old wallets, sites, gate requests, navigation coordinators and wave objectives.

## Validation and acceptance

One lead performs serial engine validation through the existing fresh-copy [runner](../tools/validate-m8.ps1) and external [deadline wrapper](../tools/run-godot.ps1). [M16 matrix](../tools/validate-m16.ps1) extends the normal M15 matrix with the focused fortification suites. Source snapshots, logs, execution results and all failures are retained under `validation-output/m8/m16-*`; progress records live in `validation-output/m16/`.

The valid source-matched [M15 baseline](milestone-15.md) is reused: **92 executions and 11,756 checks include its 1,005 air checks already**. They are not added to M16 totals. The [baseline audit](../validation-output/m16/baseline-audit.json) records the pre-existing editor serialization of `project.godot` and generated UID files; the M16 matrix exercises that preserved configuration.

### Original matrix recovery and results

The [checkpoint](../validation-output/m16/recovery-checkpoint.json) and [wrapper log](../validation-output/m16/final-matrix-01-wrapper.log) resolve through `validate-m16.ps1` to the shared runner's actual directory, **`validation-output/m8/m16-final-matrix-01/`**, not a guessed directory under `m16/`. The recorded invocation was:

```powershell
& .\tools\validate-m16.ps1 -RunName m16-final-matrix-01 -TimeoutSeconds 240
```

This command was **not executed again** during collection. The [plan](../validation-output/m8/m16-final-matrix-01/plan.json) contains 102 tests (51 headless and 51 graphical), plus separate fresh-copy import, with a 240-second external deadline for each execution. Import passed with exit 0. The completed [results](../validation-output/m8/m16-final-matrix-01/results.json), per-execution `.log`/`.stdout.log`/`.stderr.log`, invocation `.ps1` files and artifacts remain in the original directory.

<!-- M16_COLLECTION_START -->
The original [final summary](../validation-output/m8/m16-final-matrix-01/summary.json) records **102/102 test executions completed, 99 passing, 12,829 checks, five assertion failures and three native error lines; aggregate exit 1**. There are **zero pending executions**. All 103 planned records, including import, are present exactly once. Import and 99 tests exit 0; the three failed tests exit 1. The wrapper explicitly records `PHASE_EXIT: 1`. Completion is established by those final artifacts, not inferred from the earlier 70/102 snapshot.
<!-- M16_COLLECTION_END -->

At first recovery, the lead verified wrapper PID **51360**, creation **2026-09-09T21:13:31.004798Z**, executable path and the complete recorded matrix command. Its child wrapper PID 52632 named the snapshot's `headless-vehicle_production_checks.ps1`; console PID 52144 and engine PID 41300 used that same snapshot and test. The [70/102 recovery state](../validation-output/m16/collected-run-state.json) remains preserved. At final collection, that wrapper and its child chain were absent and the completed summary/results agreed with the wrapper exit. The [completed collection record](../validation-output/m16/completed-run-state.json) saves final totals, failed executions and the read-only process inventory. No duplicate matrix, extra waiting process or monitoring framework was launched. The recorded observer PID 45112 and unrelated processes were left untouched. A response-stream disconnect was not classified as an engine outcome.

| Failed original execution | Checks | Assertion failures | Native error lines | Exit | Disposition |
| --- | ---: | ---: | ---: | ---: | --- |
| `headless-construction_checks` | 267 | 1 | 0 | 1 | Invalid preview-fixture timing; preserved and covered by the targeted correction below |
| `graphical-construction_checks` | 270 | 1 | 0 | 1 | Same failed fixture prerequisite; preserved and covered by the targeted correction below |
| `graphical-movement_stress_checks` | 131 | 3 | 3 | 1 | `choke_50` arrival, full traversal and settling assertions; UNKNOWN attribution, no retry or new exception |

The movement run's three native error lines are its three `ERROR: FAIL:` assertions emitted through `push_error`; the raw runner count remains **three**, not zero. They are not three additional assertion failures or evidence of a crash.

All ten M16 executions are complete, with **1,073 checks, zero failures/native error lines and exit 0 in each execution**:

| Suite | Headless checks / exit | Graphical checks / exit |
| --- | ---: | ---: |
| `fortification_checks` | 158 / 0 | 158 / 0 |
| `fortification_combat_checks` | 118 / 0 | 118 / 0 |
| `fortification_breach_checks` | 34 / 0 | 35 / 0 |
| `fortification_integration_checks` | 65 / 0 | 66 / 0 |
| `fortification_ui_checks` | 150 / 0 | 171 / 0 |

These 1,073 checks are already included in the original matrix's 12,829 checks. The corrected `m16-focused-recovery-02` import and **4/4 executions, 637 checks, zero failures/native errors, exit 0** are retained as prior correction evidence, **not added again**. Post-matrix work is limited to the preview diagnosis and two corrected construction executions below; no runtime implementation changed.

### Exact preview failure and targeted correction

Both original construction logs first fail **`stale-preview fixture initially valid`** in [the placement case](../tests/construction_checks.gd). Earlier HQ selection, initial valid preview, camera pan/zoom, cancellation and out-of-bounds rejection pass. The failing check occurs after those camera inputs, one pointer motion back toward `FIRST = (-12,0,3)` and a fixed eight-frame wait. The original screenshots capture the initial valid preview before those inputs and a later selected site; neither captures the failed assertion's exact state.

One bounded headless reproduction, **`m16-preview-diagnostic-01`**, retains the original inputs, eight-frame wait and assertions, adding only diagnostic reads. It reproduces **267 checks, one failure, no native errors, exit 1**. Its [failure log](../validation-output/m8/m16-preview-diagnostic-01/headless-construction_checks.log) records `reason = Checking placement`, a visible active preview, correct HQ selection, no hovered/focused interface, orientation 0 and no highlighted blockers. The checked point is `(-11.82161, 0.000002, 3.291897)` while the current point is `(-11.79626, 0.000002, 3.333374)`; cooldown is 0.066667 seconds. Camera zoom is **48.712835** toward **48.5**, with remaining pan velocity **(0,0.99013)**. The camera is still changing the world point beneath the fixed viewport pixel.

This establishes an **invalid fixture timing assumption**, not a demonstrated production placement defect. Existing camera smoothing runs normally, while the 10 Hz advisory validation deliberately clears stale approval and shows neutral feedback when the point has changed since its last check. The failure concerns readiness of that advisory state after viewport camera input. It is not evidence of invalid footprint geometry, barrier snapping/orientation/height, lost selection or an incorrect protected-access rejection. The diagnostic's two `validate` calls were sampled outside the physics frame and return `Placement requires a physics tick`; those values do not establish authorization or geometry failures. The original graphical failure lacks a failure-frame snapshot, but fails the same assertion; corrected coverage verifies the intended behavior in both modes. The [saved disposition](../validation-output/m16/preview-failure-disposition.json) records these evidence limits.

The correction changes **only `_placement_checks()` in `tests/construction_checks.gd`**. It waits at most two simulated seconds for normal camera pan/zoom settling, re-aims at the intended footprint, then allows at most 0.3 seconds for actual current advisory approval. It keeps the original valid-preview assertion and strengthens the intended regression: the footprint must be authoritatively valid in a physics tick before unit entry; the prior approval must still be cached when the unit enters; and the subsequent click must produce a **new occupied rejection**, leave placement active, create no site and spend nothing. No advisory refresh is inserted between unit entry and click. Camera behavior, preview cadence, footprints, protected access, ground-height checks and authoritative placement remain unchanged.

The existing fresh-copy runner executed only the affected construction suite, in both modes:

```powershell
& .\tools\validate-m8.ps1 -RunName m16-preview-diagnostic-01 -TimeoutSeconds 240 -Modes @('headless') -Suites @('construction_checks')
& .\tools\validate-m8.ps1 -RunName m16-preview-correction-01 -TimeoutSeconds 240 -Modes @('headless', 'graphical') -Suites @('construction_checks')
```

The [corrected results](../validation-output/m8/m16-preview-correction-01/results.json) and [summary](../validation-output/m8/m16-preview-correction-01/summary.json) pass fresh import and **2/2 executions: 271 headless + 274 graphical = 545 checks, zero failures/native errors, every exit 0 and aggregate exit 0**. The diagnostic failure and both original matrix failures remain intact. These are separate post-correction results, not added to or substituted into the historical matrix totals. The full matrix remains a failed matrix. No movement retry or broad navigation investigation occurred.

### Source-matched corrections and integrated evidence

The settled source retains the navigation partition correction in `scripts/test_field.gd`: nominally shared edges `13.849999427795` and `13.850000381470` differ by **0.000000953674**. Only partition edges less than `0.00001` apart are coalesced. Actual input footprints and clearance are unchanged. Both final fortification logs verify connected shared polygon edges, no degenerate strips or overoccupied edges, distinct authored 0.001-unit offsets remaining separate, and a paid wall/gate seam with neither a physical nor navigable gap. This is not a claim that a millimetre gap permits unit passage. Warning/error detection remains enabled.

Both modes also verify ordinary physical detours around a closed gate for each team, actual direct passage when open, reserved open-doorway construction space, solid supports, occupied-close rejection and entry during pending closure. Departure and deletion during pending navigation retire membership and callbacks; delayed work cannot restore the destroyed doorway, supports or blocked navigation. The recovered fixture's `PackedVector3Array` is explicitly converted to `Array` before using `any`, and its deleted-object reference is explicitly typed `WeakRef`. The original parse failures remain saved.

Preview tests require **exact X/Z = (-20, 15)** at both resolutions; ground Y comes from the physics ray. The recovered logs record **Y = 0.000001519918**, rather than exact zero. The unchanged authoritative placement check requires `abs(point.y) <= 0.05`, checks five footprint/clearance ground samples within the same height tolerance and requires upward normals above 0.999. The final successful `placement.valid` assertions exercise that ground-height check as well as exact horizontal snapping. No full-vector equality or relaxed footprint rule is used. Existing valid and protected-access preview captures are retained. Their synthetic protected-access case does **not** verify or close the separately reported protected-access placement complaint.

The paid breach fixture uses the normal **90-second scenario clock**. The corrected wait is remaining time to `first_wave_time` plus two simulated seconds, instead of a fixed 70-second wait after assembly. In the final headless log, three normally produced Rifles assemble at 18.150 seconds; a real breach begins at 90.617 and navigation-ready resumption occurs at 106.617. The three jobs spend exactly **300 credits**. Ordinary Rifle damage removes the actual **700 HP** gate; all applied damage belongs to the paid deployed wave. Surviving actors receive the exact retained HQ objective and physically cross the destroyed-gate opening. Both display modes pass. The separately labelled inaccessible negative fixture proves bounded waiting only; it is not the reachable-breach evidence.

The earned integration uses actual finite-cache deliveries, an ordinary paid Depot and Collector, three Walls and one Gate. The [headless ledger](../validation-output/m8/m16-final-matrix-01/artifacts/headless-fortification_integration_checks/m16/earned-ledger.json) records **1000 + 600 deposited - 1050 spent = 550 credits**, with 625 loaded, 25 still carried and 1375 supply remaining. Its Collector physically detours around the closed line, crosses the open doorway and encounters restored closure. The [graphical ledger](../validation-output/m8/m16-final-matrix-01/artifacts/graphical-fortification_integration_checks/m16/earned-ledger.json) preserves its own actual timing-dependent deposits and balance. The explicit earned fixture delays first wave/sortie to 600 seconds; normal playable values remain 90/120. UI and lifecycle fixtures disclose their 6000-credit setup and paused opponents; direct HQ damage is only a result/Restart trigger, not earned combat evidence.

### Original acceptance statuses

| # | Requirement | Status |
| --- | --- | --- |
| 1 | Builder-built walls/gates with valid connections | PASS — paid construction, both axes, exact joins, real builder travel/work, rejection, pause/resume and refunds in both modes |
| 2 | Safe owner-controlled gate operation | PASS — ownership, both-team passage, supports, no-power operation, occupied/pending close and stale requests in both modes |
| 3 | Correct collision and synchronized ground navigation | PASS — actual paths and physical movement, precision checks, pending departure/deletion and preserved neighboring blockers |
| 4 | Damage, world blocking and usable destruction breaches | PASS — ordinary Rifle/Rocket damage, blocking, open-door shots, exactly-once projectile contact and retained aircraft separation |
| 5 | Bounded enemy single-barrier breach and resumed attack | PASS — paid normal 90-second wave destroys the gate and physically resumes after navigation readiness in both modes |
| 6 | Lifecycle, match freeze and Restart | PASS — pending transitions, departure, earned Collector traversal, command freeze and automated viewport Restart |
| 7 | Preserved economy, air/ground gameplay and readable HUD | NOT VERIFIED — construction preview compatibility is now verified and M16 integration/UI pass, but ordinary graphical `choke_50` group arrival/traversal/settling fails with UNKNOWN attribution |
| 8 | Accurate focused and regression validation | PASS — complete original matrix and exits, all failures, bounded preview diagnosis/correction, source-matched reuse and final static checks are saved; this does not mean all regression executions passed |

### Preserved failures and supported explanations

Every original phase retains its own source manifest, plan, results and failed logs under `validation-output/m8/`. The [handoff checks](../validation-output/m16/final-handoff-checks.json) enumerate every execution and exit, with source differences per phase. No older failed result is replaced by a later pass. Counts below exclude each successful import; all failed execution records have exit 1 and successful records exit 0. The phase outcome follows the existing runner's aggregate rule.

| Retained phase | Completed / planned | Passing | Checks | Assertions failed | Native error/warning lines | Phase exit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `m16-smoke-01` | 1 / 1 | 1 | 314 | 0 | 0 | 0 |
| `m16-focused-01` | 8 / 8 | 0 | 701 | 14 | 10 | 1 |
| `m16-focused-02` | 10 / 10 | 2 | 928 | 14 | 2 | 1 |
| `m16-focused-03` | 10 / 10 | 6 | 1006 | 4 | 2 | 1 |
| `m16-navigation-breach-diagnostic-01` | 2 / 2 | 1 | 177 | 1 | 1 | 1 |
| `m16-focused-final-01` | 12 / 12 | 10 | 883 | 0 | 4 | 1 |
| `m16-focused-recovery-01` | 6 / 6 | 2 | 459 | 4 | 10 | 1 |
| `m16-focused-recovery-02` | 4 / 4 | 4 | 637 | 0 | 0 | 0 |
| `m16-final-matrix-01` | 102 / 102 | 99 | 12829 | 5 | 3 | 1 |
| `m16-preview-diagnostic-01` | 1 / 1 | 0 | 267 | 1 | 0 | 1 |
| `m16-preview-correction-01` | 2 / 2 | 2 | 545 | 0 | 0 | 0 |

- **Initial M16 feature/lifecycle failures:** `focused-01` includes the barrier departure timeout, followed by passing membership cleanup in the settled source. Its invalid vertical-wall placement collided with the existing demonstration barrier; the fixture was moved to (-25,17), preserving authored footprints and placement rules. The [validation notes](../validation-output/m16/validation-worker-notes.md) retain the fixture explanation. The final direct pending-deletion/departure checks pass; no diagnosis was reopened during collection.
- **Combat harness and bounded breach corrections:** `focused-01` sampled a cooldown-cleared `last_fire_line`, causing nil `is_clear` errors, and performed aircraft clearance outside the physics frame. The settled tests capture the firing trace synchronously and query in physics. `focused-02` breach failures preceded waiting for initial navigation membership and moving disclosed staging to (24,22), clear of the Barracks corner. The [saved checkpoint](../validation-output/m16/breach-worker-checkpoint.json) also preserves the settled stable-engagement and world-collider tie-priority corrections. Later source-matched normal combat and paid breach checks pass; no free actors or forced gate damage were substituted.
- **Integration/UI fixture errors:** `focused-01` looked for gate obstruction text outside its actual visible `gate_state_label`. `focused-02` incorrectly expected low-level `move_to` to reject immediately; the corrected fixture instead measures real closed-line detours, collider/map obstruction and physical open-door travel. The pending-wall setup's builder occupied clearance; it now moves normally to (-22,20) first. Movement arrival requirements are retained.
- **Navigation precision:** `focused-02`, `focused-03` and the diagnostic phase preserve the real 42-edge synchronization warning and resulting failed no-warning assertions. The measured partition-edge correction and final connected/distinct-polygon checks above verify the correction without suppressing warnings.
- **Scenario timing:** both `focused-03` breach executions expired before the normal 90-second launch. The scenario-clock wait correction above passes the actual paid destruction/resumption case; the configured launch time was not shortened.
- **Late harness failures:** `focused-final-01` has two zero-check script-load failures from Variant inference. `focused-recovery-01` has two zero-check script-load failures from calling `any` on a packed array, plus two preview assertions failing per display mode from exact full-vector comparison with ray-derived ground Y. Explicit typing, conversion and exact X/Z checks resolved these in the already completed 637-check recovery; native failures are not described as zero-failure passes.
- **M16 feature failures at collection:** none in the ten final fortification executions. Earlier feature/harness failures above remain retained.
- **Demonstrated new regressions:** none established from the collected evidence. This is not a clean regression claim.
- **Construction fixture disposition:** the first ordinary failure is [headless construction](../validation-output/m8/m16-final-matrix-01/headless-construction_checks.log), followed by the same assertion in [graphical construction](../validation-output/m8/m16-final-matrix-01/graphical-construction_checks.log). The exact bounded diagnosis above establishes the invalid fixed-frame preview-readiness assumption; corrected checks verify real authorization and fresh occupied rejection in both modes. This is a fixture correction, not a repaired production defect or an accepted exception.
- **Unknown attribution:** [graphical movement stress](../validation-output/m8/m16-final-matrix-01/graphical-movement_stress_checks.log) fails `choke_50` all-unit arrival, full gate traversal and three-second settling/separation. Units **8, 12 and 40** are reported FAILED after **eight recoveries each**, respectively at `(-3.330001,0,-0.760075)`, `(-2.85,0,-1.691828)` and `(-2.85,0,1.62123)`. The headless counterpart passes, but does not invalidate this failed graphical execution. Its relationship to M16 changes or earlier movement findings is not established. It is not relabelled historical or accepted, and no full ground-movement compatibility claim is made.

### Tested-source correspondence and screenshots

The matrix's [revision](../validation-output/m8/m16-final-matrix-01/revision.txt) is `b7c65ecee829bc81e93e58a5240dca2a4d5b4744` plus the exact five-file [starting patch](../validation-output/m8/m16-final-matrix-01/starting-diff.patch). On first recovery, HEAD was already `a808bf6` and **all 388 manifest files matched byte for byte, with no extra source files**. The changed commit identifier does not invalidate matching bytes. This lead made no commit. The [manifest](../validation-output/m8/m16-final-matrix-01/source-hashes.json) hashes runtime, resources, scenes, tests, tools and configuration; the retained `project/` is the tested copy. At original matrix completion, differences were exactly the three handoff documents.

Final source differs from that original matrix only in those documents and **`tests/construction_checks.gd`**. Runtime, resources, scenes, tools, configuration and all other tests still match. The changed `_placement_checks()` method is called only by the construction suite's placement branch; shared inherited helper methods and other suites' entry points are unchanged. The [corrected 388-file manifest](../validation-output/m8/m16-preview-correction-01/source-hashes.json) and retained snapshot cover that exact final test source. Only handoff documents change after the corrected run. The original 100 non-construction executions are therefore retained as source-matched evidence, including the failed movement run; the two corrected construction executions provide the affected coverage. No combined clean-matrix total is claimed.

Existing M16 captures and their inspections are reused. The two targeted construction runs above are the only additional engine phases; their ordinary screenshot writes are retained separately and do not represent a new M16 visual review or human playtest. Current-source M16 images are under:

`validation-output/m8/m16-final-matrix-01/artifacts/graphical-fortification_ui_checks/m16/screenshots/`

The earlier corrected, inspected captures remain under:

`validation-output/m8/m16-focused-recovery-02/artifacts/graphical-fortification_ui_checks/m16/screenshots/`

The exact filename pairs below exist at **1280×720 and 1920×1080**; append `_1280x720.png` or `_1920x1080.png` to each stem:

| Captured state | Filename stem |
| --- | --- |
| Original builder / expanded Help | `fortification_normal_builder`, `fortification_normal_builder_help` |
| Valid exact-grid Wall preview / protected-access rejection | `fortification_valid_wall_preview`, `fortification_protected_wall_preview` |
| Paid closed gate / expanded Help | `fortification_paid_closed_gate`, `fortification_paid_closed_gate_help` |
| Paid open gate / expanded Help | `fortification_paid_open_gate`, `fortification_paid_open_gate_help` |
| Result / restored opening after Restart | `fortification_result`, `fortification_normal_restart` |

Occupied close is additionally saved as `fortification_gate_obstructed_1280x720.png`. The handoff checks list exact paths, PNG dimensions and SHA-256 for **22 retained PNGs** in the matrix UI artifact directory: these 21 UI captures plus `fortification_earned_collector_passage_1280x720.png`, retained from the preceding earned integration. Existing inspection evidence is reused rather than represented as a new review. Passing synthetic protected-access preview/layout assertions do not establish that the separate placement complaint's actual case was fixed.

The corrected construction suite also retains its ordinary `construction_valid_preview.png`, `construction_selected_site.png` and `construction_two_operational.png` under `validation-output/m8/m16-preview-correction-01/artifacts/graphical-construction_checks/`, at its existing **1280×800** resolution. These are separate from the reused 1280×720 and 1920×1080 M16 UI inspections.

Final checks pass: **123 documentation links/anchors; `git diff --check` exit 0; all eleven retained snapshots match their manifests; zero uncovered source differences**. The explicit construction-test replacement coverage and final document hashes are saved in [final-handoff-checks.json](../validation-output/m16/final-handoff-checks.json). Runtime, resources, scenes, tools and configuration match the original matrix, and the corrected test matches the passing targeted snapshot. These static passes do not turn the original failed matrix into a pass.

## Retained findings and limits

**Accepted historical interface exception:** the [M12 interface exception](milestone-12.md#owner-authorized-interface-exception--2026-09-09) stays **OPEN / UNKNOWN**, with historical criterion 7 **NOT VERIFIED**. It applies only to the original group-3 occurrence; neither the construction fixture correction nor the new graphical movement failure uses that exception.

**Deferred movement findings:** [the saved findings](movement-issue-records.md) remain unresolved, including historical cases retained by earlier milestones. Current passing observations do not repair or close those records; their investigations are not reopened. The new graphical `choke_50` failure retains its own UNKNOWN attribution. The outstanding M16 acceptance requirement is **group 7's preservation of ordinary ground group arrival, traversal and stable settling**; it has no new owner-approved exception.

Single-piece placement, one unfinished site, manual gates, both-owner passage when open, no completed selling/refunds or repairs, and no general multilayer siege planner are deliberate limits. The separate protected-access placement complaint remains unverified fixed. There are no wall chains, automatic perimeters/gates, upgrades, firing platforms, new units, superweapons or engine/dependency changes. No human keyboard-and-mouse playtest is claimed. This collection leaves its documentation and test-fixture edits uncommitted and untagged and preserves existing commits and unrelated work.
