# Fieldwork — RTS controls prototype

An original 3D RTS controls lab built with **Godot 4.7.2**, typed GDScript, primitive meshes, and built-in navigation. Milestone 1 covers an angled camera, selection, and movement on a repeatable 60 × 48 unit field with 12 friendly units and three obstacles.

Open `project.godot` in Godot and press **F6** with `scenes/test_field.tscn` open, or **F5** to run the configured main scene. There is no asset download, plugin installation, navigation bake, or build step. The field and its navigation mesh are generated together at scene startup.

On the development machine, launch from PowerShell in this repository:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path .
```

Exact engine used: `4.7.2.stable.official.ed1daf0bf`. The standard portable Windows build was installed after the user confirmed Godot needed installation. No global PATH or file associations were changed.

## Controls

| Input | Behavior |
| --- | --- |
| WASD or arrow keys | Smooth camera pan |
| Pointer within 18 pixels of a viewport edge | Edge pan; suspended during selection gestures |
| Mouse wheel | Smooth zoom, clamped from 20 to 60 world units |
| Left click a friendly unit | Replace selection |
| Left click empty ground | Clear selection |
| Left drag at least 6 pixels | Select friendly anchors inside the rectangle, in any direction |
| Shift + left click | Add a unit or toggle it off |
| Shift + drag | Add enclosed units without clearing others |
| Right click ground | Replace selected units' move orders with distinct destinations |
| Escape | Cancel the current selection gesture |

The controls panel consumes pointer input and suspends camera movement while hovered. Releasing a drag over it cancels the gesture. Losing application focus or leaving the window also cancels a drag. Shift is sampled when a selection gesture begins. Shift-clicking empty ground preserves selection. Clicks on obstacles or beyond the ground issue no move order; ground points near the boundary are projected onto navigation.

Mint rings indicate selected units. Amber rings show assigned destinations in debug builds and remain at those positions after arrival. Every unit has one stable numeric identity and friendly owner ID `1`. The camera has a fixed perspective angle and begins at ground focus `(0, 0, 0)`, zoom `52`. Pan limits constrain its ground focus to `x = ±29`, `z = ±23`; the elevated Camera3D is offset behind that focus.

## Implementation

| File | Responsibility |
| --- | --- |
| `project.godot` | Main scene, desktop viewport, named input actions and collision layers |
| `scenes/test_field.tscn` | Single deterministic main scene |
| `scripts/test_field.gd` | Primitive field, lighting, repeatable unit placement, navigation mesh, controls feedback and command wiring |
| `scripts/rts_camera.gd` | Camera input, edge pan, zoom, exact exponential pan integration and bounds |
| `scripts/selection_controller.gd` | Selection membership, click/drag/Shift input, cancellation, physics-tick raycasts and signals |
| `scripts/rts_unit.gd` | Identity, ownership, picking capsule, selection anchor, visual indicators and NavigationAgent3D movement |
| `scripts/group_destinations.gd` | Navigable slot generation and stable assignment per command |
| `tests/milestone_checks.gd` | Standalone engine integration checks; no testing plugin |

The field partitions a flat `NavigationMesh` at obstacle edges expanded by 0.85 units, producing connected convex polygons with holes. Geometry and navigation use the same obstacle definitions. Agents advance along navigation paths in physics ticks; step lengths are bounded to prevent overshoot and positions stay on the clearance mesh. `CharacterBody3D` collisions provide an additional solid obstacle boundary.

Group commands generate a deterministic lattice around the clicked point with configurable minimum spacing (default 1.5). Each slot is projected onto navigation, checked for connectivity and checked again for separation. Greedy nearest-pair assignment followed by improving pair swaps reduces travel; sorted unit IDs provide stable tie behavior. Assignments change only on a new order. Commands that cannot provide enough distinct, reachable slots are rejected together, preserving the previous order.

There are no global managers or autoloads. Selection emits signals for count feedback and movement requests. The scene wires these to destination assignment; indicators never own selection state. Configuration is exposed with typed exports in the relevant scripts. Because this scene is constructed at runtime, edit those defaults or inspect the Remote scene while running.

## Validation

From the repository root, with `$godot` set as above:

```powershell
& $godot --version
& $godot --headless --path . --editor --import
& $godot --headless --path . --quit-after 120
& $godot --headless --path . --fixed-fps 60 --script res://tests/milestone_checks.gd
& $godot --path . --fixed-fps 60 --script res://tests/milestone_checks.gd
git diff --check
```

The runner injects events through Godot's viewport and Input APIs, exercises the actual selection raycasts and navigation, checks every unit's final stopping distance, and exits nonzero on an assertion failure. The graphical run also writes four screenshots to ignored `validation-output/`. It uses fixed simulation FPS so playback is repeatable; this is not a performance benchmark. Keep the game focused and avoid physical input during graphical playback.

The final run results and all 20 acceptance items are recorded in [the milestone report](docs/milestone-1.md). Automated input playback and captured-frame inspection were performed; a human keyboard/mouse playtest was not performed.

## Scope and limits

- Units have solid obstacle collision and can pass through one another in transit. Unit crowd avoidance and unit-to-unit physical collision are not part of this milestone. Distinct destinations prevent stacking at arrival.
- Navigation is for this flat, static test field. Slopes, dynamic obstacles, large crowds, and disconnected terrain need separate validation before extending the scene.
- Assignment reduces straight-line travel; it does not solve a global minimum-cost path assignment around obstacles.
- No combat, economy, construction, AI, fog of war, factions, or other later systems are implemented. All visuals are original generated primitives.

Recommended next milestone: stress-test movement on a second terrain layout and design robust unit crowd handling before adding gameplay systems.
