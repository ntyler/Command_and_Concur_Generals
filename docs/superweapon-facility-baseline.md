# Buildable superweapon facility — baseline and missing specification

The [roadmap](roadmap.md#superweapon-facility--scope-definition-pending) identifies **the buildable superweapon facility** as the next planned feature. It does not assign a milestone number or define detailed behavior, scope boundaries or acceptance criteria. Repository documentation and source searches found no separate specification. The name alone does not define what to implement or how to accept it. No milestone number or weapon design has been inferred.

**Implementation: NOT STARTED. Feature verification: NOT VERIFIED. Acceptance of the completed feature: NOT ASSESSED.** The owner has authorized continued development from M16; implementation is pending the missing specification because the current instruction explicitly prohibits inventing scope. This is not a renewed movement-acceptance gate.

## Repository and implementation inspection

README, roadmap, the M16 report and the existing movement issue record were read before changes. No `AGENTS.md` was found in the repository or its checked ancestor directories. The starting working tree was clean at revision **`f5d403673647da45f61e32577f0f6c76d6c5d273`**.

The shared [construction definition](../scripts/construction_definition.gd), [construction field](../scripts/construction_field.gd), [site/accounting coordinator](../scripts/building_construction.gd), [construction building](../scripts/construction_building.gd) and [builder scene controller](../scripts/builder_assault_field.gd) were inspected. Existing construction owns placement/payment, ordinary builder approach and work eligibility, pause/resumption, navigation synchronization and building lifecycle. No facility kind or superweapon implementation exists in these paths. The focused baseline exercises these existing buildable-structure dependencies without choosing unspecified facility behavior.

## Checks actually executed

The existing [fresh-copy runner](../tools/validate-m8.ps1) and [external deadline wrapper](../tools/run-godot.ps1) were inspected and used unchanged. The phase began at **2026-09-09T22:28:07.9543869Z**, using installed **Godot 4.7.2.stable.official.ed1daf0bf** and a 240-second external deadline per execution:

```powershell
& .\tools\validate-m8.ps1 -RunName superweapon-facility-baseline-01 -TimeoutSeconds 240 -Modes @('headless') -Suites @('construction_checks', 'builder_checks')
```

| Execution | Checks | Assertion failures | Native-error lines | Exit |
| --- | ---: | ---: | ---: | ---: |
| Fresh headless import | 0 | 0 | 0 | 0 |
| `headless-construction_checks` | 271 | 0 | 0 | 0 |
| `headless-builder_checks` | 314 | 0 | 0 | 0 |

**2/2 test executions passed; 585 checks; aggregate exit 0.** Import is separate from those two test executions. The [summary](../validation-output/m8/superweapon-facility-baseline-01/summary.json), [execution results](../validation-output/m8/superweapon-facility-baseline-01/results.json), [plan](../validation-output/m8/superweapon-facility-baseline-01/plan.json), [388-file source manifest](../validation-output/m8/superweapon-facility-baseline-01/source-hashes.json), retained `project/`, invocation scripts and all logs remain in the unique phase directory. The runner reports zero source differences after the run. The subsequent edits are limited to this report and the roadmap.

Construction checks cover existing placement, accounting, synchronized navigation, failure handling and earned construction. Builder checks cover existing production, placement, physical approach/work, pause/resumption, replacement, callbacks, blocked access, interface and freeze/lifecycle behavior. All assertions and test infrastructure were unchanged. These results are **pre-change baseline observations**, not evidence that a new facility works.

No graphical checks, movement-stress checks, full regression matrix, new-feature acceptance tests or human playtest were executed. No gameplay, movement, traversal, settling or test code changed. No new failures appeared in the two executed suites; unexecuted behavior is not reported as passing. No engine upgrade, commit, tag or discard was performed.

## Preserved M16 acceptance and unresolved validation

[Milestone 16](milestone-16.md) remains **accepted for continued feature development with deferred movement validation**. Groups 1–6 and 8 retain their reported PASS status. **Group 7 remains NOT VERIFIED** for graphical `choke_50` arrival, traversal and settling failures with UNKNOWN attribution, including any relationship to the navigation correction. The [existing issue record](movement-issue-records.md#m16--graphical-choke-50-movement-validation-open) stays open. No historical movement investigation was reopened.

Keep these evidence sets separate:

- Original `m16-final-matrix-01`: **102 executions completed, 99 passed, 12,829 checks, five assertion failures, three native-error lines, aggregate exit 1**. All 1,073 M16 checks passed within that total. The three native-error lines are the three recorded movement assertion reports; the original matrix remains failed.
- Corrected fixture `m16-preview-correction-01`: **271 headless + 274 graphical = 545 checks**, zero failures/native errors, aggregate exit 0. This remains separate coverage for the corrected preview fixture and does not replace the original failed matrix.
- Current `superweapon-facility-baseline-01`: **585 headless checks**, as recorded above. It neither replaces either M16 record nor verifies the unresolved graphical movement case.

The remaining input needed is the facility's intended behavior, scope boundaries and acceptance criteria, or the location of its existing specification. Relevant post-change checks and feature acceptance must be defined against that specification. No unrelated defect may be assigned to the movement deferral without evidence.
