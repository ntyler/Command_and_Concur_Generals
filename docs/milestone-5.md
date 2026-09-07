# Milestone 5 — player-placed barracks and timed construction

**M5.0.1 status: ACCEPTANCE STILL BLOCKED.** The [diagnosis and targeted repair](milestone-5.0.1.md) fixes the separately captured baseline parked-neighbor deadlock. Three-unit and full captured-arrangement regressions fail before and pass after; the post-repair matrix passes 4,224 assertions and the five graphical/matching headless stress pairs pass. The original M5 unit 4 failure lacks the historical telemetry needed to connect its mechanism and remains unresolved. Cancellation-cleanup failure fixtures still pass 46 assertions in each display mode. The historical failed matrix below remains unchanged; passing post-repair runs do not erase it or close the original failure.

## Scope and controls

This adds `res://scenes/construction_test.tscn` to Milestone 4 at `facf285`. The F5 main scene and all earlier alternate scenes remain unchanged. The construction scene retains one owned headquarters, two collectors, two finite caches, three friendly Rifles, three distant hostile Rifles using existing retaliation, static obstacles and the original fixed camera. It removes the preplaced barracks only in this scene.

Select the owned HQ, then **Build Barracks**. Move the free translucent 6 × 5 preview over terrain. Its text states validity or the rejection reason. Left click requests construction; invalid clicks retain placement and spend nothing. Right click or Escape cancels the free preview, without also issuing movement/rally. GUI clicks get first refusal. Named `placement_confirm` and `placement_cancel` actions supplement the existing controls. Camera pan, wheel zoom, unhandled X Stop and focused-control key consumption retain their existing routing. Normal click/drag/Shift selection returns when placement ends.

Selected unfinished sites show progress and Cancel; completed sites expose the existing production panel. The original controls/credits presentation is reused. Placement text appears only while placing. There is no hardware-statistic overlay, always-on performance instrumentation or new diagnostics hotkey; existing F3 remains off by default. External monitoring applications/settings were not changed.

| Rule | Default / source |
| --- | --- |
| Buildable type | Barracks only, fixed rotation, automatic construction |
| Cost / construction duration | 400 integer credits / 10 simulated seconds, `construction/barracks.tres` |
| Footprint / height | Fixed 6 × 5 / configurable 2.6; same collider before and after completion |
| Unfinished limit | One, including preparation, failure and pending cancellation cleanup |
| Cancellation | Original full captured cost, before operational completion only |
| Navigation timeout | 5 simulated seconds per submitted update, `ConstructionField.navigation_timeout` |
| Unchanged economy | 1000 starting credits per owner; 2000 supplies/cache; Rifle 100 credits, 5 seconds, queue capacity 5 |
| Unchanged collectors | Capacity 100, 25 loaded per second, one-second unload, same speed/health/orders |

Cost, duration and height are typed resource exports and captured when accepted. The footprint/type/one-site rule deliberately constrain this prototype. No worker or collector is assigned to construction. Completed buildings remain indestructible and cannot be sold.

## Authoritative placement

`BuildingConstruction.place()` returns a `ConstructionResult` with `accepted`, written `reason`, stable field-local `site_id` and captured `paid` integer. Rejected results have no site or charge. The HQ argument accepts stale references at the boundary and validates them before typed access. Authorization requires a live registered HQ owned by the requester, the supported definition instance, valid configured values, sufficient current wallet funds, a free unfinished slot and available navigation.

The public request revalidates geometry on a physics tick, independently of the advisory preview. The complete footprint **grown by 0.85** must fit within construction bounds `Rect2(-27,-21,54,43)` and the map's inner clearance boundary. It must avoid every committed static/site rectangle also grown by 0.85, all protected access rectangles, physical blockers and live unit bodies. Full box physics queries include units, buildings, obstacles and caches. An additional live registered-unit bounds check covers new or moved units whose physics broad phase has not synchronized yet. This is deliberately conservative; it never relocates, snaps, deletes or teleports a unit to admit a building. Five ground rays at the clearance corners and center require y≈0 and an upward normal; this is validation of the existing single flat terrain, not general terrain sampling.

Protected geometry is explicit in `ConstructionField.protected_areas()`:

- Three essential corridors: `Rect2(-16.7,-13.3,28,2)`, `Rect2(-17,-13.3,3,9)` and `Rect2(-27,10,25,2)`.
- Each live HQ/cache's eight existing dock-to-access segments, expanded by 0.7 on all sides. Protection includes the full interaction segment and collector body neighborhood.
- Each committed barracks' east exit neighborhood: from its east face, 3.1 units east and ±1.8 units north/south. It covers the door link and all six ordinary spawn samples, with body margin. A new site's own exit also must fit inside the build area and clear existing obstacle clearance.

Green outlines show the fixed build boundary. Gold outlines show initial protected access/corridors; dynamically added exits are enforced by the same validity text. Two usable example centers are `(-12,0,3)` and `(-3,0,16)`, subject to live occupancy. Opening/moving the ghost changes no collision object, producer registry, footprint, navigation mesh or wallet. Physics validation runs at 10 Hz for advisory status and freshly for every confirmation; pointer/ghost terrain tracking runs in physics.

## Commit, completion and cancellation

`BuildingConstruction` is a field-local RefCounted coordinator. `ConstructionSite` stores instance state and a weak body reference. There is no second wallet, autoload, generic transaction framework or duplicate production algorithm.

Placement silently debits the existing `PlayerCredits`, captures price/duration, allocates one identity, reserves the rectangle, creates the ordinary building collider/visual, registers its normal `UnitProduction` and requests navigation before wallet/site notifications. The building's `operational=false` gates **all production API availability**, including enqueue and rally. A listener observes coherent committed state and may cancel, spend remaining credits, change selection or immediately remove the site/field. Results remain historical acceptance even if such a callback cancels the newly accepted site. Placement input checks its own lifetime/generation before continuing, and preserves a listener's selection change.

Lifecycle:

`PREPARING → CONSTRUCTING → OPERATIONAL`

`PREPARING → FAILED`; any PREPARING/CONSTRUCTING/FAILED site may commit `CANCELLING → CANCELLED`.

Only matching-generation, query-verified navigation readiness enters CONSTRUCTING. It records the physics frame and accumulates no time on that frame. Subsequent physics deltas accumulate to the captured duration. The first transition to OPERATIONAL is the completion commit: body eligibility is enabled, the unfinished slot is released, and normal production becomes available before the completion signal. The same body, site identity, owner, collider, recipe and queue object survive. No second geometry/navigation change occurs at completion. Cancellation before this commit wins; after it, cancellation rejects without a refund. At 60 fixed simulation FPS the tests require 600 full post-ready ticks (floating point accumulation can finish on the next tick).

Cancellation sets CANCELLING, marks the refund consumed and silently refunds the original price once. It disables eligibility/collision, removes selection/producer registration and the authoritative footprint, queues the body for deletion and requests restored navigation before publishing notifications. Repeated or recursive cancellation rejects. The unfinished slot remains unavailable until matching cleanup readiness; then the cancelled record is removed. A remaining operational body's ordinary production queue retains its existing captured-price cancellation and safe spawn behavior.

Permanent unfinished-body departure reconciles after the tree operation and cancels/refunds once. Same-field reparent retains identity. Operational-body removal in lifecycle fixtures removes its footprint without selling/refunding construction; the existing producer handles any undeployed job refunds. A removal during another site's preparation updates that site's generation to the latest combined geometry. Scene exit closes wallet/work, clears site records and disconnects terminal signals. Deferred departure reconciliation retains only weak field/node references and cannot touch a replacement field.

Preparation failure is visible on selected-site status, retains the paid occupied site, and keeps its full captured cancellation eligibility. It does not start construction or expose production, retry indefinitely or charge again. A cancellation submits one fresh restoration update. If restoration itself fails, the refund has already committed exactly once, geometry reservation/collision are removed, and the slot remains blocked; HQ feedback explains that the field must be reloaded. That is a bounded failure state, not automatic success or an unbounded rebake loop.

## Navigation and integration

The existing flat rectangle-partition generator was extracted to `TestField.create_navigation_mesh(rectangles)` with its polygon algorithm unchanged. Construction supplies immutable initial rectangles plus committed site rectangles; it never scans visual/transient scene geometry. The same 0.85-unit clearance produces actual navigation holes for sites and operational buildings.

`ConstructionNavigation` serializes submissions and coalesces pending changes to the latest rectangle snapshot. Requesting an update marks units suspended; mesh construction/submission occurs on a later physics tick after the site stores its generation. Each submission captures its field, region RID, map RID, old map and region iterations, intended mesh and rectangles. Readiness requires the same live field/RIDs/mesh, nonzero changed map **and** region iterations, region-map membership, and actual closest-point/owner queries witnessing current and removed holes plus open ground. Removed footprints are probed as well as added ones. An older synchronized submission cannot resume units or start construction when a newer generation is pending. A five-second simulated deadline fails explicitly. No arbitrary sleep substitutes for synchronization, and no force-map-update call is used. Godot documents the relevant iteration semantics in [NavigationServer3D](https://docs.godotengine.org/en/stable/classes/class_navigationserver3d.html).

Existing movers clear submitted avoidance velocity and briefly wait with physical collision intact. Their player order/version, assigned slot, overall elapsed deadline, recovery count, stall history and signed path-progress credit/debt survive. Readiness queries a new path and rebases that distance metric at the unchanged unit position; it does not call `move_to()` as a new player command. An invalidated final destination fails at readiness without projection to another slot. A recovery waypoint that became invalid is dropped while retaining the recovery budget. Arrived units stay arrived. During a persistent failure, active movement still reaches its original bounded command timeout. Suspension is removed on departure so it cannot follow a unit into another field.

Collector work and combat pursuit pause during the brief update; weapon cooldowns continue. Production timing may continue, but safe spawn/rally admission waits for navigation availability. This preserves cargo and avoids treating a transient old path as a permanent access failure. The earned fixture checks actual deposits across construction and conserves all finite supplies. Existing hitscan and spherical rocket queries see the normal building blocker mask (8); construction adds no health/damage target or weapon special case. Ghosts are visual meshes only and actual units/projectiles pass through them.

The generator is synchronous CPU work for a small flat rectangle set; runtime navigation-server synchronization is asynchronous. Neither large maps nor frequent changes are supported claims. Geometry generation has the existing partition-grid cost (quadratic cell count with a scan of obstacle rectangles per cell), invoked only on a committed change. Placement checks scale with registered units/obstacles only at confirmation/advisory refresh; mover pause/resume visits units once per update. Normal gameplay does not load test scripts, pairwise test sampling, logging probes or capture code.

## Preflight and intermittent stress evidence

Exact installed engine: **4.7.2.stable.official.ed1daf0bf**, unchanged. No applicable AGENTS.md existed in the repository/ancestor scope. README and milestone documentation through 4, input/project settings, movement/navigation/selection, harvesting, production/wallet/lifecycle and wrapper/tests were inspected. Git HEAD was `facf285` and the index/worktree were clean. A hashable copy of all 106 tracked baseline files was retained outside the repository before editing. Engine, backend, dependencies, existing tests/tolerances and unrelated gameplay settings were not changed; nothing was staged or committed.

The full pre-edit matrix ran **3,399 checks across 20 runs**. Nineteen runs passed; headless stress returned **1**, with **122 checks / 2 failures**. Exact failures:

1. `choke_30: all units arrive within configured tolerance` — unit 16 exhausted eight recoveries and ended FAILED at `(7.331766,0,-0.756914)`, assigned `(12,0,1.5)`.
2. `choke_30: no arrival jitter or stationary total overlap for three seconds` — this assertion also requires all arrivals; minimum settled separation was about 0.580000, maximum stationary displacement zero.

That route finished movement processing at 36 simulated seconds, with 70.6 overlap pair-seconds and a longest sampled pair run of 26.1 seconds. The separate 50-unit avoidance comparison **passed**, 64.9 enabled versus 206.2 disabled pair-seconds, a 68.5% reduction. Evidence is `validation-output/m5-pre-stress.log` and the corresponding wrapper transcript; the complete baseline matrix is `m5-pre-matrix.csv`.

Milestone 4's older pre-edit log had **three** failures: the analogous **50-unit** arrival and settled assertions (unit 38 at `(3.791837,0,0.759899)`, destination `(16,0,0)`, eight recoveries) and only **39.1%** overlap reduction (125.5 versus 206.2). This milestone's baseline differs in group size, failed unit, geometry position and comparison outcome. Matching assertion wording does not establish an identical root cause. No general crowd rewrite or demonstrated intermittent-failure fix is claimed.

All three additional **before-edit** repeats ran the entire unchanged headless `movement_stress_checks.gd` at fixed FPS 60 with the normal 240-second wrapper. They are separate from the main matrix:

| Before repeat | Checks / failures | Exit | Enabled / disabled pair-seconds | Reduction |
| --- | --- | --- | --- | --- |
| 1 | 122 / 0 | 0 | 58.9 / 206.2 | 71.4% |
| 2 | 122 / 0 | 0 | 75.6 / 206.2 | 63.3% |
| 3 | 122 / 0 | 0 | 56.3 / 206.2 | 72.7% |

These passing repeats do not negate the failed main-matrix run. The overlap metric is unchanged: every sixth 60 Hz physics tick, each unordered pair whose center distance is below 0.6 contributes 0.1 pair-seconds. Summation is over pairs and sampled moving duration, not unique elapsed time or continuous contact. The disabled comparison changes only `crowd_enabled` in the same fixed 50-unit gate setup. Per-frame wall interval metrics in the stress harness are instrumented observations, not gameplay FPS guarantees.

## Validation results

The final main matrix ran **3,936 checks across 22 runs**, with **2 failed assertions** in graphical stress (exit **1**); the other 21 runs returned **0**. Earlier tests retained every assertion. New construction coverage passes all **537 assertions** across the two display modes; graphical checks add three screenshot-save assertions, with behavioral acceptance also tested through viewport events, actual paths, movement, accounting and combat.

| Suite | Headless checks / failures | Graphical checks / failures |
| --- | --- | --- |
| Original movement | 127 / 0 | 131 / 0 |
| Movement stress | 122 / 0 | **131 / 2** |
| Movement repair | 82 / 0 | 82 / 0 |
| Combat | 183 / 0 | 191 / 0 |
| Combat corrective | 230 / 0 | 230 / 0 |
| Line of fire / obstacle load | 305 / 0 | 308 / 0 |
| Spherical projectile | 140 / 0 | 141 / 0 |
| Existing bounded combat load | 7 / 0 | 7 / 0 |
| Production | 192 / 0 | 193 / 0 |
| Harvesting | 298 / 0 | 299 / 0 |
| Construction | **267 / 0** | **270 / 0** |

The three required **after-change** stress repeats were separate bounded runs after the matrix, all retained:

| After repeat | Checks / failures | Exit | Enabled / disabled pair-seconds | Reduction |
| --- | --- | --- | --- | --- |
| 1 | 122 / 0 | 0 | 76.1 / 206.2 | 63.1% |
| 2 | 122 / 0 | 0 | 65.0 / 206.2 | 68.5% |
| 3 | 122 / 0 | 0 | 62.5 / 206.2 | 69.7% |

The final matrix's separate stress comparisons passed at 68.3/206.2 (66.9%) headless and 65.9/206.2 (68.0%) graphical. Its graphical failure was instead `cluster_50: all units arrive within configured tolerance` plus `cluster_50: no arrival jitter or stationary total overlap for three seconds`. Unit 4 exhausted eight recoveries at `(31.41587,0,19.78682)`, assigned `(33,0,22)`. The route ended movement processing at 36 seconds, had 105.9 overlap pair-seconds, longest sampled run 27.2 seconds, minimum settled separation about 0.579999 and zero stationary displacement. This is a distinct observed scenario from the pre-edit gate failure. It is retained rather than replaced by a passing rerun.

Passing repeats do not demonstrate a fix for the pre-edit intermittent failure or prove lockstep determinism. Main/repeat results are retained in `m5-final-runs.csv`; `m5-final-matrix.csv` contains the initial import plus the 22 matrix rows. All logs and transcripts are in ignored `validation-output/` under distinct pre/final/repeat prefixes.

An earlier complete implementation-validation round passed **3,914/0** across 22 runs, and its three separate headless stress repeats passed **122/0** each (75.3/206.2, 63.5%; 60.1/206.2, 70.9%; 68.5/206.2, 66.8%). Its fresh-copy suites passed **929/0** and 38 success logs were clean. That round is preserved in `validation-output/m5-round1/`; it is not the final acceptance matrix. A subsequent source review found that `UnitProduction.close(false)` itself emits a notification: cancellation had to move that close after footprint removal and the navigation request. Dedicated immediate body/field deletion listeners now verify the ordering; development run 7 passed **267/0**, native errors 0. The entire matrix and the required three repeats were rerun after this correction, yielding the final results above.

The new graphical cluster failure was investigated on the **untouched pre-edit source snapshot**, using the same engine, fixed FPS, display mode and external deadline. Baseline import returned 0. Three additional complete graphical stress runs all passed **131/0**, exit 0; their enabled/disabled comparisons were 60.9/206.2 (70.5%), 67.1/206.2 (67.5%) and 67.1/206.2 (67.5%). These are post-edit investigations of baseline code, not part of the three required before-edit repeats.

A second bounded diagnostic isolated the same original 50-unit gate-to-cluster sequence on baseline code. Its ignored script extends the unchanged stress harness, calls `_fresh(50)`, `_assignment_checks(50)`, then the original `_route("choke_50", Vector3(10,0,0),75,true)` and `_route("cluster_50", Vector3(30,0,22),75)`. No route assertion, timeout, tolerance, movement value, spawn position or destination was changed. The unrelated 30-unit and disabled-comparison portions are omitted **only in this diagnostic subset**, not in either main matrix or any required repeat.

| Baseline diagnostic repeat | Checks / failures | Exit | Observation |
| --- | --- | --- | --- |
| 1 | 39 / 0 | 0 | Both routes pass |
| 2 | 39 / 0 | 0 | Both routes pass |
| 3 | 39 / 2 | 1 | Gate arrival and settled checks fail; cluster passes |
| 4 | 39 / 0 | 0 | Both routes pass |
| 5 | 39 / 0 | 0 | Both routes pass |
| 6 | 39 / 0 | 0 | Both routes pass |

Diagnostic 3's failed gate unit was 50 at `(6.255316,0,1.410807)`, assigned `(10,0,6)`, after eight recoveries. This establishes another failure in unchanged baseline crowd behavior, but **does not establish the cause of the final graphical cluster failure**. Neither matching arrival/settled assertion names nor passing reruns prove identical causes. The cluster failure remains unclassified; there is no claim that it is fixed or conclusively pre-existing. **Full crowd-regression acceptance is NOT VERIFIED.** No crowd rewrite or test relaxation was made to obtain a green result. Evidence is `m5-investigation-baseline-graph-1/2/3.log`, `m5-investigation-baseline-cluster-1..6.log` and their transcripts; the diagnostic source is `validation-output/m5_baseline_cluster_probe.gd`.

Construction groups cover placement/input, accounting/timing/callbacks, actual topology/traversal and departure generations, production/weapons/input integration, explicit preparation/synchronization failure, and earned construction. The earned fixture starts with **zero credits and a finite 500-supply cache**, uses real trips to earn 400, builds while the collector finishes earning the last 100, and verifies total supply/cargo/deposit conservation at every transfer. The normal Rifle recipe consumes that 100, deploys, actually traverses its rally and then pursues/damages one of the original hostile units. No direct credit grant, manufactured cargo or teleported produced unit is used as earned-loop evidence.

Workspace import and seven relevant launches passed: main scene, construction, harvesting, production, combat and line-of-fire headless, plus construction graphical. A fresh directory contained **129 tracked/new nonignored files**, SHA-256 matched to the workspace and initially without `.godot` or old evidence. Fresh import and four headless suites passed: construction **267/0**, harvesting **298/0**, production **192/0**, combat **183/0**; all exit 0, **940 assertions**. Documentation was finalized afterward without executable-source changes.

Audit: the final round has **37 successful engine logs and 37 matching exit-zero wrapper transcripts**, with **zero** errors, warnings, failed assertions or leaked-resource reports in those successful runs. The failed graphical stress log is explicitly excluded from this success-only count and retained/reported above; it contains the two failed assertions. `m5-log-audit.txt` records the distinction. Earlier archived successes and baseline investigations remain separate. Wrapper self-tests passed **5/0**, exit **0**, checking child exit codes **0, 3, 2, 124** and absence of timed-out processes. The isolated native-error fixture returned expected **1**. These intentional negatives remain separate from success logs; **2 and 124 are never normal validation success**.

Measured successful preparations, from submission/CPU generation to query readiness (nine samples in each final construction run):

| Mode | CPU mesh build | Submission-to-readiness wall time | Simulated synchronization time |
| --- | --- | --- | --- |
| Headless | 0.140–0.324 ms | 1.002–2.048 ms | 0.050000 s |
| Graphical | 0.139–0.183 ms | 4.721–9.988 ms | 0.050000 s |

These are instrumented fixed-60-FPS playback observations on this machine, which can run faster than real time. They exclude waiting before a submission behind an earlier generation and are not acceptance-to-readiness latency guarantees. The configured construction timer remains ten simulated seconds after readiness. No benchmark HUD is added.

Captured-frame inspection at 1280×800 confirmed readable placement reason, selected-site Cancel/progress and two operational barracks with the normal production panel. Captures are `construction_valid_preview.png`, `construction_selected_site.png`, and `construction_two_operational.png`. Physical keyboard/mouse playtesting is **NOT VERIFIED**.

Development history is retained separately: import and the initial construction launch returned 0. `m5-dev-construction-1` returned 1 for two test parse errors (typed impossible class check and missing explicit WeakRef type). Run 2 returned 1, **202 checks / 1 assertion failure**, with two native script errors: a freed HQ crossing a typed public boundary, and a test reading a not-yet-computed firing line while the prior shot cooldown was still active; its aborted coroutine/self-capturing fixture also reported exit leaks. The public HQ boundary now validates stale Variants before casting; the firing fixture waits for the actual configured cooldown; fixture signal lifetimes are explicit. Run 3 passed **214/0**, native errors 0, with verbose leak audit. Graphical run 4 passed **217/0**. Expanded headless runs 5 and 6 passed **252/0** and **256/0**, native errors 0. The expansions cover cancellation-signal deletion/spending, viewport-confirm deletion, captured configuration, suspended-unit departure, overlapping lifecycle generations, synchronization timeout, actual ghost traversal and ghost rocket flight. No existing test assertion or gameplay tuning was weakened.

## Exact validation commands

Run from the repository root in PowerShell 7. The ignored `validation-output/m5-final-validation.ps1` records the actual driver and continues collecting results on a failed run; the following shows its engine invocations without output redirection/CSV bookkeeping. Always inspect `$LASTEXITCODE`; expected negative codes below apply only to the isolated fixtures.

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& .\tools\run-godot.ps1 -GodotPath $godot -GodotArguments @('--version')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--editor','--import','--quit','--log-file','validation-output/m5-final-import.log')
$cases = @(@('original','milestone_checks'),@('stress','movement_stress_checks'),
  @('repair','movement_repair_checks'),@('combat','combat_checks'),
  @('corrective','combat_repair_checks'),@('fire','line_of_fire_checks'),
  @('sphere','spherical_projectile_checks'),@('load','combat_checks'),
  @('production','production_checks'),@('harvesting','harvesting_checks'),
  @('construction','construction_checks'))
foreach ($graphical in @($false,$true)) {
  foreach ($case in $cases) {
    $name = $case[0] + $(if ($graphical) { '-graphical' } else { '' })
    $arguments = @('--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),
      '--log-file',('validation-output/m5-final-' + $name + '.log'))
    if (-not $graphical) { $arguments = @('--headless') + $arguments }
    if ($case[0] -eq 'load') { $arguments += @('--','--combat-load') }
    & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments $arguments
    Write-Output "$name exit=$LASTEXITCODE"
  }
}
foreach ($repeat in 1..3) {
  & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/movement_stress_checks.gd','--log-file',("validation-output/m5-final-stress-repeat-$repeat.log"))
  Write-Output "repeat=$repeat exit=$LASTEXITCODE"
}
foreach ($scene in @('construction_test','harvesting_test','production_test','combat_test','line_of_fire_test')) {
  & .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.',("res://scenes/$scene.tscn"),'--quit-after','120','--log-file',("validation-output/m5-final-launch-$scene.log"))
  Write-Output "$scene exit=$LASTEXITCODE"
}
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.','--quit-after','120','--log-file','validation-output/m5-final-launch-main.log')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--path','.','res://scenes/construction_test.tscn','--quit-after','120','--log-file','validation-output/m5-final-launch-construction-graphical.log')
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.','--script','res://tests/combat_checks.gd','--log-file','validation-output/m5-negative-errors-expected.log','--','--verify-combat-errors')
# Only the last isolated native-error invocation must return 1.
git diff --check
```

The pre-edit 20-run matrix used the same prior ten suites and display modes with the `m5-pre-` prefix. The before-edit repeat loop used the identical stress arguments above with `m5-pre-stress-repeat-1/2/3.log`. Each construction case may also be run independently by appending `-- --construction-case=placement` (or `accounting`, `navigation`, `integration`, `failure`, `earned`). Every new wait is simulation-bounded; the inherited wall watchdog is 180 seconds and the external wrapper is 240 seconds. Assertions and the native-error probe independently determine failure.

The extra baseline investigation used the pre-edit snapshot as `-ProjectPath`, with a baseline import first. Exact repeated engine arguments were:

```powershell
$baseline = (Get-Content validation-output/m5-snapshot-path.txt -Raw).Trim()
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $baseline -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--editor','--import','--quit','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m5-investigation-baseline-import.log')
foreach ($repeat in 1..3) {
  & .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $baseline -TimeoutSeconds 240 -GodotArguments @('--path','.','--fixed-fps','60','--script','res://tests/movement_stress_checks.gd','--log-file',("D:/GitHub/Command_and_Concur_Generals/validation-output/m5-investigation-baseline-graph-$repeat.log"))
  Write-Output "baseline graphical repeat=$repeat exit=$LASTEXITCODE"
}
# The separate diagnostic script described above is copied only into the
# snapshot's ignored validation-output directory; all 106 baseline files remain unchanged.
foreach ($repeat in 1..6) {
  & .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $baseline -TimeoutSeconds 240 -GodotArguments @('--path','.','--fixed-fps','60','--script','res://validation-output/m5_baseline_cluster_probe.gd','--log-file',("D:/GitHub/Command_and_Concur_Generals/validation-output/m5-investigation-baseline-cluster-$repeat.log"))
  Write-Output "baseline isolated repeat=$repeat exit=$LASTEXITCODE"
}
```

Fresh-copy procedure and invocations:

```powershell
$cleanRoot = Join-Path $env:TEMP ('fieldwork-m5-clean-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $cleanRoot | Out-Null
foreach ($relative in @(git ls-files --cached --others --exclude-standard)) {
  $destination = Join-Path $cleanRoot $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $relative -Destination $destination
  if ((Get-FileHash -LiteralPath $relative).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
    throw "Copy hash mismatch: $relative"
  }
}
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--editor','--import','--quit','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m5-clean-import.log')
foreach ($case in @(@('construction','construction_checks'),@('harvesting','harvesting_checks'),@('production','production_checks'),@('combat','combat_checks'))) {
  & .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script',('res://tests/' + $case[1] + '.gd'),'--log-file',('D:/GitHub/Command_and_Concur_Generals/validation-output/m5-clean-' + $case[0] + '.log'))
  Write-Output ($case[0] + " fresh exit=$LASTEXITCODE")
}
```

`git diff --check` returned **0** and the index remained unchanged. Baseline SHA-256 comparison found ten modified pre-existing files: README, project input actions, TestField's generator extraction, ProductionField's optional starting barracks/panel factory, RTSBuilding's operational flag, UnitProduction's availability guard, SelectionController's placement guard, RTSUnit's navigation suspension/resume, and short collector/combat pause guards. All earlier tests, recipes, scenes, wallet/accounting code, movement tuning, destination assignment, projectile/weapon/collision implementation, engine/backend and wrapper remain byte-identical to baseline. New nonignored files are the nine construction scripts and their UID metadata, definition resource, scene, test/UID and this report (23 files). Engine caches, logs, captures, CSV reports, local validation driver and machine-specific temporary-copy paths remain ignored.

## Acceptance and remaining limits

| Requirement | Result |
| --- | --- |
| 1. Preview and input behavior | PASS — automated viewport events and rendered inspection |
| 2. Full footprint, ownership, funds and protected access validation | PASS |
| 3. Exactly-once construction spending/refunds | PASS |
| 4. Timed activation of existing production | PASS |
| 5. Actual navigation changes and unit traversal | PASS |
| 6. Cancellation restores navigation without stale generations | PASS for successful cleanup; failed restoration keeps navigation blocked until reload, with the refund already committed (M5.0.1) |
| 7. Existing moving units and collectors handle topology updates | NOT VERIFIED for full regression acceptance — controlled construction fixtures pass; graphical cluster failure remains unclassified |
| 8. Existing production, safe spawning and rally reuse | PASS |
| 9. Hitscan/spherical projectile world blocking | PASS |
| 10. Callbacks, teardown and preparation failure preserve state | PASS |
| 11. Earned resources fund construction, production and real combat | PASS |
| 12. Regression and intermittent-failure reporting | PASS — failed baseline and all six repeats retained separately |
| 13. Readable contextual UI; no later systems | PASS — captured 1280×800 frames and source scope audit |

**Human keyboard/mouse playtesting: NOT VERIFIED.** A person should harvest with both collectors, place/cancel/build two barracks at several valid positions, train/cancel/rally/fight, and assess camera/selection feel and readability at their window size. Automated input and screenshots do not establish physical-input testing.

The implementation scope is the small flat field, one unfinished site and serialized footprint changes. Protected geometry is conservative; it does not solve arbitrary traffic planning or guarantee freedom from crowd deadlocks. A permanently failed preparation pauses navigation work until cancellation; active orders still have their original bounded timeout. A failed cleanup requires a scene reload, with the refund already committed. No arbitrary moving terrain, high-frequency/large-map rebuild, physics lockstep guarantee or universal frame-rate result is claimed. The known baseline intermittent stress behavior and the unclassified final graphical cluster failure remain reliability limitations. The feature is implemented and its focused suites pass, but full regression acceptance is not claimed; a newly introduced regression would need repair before acceptance. There are no builders, collector construction behavior, destruction/selling, power, technologies, strategic AI, fog or multiplayer. Work stops at Milestone 5.
