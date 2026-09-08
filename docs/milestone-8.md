# Milestone 8 — Tactical minimap and control groups

2026-09-07. Implementation and validation are in progress. The playable target is the existing `res://scenes/combined_arms_assault.tscn`. This report will record completed behavior and actual validation before handoff; pending items below are not acceptance claims.

## Baseline and preservation

The task began on clean commit `7f9a1e4d17f6f030061bc9b729484ebab225fa08`. No applicable `AGENTS.md` was found in the repository or its directory ancestors. README, roadmap, the completed [Milestone 7 report](milestone-7.md) and [movement issue records](movement-issue-records.md) were read. No existing edits were discarded, and no reset, commit, tag, installation or dependency upgrade is part of this task.

A [source comparison](../validation-output/m8/starting-source-audit.json) at **2026-09-08 02:18:39 UTC** (September 7 locally) found all **226** files captured in `validation-output/m7/request-audit-20260907/source-hashes.json`. Only `README.md`, `docs/roadmap.md` and `docs/milestone-7.md` differed, exactly the documentation differences recorded by that completed handoff. Gameplay, scenes, resources, tests, tools and the retained movement issue document matched the validated source. Therefore no affected baseline rerun was needed before Milestone 8 implementation.

The accepted starting evidence is the recorded M7 request audit: **fresh import PASS, 44/44 test executions PASS, 5,555 assertions, zero failures/native error lines, 536.602 seconds**. Vehicle Production passed **225 headless / 230 graphical** checks; Base Assault passed **124 / 130**. These are source-matched prior results, not newly executed M8 tests. See the [M7 audit](../validation-output/m7/request-audit-20260907/audit.json) and [commands/results](../validation-output/m7/request-audit-20260907/results.json). Historical validation was not repeated.

## Play and controls

Open `scenes/combined_arms_assault.tscn` in the installed Godot editor and press **F6**, or use PowerShell from the repository root:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/combined_arms_assault.tscn
```

The engine remains **Godot 4.7.2.stable.official.ed1daf0bf**. Intended controls: minimap left-click centers the existing camera; minimap right-click issues ordinary ground Move to selected eligible mobile units; **Ctrl + 1–9** replaces or clears a group, **1–9** recalls it, and a same-key double-tap centers the camera. Marker refresh is specified at **0.1 seconds** and double-tap timing at **0.3 seconds**. Implementation details and verified defaults are pending final inspection.

## Implementation and acceptance

| Required behavior | Status | Evidence |
| --- | --- | --- |
| 1. Accurate minimap mapping and camera footprint | NOT VERIFIED | Pending focused tests |
| 2. Correct, lifecycle-safe entity markers | NOT VERIFIED | Pending focused tests |
| 3. Camera navigation through minimap input | NOT VERIFIED | Pending viewport input tests |
| 4. Ground movement through the existing command system | NOT VERIFIED | Pending viewport input tests |
| 5. Group assignment, recall and double-tap centering | NOT VERIFIED | Pending focused tests |
| 6. Keyboard/UI input isolation | NOT VERIFIED | Pending focused tests |
| 7. Death, departure, match-result and Restart safety | NOT VERIFIED | Pending lifecycle tests |
| 8. Integrated produced-army gameplay | NOT VERIFIED | Pending actual production-to-combat loop |
| 9. Readable layout at tested window sizes | NOT VERIFIED | Pending 1280×720 and 1920×1080 captures/review |
| 10. Relevant regression coverage and accurate failure reporting | NOT VERIFIED | Pending final source matrix |

Important changed files, final coordinate convention, geometry/registry caching behavior and integration details will be added after implementation inspection. Automated viewport input does not constitute a human keyboard-and-mouse playtest.

## Validation commands and retained evidence

The [M8 phase runner](../tools/validate-m8.ps1) copies tracked and nonignored source into a new directory, verifies SHA-256 for each copied file and imports without an inherited `.godot` cache. Every engine invocation goes through the existing [external-timeout wrapper](../tools/run-godot.ps1), with a default **240-second wall deadline** and fixed 60 FPS for tests. Phase directories cannot be reused. Exact wrapper commands, engine arguments, stdout/stderr/combined logs, exits, durations, source hashes and per-run artifacts are retained under `validation-output/m8/<phase>/`. No failed suite is automatically retried; the aggregate runner exits nonzero for any failed, incomplete or error-bearing execution.

Planned commands, to be replaced or supplemented by actual execution records:

```powershell
# Focused edit/test cycle; always choose a new phase name.
& .\tools\validate-m8.ps1 -RunName feature-01 -Suites tactical_interface_checks,control_group_checks
# Run the normal complete regression matrix once after implementation is stable.
& .\tools\validate-m8.ps1 -RunName final-matrix
git diff --check
```

The default matrix contains **48 test executions**: the prior 22 cases per display mode plus `tactical_interface_checks` and `control_group_checks` in both headless and graphical modes. Every phase begins with fresh-copy import, so the tactical checks also validate a freshly imported source copy.

| Prior regression cases, each in both modes |
| --- |
| `milestone_checks`, `movement_repair_checks`, `parked_deadlock_checks`, `parked_deadlock_controls`, `captured_parked_cluster_checks`, `projection_step_checks` |
| `boundary_neighbor_checks`, `boundary_neighbor_controls`, `gate_movement_checks`, `gate_movement_checks -- --avoidance` |
| `construction_checks`, `construction_cleanup_checks`, `harvesting_checks`, `production_checks` |
| `combat_checks`, `combat_repair_checks`, `line_of_fire_checks`, `spherical_projectile_checks`, `movement_stress_checks` |
| `base_assault_checks`, `vehicle_production_checks`, `combat_checks -- --combat-load` |

Actual M8 totals, exits, failures and graphical observations: **NOT VERIFIED — no M8 validation phase has been run at this report's initial scaffold stage.** Every failed implementation/parser/harness execution will remain listed, with attribution distinguished between feature failure, demonstrated new regression, deferred movement finding and unknown attribution.

## Deferred movement status and limits

Outstanding movement findings remain **DEFERRED / UNRESOLVED** as documented in [movement issue records](movement-issue-records.md). The prior M7 headless unit-41 projection-fixture failure and graphical unit-5 gate failure retain **UNKNOWN attribution**, despite the later passing source-matched request audit. Matching an old assertion or unit number does not prove a newly observed failure has the same cause. Passing M8 feature checks will not retroactively establish full movement or Milestone 5 regression acceptance.

No historical movement replay, speculative repair, recorder expansion or Milestone 9 work is included. Human keyboard-and-mouse playtesting is **NOT PERFORMED / NOT VERIFIED**. Final feature limitations remain pending implementation and rendered review.
