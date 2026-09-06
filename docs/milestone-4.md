# Milestone 4 — finite supply harvesting and automatic deposits

## Scope and preflight

Implemented against clean commit `0355349` (completed Milestone 3), using installed **Godot 4.7.2.stable.official.ed1daf0bf**. No engine change, dependencies, commits or tags. No applicable `AGENTS.md` was present in the repository or its ancestors. README, Milestone 3 and the relevant movement, combat-corrective and spherical-collision reports were read alongside ownership, selection, command results, registration, health/death, movement, wallet, production and GUI code. An ignored pre-edit snapshot path is recorded in `validation-output/m4-snapshot-path.txt`.

The complete prior 18-run regression matrix ran before source edits through `tools/run-godot.ps1`. **One pre-existing headless movement-stress run failed three of 122 checks**, exit **1**; all other baseline runs passed. In `choke_50`, unit 38 exhausted eight recoveries at `(3.791837, 0, 0.759899)` toward `(16, 0, 0)`. Arrival and settled-state assertions failed. Measured overlap reduction was **39.1%**, below the unchanged 40% threshold (enabled **125.5**, disabled **206.2** sampled pair-seconds). The settled displacement metric itself was zero; the settling assertion also requires ARRIVED state. This is preserved in `m4-pre-stress.log` and its wrapper transcript, not relabeled as a harvesting regression or hidden by retries.

An isolated **pre-edit** repeat passed **122/0**, exit **0**. The original baseline matrix contained **2,802 assertions, three failures**; its repeat is separate evidence. Baseline wrapper self-tests passed **5/0**, exit **0**. Physics/avoidance remains nondeterministic; no movement tuning, timeout, overlap threshold or existing test assertion was changed to obtain a pass.

## Play and defaults

Open `scenes/harvesting_test.tscn` and press F6, or run from PowerShell:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/harvesting_test.tscn
```

F5 remains the original movement field. Every earlier alternate scene remains available. The new scene extends `ProductionField`, keeps the same fixed camera, headquarters, barracks, obstacles, three friendly Rifles and three distant hostile Rifles, and adds two Collector Trucks and two neutral caches before startup navigation generation. Collectors have stable unit IDs 7 and 8; the next produced Rifle is 9. Caches have IDs 1 and 2. All shapes are original primitive placeholders.

Select collectors and right-click a yellow cache to harvest repeatedly. Right-click owned headquarters with cargo to deposit once and idle. Ground Move and X Stop interrupt harvesting but keep cargo. A new cache assignment retains cargo; a full collector returns to HQ first. Invalid commands preserve the previous valid order. Mixed selections accept only eligible collectors, retaining combat units' prior orders. Field APIs return the existing historical `CommandBatchResult`, including intended/accepted stable IDs, NONE/PARTIAL/COMPLETE and supersession; unit/work APIs return explicit booleans. No caller treats an object as an acceptance boolean.

| Configuration | Default / owner |
| --- | --- |
| Preplaced collectors / caches | 2 / 2 in `HarvestField` |
| Initial supply per cache | 2000 integer; field `cache_supplies`, cache `initial_supplies` |
| Cargo capacity | 100 integer; collector `cargo_capacity` |
| Loading | Up to 25 integer per completed 1.0 simulated second |
| Unloading | 1.0 simulated second; entire carried amount |
| Conversion | Exactly 1 supply = 1 credit, fixed for this milestone |
| Collector health / movement | 150 / 4 world units per second; configurable existing health/speed fields |
| Collector attack / retaliation | No weapon emitter; disabled |
| Collector body and crowd | Existing capsule radius 0.43, height 1.3; all crowd/recovery defaults inherited unchanged |
| Interaction proximity | 0.3 units from claimed access point; collector export, validated in [stopping distance, 0.5] |
| Starting credits | Existing 1000 per owner, `ProductionField.starting_credits` |
| Rifle production | Existing 100 credits, 5 seconds, 5 queue slots; no collector recipe |
| Debug | Off by default; existing F3 and `--movement-debug` retained |

Positive finite loading/unloading durations and positive integer capacity/amount are required for a new order. Cache contents and cargo live in separate instance state. Shared recipe and weapon resources hold no mutable harvesting inventory. A fresh scene restores configured supply, zero cargo, starting credits, empty queues and empty claims.

The existing credit/queue panel remains the spendable-balance display. A separate small panel appears only for selected collectors, showing cargo/capacity, short activity/rejection feedback and the assigned cache's current contents. Cache labels show identity, and “Empty” after depletion. There are no hardware statistics, frame statistics or per-unit diagnostic paragraphs in normal gameplay. No external monitoring settings were changed. Existing mouse filtering, focus-consuming X, S camera pan, Train and Cancel remain active.

## State, navigation and lifecycle

`CollectorTruck` subclasses `RTSUnit`; only the existing mover changes its position. `CollectorHarvest` is a per-instance RefCounted controller with weak references to collector, field, source and HQ. Its states are:

| State | Transition |
| --- | --- |
| IDLE | Accepted cache command begins TO_SUPPLIES, or RETURNING if full; manual HQ command begins RETURNING |
| TO_SUPPLIES | Ordinary navigation order; stopped and physically valid arrival begins LOADING |
| LOADING | Each completed interval moves min(remaining cache, free capacity, configured amount); full or depleted cargo returns |
| RETURNING | Ordinary navigation order to owned HQ; valid stopped arrival begins UNLOADING |
| UNLOADING | Completed duration commits cargo to credits; automatic work returns to the same nonempty cache, otherwise idles |
| BLOCKED | Missing HQ, denied interaction/access, or exhausted movement; retain cargo, release claims, require a new command |

The arrival tick never counts toward loading/unloading time. No timer runs during travel, idle or blocked states. Explicit Move/Stop clears the old generation, assignment, interval and claims before normal movement/Stop publishes; it never resumes automatically. New accepted assignments also invalidate old continuations. Rejected requests do not change command authority or discard cargo.

Each fixed target provides eight candidates, two per side separated by 2 units. Access centers sit 1.3 units outside its footprint; the interaction ray ends 0.1 units outside that face. Selection chooses the nearest reachable free slot with stable slot-order ties and validates synchronization, owning nav region, projection distance and endpoint connectivity using existing navigation helpers. Claims are weak, local to target IDs, and limited to eight per target. They release on trip departure, interruption, collector/cache/HQ departure, failure and completion. They reserve access centers, not future supplies. Ordinary units can still obstruct a slot; this is not a new traffic manager.

Candidate/path queries occur only on command validation and trip boundaries. Admission is revalidated during dispatch because earlier callbacks can invalidate targets or claims. Each planning call visits eight candidates at most; a successful initial dispatch can plan in preflight, per-recipient validation and trip start. This is bounded local work, not a global pairwise assignment. Per-tick harvesting uses weak-reference/membership/ancestry checks, scalar state and simulation time; it does not search the scene, rebuild paths or reset recovery. At arrival and transfer boundaries it checks a reused physical ray against obstacle/weapon-blocker masks, including hits from inside shapes. The mover retains its normal sampled progress, up to eight recoveries and 90-second per-order timeout. A failed trip keeps that movement failure/history visible and releases access. No teleport, collision bypass, impulses or runtime navigation rebake exists.

Depletion only hides the stock mesh and marks the cache empty; the body and nav footprint remain. Any cargo aboard returns to the assigned valid HQ. An empty collector idles and does not choose another source. Source departure follows the same partial-cargo rule. HQ disappearance or ownership mismatch stops the trip with cargo retained; there is no remote or other-owner deposit. Buildings remain preplaced and indestructible; removal fixtures test lifecycle only.

Collectors use existing health, ownership, registration and death cleanup. An enemy weapon can damage them, but attack permission requires a weapon emitter, so collectors neither shoot nor retaliate. Death zeroes undeposited cargo without a refund, drop or credit. Live detachment retains cargo while cancelling work and claims. Same-field reparenting restores one membership using existing enter/exit hooks; departure prunes selection and clears harvesting, so a fresh selection/command is required. Re-entry never resumes an old timer. Queued objects or queued ancestors cannot transfer. Scene shutdown deactivates the existing wallet and clears registrations/claims; terminal harvest controllers disconnect their listeners.

## Transfer commit points and callbacks

Loading validates the live collector, source, owned HQ, elapsed interval, stopped arrival and clear physical interaction. It consumes the interval, withdraws a bounded integer amount silently, and adds exactly that amount to cargo before any notification. Presentation refresh is silent. Then it emits a historical `HarvestTransfer`, followed by the cache change event. Repeated completion calls cannot consume the same interval.

Depositing revalidates membership, HQ kind/ownership, geometry, completed unloading and positive cargo. `PlayerCredits.credit()` silently adds to the **existing** field wallet; the harvester clears cargo and the interval before emitting the transfer and publishing wallet changes. Credit addition checks wallet activity, known owner, positivity and integer overflow. No second wallet, generic transaction engine, permanent resource ledger or production rewrite was added.

`HarvestTransfer` records kind, committed integer amount, stable collector/owner identity, target identity and order generation. Load target identity is the stable cache ID; deposit target identity is the current HQ instance ID, a historical value only. It remains meaningful if a listener spends the deposit, changes work, detaches or frees involved objects. Transfer events precede wallet publication, so tests can measure committed deposits independently of a later balance. Zero cargo cannot mint a second deposit.

An active-transfer guard prevents recursive completion; an advancing guard prevents re-entering the simulation tick. Generation and weak-reference checks guard all post-notification continuations. A callback may spend on normal production, Stop, Move, replace the cache or immediately remove collector/cache/HQ/field. Cache change events use a small RefCounted emitter because Godot forbids freeing a Node while one of that Node's script methods is locked on the call stack. The cache's visual method returns before external notification. This is notification lifetime management, not a second inventory or transaction system.

## Coverage and validation

The new tracked `tests/harvesting_checks.gd` extends existing input/assertion helpers. Every wait has a fixed simulation budget, and the inherited process watchdog is 180 seconds; all engine calls use the external wrapper (normally 240 seconds). No existing test or assertion was changed. Fixture-only initial positions, physical enclosures, intermediate walls, removal/reparenting and supported initial-credit/cache/capacity settings are labeled in source. Cargo and earnings are obtained by actual command/navigation/timed transfers, not fabricated arrival flags or test-granted credits.

Coverage includes exact 60-tick loading/unloading boundaries, repeat trips, partial depletion, shared last-five-supply contention, capacity-35 transfers `[25,10,17]`, independent cargo, nested completion, immediate production purchase from credit notification, Stop/Move/reassignment, immediate detach/free of all involved objects, historical batches/supersession, ownership/queued ancestors, failed movement history, wall-blocked interaction, real hostile weapon damage and death. A controlled ledger accounts for remaining supply, detached cargo, committed deposits and destroyed cargo; a separate wallet equality includes normal production spending/refunds. A zero-credit fixture earns 100, buys a normal Rifle through viewport UI, observes real deployment and rally, and commands that exact unit to deal verified weapon damage.

Graphical and headless viewport events exercise collector selection, cache/ground/HQ commands, passive-hover X, focused-control X consumption, S through the Input/viewport pipeline, and existing Train/Cancel. The graphical capture is supplementary, not the acceptance oracle. Physical keyboard/mouse playtesting has not been performed.

The final matrix passed **3,399 assertions across 20 runs**, every run exit **0**:

| Suite | Headless checks / failures | Graphical checks / failures |
| --- | --- | --- |
| Original movement | 127 / 0 | 131 / 0 |
| Movement stress | 122 / 0 | 131 / 0 |
| Movement repair | 82 / 0 | 82 / 0 |
| Combat | 183 / 0 | 191 / 0 |
| Combat corrective | 230 / 0 | 230 / 0 |
| Line of fire / obstacle load | 305 / 0 | 308 / 0 |
| Spherical projectile | 140 / 0 | 141 / 0 |
| Existing combat load | 7 / 0 | 7 / 0 |
| Production | 192 / 0 | 193 / 0 |
| Harvesting | **298 / 0** | **299 / 0** |

The unchanged prior suites contribute 2,802 assertions and the new suite contributes 597. Harvest groups: loop/defaults/actual hostile damage **32**, quantities/concurrent collectors **19**, commands **38**, callbacks **113**, lifecycle/conservation **45**, blocked routes/interactions **15**, UI **19 headless / 20 graphical**, earned production/combat **14**, and recognized-case/final cleanup **3**. The extra graphical assertion saves `validation-output/harvesting_panel.png`. Captured-frame inspection at 1280×800 found readable cargo/activity/cache contents and unobscured HQ identity, with no hardware-statistic HUD; it used a 200-supply test fixture, not the scene's 2000-supply default.

Workspace import and five launches (harvesting, production, combat and line-of-fire headless, plus harvesting graphical) all exited **0**. The fresh-copy import and three headless suites passed: harvesting **298/0**, production **192/0**, combat **183/0**, all exit **0**. This fresh directory contained **106 tracked/new nonignored files**, each SHA-256 checked against the workspace, and initially no `.godot` or old validation output. Only evidence logs were written back to the workspace. Final documentation was completed afterward without executable source changes.

The audit covers **30 successful engine logs and 30 exit-zero wrapper transcripts**, with **zero engine errors, warnings, failed assertions or leaked-resource reports**. Six broad “orphan” keyword matches were inspected and were successful production assertion descriptions, not engine diagnostics. Details are in ignored `validation-output/m4-log-audit.txt`; run summaries are in `m4-final-runs.csv`. Development runs and intentional failures are excluded, and preflight failures remain separately recorded above.

Wrapper self-tests passed **5/0**, exit **0**, requiring child codes **0, 3, 2, 124** and proving timed-out processes are gone. The separate native-error negative fixture returned expected **1**. Timeout **2** and external timeout **124** are never accepted as ordinary suite success.

From the repository root in PowerShell 7, exact validation commands are:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--version')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--editor','--import','--quit','--log-file','validation-output/m4-final-import.log')
$cases = @(@('original','milestone_checks'),@('stress','movement_stress_checks'),
  @('repair','movement_repair_checks'),@('combat','combat_checks'),
  @('corrective','combat_repair_checks'),@('fire','line_of_fire_checks'),
  @('sphere','spherical_projectile_checks'),@('load','combat_checks'),
  @('production','production_checks'),@('harvesting','harvesting_checks'))
foreach ($graphical in @($false,$true)) {
  foreach ($case in $cases) {
    $name = $case[0] + $(if ($graphical) { '-graphical' } else { '' })
    $arguments = @('--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),
      '--log-file',('validation-output/m4-final-' + $name + '.log'))
    if (-not $graphical) { $arguments = @('--headless') + $arguments }
    if ($case[0] -eq 'load') { $arguments += @('--','--combat-load') }
    & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments $arguments
    if ($LASTEXITCODE -ne 0) { throw "$name failed: $LASTEXITCODE" }
  }
}
foreach ($scene in @('harvesting_test','production_test','combat_test','line_of_fire_test')) {
  & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.',('res://scenes/' + $scene + '.tscn'),'--quit-after','120','--log-file',('validation-output/m4-final-launch-' + $scene + '.log'))
  if ($LASTEXITCODE -ne 0) { throw "$scene launch failed" }
}
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--path','.','res://scenes/harvesting_test.tscn','--quit-after','120','--log-file','validation-output/m4-final-launch-harvesting-graphical.log')
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.','--script','res://tests/combat_checks.gd','--log-file','validation-output/m4-negative-errors-expected.log','--','--verify-combat-errors')
# Only the isolated last command must return 1. Normal runs must return 0.
git diff --check
```

The recorded final-run driver is ignored `validation-output/m4-final-validation.ps1`; it also retains per-run wrapper transcripts and continues to collect results if a suite fails. Its load-only invocations included a redundant `--log-file` pair after the user-argument separator; that ignored pair does not affect the suite or the real engine log flag before `--`. The commands above omit that redundant user argument. Earlier baseline commands used the same prior-suite arguments under the `m4-pre-` log prefix; the initial failure stopped that driver, after which the untouched remaining cases were run and the failing suite repeated once separately.

Fresh-copy commands:

```powershell
$cleanRoot = Join-Path $env:TEMP ('fieldwork-m4-clean-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $cleanRoot | Out-Null
foreach ($relative in @(git ls-files --cached --others --exclude-standard)) {
  $destination = Join-Path $cleanRoot $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $relative -Destination $destination
  if ((Get-FileHash -LiteralPath $relative).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
    throw "Copy hash mismatch: $relative"
  }
}
Set-Content -LiteralPath validation-output/m4-clean-path.txt -Value $cleanRoot
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--editor','--import','--quit','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m4-clean-import.log')
foreach ($case in @(@('harvesting','harvesting_checks'),@('production','production_checks'),@('combat','combat_checks'))) {
  & .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),'--log-file',('D:/GitHub/Command_and_Concur_Generals/validation-output/m4-clean-' + $case[0] + '.log'))
  if ($LASTEXITCODE -ne 0) { throw "Fresh suite failed: $LASTEXITCODE" }
}
```

`git diff --check` exited **0**. Snapshot hash comparison found only six modified pre-existing files: README; RTSUnit's unchanged default visual extracted into a hook, optional unarmed health and a post-signal validity guard; CombatController's optional weapon construction/advance; weapon-required TeamRules attack permission; silent wallet credit; and two contextual SelectionController signals/branches. New files are the harvesting scene, collector/harvest controller, cache, access field, transfer value, contextual panel, tests, source UID metadata and this report. Existing project/input settings, scenes, mover/recovery tuning, destination logic, health authority, weapon/collision code, production implementation, recipe, all old tests and wrapper match the pre-edit snapshot. Engine cache, evidence logs, captures, local drivers and machine-specific snapshot/clean paths remain ignored. Nothing was staged or committed.

## Acceptance and limits

| Requirement | Result |
| --- | --- |
| 1. Collectors and finite caches reuse ownership/navigation | PASS |
| 2. Loading obeys capacity, timing and source limits | PASS |
| 3. Correct existing wallet receives exactly-once deposits | PASS |
| 4. Repeated trips and finite depletion | PASS |
| 5. Move, X Stop, replacements and mixed historical batches | PASS |
| 6. Blocked access/missing HQ retain cargo and prevent remote credit | PASS |
| 7. Death, departure and callbacks preserve accounting | PASS |
| 8. Earned supply funds normal production and verified combat | PASS |
| 9. Final old/new suites and successful-run logs are clean | PASS — pre-existing intermittent stress failure recorded above |
| 10. Readable contextual UI without hardware-statistic clutter | PASS — automated input and captured-frame inspection |
| 11. Documentation agrees with source and recorded validation | PASS |
| 12. No construction, collector production or later systems | PASS |

This remains a flat, static two-collector prototype. Eight local access positions can all be obstructed; a safe blocked state requires a fresh player command and does not promise traffic deadlock resolution. No arbitrary movable cache/building geometry or runtime rebaking is supported. The test enclosures and departures are not construction or building-destruction features. There is no collector production, regeneration, theft, trading, cargo drop/recovery, building repair, power, technology, fog, strategic AI or multiplayer.

Human keyboard/mouse playtesting is **NOT VERIFIED**. A person should play both collectors through several trips, interruption and manual return, then Train/Cancel/rally/fight, and judge label readability, access congestion and camera/selection feel at their own window size. The captured image and automated viewport tests do not establish physical input testing. Existing intermittent stress behavior, physics lockstep determinism, varied terrain, arbitrary crowds and universal frame-rate guarantees remain outside this acceptance. No next milestone was started.
