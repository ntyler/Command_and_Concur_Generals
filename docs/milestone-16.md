# Milestone 16 — buildable walls, manual gates and basic breaching

Implementation and serial validation in progress. Final acceptance is recorded below before handoff. Historical interface and movement findings remain open.

## Play and configuration

Open [Fortified Assault](../scenes/fortified_assault.tscn) in the installed Godot 4.7.2 and press **F6**, or run:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/fortified_assault.tscn
```

The scene inherits Air Assault's original HQ, selected Bulldozer, three Rifles, 1000 credits, finite resources, paid enemy economy, defenses and declared starting helicopter. It has no free player perimeter. A short enemy demonstration line at z=18 has an initially open gate centered at (6,18), between two wall sections. The inherited ground wave/sortie timing remains 90/120 simulated seconds. Earlier scenes retain their values and the original F5 main scene.

| Structure | Credits | Working seconds | HP | Footprint | Height | Power |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
| Wall | 100 | 4 | 400 | 4 × 0.6 | 2 | 0 |
| Gate | 250 | 8 | 700 | 8 × 0.6, 6 clear opening | 2 | 0 |

Values are configurable in [Wall](../construction/wall.tres) and [Gate](../construction/gate.tres). Select one owned Bulldozer and choose Wall or Gate. Barriers alone snap their centers to a one-unit grid. **R** or the orientation button rotates between **0° and 90°**. Align collinear ends to connect walls and gate outer supports exactly; the entire gate span stays reserved even when open. A useful southern player line uses a gate at (-14,15), with walls centered at (-20,15) and (-8,15). Live units and protected access can temporarily prevent those placements.

The ordinary single unfinished-site limit, payment, physical builder travel/work, X/Move pause, right-click site resume, cancellation and original full refund remain. Rejected placement spends nothing and preserves the builder's prior order. Completed barriers cannot be refunded and are neither producers, weapons nor victory objectives.

Select an owned completed gate for **Open Gate** or **Close Gate**, current status and health. Gates complete closed and require no power. Open gates allow both teams through while supports remain solid and damageable. Closing checks all live ground units against doorway plus existing clearance both at request and final commitment. An occupied gate stays open and reports **Gate obstructed**, without displacement, damage or an automatic later close. Safely elevated aircraft do not prevent closure.

The minimap uses W for walls, C for closed gates, O for open gates and ~ during updates. Help documents R and manual gate operation. Existing Q Attack Move, X Stop, group shortcuts, economy and aircraft controls remain.

## Runtime contract

Barrier placement validates the full rotated footprint and preserves ordinary building, resource, live-unit and protected-access clearance. Only exact aligned end connections receive a scoped collision exclusion. Open gates still reserve their full span against new construction. Builder work uses the existing bounded exterior candidates, synchronized navigation and physical arrival requirements.

[BarrierBuilding](../scripts/barrier_building.gd) uses the existing building health/ownership/lifecycle authority and original primitive box geometry. One body retains support collision and picking when its doorway leaf opens. Requested state, physical state, pending navigation and effective readiness are distinct. The existing serialized construction-navigation coordinator witnesses the intended mesh and emits a guarded synchronization boundary before resuming movers. The gate commits its physical leaf there, or requests an open-map rollback if closure became occupied. Generation and membership guards reject obsolete work; previews never request navigation updates. Existing movement goals, deadlines and recovery budgets remain governed by the unchanged ground mover.

Hitscan and spherical guided projectiles use the existing firing/impact authority. Intended barrier contact can apply normal damage; intervening barriers retain world-obstruction behavior without penetration or collateral damage. Open gates aim at exposed support geometry. Aircraft retain AIR eligibility, actual 3D collision and cruise altitude. Destruction removes membership/collision immediately and serialized navigation produces the usable breach; no completed construction refund or invisible wreckage is created.

The new scene alone enables a bounded enemy breach extension. It retains the paid ground wave's HQ approach after initial move rejection, without reporting successful movement. At a configurable **0.5 simulated second** reassessment interval it checks real route availability and at most **eight distinct first obstruction candidates**. A hostile blocking barrier must have an eligible reachable exterior firing position. Owner-aware normal combat commands retain partial acceptance and supersession; no player selection is changed. Active targets remain stable, failed attempts do not indefinitely restart recovery, and surviving recipients resume the retained approach only after navigation is ready. No reachable candidate produces a clear waiting outcome. This supports a single blocking barrier, with no general multilayer siege planning.

Freeze stops new construction/gate/breach commands and builder progress. Already required navigation cleanup can finish under existing match policy. Restart reloads the scenario, retiring old wallets, sites, gate requests, navigation coordinators and wave objectives.

## Validation and acceptance

One lead performs serial engine validation through the existing fresh-copy [runner](../tools/validate-m8.ps1) and external [deadline wrapper](../tools/run-godot.ps1). [M16 matrix](../tools/validate-m16.ps1) extends the normal M15 matrix with the focused fortification suites. Source snapshots, logs, execution results and all failures are retained under `validation-output/m8/m16-*`; progress records live in `validation-output/m16/`.

The valid source-matched [M15 baseline](milestone-15.md) is reused: **92 executions and 11,756 checks include its 1,005 air checks already**. They are not added again as separate baseline coverage. M16 results will be reported independently.

| # | Requirement | Status |
| --- | --- | --- |
| 1 | Builder-built walls/gates with valid connections | NOT VERIFIED — validation pending |
| 2 | Safe owner-controlled gate operation | NOT VERIFIED — validation pending |
| 3 | Correct collision and synchronized ground navigation | NOT VERIFIED — validation pending |
| 4 | Damage, world blocking and usable destruction breaches | NOT VERIFIED — validation pending |
| 5 | Bounded enemy single-barrier breach and resumed attack | NOT VERIFIED — validation pending |
| 6 | Lifecycle, match freeze and Restart | NOT VERIFIED — validation pending |
| 7 | Preserved economy, air/ground gameplay and readable HUD | NOT VERIFIED — validation pending |
| 8 | Accurate focused and regression validation | NOT VERIFIED — validation pending |

## Retained findings and limits

The [M12 interface exception](milestone-12.md#owner-authorized-interface-exception--2026-09-09) stays **OPEN / UNKNOWN**, with historical criterion 7 **NOT VERIFIED**. [Deferred movement findings](movement-issue-records.md) remain unresolved. Current passing observations do not repair or close either historical record; their investigations are not reopened.

Single-piece placement, one unfinished site, manual gates, both-owner passage when open, no completed selling/refunds or repairs, and no general multilayer siege planner are deliberate limits. There are no wall chains, automatic perimeters/gates, upgrades, firing platforms, new units, superweapons or engine/dependency changes. No human keyboard-and-mouse playtest is claimed. Work remains uncommitted and untagged.
