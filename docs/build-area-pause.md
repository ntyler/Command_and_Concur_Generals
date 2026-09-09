# Build-area clarity and Escape Pause

Implemented 2026-09-09 in the existing Godot 4.7.2 project. Play `res://scenes/fortified_assault.tscn` with F6 or `--path . res://scenes/fortified_assault.tscn`; F5 remains the original controls field. No engine/dependency installation, commit, movement investigation or additional building milestone was performed. Existing unfinished Tempest work and historical acceptance exceptions are preserved. Verification uses automated engine viewport input, not human playtesting.

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

Validation in progress; final saved results and limitations will replace this paragraph before handoff.

The starting working tree included unfinished Tempest UI/scripts/tests without the supporting enum, resource or playable scene. An initial import exposed compile errors in these existing dependencies. Narrow optional-property/enum guards and explicit types keep the current scenes loadable without completing or enabling that facility. Its partial charge/strike code receives pause early returns, but the incomplete facility is not claimed as playable or runtime-validated by this task.
