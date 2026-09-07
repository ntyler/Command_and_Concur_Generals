# Milestone 5.0.1 — cluster diagnosis and targeted repair

**Captured baseline deadlock: FIXED. Original Milestone 5 failure: UNRESOLVED. Full Milestone 5 acceptance: STILL BLOCKED.** The continuation below adds a focused before/after regression and a bounded local recovery repair. The original M5 graphical unit 4 failure still lacks the historical telemetry needed to connect its mechanism. Passing current runs do not close it or establish equal reliability. Separate [issue records](movement-issue-records.md) retain observations, inferences and unknowns.

The following initial diagnostic report is preserved as history, including its failures and then-current “no production repair” conclusion. The **Continuation — captured regression and targeted repair** section records subsequent work and supersedes that conclusion only for Issue A.

## Preserved source and failure

At entry, HEAD was `ebddeb3` (implemented Milestone 5), its parent was `facf285` (implemented Milestone 4), and staged, unstaged and nonignored untracked status were empty. No applicable AGENTS.md existed in the repository or ancestor scope. README, M4/M5 reports, the original failed log/driver, scene/project settings, movement, commands, navigation, construction cleanup and their tests were read.

Before source edits, all **129 current source files** were copied to a new directory outside the repository and SHA-256 checked. Its path is in ignored `validation-output/m501-current-snapshot-path.txt`; individual hashes are in `m501-current-source-hashes.json`. This pristine snapshot remains separate from execution copies.

The authentic pre-M5 snapshot, recorded in `m5-snapshot-path.txt`, still exists. Every one of its **106 original files** matched `facf285` using `git hash-object --path` and the commit blob (normalizing Git line endings): **zero mismatches**, recorded in `m501-baseline-integrity.txt`. Baseline and current comparison directories were made from those complete sources; no selected production code was reverted. Their original files were verified against their respective commits after the runs: **zero mismatches** in both `m501-*-compare-integrity.txt`. Only the two compatible diagnostic test additions were overlaid. The inherited stress harness is identical between these commits.

**222 existing evidence files** were copied into ignored `validation-output/m501-preserved/`, with names, sizes, timestamps and SHA-256 in `artifact-manifest.json`. This includes the actual failed `m5-final-stress-graphical.log` and wrapper transcript. The old generic `stress-metrics.json` and PNG names had already been overwritten by later runs; their preserved versions must not be attributed to the original failure. The original harness captured only 30-unit graphical routes, so there is no historical image of the failed 50-unit state. The failed engine log is the authoritative historical observation.

Engine and configuration:

| Item | Recorded value |
| --- | --- |
| Executable | `C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe` |
| Version | `4.7.2.stable.official.ed1daf0bf` |
| Executable SHA-256 | `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643` |
| Renderer/device | Windows, `gl_compatibility`; OpenGL 3.3.0 NVIDIA 610.88; NVIDIA GeForce RTX 2070 SUPER |
| Viewport | 1280 × 800, same project/window configuration |
| Simulation | `--fixed-fps 60`, 60 physics ticks/s, time scale 1, maximum 8 physics steps/frame, jitter fix 0.5 |
| Physics backend setting | `DEFAULT`, no project physics overrides; a particular backend implementation was not independently identified |
| Test display | Inherited runner disables VSync; ordinary gameplay settings unchanged |
| Bounds | Original 180-second process watchdog, 240-second external wrapper; cluster movement deadline 75 simulated seconds |
| Arrival/settling | 0.22 mover stopping distance; assertion allows +0.01; 180 physics ticks, displacement/velocity below 0.001 and separation greater than 0.6 |

The pre-edit project configuration is in the source snapshot. Runtime values were subsequently confirmed by the read-only observer and stored in `m501-configuration.json` and route JSON. No engine, renderer, physics, controls, population, obstacle, speed, radius, recovery budget or tolerance was changed.

## First actual failure and assertion dependency

Original route sequence: fresh 30 units → assignment/debug checks → wide → gate → L-shape → cluster → boundary → fresh 50 units → assignment checks → gate → **cluster target `(30,0,22)`** → recovery fixtures → fresh avoidance-disabled 50-unit comparison.

The historical 50-unit gate passed arrival and settling. In the cluster, complete acceptance and fresh per-unit orders also passed. The first failed assertion is **`cluster_50: all units arrive within configured tolerance`**, `tests/movement_stress_checks.gd:214`. Movement processing finished at **36.0 simulated seconds**, before the 75-second deadline, with unit **4 FAILED**, eight recoveries, position `(31.41587,0,19.78682)`, assigned destination `(33,0,22)`, cleared recovery target. Intended and participating population was **50**; the unchanged fixture and acceptance checks identify units **1–50**, with no dropped recipient.

The second assertion is **`cluster_50: no arrival jitter or stationary total overlap for three seconds`**, `tests/movement_stress_checks.gd:224`. It requires `all_arrived`, the stationary sampler's ARRIVED state/velocity/displacement checks, and minimum separation >0.6. Since arrival already failed, this is a **dependent failure**, not evidence of independent post-arrival motion. Its minimum distance was **0.5799991488**, so its static separation condition also failed. Maximum displacement over the following three simulated seconds was **0**. The route had 105.9 sampled overlap pair-seconds and a longest sampled pair run of 27.2 seconds.

Numeric command versions and the other 49 assignments were not printed in that historical log. Source reconstruction gives group generation **4**, unit 4 version **2** (unit 1 version 3 because of the subgroup fixture; other units version 2). These are **inferred**, not historical telemetry. All new instrumented runs explicitly retain the complete command batch and versions. The historical unit 4 neighbors, safe velocity and recovery path history cannot be recovered from a passing rerun.

Earlier M4/M5 **gate** failures remain separate observations, retained in the M5 report. They are not used as proof of the cluster mechanism.

## Bounded reproduction and isolation

The first run used the exact original graphical invocation/configuration, changing only the output log name to preserve evidence. Pair 1 ran current then baseline using the original, uninstrumented script. Four further full-suite pairs used identical diagnostic additions in separate, freshly imported comparison copies. Execution alternated baseline/current order. There was one Godot process at a time; fixed simulation playback can run faster than real time. Background system load was not controlled, and no environment-dependent mechanism is claimed.

After those five pairs, the investigation deliberately extended by **five isolated pairs**, reaching the cap of **ten runs per version**. The common fixture is the actual pre-cluster checkpoint from **pair 2 current**, the first instrumented current run, selected before the extension. Its input SHA-256 is `aef78235fe8c6d0edb5c79b5faa0944ebb38998cb85e7aa2c1139e81cf1934fa`. All 50 units had really completed the gate. Both versions replay the same initial positions, identities, previous assigned destinations, parked radii and command counters; both verify the resulting unit-to-slot map against the captured full-suite command.

Replay positions are set during fixture creation **before units enter the scene**, never to resolve movement or force arrival. `ReplayField` inherits the same TestField geometry, camera and controllers; the stress scene resource contains only this script and the stress exports. The original 50-unit cluster `_route` and all its acceptance requirements run unchanged. The extra replay checks verify a valid 50-unit checkpoint, synchronized navigation and the captured assignment/generation. Earlier routes, old process-local IDs and internal RVO/path cache history are intentionally absent. This is equivalent command geometry and recipients, not a bitwise restoration of the engine's internal simulation state or a reconstruction of the unavailable original failing checkpoint.

Every reproduction attempt:

| Pair | Scope / execution order | Baseline checks / failures / exit | Current checks / failures / exit |
| --- | --- | --- | --- |
| 1 | Original full suite; current, baseline | 131 / 0 / 0 | 131 / 0 / 0 |
| 2 | Instrumented full suite; baseline, current | 131 / 0 / 0 | 131 / 0 / 0 |
| 3 | Instrumented full suite; current, baseline | 131 / 0 / 0 | 131 / 0 / 0 |
| 4 | Instrumented full suite; baseline, current | 131 / 0 / 0 | 131 / 0 / 0 |
| 5 | Instrumented full suite; current, baseline | 131 / 0 / 0 | 131 / 0 / 0 |
| 6 | Isolated cluster; baseline, current | 9 / 0 / 0 | 9 / 0 / 0 |
| 7 | Isolated cluster; current, baseline | **9 / 2 / 1** | 9 / 0 / 0 |
| 8 | Isolated cluster; baseline, current | 9 / 0 / 0 | 9 / 0 / 0 |
| 9 | Isolated cluster; current, baseline | 9 / 0 / 0 | 9 / 0 / 0 |
| 10 | Isolated cluster; baseline, current | 9 / 0 / 0 | 9 / 0 / 0 |

Total: **1,400 assertions, two failures, 19 of 20 runs exit 0**. Baseline contributes 700 assertions/two failures; current 700/zero. These are diagnostic runs, **not post-fix validation**. The current sample's passes neither erase the M5 failure nor demonstrate superior/equal reliability.

Evidence: `m501-pair{1..10}-{baseline,current}.log` and matching `-wrapper.txt`; `m501-all-reproduction.csv`, `m501-full-pairs.csv`, `m501-isolated-pairs.csv`. All eight routes in each complete suite still run, including the original recovery and disabled-avoidance comparison. Overlap remains the existing 10 Hz count: every unordered pair below 0.6 contributes 0.1 pair-seconds per sample. No comparison variable or threshold was altered.

## Captured baseline failure and remaining uncertainty

Pair 7 baseline failed the same two assertions at original source lines **214 and 224**, with complete fresh acceptance for **all intended/actual IDs 1–50**. Group generation remained **4**; units **6 and 12** retained version **2** and their captured assignments throughout the available history. Unit 12 entered FAILED at command time **33.75 s**; unit 6 at **36.0 s**. The route loop observed completion at **36.016667 s**. Settling then ran its full 180 physics ticks.

| Unit | Final position | Captured/current destination | Attempts | Final nav path length |
| --- | --- | --- | --- | --- |
| 6 | `(30.959076,0,18.418102)` | `(33,0,20.5)` | 8 | 2.915419 |
| 12 | `(31.516605,0,18.258211)` | `(30,0,17.5)` | 8 | 1.695576 |

Both final paths reach the actual assigned endpoint, and both destinations project to themselves. All 50 slots are distinct, minimum separation **1.5**, maximum distance from the clicked cluster center **6.1847**. Those slot/projection/endpoint results hold across all 18 instrumented cluster runs. A valid static nav path is not a promise of access through other agents.

The failed replay retained 128 recent snapshots, frames 421–2326 relative to route start, plus 216 state transitions including command acceptance and failure. The 5,666,130-byte JSON is `m501-pair7-baseline-cluster_50.json`; its supplementary `-failure.png` was captured after the stationary interval and visually inspected. It shows the correct 50-unit cluster scene, not movement timing. `m501-failure-invariants.json` records unchanged membership, assignments and generations.

The history supports this **pre-existing production deadlock**, not a false-negative arrival test. Relevant unchanged movement logic is in `scripts/rts_unit.gd`: radius choice at line 314, parking at 407, signed progress at 425, and local recovery at 466 (M5 line numbers):

* Parked units **1 and 26** ended at `(31.415806,0,17.687038)` and `(31.376335,0,18.821007)`, only **1.134655** apart. Each has avoidance radius **0.34**, priority **1**, and zero speed. A moving radius **0.24** requires 0.58 center clearance from each; those exclusion discs overlap because 1.134655 < **1.16**. Unit 12 sits on their east side, about 0.58 from each. Their *assigned* slots were 1.5 apart; arrival tolerance permits a narrower actual parked row.
* At 24.2667 s, unit 12 requested approximately `(-4.47224,0,-2.23585)` toward its unchanged goal. Its last safe callback was approximately `(0.0000165,0,0.0000563)` and applied body velocity was zero. The same near-zero applied motion persists across many samples, with a real remaining path of about 1.6956, well outside arrival tolerance. During recovery it repeatedly requests a waypoint near `(29.320564,0,18.390131)` on the other side and makes no useful progress. The local endpoint/center-ray candidate checks do not guarantee avoidance-width access through parked neighbors.
* Unit 6 repeatedly travels to a detour near `(30.578756,0,16.195108)`, ends the detour within the existing 0.3 waypoint tolerance after about 0.4 s, and then returns toward the same congested position. Attempts occur at 12, 15, 18, 21, 24, 27, 30 and 33 s. This is repeated ineffective recovery, not an arrived unit being reactivated.
* Signed progress baselines remain about 2.95681 (unit 6) and 1.25325 (unit 12). Recovery does not reset the attempt budget or wrongly credit the repeated excursion as new net progress. The original bounded failure path fires. Final processing parks the failed units, accounting for persistent separation near 0.58. Maximum subsequent displacement is **zero**, and the settling failure again depends on arrival.

The priority interpretation agrees with Godot's [NavigationAgent3D documentation](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html#class-navigationagent3d-property-avoidance-priority): higher-priority agents do not adjust for lower-priority agents. Here the telemetry also directly shows the blocked safe velocity. Requested velocity, most recent avoidance callback and applied velocity are observations at different processing phases; the observer does not claim that every sampled triple came from the same callback. The sustained stationary interval makes the blockage distinguishable despite that phase limitation.

The original stress scene **does execute the M5 generator extraction**, but it never constructs ConstructionNavigation or requests a construction update. Exact ordered mesh vertices/polygons have the same SHA-256 across baseline/current and full/isolated cluster runs: `443ace9d7e5945551bee75d47b69db442a8d446a5ab247011c64640d0aa1f3e5`. Each has one region, 50 live registered/tree-group units, and no map or region iteration change during the cluster. The failed replay stays at map iteration **2**, region **1**; full-sequence clusters stay at map **5**. Different initial iteration numbers reflect scene history, not an update during movement. Source review and current snapshots show no suspension in the stress scene.

There is no evidence of a replaced destination, omitted unit, bad navigation projection, stale reservation table or stray previous-field membership in the captured failure. Group reservations are derived from current registered unselected units on each command; this route selects all 50. Arrival checks use immutable captured assignments and versions, not the current recovery waypoint. The mover's direct/avoidance branches are exclusive and its movement-frame guard remains unchanged; 4 Hz telemetry alone cannot certify every physics callback. No post-arrival jitter was observed. The full-suite/isolated comparison establishes that **earlier routes are not necessary for this captured baseline deadlock**; it does not prove that prior route history never affects outcomes.

**Classification boundary:** the captured baseline deadlock is a demonstrated pre-existing production failure. The original M5 unit 4 failure has different participants/destination and lacks historical neighbor/recovery telemetry; its cause and M5 attribution remain unresolved. No test-harness/setup defect or environment-dependent mechanism has been established. It is not labeled “just nondeterminism.” The capture narrows a future regression fixture to parked-row clearance and repeated detours, but does not validate a minimal repair for the original failure. Changing radii, arrival precision or recovery planning would change behavior and requires its own focused before/after evidence. No parameter sweep or speculative patch was applied.

## Test-only changes

`tests/cluster_diagnostic_checks.gd` extends the original stress runner. The complete inherited route sequence/assertions remain intact; isolation is an explicit `--cluster-replay` option of this separate test entry point. `tests/cluster_diagnostic_history.gd` observes at **4 Hz**, retaining at most **128 group snapshots** and **256 state transitions**. It stores identities/membership, captured and current assignments, command generations, position, requested/safe/applied velocity, movement state, cached path/progress data, stall/recovery history and avoidance settings. Complete positions permit offline neighbor analysis without a sampling-time pair loop. Map/geometry/path endpoint inspection happens at route boundaries. The observer uses read-only cached-path accessors rather than advancing agent path logic. It disconnects its state and velocity listeners and is freed after each route.

Recent history is written only for a failed route; small command/configuration/initial/final summaries are retained for every route to permit comparisons and replay. Serialization and failure screenshots happen after the existing route assertions. There is no per-frame console logging, new normal-game HUD or production reference to these scripts. Instrumentation allocates bounded diagnostic dictionaries and reads cached paths; it **can perturb timing**, including via additional signal listeners and startup resource ordering. Both versions use matching observers within each pair. Pair 1 is explicitly uninstrumented. The replay-only metadata/assertion addition was applied equally before pairs 6–10; no inherited full-suite assertion changed.

`tests/construction_cleanup_checks.gd` adds separate behavioral fixtures for failure of **cancellation restoration**, using the existing null-mesh and stale-mesh injectors only after ordinary paid placement reaches query-verified CONSTRUCTING. It changes no production source. Normal gameplay loads none of these diagnostic scripts. Their Godot UID files are included; logs, captures, machine paths and local analysis/drivers remain ignored.

## Construction cleanup fallback

Both null-mesh and unchanged-mesh cancellation fixtures passed **46 assertions headless and 46 graphical**, native errors/warnings **0**, exit **0**. Ordinary preparation succeeds first. Cancellation still runs the real refund, removal and navigation paths. Null restoration fails after **0.016667 simulated seconds**; stale restoration reaches the unchanged **five-second** synchronization deadline, observed at **5.033333 s** including submission/test observation ticks.

This fallback is **not restricted to injection**: normal cancellation uses the same null/empty-mesh validation and five-second map/region/query readiness deadline. An actual failed restoration or missed readiness deadline can reach it. No spontaneous cancellation failure was observed in this batch, and no particular environmental cause is claimed.

The exact boundary, verified by the new fixtures and source inspection:

* The original 400-credit cost is refunded **once**, restoring 1000 in the controlled fixture. Repeat cancellation/new placement cannot add or spend credits.
* The body, collision/weapon blocker, producer registration and authoritative site footprint are removed. A physical/weapon ray through the old site is clear.
* **The old navigation hole can remain. Collision and navigation geometry are therefore not restored to equality.** The controller keeps navigation blocked and units suspended instead of letting them silently use inconsistent topology. This is a fail-closed state, not successful restoration. Existing active orders still retain their source-defined 90-second timeout while suspended; these particular cleanup fixtures do not independently measure that full timeout.
* The record remains CANCELLING and owns the unfinished slot. There is no automatic retry/unlock. An obsolete preparation-generation callback cannot restart construction; further construction rejects before spending.
* Selecting the owned HQ displays a disabled Build button and explicit **“Cleanup failed; refunded once. Reload this field to reset navigation.”** feedback. This is contextual HQ feedback, not a global alert when another selection is active. There is no newly added reload control.
* Scene reload closes the old wallet/controller, clears records and navigation signal connections, restores normal starting state/terrain and ignores old callbacks. Reload resets the scene, not a persistent saved economy.

No concrete accounting or continuation-safety defect was found in this scoped fallback, so no automatic navigation-recovery redesign or production change was made.

## Commands, validation and acceptance

All engine invocations used `tools/run-godot.ps1`. Exact original command (historical output path shown; first reproduction substitutes `m501-pair1-current.log`):

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments @('--path','.','--fixed-fps','60','--script','res://tests/movement_stress_checks.gd','--log-file','validation-output/m5-final-stress-graphical.log')
```

Recorded batch drivers are ignored `validation-output/m501-full-pairs.ps1` (pairs 2–5 plus clean-copy imports) and `m501-isolated-pairs.ps1` (pairs 6–10). They retain every ordinary failure and alternate order. `m501-compare-paths.json` records both actual project paths. Pair 1 baseline uses the verified original snapshot as `-ProjectPath`, the original script and absolute `m501-pair1-baseline.log` path. Subsequent invocations expand to:

```powershell
# $project is the baseline/current comparison directory, $pair is 2..10,
# and $version is baseline or current as recorded in the result table.
$prefix = "D:/GitHub/Command_and_Concur_Generals/validation-output/m501-pair$pair-$version"
$arguments = @('--path','.','--fixed-fps','60','--script',
  'res://tests/cluster_diagnostic_checks.gd','--log-file',"$prefix.log",
  '--',"--diagnostic-prefix=$prefix")
if ($pair -ge 6) {
  $arguments += '--cluster-replay=D:/GitHub/Command_and_Concur_Generals/validation-output/m501-pair2-current-cluster_50.json'
}
& .\tools\run-godot.ps1 -GodotPath $godot -ProjectPath $project -TimeoutSeconds 240 -GodotArguments $arguments
$code = $LASTEXITCODE # Ordinary failures remain failures.
```

Import calls used `--headless --path . --editor --import --quit --log-file <path>`, external timeout 120, and exit **0**: workspace diagnostic import, baseline comparison import, current comparison import, final workspace import. Logs use `m501-diagnostic-import`, `m501-baseline-import`, `m501-current-import`, `m501-final-import`. Version read used `--version`, exit **0**, retained in `m501-version.txt`.

Cleanup and wrapper validation:

```powershell
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/construction_cleanup_checks.gd','--log-file','validation-output/m501-cleanup-headless.log')
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments @('--path','.','--fixed-fps','60','--script','res://tests/construction_cleanup_checks.gd','--log-file','validation-output/m501-cleanup-graphical.log')
& .\tests\validation_wrapper_checks.ps1 -GodotPath $godot
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 30 -GodotArguments @('--headless','--path','.','--script','res://tests/combat_checks.gd','--log-file','validation-output/m501-negative-native-expected.log','--','--verify-combat-errors')
git diff --check
```

The cleanup runs contribute **92/0**. Wrapper self-tests contribute **5/0**, wrapper exit **0**, expected child codes **0, 3, 2, 124**, with terminated processes checked absent. Only the isolated native-error fixture expects exit **1**. Expected watchdog **2** and external timeout **124** are never accepted as ordinary suite success. Negative fixture logs are excluded from success-log auditing and kept separate from the ordinary failed baseline reproduction.

Audit (`m501-log-audit.csv/.txt`, generated by `m501-analyze.ps1`): **25 successful engine logs and matching exit-zero transcripts**, with **zero engine errors, warnings or leak diagnostics**. These are 19 successful reproductions, two cleanup runs and four imports. The failed baseline reproduction contains exactly the two reported assertion errors and is retained outside that success count. `git diff --check` returns **0**. No existing executable source, scene, project setting, test assertion or wrapper changed; only the three new test scripts/UIDs, this report, README and M5 status documentation changed. Nothing was staged, committed or tagged.

No supported repair was made, so there is **no before/after fix comparison** and no claim of post-fix five graphical/headless repetitions, full regression matrix, fresh-copy gameplay matrix or topology/collector acceptance. The prior M5 matrix remains **3,936 assertions/two failures**, with its original evidence preserved. This task completed the bounded diagnosis and the separate cleanup-fallback check; it did not repeat unrelated suites as a substitute for explaining the failure.

Milestone 5's full regression requirement **cannot yet be accepted**. The most useful next evidence is a focused reproduction of the captured parked-row/recovery deadlock, followed by a justified repair and the full required before/after validation; the original M5 failure still needs equivalent telemetry or a demonstrated common invariant. Human keyboard/mouse playtesting was **not performed**. No later milestone was started.

## Continuation — captured regression and targeted repair

**Captured baseline deadlock: FIXED. Original Milestone 5 failure: UNRESOLVED. Full Milestone 5 acceptance: STILL BLOCKED.** These conclusions refer to the separate [Issue A and Issue B records](movement-issue-records.md), not interchangeable unit numbers or assertion names.

### Preservation and reproduction

HEAD remains `ebddeb3`. Before the continuation, **136 tracked/nonignored source files**, including all prior uncommitted diagnostics and documentation, were copied outside the repository and SHA-256 verified. `validation-output/m501r-before-path.txt` and `m501r-before-hashes.json` identify that pristine copy. **180 evidence files** were separately retained in `m501r-preserved/manifest.json`. The authentic M4 snapshot and its original hashes remain intact. A separate pre-fix execution copy, identified by `m501r-before-verify-path.txt`, received only test additions; its production source is unchanged. No source was reverted, staged or committed. The prior observer, original tests and cleanup fallback remain unchanged.

`tests/parked_deadlock_checks.gd` reduces Issue A to captured unit 12 and parked neighbors 1/26. It inherits the original stress field's obstacles and navigation, creates/registers ordinary RTSUnits and uses public `move_to` commands. The neighbors begin at their recorded positions and receive their original goals, already within the ordinary 0.22 arrival threshold; normal movement processing parks them without needing a travel step. No ARRIVED flags, recovery timers or hidden agent state are forced.

The mover starts at its recorded clear position `(33.468826,0,18.115181)`, from the first detour's completion event at frame 609, and receives its original goal `(30,0,17.5)`. All initial collision capsules are separated. This intentionally reconstructs recorded geometry using a later parked arrangement and an earlier clear mover pose. It does **not** claim those poses coexisted at one historical frame, restore the old command version/group generation or replay hidden engine state. The command is fresh and its accepted assignment/version are captured. It reproduces the same clearance blockage using normal movement, without manufacturing an invalid initial overlap.

The predetermined initial runs were exactly three per rendering mode, before production edits:

| Run | Checks / failures / exit | Actual result |
| --- | --- | --- |
| Headless 1 | 13 / 2 / 1 | FAILED at 27 s, eight recoveries |
| Headless 2 | 13 / 2 / 1 | Same blocked position and recovery outcome |
| Headless 3 | 13 / 2 / 1 | Same blocked position and recovery outcome |
| Graphical 1 | 13 / 2 / 1 | Same blocked position and recovery outcome |
| Graphical 2 | 13 / 2 / 1 | Same blocked position and recovery outcome |
| Graphical 3 | 13 / 2 / 1 | Same blocked position and recovery outcome |

Every run stopped at `(31.516605,0,18.258211)`, matching captured unit 12's blocked position. There were no body collision contacts and no subsequent displacement. In this first fixture revision, the error probe also counted the arrival assertion's own `push_error`, producing a **dependent second assertion failure**. The final fixture distinguishes assertion errors from additional native diagnostics and adds a bounded-continuation assertion; arrival/settling requirements are unchanged. That final **14-check fixture** was run on unchanged production in the separate before copy: **one arrival failure, exit 1**, the same blockage. Evidence: `m501r-reduced3-{headless,graphical}-{1..3}.*`, `m501r-reduced3-runs.csv`, `m501r-before-final-fixture.*`. These ordinary failed reproductions remain failures, separate from intentional negative controls.

### Mechanism and physical accessibility

The unit body is a capsule of radius **0.43**, height **1.3**, centered 0.65 above the ground. Its collision layer is 2 and mask is 4: physical walls block it, while peers use the existing soft avoidance contract rather than body-to-body collision. The captured mover's avoidance radius is **0.24**, each stationary neighbor's **0.34**, so center clearance is **0.58**. The neighbors are **1.134655** apart, below the **1.16** required to pass between their avoidance discs. Initial body-overlap checks in both new fixtures are stricter than this moving soft-contact contract; no new permission to overlap solid geometry is introduced.

The static path and assigned endpoint remain valid, but the direct path crosses this closed local opening. In the reduced failure, the remaining distance is about **1.6956**, and signed progress from its last baseline of **1.78536** is below the unchanged 0.3 credit threshold. Nonzero requested movement is cancelled by avoidance to near-zero safe/applied velocity. There are no physical slide contacts. Recovery attempts at command times 3, 6, …, 24 seconds repeatedly choose the same unsuitable detour, expire within the existing two-second duration, and fail at 27 seconds after eight attempts. No deadline or progress credit is incorrectly reset; the defect is ineffective route choice.

The original selector checks projection, endpoint occupancy, a **center ray**, endpoint reachability and maximum path length, then favors proximity to the final goal. A center ray that clears a neighbor's 0.43 capsule does not establish the 0.58 clearance required by avoidance. Offline geometry inspection of the reduced blocked position gives:

| Candidate index | Minimum center clearance | Old center-ray result | Parked avoidance clearance |
| --- | --- | --- | --- |
| 0, selected before fix: `(29.548819,0,17.274437)` | 0.465810 | Clear | Insufficient |
| 1 | 0.553372 | Clear | Insufficient |
| 2–5 | 0.126201–0.427171 | Blocked by neighbor | Insufficient |
| 6 | 0.566117 | Clear | Insufficient |
| 7, outward escape: `(33.712647,0,18.126292)` | 0.579999, at existing contact | Clear | Does not deepen contact |
| 8 | 0.532179 | Clear | Insufficient |
| 9–11 | 0.066369–0.345572 | Blocked by neighbor | Insufficient |

The candidates lie on the open mesh with clear endpoints and short straight navigation paths in this reduced fixture. `m501r-candidate-geometry.csv` is an **offline geometric explanation**, not an independent production-algorithm oracle used to pass tests. The actual chosen targets are recorded by the fixture. The larger original capture selected a different westward candidate because other participants affect the old checks; both routes exhibit the same missing-clearance defect.

Accessibility is established by controls using actual movement, rather than by path existence alone. On pre-fix production, removing neighbor 1, moving it by public order to `(33,0,12)`, or removing both neighbors each allows arrival in about **0.6833 seconds**, without recovery. Recreating the original case and issuing an explicit outer route through `(33.5,0,16)` and `(30,0,16)` reaches the original final goal with both neighbors stationary. This is a reachability witness only; the core regression still requires the single originally accepted goal command to succeed. Each control recreates its field first. The initial control revision passes **67 checks, exit 0**, in `m501r-controls-before.*`.

Clearance checking alone is insufficient: after reaching an outward escape waypoint, the old recovery completion logic immediately resumes the direct goal path and returns into the same parked row. This also matches captured unit 6's repeated outward detour followed by renewed congestion. A separate, deliberately incomplete **one-leg ablation** keeps the new clearance filter but disables continuation. It still fails after eight attempts at 27 seconds, **14 checks / one failure / exit 1**, with zero settling displacement. Evidence `m501r-negative-one-leg.*` and the ignored diagnostic subclass `m501r-ablation.gd` is retained separately from normal validation.

### Minimal production repair

Only **`scripts/rts_unit.gd`** changes production behavior:

1. At recovery, a local physics broad-phase query collects nearby bodies. Actual navigation path segments are checked against stationary, avoidance-enabled peer agents on matching avoidance layers. Required clearance is the sum of current agent radii, capped at existing contact distance, with 0.001 numerical slack. An agent may escape an existing contact but cannot select a segment that moves deeper into it. Existing projection, obstacle-ray, endpoint, path-length and scoring checks remain in place.
2. On reaching the first detour waypoint, if the direct path still lacks clearance from nearby parked peers, recovery may select **one additional local waypoint**. Both legs share the existing two-second attempt duration, progress baseline, interval, attempt count and command deadline. There is no new transition signal. Arrival, replacement, Stop, failure and invalidated detour cleanup clear the new waypoint counter; ordinary pursuit retargeting preserves active recovery history as before.

In the focused post-fix run, attempt 1 first heads outward to `(33.712646,0,18.126291)` at command time **3.0 s**. At **3.383333 s**, it continues around the row toward `(31.759991,0,16.710915)`. The same attempt's elapsed time advances from 0.016667 to **0.4**, rather than restarting. Actual arrival at the original final destination occurs at **4.166667 s**, with **one recovery attempt**, maximum per-tick displacement about **0.083335**, no physical collision contacts and **zero** displacement over the subsequent 180 physics ticks. Parked neighbors remain fixed. Six final focused runs, three in each mode, each pass **14 checks, exit 0**.

No final slot, parked position, obstacle, radius, arrival/settling tolerance, speed or movement budget changes. No hardcoded identity or fixture coordinate enters production. Group assignment, collision, combat, harvesting, production, construction, controls, diagnostics defaults and HUD code are untouched.

Added work is local and event-bound: at most one 64-body query for the initial selection and one for continuation, with up to the existing 12 candidates per selection. Candidate checks cost **O(candidates × returned neighbors × path segments)**, plus their navigation/physics queries; continuation also requests the direct goal path once. There is no new ordinary per-frame tree scan, pair loop, path reconstruction, debug allocation or logging. This remains a bounded heuristic for the existing flat terrain. The query can truncate above 64 nearby bodies, considers stationary peers, and the two-leg horizon does not solve every reachable crowded route. It provides no FPS, lockstep determinism or universal reachability guarantee.

### Controls, full captured arrangement and Issue B

Final `tests/parked_deadlock_controls.gd` passes **84 checks in each mode**. It covers neighbor removal and ordinary departure, the clear route and explicit accessibility witness, synchronous replacement at RECOVERING with a complete captured CommandBatchResult, immediate deletion of the blocking neighbor during that callback, actual second-leg interruption by viewport **X Stop**, second-leg replacement with actual arrival, and complete teardown. A separate solid enclosure accepts a navmesh-valid goal but physically prevents exit; it must reach bounded FAILED without crossing the walls, then accept and complete a fresh order after the walls are removed. Successful reachable cases preserve captured versions/goals and settling. The continuation emits no new callbacks; existing movement/combat repair tests additionally retain synchronous supersession, pursuit, membership and deletion coverage.

`tests/captured_parked_cluster_checks.gd` and `tests/fixtures/parked_cluster_capture.json` retain **all 50 captured participants**. The JSON records its input SHA-256 (`dd837f1f7da2b07f60f0d0ddf369388a94a8c1656681b07397528bf2efe4ea58`), the 48 captured parked positions and original assignments. Unit 6 begins at its recorded frame-744 clear detour position; unit 12 uses frame 609 as above. The minimum initial body separation is about **0.889992**, greater than twice the 0.43 capsule radius. All units are created and registered normally; 48 public orders enter normal parked state, then both movers receive fresh commands to their original captured goals. This is another controlled reconstruction, not a simultaneous historical checkpoint or hidden-state replay.

| Full captured arrangement | Unit 6 | Unit 12 | Checks / failures / exit |
| --- | --- | --- | --- |
| Before, headless | FAILED, eight attempts, 27 s | FAILED, eight attempts, 27 s | 10 / 2 / 1 |
| Before, graphical | FAILED, eight attempts, 27 s | FAILED, eight attempts, 27 s | 10 / 2 / 1 |
| After, headless | ARRIVED, one attempt, 4.666667 s | ARRIVED, one attempt, 4.583333 s | 10 / 0 / 0 |
| After, graphical | ARRIVED, one attempt, 4.666667 s | ARRIVED, one attempt, 4.583333 s | 10 / 0 / 0 |

Afterward both retain their original destinations `(33,0,20.5)` and `(30,0,17.5)` and accepted command versions. All 48 neighbors remain stationary, and all 50 settle for 180 ticks. Evidence: `m501r-captured-parked-{before,after}-{headless,graphical}.*` and `m501r-captured-parked-runs.csv`. The original 50-unit route and population are unchanged; these extra tests do not substitute for it.

**Issue B remains open.** The preserved M5 unit 4 endpoint, assigned goal `(33,0,22)` and eight recoveries do not expose its historical neighbors or detours. Neither a violated clearance invariant nor the return-from-escape cycle can be established from that log. To fill this specific gap on a recurrence, one full original-sequence run used the existing observer, retaining neighbor/velocity/recovery history if it failed. It passed **131 checks**, so it supplied no missing historical failure state. The separate unchanged stress runs also passed. This establishes current successful behavior, not a causal link to the historical M5 failure. The original dependent settling failure remains preserved; its recorded displacement was zero.

### Complete post-repair validation

All runs use the same Godot 4.7.2 executable, fixed 60-FPS playback and external wrapper. Original deadlines and assertions remain unchanged. One Godot process ran at a time. The bounded initial six-run reproduction preceded any broad validation; no further 20-run baseline/current campaign was started.

| Suite in main matrix | Headless checks / failures / exit | Graphical checks / failures / exit |
| --- | --- | --- |
| Original milestone | 127 / 0 / 0 | 131 / 0 / 0 |
| Unchanged movement stress | 122 / 0 / 0 | 131 / 0 / 0 |
| Movement repair | 82 / 0 / 0 | 82 / 0 / 0 |
| Combat | 183 / 0 / 0 | 191 / 0 / 0 |
| Combat command/lifecycle repair | 230 / 0 / 0 | 230 / 0 / 0 |
| Line of fire | 305 / 0 / 0 | 308 / 0 / 0 |
| Spherical projectiles | 140 / 0 / 0 | 141 / 0 / 0 |
| Combat load | 7 / 0 / 0 | 7 / 0 / 0 |
| Production | 192 / 0 / 0 | 193 / 0 / 0 |
| Harvesting | 298 / 0 / 0 | 299 / 0 / 0 |
| Construction | 267 / 0 / 0 | 270 / 0 / 0 |
| Focused parked deadlock | 14 / 0 / 0 | 14 / 0 / 0 |
| Parked controls | 84 / 0 / 0 | 84 / 0 / 0 |
| Construction cleanup fallback | 46 / 0 / 0 | 46 / 0 / 0 |

Main matrix: **4,224 assertions across 28 runs, zero failures**. The subsequently added full captured-arrangement test contributes another **20/0** in its two post-fix modes, recorded separately above. Every current suite therefore ran in both modes. Construction cleanup source/design is unchanged; its shared movement dependencies were revalidated.

Other required runs, outside that matrix:

| Batch | Executions and result |
| --- | --- |
| Final focused repetitions | Three headless + three graphical, 14/0 each, all exit 0; total 84/0 |
| Unchanged isolated 50-unit cluster route using prior checkpoint | One graphical + one headless, 9/0 each, all 50 accepted with captured group assignment verified |
| Targeted instrumented original suite sequence | One graphical, 131/0, exit 0 |
| Predetermined graphical stress repeats 1, 2, 3, 4, 5 | 131/0/exit 0 each |
| Matching headless stress repeats 1, 2, 3, 4, 5 | 122/0/exit 0 each; paired total 1,265/0 |
| Fresh-copy headless stress | 122/0, exit 0 |
| Fresh-copy headless construction | 267/0, exit 0 |
| Fresh-copy headless harvesting | 298/0, exit 0 |
| Fresh-copy headless production | 192/0, exit 0; fresh total 879/0 |

The original stress script runs its complete original sequence, including the affected 50-unit route after gate arrival, and its unchanged avoidance-disabled comparison. Its overlap metric remains the original 10-Hz unordered pair count below 0.6: one overlapping pair contributes 0.1 pair-seconds per sampled tick. Neither comparison setup nor metric was changed.

The final validation batch plus the two post-fix captured-arrangement checks contributes **6,621 successful assertions across 53 runs**. Development/pre-fix controls are not added to that acceptance total. For completeness, the earlier positive development runs were: initial post-fix focused **13/0**; final controls **84/0**; movement repair **82/0**; combat repair **230/0**; cleanup **46/0**, all exit 0. The previously described pre-fix controls contributed 67/0. Together these account for all **7,143 passing assertions across 59 positive functional runs** during the continuation; this larger number includes development and pre-fix controls and is not the acceptance matrix count.

The fresh execution copy began without `.godot`, imported successfully, and retained **143 hash-verified source files**, including the final new test sources copied before its import. `m501r-clean-path.txt` and `m501r-validation-source-hashes.json` record provenance. No production source changed during final validation. The final extra captured-test UID was generated by the completion workspace import; subsequent edits are documentation only. All four continuation editor imports (before verification copy, workspace final, fresh copy, workspace completion) returned **0**.

`validation_wrapper_checks.ps1` passes **5/0**, exit 0, preserving expected child codes **0, 3, 2, 124** and checking that timed-out processes are gone. Its three negative children are isolated from normal success validation. The separate native-error fixture produces **one deliberate assertion failure, exit 1**, proving the logger catches it. The one-leg ablation is also an isolated expected failure. Expected watchdog exit 2 and external timeout 124 are never treated as ordinary success.

`m501r-all-engine-runs.csv` records all **74 dedicated log/transcript pairs**: 63 exit-zero runs and 11 nonzero runs (nine ordinary pre-fix reproductions plus two intentional negatives). The four wrapper-self-test child executions are recorded separately in `m501r-wrapper-self-tests.txt`. Audit of all **63 successful engine logs and their matching wrapper transcripts** found **zero errors, warnings or leak diagnostics**. The successful count includes four imports. `m501r-audit.ps1/.txt` reproduces the audit and verifies the pristine-before and fresh-copy hashes. `git diff --check` passes; machine-specific paths, logs, analysis files and captures remain under ignored validation output. No human keyboard/mouse playtest was performed.

### Commands and evidence locations

All paths below are relative to the repository unless absolute. The retained `validation-output/m501r-validate.ps1` records exact ordering, arguments and project directories for the 51-run final driver, imports and isolated wrapper/native checks. `m501r-validation-runs.csv` records each functional run's exact arguments, checks, failures and exit. The four additional captured-arrangement comparisons have their own CSV as listed above. Unique `m501r-<name>.log` and `m501r-<name>-wrapper.txt` files preserve every invocation's output.

The focused test commands, also applicable to `parked_deadlock_controls` and `captured_parked_cluster_checks`, are:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$prefix = 'D:/GitHub/Command_and_Concur_Generals/validation-output/new-parked-check'
$arguments = @('--headless','--path','.','--fixed-fps','60','--script',
  'res://tests/parked_deadlock_checks.gd','--log-file',"$prefix.log",
  '--',"--diagnostic-prefix=$prefix")
& .\tools\run-godot.ps1 -GodotPath $godot -TimeoutSeconds 240 -GodotArguments $arguments
# Omit --headless for the graphical invocation. Use a new prefix for every run.
# For unchanged-production comparison, also supply the recorded before
# execution directory as -ProjectPath; use the same test and absolute log path.
```

The unchanged original-sequence command is the historical invocation shown earlier with a new log name. The full matrix's script names are in the driver; combat load adds `-- --combat-load`. Fresh-copy runs add `-ProjectPath` using `m501r-clean-path.txt`. Import uses `--headless --path . --editor --import --quit`, timeout 120. Each normal functional run requires exit 0; the outer watchdog is 240 seconds and the inherited runner watchdog remains 180 seconds.

The repair is supported for Issue A by failed unchanged-production regressions, geometric/velocity evidence, successful accessibility controls, a failing incomplete-repair ablation, and successful arrival/settling in both the reduced and full captured arrangements. Issue B's missing historical mechanism remains the precise acceptance blocker. Work stops here; no later milestone or gameplay feature was begun.

## Issue B-only follow-up

The subsequent [targeted Issue B investigation](issue-b-investigation.md) preserves the validated Issue A repair and all its regressions. The original log and source geometry constrain the final settled arrangement: unit 4 is beside a parked peer, and a direct retry would be obstructed. The neighbor could have parked after unit 4 failed, so this arrangement may be a consequence rather than the cause. It does not establish why the historical eight recovery attempts failed.

Six predetermined historical-source cases now retain command, navigation, neighbor, timestamped avoidance and recovery history even when they pass. None reproduces the original cluster deadlock. One full run fails at the earlier gate with a different participant/goal; that failure is preserved separately. A nearby matching unit-4/goal trajectory and successful clearance-intruding detours provide useful controls, without proving a shared Issue A cause. One further current-source run validates the final trace timestamp schema. Across seven functional diagnostic runs there are 436 checks and two retained gate assertion failures; both imports pass and eight successful engine logs/transcripts are clean.

Production source, Issue A tests, acceptance tolerances and requirements are unchanged. The follow-up report contains provenance, exact run results, constraints and remaining unknowns. **Issue B: UNRESOLVED; Milestone 5: STILL BLOCKED.**
