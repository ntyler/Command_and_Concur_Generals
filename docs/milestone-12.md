# Milestone 12 — Bulldozers and builder-driven construction

Status: implementation integrated; final validation in progress. This report will be completed before handoff. Milestone 12 is the existing roadmap identifier. Power generation remains subsequent work and is not implemented.

## Playable scene and controls

[Builder Assault](../scenes/builder_assault.tscn) is the intended builder-based player experience. Open it in the installed Godot **4.7.2.stable.official.ed1daf0bf** and press F6, or run:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/builder_assault.tscn
```

The player starts with one HQ, one selected Bulldozer, three existing Rifle units, **1000 credits**, finite western supplies, no production buildings and no collectors. Enemy buildings, two enemy collectors, starting funds and repeat-wave behavior are inherited unchanged from Economy Assault. Stable starting enemy unit IDs remain 9 and 10; subsequent production begins above 10.

Select exactly one owned Bulldozer, choose **Build Supply Depot**, **Build Barracks** or **Build Vehicle Factory**, and left-click a valid preview. Right-click or Escape cancels the free preview, preserving the earlier order. An accepted placement replaces that order. Right-click ground or use **X Stop** to release the builder and pause the paid site. Right-click an owned unclaimed unfinished site with one selected Bulldozer to resume. Select the site and use **Cancel construction** to remove it and refund its original payment once. Select HQ to train another Bulldozer, or a completed Depot to train a Collector. Select a Collector and right-click supplies to harvest. Combat right-click and Q Attack Move, minimap commands, groups 1–9 and Help remain available.

The funded opening is **Depot 300 + Collector 200 = 500 credits**, leaving 500 of the unchanged initial 1000. The normal gameplay sequence is builder → Depot → paid Collector → real harvesting → Barracks/Factory → paid army → combat. HQ drop-off compatibility remains.

## Configuration and construction authority

| Setting | Default |
| --- | --- |
| Bulldozer production | 500 credits / 6 simulated seconds / existing five-slot queue |
| Bulldozer health / speed | 200 HP / 3.5 units per second |
| Bulldozer collision and recovery | Inherited RTSUnit capsule, crowd settings and bounded recovery |
| Work position / arrival tolerance | 1.3 units outside the footprint face / 0.3 units |
| Supply Depot | Existing 300 credits / 10 working seconds / 450 completed HP |
| Barracks | Existing 400 credits / 10 working seconds / 450 completed HP |
| Vehicle Factory | Existing 600 credits / 15 working seconds / 450 completed HP |
| Collector | Existing 200 credits / 6 simulated seconds; harvesting defaults unchanged |
| Unfinished-site limit | Existing one-site limit, including paused sites and pending cleanup |

The original primitive Bulldozer is an ordinary registered, selectable, damageable RTSUnit subclass. It has no weapon, retaliation, harvesting, cargo or Attack Move coordinator. HQ production uses UnitProduction payment, FIFO queue, cancellation, safe capsule spawn and ground rally. Produced builders start with no assignment. No movement/projection/recovery algorithm or existing unit default is changed.

`builder_construction_enabled` opts the new scene into builder authority. `BuildingConstruction` still owns authoritative validation, exact payment, stable site identity, original paid cost, construction duration and serialized navigation updates. UI selection only authorizes new placement/resume commands; ongoing construction checks live field/owner/registration and assignment state independently of UI selection. One site has one weak builder reference and one builder holds one site ID.

Placement preserves full footprint, ground, occupied-unit, access-corridor and exit checks. It additionally plans from eight bounded positions outside the footprint using ordinary navigable paths, capsule clearance and an unobstructed segment to the outside face. After committing geometry, the final approach is planned and dispatched once after navigation readiness. Travel uses the unchanged movement deadline and retry budget. A failed or newly obstructed approach releases the assignment and leaves a paid paused site; no automatic retry order resets recovery.

States are **Preparing site**, **Builder travelling**, **Constructing**, **Paused — needs builder** (with failure details where applicable), and **Complete**. Only an alive registered same-owner builder at its valid work point, with the captured movement order and clear actual capsule/interaction segment, advances time in the active match. Travelling, stopped, obstructed, missing and out-of-position builders earn no progress. Selecting another object does not pause an otherwise valid worker.

Move, Stop, death, immediate/deferred removal, ownership invalidation and departure release work without resetting progress or refunding the building. Same-field builder reparenting keeps its ordinary stable identity/registration, but its departure releases construction; select it and resume explicitly. Building same-field reparenting retains the existing site identity. No completed-building repair, selling or HQ reconstruction is added. Unfinished sites retain their previous invulnerability/refund policy; completed buildings retain normal assault damageability.

Completion first commits operational state and clears the unfinished slot, then releases the builder. Cancellation first commits cancellation/refund and removes collision/registration, then stops obsolete work and restores navigation. Claim references and IDs are cleared before notification callbacks; approach generations and captured order versions protect replacement commands. Match freeze clears builder claims and stops time. Restart closes old site/navigation managers, queues, weak references and listeners and reloads this scene.

Earlier construction, base-assault, combined-arms, economy and supply-depot scenes retain explicit **legacy prototype HQ-based automatic construction and HQ deposits**. F5 still launches the original main scene. No enemy builder strategy, power, defenses, new combat units, aircraft, walls or superweapons are included.

## Acceptance

| Requested group | Result |
| --- | --- |
| 1. HQ builder production and capability separation | Pending final validation |
| 2. Builder-selected placement and exact payment | Pending final validation |
| 3. Travel-gated construction progress | Pending final validation |
| 4. Pause, reassignment and preserved progress | Pending final validation |
| 5. Completion, cancellation and lifecycle safety | Pending final validation |
| 6. Real builder-to-depot-to-economy-to-army gameplay | Pending final validation |
| 7. Legacy scenes and existing interface | Pending final validation |
| 8. Accurate validation and failure reporting | Pending final validation |

## Validation and preserved failures

The lead agent owns final integration and all Godot runs. Tests use the existing fresh-copy/source-hashing runner, fixed 60 simulated FPS and external 240-second timeout. Headless and graphical runs are serialized. Automated input/capture inspection is not human playtesting; **no human playtest occurred**.

- `m12-import-smoke-01`: fresh import passed, but construction execution exposed a newly introduced eager-resource/script cycle (187 checks, one failed logger assertion, 99 native error lines, exit 1). Changed the default Barracks resource initialization from eager preload to runtime load; no resource values changed.
- `m12-import-smoke-02`: fresh import and all **267 headless construction checks pass**, no native errors, exit 0.
- `m12-focused-01`: fresh import passed, but new focused harness failed to parse two impossible sibling-class type checks (zero checks, three native error lines, exit 1). Failure retained; harness correction pending the next focused phase.

All phase logs, commands, source hashes and results are retained under [validation-output/m8](../validation-output/m8). Full matrix and final source/documentation checks will be recorded here.

The [M11 report](milestone-11.md) remains the source-matched baseline, including its retained unknown-attribution projection-fixture failure. The [deferred movement records](movement-issue-records.md) remain unresolved; feature completion does not close them or establish universal crowd reachability. No engine upgrade, dependency install, commit, tag, discarded work, movement investigation or historical validation replay occurred.
