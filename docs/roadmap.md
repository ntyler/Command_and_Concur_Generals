# Feature roadmap and current priority

## Priority decision — 2026-09-07

The user explicitly authorized forward feature development from the current working implementation, superseding the earlier requirement to resolve historical movement failures before starting another milestone.

**Outstanding movement issues are DEFERRED KNOWN LIMITATIONS; their engineering status remains UNRESOLVED. They do not automatically block authorized feature development, now completed through Milestone 10. Full movement acceptance and full Milestone 5 regression acceptance have not passed.** This is a scheduling decision, not a bug closure, test waiver or claim of movement reliability.

This decision supersedes earlier instructions in milestone/investigation reports that all subsequent work must remain blocked or that another movement investigation must come next. Those reports retain their historical results, failures, reproduction constraints and evidence. Closed historical execution budgets are not reopened.

- Preserve the current implementation, including Issue A's parked-neighbor repair, the projection step-size repair, the bounded local escape repair and the numerical gate-corner repair. Do not roll back validated repairs.
- Preserve existing tests and assertions, fixtures, failed executions, reproduction records, diagnostics and retained evidence, including ignored `validation-output/` files.
- Keep open cases visible in [movement issue records](movement-issue-records.md). Do not start movement investigation, historical replay, recorder expansion or repair unless the user requests it or concrete evidence demonstrates that it directly prevents required next-milestone behavior. Scope any necessary work to that demonstrated dependency.
- Continue relevant regression testing and report all failures. A passing rerun does not erase a failure; a familiar assertion name does not establish that a new failure is pre-existing. Use retained baseline/source evidence for attribution, and label uncertain attribution unknown.
- Assess each feature milestone separately from deferred movement acceptance. The deferral does not excuse new regressions or failure of that milestone's own requirements.

## Implemented sequence and current feature

At the priority decision, the repository documented milestones through Milestone 5 and its corrective work, with no subsequent feature defined. Milestone 6 was then recommended and explicitly authorized for implementation; its current behavior and evidence are in [the Milestone 6 report](milestone-6.md).

| Milestone | Feature / status |
| --- | --- |
| 1–1.5.1 | Camera, selection, group movement and crowd controls; validated repairs retained, movement limitations remain |
| 2–2.5.1 | Health, Rifle/Rocket combat, pursuit/retaliation, line of fire and spherical projectile collision |
| 3 | Fixed HQ/barracks, shared credits, Rifle queues and rally points |
| 4 | Finite supply harvesting, collector cargo and automatic deposits |
| 5 | Player-placed barracks, paid timed construction, cancellation and serialized navigation updates; feature implemented, full regression acceptance not passed |
| **6 — implemented** | **Playable base assault: damageable HQs/completed barracks, an integrated economy-to-combat scenario, victory/defeat/draw and restart. See the separate feature validation report.** |
| **7 — implemented; feature checks pass** | **Vehicle Factory and existing Rocket Vehicle production, through shared construction/queues, in a combined-arms assault variant. All A–G feature groups pass automated headless/graphical validation, including the zero-credit earned-army victory loop. Movement acceptance remains separate; see [results and limitations](milestone-7.md).** |
| **8 / 8.1 — complete** | **Fully revealed minimap, groups 1–9, compact Help and contextual HUD in the combined-arms scene. All eight final acceptance groups pass in [Milestone 8.1](milestone-8.1.md); the earlier [M8 report](milestone-8.md) retains its historical scaffold.** |
| **9 — attack-move; complete** | **All eight acceptance groups PASS. Q/button battlefield or minimap targeting for existing Rifles/Rockets, bounded automatic engagements and resumed original slots through existing movement/combat. Expanded/collapsed Help verified at 1280x720 and 1920x1080. See [Milestone 9](milestone-9.md).** |
| **10 — enemy economy and repeat assaults; complete** | **All eight feature groups PASS in the separate economy-assault scene. Real harvesting funds paid Rifle production, staging and existing attack-move waves. Opponent/integration: 261 passing assertions in both modes. Full matrix: 59/60 executions, 7,393 assertions, three graphical movement-stress failures of unknown attribution, exit 1. See [Milestone 10](milestone-10.md).** |

Milestone 6 gives construction, harvesting, production and combat a shared match objective. It uses a small flat map and existing units, resources and commands. Strategic AI, additional economic systems and general movement reliability work remain outside this milestone.

Milestone 6's original scope and validation remain in its [implementation prompt](milestone-6-prompt.md) and [report](milestone-6.md). Milestone 7 added one factory, one recipe for the existing Rocket Vehicle and a combined-arms scene reusing the base-assault lifecycle. [Milestone 7](milestone-7.md) records its completed implementation and historical validation separately from deferred movement acceptance.

The completed **Milestone 8 — tactical minimap and control groups** remains in `res://scenes/combined_arms_assault.tscn`. Left-click the minimap to center the existing camera; right-click for ordinary ground Move. **Ctrl + 1–9** replaces/clears a mobile-unit group, **1–9** recalls it, and a double-tap centers the camera. Marker refresh defaults to **0.1 seconds**, and double-tap timing to **0.3 seconds** of real input time. The map uses fixed +X-right/+Z-down orientation and shows the fully revealed field. Existing selection, ownership, command acceptance, construction, production and match-result/Restart systems remain authoritative.

Final M8/8.1 acceptance is saved in [Milestone 8.1](milestone-8.1.md): 18 post-fix executions / 3,146 passing checks plus four unaffected combat/line-of-fire executions / 987 reused passing checks, with 12 corrected-source captures inspected. This supersedes the initial M8 report's pending acceptance entries. No human playtest occurred.

**Milestone 9 — Attack Move commands is COMPLETE (2026-09-08)** in the same playable scene. Q or the contextual button enters ground targeting; battlefield and minimap clicks share normal batch-command authority. Existing armed units retain an original final slot, acquire nearby eligible hostiles with shared line-of-fire geometry, pursue/fire using existing combat, abandon bounded engagements and resume travel. Collectors remain ineligible and keep their work in mixed selections. Ordinary Move/Attack/Stop and group recall preserve their separate meanings.

The [M9 report](milestone-9.md) records the original complete matrix (**56 executions / 7,116 checks**) and final source coverage: **50 reused executions / 6,277 checks + six post-layout executions / 855 checks**, all passing with zero failures/native error lines and exits 0. The affected reruns cover HUD, attack-move UI and tactical interface in both modes, including produced Rifle/Rocket damage, independent physical resumed travel and retained distinct slot arrival. Source hashes, corrected Help captures, earlier failed executions and all eight PASS acceptance groups are saved. No human playtest occurred.

The completed M9 scenes retain their starting forces, credits, costs, resource amounts, production timing, 90-second scripted enemy assault and result/Restart rules.

**Milestone 10 — enemy economy and repeat assaults is COMPLETE (2026-09-08)** in the separate `res://scenes/economy_assault.tscn`. Open it and press F6, or use the installed Godot with `--path . res://scenes/economy_assault.tscn`. A bounded scene-local controller uses real owner-isolated harvesting, paid Rifle queues, assembled produced troops and existing attack-move. Defaults remain 300 enemy credits, a new finite 2000-supply cache, 0.5-second planning, 90-second earliest wave, 60-second launch interval, preferred/maximum three recipients, 30-second partial wait and a 12-unit combat population including pending deployments. The first threshold is earliest eligibility; production and staging can delay launch. Earlier playable scenes retain their one-shot assaults.

The [M10 report](milestone-10.md) saves all eight PASS feature groups, actual commands/exits, original failed runs and normal captures at 1280x720 and 1920x1080. The completed, source-matched matrix has **60/60 completed executions, 59 passing, 7,393 assertions, three failures and phase exit 1**. Opponent checks pass **96 headless / 98 graphical**, and zero-credit integration passes **33 / 34**, including real damage by every member of two paid waves and exact deposit/spending reconciliation. These 261 assertions are part of the matrix, not an additional acceptance total. No runtime changes or engine reruns were needed during final recovery; only the three handoff documents changed.

**Unknown attribution:** graphical `movement_stress_checks` failed three `choke_30` arrival/traversal/settling assertions for unit 13. This occurrence is not established as pre-existing or newly introduced. Its failed log and metrics remain linked in M10, without retries or historical movement investigation. No M10 feature failures or demonstrated newly introduced regressions remain; documented deferred movement findings remain separately unresolved. Feature completion does not claim a clean full regression matrix or a human playtest.

No strategic planner, rebuilds, free reinforcement income, fog of war, patrol/guard, stances, new gameplay unit types, multiplayer, automatic flanking or movement investigation is included. **Milestone 11 is not started or authorized by this task.**

## Baseline and validation provenance

The working tree was clean at the start of the original priority update, at commit `d5fc444`. Current `scripts/rts_unit.gd` SHA-256 is `2f46d67b3267ab233405457f8c84e83ebc46b8f461e75deef46ee5c3f33b34d0`, matching final source in the [latest gate repair report](milestone-5-gate-repair.md).

That report records a final 36-execution integration matrix with 4,740 assertions and zero failures, while preserving an earlier graphical unit-23 gate run with 39 checks and three failures on the repaired code. Historical unit 41 and original Issue B remain unresolved. These are prior results and do not establish full movement acceptance.

The M7 completion pass started at clean existing implementation commit `643099f`. Its previously unfinished report now records **225 headless / 230 graphical** passing Vehicle Production checks and **124 / 130** passing Base Assault checks. The first M7 complete matrix passed 43 of 44 test executions, with three headless projection-fixture assertions failing; attribution to historical movement issues or M7 integration remains unknown. That failed execution is retained in [movement issue records](movement-issue-records.md) and [the M7 report](milestone-7.md), separately from passing required feature behavior. No gameplay, movement, existing test, engine or dependency changes were made during this completion pass.

The M7 completion pass then ran one complete matrix on a freshly imported source copy: **43/44 test executions passed, 5555 assertions and 2 failures**, with all M7 and M6 feature checks passing in both modes. Graphical `choke_50` arrival/settling failed for unit 5; its relationship to earlier failures remains unknown. This failed execution was retained without retry or movement investigation. [Exact commands, per-suite results and screenshots](milestone-7.md#completion-verification-on-the-installed-engine) preserve the M7 handoff. Feature A–G acceptance passed in that verification; full movement/Milestone 5 acceptance remains unpassed. That pass contained no M8 implementation.

A repeated M7 implementation request was audited against the existing `643099f` implementation with those four documentation edits preserved. Its single current-source matrix, `request-audit-20260907`, passed fresh import and **44/44 test executions, 5555 assertions and zero failures**. M7 passed **225 headless / 230 graphical** checks and M6 **124 / 130**. No gameplay or test change was needed. [That request's verification](milestone-7.md#repeated-request-verification) retains separate source hashes, commands, results and images; it does not close the earlier failed movement executions or reopen investigation. Only handoff documentation was updated during that completed M7 pass.

M8 began on clean commit `7f9a1e4d17f6f030061bc9b729484ebab225fa08`. Its starting audit matched all **226** files in the completed M7 request snapshot except the three expected handoff documents (`README.md`, `docs/roadmap.md`, `docs/milestone-7.md`). Gameplay, scenes, resources, tests and tools matched, so the recorded M7 results are reused as the baseline without another historical validation campaign. The [M8 report](milestone-8.md#baseline-and-preservation) retains the comparison and separates newly executed M8 results from that baseline. The installed Godot version and dependencies remain unchanged.
