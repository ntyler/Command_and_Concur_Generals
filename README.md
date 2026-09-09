# Fieldwork — RTS prototype

**Current milestone: [Milestone 11 — Supply Depots and Collector production](docs/milestone-11.md) is COMPLETE for its feature requirements** in `res://scenes/supply_depot_assault.tscn`. All eight feature groups pass; no depot requirement remains outstanding. The final matrix completed **64 executions, 63 passing, 8,110 checks and three failures**, exit 1: headless projection-fixture unit 41 exhausted movement retries, with attribution unknown. The matrix is not passing. Depot and corrected earned integration pass both modes (717 checks included in the total). [Milestone 10](docs/milestone-10.md) remains complete with its retained unknown-attribution graphical movement-stress failure. Full movement/Milestone 5 acceptance remains unresolved. No human playtest occurred. [Next focused feature — Milestone 12](docs/roadmap.md#next-focused-feature--builder-driven-construction): Bulldozers and builder-driven construction before power generation, scheduled but not implemented; current HQ-based automatic construction is prototype behavior.

An original 3D RTS prototype built with **Godot 4.7.2**, typed GDScript, primitive meshes, and built-in navigation. The validated controls and crowd-movement fields remain available. Combat includes health, hitscan rifles, guided rockets, pursuit and limited retaliation. Milestone 2.5.1 supplies spherical projectile/world collision; Milestone 3 adds fixed headquarters/barracks, starting credits and Rifle production. Milestone 4 adds finite supplies, two preplaced unarmed Collector Trucks, automatic deposits and harvesting-funded production. Milestone 5 adds player-placed barracks, paid timed construction, cancellation and serialized runtime navigation changes in a separate construction scene.

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

The separate `scenes/line_of_fire_test.tscn` can also be launched with F6 or `& $godot --path . res://scenes/line_of_fire_test.tscn`. It has clear and blocked Rifle lanes, an opening, a wall behind a target, a Rocket lane with a wall-shadow route, and a 20 mm wall. Bravo retaliation is off in this geometry lab. After ordering the marked Rocket Vehicle to attack, press **T** to move its target into or out of the wall shadow using ordinary movement. F3 adds firing segments, contact markers and the configured rocket launch sphere; normal blocked labels remain visible with debugging off.

Exact engine used: `4.7.2.stable.official.ed1daf0bf`. The standard portable Windows build was installed after the user confirmed Godot needed installation. No global PATH or file associations were changed.

To play production, open `scenes/production_test.tscn` and press **F6**, or run `& $godot --path . res://scenes/production_test.tscn`. Click your western barracks, press **Train Rifle Unit**, and watch the unit deploy after five simulated seconds and move to its rally point. With the barracks selected, right-click ground to change the rally. Select the produced unit and right-click a coral hostile to fight. The headquarters displays identity, owner and credits. Both fixed buildings block navigation and weapon fire and cannot be attacked.

Each owner starts with **1000 integer credits**. A Rifle costs **100**, takes **5 simulated seconds**, and occupies one of **5 queue slots**, including the active or completed-but-blocked job. Barracks sharing an owner use the same field-local balance. Training is FIFO, one active job per barracks. Cancel any undeployed job for its original full payment exactly once. A blocked exit holds the head at 100%, displays **Exit blocked**, and retries every **0.25 simulated seconds** without charging again or training later jobs. Six bounded local candidates must pass navigation and full Rifle-capsule clearance. Deployment removes the job before completion callbacks; subsequent unit death or rally rejection cannot refund it. See [Milestone 3](docs/milestone-3.md) for lifecycle details and validation.

To play harvesting, open `scenes/harvesting_test.tscn` and press **F6**, or run `& $godot --path . res://scenes/harvesting_test.tscn`. Select one or both western Collector Trucks, then right-click a yellow supply cache. Each cache begins with **2000 supplies**. Collectors carry **100**, load **25 per completed simulated second**, return to the existing owned headquarters and unload for **one simulated second**. Each deposited supply adds **one credit to the existing production balance**. They repeat trips to that cache until it empties, including a final partial load. Select your barracks and spend those credits on normal Rifle production, rally and combat.

Ground Move and **X Stop** cancel harvesting immediately while preserving cargo. Right-click an owned HQ with cargo to deposit once and idle. A new cache assignment preserves cargo; a full collector deposits before going to the new cache. Rejected commands preserve existing work. Mixed selections dispatch only to eligible collectors and report partial acceptance; combat units keep their orders. Death loses undeposited cargo. Missing HQ or blocked access retains cargo and requires a new command. Empty caches remain as static obstacles. Cargo/activity and the assigned cache's remaining amount appear only for selected collectors; the existing credit and production panel is reused. Collectors have 150 health, move at 4 units/s with the unchanged crowd/recovery settings, and cannot fire or be produced in this earlier HQ-only scene. See [Milestone 4](docs/milestone-4.md) for transfer, lifecycle, validation and pre-existing stress-test evidence.

To play construction, open `scenes/construction_test.tscn` and press **F6**, or run `& $godot --path . res://scenes/construction_test.tscn`. This scene starts with the same HQ, collectors, supplies, credits and combat units, but **no barracks**. Select the HQ and press **Build Barracks**. The free translucent preview shows the actual footprint and a written placement reason. Left-click valid ground to spend **400 credits**; right-click or **Escape** cancels placement. UI clicks cannot place. During placement or F3 diagnostics, green outlines mark the construction boundary and gold outlines show protected access; they are hidden during ordinary play. Positions near `(-12, 0, 3)` and `(-3, 0, 16)` provide room for two barracks when clear of units.

One unfinished site is allowed. Its **10 simulated seconds** start only after the updated navigation map is synchronized and verified by queries. Select the site to inspect progress or **Cancel construction** for the original full cost. Cleanup holds the slot until the restored navigation is ready. Completed barracks use the existing Rifle queue and rally controls; completion cannot be sold or refunded. Existing movers briefly wait and replan with their original command history; newly invalid destinations fail safely. Harvesting continues with conserved cargo and credits. See [Milestone 5](docs/milestone-5.md) for exact placement/access rules, failure behavior, validation and separately reported intermittent stress results.

Current construction checks pass **267 headless / 270 graphical assertions**. The historical M5 matrix ran **3,936 assertions with two graphical 50-unit cluster failures**. Full crowd-regression acceptance remains **NOT VERIFIED**: baseline gate failures are established, but the original M5 cluster failure's cause is unconfirmed. The report retains the failed matrix and every required repeat and diagnostic run; passing reruns are not presented as proof that this historical failure was repaired.

[Milestone 5.0.1 diagnosis and repair](docs/milestone-5.0.1.md) fixes the separately captured baseline parked-neighbor deadlock using clearance-aware local recovery and at most two waypoints within the existing attempt deadline. The three-unit reproduction fails before and passes after; a reconstruction with both captured movers and all 48 parked neighbors also fails before and passes after in both display modes. The post-repair matrix passes **4,224 assertions**, with five graphical stress repeats and five matching headless runs also passing. The original M5 unit 4 failure remains causally unresolved, so full acceptance stays **blocked**. [Issue records](docs/movement-issue-records.md) distinguish the two cases. Cleanup-failure checks remain intact and pass **46 headless / 46 graphical assertions**.

To play **base assault**, open `scenes/base_assault.tscn` and press **F6**, or run:

```powershell
& $godot --path . res://scenes/base_assault.tscn
```

Destroy the coral HQ while protecting the mint HQ. Each has **1200 HP**. Start with **1000 credits**, three Rifles, two collectors, two finite supply caches and no barracks. The owned HQ starts selected: **Build Barracks** costs **400**, completes after **10 simulated seconds** plus navigation preparation, and provides the existing **100-credit / 5-second** Rifle queue and rally controls. A completed barracks has **450 HP**; unfinished sites keep their existing cancellation rules. Select collectors and right-click supplies to earn more credits, then select combat units and right-click hostile units or buildings to attack. Other buildings and terrain still obstruct fire. The enemy's three Rifles receive one HQ assault order after **90 simulated seconds**; there is no enemy economy or strategic AI.

Enemy-HQ destruction is victory; player-HQ destruction is defeat; both lost in one physics tick is a draw. The result stops gameplay and shows **Restart**, which reloads the initial match. Building destruction gives no construction refund; only paid undeployed production jobs refund, once. The earlier scenes retain their defaults and invulnerable buildings. See [Milestone 6](docs/milestone-6.md) for lifecycle details, complete validation and limits.

To play **combined arms**, open `scenes/combined_arms_assault.tscn` and press **F6**, or run:

```powershell
& $godot --path . res://scenes/combined_arms_assault.tscn
```

Milestone 7 adds **Build Vehicle Factory** alongside **Build Barracks** at the HQ. The factory costs **600 credits**, takes **15 simulated seconds** after navigation preparation, and trains the existing **Rocket Vehicle for 250 credits / 8 seconds**. It has 450 HP and five queue slots, including a completed vehicle waiting at a blocked exit. The blue-gray garage and raised gold roof rails distinguish it from the barracks. Both buildings use the existing single unfinished-site limit, shared wallet, cancellation, safe deployment and right-click rally controls. No barracks prerequisite is needed for the factory.

Start with the same 1000 credits, collectors, supplies and small force, with neither production building. Harvest to fund both structures and their units, then attack the coral HQ while protecting yours. The original 90-second enemy assault, victory/defeat/draw and Restart remain. Restart reloads this combined-arms scene with clean initial state. Earlier scenes, including the original base assault, retain their defaults. See [Milestone 7](docs/milestone-7.md) for exact configuration, automated acceptance and preserved deferred movement limitations.

The completed **Milestone 7 baseline** passed **225 headless / 230 graphical feature assertions**, including the zero-credit earned construction/production/combat/victory/Restart loop. Its final recorded request audit passed fresh-copy import and **44/44 test executions: 5555 assertions, zero failures**, including Base Assault and the complete ordinary regression matrix. Earlier M7 runs retain two graphical movement-stress failures (unit 5, 50-unit gate arrival/settling) and three headless projection-fixture failures. Their attribution remains unknown; the passing baseline does not resolve them or establish full movement acceptance. [The M7 report](docs/milestone-7.md#repeated-request-verification) preserves those historical commands, results and captured frames. No human playtest was performed.

**Milestone 8** adds a compact lower-right tactical map to this same `res://scenes/combined_arms_assault.tscn`. The fully revealed map shows obstacle footprints, mint/coral mobile units, HQs, barracks, factories, committed construction sites and supply caches. Units use circles, supplies use diamonds, and structures show their footprint with **H/B/V/+** labels. Selected units gain white rings; depleted supplies remain outlined markers. The white ground-view outline follows actual camera pan and zoom. Orientation is fixed: **world +X is right, +Z is down (−Z is up)**. The map preserves aspect ratio, including letterboxing after a resize. Markers refresh every **0.1 seconds** by default; camera feedback updates every frame.

Left-click valid minimap content to center the camera while preserving its zoom, angle and selection. Right-click it to send selected mobile units an ordinary ground **Move** through the existing command API, including normal collector interruption with cargo retained. Panel padding and letterboxed margins do not accept map commands. The minimap consumes pointer events, suppresses hover-driven edge scrolling and leaves unconsumed keyboard camera input available. Placement and match results keep their existing interaction rules.

Use **Ctrl + 1–9** to replace a control group with the selected owned mobile units; assigning with no mobile selection clears it. Press **1–9** to recall a populated group, or double-tap the same number within **0.3 seconds** to recall and center the camera. Assignment and recall preserve unit orders. Empty recalls do nothing, and newly produced units join only when explicitly assigned. A single assigned group reads **Group 3 · 2 units**; multiple groups use numbered chips with valid unit counts (`u` means units), with full descriptions on hover. Death, ownership and field membership govern eligibility; Restart clears groups and timing, and window or GUI focus changes clear double-tap timing. Group shortcuts yield to consumed UI input and are inactive during placement or frozen results. Earlier scenes retain their defaults. See the [M8 report](docs/milestone-8.md) for the tactical-interface baseline and the [M8.1 report](docs/milestone-8.1.md) for the current HUD validation and retained failures.

**Milestone 8.1** replaces the combined-arms scene's permanent controls guide with **Help** and **F1 Help · F3 Debug**. Help starts closed, opens by click or F1, and closes by the same controls or Escape. Opening it leaves the simulation running. When open Help owns Escape, that press closes Help; another Escape can cancel active placement. Help and contextual panels consume their own pointer input while leaving the uncovered battlefield and minimap usable. Restart returns Help to its compact state.

Credits remain visible in the upper-right panel. The actual selection determines the remaining content: a neutral prompt, one unit's identity/HP/status, mixed-unit counts, collector cargo/activity and assigned supply contents, or the existing HQ/site/producer controls. Production queues keep their prices, progress, Cancel controls and blocked-exit feedback. Selected or damaged actors show compact health bars; exact mobile names/HP and collector details live in the selection panel. Buildings and supplies keep compact identifying labels, and blocked-fire warnings remain visible. F3 reveals detailed world health/movement and access diagnostics. Normal gameplay has no hardware-statistic overlay. The compact objective retains the **90-simulated-second** assault countdown; the **600-second** delay seen in some automated captures belongs only to isolated test instances.

## Controls

To play **Supply Depot Assault**, open `scenes/supply_depot_assault.tscn` and press **F6**, or run `& $godot --path . res://scenes/supply_depot_assault.tscn`. Select your HQ, choose **Build Supply Depot**, then place on valid clear ground. A depot costs **300 credits**, takes **10 simulated seconds** after navigation readiness, and completes with **450 HP**. One unfinished site is allowed. It uses a 6 × 5 footprint, six delivery bays and a separate production exit. Current automatic HQ construction is the prototype; the scheduled builder feature will move building choices and active construction to Bulldozers.

Select a completed owned depot to **Train Collector Truck** for **200 credits / 6 seconds**, with five outstanding queue slots. New trucks use the existing unarmed 150-HP, speed-4, capacity-100 configuration. They rally using ordinary movement and need a supply assignment. Right-click a cache with a collector selected to gather and automatically return to the shortest usable owned HQ/depot navigation route. A valid ongoing delivery retains its target; failed automatic return permits one alternative, then blocks safely with cargo retained. Right-click an owned HQ or depot with cargo to deliver once and idle. Ground Move or X Stop retains cargo and cancels harvesting. Supplies remain neutral resources; depots do not grant exclusive cache ownership.

Full unloading takes one simulated second, then each supply credits the owner's existing wallet exactly once. A lost collector loses its undeposited cargo. Cancelling an unfinished site refunds its captured construction payment once; a completed destroyed building has no construction refund. Paid undeployed Collector jobs refund on cancellation or producer destruction; deployed units remain independent. **Exit blocked** holds a paid completed job and retries safe deployment every 0.25 simulated seconds. Depot destruction is not a match objective; HQ loss and Restart retain the existing rules. Selected collectors show cargo/activity and their current drop-off; depots use **D** minimap markers. See the [M11 report](docs/milestone-11.md) for exact evidence and limits. Supply trucks gather and deliver; they do not construct buildings.

To play the **enemy economy and repeat assaults** scenario, open `scenes/economy_assault.tscn` and press **F6**, or run `& $godot --path . res://scenes/economy_assault.tscn`. F5 remains the original movement field. The enemy adds one completed barracks, two Collector Trucks and a separate finite 2000-supply cache, starting with 300 credits. Its collectors make normal repeated trips to its own HQ; its barracks spends the normal 100 credits and five seconds per Rifle. Newly produced troops rally to staging and launch in groups of three, no earlier than 90 simulated seconds and at least 60 seconds between accepted waves. A one/two-unit group waits 30 seconds after assembly. Population is capped at 12 living enemy combat units plus paid pending jobs; starting defenders count, collectors do not. Settings live in `scenarios/enemy_economy.tres` / `EnemyEconomyConfig`.

Player economy, construction, Rifle/Rocket production, minimap, groups and Q/X controls remain available. The new opponent uses existing attack-move, has no free waves, rebuilds or tactical micromanagement, and eventually exhausts its cache. Destroying its barracks stops further production and refunds only undeployed paid jobs; existing troops continue. The objective shows the earliest first assault, then “Enemy reinforcements active,” since production and travel can delay actual launches. Older base-assault and combined-arms scenes keep their one-shot 90-second assault. See the [M10 report](docs/milestone-10.md) for actual validation and fixture limits.

**Milestone 9 Attack Move:** select existing Rifles and/or Rocket Vehicles, click **Attack Move · Q** or press **Q**, then left-click navigable battlefield ground or valid minimap content. Right-click or Escape cancels pending targeting. Entering or cancelling targeting leaves existing orders intact; invalid destinations retain targeting with rejection feedback. During targeting, minimap left-click confirms the destination. Outside targeting it still centers the camera, and ordinary ground/minimap right-click remains Move. A remains camera pan.

Attack-moving combat units scan every **0.25 simulated seconds** within **12 world units**, choose the nearest eligible hostile with a clear existing firing line (stable identity breaks ties), and use ordinary pursuit and weapons. Their original final slots remain reserved while fighting. They resume those same slots after the engagement and return to ordinary idle on arrival. The leash is **16 units from the attacker's acquisition position**; continuously blocked fire is abandoned after **2 seconds**, observed at scan intervals. Abandoned targets are ignored locally for **3 seconds**. Explicit Attack retains its existing persistent blocked-fire behavior. This adds no idle scanning, flanking, weapon changes or enemy assault changes. Mixed selections leave collectors and their cargo/work untouched. See the [M9 report](docs/milestone-9.md) for acceptance and limitations.

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
| Right click a hostile HQ or completed barracks (base assault) | Attack the building with selected combat units |
| Restart on the base-assault result | Load a fresh initial match after victory, defeat or draw |
| X | Stop selected units' movement, combat and harvesting; retain loaded cargo; S remains camera pan |
| Attack Move button / Q (combined arms) | Target battlefield or minimap ground with selected combat units; auto-engage encountered hostiles and resume the original final slots |
| Right click / Escape while Attack Move targets ground | Cancel pending targeting without issuing a replacement order; open Help retains its Escape-close priority |
| Escape | Close open Help when it owns input; otherwise cancel the current selection gesture or placement |
| Help button / F1 (combined arms) | Open or close the full controls guide; simulation continues |
| F3 | Toggle movement/combat diagnostics, detailed world health and construction/access outlines |
| T (line-of-fire scene only) | Move the marked rocket target into/out of the wall shadow |
| Click or Shift-click an owned building (production scene) | Select that building alone and clear unit selection |
| Right click ground with barracks selected | Set rally for future deployments; preserve current units' orders |
| Train / Cancel in barracks panel | Enqueue a paid Rifle / refund that undeployed job |
| Build Supply Depot at HQ (depot assault prototype) | Place a 300-credit depot with ten seconds of automatic construction |
| Train / Cancel in completed Supply Depot | Enqueue a 200-credit Collector Truck / refund that undeployed job |
| Right click supply with collectors selected (harvesting scene) | Begin or replace automatic harvesting |
| Right click owned HQ or operational depot with loaded collectors selected | Return to that building and deposit once, then idle |
| Build Barracks at owned HQ (construction scene) | Enter free placement mode |
| Left click ground while placing | Request a validated site at the selected building's displayed price |
| Right click while placing | Cancel placement without issuing a unit order |
| Cancel construction in selected-site panel | Refund the unfinished site's original payment and restore terrain |
| Left click minimap content (combined arms) | Center the existing camera; preserve zoom, selection and orders |
| Right click minimap content (combined arms) | Ordinary ground Move for selected eligible mobile units |
| Ctrl + 1–9 (combined arms) | Replace that group with selected mobile units; empty selection clears it |
| 1–9 (combined arms) | Recall valid group members; empty groups do nothing |
| Double-tap the same 1–9 within 0.3 seconds (combined arms) | Recall and center the camera on that group |

The controls/Help panel consumes pointer input and suspends camera movement while hovered. X still stops selected units over passive HUD content; a focused UI control that consumes X keeps the event. Releasing a drag over the controls/Help panel cancels the gesture. Losing application focus or leaving the window also cancels a drag. Shift is sampled when a selection gesture begins. Shift-clicking empty ground preserves selection. Clicks on obstacles or beyond the ground issue no move order; ground points near the boundary are projected onto navigation.

Building selection is separate from the unit-only `selected_units()` API. Selecting units, dragging a selection box, or normally clicking empty ground clears the building. Hostile buildings cannot be selected. Barracks do not issue attacks; X never cancels production. Production GUI controls consume pointer events and validate current membership/ownership again when activated.

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

Rockets use a configurable **0.1-unit spherical world-collision radius**, copied at launch. Launch additionally requires that sphere to be clear. Flight explicitly checks initial overlaps and sweeps the full sphere using Godot shape queries. Query margin is a separate conservative **0.0001 units**. A centerline-clear rocket can graze a wall with its volume. The visible flying sphere matches the configured radius; F3 shows the launch volume.

Attempted travel is clipped to both target aim and remaining lifetime. An already expired rocket cannot move; otherwise valid world/target contact within the usable interval resolves before expiry. World contact wins numerical ties with target arrival, while a sufficiently distant wall behind the target does not cancel damage. The original point target-arrival model and hitscan line queries remain unchanged. This is line of fire; target awareness and selection are unchanged. There is no splash damage, cover bonus or attack-move.

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
| `scripts/production_field.gd`, `scripts/rts_building.gd` | Fixed base geometry, initial navigation footprints, producer membership and safe spawn admission |
| `scripts/player_credits.gd`, `scripts/unit_production.gd`, `scripts/production_result.gd` | Field-local funds, isolated FIFO jobs, captured refunds and explicit acceptance |
| `scripts/production_definition.gd`, `production/rifle.tres`, `scenes/rifle_unit.tscn` | Shared recipe and the existing Rifle configuration; no mutable jobs in Resources |
| `scripts/production_panel.gd`, `tests/production_checks.gd` | Minimal GUI and production, input, lifecycle and combat integration checks |
| `scripts/harvest_field.gd`, `scenes/harvesting_test.tscn` | Playable harvesting field, finite-cache membership and bounded local access claims |
| `scripts/collector_truck.gd`, `scripts/collector_harvest.gd` | Primitive unarmed unit using the existing mover and separate timed cargo/order state |
| `scripts/supply_cache.gd`, `scripts/harvest_transfer.gd` | Finite instance inventory and historical committed transfer values |
| `scripts/harvest_panel.gd`, `tests/harvesting_checks.gd` | Contextual cargo UI and real-trip, callback, lifecycle, conservation and earned-production checks |
| `scripts/construction_field.gd`, `scenes/construction_test.tscn` | Barracks-free starting scene, full-footprint validation and protected access geometry |
| `scripts/building_construction.gd`, `scripts/construction_site.gd`, `scripts/construction_result.gd` | Stable paid sites, bounded lifecycle, captured refunds and historical acceptance |
| `scripts/construction_navigation.gd` | Serialized rectangle meshes, map/region iteration checks and query readiness |
| `scripts/construction_definition.gd`, `construction/barracks.tres` | Barracks cost/time/height configuration and fixed footprint |
| `scripts/building_placement.gd`, `scripts/construction_panel.gd`, `scripts/construction_building.gd` | Free ghost input, contextual controls and ordinary producer presentation |
| `tests/construction_checks.gd` | Viewport, accounting, topology, lifecycle, failure and earned construction/combat checks |
| `tests/parked_deadlock_checks.gd`, `tests/parked_deadlock_controls.gd` | Captured parked-neighbor reproduction, reachability controls, bounded failure and recovery interruption |
| `tests/captured_parked_cluster_checks.gd`, `tests/fixtures/parked_cluster_capture.json` | Both captured movers with all 48 stationary neighbors, original goals and recorded source provenance |
| `scripts/base_assault_field.gd`, `scenes/base_assault.tscn` | Integrated bases/economy, opt-in building health, one scripted assault and end-of-physics result/restart |
| `tests/base_assault_checks.gd` | Building weapons/input, destruction/refunds, actual defeat, same-tick draws and earned-credit victory/restart |
| `scenes/combined_arms_assault.tscn` | Combined-arms composition with explicit tactical-interface opt-in |
| `scripts/minimap_mapping.gd`, `scripts/tactical_minimap.gd` | Shared aspect-preserving conversion, clipped camera footprint, registry markers and minimap input |
| `scripts/control_groups.gd` | Field-scoped weak membership, named 1–9 actions and real-time double-tap handling |
| `tests/tactical_interface_checks.gd`, `tests/control_group_checks.gd` | Focused viewport, geometry, lifecycle, keyboard and produced-army integration checks |
| `tools/validate-m8.ps1` | Fresh source copies, bounded M8/regression phases, preserved logs/hashes/artifacts and aggregate results |
| `construction/supply_depot.tres`, `scenes/supply_depot_assault.tscn` | Depot defaults and opt-in economy-assault composition |
| `production/collector_truck.tres`, `scenes/collector_truck.tscn` | Paid production of the existing unarmed Collector Truck |
| `tests/supply_depot_checks.gd`, `tests/supply_depot_integration_checks.gd` | Depot lifecycle/UI/routing and real earned depot-to-collector-to-Rifle coverage |

The field partitions a flat `NavigationMesh` at obstacle edges expanded by 0.85 units, producing connected convex polygons with holes. Geometry and navigation use the same obstacle definitions. Agents advance along navigation paths in physics ticks; step lengths are bounded to prevent overshoot and positions stay on the clearance mesh. `CharacterBody3D` collisions provide an additional solid obstacle boundary.

Group commands generate a deterministic compact lattice with configurable spacing (default 1.5), a group-size-dependent radius capped at 18, and a 1,600-candidate ceiling. Slots are projected onto navigation and checked for connectivity; spatial buckets reject duplicates and preserve reservations belonging to unselected units. Coordinate ordering followed by three pair-swap passes gives O(n²) assignment work with stable ties. Assignments change only on a new order. Commands that cannot provide enough distinct, reachable slots are rejected together, preserving the previous order.

`TestField.issue_move`, `issue_attack` and `issue_stop` return `CommandBatchResult`: a field-local request generation, intended and accepted stable unit IDs, `NONE`/`PARTIAL`/`COMPLETE` acceptance, `superseded`, and accepted movement assignments by ID. Acceptance is historical: a callback can replace an accepted order before dispatch returns. Use `is_complete() and not superseded` for a whole unsuperseded batch, or `has_acceptance()` for any historical acceptance. Never use object truthiness. Route tests retain fresh per-unit versions and capture assignments from the result. `last_command_result` and `last_command_slots` are diagnostics; pre-dispatch rejection preserves prior command snapshots and superseded dispatch cannot overwrite newer reporting. The field registers its units and handles `tree_exiting` immediately; detached or freed units no longer participate in selection, commands or reservations. Internal reparenting restores membership on tree entry.

Crowd movement uses Godot's RVO avoidance with ten nearby neighbors and a short prediction horizon. Soft avoidance radii allow limited shoulder contact near destinations or during congestion. Parked rows can still close a direct passage; bounded recovery can attempt a local route around them. Every step remains constrained to navigation and physical obstacles. Arrived units hold position and never rearrange their final slots.

Units distinguish travelling, congested, recovering, arrived and failed. Progress means reducing the **remaining navigable path length**, sampled every 0.75 seconds; side-to-side oscillation cannot keep resetting the stuck timer. After 2.25 seconds without meaningful progress, recovery samples up to 12 local detours or requests a repath, with at least 2.5 seconds between attempts. Detours expire after two seconds or end sooner when meaningful progress resumes. Ending temporary recovery preserves the per-order attempt count. An order that remains blocked after eight recovery attempts, or reaches its 90-second deadline, fails safely. A replacement order clears prior timers, temporary targets, velocity and recovery state immediately. Transitions publish coherent state before invoking synchronous listeners, and an obsolete transition cannot overwrite a listener's replacement order.

Recovery checks actual candidate path segments against nearby stationary agents' combined avoidance radii. At the first waypoint it may choose one further local waypoint if returning to the final destination is still blocked. Both legs share the original two-second attempt duration, progress history and eight-attempt budget. Local broad-phase queries return at most 64 bodies and run only at recovery or continuation; no per-frame all-unit scan is added. This remains a bounded heuristic, not a guarantee that every reachable crowded destination can be found.

Change only `unit.crowd_enabled` to toggle avoidance, including during movement. Its setter synchronizes the agent and clears pending velocity state. The movement callback rejects disabled or obsolete submissions, and a physics-frame guard prevents a mode change from applying two movements in one tick. Scene defaults and crowd tuning are unchanged by Milestone 1.5.1.

There are no global managers or autoloads. Selection emits signals for count feedback and movement requests. The scene wires these to destination assignment; indicators never own selection state. Configuration is exposed with typed exports in the relevant scripts. Because this scene is constructed at runtime, edit those defaults or inspect the Remote scene while running.

Combat health/death components are created when a unit has a weapon definition or explicitly enables `damageable`; the latter permits an unarmed collector without a weapon emitter. Attack permission still requires an actual weapon. Armed units also have a match-local `AttackMoveOrder` coordinator; only an accepted active parent scans or resumes movement. `TestField.issue_attack_move` uses the same `CommandBatchResult` contract, retaining all intended mobile identities and assigning final slots only to eligible combat participants. The movement fields retain their original configuration. Unit-level command APIs retain bools; field-level commands return the batch result described above. Group authority is captured before selection queries and guarded during dispatch. Internal `retarget_pursuit()` keeps the movement order, stall clock, signed path-progress credit/debt and recovery history. Rebasing compares old/new path lengths at the same attacker position, so a changing target alone earns no progress. A real detour keeps its waypoint and expiry; a fallback repath tracks the new destination. Real replacement orders still clear per-order state. Selection and targeting require live membership in the owning field, using an O(1) registration lookup plus tree/ancestry checks.

## Validation

The [Milestone 11 report](docs/milestone-11.md) records depot acceptance, the corrected return comparison, source correspondence, every retained failed phase, final matrix commands and viewport evidence. The current expanded matrix includes both M11 suites and all M10 regression suites in headless and graphical modes on a fresh source-hashed copy.

The [Milestone 9 report](docs/milestone-9.md) records current attack-move acceptance and execution results. Completed HUD/tactical acceptance remains in [Milestone 8.1](docs/milestone-8.1.md); the [Milestone 8 report](docs/milestone-8.md) retains the original tactical scaffold and baseline. `tools/validate-m8.ps1` runs selected suites or the normal regression matrix through the existing external wrapper; use a new phase name for every execution so prior evidence is retained.

M9's original complete matrix passed **56 executions / 7,116 checks**. Final source coverage reuses **50 executions / 6,277 checks** and replaces the affected HUD, attack-move UI and tactical-interface results with **six post-layout executions / 855 checks**: **7,132 passing checks**, zero failures/native error lines, all exits 0. Both normally produced combat units deal damage, physically resume travel and reach their original distinct slots. The report retains earlier failures, source hashes, exact commands and current captures. No human playtest occurred.

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
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/spherical_projectile_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/spherical_projectile_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/production_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/production_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/harvesting_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/harvesting_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/construction_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/construction_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/base_assault_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/base_assault_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/vehicle_production_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--path', '.', '--fixed-fps', '60', '--script', 'res://tests/vehicle_production_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'res://tests/combat_checks.gd', '--', '--combat-load')
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
git diff --check
```

The runners inject events through Godot's viewport and Input APIs, exercise actual selection raycasts and navigation, and exit nonzero on assertion failure. Each movement wait has a simulation deadline. The inherited 180-second in-process watchdog gives diagnostics while the Godot event loop remains responsive; it cannot interrupt a synchronous block. The external wrapper defaults to 240 seconds, accepts `-TimeoutSeconds`, terminates the child process tree on expiry, and returns **124**. Normal child codes are reported and preserved; wrapper launch errors return **125**. Read `$LASTEXITCODE` immediately after each command; a CI/shell entry point should end with `exit $LASTEXITCODE` to propagate that command's exact result.

The wrapper self-test deliberately checks the internal watchdog's **2**, the unarmed blocking fixture's **3**, and the armed blocking fixture's external **124**, then returns **0** only if all checks pass. Expected failure logs are separate from ordinary validation. The blocking fixture requires `-- --verify-external-timeout` and is never loaded by a normal suite. See the corrective report for standalone commands.

Post-arrival checks sample all 180 physics ticks over three simulated seconds, requiring maximum displacement below 0.001 world units, ARRIVED state, no active movement, and velocity below 0.001. Overlap measurements sample center distances below 0.6 at 10 Hz: pair-seconds sum those sampled durations over pairs; the longest run estimates consecutive sampled overlap, not continuously observed contact.

Graphical checks write screenshots to ignored `validation-output/`; stress checks also write `stress-metrics.json`. Test playback uses fixed simulation FPS and disables VSync in the test harness only. The main playable scenes retain their normal display settings. Performance observations describe this instrumented playback, not a promised game frame rate. Keep the game focused and avoid physical input during graphical input playback.

Combat validation combines real input, health, cooldown, order-version and physics assertions with eight graphical captures. Its engine-error probe fails the run on errors or warnings, including during field teardown. The separate `--combat-load` check starts 12 units per team, runs a fixed 12-second engagement, stops survivors and verifies outstanding projectile cleanup after their lifetime. Its metrics are written to `validation-output/combat-load-metrics.json`. Normal scenes do not load test instrumentation.

See [Milestone 2.5.1 spherical collision and current acceptance evidence](docs/milestone-2.5.1.md), [Milestone 2.5 historical point-collision results](docs/milestone-2.5.md), [Milestone 2.0.1 corrections](docs/milestone-2.0.1.md) and the qualified [Milestone 2 architecture and historical validation](docs/milestone-2.md). Historical movement evidence remains in [Milestone 1.5.1](docs/milestone-1.5.1.md), [Milestone 1.5](docs/milestone-1.5.md) and [Milestone 1](docs/milestone-1.md). Every current stress route proves complete unsuperseded acceptance, new unit versions and captured assignments. Automated input playback and captured-frame inspection were performed; a human keyboard/mouse playtest was not performed.

## Scope and limits

- Crowd avoidance reduces overlap but permits partial contact. It is not rigid vehicle collision. Successful runs settle at distinct positions; the documented cluster congestion can exhaust recovery and require a replacement order.
- Navigation supports these flat fields and serialized barracks placement/cancellation in the construction scene. Slopes, arbitrary moving geometry, frequent large-map rebuilding, opposing traffic through a gate, and crowds above 50 need separate validation.
- Assignment reduces straight-line travel; it does not solve a global minimum-cost path assignment around obstacles.
- Weapon obstruction supports marked static primitive convex shapes and swept spherical rockets. Moving blockers, arbitrary concave meshes, bouncing and projectile pathfinding are outside the tested scope. Other units do not intercept shots.
- Combat has no visibility filtering, cover bonuses, automatic repositioning, splash damage or armor multipliers. Attack-move acquisition is limited to eligible nearby hostiles with an initially clear firing line and an active player order.
- The tactical map is fully revealed and fixed in orientation. Control groups contain locally owned mobile units only and persist for the current match; they do not save, include buildings or automatically absorb newly produced units.
- Production, harvesting and construction demonstrations remain available separately; base assault integrates them and adds damage/destruction for HQs and completed production buildings. Combined arms adds the Vehicle Factory and existing Rocket Vehicle recipe; Supply Depot Assault adds depot production of the existing Collector Truck. No builders, building repair/capture/sale, power, technology, further unit recipes, resource regeneration, trading, cargo drops, fog of war, strategic AI or multiplayer are implemented. All visuals are original generated primitives.

Physical-input construction/harvesting/production/combat playtesting, opposing traffic and varied terrain remain separate work. Production is limited to flat geometry, normal simulation timing and a small local exit search; harvesting has eight local access slots per target and can fail safely under permanent obstruction. Neither physics lockstep determinism nor universal frame-rate behavior is claimed.
