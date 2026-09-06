# Milestone 2.0.1 — combat command and lifecycle correctness

This is the historical corrective acceptance report. References below to line-of-fire work not being started describe that milestone's endpoint. [Milestone 2.5](milestone-2.5.md) now adds weapon obstruction while retaining these corrections and their regression assertions.

**Verdict: ACCEPT** for the existing flat, static RTS fields and scoped combat foundation. All five review findings have focused repository regressions. The complete existing regression set, graphical corrective playback and fresh-copy validation pass. No physical keyboard-and-mouse playtest is claimed. No line-of-fire or projectile/world-collision work was started. No commit or tag was made.

## Preflight and scope

Validation used the installed `4.7.2.stable.official.ed1daf0bf` console executable on Windows, without installing or changing dependencies. No applicable AGENTS.md existed in the repository or its ancestors. README, milestone documentation through 2, the supplied acceptance review, ignored `m2-review-evidence.md`, command/selection/movement/combat/firing code, tests, Git status, staged/unstaged changes and new combat files were inspected.

HEAD and `milestone-1.5.1` resolve to `9a297df`. Milestone 2 was already present as five modified tracked files and 24 new nonignored files, with no staged changes. That work was preserved. A separate pre-repair copy was made from `git ls-files --cached --others --exclude-standard`; its path is recorded only in ignored `validation-output/m201-before-path.txt`.

Fresh baseline runs all passed: combat 168/0 headless and 176/0 graphical; original 126/0 and 130/0; stress 118/0 and 127/0; movement repair 73/0; wrapper 5/0. Every baseline suite exited 0. There were no newly observed baseline-suite failures; the five known review defects were reproduced separately. Earlier successful Milestone 2 measurements remain historical successes, not retroactively failed runs.

The corrective implementation changes only selection input routing, the field command/result boundary, internal pursuit refreshes and the post-damage emitter lifetime check. Camera, input mappings, scenes, destination generation/assignment, movement thresholds, health, weapon resources, projectiles, team rules, retaliation and the external wrapper are preserved. Existing tests change where the batch API requires migration, with additional acceptance assertions.

## Repairs

| Finding | Root cause | Narrow repair and evidence |
| --- | --- | --- |
| X ignored over the passive panel | The pointer-hover guard returned before unhandled keyboard Stop | Handle X first in `_unhandled_input`, after normal GUI consumption. Viewport events verify actual moving-unit and pursuit cancellation over panel/world; left/right mouse commands remain filtered; a focused test Control consumes X without issuing Stop. |
| Moving-target refreshes starve recovery | `move_to()` reset sample/stall clocks faster than the progress window completed | `RTSUnit.retarget_pursuit()` updates an existing chase without resetting its order, clocks, progress credit/debt, recovery attempts or temporary waypoint expiry. Controller counters remain cumulative. Continuous ordinary target movement inside the existing enclosure fixture now activates recovery and terminates within existing limits. |
| Selection callbacks overwrite a replacement | Batch authority began after `selected_units()`, which can emit `selection_changed` during pruning | Allocate a request generation and capture accepted-command authority before the selection query; check it immediately afterward and throughout dispatch. Tests exercise outer Move, Attack and Stop with ownership-driven pruning and a synchronous replacement, including later physics ticks and shared reporting. |
| Committed hitscan accesses a freed emitter | A damage listener can immediately free the source before `fired.emit` | Check emitter lifetime immediately after damage callbacks. The already-committed shot returns true without instance access when the emitter is gone. Surviving emitters retain one notification. Direct and controller-driven firing cover immediate free, ordinary death, queue_free, source detach and target detach. |
| Bool hides partial group execution | A later member can depart after earlier members accepted, and old code returned false | A small value-based `CommandBatchResult` records exactly which members accepted. Validate references before typed calls, skip unavailable later members, preserve earlier historical evidence, and avoid publishing obsolete reporting after replacement. Tests include actual free before dispatch and free of an already accepted member from a later member's callback. |

Important files: `scripts/selection_controller.gd`, `scripts/rts_unit.gd`, `scripts/combat_controller.gd`, `scripts/weapon_emitter.gd`, `scripts/test_field.gd`, new `scripts/command_batch_result.gd`, and new `tests/combat_repair_checks.gd`. Godot-generated `.gd.uid` sidecars are normal source metadata; caches and validation output remain ignored.

## Batch contract and caller migration

Field `issue_move`, `issue_attack` and `issue_stop` return `CommandBatchResult`. Unit-level movement/Stop and `CombatController.issue_attack` retain their bool acceptance contract.

| Result field | Meaning |
| --- | --- |
| `generation` | Monotonically allocated request identity within this field instance, assigned before selection queries. Rejected requests can leave gaps between accepted generations. |
| `intended_ids` | Stable unit IDs from the resolved selection snapshot. Movement uses the existing sorted-ID assignment order. |
| `accepted_ids` | IDs whose unit-level call actually returned acceptance, captured without reading possibly replaced or freed member state afterward. No duplicates or node references. |
| `acceptance` | `NONE`, `PARTIAL` or `COMPLETE`, based on historical accepted/intended recipients. Empty selection is NONE. |
| `assignments` | Accepted movement destinations by stable unit ID, copied from this command's planned assignments. Attack/Stop leave it empty. |
| `superseded` | A newer accepted group command took authority before this dispatch returned. This is a return-time snapshot, not a live subscription to future commands. |

Acceptance is historical. A unit can accept A and replace it with B in A's callback. Reporting A's acceptance does not claim A remains active. A one-unit batch can be COMPLETE and superseded; a multi-unit batch can be PARTIAL and superseded. Pre-dispatch rejection reports NONE and does not advance any unit's order. Rejected nested requests do not take accepted-command authority from the outer operation. The implementation does not roll back accepted members.

Use `result.is_complete() and not result.superseded` when every intended member must accept an unsuperseded dispatch. Use `result.has_acceptance()` when any historical acceptance is the relevant fact. Read the explicit fields for partial/superseded cases; never test result-object truthiness. Treat returned snapshots as read-only values.

Only the still-authoritative dispatch publishes `last_command_result` and its accepted/intended status count. Movement additionally publishes accepted `last_command_slots` after dispatch. A rejected pre-dispatch request retains prior command snapshots, though a capacity/reachability rejection can update the status explanation. A superseded outer call publishes none of these values over the newer command.

All call sites were searched and migrated:

- Contextual input signals still invoke the field entry points; those methods own user-visible batch reporting. Signal return values are not interpreted as booleans.
- Combat assertions deliberately choose complete acceptance for ordinary batches, no acceptance for rejected batches, or any historical acceptance during reentrant dispatch. Existing unit-version, target, motion, damage and lifecycle assertions remain.
- Stress routes require complete **unsuperseded** acceptance, retain a fresh `order_version` increment for every intended unit, and read captured assignments by ID from the result. They verify the unit's assigned destination matches that snapshot. Partial/rejected routes still return before simulation; stale slots cannot pass a route.
- Original and movement-repair callers now assert explicit acceptance/rejection. Reservation reuse and reparent checks gained fresh acceptance assertions.
- Corrective tests verify exact intended/accepted IDs, generation ordering, supersession, actual changed unit orders and copied destinations, including deletion before result construction.

Existing totals increased because of added acceptance checks: original +1; stress +4; movement repair +9; combat +15. No existing behavioral assertion, tolerance, deadline or fixture difficulty was weakened.

## Pursuit accounting and lifecycle details

For an active chase, retargeting computes the old remaining path length at the current attacker position. It retains the difference between the existing best-progress reference and that distance, including negative debt. After changing the destination, it adds that same credit/debt to the new remaining distance measured at the **same position**. Target movement or the rebase itself therefore adds no progress. The sample clock is not restarted. Small actual advances can still accumulate; the existing signed-distance protection against backtracking/oscillation is retained.

Retargeting invalidates an outstanding avoidance submission but does not create a new movement order or reset velocity every half-second. A real temporary detour retains its target, priority and remaining expiry; a recovery fallback that merely repathed to the final destination follows the refreshed destination without starting another attempt. When recovery ends, the agent resumes toward the updated final destination. New player moves, Stop, replacement attacks and target invalidation retain their existing cleanup semantics.

Remaining-distance queries still run at the existing sample interval. Retargeting adds two bounded path-length queries only on the existing pursuit refresh schedule; it adds no per-frame all-unit search or pairwise loop. No performance improvement is claimed.

The enclosure test uses unchanged defaults: progress window 0.75 s, meaningful progress 0.3 units, stuck threshold 2.25 s, recovery interval 2.5 s, eight attempts, and 90 s cumulative pursuit deadline. The target repeatedly navigates between `(2,0,16)` and `(2,0,-18)` using ordinary movement, so refreshes continue beyond the first leg.

| Observation | Pre-fix stationary | Pre-fix moving | Repaired stationary | Repaired moving |
| --- | --- | --- | --- | --- |
| Refreshes at six-second sample | 1 | 12 | 1 | 12 |
| Maximum observed stalled time by sample | 5.25 s | 0 s | 5.25 s | 5.25 s |
| Recovery attempts by sample | 2 | 0 | 2 | 2 |
| Maximum attacker displacement | 0.1449 | 0.2044 | 0.1449 | 0.2044 |
| Refreshes before bounded termination | 1 | 168 | 1 | 45 |
| Maximum attempts before termination | 8 | 0 | 8 | 8 |
| Maximum sampled cumulative pursuit duration | 23.25 s | 90.00 s | 23.25 s | 23.25 s |

Both repaired rendering modes observed these values in this run; tests assert bounds and useful behavior, not identical trajectories or exact recovery counts. The six-second observation sees the controller at approximately 5.983 s because the coroutine samples at the physics-frame boundary. The pre-fix defect was recovery starvation, not infinite pursuit: its existing 90-second limit still terminated it.

Additional accounting checks use controlled sampler fixtures with actual navigation queries: stationary attacker/changing destinations, sideways oscillation with retargets, small real advances accumulating, and an actual temporary detour retaining expiry and eventually using the refreshed destination. An ordinary progressing attacker also continues a moving-target pursuit without permanent failure. Replacement during recovery is checked immediately and over subsequent physics ticks.

For firing, cooldown and shot count are committed before the damage call. Returning the already-established fact of acceptance requires no emitter data after immediate destruction. A destroyed emitter emits no post-shot signal; a survivor emits once. The immediate callers were traced: `TeamRules.damage_target` returns the health result directly, and the combat controller returns after its firing attempt. The normal controller path is also executed in the regression, with engine-error capture through teardown. No errors are suppressed and the immediate-free reproduction remains immediate free.

## Focused before/after evidence

The repository test was first added before production repairs. `m201-red-confirmed.log` recorded 161 checks / 29 failures, exit 1, including five native errors. The graphical input-only run recorded 23 checks / 2 failures, exit 1, with zero native errors. After expanding continuous target movement and cleanup coverage, the same behavioral scenarios were rerun against the isolated **pre-fix production copy**: `m201-red-expanded.log`, 177 checks / 32 failures, exit 1, with five native errors. Its fresh import exited 0.

| Case (`--repair-case=`) | Expanded pre-fix checks / failures | Final checks / failures, headless and graphical | Evidence distinction |
| --- | --- | --- | --- |
| `input` | 21 / 2 | 21 / 0 | Executed before and after; graphical hover failures reproduced before repair |
| `pursuit` | 40 / 4 | 40 / 0 | Executed before and after; same enclosure, defaults, moving target and deadlines |
| `accounting` | 2 / 1 | 8 / 0 | Pre-fix confirms retarget API absent; detailed new-API accounting assertions executed after repair, not claimed to have run on the absent API |
| `selection` | 15 / 9 | 24 / 0 | All three outer entry points reproduced before repair; result-field checks become executable with the new API |
| `firing` | 40 / 1 | 40 / 0 | Direct and normal controller paths executed before/after; native-error check separately caught both pre-fix invalid accesses |
| `batch` | 48 / 14 | 86 / 0 | Partial/complete/rejected/nested/deletion scenarios executed before/after; explicit result checks fail at the old bool boundary before repair |
| `continuity` | 9 / 0 | 9 / 0 | Actual cooldown spam and source ownership/unregistration projectile controls pass before/after |

Totals include one case-name check and one final native-error assertion. In the expanded pre-fix run, the latter fails for two emitter invalid accesses and three freed-later-member typed-call errors. It is not counted as five additional assertion failures. The final suite is **230 checks / 0 failures**, zero native errors, exit 0 in headless, graphical and fresh-copy runs.

Temporary bool compatibility allowed behavioral scenarios to execute against the old API. It was removed from the final typed suite; no result object is used for implicit boolean conversion. Counts also increase when formerly unavailable result fields can be checked. An initial test-development attempt freed a member during that member's own locked signal/call, which Godot rejects. That invalid fixture was replaced before the recorded confirmed/expanded red runs by freeing an earlier accepted member from a later member's callback. These test-development errors are not attributed to production defects.

Each fixture resets the field, waits for deferred deletion, frees detached nodes, and uses one-shot or explicitly disconnected temporary listeners. Assertion failures print and increment the failure count independently of native error logging; either produces exit 1. No normal scene loads corrective instrumentation.

## Exact validation commands and results

Commands run from the repository root in PowerShell 7. Every Godot invocation uses the existing external wrapper. `$LASTEXITCODE` was captured immediately. Console output is in the corresponding ignored `*-wrapper.txt`; the engine log names below are relative to `validation-output/`.

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 15 -GodotArguments @('--version')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','validation-output/m201-final-import.log')
```

Both exit 0. For each row in the following table, the exact independent suite invocation is:

```powershell
$suite = 'combat_checks.gd' # Script column
$name = 'combat'           # Name column
$arguments = @('--path','.','--fixed-fps','60','--script',('res://tests/' + $suite),'--log-file',('validation-output/m201-final-' + $name + '.log'))
# Include this line only for rows marked headless:
$arguments = @('--headless') + $arguments
# Include this line only for the two load rows:
$arguments += @('--','--combat-load')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments $arguments
```

| Name | Script | Mode | Checks / failures | Exit |
| --- | --- | --- | --- | --- |
| `original` | `milestone_checks.gd` | Headless | 127 / 0 | 0 |
| `original-graphical` | `milestone_checks.gd` | Graphical | 131 / 0 | 0 |
| `stress` | `movement_stress_checks.gd` | Headless | 122 / 0 | 0 |
| `stress-graphical` | `movement_stress_checks.gd` | Graphical | 131 / 0 | 0 |
| `repair` | `movement_repair_checks.gd` | Headless | 82 / 0 | 0 |
| `combat` | `combat_checks.gd` | Headless | 183 / 0 | 0 |
| `combat-graphical` | `combat_checks.gd` | Graphical | 191 / 0 | 0 |
| `corrective` | `combat_repair_checks.gd` | Headless | 230 / 0 | 0 |
| `corrective-graphical` | `combat_repair_checks.gd` | Graphical | 230 / 0 | 0 |
| `load` | `combat_checks.gd` | Headless + combat-load | 7 / 0 | 0 |
| `load-graphical` | `combat_checks.gd` | Graphical + combat-load | 7 / 0 | 0 |

Baseline commands use the same template and mode/script rows for original, stress, repair and combat, replacing `m201-final-` with `m201-pre-`. Their totals are recorded in preflight above. Focused reproduction commands actually executed:

```powershell
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/combat_repair_checks.gd','--log-file','validation-output/m201-red-confirmed.log')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 60 -GodotArguments @('--path','.','--fixed-fps','60','--script','res://tests/combat_repair_checks.gd','--log-file','validation-output/m201-red-input-graphical.log','--','--repair-case=input')
```

The first two commands ran before repairs and exited 1. To rerun a single current corrective case, use the second command with any case from the focused table and a new output filename; omit `--headless` for graphical input playback. All cases also ran after integration in both full corrective suites above.

For the expanded red run, `$redCopy` came from `m201-before-path.txt`. Only the expanded test was added to that pre-fix production copy; its original source was not repaired:

```powershell
$redCopy = (Get-Content validation-output/m201-before-path.txt -Raw).Trim()
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $redCopy -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m201-red-copy-import.log')
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $redCopy -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/combat_repair_checks.gd','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m201-red-expanded.log')
```

Import exit 0; expanded red suite exit 1. The isolated paths/logs are local evidence and need regenerating on another checkout.

Fresh-copy validation copied all tracked/new nonignored files into a new directory without `.godot` or validation output. The path is recorded in ignored `m201-clean-path.txt`. These exact commands all exited 0:

```powershell
$cleanRoot = (Get-Content validation-output/m201-clean-path.txt -Raw).Trim()
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 60 -GodotArguments @('--headless','--path','.','--editor','--import','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m201-clean-import.log')
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/combat_checks.gd','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m201-clean-combat.log')
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $cleanRoot -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/combat_repair_checks.gd','--log-file','D:/GitHub/Command_and_Concur_Generals/validation-output/m201-clean-corrective.log')
```

Fresh combat: 183/0. Fresh corrective: 230/0, native errors 0. Copied original-file hashes matched the workspace at execution. All game resources resolve through the copy's `res://`; only output log paths point back to the workspace.

Wrapper and isolated negative checks:

```powershell
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.','--script','res://tests/combat_checks.gd','--log-file','validation-output/m201-final-error-expected.log','--','--verify-combat-errors')
git diff --check
```

Wrapper: **5/0, exit 0**, preserving child codes **0, 3, 2, 124** and proving no blocked process survives. The isolated engine-error fixture: **1 check / 1 expected failure, exit 1**. Whitespace check: **exit 0**. Expected internal timeout 2 and external timeout 124 are confined to wrapper fixtures, never counted as passing gameplay runs. Successful-path scans cover 15 final/fresh engine logs with **zero errors, warnings or failed assertions**; red runs and intentional negative fixtures are excluded.

Graphical runs inject actual viewport events and assert motion, selection, command versions, focus ownership, firing and damage. They are automated engine interaction, not a physical human playtest. Instrumented load checks retain their existing bounds and timing definitions; neither exact cross-renderer trajectories nor a causal performance improvement is claimed.

## Acceptance checklist and remaining limits

| # | Corrective requirement | Status |
| --- | --- | --- |
| 1 | X works over panel/world; consumed keyboard input remains respected | PASS |
| 2 | Moving-target refreshes no longer starve blocked-attacker recovery | PASS |
| 3 | Internal retarget keeps history/deadlines; real replacements reset appropriate state | PASS |
| 4 | Selection-pruning callbacks cannot overwrite newer Move/Attack/Stop commands | PASS |
| 5 | Immediate shooter deletion preserves committed firing result without engine error | PASS |
| 6 | Batch result distinguishes none/partial/complete with actual stable recipients | PASS |
| 7 | Superseded dispatch preserves newer unit state and reporting | PASS |
| 8 | All affected callers explicitly use revised acceptance semantics | PASS |
| 9 | All five findings have focused repository regression coverage | PASS |
| 10 | Existing movement/combat/lifecycle/cooldown/wrapper coverage passes | PASS |
| 11 | Successful logs clean; negative fixtures isolated | PASS |
| 12 | Documentation separates historical evidence and repaired coverage | PASS |
| 13 | No later systems, tuning changes or unrelated changes introduced | PASS |

Physical keyboard/mouse feel, other platforms, dynamic navigation, opposing gate traffic, larger crowds and lockstep simulation remain NOT VERIFIED. Crowd avoidance still permits brief overlap and navigation remains limited to these flat static fields. Result identities are field-local historical values, not multiplayer IDs. Godot's restriction on immediately freeing an object locked in its own call/signal remains an engine constraint; regressions exercise valid immediate-free boundaries, including the requested hitscan callback. No new stance, diplomacy or command framework is introduced.

Milestone 2 acceptance is now supported within its documented scope. A narrowly scoped line-of-fire and projectile-obstacle milestone can begin. No broad movement redesign is required by these findings.
