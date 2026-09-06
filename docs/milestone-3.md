# Milestone 3 — fixed-base unit production and starting credits

Milestone 3 adds only preplaced indestructible headquarters/barracks, building selection, session credits, Rifle queues/cancellation, safe deployment, rally points and a small production panel. Movement, weapon tuning, pursuit, line of fire, spherical projectiles and historical command results retain their existing implementations.

## Preflight and playable scene

The workspace and index were clean at `a1f6fe2`. No applicable AGENTS.md files were found in the repository or its ancestor directories. README, milestone reports through 2.5.1, project inputs, field/unit registration, command results, collision/navigation, ownership, selection and the external wrapper were inspected. A pre-edit source copy is recorded in ignored `validation-output/m3-before-path.txt`.

Installed engine: **4.7.2.stable.official.ed1daf0bf**. No engine change, dependency installation, staging, commit or tag was performed. The pre-edit regression matrix passed **2,417 assertions across 16 runs**, all exits 0. Wrapper self-tests passed **5/0**, exit 0. There were no pre-existing gameplay failures. Intentional fixture errors/timeouts remained separate.

Open `scenes/production_test.tscn` and press F6. F5 still launches `scenes/test_field.tscn`; all prior scene files and project input mappings remain unchanged.

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/production_test.tscn
```

The scene has one Alpha headquarters, one Alpha barracks, three friendly Rifles and three Bravo Rifles outside immediate base firing range. Bravo uses existing damage-triggered retaliation only. Fixed obstacles provide firing and navigation routes. Camera focus/zoom stay `(0,0,0)`/52. HQ footprint is x=[−24,−17], z=[−10,−4]; barracks x=[−21,−15], z=[4,9]. The east exit is `(−13.7,0,6.5)` and default rally `(−8,0,3)`.

Click the barracks → Train Rifle → wait five simulated seconds → unit deploys and rallies → select it → right-click a hostile. WASD/arrows/edges pan; wheel zooms. Click/drag/Shift select units. Click or Shift-click an owned building selects it alone. Drag selects units only; selecting units or normally clicking empty ground clears the building. Buildings never enter `selected_units()` or a movement/combat batch. Enemy buildings are not selectable or attackable.

With barracks selected, right-click valid ground to set rally. Right-clicking a unit does nothing for the building. X stops selected units, including over passive production UI, and never cancels jobs. A focused control that consumes X retains it. S remains camera pan. F3 debugging is off by default.

## Defaults, credits and jobs

| Setting | Default | Configuration |
| --- | --- | --- |
| Starting credits | 1000 per owner | `ProductionField.starting_credits` |
| Rifle price | 100 integer credits | `production/rifle.tres`, `credit_cost` |
| Training duration | 5 simulated seconds | Recipe `training_duration` |
| Queue capacity | 5 outstanding jobs | `RTSBuilding.queue_capacity` |
| Simultaneously training | 1 per barracks | FIFO rule |
| Blocked exit retry | 0.25 simulated seconds | `spawn_retry_interval` |
| Cancellation refund | 100% original payment | All undeployed jobs |

`PlayerCredits` is created by each field for owners 1/2. Same-owner producers share its balance; different owners and different fields do not. No global account, income, storage or ledger exists. Negative starting configuration clamps to zero. A successful enqueue deducts once; completion/retry never charges. Unsupported/null recipes, unusable unit scenes, negative prices, nonfinite/nonpositive durations, invalid producer membership/control, exhausted capacity or insufficient funds reject through `ProductionResult.accepted = false` with a reason. A zero-cost valid recipe is allowed. A zero/negative capacity accepts no jobs.

`ProductionDefinition` contains identifier/name, PackedScene, integer cost and duration. Only a normal Rifle root using the existing RTSUnit script, Rifle weapon, 100 health, speed 5 and unit scale is supported; scenes with added child nodes are rejected. `scenes/rifle_unit.tscn` composes that existing unit and weapon without retuning. Resources contain no mutable jobs. Acceptance captures a field-unique job ID, payer, original price, scene reference, display name and duration. Later recipe replacement or price/time edits cannot alter a queued payment or training time. UI `jobs()` returns value snapshots, not mutable job objects.

The capacity includes waiting, training and completed-but-blocked jobs. Only the head advances, using `_physics_process(delta)`. Progress clamps at 100%; later jobs stay at zero while the head waits to spawn. Cancelling waiting/active/blocked jobs removes the job and returns its captured payment exactly once. Cancelling the head starts the next at zero; repeated and post-deployment cancellation reject. Refunds go to the captured payer, even if an isolated fixture changes building ownership. Capture gameplay is not implemented.

Wallet and queue changes finish before either publishes notifications. Nested listeners can enqueue/cancel without observing a debit absent its job or a refund whose job remains cancellable. Results describe historical acceptance; a synchronous callback may already have cancelled an accepted job by the time the outer call returns. This does not change `CommandBatchResult` or its explicit acceptance semantics.

## Deployment boundary and safe spawning

The 100% queue-change notification is **before** deployment; cancellation at that notification wins. The field then checks at most six ordered candidate offsets from the east exit: `(0,0)`, `(0,−1.1)`, `(0,1.1)`, `(1.1,0)`, `(1.1,−1.1)`, `(1.1,1.1)` in x/z. The farthest is under 1.56 units from the exit. Search is deterministic, bounded and never expands across the map.

Queries wait for a synchronized navigation map and execute only during physics. Exit and candidate must lie on this field's navigation region, within its inset bounds, within 0.02 units of navigation (points themselves are not moved), and have a complete direct local navigation route. This rejects projection through a hole or wall. A real capsule overlap query then checks Units, Obstacles and Weapon Blockers. Terrain is excluded because the capsule rests on it; low boundary rails remain included. The capsule uses the same source as RTSUnit: radius **0.43**, height **1.3**, center **0.65** above its origin. Spawn query skin is **0.001**, independent of gameplay body tuning. Same-tick field-local position claims prevent competing producers from choosing overlapping positions before new bodies synchronize. Claims expire at the next physics frame and are cleared with the field.

No acceptable sample means **Exit blocked**, a completed paid head held at 100%, and a retry after the configured simulation interval. No later job trains. Occupants are neither moved nor displaced. Safe finite search may wait despite open ground outside its local samples; this is intentional.

Creation configures owner and unique unit ID off-tree, uses the existing Rifle `_ready()` setup, then the existing `register_unit()` path. The unit is hidden until commit. Creation/registration can run SceneTree callbacks; if cancellation/removal wins or registration fails, the uncommitted unit is removed and the job is retained for retry unless it was cancelled. No hidden second population is maintained.

**Deployment commits when a fully initialized registered Rifle exists and its job is removed from the head, before showing the unit, issuing rally or publishing completion.** A visibility, queue or completion callback may remove that unit; the job cannot return or refund. `deployed` carries historical job/unit IDs and rally acceptance, avoiding freed node arguments. The latest deployment retains one small value record. Enqueue/cancel remain available during notifications; a local guard prevents recursive production advancement. No generic transaction framework is introduced.

Rally captures the current point at that commit and goes through `RTSUnit.move_to()` after navigation reachability validation. It does not modify selection or any existing unit's order. Changing rally affects future deployments only. A rejected rally leaves the newly committed unit idle and reports the rejection; the paid job stays completed. Normal move, attack, X Stop, damage/death and departure use the same controllers and field membership as preplaced Rifles.

## Architecture, lifetime and costs

`RTSBuilding` is a StaticBody3D with primitive visuals and one solid footprint; it has no movement, health or combat. It uses movement obstacle mask 4 and weapon-blocker mask 8. Geometry and footprint exclusions are created before initial navigation preparation through a small `TestField._build_obstacle()` extension. Thin visual roof/door trim is decorative, like existing obstacle caps. Fixed buildings are not repositioned or removed during normal gameplay, and no request/spawn rebuilds navigation.

`ProductionField` owns wallets and a small producer registry. Each `UnitProduction` is a RefCounted local queue with weak field/building references. On `tree_exiting`, final removal is reconciled deferred, after a synchronous same-field reparent can complete. Requests immediately reject a detached/queued producer or queued ancestor; permanent departure from a live field closes the queue and refunds all undeployed jobs once. Same-field reparent preserves the original queue, progress and registration. Whole-field teardown deactivates its wallet, closes queues without publishing refunds into dying nodes and clears registrations/claims. Closing queues disconnects terminal listeners, including callbacks that captured the queue itself.

`ProductionPanel` subscribes to one selected queue at a time and disconnects when selection changes or UI exits. Buttons bind stable job IDs and validate the current selected producer again at activation. Pointer events are consumed by GUI. Queue rows rebuild on notifications only; frame updates read one progress scalar. Identity and credits remain visible at the HQ, with no production control.

Steady training does constant work per producer; idle frames perform no navigation/physics queries. Spawn attempts make at most six candidate overlap queries and bounded local navigation/path checks, at the retry interval rather than every blocked frame. Same-frame claim comparisons scale with that frame's successful spawn admissions. Queue operations/snapshots are linear in configured capacity (default five). Registration checks traverse only ancestor links, not the scene tree. Unit-ID allocation, wallets and registries use direct lookups. Existing movement/combat internals and their cost bounds remain unchanged. No test instrumentation is loaded by playable scenes.

Godot's [direct shape query documentation](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html) describes full-volume overlap queries; the [Node lifecycle documentation](https://docs.godotengine.org/en/stable/classes/class_node.html) describes tree entry/ready/exit ordering. Exact-engine runtime checks below verify the behavior relied upon here.

## Validation commands and evidence

All validation uses the existing external wrapper and fixed 60 FPS test simulation. The inherited runner watchdog is 180 wall seconds; the external deadline is 240 seconds for suites. Successful assertions alone do not excuse native errors: the new suite checks EngineErrorProbe through teardown and successful logs are also audited after process exit for warnings/leaks.

```powershell
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--version')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','validation-output/m3-final-import.log')
$cases = @(
  @('original','milestone_checks'), @('stress','movement_stress_checks'),
  @('repair','movement_repair_checks'), @('combat','combat_checks'),
  @('corrective','combat_repair_checks'), @('fire','line_of_fire_checks'),
  @('sphere','spherical_projectile_checks'), @('load','combat_checks'),
  @('production','production_checks')
)
foreach ($graphical in @($false,$true)) {
  foreach ($case in $cases) {
    $name = $case[0] + $(if ($graphical) { '-graphical' } else { '' })
    $arguments = @('--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),
      '--log-file',('validation-output/m3-final-' + $name + '.log'))
    if (-not $graphical) { $arguments = @('--headless') + $arguments }
    if ($case[0] -eq 'load') { $arguments += @('--','--combat-load') }
    & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments $arguments
    if ($LASTEXITCODE -ne 0) { throw "$name failed: $LASTEXITCODE" }
  }
}
foreach ($scene in @('production_test','combat_test','line_of_fire_test')) {
  & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.',('res://scenes/' + $scene + '.tscn'),'--quit-after','120','--log-file',('validation-output/m3-final-launch-' + $scene + '.log'))
  if ($LASTEXITCODE -ne 0) { throw "$scene launch failed" }
}
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--path','.','res://scenes/production_test.tscn','--quit-after','120','--log-file','validation-output/m3-final-launch-production-graphical.log')
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.','--script','res://tests/combat_checks.gd','--log-file','validation-output/m3-negative-errors-expected.log','--','--verify-combat-errors')
# The last isolated command MUST return 1, not 0.
git diff --check
```

Every final matrix run exited **0**, with **2,802 passing assertions across 18 runs**:

| Suite | Headless checks / failures | Graphical checks / failures |
| --- | --- | --- |
| Original movement | 127 / 0 | 131 / 0 |
| Movement stress | 122 / 0 | 131 / 0 |
| Movement repair | 82 / 0 | 82 / 0 |
| Combat | 183 / 0 | 191 / 0 |
| Combat corrective | 230 / 0 | 230 / 0 |
| Line of fire, including obstacle load | 305 / 0 | 308 / 0 |
| Spherical projectile | 140 / 0 | 141 / 0 |
| Existing combat load | 7 / 0 | 7 / 0 |
| New production | **192 / 0** | **193 / 0** |

The original 2,417 assertions remain intact; no prior test script or assertion was migrated or weakened. The new suite contributes 385 assertions across its two modes. Production groups are credits/authorization **29**, queue/refunds **15**, spawning **34**, rally/integration **19**, GUI **30 headless / 31 graphical**, callbacks/lifecycle **51**, end-to-end combat **12**, and final node/error cleanup **2**.

Tests observe actual balances, stable job IDs, deployment counts and timestamps, unit registration/health/orders, physical capsule clearance, navigation around the barracks, target damage and node/signal cleanup. They reject early deployment through 4.9 seconds and require completion at 300–302 physics ticks for five-second jobs; each following job gets its own full training duration. A blocked exit is held across repeated retry intervals, then only one slot is cleared and the actual deployed capsule is checked beside five untouched occupants. Tests also cover wrong roots/configuration, captured payment after same-resource edits, active/waiting/completed cancellation, failed registration rollback and recovery, same-tick competing producers, and removal before/after the deployment boundary.

Viewport events exercise Train, Cancel, building/unit click/Shift/drag, hostile/ground right-click, passive-hover X and a focused key consumer. The end-to-end case begins with a real GUI payment and creation, follows the produced Rifle to its rally, selects it, issues an accepted contextual attack and observes hostile damage before Stop/death cleanup. It does not start with a precreated substitute unit. The one extra graphical assertion saves `validation-output/production_panel.png`; visual inspection found readable building identities, queue controls and the rally marker. The capture includes an isolated hostile-building selection fixture that is not in the playable scene. Screenshots supplement behavioral assertions.

Isolated fixtures make their scope explicit: secondary barracks used for wallet sharing do not train or claim dynamic navigation support; the simultaneous admission fixture supplies two queues the same exit to exercise their real deployment path. A test subclass can refuse registration or rally, exercising rollback/idle handling without modifying runtime algorithms. Native engine error probes and test-only callbacks are not loaded by the scene.

Workspace import and four direct launches (three headless, production graphical) exited **0**. Wrapper checks passed **5/0**, exit **0**, preserving expected child codes **0, 3, 2, 124**, and checking that the timed-out child tree was gone. The isolated `--verify-combat-errors` fixture returned expected **1** with one intentionally failed assertion. Internal timeout **2** is never treated as ordinary validation success. These negatives are excluded from the successful-log audit.

Fresh-copy validation copied **90 tracked/new nonignored files**, checked each SHA-256, and started without `.godot` or old validation output. The path is recorded in ignored `validation-output/m3-clean-path.txt`:

```powershell
$cleanRoot = Join-Path $env:TEMP ('fieldwork-m3-clean-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $cleanRoot | Out-Null
foreach ($relative in @(git ls-files --cached --others --exclude-standard)) {
  $destination = Join-Path $cleanRoot $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $relative -Destination $destination
  if ((Get-FileHash -LiteralPath $relative).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
    throw "Copy hash mismatch: $relative"
  }
}
Set-Content -LiteralPath validation-output/m3-clean-path.txt -Value $cleanRoot
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m3-clean-import.log')
foreach ($case in @(@('production','production_checks'),@('combat','combat_checks'))) {
  & .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),'--log-file',('D:/GitHub/Command_and_Concur_Generals/validation-output/m3-clean-' + $case[0] + '.log'))
  if ($LASTEXITCODE -ne 0) { throw "Fresh suite failed: $LASTEXITCODE" }
}
```

Fresh import exited **0**; fresh production passed **192/0** and combat **183/0**, both exit **0**. Only evidence log paths pointed back to the workspace; resources resolved in the fresh directory. Final documentation totals were completed afterward, with executable sources unchanged.

The completed audit covers **26 successful engine logs and 26 exit-zero wrapper transcripts**: workspace import, 18 matrix runs, four launches and fresh import/two suites. It found **zero errors, warnings, failed assertions or leaked-resource messages**. Evidence is in ignored `validation-output/m3-log-audit.txt`; development and intentional-negative logs are separate. `git diff --check` exited **0**. The source hash audit records only four changed pre-existing files: README, RTSUnit (shared unchanged capsule constants/factory), SelectionController (building-only selection branch), and TestField (obstacle construction hook). Existing project settings, scenes, movement algorithms, destinations, combat/line-of-fire/projectile code, weapons, old tests and wrapper hashes match the baseline. New `.gd.uid` files are source identity metadata; engine cache, captures, local paths and logs remain ignored.

## Acceptance

| Requirement | Result |
| --- | --- |
| 1. Fixed building selection and navigation/weapon blocking | PASS |
| 2. Credits and authorization enforced by APIs | PASS |
| 3. FIFO duration, capacity and exact deductions | PASS |
| 4. Exactly-once cancellation/refunds | PASS |
| 5. Unsafe spawns wait, then deploy without overlap/duplication | PASS |
| 6. Existing unit ownership, movement, combat and lifecycle | PASS |
| 7. Future-only rallies preserve existing orders | PASS |
| 8. GUI preserves selection and X Stop behavior | PASS |
| 9. Callback, departure and scene-reset safety | PASS |
| 10. New/prior suites and clean successful logs | PASS |
| 11. Documentation agrees with source and recorded results | PASS |
| 12. No construction, harvesting, destruction or later systems | PASS |

Acceptance is supported for this milestone's fixed-base prototype scope. Physical-input playtesting remains unverified as described below.

## Scope and remaining playtest

No construction, harvesting, vehicles from production, building damage/destruction/capture/sale, power, tech, population, fog, strategic AI, multiplayer, persistence or new combat mechanic is present. Building removal/reparent cases are lifecycle fixtures, not gameplay. Static navigation is prepared once and will not track arbitrary moved/removed fixture buildings. Only this flat field and normal Rifle configuration are supported. The bounded candidate search can deliberately hold despite more distant empty ground. Repeated rallies may become congested and use the existing mover's failure/replacement behavior; production does not add formation placement or push parked units.

Automated viewport mouse/keyboard events and graphical captures are not hardware input testing. A person should still play the select/train/cancel/rally/fight loop, judge building-label and queue readability at their window size, and check camera/selection feel. Physics and avoidance are not claimed lockstep deterministic, and fixed-step validation does not establish universal frame-rate guarantees.
