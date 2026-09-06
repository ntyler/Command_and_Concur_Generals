# Milestone 2 — Basic RTS combat foundation

Validated on 2026-09-06 with **Godot 4.7.2.stable.official.ed1daf0bf**, Windows, PowerShell 7.6.5, and the Compatibility renderer. Graphical runs used an NVIDIA GeForce RTX 2070 SUPER, OpenGL 3.3, driver 610.88. The original reported verdict was **ACCEPT within the tested flat, static-field scope**; the subsequent review found five coverage/correctness gaps. See the qualification below and [Milestone 2.0.1](milestone-2.0.1.md) for repaired acceptance evidence. No commit was made and no later milestone was started.

## Preflight and preserved baseline

The repository was clean at `9a297df` (`Complete RTS movement robustness milestone 1.5.1`). No applicable `AGENTS.md` existed in the repository or its ancestors. README, all three previous milestone reports, project configuration, original/stress scenes, movement/selection/destination scripts, movement tests and the external wrapper were read before editing. The complete initial diff was empty.

All baseline suites passed before implementation; there were **no pre-existing failures in this run**. Historical variability recorded in Milestone 1.5.1 remains historical evidence, not a failure attributed to this baseline.

| Baseline suite | Checks / failures | Exit | Evidence in `validation-output/` |
| --- | --- | --- | --- |
| Milestone 1 headless | 126 / 0 | 0 | `m2-pre-original.log` |
| Milestone 1 graphical | 130 / 0 | 0 | `m2-pre-original-graphical.log` |
| Movement stress headless | 118 / 0 | 0 | `m2-pre-stress.log` |
| Movement stress graphical | 127 / 0 | 0 | `m2-pre-stress-graphical.log` |
| Movement repair | 73 / 0 | 0 | `m2-pre-repair.log` |
| External wrapper self-test | 5 / 0 | 0 | `m2-pre-wrapper.txt` |

Integration was limited to optional unit composition, field registration and dispatch, contextual input, and a named Stop action. Camera code, destination generation/assignment, original/stress scenes, previous tests, previous milestone reports and the wrapper were not changed. No movement tuning value was changed.

## Acceptance review qualification

The tables and measurements below preserve the original Milestone 2 runs. Their successful exits remain valid historical evidence; they did not cover every command/callback interaction. The subsequent read-only review reproduced five gaps: X over passive UI, moving-target refreshes starving recovery, selection-pruning reentrancy, immediate source deletion during hitscan damage, and ambiguous partial group acceptance. The original all-PASS checklist was therefore insufficient for full acceptance. [Milestone 2.0.1](milestone-2.0.1.md) records the failing reproductions, repairs, revised batch API and current validation. No historical successful run is reclassified as a failed run.

## Playable scene and controls

Launch `res://scenes/combat_test.tscn` directly or open it in the editor and press F6. F5 still launches the original movement field. The combat field uses the original field's fixed camera at focus `(0, 0, 0)`, zoom 52, and bounds `x = ±29`, `z = ±23`.

Each team has four Rifle Units and two Rocket Vehicles. Alpha is mint and locally controlled; Bravo is coral with retaliation enabled. Fixed spawns are defined in `CombatField.STARTS`. Two obstacles share their definitions with navigation generation: `Rect2(-5, -12, 4, 6)` and `Rect2(4, 5, 5, 6)`. The controls panel explains the teams and range-only combat.

- Left click or drag selects Alpha; Shift keeps the existing add/toggle behavior.
- Right-click a living hostile to attack. Right-click valid ground to move. Friendly-unit clicks issue no attack or replacement movement.
- **X** is the named `unit_stop` action. It stops movement and combat. Original tests covered the world pointer position; 2.0.1 repairs/tests passive-panel hover while respecting focused controls that consume X. S remains the existing camera-back control, preserving WASD.
- Camera, zoom, selection cancellation and F3 movement debugging retain their controls. Movement debugging remains disabled by default.

Bravo does not acquire targets or attack at startup. Health bars and unit-name/current-health labels are always visible. Hits show a white flash for 0.12 simulated seconds; rifles show a short tracer; rockets are visible yellow primitives. Death immediately hides and queues the unit for deletion.

## Architecture and ownership

| File | Responsibility |
| --- | --- |
| `scripts/health.gd` | Reusable health and damage/death notifications, independent of visuals and team policy |
| `scripts/team_rules.gd` | Central membership, local control, hostility and damage-target checks |
| `scripts/weapon_definition.gd`, `weapons/rifle.tres`, `weapons/rocket.tres` | Minimal typed weapon configuration |
| `scripts/weapon_emitter.gd` | Simulation cooldown, final firing checks, immediate damage or projectile launch |
| `scripts/combat_controller.gd` | Per-unit versioned attack orders, pursuit, facing, retaliation and death coordination |
| `scripts/guided_projectile.gd` | Independent shot data, guided travel, bounded lifetime and one impact |
| `scripts/combat_feedback.gd` | Team materials, health labels/bars, hit flash and tracer presentation |
| `scripts/combat_field.gd`, `scenes/combat_test.tscn` | Fixed two-team layout built through the existing field |
| `scripts/rts_unit.gd` | Existing locomotion plus optional combat composition, safe halt and visual yaw helpers |
| `scripts/test_field.gd` | Live registration lookup and versioned selected-group command dispatch |
| `scripts/selection_controller.gd`, `project.godot` | Contextual command raycasts and X Stop input |
| `tests/combat_checks.gd`, `tests/engine_error_probe.gd` | Integration/load validation and native engine-error capture |

The existing integer `owner_id` is the team identity; there is no second parallel ownership property. Equal IDs are friendly; different IDs are hostile. Local selection requires owner 1 and live membership in the owning field. A valid attack also requires both units to have combat components. Membership checks reject dead, detached, queued-for-deletion, unregistered and outside-field units. The registry uses an O(1) dictionary lookup plus tree/ancestry checks; the existing unit list remains available for selection and commands.

Health accepts attributed damage without knowing diplomacy. Weapon and projectile damage goes through `TeamRules.damage_target`; retaliation validates the attributed source through the same ownership rules. Changing ownership emits availability notification, refreshes the tint and cancels an order if its target is now friendly. This does not implement diplomacy or cross-field transfers.

Combat is composed only for units with a weapon resource. `RTSUnit` remains the only normal unit mover. The controller executes before the mover using `process_physics_priority = -10`; Godot orders lower physics priorities first. Target and projectile references use `WeakRef`, whose `get_ref()` returns null after the object is destroyed. See the primary [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-property-process-physics-priority) and [WeakRef](https://docs.godotengine.org/en/stable/classes/class_weakref.html) documentation.

## Health and death lifecycle

`UnitHealth.maximum` is configurable and initializes `current` on ready. An invalid/nonpositive maximum falls back to 1. `apply_damage` returns the amount actually removed, clamps health at zero, and rejects nonfinite/nonpositive values or damage after death as a zero-return no-op with no notification. Accepted damage emits `damaged(amount, source)`; a lethal application emits `died(source)` exactly once. Health is already zero before callbacks, including nested damage callbacks.

Death coordinates these steps synchronously: clear the combat target and temporary chase state; halt and clear movement/recovery; disable collision, crowd avoidance and physics; unregister from the field; remove selection and destination participation; notify current attackers; hide and `queue_free`. Health rejects orders immediately through shared alive/member checks, including before deferred deletion. There is no separate persistent combat reservation cache. Existing move reservations derive from current registered units, so unregistration releases them.

Departure uses the existing field tree-exit path. Target death, detachment, free, reparenting outside the field and becoming friendly cancel attackers safely. Halting checks whether debug-marker children are still inside the tree because children can exit before the unit's `tree_exiting` signal. A live unit can accept a later command after an ordinary failure or target invalidation.

## Orders, pursuit and facing

The original unit and field APIs returned bool acceptance. Invalid targets and invalid weapon definitions rejected without advancing unit orders. Versions protected replacements during per-unit dispatch, but review found an earlier callback boundary in selection queries and ambiguity after partial acceptance. In 2.0.1, unit APIs retain bools; field Move/Attack/Stop return `CommandBatchResult` with stable intended/accepted IDs, request generation, acceptance extent, supersession and accepted movement assignments. Authority is checked across selection queries and dispatch. Acceptance records history, not whether an order remains active. See the corrective report for the full contract and caller migration.

| State | Meaning and transition |
| --- | --- |
| `NONE` | No attack target; ordinary movement or Stop can still have player priority |
| `PURSUING` | Valid target outside range; navigation chase is submitted/updated on the bounded schedule |
| `FACING` | Movement stopped; turning to the target, or holding just outside actual range within hysteresis |
| `ATTACKING` | In actual range, stopped and aligned; fire when cooldown permits |
| `TARGET_INVALIDATED` | Target unavailable or pursuit cannot continue; motion/target cleared, then `NONE` on the next physics tick |

Order preparation clears the old target connection, pursuit timer, update history and recovery budget before any public transition signal. Signals publish only on state changes. Version checks follow synchronous emissions. A replacement ground move publishes `NONE` only after its movement state is coherent. Halting uses the mover's settled `ARRIVED` state at the current position rather than adding another locomotion state.

Pursuit proposes a point 85% of weapon range from the target in the attacker's direction, projects it onto navigation and verifies a reachable path endpoint. It waits for a synchronized navigation map before querying. The first chase can submit on the next physics tick. Later updates are checked no more often than every 0.5 simulated seconds and require target displacement of at least 1 unit, no existing chase, or a chase that has stopped. A stationary target does not cause periodic path rebuilding while a valid chase continues.

Chase movement uses the existing mover with crowd avoidance and bounded recovery. The original controller retained a cumulative 90-second pursuit deadline and eight-attempt cap, but calling `move_to` on each refresh erased the mover's stall/progress clocks: the cap alone did not prove recovery could activate. In 2.0.1, internal retargeting preserves those clocks, signed progress/debt and active recovery state. New chase legs still use `move_to`, retaining cumulative attack limits. Unreachable/exhausted pursuit clears the attack safely. This is a simple near-target heuristic; it is not tactical firing-position optimization or a new formation allocator.

At distance at most weapon range, the controller stops movement and turns the visual body around Y at 4 radians per simulated second. It fires only within 8 degrees of the target. Position and navigation/selection anchors are not rotated. It holds through a 0.75-unit range margin, resuming pursuit beyond `range + 0.75`; holding outside actual range never authorizes a shot. Tests oscillate a target inside that band and then move it beyond the margin.

## Weapons and retaliation defaults

| Setting | Rifle Unit | Rocket Vehicle |
| --- | --- | --- |
| Maximum health | 100 | 150 |
| Weapon mode | `HITSCAN` | `GUIDED_PROJECTILE` |
| Damage | 12 | 32 |
| Range | 8 | 11 |
| Cooldown | 0.75 s | 1.8 s |
| Facing tolerance | 8 degrees | 8 degrees |
| Projectile speed / maximum lifetime | Unused | 9 units/s / 6 s |

The weapon resource also carries the display name. Damage, range and cooldown must be finite and positive; facing tolerance must be finite and nonnegative. Guided mode requires finite positive speed and lifetime. These are placeholder values, not a balance claim.

Cooldown advances with physics delta, not wall-clock time. Final firing checks revalidate the source, target, actual distance, movement, facing and cooldown. The cooldown and shot count are established before damage callbacks, preventing reentrant duplicate fire. Cooldown intentionally survives order replacement and Stop so rapid input cannot bypass fire rate.

Hitscan damage occurs synchronously at successful fire; a surviving emitter's `fired` signal sees updated health and established cooldown. Original tests did not cover a damage listener immediately freeing the source. Milestone 2.0.1 treats that callback as a destruction boundary: committed firing still returns true, and a destroyed emitter does not access or emit its notification. The tracer has no damage authority. Guided fire creates one field-owned projectile with copied damage, speed, lifetime, launch team and weak source/target references. Its original target cannot be changed by later source commands. It applies no launch damage, moves over simulated time and resolves once at impact, with the spent flag set before damage callbacks. Lifetime expiry takes priority if the lifetime limit is reached on the same tick. Invalid targets cause a harmless despawn. A departed/dead source does not erase the shot; impact still requires its original target to be registered, alive and hostile to the launch team. Attribution is null if the source no longer exists.

Retaliation defaults off on generic combat units and on for Bravo in the combat scene. Accepted damage can start the same attack-order path against a valid hostile source only when no higher-priority player command or existing attack target is present. Active player movement and explicit attacks take priority. A completed move releases its temporary priority; X Stop holds it until another player order. There is no idle auto-acquisition, repeated per-frame order creation or strategic AI.

## Validation commands and results

Run from the repository root in PowerShell 7. The engine path below resolves to the installed portable executable. Every gameplay validation uses the existing external wrapper; its default deadline is 240 seconds. The inherited responsive-loop watchdog is 180 seconds. Fixed 60 Hz simulation and disabled VSync apply only to test playback, not normal gameplay.

```powershell
$godot = Join-Path $env:LOCALAPPDATA 'Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$run = @{ GodotPath = $godot; TimeoutSeconds = 240 }
& .\tools\run-godot.ps1 @run -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','validation-output/m2-import.log')
& .\tools\run-godot.ps1 @run -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/milestone_checks.gd','--log-file','validation-output/m2-original.log')
& .\tools\run-godot.ps1 @run -GodotArguments @('--path','.','--fixed-fps','60','--script','res://tests/milestone_checks.gd','--log-file','validation-output/m2-original-graphical.log')
& .\tools\run-godot.ps1 @run -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/movement_stress_checks.gd','--log-file','validation-output/m2-stress.log')
& .\tools\run-godot.ps1 @run -GodotArguments @('--path','.','--fixed-fps','60','--script','res://tests/movement_stress_checks.gd','--log-file','validation-output/m2-stress-graphical.log')
& .\tools\run-godot.ps1 @run -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/movement_repair_checks.gd','--log-file','validation-output/m2-repair.log')
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
& .\tools\run-godot.ps1 @run -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/combat_checks.gd','--log-file','validation-output/m2-combat.log')
& .\tools\run-godot.ps1 @run -GodotArguments @('--path','.','--fixed-fps','60','--script','res://tests/combat_checks.gd','--log-file','validation-output/m2-combat-graphical.log')
& .\tools\run-godot.ps1 @run -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/combat_checks.gd','--log-file','validation-output/m2-combat-load.log','--','--combat-load')
& .\tools\run-godot.ps1 @run -GodotArguments @('--path','.','--fixed-fps','60','--script','res://tests/combat_checks.gd','--log-file','validation-output/m2-combat-load-graphical.log','--','--combat-load')
```

Capture `$LASTEXITCODE` immediately after each wrapper invocation. Successful final results:

| Validation | Checks / failures | Exit | Log |
| --- | --- | --- | --- |
| Workspace editor import | Clean | 0 | `m2-import.log` |
| Fresh-copy editor import, with no `.godot` cache | Clean | 0 | `m2-clean-import.log` |
| Milestone 1 headless / graphical | 126 / 0; 130 / 0 | 0 each | `m2-original*.log` |
| Movement stress headless / graphical | 118 / 0; 127 / 0 | 0 each | `m2-stress*.log` |
| Movement repair | 73 / 0 | 0 | `m2-repair.log` |
| Wrapper self-test | 5 / 0 | 0 | `m2-wrapper.txt` |
| Combat headless / graphical | 168 / 0; 176 / 0 | 0 each | `m2-combat.log`, `m2-combat-graphical.log` |
| Combat headless from the fresh imported copy | 168 / 0 | 0 | `m2-clean-combat.log` |
| 24-unit load headless / graphical | 7 / 0 each | 0 each | `m2-combat-load*.log` |

Direct launch checks used a 60-second external deadline and `--quit-after 120`:

```powershell
$launch = @{ GodotPath = $godot; TimeoutSeconds = 60 }
& .\tools\run-godot.ps1 @launch -GodotArguments @('--headless','--path','.','--quit-after','120','--log-file','validation-output/m2-launch-main.log')
& .\tools\run-godot.ps1 @launch -GodotArguments @('--headless','--path','.','res://scenes/movement_stress.tscn','--quit-after','120','--log-file','validation-output/m2-launch-30.log')
& .\tools\run-godot.ps1 @launch -GodotArguments @('--headless','--path','.','res://scenes/movement_stress.tscn','--quit-after','120','--log-file','validation-output/m2-launch-50.log','--','--units=50')
& .\tools\run-godot.ps1 @launch -GodotArguments @('--headless','--path','.','res://scenes/combat_test.tscn','--quit-after','120','--log-file','validation-output/m2-launch-combat.log')
& .\tools\run-godot.ps1 @launch -GodotArguments @('--path','.','res://scenes/combat_test.tscn','--quit-after','120','--log-file','validation-output/m2-launch-combat-graphical.log')
```

All five direct launches returned **0**, reporting respectively 12 friendly/3 obstacles, 30 friendly/7 obstacles, 50 friendly/7 obstacles, and 12 combat/2 obstacles for both combat modes.

For the fresh import, tracked and new nonignored files were copied with `git ls-files --cached --others --exclude-standard` into a newly created temporary directory, excluding all existing cache/output. That directory was supplied as `-ProjectPath $importRoot` to the same wrapper with `@('--headless','--path','.','--editor','--import','--log-file',$absoluteImportLog)`. The headless combat command above then ran with the same `-ProjectPath` and an absolute `m2-clean-combat.log` path. The temporary path is recorded only in ignored `m2-clean-import-path.txt`; no workspace files were deleted or moved.

### Negative checks and test validity

The wrapper self-test passes only when normal exit 0, guarded fixture exit 3, internal watchdog exit 2 and externally killed blocked process exit 124 are preserved, and neither launcher nor engine survives. The expected internal timeout **2** is confined to its `--verify-timeout` fixture; it is never treated as successful normal validation. A wrapper launch failure would be 125, not a gameplay pass.

Combat tests install a test-only `Logger` and fail on engine errors/warnings through complete field teardown. The callback is mutex-protected because Godot can call loggers from worker threads; see [Logger](https://docs.godotengine.org/en/stable/classes/class_logger.html). Its isolated negative check intentionally accesses a detached Node3D's global transform:

```powershell
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.','--script','res://tests/combat_checks.gd','--log-file','validation-output/m2-error-probe-expected.log','--','--verify-combat-errors')
```

This returned **1**, with **1 check / 1 expected failure**, proving that an actual engine error makes the suite fail. It is excluded from successful-path log checks. Development failures are kept separate: the group replacement regression reproduced three failures before the field batch guard (`m2-group-red.log`, exit 1). Log review also exposed the marker access during tree exit; the guard was fixed and the error probe added before final validation. Neither issue is counted as a pre-existing baseline failure.

Tests use the real scene/components, input raycasts, health values, cooldown values, captured order versions, target identities, membership and observed position changes. Isolated firing tests disable automatic controller ticking to establish exactly one real emitter event. They do not copy the production attack algorithm. Fixtures reset the whole field, explicitly free detached nodes, disconnect temporary listeners and wait for deferred deletion. Projectile tests prove delayed health loss, one resolution, launch/source independence and expiry within one physics tick of the configured lifetime. Blocked pursuit uses real physical enclosure and a shortened fixture budget; gameplay tuning is unchanged. Reentrant tests cover every combat state, movement-to-combat replacement and replacement during selected-group dispatch.

The default engagement starts the twelve-unit scene, issues a six-unit player attack and runs until an observed death, bounded by 20 simulated seconds. It then verifies target-projectile cleanup and survivor movement. This is a defined engagement endpoint, not a claim that one order destroys the entire opposing team.

All eight graphical captures were inspected: `combat_initial_teams.png`, `combat_friendly_selection.png`, `combat_pursuit.png`, `combat_rifle_fire.png`, `combat_projectile_flight.png`, `combat_projectile_impact.png`, `combat_destroyed.png`, and `combat_survivor_control.png`. Their assertions also run in the graphical suite; screenshots alone do not establish damage timing. This was automated engine input playback and rendered-frame inspection. **No human physical keyboard-and-mouse playtest was performed.**

## Performance observations

The load fixture creates 12 units per team, each with eight rifles and four rocket vehicles, in fixed grids. It explicitly issues paired orders to both sides, runs 720 physics ticks (12 simulated seconds), then stops survivors and waits 390 ticks (6.5 seconds) for outstanding shots to resolve. It checks live-only registration throughout, at most 32 projectiles and at most 25 pursuit updates per unit, then zero remaining projectiles. Those bounds follow eight launchers with 1.8-second cooldown/6-second lifetime and a 0.5-second pursuit interval. Pairing opposing units is test setup, not gameplay AI.

| Captured metric | Headless | Graphical |
| --- | --- | --- |
| Starting units / simulation duration | 24 / 12 s | 24 / 12 s |
| Engagement wall time | 640.601 ms | 2841.647 ms |
| p95 wall interval between physics samples | 2.215 ms | 5.803 ms |
| Successful shots | 170 | 173 |
| Actual health removed | 2624 | 2652 |
| Deaths / survivors at endpoint | 10 / 14 | 11 / 13 |
| Peak live projectiles | 8 | 8 |
| Largest observed per-unit pursuit-update count | 9 | 9 |

These are captured instrumented playback observations, not isolated CPU timings or universal FPS targets. Wall time measures the engagement loop, excluding scene setup and the final cleanup wait. The p95 sample is the sorted 720 wall intervals at index `int(720 * 0.95)`. Fixed simulation delta and fixed setup do **not** make RVO trajectories or kill counts lockstep deterministic; the two runs visibly differ. The final graphical run overwrote `combat-load-metrics.json`; both original measurements remain in their separate logs.

Combat does no per-frame scene-tree target searches or all-pairs hostile scans. Each controller checks its own target; each projectile checks its own target. Pursuit navigation queries occur on the bounded update path. The body-material child scan runs once during construction. Resources are preloaded, cooldown uses a float rather than timer nodes, flashes tick only while active, and tracers/projectiles have bounded lifetimes. The field lists are iterated for command dispatch, status events and teardown. Load metrics and projectile-group enumeration run only in the test script. No test instrumentation is attached to normal scenes.

The unchanged movement comparisons also passed:

| Final movement run | Max destination generation / assignment | Enabled / disabled deep-overlap pair-seconds | Reduction |
| --- | --- | --- | --- |
| Headless | 5.133 / 4.078 ms | 58.4 / 206.2 | 71.7% |
| Graphical | 2.431 / 4.534 ms | 69.5 / 206.2 | 66.3% |

Overlap retains the Milestone 1.5.1 definition: each pair with center distance below 0.6 contributes 0.1 pair-seconds at 10 Hz. Reduction is `100 * (1 - enabled / disabled)`. Both fixtures use the same 50-unit spawns, destination and movement defaults; only the public crowd flag changes. It is sampled deep overlap, not exact continuous mesh contact. Some regression runs overlapped other validation processes, so these timings do not establish a performance improvement.

## Historical acceptance checklist (qualified by the review above)

| # | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| 1 | Explicit, consistent ownership | PASS | Shared TeamRules and team-count/member tests |
| 2 | Hostiles excluded from local selection | PASS | Actual click and rectangle tests |
| 3 | Contextual attack versus ground movement | PASS | Right-click raycast/order-version assertions |
| 4 | Friendly, dead and detached targets rejected | PASS | Explicit false returns and unchanged versions |
| 5 | Acceptance/rejection unambiguous | PASS | Bool results, invalid-batch and replacement tests |
| 6 | Pursuit uses existing navigation | PASS | Speed bounds, navigation/obstacle observations and source review |
| 7 | Stop and face before firing | PASS | Zero motion, actual range and facing checks at first shot |
| 8 | Hysteresis prevents boundary oscillation | PASS | Forty alternating margin samples; no pursue or out-of-range shot |
| 9 | Move and Stop cancel attacks | PASS | Ground/X input and unit/group replacement tests |
| 10 | Replacement attacks safely change target | PASS | Target identity, versions and synchronous listeners |
| 11 | Reusable configurable health/damage | PASS | Visual-independent configured health fixture |
| 12 | Death exactly once | PASS | Overkill, post-death and nested damage assertions |
| 13 | Death clears selection/reservations/membership/targeting | PASS | Immediate cleanup and old-destination reuse |
| 14 | Hitscan damage at fire | PASS | Health 100 to 88 before fired notification returns |
| 15 | Hitscan cooldown enforced | PASS | Same-tick, 0.74/0.75-second and command-spam checks |
| 16 | Projectile damage delayed until impact | PASS | Travel with health 100; impact changes health to 68 |
| 17 | Projectile damage at most once | PASS | Single resolved event and unchanged health afterward |
| 18 | Bounded lifetime and invalid-target handling | PASS | Death/detach/free/friendly/expiry fixtures |
| 19 | Fired projectiles independent of source orders | PASS | Move, new target and source death during the same flight |
| 20 | Limited retaliation without strategic AI | PASS | Valid/invalid source and explicit priority tests; source review |
| 21 | Coherent, replacement-safe state signals | PASS | All five states and synchronous group/movement listeners |
| 22 | Fixed combat scene demonstrates an engagement | PASS | Fixed setup, damage/death endpoint within 20 simulated seconds |
| 23 | Bounded 24-unit load completes | PASS | Both modes: seven checks, bounded work, projectile cleanup |
| 24 | All prior regression and wrapper suites pass | PASS | Five movement/controls runs plus wrapper table above |
| 25 | Headless combat passes | PASS | 168 / 0, exit 0; repeated from fresh imported copy |
| 26 | Graphical combat passes | PASS | 176 / 0, exit 0; eight inspected captures |
| 27 | Tested successful paths have no engine errors | PASS | Engine probe through teardown plus import/launch/test log scans |
| 28 | Accurate documentation | PASS | README/report checked against source, commands and recorded output |
| 29 | No later gameplay systems | PASS | Complete diff and new-file review |
| 30 | No unrelated content overwritten | PASS | Clean checkpoint baseline and final file inventory; no commit |

`git diff --check` passed. The complete tracked diff and all new source/test/resource files were reviewed. Successful final import, direct launch and test logs contain no parser, resource, navigation, signal, invalid-reference or runtime errors/warnings. Generated output remains in ignored `.godot/` and `validation-output/`. New `.gd.uid` files are normal Godot source metadata; no generated logs, screenshots, cache or machine-specific configuration was added to the change.

## Limits and next scope

There is **no line of sight, cover, guided-projectile world collision, splash damage, armor multipliers, attack-move, strategic AI, economy or construction**. Range-based rifles can hit through obstacles; rockets can pass through them. There is also no production, fog, campaign, multiplayer or other later gameplay system. All art is original primitive geometry and generated materials; no assets or plugins were downloaded.

The firing-position heuristic can be suboptimal near obstacles or crowds. Avoidance permits partial moving overlap; bounded failure remains possible in untested congestion. Opposing traffic, changing navigation, varied terrain, large combat crowds beyond the 24-unit fixture, other platforms, long-duration soak behavior and physical-input feel are **NOT VERIFIED**. Fixed setups do not imply network/replay determinism.

Milestone 2 can be accepted for the requested foundation. Recommended Milestone 2.5 is a human combat playtest plus a separately scoped line-of-fire/obstacle milestone, with focused blocked-shot and projectile collision regressions before adding further gameplay. No such later work was implemented here.
