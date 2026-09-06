# Milestone 2.5.1 — spherical projectile collision verification and correction

The discrepancy was **missing functionality**, not documentation alone. The production path at `9111f90` was WeaponEmitter.try_fire → GuidedProjectile.configure → GuidedProjectile._physics_process → LineOfFire.segment. It used a finite ray and 0.0001-radius origin/endpoint probes. No nonzero projectile radius was swept; the 0.22-radius SphereMesh was presentation only. The previous successful point-based tests remain historical successes, not retroactive failures.

This narrow correction preserves Godot **4.7.2.stable.official.ed1daf0bf**, the physics backend, static layouts, navigation/movement tuning, command/batch semantics, selection, X Stop, pursuit progress/recovery, source-safe firing, target ownership and cooldowns. No dependencies, engine upgrade, commit, tag or later gameplay systems were added.

## Preflight and baseline

The working tree and index were clean at `9111f90`. No applicable AGENTS.md was found. README, milestone reports through 2.5, collision/query/projectile/configuration/weapon code, combat and corrective tests, collision filtering and the existing external wrapper were inspected. A pre-edit copy is recorded in ignored `validation-output/m251-before-path.txt`.

Installed engine detection used the wrapper's `--version` invocation (exit 0). Before editing, the focused line-of-fire suite passed **305/0 headless** and **308/0 graphical**, both exit **0**. Evidence: `m251-pre-fire.log`, `m251-pre-fire-graphical.log` and wrapper transcripts. No pre-existing suite failure was observed.

## Actual shape, query and launch contract

| Setting | Value / behavior |
| --- | --- |
| Production resource | WeaponDefinition.projectile_collision_radius; explicitly 0.1 in weapons/rocket.tres |
| Validation | Finite and strictly positive for guided weapons; zero, negative, infinity and NaN rejected |
| Shape | SphereShape3D, with radius copied into the flying projectile at launch |
| Query margin | 0.0001 world units, independently configured as LineOfFire.SPHERE_QUERY_MARGIN |
| Existing line tolerance | CONTACT_EPSILON remains 0.0001 for unchanged hitscan/body/muzzle line checks |
| Filter | Weapon Blockers, layer 4 / mask 8; physics bodies only, not areas |
| Initial / launch overlap | intersect_shape, maximum one result, explicitly before any movement cast |
| Flight authority | cast_motion over the complete attempted sphere movement; safe fraction controls movement |
| Endpoint ties | Same sphere and margin checked at the endpoint; world contact takes precedence |
| Contact presentation | get_rest_info at the unsafe fraction supplies a surface point; if unavailable, retain the safe center |

Query parameter objects and the SphereShape3D are reused by the existing field-owned LineOfFire helper. Radius updates occur only when its value changes. There is no global manager, expanded obstacle geometry, per-unit scene scan or unit interception. Only explicitly marked static world solids participate; ground, low rails, units and visuals remain excluded. Queries reject unsafe processing context or invalid radius without manufacturing clearance.

The normal emitter still requires an actual clear body-to-muzzle and muzzle-to-aim line. For a guided weapon, weapon_clearance also checks its launch sphere. The controller uses that same eligibility query for coherent BLOCKED holding/rechecks; the emitter performs a fresh authoritative check before committing a shot. Hitscan calls retain only the original line behavior.

A launch overlap commits no projectile, damage, fired notification or new cooldown. The existing 0.2-second recheck and target retention remain unchanged. A centerline-clear flight may subsequently graze an obstacle with its sphere. Radius-only flight collision is expected, without any automatic repositioning.

Muzzle and aim heights remain 0.9 and 0.75; body attachment remains 0.6. The same resource radius governs launch, initial flight overlap and every sweep. Later source-resource changes do not resize a launched shot. The flying SphereMesh now matches that copied radius. F3 shows a translucent launch sphere of the resource's actual radius; it remains absent/hidden when debugging is off.

The documented [Godot cast_motion API](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html#class-physicsdirectspacestate3d-method-cast-motion) returns safe/unsafe movement fractions and ignores existing overlaps, so explicit overlap detection is required. [PhysicsShapeQueryParameters3D](https://docs.godotengine.org/en/stable/classes/class_physicsshapequeryparameters3d.html) supplies shape, transform, motion, margin and filtering. Runtime tests on the exact installed engine verify these semantics. The query margin favors blocking, never extra clearance; native solver fractions can stop slightly before mathematical tangency.

## Contact and lifetime ordering

The old code increased age by a full tick and expired immediately, discarding valid contact within the usable part of that tick. Source inspection and executed before/after tests confirm this defect.

Current processing:

1. Spent shots do nothing. A shot already at lifetime expires without movement. Invalid target/field membership resolves INVALIDATED.
2. Compute usable time as min(delta, lifetime − age).
3. Clip attempted motion both to usable time and to the unchanged original target aim point.
4. Check initial overlap, then sweep the sphere across that complete attempted interval.
5. World contact commits the safe center and recorded contact point, before any target damage. World/target numerical ties favor the blocker.
6. If the sweep is clear and the target aim is reached, resolve TARGET. Otherwise advance only through usable time, then expire if lifetime is exhausted.

Contacts at the inclusive final interval endpoint resolve before expiry; no motion or damage occurs after it. Target arrival still requires reaching the aim point, with no proximity shortcut and no expanded target-hit model. A sufficiently distant wall behind the aim point cannot cancel a valid earlier target hit.

Terminal age is clamped to lifetime; world-contact age uses the safe travel fraction. Spent/outcome/contact, disabled processing, hidden state and queued deletion are committed before presentation, damage or resolved callbacks. Reentrant attempts cannot complete twice. Launch team, original target, speed, damage and cooldown remain unchanged; weak references preserve source/target destruction safety.

## Distinguishing before/after evidence

New repository suite: `res://tests/spherical_projectile_checks.gd`. The normal-flight graze/near-miss/radius and lifecycle cases use the real emitter. Initial overlap and precise final-tick cases are explicitly isolated collision fixtures with valid launch data, not claimed successful normal launches.

A finite test wall spans x=[−4,−3.98], z=[8+gap,10+gap]; the path stays at z=8. The muzzle starts four units before it. Fixture dimensions prove the full centerline misses the wall and the origin is not overlapping. Normal radius 0.1 collides for gap 0.06 and clears for gap 0.16. At gap 0.08, radius 0.04 clears and radius 0.12 collides. Both configured-radius runs use speed 600, so one tick's travel budget is 10 units against 0.02-unit wall thickness. No production collision algorithm is copied into the tests.

The final distinguishing suite was copied into the pre-change source snapshot and run with `-- --sphere-baseline`. **105 assertions executed, 32 failed, exit 1, native errors/warnings 0.** Configurable-radius assertions and feedback/API assertions that required new fields were explicitly not executed there. They are not claimed as pre-fix reproductions. The earlier development red run contained 94 assertions/27 failures; the final red run adds the exact-expiry/already-expired cases.

| Group | Executed pre-change checks / failures | Corrected headless checks / failures |
| --- | --- | --- |
| Radius-only normal-speed graze | 7 / 3 | 9 / 0 |
| Clear near miss | 6 / 0 | 8 / 0 |
| Configurable radius and invalid values | Not executed: API absent | 24 / 0 |
| Launch-volume overlap / blocked restoration / debug | 3 / 1 | 8 / 0 |
| Isolated initial overlap | 5 / 3 | 5 / 0 |
| Fast radius-only graze | 8 / 3 | 10 / 0 |
| Contact and expiry ordering | 51 / 18 | 51 / 0 |
| Source death/free, target detach/free, reentry cleanup | 23 / 4 | 23 / 0 |
| Suite cleanup and native-error probe | 2 / 0 | 2 / 0 |
| Total | 105 / 32 | 140 / 0 |

Graphical adds one saved-image assertion: **141/0**. Both corrected runs exit 0. The suite observes actual health, terminal outcome/count, safe position, age, normal launch acceptance and node cleanup. It also changes the source radius after launch to verify copied flight data, checks the actual rendered sphere radius, and verifies F3 launch geometry/hiding. Screenshot `sphere_launch_volume.png` is supplemental; it does not establish collision correctness.

Ordering fixtures cover wall first, target before a distant wall, sphere-front/target numerical tie, contact before remaining lifetime, contact beyond remaining lifetime, target exactly at expiry and an already expired shot. A 0.001-second remaining life at speed 600 advances exactly 0.6 units before expiry. A 0.005-second life permits the earlier world/target impact despite a 1/60-second full tick. Tests require no age overshoot and intentionally reenter both tick and completion callbacks.

## Preserved tests and justified migration

One older fixture intentionally changed: `_swept_geometry_checks` previously set expiry life to 1/60 second while a wall lay about 2 units ahead at speed 600. It therefore relied on full-tick expiry winning over an earlier reachable wall. Its purpose remains expiry without damage/excess completion; life is now 0.001 second so expiry actually occurs before reaching that wall. Original assertions remain. Separate distinguishing cases prove the corrected before/after-lifetime ordering.

No legacy lane relocation, tolerance increase, navigation change, masked-out blocker or damage/cooldown/command assertion weakening was needed. Existing combat and corrective test scripts are unchanged. The line-of-fire load output gains a sphere-query count; its original acceptance and cost bounds remain.

## Validation

Use the existing external wrapper from the repository root in PowerShell 7:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--version')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','validation-output/m251-final-import.log')
$cases = @(
  @('original','milestone_checks'), @('stress','movement_stress_checks'),
  @('repair','movement_repair_checks'), @('combat','combat_checks'),
  @('corrective','combat_repair_checks'), @('fire','line_of_fire_checks'),
  @('sphere','spherical_projectile_checks'), @('load','combat_checks')
)
foreach ($graphical in @($false,$true)) {
  foreach ($case in $cases) {
    $name = $case[0] + $(if ($graphical) { '-graphical' } else { '' })
    $arguments = @('--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),
      '--log-file',('validation-output/m251-final-' + $name + '.log'))
    if (-not $graphical) { $arguments = @('--headless') + $arguments }
    if ($case[0] -eq 'load') { $arguments += @('--','--combat-load') }
    & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments $arguments
    if ($LASTEXITCODE -ne 0) { throw "$name failed: $LASTEXITCODE" }
  }
}
```

The run used separate shell sessions for the headless and graphical loops. All final suite exits were **0**, with **2,417 passing assertions across 16 runs**:

| Final suite | Headless checks / failures | Graphical checks / failures |
| --- | --- | --- |
| Original movement | 127 / 0 | 131 / 0 |
| Movement stress | 122 / 0 | 131 / 0 |
| Movement repair | 82 / 0 | 82 / 0 |
| Combat | 183 / 0 | 191 / 0 |
| Combat corrective | 230 / 0 | 230 / 0 |
| Line of fire, including obstacle load | 305 / 0 | 308 / 0 |
| Spherical projectile | 140 / 0 | 141 / 0 |
| Existing combat load | 7 / 0 | 7 / 0 |

The 24-unit obstacle load still observed 132 shots, 2076 damage, 12 deaths, 12 survivors, six peak projectiles, zero endpoint projectiles, six peak blocked units and zero pursuit updates in both modes. Query counts were 1098 clearance calls, 2196 line segments, **1500 sphere queries** (launch and flight), and 10188 total direct physics calls. At most four direct calls serve one flight sphere query: initial overlap, motion cast, endpoint overlap when needed, and contact information on impact. A clear stationary launch-volume check uses one overlap call.

Existing load bounds remain intact. The obstacle load's instrumented wall times were 661.453 ms headless and 2472.429 ms graphical; neither is a promised game FPS or a claimed speedup. Existing combat load observed 171 shots, 2628 damage, 11 deaths, 13 survivors, eight peak projectiles and nine maximum pursuit updates. Cross-mode counts/trajectories are not required to match.

The relevant scene launches, wrapper tests and isolated error fixture used:

```powershell
foreach ($scene in @('combat_test','line_of_fire_test')) {
  & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @(
    '--headless','--path','.',('res://scenes/' + $scene + '.tscn'),'--quit-after','120',
    '--log-file',('validation-output/m251-final-launch-' + $scene + '.log'))
  if ($LASTEXITCODE -ne 0) { throw "$scene failed" }
}
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--path','.','res://scenes/line_of_fire_test.tscn','--quit-after','120','--log-file','validation-output/m251-final-launch-fire-graphical.log')
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.','--script','res://tests/combat_checks.gd','--log-file','validation-output/m251-negative-errors-expected.log','--','--verify-combat-errors')
git diff --check
```

Workspace import and all three scene launches exited **0**. Wrapper self-tests passed **5/0**, exit **0**, preserving intentional child codes **0, 3, 2, 124** and checking that no blocked child survives. The isolated native-error probe returned its expected **1**, with one expected failed assertion. These intentional negatives are separate from successful-path logs.

For the final red reproduction, the expanded test was copied into the recorded pre-edit directory; no production file there was repaired:

```powershell
$before = (Get-Content validation-output/m251-before-path.txt -Raw).Trim()
Copy-Item -LiteralPath tests/spherical_projectile_checks.gd -Destination (Join-Path $before 'tests/spherical_projectile_checks.gd')
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $before -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m251-red-import.log')
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $before -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/spherical_projectile_checks.gd','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m251-red-sphere.log','--','--sphere-baseline')
```

Red import exited 0; final red suite exited 1 as described above. The snapshot/output paths are local evidence, not portable dependencies.

Fresh-copy validation created a new directory, copied **70** tracked/new nonignored files, and verified every copied SHA-256. It contained no old `.godot` cache or validation output. The directory is recorded in `validation-output/m251-clean-path.txt`:

```powershell
$cleanRoot = Join-Path $env:TEMP ('fieldwork-m251-clean-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $cleanRoot | Out-Null
foreach ($relative in @(git ls-files --cached --others --exclude-standard)) {
  $destination = Join-Path $cleanRoot $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $relative -Destination $destination
  if ((Get-FileHash -LiteralPath $relative).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
    throw "Copy hash mismatch: $relative"
  }
}
Set-Content -LiteralPath validation-output/m251-clean-path.txt -Value $cleanRoot
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m251-clean-import.log')
foreach ($case in @(@('sphere','spherical_projectile_checks'),@('fire','line_of_fire_checks'),@('combat','combat_checks'),@('corrective','combat_repair_checks'))) {
  & .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 240 -GodotArguments @(
    '--headless','--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),
    '--log-file',('D:/GitHub/Command_and_Concur_Generals/validation-output/m251-clean-' + $case[0] + '.log'))
  if ($LASTEXITCODE -ne 0) { throw "Fresh suite failed: $LASTEXITCODE" }
}
```

Fresh import and all four suites exited **0**: sphere **140/0**, line of fire **305/0**, combat **183/0**, corrective **230/0**. Resource resolution used the fresh copy; only evidence log paths pointed back to the workspace. Final report text was completed afterward; executable sources were unchanged.

The successful-path audit covers **25 engine logs and 25 exit-0 wrapper transcripts**: 16 matrix runs, workspace import, three direct launches and fresh import plus four suites. There are **zero engine errors, warnings, failed assertions or leaked-resource messages**. Red and intentional-negative logs are excluded. `git diff --check` exits **0**. Ignored audit files are `m251-log-audit.txt` and `m251-scope-audit.txt`.

Important changed files: `scripts/line_of_fire.gd` (shared shape queries), `scripts/guided_projectile.gd` (copied radius, clipped travel, terminal ordering and visual size), `scripts/weapon_definition.gd`/`weapons/rocket.tres` (radius), one clearance call each in controller/emitter, `scripts/combat_feedback.gd` (debug launch sphere), the new spherical suite and the documented expiry/metrics edits to the existing line-of-fire suite. README and the 2.5/2.5.1 reports distinguish historical and current behavior. Project configuration, scenes, movement, selection, destinations, combat/corrective tests and wrapper hashes match the pre-edit copy.

## Acceptance

**Milestone 2.5.1 acceptance is supported for the required static-primitive scope.**

| Requirement | Status |
| --- | --- |
| Real configurable spherical world-collision volume | PASS |
| Radius-only graze and clear-near-miss behavior | PASS |
| Launch-volume and initial-overlap handling | PASS |
| Contact/lifetime ordering and exactly-once cleanup | PASS |
| Prior regression coverage and clean successful logs | PASS |
| Documentation matches implementation and qualifies historical evidence | PASS |

## Scope and limitations

Only marked static primitive convex solids are covered. Moving/concave geometry, unit interception, target-volume redesign, splash, destructible obstacles, automatic repositioning, visibility and later systems remain absent. Native physics tolerances are not lockstep determinism guarantees. No physical keyboard-and-mouse playtest is claimed. No test query/event instrumentation is loaded by normal scenes; scalar field query counters remain bounded diagnostics.
