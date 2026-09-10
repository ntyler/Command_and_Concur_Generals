# Build-area clarity and Escape Pause

Implemented 2026-09-09 in the existing Godot 4.7.2 project. Play `res://scenes/fortified_assault.tscn` with F6 or `--path . res://scenes/fortified_assault.tscn`; F5 remains the original controls field. No engine/dependency installation, new commit, movement investigation or additional building milestone was performed during this closeout. Existing unfinished Tempest work and historical acceptance exceptions are preserved. Verification uses automated engine viewport input, not human playtesting.

## Boundary cause and behavior

`ConstructionField.placement_geometry()` required the footprint expanded by **0.85 units on every side** to fit both `BUILD_AREA = Rect2(-27, -21, 54, 43)` and the supported terrain rectangle. The obsolete HQ prototype box therefore rejected valid supported terrain in builder-enabled matches, producing the old “Full footprint and clearance must fit inside the green boundary” message.

These rectangles are distinct:

| Geometry | X range | Z range |
| --- | --- | --- |
| Physical terrain | -30 to 30 | -24 to 24 |
| Supported construction boundary / existing navigation inset | -29.15 to 29.15 | -23.15 to 23.15 |
| Old prototype construction box | -27 to 27 | -21 to 22 |
| Camera focus limits | -29 to 29 | -23 to 23 |

Builder matches now use `construction_area()` derived from `field_bounds.grow(-CLEARANCE)`. The original HQ construction prototype keeps its authored local box. The world and navigation geometry were not enlarged. The preview footprint still expands by 0.85; production exits and Depot delivery areas must also fit. Obstacles, live occupancy, protected HQ/depot deliveries and approach corridors, and builder reachability still reject independently.

The visible green guide uses the same effective rectangle as validation. Map-edge feedback says “Too close to map edge—move the building inward,” with a suffix when the actual failing shape is a production exit or delivery access. The preview records the proposed footprint, clearance rectangle, failing shape and exact out-of-bounds perimeter segments, which render bright red. Protected delivery/access overlaps keep their separate named owners and intersection highlights. The screenshot image itself was not present in the attachment; its quoted message was traced in source, and the current playable scene was verified through the existing Fortified viewport observer and scene inheritance.

## Pause and retained state

One non-repeated Esc opens Pause. It clears only pending input (preview, targeting, selection gesture and deferred picks), closes Help and clears group double-tap/camera input timing. Right-click remains cancellation without Pause. The menu is the sole match Esc owner in `_unhandled_key_input`, preserving unrelated GUI-consumed keys. It consumes repeats and releases so one keypress cannot toggle twice.

Esc/Resume resumes. Restart Match and Quit to Desktop present confirmations. Esc/Back cancels a confirmation and leaves the match paused. Restart uses the existing scene replacement path and starts a fresh unpaused match. Victory/defeat/draw cannot resume through Esc.

Godot `SceneTree.paused` freezes inherited gameplay processing and physics; the menu uses `PROCESS_MODE_ALWAYS`. A separate `manual_pause_active` contributes to the existing `gameplay_enabled` guard without overwriting terminal result state. No paid site is refunded, no builder detached, and no accepted order is stopped by manual pause. Progress uses simulated delta, so resume does not catch up paused wall time. Explicit guards cover late damage, navigation avoidance, projectile, weapon cooldown, defense, attack-move, navigation and existing optional strike/charge callbacks. Genuine destruction/departure/teardown keeps lifecycle cleanup; manual pause does not call the destructive result-freeze path.

## Validation

**Build-area / Esc Pause closeout: VERIFIED by automated validation.** All 48 originally planned affected-suite executions are complete, with the previously saved 39 retained and only the nine missing graphical executions resumed. The new deferred-callback teardown case also passes, including its directly affected Pause/Quit and fortification validation. This accepts the scoped feature, not full movement acceptance or the unfinished superweapon facility.

### Saved runs and source correspondence

Recovery started at HEAD and origin/main `e9b0617`, after the separate automatic-harvesting commit `4448e3c`. No interrupted Godot/test process remained. The local Pause diff already contained the 47-line teardown extension; its reported +2/-2 was the explicit `WeakRef` typing correction relative to the failed recovery snapshot. That correction and the actual callback-path regression were preserved.

Both original 418-file frozen projects still match their recorded SHA-256 manifests. Their source matches `e9b0617` after line-ending normalization, although their recorded base revision is `4448e3c` with pending changes later committed by `e9b0617`. At this resumption, 417 files matched the working tree byte-for-byte; only the extended `tests/pause_checks.gd` differed. The final original-snapshot differences are exactly that test, the two-line freed-owner guard in `scripts/barrier_building.gd`, and this report. The new validation snapshots match all final executable source; their only later difference is this documentation update. No harvesting implementation or fixture was edited.

| Evidence phase | Test executions | Checks | Result |
| --- | ---: | ---: | --- |
| [Saved focused-03](../validation-output/m8/build-area-pause-closeout-focused-03/summary.json): headless fixture-resource 1, Pause 105, Quit 8, defense UI 128 | 4 | 242 | Retained clean passes |
| [Saved affected-01 results](../validation-output/m8/build-area-pause-closeout-affected-01/results.json): all 24 headless and first 15 graphical executions | 39 | 5,944 | Retained clean passes; original interrupted phase remains unchanged |
| [Resumed graphical-01](../validation-output/m8/build-area-pause-resumed-graphical-01/summary.json): exactly the missing nine entries below | 9 | 1,537 | All clean |
| [Smallest corrected teardown case](../validation-output/build-area-pause/resumed-teardown-02/headless-teardown.stdout.log): `--pause-case=teardown`, headless | 1 | 55 | 52 teardown checks plus 3 runner/cleanup checks; clean |
| [Resumed Pause/Quit](../validation-output/m8/build-area-pause-resumed-pause-01/summary.json): Pause 135 headless / 139 graphical; Quit 8 / 8 | 4 | 290 | All clean on final executable source |
| [Affected headless fortification](../validation-output/m8/build-area-pause-resumed-fortification-01/summary.json) | 1 | 158 | Clean; graphical counterpart is included in the nine above |

The original 48 entries total **7,481 checks**. Substituting the five directly affected reruns yields **7,541 checks across the same 48 suite/mode entries**, including the 30 added deferred-teardown checks in each full Pause run. Counting every clean execution in the table, including overlapping focused coverage, gives **58 test executions / 8,226 check instances**, plus **five separate successful fresh imports**. These are not 8,226 unique assertions. The saved 242-check phase overlaps the affected suite and was not rerun.

The nine previously missing executions were all graphical, each with zero failures, zero native diagnostic lines and exit 0:

| Test script (`tests/`) | Checks |
| --- | ---: |
| `fortification_checks.gd` | 158 |
| `fortification_ui_checks.gd` | 178 |
| `air_production_checks.gd` | 96 |
| `enemy_economy_checks.gd` | 100 |
| `power_ui_checks.gd` | 208 |
| `hud_clarity_checks.gd` | 212 |
| `attack_move_ui_checks.gd` | 117 |
| `air_ui_checks.gd` | 238 |
| `vehicle_production_checks.gd` | 230 |

### Deferred synchronization and shutdown

The new regression connects a synchronous observer before `request_gate()` binds the gate. An ordinary unpaused opening emits synchronization and ready once with an empty deferred map. Closing then opens Pause from that same observer before the gate collider callback. Before any teardown, the test requires the real gate callable and matching generation in `_deferred_synchronizations`, an unchanged open collider, pending/blocked navigation, and no additional ready notification. It never inserts the callback by directly calling `defer_synchronization()`.

Both attached-gate match destruction and detached-gate destruction clear the populated callback and listeners. The detached gate remains alive only long enough to deliver matching late synchronization/ready callbacks after its match is freed; its state stays unchanged. Final checks require dead weak references, an invalid freed-gate callable, no root children, no new submissions or ready/synchronization notices, and an unpaused tree. The existing freeze case still verifies that Resume drains the deferred gate callback exactly once.

The first resumed focused attempt reached those assertions but was **not clean**: [55 checks / 1 failure, exit 1](../validation-output/build-area-pause/resumed-teardown-01/headless-teardown.stdout.log), with [one freed-object cast diagnostic](../validation-output/build-area-pause/resumed-teardown-01/headless-teardown.stderr.log) in `BarrierBuilding._owner_field()` during the late ready callback. The narrow fix checks `is_instance_valid(gameplay_field)` before casting it. The unchanged regression then passed 55/0, followed by the final-source runs above. No navigation synchronization logic or harvesting behavior was replaced.

Validation used the existing `tools/validate-m8.ps1` fresh-copy runner, `tools/run-godot.ps1` process-tree watchdog and inherited simulation watchdog, serially on installed `4.7.2.stable.official.ed1daf0bf`. Resumed matrix phases used 120-second external limits; the smallest teardown attempts used 240 seconds. All accepted logs were audited through final `GODOT_EXIT: 0`, including output after the gameplay assertion summary. They contain no assertion failures, native errors/warnings, ObjectDB/resource retention reports, PagedAllocator errors, hangs or abnormal exits. Runtime teardown checks also pass. The [final process check](../validation-output/build-area-pause/final-process-check.json) records no surviving Godot/test wrapper process.

### Graphical evidence and final audit

The nine resumed graphical runs retain **104 PNG artifact files representing 88 distinct image hashes**. The final Pause run produces four more screenshots: 1280×720 and 1920×1080 Pause overlays, Restart confirmation and Quit confirmation. The saved affected phase retains its original Pause and 20 boundary screenshots, including valid near/far placements and footprint, clearance, production-exit and delivery-edge failures. All logs, invocations, frozen projects and screenshots remain in their original phase directories under the ignored `validation-output/` tree.

The [visual review](../validation-output/build-area-pause/visual-review.md) records 14 inspected actual viewport images, including final-source Pause/confirmations, boundary highlights, gate controls, Help and HUD layouts. These are automated viewport-input captures, not human playtesting. The runner can copy the same recent screenshot into a following execution's artifact folder; distinct hashes prevent those copies being claimed as new screenshots from that later suite.

The [aggregate audit](../validation-output/build-area-pause/aggregate-summary.json), produced by [the saved checker](../validation-output/build-area-pause/closeout_audit.py), records every execution/count, log hash, frozen-source comparison, screenshot hash/dimensions, local documentation link/anchor check, explicit documentation whitespace check and `git diff --check` result. Only this report required a documentation update; README and roadmap already point to it and preserve the existing acceptance boundaries.

Final documentation checks pass: **110 local links/anchors across README, roadmap and this report**, no trailing documentation whitespace, and **`git diff --check` exit 0**. Final Git status has only three unstaged modified files: `docs/build-area-pause.md`, `scripts/barrier_building.gd` and `tests/pause_checks.gd`. Nothing was committed.

### Retained failures and limits

The [historical recovery audit](../validation-output/build-area-pause-recovery-audit/README.md) preserves the earlier parse failures, six obsolete Escape-flow fixture assertions, and fixture-loading shutdown leaks (105/53 or 106/54 retained objects/resources with PagedAllocator errors). Assertion passes accompanied by those diagnostics remain failed evidence. The no-match fixture probe reproduced retention without creating a match; the committed fixture resource-loading cleanup and later clean runs establish the corrected dependency behavior. The earlier `build-area-pause-recovery-focused-01` also remains failed: Pause could not parse the two inferred weak references, and its dependent Quit runs hit the external watchdog. Its two passing fixture-only checks do not validate Pause. None of those failed phases is included in the clean totals above.

Automatic harvesting in `4448e3c` is a preserved baseline dependency, not an implementation or validation deliverable of this closeout. In particular, the finite-wallet enemy fixture's `collection_radius = 0.0` belongs to that separate change; the older Escape/group-input fixture failure has a different cause. Passing compatibility checks here do not absorb the automatic-harvesting feature's own acceptance claims.

Historical movement failures remain unresolved under the [roadmap's existing exceptions](roadmap.md), including the M16 movement validation limit. The separate historical M12 group-3 interface occurrence remains open with unknown cause and criterion 7 NOT VERIFIED. This closeout neither replays nor resolves those failures.

The starting working tree included unfinished Tempest UI/scripts/tests without the supporting enum, resource or playable scene. An initial import exposed compile errors in these existing dependencies. Narrow optional-property/enum guards and explicit types keep the current scenes loadable without completing or enabling that facility. Its partial charge/strike code receives pause early returns, but the incomplete facility is not claimed as playable or runtime-validated by this task.
