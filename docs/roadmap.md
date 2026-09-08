# Feature roadmap and current priority

## Priority decision — 2026-09-07

The user explicitly authorized forward feature development from the current working implementation, superseding the earlier requirement to resolve historical movement failures before starting another milestone.

**Outstanding movement issues are DEFERRED KNOWN LIMITATIONS; their engineering status remains UNRESOLVED. They do not automatically block starting Milestone 6. Full movement acceptance and full Milestone 5 regression acceptance have not passed.** This is a scheduling decision, not a bug closure, test waiver or claim of movement reliability.

This decision supersedes earlier instructions in milestone/investigation reports that all subsequent work must remain blocked or that another movement investigation must come next. Those reports retain their historical results, failures, reproduction constraints and evidence. Closed historical execution budgets are not reopened.

- Preserve the current implementation, including Issue A's parked-neighbor repair, the projection step-size repair, the bounded local escape repair and the numerical gate-corner repair. Do not roll back validated repairs.
- Preserve existing tests and assertions, fixtures, failed executions, reproduction records, diagnostics and retained evidence, including ignored `validation-output/` files.
- Keep open cases visible in [movement issue records](movement-issue-records.md). Do not start movement investigation, historical replay, recorder expansion or repair unless the user requests it or concrete evidence demonstrates that it directly prevents required next-milestone behavior. Scope any necessary work to that demonstrated dependency.
- Continue relevant regression testing and report all failures. A passing rerun does not erase a failure; a familiar assertion name does not establish that a new failure is pre-existing. Use retained baseline/source evidence for attribution, and label uncertain attribution unknown.
- Assess Milestone 6 behavior separately from deferred movement acceptance. The deferral does not excuse new regressions or failure of Milestone 6's own requirements.

## Implemented sequence and next feature

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

Milestone 6 gives construction, harvesting, production and combat a shared match objective. It uses a small flat map and existing units, resources and commands. Strategic AI, additional economic systems and general movement reliability work remain outside this milestone.

Milestone 6's original scope and validation remain in its [implementation prompt](milestone-6-prompt.md) and [report](milestone-6.md). The user subsequently authorized Milestone 7: one factory, one recipe for the existing Rocket Vehicle, and a combined-arms scene reusing the base-assault lifecycle. [Milestone 7](milestone-7.md) records its implementation and validation separately from deferred movement acceptance. No Milestone 8 work is started or defined by this handoff.

## Baseline and validation provenance

The working tree was clean at the start of the original priority update, at commit `d5fc444`. Current `scripts/rts_unit.gd` SHA-256 is `2f46d67b3267ab233405457f8c84e83ebc46b8f461e75deef46ee5c3f33b34d0`, matching final source in the [latest gate repair report](milestone-5-gate-repair.md).

That report records a final 36-execution integration matrix with 4,740 assertions and zero failures, while preserving an earlier graphical unit-23 gate run with 39 checks and three failures on the repaired code. Historical unit 41 and original Issue B remain unresolved. These are prior results and do not establish full movement acceptance.

The M7 completion pass started at clean existing implementation commit `643099f`. Its previously unfinished report now records **225 headless / 230 graphical** passing Vehicle Production checks and **124 / 130** passing Base Assault checks. The first M7 complete matrix passed 43 of 44 test executions, with three headless projection-fixture assertions failing; attribution to historical movement issues or M7 integration remains unknown. That failed execution is retained in [movement issue records](movement-issue-records.md) and [the M7 report](milestone-7.md), separately from passing required feature behavior. No gameplay, movement, existing test, engine or dependency changes were made during this completion pass.

The completion pass then ran one complete matrix on a freshly imported source copy: **43/44 test executions passed, 5555 assertions and 2 failures**, with all M7 and M6 feature checks passing in both modes. Graphical `choke_50` arrival/settling failed for unit 5; its relationship to earlier failures remains unknown. This failed execution was retained without retry or movement investigation. [Exact commands, per-suite results and screenshots](milestone-7.md#completion-verification-on-the-installed-engine) complete the M7 handoff. Feature A–G acceptance passes; full movement/Milestone 5 acceptance remains unpassed. No Milestone 8 work follows.

A repeated implementation request was audited against the existing `643099f` implementation with those four documentation edits preserved. Its single current-source matrix, `request-audit-20260907`, passed fresh import and **44/44 test executions, 5555 assertions and zero failures**. M7 remains **225 headless / 230 graphical**, M6 **124 / 130**, all passing. No gameplay or test change was needed. [This request's verification](milestone-7.md#repeated-request-verification) retains separate source hashes, commands, results and images; it does not close the earlier failed movement executions or reopen investigation. Only the handoff documentation was updated, and work stops at Milestone 7.
