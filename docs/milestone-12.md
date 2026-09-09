# Milestone 12 — Bulldozers and builder-driven construction

**Milestone 12: accepted for continued feature development with a documented interface exception.** Owner-authorized acceptance decision recorded 2026-09-09; the development gate is closed. **Technical verification: acceptance criterion 7 remains NOT VERIFIED.** The bounded control-group compatibility continuation is finished. Current targeted interface checks pass, but the original graphical failure does not record cumulative selection before Ctrl+3, stored membership, or restored IDs. Its earliest unverified stage is valid accumulated selection before assignment; no production defect or invalid fixture assumption is established. Passing observations do not reconstruct that missing state. Full movement-regression acceptance also remains unpassed, separately under the existing deferral. Milestone 12 retains its existing identifier. Power generation is next as Milestone 13; it is not implemented or begun.

## Owner-authorized interface exception — 2026-09-09

The owner explicitly authorizes continued feature development despite the unattributed historical **group 3 assignment/recall failure**. This project acceptance decision supersedes the requirement to establish and correct that occurrence's original mechanism before proceeding beyond Milestone 12. It does not repair or close the [open interface issue](movement-issue-records.md#m12--historical-group-3-assignmentrecall-failure-open), or change criterion 7 to PASS. The original failure and its unknown cause remain valid evidence.

The exception applies only to that historical interface occurrence. It does not permit removing or weakening control-group tests, ignoring a demonstrated new interface regression, bypassing ownership, selection or keyboard-focus requirements, accepting unrelated failures automatically, or claiming complete movement or historical regression acceptance. The **1,030 passing compatibility checks across six source-matched executions** are current tested evidence, not proof of repair. The separately recorded targeted and final UI phases below retain their own counts and source provenance; this decision adds no runtime validation.

All builder results, failed executions, diagnostics, test assertions and new failure-only snapshots remain preserved. The movement findings remain separately deferred and unresolved. **No human keyboard-and-mouse playtest has occurred.** Revisit the open interface issue when normal play or relevant testing supplies actionable evidence, or when a change to the affected interface requires investigating a reproduced failure. No historical replay, diagnostic campaign or broad review is launched for this closeout.

This closeout changes only this report, the roadmap, the existing issue record and README milestone status. It implements no gameplay or power generation, launches no Godot execution, changes no engine, creates no commit or tag, and discards no unrelated work. Only documentation-link and whitespace checks are run; earlier validation artifacts remain historical records of their own runs and decisions.

Closeout documentation checks: **125 local links, including 15 anchors, pass** across the four updated documents; scoped **`git diff --check` exits 0**. These are documentation results only, separate from every saved Godot validation phase.

**Next feature: Milestone 13 — Power generation**, with planned report path `docs/milestone-13.md`, as recorded in the [roadmap](roadmap.md#next-feature--milestone-13-power-generation). HQ produces Bulldozers; Bulldozers construct buildings, including the upcoming Power Plant; Supply Depots produce Supply Trucks/Collectors; Collectors harvest and deliver supplies. Milestone 13 implementation is outside this documentation-only closeout.

## Playable scene and controls

[Builder Assault](../scenes/builder_assault.tscn) is the intended builder-based player experience. Open it in the installed Godot **4.7.2.stable.official.ed1daf0bf** and press F6, or run:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/builder_assault.tscn
```

The player starts with one HQ, one selected Bulldozer, three existing Rifle units, **1000 credits**, finite western supplies, no production buildings and no collectors. Enemy buildings, two enemy collectors, starting funds and repeat-wave behavior are inherited unchanged from Economy Assault. Stable starting enemy unit IDs remain 9 and 10; subsequent production begins above 10.

Select exactly one owned Bulldozer, choose **Build Supply Depot**, **Build Barracks** or **Build Vehicle Factory**, and left-click a valid preview. Right-click or Escape cancels the free preview, preserving the earlier order. An accepted placement replaces that order. Right-click ground or use **X Stop** to release the builder and pause the paid site. Right-click an owned unclaimed unfinished site with one selected Bulldozer to resume. Select the site and use **Cancel construction** to remove it and refund its original payment once. Select HQ to train another Bulldozer, or a completed Depot to train a Collector. Select a Collector and right-click supplies to harvest. Combat right-click and Q Attack Move, minimap commands, groups 1–9 and Help remain available.

The funded opening is **Depot 300 + Collector 200 = 500 credits**, leaving 500 of the unchanged initial 1000. The normal gameplay sequence is builder → Depot → paid Collector → real harvesting → Barracks/Factory → paid army → combat. HQ drop-off compatibility remains.

## Configuration and construction authority

| Setting | Default |
| --- | --- |
| Bulldozer production | 500 credits / 6 simulated seconds / existing five-slot queue |
| Bulldozer health / speed | 200 HP / 3.5 units per second |
| Bulldozer collision and recovery | Inherited RTSUnit capsule, crowd settings and bounded recovery |
| Work position / arrival tolerance | 1.3 units outside the footprint face / 0.3 units |
| Supply Depot | Existing 300 credits / 10 working seconds / 450 completed HP |
| Barracks | Existing 400 credits / 10 working seconds / 450 completed HP |
| Vehicle Factory | Existing 600 credits / 15 working seconds / 450 completed HP |
| Collector | Existing 200 credits / 6 simulated seconds; harvesting defaults unchanged |
| Unfinished-site limit | Existing one-site limit, including paused sites and pending cleanup |

The original primitive Bulldozer is an ordinary registered, selectable, damageable RTSUnit subclass. It has no weapon, retaliation, harvesting, cargo or Attack Move coordinator. HQ production uses UnitProduction payment, FIFO queue, cancellation, safe capsule spawn and ground rally. Produced builders start with no assignment. No movement/projection/recovery algorithm or existing unit default is changed.

`builder_construction_enabled` opts the new scene into builder authority. `BuildingConstruction` still owns authoritative validation, exact payment, stable site identity, original paid cost, construction duration and serialized navigation updates. UI selection only authorizes new placement/resume commands; ongoing construction checks live field/owner/registration and assignment state independently of UI selection. One site has one weak builder reference and one builder holds one site ID.

Placement preserves full footprint, ground, occupied-unit, access-corridor and exit checks. It additionally plans from eight bounded positions outside the footprint using ordinary navigable paths, capsule clearance and an unobstructed segment to the outside face. After committing geometry, the final approach is planned and dispatched once after navigation readiness. Travel uses the unchanged movement deadline and retry budget. A failed or newly obstructed approach releases the assignment and leaves a paid paused site; no automatic retry order resets recovery.

States are **Preparing site**, **Builder travelling**, **Constructing**, **Paused — needs builder** (with failure details where applicable), and **Complete**. Only an alive registered same-owner builder at its valid work point, with the captured movement order and clear actual capsule/interaction segment, advances time in the active match. Travelling, stopped, obstructed, missing and out-of-position builders earn no progress. Selecting another object does not pause an otherwise valid worker.

Move, Stop, death, immediate/deferred removal, ownership invalidation and departure release work without resetting progress or refunding the building. Same-field builder reparenting keeps its ordinary stable identity/registration, but its departure releases construction; select it and resume explicitly. Building same-field reparenting retains the existing site identity. No completed-building repair, selling or HQ reconstruction is added. Unfinished sites retain their previous invulnerability/refund policy; completed buildings retain normal assault damageability.

Completion first commits operational state and clears the unfinished slot, then releases the builder. Cancellation first commits cancellation/refund and removes collision/registration, then stops obsolete work and restores navigation. Claim references and IDs are cleared before notification callbacks; approach generations and captured order versions protect replacement commands. Match freeze clears builder claims and stops time. Restart closes old site/navigation managers, queues, weak references and listeners and reloads this scene.

Earlier construction, base-assault, combined-arms, economy and supply-depot scenes retain explicit **legacy prototype HQ-based automatic construction and HQ deposits**. F5 still launches the original main scene. No enemy builder strategy, power, defenses, new combat units, aircraft, walls or superweapons are included.

## Acceptance

| Original requested group | Final status and evidence |
| --- | --- |
| 1. HQ builder production and capability separation | **PASS.** Normal paid HQ queue, safe deployment/rally, stable identity, unarmed/nonharvesting capability and Collector/Depot separation; builder production case passes both modes. |
| 2. Builder-selected placement and exact payment | **PASS.** Exactly one owned builder authorizes placement; invalid/free previews preserve orders and money, committed sites charge once. Placement/UI cases pass both modes. |
| 3. Travel-gated construction progress | **PASS.** Ordinary physical approach, full working duration, actual capsule/access eligibility and zero travel/blocked progress. Bounded failed approach pauses safely; work/blocked cases pass. No universal reachability claim. |
| 4. Pause, reassignment and preserved progress | **PASS.** Move/Stop/death/departure pause; normally paid HQ replacement travels to resume the same paid site, with preserved elapsed work and no second building charge. Replacement/claims/lifecycle cases pass. |
| 5. Completion, cancellation and lifecycle safety | **PASS.** Original-price single refund, completion boundary, synchronous replacement callbacks, weak claims, reparenting, match freeze and Restart pass. |
| 6. Real builder-to-depot-to-economy-to-army gameplay | **PASS for the earned opening and commandable army.** Real Depot/Collector/harvesting/Factory/Rocket chain, physical vehicle arrival and accepted Attack Move; exact ledger below. The builder-opening harness does not wait for enemy damage or victory; it is not evidence for an uninterrupted builder-scene combat campaign. |
| 7. Legacy scenes and existing interface | **NOT VERIFIED — historical verification gap remains open.** Legacy construction, production, economy, combat, HUD, tactical and groups suites pass, but original graphical paid-army group assignment/recall failed before Attack Move dispatch. Its cause remains unknown after passing focused observations; clean existing-interface compatibility cannot be claimed. The owner accepts continued development under the scoped interface exception above; this is not an unconditional PASS. |
| 8. Accurate validation and failure reporting | **PASS.** Completed original matrix, every failed phase, bounded diagnostic/reruns, source correspondence, retained rendered evidence and documentation/whitespace results are recorded below. |

Builder-specific matrix executions pass **305 headless / 314 graphical** checks and earned integration passes **45 / 46**: **710 passing checks in four executions**, included in the matrix total. The source-matched earlier focused phase passes six executions / 974 checks (builder, earned integration and tactical interface); those are prior observations, not extra matrix checks.

The earned ledger is **1000 starting + 400 deposited − 1350 paid = 50 credits**. Spending is Depot 300 + Collector 200 + Factory 600 + Rocket Vehicle 250. Four real 100-credit deliveries go to the completed Depot; finite cache remainder is 1600 and cargo ends at zero. The same initial builder physically completes both buildings; no wallet/cargo grants, free actors, teleportation or injected construction progress fund this sequence. Only the fixture's first enemy wave is delayed to 600 simulated seconds; the shipped scene's enemy timing remains unchanged. Separate compatibility suites cover combat and results, with the UI qualification in group 7.

## Validation and preserved failures

One lead agent collected and triaged the saved work. The working tree started clean at existing commit `4c1174a1736b82372ee36814dc6271e78b3e81ca`; no applicable AGENTS.md files were present. That collection changed only this report, README, roadmap and `tests/attack_move_ui_checks.gd`. This continuation began with those four files already modified, preserved them in the before-run snapshot, and additionally extends only `tests/builder_checks.gd`. No applicable AGENTS.md was found in the repository or its directory ancestors. One lead agent performed this continuation, without subagents. No gameplay source changes, new reviewers, duplicate matrix, historical movement investigation, engine upgrade, dependency installation, commit, tag or discarded work occurred. Tests use the existing fresh-copy/source-hashing runner, fixed 60 simulated FPS and external 240-second timeout. Headless and graphical runs are serialized. Automated input/capture inspection is not human playtesting; **no human playtest occurred**.

- [m12-import-smoke-01 failed construction log](../validation-output/m8/m12-import-smoke-01/headless-construction_checks.log): fresh import passed, but construction exposed the introduced eager-resource/script cycle (187 checks, one failed logger assertion, 99 native error lines, exit 1). The saved implementation already corrects default Barracks initialization from eager preload to runtime load; resource values are unchanged.
- [m12-import-smoke-02 summary](../validation-output/m8/m12-import-smoke-02/summary.json): fresh import and all 267 headless construction checks pass, zero errors, exit 0.
- [m12-focused-01 failed builder log](../validation-output/m8/m12-focused-01/headless-builder_checks.log): two impossible sibling-class type checks prevented parsing (zero checks/reported assertions, three native error lines, exit 1). The existing harness correction preserves capability separation checks.
- `m12-focused-02`: four executions, two passing, 666 checks / two failed logger assertions / four native error lines, phase exit 1. [Headless](../validation-output/m8/m12-focused-02/headless-builder_checks.log) and [graphical](../validation-output/m8/m12-focused-02/graphical-builder_checks.log) builder executions each triggered typed `Array[CollectorTruck].has(Bulldozer)` errors. Existing final source compares instance identities within the typed array instead; the nonmembership assertion remains. This phase also predates a `building_placement.gd` edit and is not reused as final runtime validation.
- [m12-focused-03 summary](../validation-output/m8/m12-focused-03/summary.json): fresh import, six of six executions pass, 974 checks, zero failures/native errors, exit 0. Builder 305/314, integration 45/46, tactical 126/138; runtime source matches the final matrix and current source.

All phase commands, logs, errors and source copies remain under [validation-output/m8](../validation-output/m8), including all seven failed test executions across the eight M12 phases. Across those phases there are **84 test executions, 77 passing, 11,193 reported checks, 17 reported assertion failures and 115 native error lines**; eight successful imports are separate. These are cumulative historical observations, not unique acceptance coverage. A parse failure can report zero checks and still fail the execution.

## Original final matrix — completed, results preserved

The existing process **finished normally under its wrapper**, without interruption or timeout. [Wrapper log](../validation-output/m12/final-matrix-01-wrapper.log), [plan](../validation-output/m8/m12-final-matrix-01/plan.json), [results](../validation-output/m8/m12-final-matrix-01/results.json) and [final summary](../validation-output/m8/m12-final-matrix-01/summary.json) agree: successful fresh import, all 68 planned test executions complete, **65 passing, 8,814 checks, 14 failures, nine native error lines, MATRIX_EXIT 1**, in **1172.103 seconds** including import. The wrapper ended at approximately 2026-09-09 03:34:08 UTC; collection found no live matrix/Godot process. No missing checks or resumed matrix runs were needed. The response-stream disconnect did not stop local validation.

The existing `tools/validate-m12.ps1 -RunName m12-final-matrix-01` expands to 33 suite names plus gate avoidance in each mode. Exact child shell commands, wrapper calls, engine arguments, timestamps and exits are in the linked results and sibling `<label>.ps1` files. All runs use installed Godot **4.7.2.stable.official.ed1daf0bf**; graphical commands omit `--headless`.

| Original scope | Completed | Passing | Checks | Failures | Native error lines |
| --- | --- | --- | --- | --- | --- |
| Headless | 34 / 34 | 33 | 4363 | 5 | 5 |
| Graphical | 34 / 34 | 32 | 4451 | 9 | 4 |
| Total tests | 68 / 68 | 65 | 8814 | 14 | 9 |

Each cell below is **checks / failures**. Every successful execution exits 0; the three failed executions exit 1. Import is excluded from test counts.

| Suite | Headless | Graphical |
| --- | --- | --- |
| builder_checks | 305 / 0 | 314 / 0 |
| builder_integration_checks | 45 / 0 | 46 / 0 |
| supply_depot_checks | 272 / 0 | 284 / 0 |
| supply_depot_integration_checks | 80 / 0 | 81 / 0 |
| enemy_economy_checks | 96 / 0 | 98 / 0 |
| enemy_economy_integration_checks | 33 / 0 | 34 / 0 |
| attack_move_checks | 124 / 0 | 124 / 0 |
| attack_move_batch_checks | 155 / 0 | 155 / 0 |
| attack_move_ui_checks | 91 / 0 | 88 / 7 |
| hud_clarity_checks | 197 / 0 | 209 / 0 |
| milestone_checks | 127 / 0 | 131 / 0 |
| movement_repair_checks | 82 / 0 | 82 / 0 |
| parked_deadlock_checks | 14 / 0 | 14 / 0 |
| parked_deadlock_controls | 84 / 0 | 84 / 0 |
| captured_parked_cluster_checks | 10 / 0 | 10 / 0 |
| projection_step_checks | 32 / 0 | 32 / 0 |
| boundary_neighbor_checks | 23 / 0 | 23 / 0 |
| boundary_neighbor_controls | 193 / 0 | 193 / 0 |
| gate_movement_checks | 14 / 0 | 14 / 0 |
| gate_movement_checks-avoidance | 39 / 0 | 39 / 0 |
| construction_checks | 267 / 0 | 270 / 0 |
| construction_cleanup_checks | 46 / 0 | 46 / 0 |
| harvesting_checks | 298 / 0 | 299 / 0 |
| production_checks | 192 / 0 | 193 / 0 |
| combat_checks | 183 / 0 | 191 / 0 |
| combat_repair_checks | 230 / 0 | 230 / 0 |
| line_of_fire_checks | 305 / 0 | 308 / 0 |
| spherical_projectile_checks | 140 / 0 | 141 / 0 |
| movement_stress_checks | 122 / 5 | 131 / 2 |
| base_assault_checks | 124 / 0 | 130 / 0 |
| vehicle_production_checks | 225 / 0 | 230 / 0 |
| combat_load | 7 / 0 | 7 / 0 |
| tactical_interface_checks | 126 / 0 | 138 / 0 |
| control_group_checks | 82 / 0 | 82 / 0 |

## Attack Move UI finding and bounded follow-up

**Technical disposition: OPEN; original cause UNKNOWN; criterion 7 NOT VERIFIED.** The owner-authorized interface exception permits continued feature development without closing this finding. No supported gameplay repair or invalid original input assumption was found. The current test changes improve failure localization and add compatibility coverage; they are not a repair of the original occurrence.

### Exact original failure and sequence

The [original graphical log](../validation-output/m8/m12-final-matrix-01/graphical-attack_move_ui_checks.log) and [tested fixture](../validation-output/m8/m12-final-matrix-01/project/tests/attack_move_ui_checks.gd) identify `_am_ui_integration`, **group 3**, and the first failed assertion at original line **307**: `normal viewport group assignment and recall selects both produced types with existing Rifle escorts`. The assertion combines selected-array equality with filtered group membership equality. At least one was false; the original log records neither array. Acceptance criterion 7 is not a keyboard group number.

Expected selected and stored IDs are **[9, 10, 1, 2, 3]**, in that order: paid Rifle #9, paid Rocket #10, starting Rifle escorts #1–3. Observed original IDs: each individual click assertion proves that its just-clicked unit is selected and passes ordinary live/owned/registered selection pruning. The accumulated array, stored IDs after assignment, and actual restored array are **not recorded**. Zero later damage and missing slot keys cannot identify which group stage failed.

The original whole-suite predecessors were:

1. `input` (25/0 graphical): viewport selection, contextual Attack Move, actual 720p/1080p resize/capture, terrain/minimap dispatch and cancellation, X Stop.
2. `context` (20/0): GUI-consumed Q, simulated selection focus-out/in, Collector rejection, placement/Escape, a modal opened then hidden/freed, group 3 recall preserving an existing parent, Help open/body click/Close Help, F1, first Escape closing Help, second Escape cancelling targeting, and cancelled queued confirmation.
3. `lifecycle` (12/0): result freeze, viewport Restart, fresh coordinator/selection/minimap state. Integration then creates another fresh Combined Arms scene.
4. Integration configures 2000 credits and 600-second first assault; moves escorts through the minimap; builds ordinary Factory/Barracks; sets real staging rallies; selects producers and clicks Train; pays 1350, leaving 650. Its bounded state predicate confirms all five actors stopped in ARRIVED at staging. It centers the camera, waits the existing two frames, clicks #9 without Shift, then Shift-clicks #10, #1, #2, #3, with the existing two-frame click helper. All five individual checks pass. `_tactical_key(3, true)` pushes number-3 press/release with `ctrl_pressed=true`, then waits two frames. Public `select_building(factory)` clears unit context; `_tactical_key(3)` pushes number-3 press/release with Ctrl false, then waits two frames. The combined assertion fails.

The next original action is a **contextual Attack Move button click**, not Q. Its arming and minimap dispatch assertions fail, followed by real damage, arrival and per-produced-unit resumed-travel witnesses. Missing dictionary keys at original lines 338/341 cause two native errors and abort the rest of integration; the logger assertion makes seven failures total. This occurrence never establishes an accepted attack-move command. No pathfinding, avoidance, pursuit or recovery investigation is justified by it.

Help/modal/placement and pending targeting are explicitly closed or disposed in the preceding cases; integration creates a new scene and uses public construction APIs rather than placement UI. This supports the intended setup, but **there is no original point-of-failure observation of application focus, GUI focus, modifiers or input modes**. No builder exists in this legacy fixture. These facts do not prove that a builder regression, focus interruption, or invalid input sequence caused the failure.

### Stage-by-stage evidence

| Stage | Original occurrence | Current focused evidence |
| --- | --- | --- |
| Valid accumulated selection | Each last-clicked actor passes; full accumulated IDs absent. **Earliest unverified stage**, including whether #9 remains after Shift-clicking #10. | Exact prefix checked after every click; final ordered array, live ownership and empty pending-pick queue checked before Ctrl+3. |
| Ctrl+3 input | Helper specifies number press/release with Ctrl true; original delivery/consumption unobserved. | Original helper retained. Separate mixed-group case additionally sends explicit Ctrl down, 3 down/up, Ctrl up. |
| Stored membership | No post-assignment observation before selecting Factory. | Raw stored stable IDs and normal eligibility-filtered members both equal expected IDs before context change. |
| Modifier release | Original helper releases 3 with Ctrl true, then recall event carries Ctrl false; it does not synthesize a separate Ctrl-key event. | Original per-event route passes. Additional explicit-release route and release-only no-op pass; all modifier releases are sent even if its assignment assertion fails. |
| Number recall / eligibility | Composite failure cannot separate missing assignment, consumed recall or ineligible members. | Exact returned members/selection pass. Existing control-group tests cover ownership, death, queued ancestors, removal, weak identity and ID reuse. |
| Actual restored selection | Not recorded independently of membership. | All mobile selection indicators match expected membership, building context clears, and five-unit HUD appears. |
| Subsequent Attack Move / Q | Original HUD arming fails; no accepted command is established. | Original HUD/minimap paid integration passes real engagement and travel. Separate recalled Collector/Rifle and builder-to-army tests verify Q filtering. |

The [94-check diagnostic](../validation-output/m8/m12-ui-diagnostic-01/results.json) differs from original source only by event-boundary logging; it adds no assertions, waiting, fixture changes or gameplay changes. Its [source](../validation-output/m8/m12-ui-diagnostic-01/project/tests/attack_move_ui_checks.gd) records expected accumulated IDs, stored/returned membership, enabled/focused groups, no GUI focus or placement and correct HUD transitions. The [94-headless/97-graphical handoff](../validation-output/m8/m12-ui-handoff-01/results.json) then adds three assertions: exact accumulated selection, exact stored eligible membership, and complete accepted command slots; missing slots return after a failed assertion instead of cascading dictionary errors. Engine, shared helpers, creation, selection, timing and runtime remain unchanged. The successful original graphical path would have 94 checks, while its failed/aborted path reported 88. Thus the count differences reflect instrumentation/assertions and previously unexecuted downstream checks, not evidence of a gameplay fix.

### Bounded current work and results

First, before editing, [m12-ui-compatibility-before-01](../validation-output/m8/m12-ui-compatibility-before-01/results.json) ran the **entire current graphical UI suite**, retaining every original predecessor and the original paid production/selection/key sequence. Fresh import and **97 checks pass**, with [the inherited observations](../validation-output/m8/m12-ui-compatibility-before-01/graphical-attack_move_ui_checks.log) showing selection/group IDs [9,10,1,2,3], enabled/focused groups, no GUI focus/placement, 100 Rifle damage, 32 Rocket damage, three deaths and individual resumed travel. This is an observation, not attribution of the original failure.

`tests/attack_move_ui_checks.gd` now replaces unconditional state logging with a small **failure-only** group snapshot. It includes the checked operation and synthetic modifier flags, expected/selected/stored IDs, filtered members, ownership/liveness/field eligibility, visible selection indicators, global Input modifier state, application/GUI focus, modal/Help/placement/targeting flags and pending picks. `Viewport.push_input` events and global `Input` state are kept distinct; synthetic viewport testing is not native keyboard playtesting. No continuous recording or unrelated frame collection was added.

The original sequence, shared input helpers, two-frame waits, movement predicates/budgets and all original integration assertions remain. Prefix, storage and visible-selection assertions return from an already-failed integration stage rather than inventing selection or dispatching unsupported downstream commands. There was no demonstrated timing defect, so no longer sleep, readiness workaround, private selection write, production patch, or capability restriction was introduced.

A separate `groups` case **after** the original four UI cases checks normal viewport Collector/Rifle selection, explicit modifier release, release-only no-op, exact group storage/recall/visible selection, focused-key consumption, Q accepting only the Rifle while preserving Collector membership/order, and X Stop. The existing builder UI case now additionally checks builder preview cancellation → army viewport selection → Ctrl+3 storage → builder selection/preview/Help → two Escapes → 3 recall → visible army/context and Q. Existing builder-only grouping and builder/combat Q filtering remain intact.

The [targeted phase](../validation-output/m8/m12-ui-compatibility-targeted-01/results.json) passes fresh import and all six executions: **1030 checks, zero failures/native errors, exit 0**, 79.090 seconds. A small new-harness correction ensures synthetic Ctrl/3 releases occur even on assignment assertion failure. It does not change the successful path and does not explain the original occurrence. The [final affected UI phase](../validation-output/m8/m12-ui-compatibility-final-01/results.json) reruns both UI modes on that exact final test source: fresh import, **229 checks, zero failures/native errors, exit 0**, 27.979 seconds. No further test retries were made.

| Final targeted coverage | Headless checks / failures | Graphical checks / failures | Source phase |
| --- | --- | --- | --- |
| Original Attack Move UI sequences plus group compatibility | 113 / 0 | 116 / 0 | compatibility-final-01 |
| Control groups, consumed/repeated/modifier keys, ownership/lifecycle, X, result/Restart | 82 / 0 | 82 / 0 | compatibility-targeted-01 |
| Builder suite, including builder-to-army/group/Help/placement transitions | 314 / 0 | 323 / 0 | compatibility-targeted-01 |
| Total | 509 / 0 | 521 / 0 | Six source-matched entries; 1030 checks |

Both final UI executions retain original real-damage, distinct-slot arrival and **independent engagement plus physical resumed travel for each produced unit**. Neither escorts nor a named state substitute for those witnesses. Both report 100 Rifle damage, 32 Rocket damage and three deaths. The targeted graphical [army capture](../validation-output/m8/m12-ui-compatibility-targeted-01/artifacts/graphical-attack_move_ui_checks/m9/screenshots/produced_army_1280x720.png) was inspected: five selection rings, a four-Rifle/one-Rocket HUD and group 3 with five units at 1280×720. This is automated capture inspection, not human playtesting.

Exact invocations (each phase retained without overwriting earlier evidence):

```powershell
& ./tools/validate-m8.ps1 -RunName m12-ui-compatibility-before-01 -Modes graphical -Suites attack_move_ui_checks
& ./tools/validate-m8.ps1 -RunName m12-ui-compatibility-targeted-01 -Modes headless,graphical -Suites attack_move_ui_checks,control_group_checks,builder_checks
& ./tools/validate-m8.ps1 -RunName m12-ui-compatibility-final-01 -Modes headless,graphical -Suites attack_move_ui_checks
```

[Before wrapper](../validation-output/m12/ui-compatibility-before-01-wrapper.log), [targeted wrapper](../validation-output/m12/ui-compatibility-targeted-01-wrapper.log) and [final wrapper](../validation-output/m12/ui-compatibility-final-01-wrapper.log) retain outcomes; each phase retains exact child commands, source hashes/copy and captures. This continuation ran nine test executions / **1356 passing checks**, plus three imports, with no failed executions. The original failures remain untouched. These cumulative observations are not nine distinct acceptance entries or proof of original repair.

## Reused evidence and final tested-source correspondence

This section records the completed compatibility continuation before the owner-authorized documentation decision above. Its saved manifests, comparisons, counts and check outcomes are retained unchanged; they are not a new execution or a check of the later closeout edits.

The final [compatibility check script](../validation-output/m12/compatibility-checks.ps1) and [saved checks](../validation-output/m12/compatibility-checks.json) verify all seven relevant immutable phase snapshots against their own manifests, and compare the same **291-path** current source set. No paths were added or omitted. All runtime scripts, scenes, resources, tools and unchanged tests remain byte-identical to the original matrix. Current differences from original/focused source are only README, roadmap, this report, `tests/attack_move_ui_checks.gd` and `tests/builder_checks.gd`.

The final UI test is matched to `m12-ui-compatibility-final-01` (SHA-256 `e27ecd55c38c530d61e5185b18a342c6d6ce1fb581e9899031e43ab5940a0182`); builder test to `m12-ui-compatibility-targeted-01` (`315f08e243ccb0ef097e85aa7d3f25a1cf760368b10e3048e7e610f3471375c9`). Final UI-phase source differs from current only in documents. The targeted phase additionally predates the explicitly rerun UI failure-branch release correction.

`enemy_economy_checks.gd` and its integration descendant override `_run` and call none of the changed UI integration/groups/snapshot helpers. `builder_integration_checks.gd` also overrides `_run` and does not call the edited `_builder_ui`; its used helpers, class-level state and runtime are unchanged. Their source-matched original passes, including the earned-opening 45/46 checks, remain applicable. This is why those dependencies were not rerun.

Final coverage reuses **62 original matrix entries** (60 passing, 7852 checks, seven failures in the two deferred movement runs) plus the six entries above. This covers the same 68 suite/mode entries: **66 passing, 8882 checks, seven movement failures**. It is combined source-matched coverage, not another full matrix or acceptance of the unexplained original UI occurrence. The original matrix remains **65/68 passing, 8814 checks, 14 failures, exit 1**. Earlier handoff results and their [91-link/whitespace check](../validation-output/m12/handoff-checks.json) remain historical evidence; they are not substituted for this final document check.

The prior continuation's final documentation checks passed **97 local links, including six anchors**, and **`git diff --check` exited 0**. Outcomes remain saved in `compatibility-checks.json` for that report, README and roadmap revision, including its then-INCOMPLETE acceptance decision. The check also verified the retained capture inventory and the one inspected current capture. No Godot process was launched by that check. That historical record is not overwritten by this owner-authorized closeout.

## Existing rendered evidence

Previously inspected matrix builder captures are reused; there is no visual/runtime change invalidating them and no repeat screenshot-review campaign. The one new army capture inspected for control-group compatibility is identified above. The [capture inventory](../validation-output/m12/capture-inventory.json) lists 12 retained entries with actual dimensions and SHA-256 hashes; the handoff check verifies those bytes unchanged. Nine are builder-suite entries and three integration entries, including duplicated inherited result/Restart captures.

- [Builder choices at 1280×720](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_checks/m12/screenshots/builder_choices_1280x720.png) and [1920×1080](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_checks/m12/screenshots/builder_choices_1920x1080.png).
- [Depot preview](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_checks/m12/screenshots/builder_depot_preview_1280x720.png), [constructing](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_checks/m12/screenshots/builder_constructing_1280x720.png) and [paused site](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_checks/m12/screenshots/builder_paused_site_1280x720.png), all 1280×720.
- [Help at 1280×720](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_checks/m12/screenshots/builder_help_1280x720.png) and [1920×1080](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_checks/m12/screenshots/builder_help_1920x1080.png).
- [Earned Depot/Collector/Factory/army](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_integration_checks/m12/screenshots/builder_earned_depot_collector_factory_army_1280x720.png), 1280×720.
- [Match result](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_checks/m12/screenshots/builder_match_result_1280x720.png) and [Restart](../validation-output/m8/m12-final-matrix-01/artifacts/graphical-builder_checks/m12/screenshots/builder_restart_1280x720.png) are actually **1920×1080**, despite their historical `_1280x720` filenames. They are not mislabeled here as 720p evidence.

The affected suites automatically save their usual captures in the new phase directories; those are retained. The new army image supplements the visible-selection assertions but cannot explain the original failure. No human physical-input playtest occurred.

## Deferred movement and outstanding acceptance

The original matrix's [headless movement-stress log](../validation-output/m8/m12-final-matrix-01/headless-movement_stress_checks.log) has **122 checks / five failures**: unit 27 exhausts eight recovery attempts at `(-2.85, 0, 1.574633)`, first toward `(7.5, 0, 3)` in `choke_30` (arrival, gate traversal, settling fail), then toward `(20.5, 0, -19.5)` in `L_shape_30` (arrival and settling fail). The [graphical log](../validation-output/m8/m12-final-matrix-01/graphical-movement_stress_checks.log) has **131 checks / two failures**: `choke_50` unit 6 exhausts eight attempts at `(6.234186, 0, -1.316787)` toward `(10, 0, -4.5)` (arrival and settling fail). Error lines correspond to those assertions. Their relationship to builder integration or historical failures is **UNKNOWN**; familiar geometry/IDs are not causal proof. Both projection-step modes pass in this matrix without closing prior projection failures.

The [M11 report](milestone-11.md), its retained unknown-attribution projection failure, and [deferred movement records](movement-issue-records.md) remain intact. Movement policy, repaired algorithms, defaults, fixtures, assertions and execution budgets are unchanged. No stress rerun or historical investigation was launched.

**Open technical verification gap, accepted development exception:** the original occurrence lacks an observation of the complete selected IDs before Ctrl+3, beginning with accumulation across Shift-clicks. If that stage had the expected [9,10,1,2,3], the next missing observation would be raw stored IDs immediately after assignment, followed by recall input/focus and restored IDs. Current source did not reproduce the failure in the bounded continuation; no defect or invalid original fixture assumption can be attributed from the retained evidence. It is not established as a movement limitation, pre-existing issue, builder regression or corrected fixture. Criterion 7 remains **NOT VERIFIED** despite passing targeted compatibility checks. The owner-authorized decision accepts Milestone 12 for continued feature development with a documented interface exception and supersedes this gap's former development gate. The issue remains open under the revisit conditions recorded above. Full movement/Milestone 5 regression acceptance is separately unresolved under the existing deferral. **Milestone 13 — Power generation** is the next feature, with planned report `docs/milestone-13.md`; it was not begun.
