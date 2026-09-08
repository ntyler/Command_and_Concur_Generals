# Milestone 8.1 — HUD clarity and contextual selection

**Status: COMPLETE — all eight Milestone 8.1 acceptance groups pass.** The corrected runtime passed **18/18 affected headless/graphical executions, 3,146 checks, zero failures or native errors**, plus the focused **48/48** callback reproduction. Four unchanged combat/line-of-fire executions contribute **987 reused checks**. The reconciled 22-execution coverage is **4,133 checks**; the earlier **4,105-check** snapshot is pre-fix evidence, not post-fix validation. Rendered captures were inspected at 1280×720 and 1920×1080. No human playtest occurred.

## Play and visible changes

Open [scenes/combined_arms_assault.tscn](../scenes/combined_arms_assault.tscn) in Godot and press **F6**, or run from the repository root:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/combined_arms_assault.tscn
```

The installed engine remains **4.7.2.stable.official.ed1daf0bf**. F5 still launches the original `scenes/test_field.tscn`; the command above selects the actual combined-arms game.

- **Help:** a small Help button and F1/F3 hint replace the permanent guide. Click or F1 toggles full instructions. Help starts closed on launch and Restart, does not pause the match, and consumes pointer events only within its visible bounds. Escape closes open Help when it owns input; another Escape retains placement cancellation.
- **Selection:** credits remain visible. The existing selection controller supplies neutral, single-unit, mixed-group, collector, HQ, construction-site and producer content. Single actors show exact HP; mixed groups show actual count and type counts without an invented combined HP value. Collector cargo, activity and assigned supply contents share this panel. Construction/production, queue progress, costs, cancellation and blocked-exit feedback remain available.
- **World feedback:** selected or damaged mobile units/buildings show compact health bars. Mobile names and exact HP move to selection context; buildings and supplies retain compact identifying labels. Existing blocked-fire warnings remain. F3 exposes detailed health/movement diagnostics. Construction boundary/access outlines appear during placement or diagnostics, with their underlying geometry and validation unchanged.
- **Tactical feedback:** a single assigned group reads “Group 3 · 2 units”; multiple groups use numbered chips with valid counts and full tooltip descriptions. The minimap keeps its existing dimensions, mapping and input. The compact objective reads “Destroy enemy HQ · Protect your HQ” and retains the assault countdown and command acceptance feedback.

Normal gameplay contains no hardware-statistic overlay. No hover-name system or new gameplay commands were introduced. [README controls](../README.md#controls) document the input changes.

## Scope and recovery

The original request is retained locally in Codex attachment `33426177-76ae-4051-8b51-c6a03e9e949f/pasted-text.txt` (identical request in `344d3a2e-6402-4151-ac02-35efdce25679`). The resume request is attachment `f3f87923-b591-4f2b-be46-cc08474ab307/pasted-text.txt`. Repository status, tracked diff and new files were inspected; no applicable `AGENTS.md` was found in the repository or directory ancestors. Existing edits and ignored evidence were preserved. The short [resume checkpoint](../validation-output/m8.1/progress.md) records coordination and saved state.

The saved [M8.1 regression source manifest](../validation-output/m8/hud81-regression-01/source-hashes.json) was compared with the recovered workspace. At that checkpoint, four files differed: `scripts/control_groups.gd`, `scripts/harvest_panel.gd`, `scripts/production_panel.gd`, and `tests/hud_clarity_checks.gd`. Thus the first graphical HUD pass did not certify later layout, membership or lifetime edits. The [Milestone 8 baseline report](milestone-8.md#baseline-and-preservation) retains the earlier source-matched M7 evidence for unchanged behavior; its initial acceptance scaffold is not this milestone's acceptance table.

Changes are limited to HUD composition, contextual display, label/diagnostic visibility, necessary input/lifetime corrections, and relevant tests/documentation. No movement, navigation, avoidance, collision, weapon balance, costs or production durations were changed. No commit, tag, engine upgrade, dependency installation or movement investigation is part of this milestone.

| Important files | Purpose |
| --- | --- |
| `scripts/rts_help_panel.gd`, `scripts/base_assault_field.gd`, `project.godot` | Compact Help/F1 routing, objective/feedback placement and match UI lifetime |
| `scripts/production_panel.gd`, `scripts/construction_panel.gd`, `scripts/harvest_panel.gd`, `scripts/harvest_field.gd` | Authoritative contextual selection, retained building actions and observer ownership |
| `scripts/world_health_bar.gd`, `scripts/combat_feedback.gd`, `scripts/rts_building.gd`, `scripts/rts_unit.gd`, `scripts/construction_building.gd`, `scripts/supply_cache.gd` | Compact labels/bars and diagnostic visibility |
| `scripts/production_field.gd`, `scripts/construction_field.gd`, `scripts/building_placement.gd` | Diagnostic propagation and relevant placement-guide visibility |
| `scripts/tactical_minimap.gd`, `scripts/control_groups.gd` | Readable membership and bounded focus/departure corrections |
| `tests/hud_clarity_checks.gd`, `tests/base_assault_checks.gd`, `tests/harvesting_checks.gd` | HUD viewport/lifecycle checks, intentional presentation expectation, explicit fixture readiness |

## Findings and corrections

**Panel callback during teardown.** The original tactical log failed `tactical checks and teardown have no native errors or warnings`: **126 checks, 1 failure, native_errors=6, exit 1**. The six identical native traces were:

```text
ERROR: Condition "!is_inside_tree()" is true. Returning: Rect2()
   at: get_viewport_rect (scene/main/canvas_item.cpp:1231)
   GDScript backtrace (most recent call first):
       [0] _layout (res://scripts/production_panel.gd:74)
```

The panel's `_layout` callback still reached `get_viewport_rect()` after the panel departed the tree. Resizing subscribed the panel to the longer-lived viewport; minimum-size/model changes also queued deferred layout work. Checking whether the field object existed did not establish active panel tree membership. A tree/deletion guard was already saved before this resume, but did not by itself demonstrate signal cleanup or derived-panel safety. The resume correction explicitly disconnects viewport, minimum-size, selection, credit, construction and actor/queue observers on exit, records closing state, and clears old field/producer references. Refresh and action paths require the original panel/field/selection to remain active; derived construction refresh cannot continue after an inactive base refresh. Placement-status layout receives the same lifetime checks and disconnects its resize observers. Pending old callbacks retain their old instance and cannot operate on a restarted match. Active selection/model notifications remain enabled.

The same original native error affected [Vehicle Production](../validation-output/m8/hud81-regression-01/headless-vehicle_production_checks.log) (**225 checks, 1 failure, 18 native errors, exit 1**) and [Base Assault](../validation-output/m8/hud81-regression-01/headless-base_assault_checks.log) (**124 checks, 1 failure, 21 native errors, exit 1**). Their gameplay assertions passed; the native-error assertions correctly failed. Final focused lifetime and affected-suite passes are recorded below.

An earlier implementation error is also retained: [world-label review](../validation-output/m8.1/world-label-review.md) recorded Construction Cleanup **46 checks, 1 failure, native_errors=2, exit 1**, with `Amount of unbind() arguments must be 1 or greater` at `ProductionPanel._watch`. Zero-argument signals now use the ordinary callable; only positive argument counts use `unbind`. The later saved regression passed Cleanup **46/0, exit 0**. This failure is preserved rather than hidden by the later pass.

**Control groups.** The original [82-check log](../validation-output/m8/hud81-regression-01/headless-control_group_checks.log) failed these exact assertions, **2 failures, native_errors=0, exit 1**:

1. `a different group key consumed by focused UI breaks pending double-tap sequence`
2. `queued ancestor makes descendant group member immediately ineligible for recall`

These were actual input/lifetime defects, not changed label expectations. A freshly imported archive of baseline commit `a75749664e79745b64c897c754d792fc81668dde` reproduced both with the same unchanged test contents after line-ending normalization. The [bounded baseline review and commands](../validation-output/m8.1/group-baseline-review/README.md) and [source/results record](../validation-output/m8.1/group-baseline-review/source-and-results.json) establish this attribution. The group controller clears pending double-tap timing when GUI focus changes, including a GUI interaction whose keys never reach unhandled gameplay input. Its member resolver rejects a unit beneath a queued intermediate ancestor before descendant tree-exit notifications arrive. GUI consumption/filtering, assignment, recall, membership and centering assertions remain intact. The saved corrected focused headless run passed **82 checks, 0 failures, native_errors=0, exit 0**; final integration verification is separate.

**Harvesting fixture.** The original [harvesting log](../validation-output/m8/hud81-regression-01/headless-harvesting_checks.log) reported **298 checks, 3 failures, native_errors=0, exit 1**, all in the quantities case:

1. `non-multiple capacity configuration accepts harvesting`
2. `configured capacity makes two real collection trips (bounded simulation deadline)`
3. `transfers clamp independently to interval amount, remaining capacity and final cache contents`

The initial order refusal cascaded into the expected two-trip/load failures. The original log did not record its rejection reason, so the cause remains **UNKNOWN**. All 19 contextual UI checks passed in that execution; the failure did not assert removed floating cargo text. Later saved [quantities](../validation-output/m8.1/harvest-quantities-review-01.log) and [full](../validation-output/m8.1/harvest-full-review-01.log) runs passed **22/0** and **298/0**, both exit 0/native_errors=0; these passes do not prove the first failure's cause.

The fixture previously waited five frames and accepted any nonzero navigation-map iteration, which could still describe the departed field's region in the shared world. It now waits at most 60 frames for the newly instantiated region to own both collector start positions and asserts that explicit readiness before commands. A failed capacity order now prints acceptance/rejection and current-region diagnostics. This addresses a plausible synchronization weakness without claiming the original race is proven. Capacity **35**, total supplies/credits **52**, expected loads **[25, 10, 17]**, travel/deposit deadlines and all gameplay assertions remain unchanged. Harvesting mechanics were not edited.

**Existing test edits.** The Base Assault completion check still requires damage eligibility and **450 HP**; it now checks the intended compact identity and contextual health-bar policy instead of mandatory floating numerical HP. The two pre-existing Harvesting UI edits replace local panel coordinates with `get_global_rect()` after nesting cargo inside the shared selection panel; command isolation and X Stop assertions remain. Tactical/group tests were not weakened to accept changed behavior. New HUD checks use viewport events for Help, selection, construction/production, minimap, groups, focused keys, F3 and Restart, with explicit lifetime assertions added during the resume.

**Synchronous selection-pruning reproduction — confirmed and corrected.** Recovery found `_hud_reentrant_panel_departure(false/true)` already added to `tests/hud_clarity_checks.gd`, after the earlier integration snapshot, but no saved execution result or running reproduction. It changes one Rifle's ownership in an ordinary mixed selection, then removes and retains the whole field from the normal getter's pruning notification. It neither blocks signals nor directly rewrites selection membership.

The first execution is preserved in [callback-reproduction-01.log](../validation-output/m8.1/callback-reproduction-01.log): **48 checks, 3 failures, 2 native/script errors, exit 1**. `ProductionPanel._refresh` continued after `selected_units()` returned and accessed its cleared `field` when formatting credits (original line 107). `HarvestPanel._refresh` changed retained visibility/text and then accessed the cleared field's `production_panel` (original line 82). The collector's retained-state and subsequent deferred-state assertions failed, as did the native-error assertion. The production retained-state assertions passed because the script error aborted that refresh; they alone were not proof of safety.

The smallest supported correction rechecks active context immediately after `selected_units()` in those two refresh methods, before observer registration or UI writes. The collector refresh also releases its `_refreshing` gate on that early return, reusing its unchanged entry lifetime predicate through `_context_active()`. No selection/controller or command behavior changed. The existing regression remains intact, including both production and collector entry paths, observer cleanup and deferred re-entry. [callback-fixed-01.log](../validation-output/m8.1/callback-fixed-01.log) passed **48/48, native_errors=0, exit 0**. Both runs used the same exact focused command:

```powershell
& .\tools\run-godot.ps1 -GodotPath 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/hud_clarity_checks.gd','--','--hud-case=panel_lifetime')
```

Output was redirected to the two distinct logs above; `$LASTEXITCODE` was captured immediately and propagated. The first used the `hud81-final-01` runtime with the already-pending test addition; the second used the corrected runtime subsequently captured in `hud81-callback-01`. This closes the specific review concern; no further callback audit or review team was started.

## Assault timer

Normal combined-arms play retains **90 simulated seconds**, from `BaseAssaultField`'s exported `assault_delay = 90.0`. `scenes/combined_arms_assault.tscn` has no delay override. Physics advances `elapsed` by `delta`, issues the assault once at `elapsed >= assault_delay`, and displays `ceil(max(0, assault_delay - elapsed))`; display and dispatch therefore share the configured schedule and simulation clock. The result freezes that clock. Restart loads the combined-arms scene again with fresh elapsed/issued state and its normal 90-second default.

Tactical/HUD fixtures assign **600 seconds** to individual freshly instantiated fields before adding them to the scene tree. Those fixtures provide time for isolated layout/economy interactions and do not mutate the packed scene or shared construction/weapon resources. A test image near 548 seconds is consistent with an already-running 600-second fixture; no normal-launch leak or countdown arithmetic defect was demonstrated. Other existing isolated production accounting cases also use local delays. **No gameplay timer correction was made.** HUD checks cover fresh normal instances after overridden instances, real dispatch at 90 seconds, displayed countdown, and Restart defaults.

## Saved validation before final integration

The original regression ran from a fresh source copy through [validate-m8.ps1](../tools/validate-m8.ps1) and the installed-engine [external wrapper](../tools/run-godot.ps1). [results.json](../validation-output/m8/hud81-regression-01/results.json) retains exact commands, arguments, exits, durations and native-error lines. Each per-suite `.ps1` beside its log is the exact replayable wrapper call. No graphical run is present in this original regression phase.

| Original saved execution | Checks / failures | Exit | Native errors |
| --- | --- | --- | --- |
| Fresh-copy import | — | 0 | 0 |
| Headless selection/milestone | 127 / 0 | 0 | 0 |
| Headless tactical interface | 126 / 1 | 1 | 6 |
| Headless control groups | 82 / 2 | 1 | 0 |
| Headless production | 192 / 0 | 0 | 0 |
| Headless harvesting | 298 / 3 | 1 | 0 |
| Headless construction | 267 / 0 | 0 | 0 |
| Headless construction cleanup | 46 / 0 | 0 | 0 |
| Headless vehicle production | 225 / 1 | 1 | 18 |
| Headless base assault | 124 / 1 | 1 | 21 |
| Headless combat | 183 / 0 | 0 | 0 |
| Headless line of fire | 305 / 0 | 0 | 0 |

Separate direct workspace HUD logs retain [headless-01](../validation-output/m8.1/hud-headless-01.log) **132/0**, [graphical-01](../validation-output/m8.1/hud-graphical-01.log) **141/0**, and later [headless-02](../validation-output/m8.1/hud-headless-02.log) **147/0**, all **exit 0, native_errors=0**. The graphical pass predates later Help/placement/nine-group and lifetime checks. Its captures remain historical evidence, not current layout proof. No failure is erased by a passing rerun.

After the resume corrections, the coordinated focused runs used these exact wrapper calls from the repository root:

```powershell
& .\tools\run-godot.ps1 -GodotPath 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/harvesting_checks.gd','--','--harvest-case=quantities')
& .\tools\run-godot.ps1 -GodotPath 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/control_group_checks.gd')
& .\tools\run-godot.ps1 -GodotPath 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/tactical_interface_checks.gd')
& .\tools\run-godot.ps1 -GodotPath 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' -TimeoutSeconds 120 -GodotArguments @('--headless','--path','.','--fixed-fps','60','--script','res://tests/hud_clarity_checks.gd','--','--hud-case=panel_lifetime')
```

| Focused resume check | Checks / failures | Exit | Native errors |
| --- | --- | --- | --- |
| [Harvesting quantities](../validation-output/m8.1/resume-harvest-quantities.log) | 22 / 0 | 0 | 0 |
| [Control groups](../validation-output/m8.1/resume-control-groups.log) | 82 / 0 | 0 | 0 |
| [Tactical interface](../validation-output/m8.1/resume-tactical.log) | 126 / 0 | 0 | 0 |
| [HUD panel lifetime](../validation-output/m8.1/resume-panel-lifetime.log) | 34 / 0 | 0 | 0 |

The lifetime case covers legitimate health/work updates, observer counts across repeated selections, selected unit departure, detached retained panels, and old deferred actions after match replacement. The full HUD suite separately exercises selected producer destruction and viewport Restart. These intermediate focused passes are distinct from the completed corrected-source integration below.

## Final integration validation and captures

The **earlier, pre-callback-fix** disconnected run finished successfully. Its actual files are [results.json](../validation-output/m8/hud81-final-01/results.json), [summary.json](../validation-output/m8/hud81-final-01/summary.json), [plan.json](../validation-output/m8/hud81-final-01/plan.json), and [source-hashes.json](../validation-output/m8/hud81-final-01/source-hashes.json), corroborated by [resume-final-wrapper.log](../validation-output/m8.1/resume-final-wrapper.log). It completed a fresh import and **22/22 test executions, 4,105 checks, 0 failures, 0 native-error lines, every exit 0**, in 359.368 seconds. That result predates the demonstrated synchronous callback failure and does not certify the correction. Recovery found no remaining Godot or validation process; no completed execution was restarted merely because the stream disconnected.

The run tested its isolated `validation-output/m8/hud81-final-01/project/` copy, based on the revision saved in [revision.txt](../validation-output/m8/hud81-final-01/revision.txt) plus the recorded working changes. All **260** manifest entries were checked against the recovered workspace: only `README.md` and `tests/hud_clarity_checks.gd` differed. The test delta added the pending reproduction; all runtime files matched. Each execution's exact wrapper call and process command are retained in `results.json` and the identically named `.ps1` beside each log. The saved plan corresponds to this runner invocation from the repository root (with `$godot` as defined under Play):

```powershell
& .\tools\validate-m8.ps1 -RunName hud81-final-01 -GodotPath $godot -TimeoutSeconds 240 -Modes headless,graphical -Suites hud_clarity_checks,tactical_interface_checks,control_group_checks,harvesting_checks,construction_checks,construction_cleanup_checks,production_checks,vehicle_production_checks,base_assault_checks,combat_checks,line_of_fire_checks
```

Only the demonstrated callback correction required subsequent runtime edits: `scripts/production_panel.gd` and `scripts/harvest_panel.gd`. The already-existing runner captured the corrected source and regression in [hud81-callback-01](../validation-output/m8/hud81-callback-01/plan.json), using this exact command:

```powershell
& .\tools\validate-m8.ps1 -RunName hud81-callback-01 -GodotPath 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' -TimeoutSeconds 240 -Modes headless,graphical -Suites hud_clarity_checks,tactical_interface_checks,harvesting_checks,construction_checks,construction_cleanup_checks,production_checks,vehicle_production_checks,base_assault_checks
```

The **post-fix** run also finished successfully before this handoff resumed. [callback-final-wrapper.log](../validation-output/m8.1/callback-final-wrapper.log) identifies the actual [results.json](../validation-output/m8/hud81-callback-01/results.json), [summary.json](../validation-output/m8/hud81-callback-01/summary.json), and [source-hashes.json](../validation-output/m8/hud81-callback-01/source-hashes.json). Its fresh import and **16/16 executions passed: 2,982 checks, 0 failures, 0 native-error lines, every exit 0**, in 309.023 seconds including import. The final result files were saved at approximately **2026-09-08 03:19:25 UTC / September 7, 23:19:25 America/Indianapolis**. Process inspection during collection found no remaining Godot or associated wrapper process. The completed runner was not duplicated.

Control-group checks extend `base_assault_checks.gd` and instantiate the assault HUD, so their earlier passes could not be reused. Only those two missing affected executions were completed, serially, against the **same retained `hud81-callback-01/project/` snapshot**, after verifying all 261 snapshot hashes. [Supplementary results](../validation-output/m8.1/callback-control-groups-01/results.json) and the [collection script](../validation-output/m8.1/collect-callback-control-groups.ps1) retain exact wrapper calls, timestamps, durations and exits. Both passed **82/82, exit 0, native_errors=0**. The original 16-run plan/results were left intact. The checkpoint's provisional proposal to reuse control-group results is superseded by this dependency reconciliation.

| Final affected suite | Headless checks / failures | Graphical checks / failures |
| --- | --- | --- |
| HUD clarity | [193 / 0](../validation-output/m8/hud81-callback-01/headless-hud_clarity_checks.log) | [205 / 0](../validation-output/m8/hud81-callback-01/graphical-hud_clarity_checks.log) |
| Tactical interface | [126 / 0](../validation-output/m8/hud81-callback-01/headless-tactical_interface_checks.log) | [138 / 0](../validation-output/m8/hud81-callback-01/graphical-tactical_interface_checks.log) |
| Harvesting | [298 / 0](../validation-output/m8/hud81-callback-01/headless-harvesting_checks.log) | [299 / 0](../validation-output/m8/hud81-callback-01/graphical-harvesting_checks.log) |
| Construction | [267 / 0](../validation-output/m8/hud81-callback-01/headless-construction_checks.log) | [270 / 0](../validation-output/m8/hud81-callback-01/graphical-construction_checks.log) |
| Construction cleanup | [46 / 0](../validation-output/m8/hud81-callback-01/headless-construction_cleanup_checks.log) | [46 / 0](../validation-output/m8/hud81-callback-01/graphical-construction_cleanup_checks.log) |
| Production | [192 / 0](../validation-output/m8/hud81-callback-01/headless-production_checks.log) | [193 / 0](../validation-output/m8/hud81-callback-01/graphical-production_checks.log) |
| Vehicle production | [225 / 0](../validation-output/m8/hud81-callback-01/headless-vehicle_production_checks.log) | [230 / 0](../validation-output/m8/hud81-callback-01/graphical-vehicle_production_checks.log) |
| Base assault | [124 / 0](../validation-output/m8/hud81-callback-01/headless-base_assault_checks.log) | [130 / 0](../validation-output/m8/hud81-callback-01/graphical-base_assault_checks.log) |
| Control groups, supplementary | [82 / 0](../validation-output/m8.1/callback-control-groups-01/headless-control_group_checks.log) | [82 / 0](../validation-output/m8.1/callback-control-groups-01/graphical-control_group_checks.log) |
| **Post-fix affected total: 18/18** | **1,553 / 0** | **1,593 / 0** |

Every execution above exited **0** with **0 native/script errors or warnings**. The focused corrected callback reproduction's **48/48** is additional evidence, not added again to the integration total; its assertions also run inside both full HUD executions. The two new reproduction paths account for the **28-check** increase over the prior matrix (14 additional assertions in each HUD mode).

### Final source correspondence and reused results

Both snapshot manifests were checked against their retained project files: **260/260** entries match for `hud81-final-01`, and **261/261** match for `hud81-callback-01`. Their base revision is `a75749664e79745b64c897c754d792fc81668dde`, plus the captured working changes; [starting-diff.patch](../validation-output/m8/hud81-callback-01/starting-diff.patch) and [starting-status.txt](../validation-output/m8/hud81-callback-01/starting-status.txt) retain the dirty-workspace provenance. The snapshots differ only in `README.md`, newly captured `docs/milestone-8.1.md`, `scripts/production_panel.gd`, `scripts/harvest_panel.gd`, and `tests/hud_clarity_checks.gd`.

At collection, the corrected snapshot matched **260/261** current workspace files, with only this report different. Final handoff edits also update the README status; **all runtime, scene, resource, test, project configuration and runner files still match the corrected snapshot byte for byte**. The only final manifest mismatches are these two documentation files. The post-fix runtime identities are:

| Corrected file | SHA-256 |
| --- | --- |
| `scripts/production_panel.gd` | `10a13fd848b0d6244903a4f5ffb0736882c3c8313722cf6d0b49344dbec7e557` |
| `scripts/harvest_panel.gd` | `b4fbb1ca2b4d70246b5eeef2dc7aa6a5a6ce13d0734f9a04d4460b4cbf44c7de` |

Combat fixtures load `scenes/combat_test.tscn` through `CombatField`; line-of-fire fixtures load `scenes/line_of_fire_test.tscn` through `LineOfFireField`, inheriting the combat fixture. Neither uses ProductionPanel or HarvestPanel. Their fixture scripts, inherited tests, scene/resource dependencies and shared combat/selection/runtime files are unchanged between the snapshots and final workspace. Therefore only these earlier executions are reused:

| Reused unaffected suite from `hud81-final-01` | Headless checks / failures | Graphical checks / failures |
| --- | --- | --- |
| Combat | [183 / 0](../validation-output/m8/hud81-final-01/headless-combat_checks.log) | [191 / 0](../validation-output/m8/hud81-final-01/graphical-combat_checks.log) |
| Line of fire | [305 / 0](../validation-output/m8/hud81-final-01/headless-line_of_fire_checks.log) | [308 / 0](../validation-output/m8/hud81-final-01/graphical-line_of_fire_checks.log) |
| **Reused total: 4/4** | **488 / 0** | **499 / 0** |

These four executions exited 0 with zero native-error lines. **3,146 post-fix affected checks + 987 reused unaffected checks = 4,133 checks across 22 reconciled executions**, all passing. This is a correspondence-based handoff across two source captures, not a claim that all 4,133 checks ran after the callback correction. No historical movement suite or general review was restarted, and all failed logs remain preserved.

### Verified rendered captures and sizes

All **12 corrected-source PNGs** below were opened and inspected during final collection. PNG dimensions agree with the actual viewport sizes asserted by the graphical HUD log. These are game window **content/viewport sizes**, not measurements including the operating system window border. Text and queue controls fit their panels; Help, context, objective and minimap do not overlap. Placement guidance remains readable beside expanded Help. Compact mobile health feedback leaves the army visible; buildings and supplies retain small identity labels. No hardware-statistics overlay appears. The full-queue shots retain all five Cancel controls, and both nine-group shots fit their chips beneath the unchanged map.

| Verified state | 1280×720 capture | 1920×1080 capture |
| --- | --- | --- |
| Initial compact Help / HQ context | [Initial](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/initial_1280x720.png) | [Initial](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/initial_1920x1080.png) |
| Expanded Help | [Help](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/help_1280x720.png) | [Help](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/help_1920x1080.png) |
| Help during valid placement | [Help and placement](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/help_placement_1280x720.png) | — |
| Mixed Rifle/Rocket selection, Group 3 | [Mixed selection](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/mixed_1280x720.png) | — |
| All nine group chips | [Nine groups](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/nine_groups_1280x720.png) | [Nine groups](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/nine_groups_1920x1080.png) |
| Full Vehicle Factory queue | [Production](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/production_1280x720.png) | [Production](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/production_1920x1080.png) |
| Victory overlay / accessible Restart | [Victory](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/victory_1280x720.png) | — |
| Restarted normal scene, closed Help, 90 seconds | [Restarted](../validation-output/m8/hud81-callback-01/artifacts/graphical-hud_clarity_checks/m8.1/screenshots/restarted_1280x720.png) | — |

The initial 1920×1080 capture follows the same live Help fixture and reads 89 seconds; Restart reads 90. Mixed/production/group fixtures intentionally use local 600-second delays. Earlier captures remain preserved but are superseded for final layout evidence by these corrected-source images. Automated viewport injection is **not physical keyboard-and-mouse playtesting**; no human playtest was performed.

## Original acceptance groups

| Original required group | Status | Final evidence |
| --- | --- | --- |
| 1. Compact Help behavior | PASS | Corrected HUD Help case: closed launch/Restart, click/F1/Escape, continued simulation, bounded pointer consumption, uncovered world/minimap access, placement Escape priority and focused-key isolation; inspected Help captures |
| 2. Correct contextual selection panel | PASS | HUD context/production/lifetime cases and harvesting: neutral/single/mixed/collector/HQ/site/producer context, authoritative HP/counts/cargo, live updates, destruction/selection pruning, observer cleanup and retained/deferred old callbacks; focused correction 48/48 |
| 3. Reduced overlapping world labels | PASS | HUD labels case verifies hidden healthy mobile names/HP, selected/damaged bars and compact building identity; inspected mixed, production and nine-group captures show visible units without floating paragraphs; exact HP stays in context |
| 4. Debug-only diagnostic visibility | PASS | HUD labels case: three F3 cycles, diagnostic visibility restored, no node/economy/health changes, placement-only access outlines; normal captures show no diagnostic/hardware overlay |
| 5. Clear control-group and objective feedback | PASS | Actual “Group 3 · 2 units”, valid-member departure, nine numbered chips and full tooltip assertions; inspected both chip layouts; compact objective and command feedback preserved |
| 6. Accurate countdown and Restart | PASS | HUD lifecycle executes the real 90-second assault boundary, matching displayed countdown and all three enemy orders; fresh instances after local overrides and viewport Restart restore the normal schedule, Help/debug/groups/economy/force |
| 7. Preserved minimap, groups, production, and input behavior | PASS | All 18 affected executions pass, including the two corrected-snapshot control-group checks; tactical viewport mapping/commands/input isolation, construction/production/refunds/blocked exits and lifetime checks; four unaffected combat/line-of-fire passes reused on unchanged dependencies |
| 8. Readable layouts at the tested resolutions | PASS | All 12 corrected-source captures visually inspected and dimensions verified; HUD geometry asserts panel bounds/non-overlap, unobscured minimap, five Cancel controls and all nine chips at 1280×720 and 1920×1080 |

## Deferred movement and limits

Movement issues remain **DEFERRED / UNRESOLVED**, separately from HUD acceptance, under the existing [roadmap decision](roadmap.md#priority-decision--2026-09-07) and [movement issue records](movement-issue-records.md). Full movement and full Milestone 5 regression acceptance have not passed. Historical M7 unit-41 projection-fixture and unit-5 gate failures retain unknown attribution despite later passing source-matched runs. The earlier harvesting-fixture failure's cause also remains **UNKNOWN**; readiness diagnostics and later passes do not establish its original cause, and it is not relabeled a historical movement issue.

No Milestone 8.1 acceptance requirement remains failed or unverified within the recorded automated/runtime and rendered checks. Physical keyboard-and-mouse human playtesting, other platforms/renderers, other window sizes and a new performance benchmark were not performed. This milestone adds no fog of war, units, strategic AI, group-editing system, or general movement repair. Milestone 9 is not started; no commit or engine upgrade was made. Logs, source copies and screenshots under ignored `validation-output/` are local evidence and must accompany this report if transferred elsewhere.
