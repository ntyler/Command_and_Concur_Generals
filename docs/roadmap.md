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

The repository documents milestones through Milestone 5 and its corrective work. It defines no subsequent feature milestone. Milestone 6 below is a new recommendation, not a recovered prior commitment.

| Milestone | Feature / status |
| --- | --- |
| 1–1.5.1 | Camera, selection, group movement and crowd controls; validated repairs retained, movement limitations remain |
| 2–2.5.1 | Health, Rifle/Rocket combat, pursuit/retaliation, line of fire and spherical projectile collision |
| 3 | Fixed HQ/barracks, shared credits, Rifle queues and rally points |
| 4 | Finite supply harvesting, collector cargo and automatic deposits |
| 5 | Player-placed barracks, paid timed construction, cancellation and serialized navigation updates; feature implemented, full regression acceptance not passed |
| **6 — recommended next** | **Playable base assault: damageable HQs/completed barracks, an integrated economy-to-combat scenario, victory/defeat and restart** |

Milestone 6 gives construction, harvesting, production and combat a shared match objective. It uses a small flat map and existing units, resources and commands. Strategic AI, additional economic systems and general movement reliability work remain outside this milestone.

The focused handoff is [Milestone 6 implementation prompt](milestone-6-prompt.md). Its status is **PROPOSED / NOT IMPLEMENTED**; this priority update changes documentation only.

## Baseline and validation provenance

The working tree was clean at the start of this update, at commit `d5fc444`. Current `scripts/rts_unit.gd` SHA-256 is `2f46d67b3267ab233405457f8c84e83ebc46b8f461e75deef46ee5c3f33b34d0`, matching final source in the [latest gate repair report](milestone-5-gate-repair.md).

That report records a final 36-execution integration matrix with 4,740 assertions and zero failures, while preserving an earlier graphical unit-23 gate run with 39 checks and three failures on the repaired code. Historical unit 41 and original Issue B remain unresolved. These are prior results, not tests rerun for this documentation update, and do not establish full movement acceptance.
