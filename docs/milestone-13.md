# Milestone 13 — Power Plants and power management

Implementation and validation are in progress. Final acceptance and exact run results will replace this checkpoint before handoff.

## Playable extension

Open [Power Assault](../scenes/power_assault.tscn) in the installed Godot 4.7.2 and press **F6**, or run from the repository root:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/power_assault.tscn
```

The player starts with the existing HQ, selected Bulldozer, three Rifles and 1000 credits, without a Power Plant, collectors or production buildings. Build a Supply Depot for 300 credits, produce a Collector for 200, and harvest through the existing loading, travel and deposit systems. A Barracks or Factory may be built before a plant; there is no power prerequisite. F5 and all earlier scenes keep their previous entry points and opt out of power penalties.

Select exactly one owned Bulldozer and choose **Build Power Plant**. Left-click valid ground to pay and assign construction. The free preview, travel and unfinished site generate nothing. X Stop or a ground Move pauses work; select a builder and right-click the owned unclaimed unfinished site to resume. Selecting the unfinished site exposes normal full-price cancellation. One unfinished site remains the limit. A completed plant cannot be cancelled, sold or refunded.

## Configuration and behavior

| Building | Construction cost / working time | Generated | Required |
| --- | --- | --- | --- |
| Power Plant | 500 credits / 10 simulated seconds | 10 | 0 |
| Barracks | Unchanged: 400 credits / 10 seconds | 0 | 2 |
| Vehicle Factory | Unchanged: 600 credits / 15 seconds | 0 | 4 |
| HQ | Unchanged | 0 | 0 |
| Supply Depot | Unchanged: 300 credits / 10 seconds | 0 | 0 |

Nominal power lives in the configurable [construction definitions](../scripts/construction_definition.gd) and their resources, including [Power Plant](../construction/power_plant.tres). Runtime totals are separate. Units consume no power. Plants use a 6×5 committed footprint, a distinct original twin-transformer primitive, and the ordinary navigation/weapon blocker. Completed plants inherit **450 HP** from the existing non-HQ assault-building convention. Partial damage does not reduce output. Unfinished sites retain the existing immunity and cancellation policy. Plants have no unit recipe/queue and are not victory objectives.

Generation greater than or equal to required power is **NORMAL**, including 0/0. Below demand is **LOW POWER**: every operational owned Barracks and Factory earns **50%** of normal training progress. Idle and blocked-complete producers still contribute full nominal demand. There are no priorities, partial allocation, power lines, stored energy, switches or upkeep.

The enemy retains its HQ, barracks, two collectors, separate 300-credit wallet, finite supplies and existing wave configuration. One explicit completed enemy plant occupies `Rect2(23, -6, 6, 5)`, centered at `(26, 0, -3.5)`. Its ordinary registration supplies 10 power against the enemy barracks' demand of 2. Destroying it slows the same paid enemy Rifle queue. No hidden generation or AI construction/rebuilding is added; wave timers are unchanged.

## Accounting, notifications and time boundary

[PowerGrid](../scripts/power_grid.gd) belongs to one field and derives coherent owner totals from that field's existing weak building registry. Eligibility requires current field membership/ancestry, operational completion, liveness, an unqueued building and unqueued ancestors. Duplicate registration is identity-based; removal cannot subtract twice or make negative totals. Every read rechecks eligibility, including supported internal ownership changes. No scene-tree scan, global account or save persistence is added.

Ownership/operational setters and registration/departure schedule refresh after existing lifecycle commits. The powered field also refreshes its registry at the start of its physics processing. Builder completion refreshes after the site, unfinished slot and builder release commit. Snapshots reconcile before returning; queued deletion is excluded immediately on read. All owner totals commit before the parameterless change notification. Listeners read current state; nested changes are committed and notified without replaying an older snapshot, including deletion by the last listener. Identical state produces no repeated notification. Same-field reparenting retains ordinary building/site identity and queues. Actual departure removes eligibility; supported re-entry restores eligible membership under the existing registration rules.

Each active [production job](../scripts/unit_production.gd) reads the current owner snapshot **immediately before its physics progress increment**. Construction runs at priority −100 before ordinary producers, so a completed plant applies to their later increments that tick. A death occurring after a producer's increment affects its next increment. If a synchronous rate-read listener changes the producer's owner, that increment is skipped and the next physics advance reads the new owner. Listener cancellation, producer loss, field removal or result freeze is checked again before progress.

The multiplier scales only accumulated training progress. Nominal recipe duration, payment, identity, queue order and existing progress remain intact. A completed job stays at 100%; its 0.25-second spawn-clearance retry uses unscaled simulated time. Normal cost/refund and exactly-once deployment commits remain authoritative. HQ Bulldozers, Depot Collectors, construction, harvesting, movement, combat and projectiles use their existing timing.

Result freeze continues to close gameplay admission and stop construction/production. Power notifications cannot enable gameplay. Teardown clears the old grid's totals and listeners; Restart creates a fresh field, restoring actual starting buildings and the local 0/0 NORMAL display. Retained old managers cannot contribute to the new scene.

## HUD

Credits remain separate from the local player's generated/required power display. A written LOW POWER warning explains the Barracks/Factory 50% rate. Selected plants show health and current generation; unfinished plants also retain construction/paused status. Selected consumers show nominal demand and current rate alongside unchanged queue, progress, Cancel and blocked-exit feedback. Recipe time is labelled as base time. The minimap adds **P** through the ordinary building registry. The ordinary panel does not reveal enemy wallets or a detailed enemy power budget.

## Acceptance and validation

Pending final focused and regression results.

## Preserved limitations

The [M12 acceptance with interface exception](milestone-12.md) remains unchanged: the historical group-3 occurrence is open, cause unknown, and M12 criterion 7 NOT VERIFIED. Current tests do not reconstruct or close that occurrence. [Movement findings](movement-issue-records.md) remain separately deferred and unresolved. No historical investigation or recorder campaign is part of this work. No human keyboard-and-mouse playtest has occurred; viewport automation and image inspection are reported as such.
