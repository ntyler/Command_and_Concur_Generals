# Milestone 2.5 — line of fire and projectile–obstacle interaction

**Historical point-collision report, qualified by Milestone 2.5.1.** Source inspection of `9111f90` confirmed that a normal rocket used a ray segment plus tiny endpoint probes, not a swept nonzero-radius sphere. Its successful tests below remain valid historical results, but did not prove compliance with the spherical projectile requirement. The earlier blanket acceptance statement is therefore qualified.

Current implementation: [Milestone 2.5.1](milestone-2.5.1.md) adds a configurable 0.1-unit SphereShape3D, explicit initial/launch overlap checks, cast_motion flight sweeps, a separate 0.0001-unit query margin and lifetime-clipped final-tick travel. Hitscan remains line-based. Flying geometry and F3 launch feedback show the configured radius. The remainder of this document records the prior implementation and measurements; current acceptance, distinguishing regressions and justified expiry-fixture migration are in the corrective report.

Implemented and validated on 2026-09-06 using **Godot 4.7.2.stable.official.ed1daf0bf**, Windows, PowerShell 7 and the existing Compatibility renderer/physics backend. No engine change, navigation redesign, automatic firing-position search, commit or tag was made. This report supersedes earlier range-only weapon behavior; historical results remain in the earlier reports.

## Preflight and preserved behavior

README, reports through 2.0.1, project/scenes, movement, selection, destination assignment, team rules, command-batch results, combat components and existing tests were inspected. No applicable AGENTS.md was found. The accepted Milestone 2 baseline is commit `f174222`. A pre-edit copy of all tracked/nonignored new files is recorded in ignored `validation-output/m25-before-path.txt`. Staged changes were empty.

Every documented baseline suite passed before test migration. Logs are `m25-pre-<name>.log`, with wrapper transcripts alongside:

| Baseline name | Headless checks / failures | Graphical checks / failures |
| --- | --- | --- |
| original | 127 / 0 | 131 / 0 |
| stress | 122 / 0 | 131 / 0 |
| repair | 82 / 0 | Not part of the documented baseline command set |
| combat | 183 / 0 | 191 / 0 |
| corrective | 230 / 0 | 230 / 0 |
| load | 7 / 0 | 7 / 0 |

All baseline engine runs exited 0. Wrapper self-tests passed 5/0. There were no observed pre-existing suite failures.

Original/main, stress and combat scene layouts, camera/input mappings, navigation construction, collision masks, movement tuning, destination assignment, pursuit retarget/progress accounting, recovery budgets, health, team rules and batch acceptance semantics remain intact. The only movement-script change refreshes combat debug visibility when F3 toggles. Existing obstacles acquire an additional weapon-only layer. Decorative cap dimensions are clamped positive for new thin walls; cap dimensions on the older layouts are unchanged.

## Geometry and physics query

`LineOfFire` is one small field-owned RefCounted helper, shared by controller, emitter and projectiles. It is not an autoload or global manager. Static bodies' collision shapes are authoritative; visual meshes and navigation outlines are not queried.

| Physics layer | Bit mask | Policy |
| --- | --- | --- |
| 1 — Terrain | 1 | Ground; excluded from weapons |
| 2 — Units | 2 | Unit bodies; excluded from weapons |
| 3 — Obstacles | 4 | Existing obstacle/picking/movement role, unchanged |
| 4 — Weapon Blockers | 8 | Explicit obstacle rectangle bodies also retain bit 4 |

Layer 4 was unused before this change. Low boundary rails retain only bit 4. Ground, decorative caps/grid, units, selection indicators, health bars, tracers, rocket visuals and debug geometry do not block fire. New fixtures use static BoxShape3D solids. Supporting arbitrary concave meshes or moving blockers is outside this milestone.

World-space positions are unit origin plus vertical offsets: body attachment **0.6**, muzzle **0.9**, target aim **0.75**. There is no forward offset that can poke a muzzle through a wall. Each firing query validates body-to-muzzle attachment before muzzle-to-aim. Weapons, rockets and tracers share these conventions.

The helper reuses ray/shape query parameter objects. It rejects unavailable/out-of-physics queries; unavailable never means clear. `WeaponEmitter.try_fire()` is supported during physics processing and returns false outside it. Input continues to issue commands, leaving actual firing to physics ticks. Fixtures wait for navigation-map synchronization and query in a physics frame.

Each segment performs an origin overlap probe, a finite ray to the intended endpoint, and—if no earlier contact exists—an endpoint overlap probe. The ray has `hit_from_inside = true`; the origin probe independently rejects supported contained origins without shifting them through geometry. Probe radius is **0.0001 world units (0.1 mm)**, margin zero. Endpoint contacts within that numerical skin conservatively favor the blocker. No large offset or old 0.05-unit proximity shortcut is used. A wall farther behind the target does not block. Reported contained-origin contact is the origin; a ray contact is its actual intersection. Traces hold value geometry/collider IDs, not owning references to nodes.

Official documentation consulted for the installed Godot 4 API:

- [Physics ray casting and safe physics processing](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html).
- [PhysicsRayQueryParameters3D: mask and inside-origin behavior](https://docs.godotengine.org/en/stable/classes/class_physicsrayqueryparameters3d.html).
- [PhysicsDirectSpaceState3D: intersect_ray and intersect_shape](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html).
- [Engine.is_in_physics_frame](https://docs.godotengine.org/en/stable/classes/class_engine.html).

The documented concave-shape restriction is one reason the required fixtures use primitive convex solids. Runtime validation on the exact installed build supplies the version-specific evidence.

## Firing, holding and commands

The controller caches clearance for status/rechecks. The emitter independently revalidates definition, live hostile field membership, motion, range, facing, cooldown and geometry immediately before committing cooldown/shot count. There is no notification between final validation and commitment. A stale clear controller trace cannot authorize damage. The repaired post-damage immediate-source-free guard and committed-shot return value remain covered.

Within actual range, a blocked attacker enters **BLOCKED**, faces its target and holds. Target and attack-order identity remain unchanged. No shot, tracer, successful-shot notification or rocket is produced. A blocked attempt never consumes/restarts cooldown; existing cooldown advances normally. Recheck interval defaults to **0.2 simulated seconds**, exported with editor range 0.05–2.0. Restored clearance is recognized within that interval plus physics scheduling; facing and cooldown can still delay the shot.

Intentional holding issues no repeated move orders, spends no movement-recovery attempts and adds no pursuit time. There is no new blocked timeout. Existing cumulative pursuit history is retained; ordinary pursuit resumes beyond the existing 0.75-unit hysteresis band. Between actual range and the hysteresis boundary, the unit holds as FACING and cannot shoot.

Move, viewport X Stop and replacement Attack clear cached controller geometry, blocked feedback and recheck timer through the existing order preparation path. Target invalidation clears them through existing availability handling. State and feedback are coherent before notifications; identical blocked-state notifications are suppressed. A blocked-state listener can synchronously replace the order, with no old writes afterward. Existing field batch results keep historical acceptance, supersession and captured stable-ID assignments.

## Projectile ordering and lifecycle

Launch requires clear firing geometry. A fired rocket keeps its original target plus copied launch team, speed, lifetime and damage; source movement, replacement, death or deletion does not cancel or retarget it.

For each physics tick:

1. An already spent rocket does nothing. Advance age; lifetime expiry wins at the start of the tick.
2. Reject an invalid original hostile target/field as INVALIDATED.
3. Compute the intended next point using move_toward, clamped to target aim with no overshoot.
4. Sweep the entire previous-to-next segment. Earliest world contact wins; endpoint numerical ties favor the world.
5. Only if clear, commit movement. Exact arrival at the clamped aim point resolves TARGET.

WORLD, TARGET, INVALIDATED and EXPIRED are exclusive terminal outcomes. Spent/outcome/contact position, disabled processing, hidden state and queued deletion are committed before feedback, damage or resolved callbacks. Reentrant completion attempts have no effect. Only TARGET can damage the original still-valid hostile, once. WORLD creates a 0.18-second orange contact marker and applies no target, splash or obstacle damage. Cleanup uses weak references and guards the field/source/target lifetimes.

Collision is point/centerline with a numerical skin; the visible 0.22-radius rocket sphere does not imply volumetric collision. Homing steers toward the target but does not avoid obstacles.

## Scene and focused regressions

`res://scenes/line_of_fire_test.tscn` directly launches six paired lanes: clear Rifle, blocked Rifle, opening, wall behind target, clear Rocket with a wall-shadow route, and a thin-wall area. The wall is 0.02 units thick. Both teams use existing Rifle/Rocket definitions; this lab disables retaliation to isolate geometry. Ordinary movement remains available. T manually moves the marked Bravo rocket target between z=8 and z=14; it is not AI. F5 still launches the original movement field.

BLOCKED health labels are visible without debugging. F3 adds firing segments and blocker contact markers. Debug meshes are allocated/drawn only when enabled, have no collision and are disabled by default. World-impact presentation is ordinary bounded feedback.

`tests/line_of_fire_checks.gd` extends the existing corrective harness, reusing its independent batch and pursuit regressions. It does not reproduce the ray or movement algorithms. Individual groups can run with `-- --fire-case=<name>`.

| Group | Headless assertions | Evidence |
| --- | --- | --- |
| hitscan | 10 | Same configured ready/facing/in-range weapon; clear damage 12 once versus actual wall evidence, 100 blocked attempts, no committed effects |
| restoration | 11 | Ordinary target movement around the wall; retained order, bounded recheck, cooldown continuation, no recovery or notification spam |
| filtering | 15 | Both directions; self/non-target/decor exclusion, opening, wall behind target, origin-contained and attachment-only blockers |
| authority | 5 | Unsafe direct call rejected; a synchronous callback moves a clear target behind a wall before emitter validation |
| projectiles | 10 | Real clear launch then ordinary target movement behind the existing wall; world contact, no damage, cleanup; blocked launch rejected |
| geometry | 29 | 600 units/s at 60 Hz against 0.02-unit wall, target-first, near-wall target, contained origin, endpoint tie, expiry |
| lifecycle | 49 | Source movement/replacement/death/free; target death/detach/queue/free; world cleanup after source free; live-projectile scene teardown |
| commands | 120 | Move/X/Attack from BLOCKED, synchronous replacement, invalidation and unchanged historical batch/supersession regressions |
| pursuit | 47 | Out-of-range navigation, range hysteresis and unchanged moving-target recovery-starvation regressions |
| load | 6 | 24 mixed units, clear/blocked lanes, fixed endpoint, query/shot/damage/projectile counts and cleanup |

The suite adds three runner/teardown assertions: **305 headless** total. Three saved-image assertions produce **308 graphical** total. Screenshots supplement actual state, damage, contact-position and simulation-time assertions. Terminal observers deliberately reenter both projectile tick and completion to verify exactly-once behavior.

Restoration was first observed clear on frame 51 and firing on frame 54 relative to target movement: three physics frames, within the 0.2-second bound plus scheduling. The test confirms facing and cooldown eligibility when clearance first returns. A three-second blocked observation also checks unchanged order/position, zero recovery/pursuit time, at most 17 clearance checks and no duplicate state notifications.

## Legacy migration

No old combat fixture needed relocation: baseline clear lanes remained clear with the new blocker mask. No navigation layout, damage value, cooldown threshold, timing tolerance, immediate-free callback or command assertion was weakened.

Older direct-emitter tests assumed firing could occur from process/render continuations. That assumption is now invalid because firing performs direct physics queries. Added physics-frame waits cover hitscan setup, the continuation after its graphical capture, the shared projectile-launch helper, retaliation setup, immediate-destruction direct firing and rapid replacement setup. All helper callers await its supported physics phase.

Development failures are separate from baseline/final evidence: an initial focused-test type-inference parse error was corrected; the new X assertion originally observed buffered viewport input before dispatch; and the first final graphical legacy run exposed the missing post-capture physics wait (three reported failures including the error-probe assertion). These are retained under `m25-dev-*`. Final reruns preserve all original assertions. There is no mask-disabling switch or production launch bypass.

## Validation commands and results

Run from the repository root in PowerShell 7:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--version')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import')

$cases = @(
  @('original','milestone_checks'), @('stress','movement_stress_checks'),
  @('repair','movement_repair_checks'), @('combat','combat_checks'),
  @('corrective','combat_repair_checks'), @('fire','line_of_fire_checks'),
  @('load','combat_checks')
)
foreach ($graphical in @($false,$true)) {
  foreach ($case in $cases) {
    $name = $case[0] + $(if ($graphical) { '-graphical' } else { '' })
    $arguments = @('--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),
      '--log-file',('validation-output/m25-final-' + $name + '.log'))
    if (-not $graphical) { $arguments = @('--headless') + $arguments }
    if ($case[0] -eq 'load') { $arguments += @('--','--combat-load') }
    & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments $arguments
    if ($LASTEXITCODE -ne 0) { throw "$name failed: $LASTEXITCODE" }
  }
}
```

The above is the reproducible final matrix; this run launched headless and graphical loops in separate shell sessions. Each child used the existing wrapper and a 240-second external deadline. Output transcripts are `m25-final-<name>-wrapper.txt`. Only the affected combat suite was rerun after the post-capture timing migration.

| Final suite | Headless checks / failures | Graphical checks / failures | Child exit |
| --- | --- | --- | --- |
| Original movement | 127 / 0 | 131 / 0 | 0 |
| Movement stress | 122 / 0 | 131 / 0 | 0 |
| Movement repair | 82 / 0 | 82 / 0 | 0 |
| Combat | 183 / 0 | 191 / 0 | 0 |
| Combat corrective | 230 / 0 | 230 / 0 | 0 |
| Line of fire | 305 / 0 | 308 / 0 | 0 |
| Existing combat load | 7 / 0 | 7 / 0 | 0 |

Direct launch commands (all bounded, no test harness):

```powershell
foreach ($scene in @('test_field','movement_stress','combat_test','line_of_fire_test')) {
  & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @(
    '--headless','--path',".",("res://scenes/" + $scene + ".tscn"),
    '--quit-after','120','--log-file',("validation-output/m25-final-launch-" + $scene + ".log"))
  if ($LASTEXITCODE -ne 0) { throw "$scene failed" }
}
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--path','.','res://scenes/line_of_fire_test.tscn','--quit-after','120','--log-file','validation-output/m25-final-launch-fire-graphical.log')
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.','--script','res://tests/combat_checks.gd','--log-file','validation-output/m25-negative-errors-expected.log','--','--verify-combat-errors')
git diff --check
```

The isolated error fixture must return **1**, not 0. Wrapper self-tests return **0**, 5/0, preserving child codes **0, 3, 2, 124** and confirming no blocked child survives. Internal watchdog 2 and external timeout 124 are confined to intentional fixtures, never accepted as successful gameplay exits. Wrapper launch failure remains 125.

Clean editor import, all four headless direct scene launches and the graphical line-of-fire scene launch exited **0**. The main-scene setting remains `res://scenes/test_field.tscn`.

Fresh-copy validation copied all **67** tracked/nonignored new files to a new directory without `.godot` or prior validation output and verified each copied file's SHA-256 against the workspace. The directory is recorded in ignored `m25-clean-path.txt`. Creation and validation:

```powershell
$cleanRoot = Join-Path $env:TEMP ('fieldwork-m25-clean-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $cleanRoot | Out-Null
foreach ($relative in @(git ls-files --cached --others --exclude-standard)) {
  $destination = Join-Path $cleanRoot $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $relative -Destination $destination
  if ((Get-FileHash -LiteralPath $relative).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
    throw "Copy hash mismatch: $relative"
  }
}
Set-Content -LiteralPath validation-output/m25-clean-path.txt -Value $cleanRoot
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m25-clean-import.log')
foreach ($case in @(@('combat','combat_checks'),@('corrective','combat_repair_checks'),@('fire','line_of_fire_checks'))) {
  & .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 240 -GodotArguments @(
    '--headless','--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),
    '--log-file',('D:/GitHub/Command_and_Concur_Generals/validation-output/m25-clean-' + $case[0] + '.log'))
  if ($LASTEXITCODE -ne 0) { throw "Fresh suite failed: $LASTEXITCODE" }
}
```

Fresh import, combat **183/0**, corrective **230/0**, and line-of-fire **305/0** all exited **0**. Their resources resolve through the clean copy's `res://`; only evidence log paths point back to the workspace. This report's final evidence text was completed afterward; executable sources were unchanged.

The final audit covers **24 successful engine logs** and their **24 exit-0 wrapper transcripts**: the 14-suite matrix, workspace import, five direct launches, and fresh import plus three suites. There are **zero engine errors, warnings, failed assertions or leaked-resource messages** in those logs. Development and intentional-negative logs are excluded. `git diff --check` exits **0**; Git's local LF-to-CRLF advisory is separate from engine warnings. Local reports are `m25-log-audit.txt` and `m25-scope-audit.txt`. Original source hashes outside the listed milestone changes match the pre-edit copy.

Graphical evidence in ignored `validation-output/`: `fire_initial_lanes.png`, `fire_blocked_debug.png`, and `fire_rocket_world_impact.png`. Captures were inspected for layout/feedback; the small world marker can be occluded by the wall from the default camera, so contact placement, duration and zero damage are proved by assertions rather than inferred from the image.

## Measured load and cost

The new 24-unit fixture runs twelve simulated seconds with eight Rifles/four Rockets per team and both clear and obstructed six-unit lanes. Headless and graphical observations in this run:

| Measurement | Headless | Graphical |
| --- | --- | --- |
| Shots / damage / deaths | 132 / 2076 / 12 | 132 / 2076 / 12 |
| Survivors | 12 | 12 |
| Peak / endpoint active projectiles | 6 / 0 | 6 / 0 |
| Peak blocked units | 6 | 6 |
| Maximum pursuit updates | 0 | 0 |
| Clearance calls | 1098 | 1098 |
| Segment calls | 3426 | 3426 |
| Direct physics API calls | 9918 | 9918 |
| Instrumented wall time (ms) | 771.107 | 2644.769 |

These counts exclude fixture synchronization and post-endpoint cleanup. A clearance call includes up to two segments; a segment uses at most three direct queries. Counts include controller checks and authoritative emitter attempts; projectile sweeps contribute segments/physics calls but not clearance calls. The asserted clearance ceiling is 24 × (ceil(12/0.2) + ceil(12/0.75) + 3) = **1896**. Surviving blocked units are a valid endpoint. After Stop and 6.5 further simulated seconds, projectile and impact groups are empty.

The existing combat-load suite still passes its original bounds: this run observed 171 shots, 2628 damage, 11 deaths, 13 survivors, eight peak projectiles and nine maximum pursuit updates in both modes. These observed counts are not required to match across rendering modes. Neither load reports a promised game FPS or causal speedup.

Source inspection finds no added per-frame scene-tree search or pairwise unit loop. Clearance work is constant per active in-range unit at the configured interval, plus fresh eligible-shot checks; one bounded sweep runs per active projectile physics tick. Query-result objects/physics result arrays are bounded allocations; query parameter objects are reused. Existing navigation path reconstruction remains in the existing pursuit update, not in clearance checks. Debug-off paths do not allocate/draw debug meshes. Load sampling/group enumeration, native-error probes and per-assertion logging live only in test scripts. Production counters are three scalar field-local diagnostics; normal scenes load no tests and log no per-shot/recheck messages.

## Acceptance and limitations

**Historical verdict: the point-based checks passed, but this was insufficient for the required spherical collision contract. See Milestone 2.5.1 for corrected acceptance.** PASS values below describe the historical assertions, not spherical coverage.

| # | Requirement | Status |
| --- | --- | --- |
| 1 | Clear fire works; marked static obstacles block firing | PASS |
| 2 | Blocked units retain targets, hold coherently and resume when clear | PASS |
| 3 | Blocked attempts commit no shots, damage, projectiles or new cooldown | PASS |
| 4 | Fresh weapon checks reject stale controller clearance | PASS |
| 5 | Filtering, muzzle attachment, wall-behind-target and inside-origin cases | PASS |
| 6 | Segment sweeps detect thin walls at tested high speeds | PASS |
| 7 | World, target, invalidation and expiry resolve exactly once | PASS |
| 8 | Source/target destruction and synchronous replacement safety | PASS |
| 9 | Pursuit recovery, historical batches, X Stop and prior corrections | PASS |
| 10 | Existing/new suites pass with physics-phase migrations documented | PASS |
| 11 | Successful logs clean; external deadlines and isolated negatives verified | PASS |
| 12 | No automatic repositioning or later systems added | PASS |

Automated viewport input and rendered-frame inspection were performed; no physical keyboard-and-mouse playtest is claimed.

Static primitive convex blockers and flat existing fields are the supported scope. Moving/concave blockers, visibility/fog, cover bonuses, firing-position search, unit interception/friendly fire, volumetric projectile collision, splash, obstacle damage/destruction and other later systems are absent. Other platforms, larger loads and lockstep determinism remain unverified.
