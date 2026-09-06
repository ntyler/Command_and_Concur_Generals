# Fieldwork — RTS prototype

An original 3D RTS prototype built with **Godot 4.7.2**, typed GDScript, primitive meshes, and built-in navigation. The validated controls and crowd-movement fields remain available. Combat includes health, hitscan rifles, guided rockets, pursuit and limited retaliation. Milestone 2.5 adds static weapon blockers, blocked holding and swept projectile/world collision.

Open `project.godot` in Godot and press **F6** with `scenes/test_field.tscn` open, or **F5** to run the configured main scene. There is no asset download, plugin installation, navigation bake, or build step. The field and its navigation mesh are generated together at scene startup.

On the development machine, launch from PowerShell in this repository:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path .
```

The original field remains the F5 main scene. To run the alternate stress layout, open `scenes/movement_stress.tscn` and press F6, or use:

```powershell
& $godot --path . res://scenes/movement_stress.tscn
& $godot --path . res://scenes/movement_stress.tscn -- --units=50
& $godot --path . res://scenes/movement_stress.tscn -- --units=50 --movement-debug
```

The stress field is 72 × 56 units, with a 3.6-unit physical gate (1.9 units of navigable center clearance), an L-shaped obstacle, a three-obstacle cluster, and open western ground. Spawns and camera are fixed. `--units` is clamped to 30–50. Suggested world-space test destinations: wide route `(-22, 0, -15)`, beyond the gate `(9, 0, 0)` for 30 or `(10, 0, 0)` for 50, behind the L `(25, 0, -18)`, cluster `(20, 0, 22)`, boundary `(34.8, 0, 25.8)`.

To play combat, open `scenes/combat_test.tscn` and press F6, or run:

```powershell
& $godot --path . res://scenes/combat_test.tscn
```

Team Alpha is mint and player-controlled; Team Bravo is coral and retaliates when damaged. Each team starts with four Rifle Units and two Rocket Vehicles, at fixed positions around two obstacles. Select Alpha units, right-click a Bravo unit, and watch them approach, face and fire. Ground movement, X Stop, or another attack target interrupts the order. Hostiles do not initiate attacks or search for targets on their own.

The separate `scenes/line_of_fire_test.tscn` can also be launched with F6 or `& $godot --path . res://scenes/line_of_fire_test.tscn`. It has clear and blocked Rifle lanes, an opening, a wall behind a target, a Rocket lane with a wall-shadow route, and a 20 mm wall. Bravo retaliation is off in this geometry lab. After ordering the marked Rocket Vehicle to attack, press **T** to move its target into or out of the wall shadow using ordinary movement. F3 adds firing segments and contact markers; normal blocked labels remain visible with debugging off.

Exact engine used: `4.7.2.stable.official.ed1daf0bf`. The standard portable Windows build was installed after the user confirmed Godot needed installation. No global PATH or file associations were changed.

## Controls

| Input | Behavior |
| --- | --- |
| WASD or arrow keys | Smooth camera pan |
| Pointer within 18 pixels of a viewport edge | Edge pan; suspended during selection gestures |
| Mouse wheel | Smooth zoom, clamped from 20 to 60 world units (80 in the stress field) |
| Left click a friendly unit | Replace selection |
| Left click empty ground | Clear selection |
| Left drag at least 6 pixels | Select friendly anchors inside the rectangle, in any direction |
| Shift + left click | Add a unit or toggle it off |
| Shift + drag | Add enclosed units without clearing others |
| Right click ground | Replace selected units' move orders with distinct destinations |
| Right click a living hostile unit | Attack with selected combat units; friendly clicks issue no attack |
| X | Stop selected units' movement and combat; S remains camera pan |
| Escape | Cancel the current selection gesture |
| F3 | Toggle movement debugging and combat firing lines |
| T (line-of-fire scene only) | Move the marked rocket target into/out of the wall shadow |

The controls panel consumes pointer input and suspends camera movement while hovered. X still stops selected units over this passive panel; a focused UI control that consumes X keeps the event. Releasing a drag over it cancels the gesture. Losing application focus or leaving the window also cancels a drag. Shift is sampled when a selection gesture begins. Shift-clicking empty ground preserves selection. Clicks on obstacles or beyond the ground issue no move order; ground points near the boundary are projected onto navigation.

Mint rings indicate selected units. Movement debugging is off by default. F3 (or `--movement-debug`) shows amber final destinations, blue current waypoints, and labels with state, stalled time and retry count. Markers remain available after arrival. Every unit has one stable numeric identity. Existing `owner_id` is also the team ID: `1` for Alpha and `2` for Bravo; the movement fields contain only team 1. The original and combat cameras begin at ground focus `(0, 0, 0)`, zoom `52`, with focus bounds `x = ±29`, `z = ±23`. The stress camera uses the same angle, focus `(0, 0, 0)`, zoom `62`, and bounds `x = ±35`, `z = ±27`. The elevated Camera3D is offset behind its ground focus.

## Combat behavior

| Unit | Health | Damage | Range | Cooldown | Delivery |
| --- | --- | --- | --- | --- | --- |
| Rifle Unit | 100 | 12 | 8 | 0.75 s | Immediate hitscan with a brief tracer |
| Rocket Vehicle | 150 | 32 | 11 | 1.8 s | Guided projectile, speed 9 units/s, maximum life 6 s |

Health bars and unit-name/current-health labels are always visible on combat units. A brief white flash marks damage; dead units immediately stop participating and disappear. Health clamps at zero, death occurs once, and nonpositive/nonfinite damage is rejected.

Combat uses the existing navigation mover. Pursuit aims at 85% of weapon range from the target and checks for updates every 0.5 simulated seconds; a target movement of at least 1 unit or a completed chase requires a new path. Units turn at 4 radians/s and fire within 8 degrees of the target. They stop at weapon range, hold position through a 0.75-unit hysteresis band, and resume pursuit beyond that band. Holding outside actual weapon range never permits a shot. Recovery attempts and pursuit time remain bounded by the mover's existing per-order limits, including across chase updates.

Weapon cooldown survives replacement orders, preventing rapid command input from bypassing fire rate. An already-fired projectile retains its original target, launch team and damage even if its source moves, changes orders or dies. Target death, detachment, unregistration or becoming friendly to the launch team cancels impact safely.

Retaliation uses the same attack system and only reacts to a valid hostile damage source. An explicit player attack or active movement takes priority; X Stop holds that priority until another player order. A completed move releases its temporary retaliation priority. There is no idle auto-acquisition.

Marked static obstacles block both weapons. In-range attackers show **BLOCKED**, retain their target/order and hold position. Clearance is rechecked every 0.2 simulated seconds; restored clearance resumes firing subject to facing and cooldown. Blocked attempts never commit a shot or restart cooldown, while an existing cooldown continues. Beyond the existing hysteresis band, ordinary pursuit resumes. Units do not automatically find another firing position.

Physics layer 4, **Weapon Blockers** (mask 8), marks obstacle bodies in all fields. Ground, low boundary rails, decorative caps, units and visual feedback are excluded. A shared physics-step query checks body attachment (height 0.6) to muzzle (0.9), then muzzle to target aim (0.75). The emitter makes a fresh check before every committed shot. Input only issues commands; direct firing outside physics processing returns false.

Rockets sweep their actual movement segment, clamped to the original target's aim point. Lifetime expiry takes priority at tick start, then target invalidation, then earliest world contact, then target arrival. A 0.0001-unit endpoint/origin skin resolves numerical ties conservatively in favor of a blocker. The visible rocket has point/centerline collision. Homing can hit a wall when a target moves behind it. This is line of fire; target awareness and selection are unchanged. There is no splash damage, cover bonus or attack-move.

## Implementation

| File | Responsibility |
| --- | --- |
| `project.godot` | Main scene, desktop viewport, named input actions and collision layers |
| `scenes/test_field.tscn`, `scenes/movement_stress.tscn` | Original main scene and alternate stress layout |
| `scripts/test_field.gd` | Primitive field, lighting, repeatable unit placement, navigation mesh, controls feedback and command wiring |
| `scripts/rts_camera.gd` | Camera input, edge pan, zoom, exact exponential pan integration and bounds |
| `scripts/selection_controller.gd` | Selection membership, click/drag/Shift input, cancellation, physics-tick raycasts and signals |
| `scripts/rts_unit.gd` | Identity, ownership, picking, NavigationAgent3D avoidance, movement states, bounded recovery and debug feedback |
| `scripts/group_destinations.gd` | Navigable slot generation and stable assignment per command |
| `tests/milestone_checks.gd` | Standalone engine integration checks; no testing plugin |
| `tests/movement_stress_checks.gd` | Extends the existing harness with 30/50-unit routes, overlap comparisons, recovery and timing checks |
| `tests/movement_repair_checks.gd` | Focused command, signal, crowd-toggle, departure, recovery and stationary-observation regressions |
| `tools/run-godot.ps1` | PowerShell 7 child-process launcher with an external deadline and preserved child exit codes |
| `tests/validation_wrapper_checks.ps1`, `tests/blocking_fixture.gd` | Isolated wrapper/watchdog verification, including a deliberately blocked main thread |
| `scripts/combat_field.gd`, `scenes/combat_test.tscn` | Alternate two-team field sharing the existing navigation, camera and selection |
| `scripts/team_rules.gd`, `scripts/health.gd` | Central ownership/target rules and reusable health authority |
| `scripts/combat_controller.gd` | Versioned per-unit orders, pursuit, retaliation and death coordination |
| `scripts/weapon_definition.gd`, `weapons/*.tres`, `scripts/weapon_emitter.gd` | Configurable weapon data, simulation cooldown and firing authority |
| `scripts/guided_projectile.gd`, `scripts/combat_feedback.gd` | Independent projectile travel/impact and team/health/tracer presentation |
| `tests/combat_checks.gd`, `tests/engine_error_probe.gd` | Combat integration/load tests and engine-error capture through teardown |
| `scripts/command_batch_result.gd`, `tests/combat_repair_checks.gd` | Historical batch acceptance values and focused command/lifecycle regressions |

The field partitions a flat `NavigationMesh` at obstacle edges expanded by 0.85 units, producing connected convex polygons with holes. Geometry and navigation use the same obstacle definitions. Agents advance along navigation paths in physics ticks; step lengths are bounded to prevent overshoot and positions stay on the clearance mesh. `CharacterBody3D` collisions provide an additional solid obstacle boundary.

Group commands generate a deterministic compact lattice with configurable spacing (default 1.5), a group-size-dependent radius capped at 18, and a 1,600-candidate ceiling. Slots are projected onto navigation and checked for connectivity; spatial buckets reject duplicates and preserve reservations belonging to unselected units. Coordinate ordering followed by three pair-swap passes gives O(n²) assignment work with stable ties. Assignments change only on a new order. Commands that cannot provide enough distinct, reachable slots are rejected together, preserving the previous order.

`TestField.issue_move`, `issue_attack` and `issue_stop` return `CommandBatchResult`: a field-local request generation, intended and accepted stable unit IDs, `NONE`/`PARTIAL`/`COMPLETE` acceptance, `superseded`, and accepted movement assignments by ID. Acceptance is historical: a callback can replace an accepted order before dispatch returns. Use `is_complete() and not superseded` for a whole unsuperseded batch, or `has_acceptance()` for any historical acceptance. Never use object truthiness. Route tests retain fresh per-unit versions and capture assignments from the result. `last_command_result` and `last_command_slots` are diagnostics; pre-dispatch rejection preserves prior command snapshots and superseded dispatch cannot overwrite newer reporting. The field registers its units and handles `tree_exiting` immediately; detached or freed units no longer participate in selection, commands or reservations. Internal reparenting restores membership on tree entry.

Crowd movement uses Godot's RVO avoidance with ten nearby neighbors and a short prediction horizon. Soft avoidance radii allow limited shoulder contact near destinations or during congestion so parked rows do not seal a passage. Every step remains constrained to navigation and physical obstacles. Arrived units hold position and never rearrange their final slots.

Units distinguish travelling, congested, recovering, arrived and failed. Progress means reducing the **remaining navigable path length**, sampled every 0.75 seconds; side-to-side oscillation cannot keep resetting the stuck timer. After 2.25 seconds without meaningful progress, recovery samples up to 12 local detours or requests a repath, with at least 2.5 seconds between attempts. Detours expire after two seconds or end sooner when meaningful progress resumes. Ending temporary recovery preserves the per-order attempt count. An order that remains blocked after eight recovery attempts, or reaches its 90-second deadline, fails safely. A replacement order clears prior timers, temporary targets, velocity and recovery state immediately. Transitions publish coherent state before invoking synchronous listeners, and an obsolete transition cannot overwrite a listener's replacement order.

Change only `unit.crowd_enabled` to toggle avoidance, including during movement. Its setter synchronizes the agent and clears pending velocity state. The movement callback rejects disabled or obsolete submissions, and a physics-frame guard prevents a mode change from applying two movements in one tick. Scene defaults and crowd tuning are unchanged by Milestone 1.5.1.

There are no global managers or autoloads. Selection emits signals for count feedback and movement requests. The scene wires these to destination assignment; indicators never own selection state. Configuration is exposed with typed exports in the relevant scripts. Because this scene is constructed at runtime, edit those defaults or inspect the Remote scene while running.

Combat components are created only when a unit has a weapon definition. The movement fields retain their original configuration. Unit-level command APIs retain bools; field-level commands return the batch result described above. Group authority is captured before selection queries and guarded during dispatch. Internal `retarget_pursuit()` keeps the movement order, stall clock, signed path-progress credit/debt and recovery history. Rebasing compares old/new path lengths at the same attacker position, so a changing target alone earns no progress. A real detour keeps its waypoint and expiry; a fallback repath tracks the new destination. Real replacement orders still clear per-order state. Selection and targeting require live membership in the owning field, using an O(1) registration lookup plus tree/ancestry checks.

## Validation

From the repository root in **PowerShell 7**, with `$godot` set as above, use the external wrapper for validation:

```powershell
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--version')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--editor', '--import')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--quit-after', '120')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/milestone_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/milestone_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/movement_stress_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/movement_stress_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/movement_repair_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/combat_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/combat_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/combat_repair_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/combat_repair_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/line_of_fire_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/line_of_fire_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/combat_checks.gd', '--', '--combat-load')
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
git diff --check
```

The runners inject events through Godot's viewport and Input APIs, exercise actual selection raycasts and navigation, and exit nonzero on assertion failure. Each movement wait has a simulation deadline. The inherited 180-second in-process watchdog gives diagnostics while the Godot event loop remains responsive; it cannot interrupt a synchronous block. The external wrapper defaults to 240 seconds, accepts `-TimeoutSeconds`, terminates the child process tree on expiry, and returns **124**. Normal child codes are reported and preserved; wrapper launch errors return **125**. Read `$LASTEXITCODE` immediately after each command; a CI/shell entry point should end with `exit $LASTEXITCODE` to propagate that command's exact result.

The wrapper self-test deliberately checks the internal watchdog's **2**, the unarmed blocking fixture's **3**, and the armed blocking fixture's external **124**, then returns **0** only if all checks pass. Expected failure logs are separate from ordinary validation. The blocking fixture requires `-- --verify-external-timeout` and is never loaded by a normal suite. See the corrective report for standalone commands.

Post-arrival checks sample all 180 physics ticks over three simulated seconds, requiring maximum displacement below 0.001 world units, ARRIVED state, no active movement, and velocity below 0.001. Overlap measurements sample center distances below 0.6 at 10 Hz: pair-seconds sum those sampled durations over pairs; the longest run estimates consecutive sampled overlap, not continuously observed contact.

Graphical checks write screenshots to ignored `validation-output/`; stress checks also write `stress-metrics.json`. Test playback uses fixed simulation FPS and disables VSync in the test harness only. The main playable scenes retain their normal display settings. Performance observations describe this instrumented playback, not a promised game frame rate. Keep the game focused and avoid physical input during graphical input playback.

Combat validation combines real input, health, cooldown, order-version and physics assertions with eight graphical captures. Its engine-error probe fails the run on errors or warnings, including during field teardown. The separate `--combat-load` check starts 12 units per team, runs a fixed 12-second engagement, stops survivors and verifies outstanding projectile cleanup after their lifetime. Its metrics are written to `validation-output/combat-load-metrics.json`. Normal scenes do not load test instrumentation.

See [Milestone 2.5 behavior, commands and acceptance evidence](docs/milestone-2.5.md), [Milestone 2.0.1 corrections](docs/milestone-2.0.1.md) and the qualified [Milestone 2 architecture and historical validation](docs/milestone-2.md). Historical movement evidence remains in [Milestone 1.5.1](docs/milestone-1.5.1.md), [Milestone 1.5](docs/milestone-1.5.md) and [Milestone 1](docs/milestone-1.md). Every current stress route proves complete unsuperseded acceptance, new unit versions and captured assignments. Automated input playback and captured-frame inspection were performed; a human keyboard/mouse playtest was not performed.

## Scope and limits

- Crowd avoidance reduces overlap but permits brief partial contact. It is not rigid vehicle collision. Tested units settle at distinct positions; difficult untested congestion can fail safely and accept a replacement order.
- Navigation is for these flat, static fields. Slopes, dynamic navigation changes, opposing traffic through a gate, and crowds above 50 need separate validation.
- Assignment reduces straight-line travel; it does not solve a global minimum-cost path assignment around obstacles.
- Weapon obstruction supports marked static primitive convex shapes. Moving blockers, arbitrary concave meshes and volumetric ballistics are outside the tested scope. Other units do not intercept shots.
- Combat has no visibility filtering, cover bonuses, automatic repositioning, splash damage, armor multipliers or attack-move.
- No economy, construction, production, fog of war, strategic AI or other later systems are implemented. All visuals are original generated primitives.

Physical-input combat playtesting, opposing traffic and varied terrain remain separate work. No systems beyond Milestone 2.5 were added.
