# Milestone 15 — Airfield, Attack Helicopter and Air Defense

**Milestone 15: COMPLETE (2026-09-09).** All eight original acceptance groups PASS. The existing final matrix completed **92/92 executions, 11,756 checks, zero failures/native error lines, exit 0**, including all ten air executions and the fresh-copy earned integration in both modes. No required M15 feature remains outstanding. Historical interface and movement findings remain separately open. No human keyboard-and-mouse playtest occurred.

## Play and configuration

Open [Air Assault](../scenes/air_assault.tscn) in the installed Godot 4.7.2 and press **F6**, or run from the repository root:

```powershell
$godot = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/air_assault.tscn
```

The exact tested engine is `4.7.2.stable.official.ed1daf0bf`. F5 keeps the original main scene. The player begins with the inherited HQ, one Bulldozer, three Rifles, 1000 credits and finite supplies, with no prebuilt Airfield, generator or aircraft. Select the Bulldozer to construct a 300-credit Supply Depot; its 200-credit Collector earns the additional funds through ordinary loading and deposits. Build an Airfield and a Power Plant, select the Airfield and train an Attack Helicopter. Select aircraft by click/drag, right-click ground or the minimap to move, right-click eligible hostile ground actors to attack, use **Q** for Attack Move and **X** to Stop. Existing **Ctrl+1–9**, recall and double-tap centering apply. **F1** opens Help. Destroy the hostile HQ while protecting yours; Restart reloads this scene.

| Setting | Airfield | Attack Helicopter | Air Defense Battery |
| --- | --- | --- | --- |
| Cost | 1000 credits | 600 credits | 800 credits |
| Construction/training time | 15 builder work seconds | 10 training seconds | 12 builder work seconds |
| Health | 450, existing completed-producer default | 180 | 600 |
| Power | 3 nominal demand | none | 3 nominal demand |
| Production | Existing five-job FIFO; helicopters only | — | none |
| Movement | Stationary 6×5 footprint | 8 units/s horizontal; 4 units/s vertical; 8-unit cruise altitude; 0.5-radius body | Stationary 6×5 footprint |
| Weapon | none | Ground-only guided rocket: 24 damage, 12-unit 3D range, 1.5-second cooldown | Air-only hitscan: 30 damage, 16-unit 3D range, 1-second cooldown |
| Aim | — | 3 rad/s yaw; 8° horizontal tolerance | 3 rad/s yaw/pitch; 8° tolerance; 0.25-second scan |

The helicopter rocket retains speed 12, lifetime 6 seconds and spherical world-collision radius 0.1. Definitions are in [Airfield](../construction/airfield.tres), [AA](../construction/air_defense_battery.tres), [helicopter production](../production/attack_helicopter.tres), [helicopter weapon](../weapons/helicopter_rocket.tres) and [AA weapon](../weapons/air_defense.tres). Runtime jobs, cooldowns and targets remain instance state.

Both buildings use ordinary paid Bulldozer placement, travel, work, pause/resume, cancellation and the single unfinished-site limit. Previews and unfinished sites have no operational demand, production or firing. Completed footprints obstruct ground navigation and weapons. Airfields train at 100% with adequate owner power and 50% at shortage, making an uninterrupted low-power helicopter take 20 seconds. The same owner grid controls AA; shortage prevents new shots and clears acquisition while cooldown continues without reset or catch-up shots. Already committed shots remain committed. Aircraft have no grid demand and fly at full speed during shortage.

The enemy retains its paid ground economy and **90-second earliest wave / 60-second interval**. One explicit preplaced AA at `Rect2(14, -1, 6, 5)` joins the existing ground battery and Barracks. The ordinary enemy plant supplies 10 against demand 8 (Barracks 2 + ground defense 3 + AA 3). One declared starting helicopter at `(25, 8, 15)` receives one scripted Attack Move toward the player HQ after 120 simulated seconds. This starting force is not a paid-production demonstration. No hidden funds, power, replacement aircraft or enemy air planner are added. Ground approaches to power remain available along the east/north.

## Flight, deployment and combat contract

The actual helicopter gameplay body is elevated, with a sphere at its root and matching picking/aim geometry. It moves above ground obstacles without using ground-navigation projection. Every movement is bounded by speed, map bounds and sphere world sweeps; initial overlaps and same-tick aircraft registry checks supplement the sweep. The supported flat datum is 0; the whole scenario cruise plane at y=8 clears static geometry by the actual body radius. A flight-height obstruction stops the body safely. This is direct flight with bounded local spacing, validated for three aircraft, not general aerial obstacle routing or a large-swarm guarantee.

Normal production captures one payment and waits at a blocked launch volume. Airfield height is 1.4; the default launch sphere center is y=2.08 above its pad. The initial sphere and full vertical climb volume must be clear. One registered owned aircraft is deployed per job. Weak field-local reservations cover takeoff, including same-tick launches, and clear on safe climb completion, aircraft departure/destruction or scene cleanup. The actual body climbs at 4 units/s before horizontal mission travel. It cannot fire while taking off. New orders replace pending intent; X removes pending travel/combat and completes the safe climb into hover. The current surviving Airfield rally applies at clearance unless superseded. Source destruction preserves the deployed aircraft and captured rally fallback; only undeployed jobs refund once.

Shared GROUND/AIR eligibility applies through explicit command acceptance, acquisition, retaliation, the final emitter boundary and projectile impact. Rifles/Rocket Vehicles remain ground-only; Ground Defense remains hostile ground-mobile-only. Helicopters attack eligible hostile ground units and damageable buildings. AA attacks hostile aircraft only, including aircraft taking off. Rejected targets preserve valid prior orders; malformed armed members still reject a batch atomically. CommandBatchResult records actual recipients, captured domain-specific assignments and supersession. Ground members retain normal navigable slots; aircraft receive distinct bounded flight slots.

Helicopter pursuit derives horizontal standoff from actual 3D range and fixed cruise altitude. It faces horizontally while its rocket aims downward. AA aims with yaw and pitch, remains stationary and rechecks power, ownership, lifetime, 3D range, facing and obstruction at commitment. Guided rockets keep captured ownership/eligibility, delayed damage, spherical collision, world obstruction, lifetime clipping and exactly-once terminal outcomes after source orders or deletion.

Match results freeze flight, takeoff, production, acquisition and attacks. Restart retires the old wallet/grid, targets, groups, projectiles, jobs, callbacks and launch claims, and resets the scripted sortie. The interface includes priced builder choices, helicopter queue/cancellation, taking-off/hover status, AA power/status, distinct aircraft/F/A minimap markers, compact Help and visible result/Restart controls. The Air Assault panel uses a small spacing adjustment to fit all five queued jobs above the minimap at 720p.

## Earned integration and fixture boundaries

The [earned suite](../tests/air_integration_checks.gd) starts with the original **1000 credits**, original builder and finite 2000-supply cache. It pays **Depot 300 + Collector 200 + Airfield 1000 + Power Plant 500 + Helicopter 600 = 2600**. Actual Collector loading/deposits supply the funds. The recorded headless development ledger is **1000 + 2000 deposited − 2600 spent = 400**, with 2000 loaded, zero cargo and zero remaining cache supply. Every transfer checks ownership and conservation; the final ledger is saved as JSON by the suite.

The paid aircraft physically climbs, flies into actual range, fires a guided rocket and damages the real hostile ground-defense building for 24. The same aircraft flies into enemy AA range and is killed by ordinary 30-damage hitscan. An original Rifle then uses normal ground movement around the eastern approach and fires at the hostile power plant. Enemy paid ground production/harvesting and both defenses remain live. No free player aircraft, cargo assignment, forced damage, forced construction progress or gameplay-value tuning proves these integration claims.

The earned fixture explicitly duplicates only the scene instance's enemy configuration to delay the first ground wave and starting air sortie to **600 seconds**, allowing observation of the economic sequence. Shared resources and the normal scene retain 90/120 seconds. Isolated flight/combat/production/UI tests separately declare free starting actors, extra starting funds, paused enemies, completed power bodies or direct lifecycle/result triggers. Those fixtures do not certify earned purchases. Automated viewport input and rendered inspection do not constitute human playtesting.

## Recovery, retained failures and corrections

The interrupted work began at clean commit `18938abfd33c82aaac80395ea40753281201c1c6`. No applicable AGENTS.md existed in the workspace or ancestors. The [saved baseline audit](../validation-output/m15/baseline-audit.json) matches original gameplay to M14's snapshot; only its handoff documents differ. M14's matrix remains **81/82 passing, 10,751 checks, five graphical movement-stress failures, exit 1**. It is baseline evidence, not a clean matrix or new air coverage.

Recovery checked OS processes and the previous task and all three workers. Flight, combat and buildings workers had all completed and were idle; no engine process remained. Their [flight notes](../validation-output/m15/flight-notes.md) and [building notes](../validation-output/m15/buildings-notes.md) were collected before new snapshots. No new workers, review wave or movement investigation were launched. [Recovery checkpoints](../validation-output/m15/recovery-checkpoint.txt) preserve progress.

| Retained failure | Supported classification and correction |
| --- | --- |
| `m15-smoke-01`, `m15-smoke-02` imports | UI source encoding/line-break parse failures and dependent compile errors. Saved UTF-8/line corrections were already present on recovery; later fresh imports pass. Both original imports and snapshots remain. |
| `m15-smoke-03` air combat: 84 checks, one failed native-error assertion | **Fixture lifetime error.** Original `_air_counter` lambda captured a target deleted by actual AA damage. Engine log: `Lambda capture at index 0 was freed. Passed "null" instead.` Stack points to `_until` in harvesting_checks.gd:77, then `_frames` in milestone_checks.gd:277. Saved correction captures a WeakRef and queries it, preserving the kill assertion. `m15-affected-dev-01` air combat then passed 85 checks without errors. |
| `m15-affected-dev-01` ground combat: 183 checks, two failures | **Demonstrated new regression.** Domain-filtered mixed attack dispatch accidentally allowed a valid member to attack when another selected weapon was malformed. Restore pre-dispatch malformed-weapon atomic rejection while keeping per-domain filtering. Existing `combat_checks` assertion remains unchanged and passes after correction. Second failed assertion was the logger reporting that first failure. |
| `m15-recovery-core-01` production/integration parse failures | **Fixture typing errors.** Explicit WeakRef declarations replace inferred Variant at original production line 121 and integration line 99. No gameplay change. |
| `m15-recovery-economy-02` production speed assertions; `m15-production-timing-diagnostic-01` | **Fixture sampling error.** Sampling from the pre-update physics signal to a post-update process frame included an extra step: 1.06666565 climb units / 15 counter increments and 8.13333702 cruise units / 60. Align both endpoints after physics. Measured results become 0.99999905 / 15 and 8.00000286 / 60, with unchanged 4/8 speeds and unchanged bounds assertions. |
| `m15-recovery-features-03` full-queue UI at 720p | **Demonstrated new UI regression.** The five-job panel ended at y=425 and the minimap began at y=422.08, failing collapsed and expanded Help layouts. Reduce only Air Assault column spacing from 5 to 3; preserve fonts, full queue and existing layout assertions. |

All failed runs, source copies and stdout/stderr remain under `validation-output/m8/m15-*`. Gameplay assertions passing never override native errors. The integration damage listener now captures stable source identity rather than a soon-deleted helicopter object. Production adds an explicit paid takeoff-death reservation check; UI adds 1080p result capture.

## Validation and acceptance

The saved [process outcome](../validation-output/m15/matrix-process-outcome.json) records completion at **2026-09-09T19:45:23.5117805Z**, exit **0**. Its earlier `recovered_state: running` describes the observation before completion; the final `state` is `completed`. The [runner summary](../validation-output/m8/m15-final-matrix-01/summary.json) independently confirms all 92 planned tests finished. The response-stream disconnect was not a validation result. No process was identified by a reused PID, no duplicate test or waiting loop was started, and no reviewer was launched during this closeout.

The existing invocation was:

```powershell
& .\tools\validate-m15.ps1 -RunName m15-final-matrix-01 -TimeoutSeconds 240
```

The [plan](../validation-output/m8/m15-final-matrix-01/plan.json) records the exact installed engine, PowerShell executable, 240-second external deadline for each execution, all arguments and fresh project path `validation-output/m8/m15-final-matrix-01/project`. The [results](../validation-output/m8/m15-final-matrix-01/results.json) preserve each command, wrapper call, elapsed time, checks and exit. Every one of the **93 execution records** (fresh import plus 92 tests) has exit 0, its `.ps1`, combined `.log`, `.stdout.log` and `.stderr.log`; all stderr files are empty. Import has no assertion count and is excluded from test totals. The runner reports 1087.795 seconds across executions.

| Final matrix subset | Executions passed/completed/planned | Checks | Failures / native error lines | Exit |
| --- | --- | --- | --- | --- |
| Headless tests | 46 / 46 / 46 | 5,795 | 0 / 0 | All 0 |
| Graphical tests | 46 / 46 / 46 | 5,961 | 0 / 0 | All 0 |
| Full matrix | 92 / 92 / 92 | 11,756 | 0 / 0 | Aggregate 0 |

| Air suite within the matrix | Headless checks | Graphical checks | Outcome |
| --- | --- | --- | --- |
| Flight | 52 | 55 | PASS, both exit 0 |
| Combat | 85 | 85 | PASS, both exit 0 |
| Production | 96 | 96 | PASS, both exit 0 |
| Earned integration | 54 | 56 | PASS, both exit 0 |
| Interface | 200 | 226 | PASS, both exit 0 |
| Air subtotal, ten executions | 487 | 518 | 1,005 passing checks already included above |

Both final [headless ledger](../validation-output/m8/m15-final-matrix-01/artifacts/headless-air_integration_checks/m15/earned-ledger.json) and [graphical ledger](../validation-output/m8/m15-final-matrix-01/artifacts/graphical-air_integration_checks/m15/earned-ledger.json) reconcile **1000 + 2000 deposited − 2600 spent = 400** with correct ownership and conservation. The [headless integration wrapper log](../validation-output/m8/m15-final-matrix-01/headless-air_integration_checks.stdout.log) records 54 passing checks; the [graphical integration wrapper log](../validation-output/m8/m15-final-matrix-01/graphical-air_integration_checks.stdout.log) records 56. Fresh-copy import and both earned runs are complete, not inferred from development tests.

### Original acceptance statuses

| # | Original requirement | Status | Saved final evidence |
| --- | --- | --- | --- |
| 1 | Builder-created Airfield and paid helicopter production | PASS | Air production and earned integration: ordinary builder work, payment, FIFO, cancellation and real deployment. |
| 2 | Real takeoff, bounded flight, and safe deployment | PASS | Flight and production: elevated gameplay body, real climb, obstacle traversal, speed/bounds, blocked volume, launch claims and exactly-once deployment. |
| 3 | Ground/air targeting separation | PASS | Air combat plus existing combat/defense/attack-move suites: explicit commands, acquisition, emitter and impact eligibility; malformed-weapon atomic rejection remains intact. |
| 4 | Helicopter combat and powered AA counter | PASS | Real delayed rocket damage, obstruction, powered AA aim/hits, shortage and cooldown restoration; earned aircraft damages ground battery and dies to AA. |
| 5 | Power, destruction, callbacks, freeze, and Restart | PASS | Production/combat/UI and inherited lifecycle suites: source/target deletion, takeoff death, stale claims, owner grids, frozen results and viewport Restart. |
| 6 | Mixed commands, groups, minimap, and readable interface | PASS | Air UI, flight, Attack Move UI, tactical interface and groups; domain-specific slots and prior source-matched visual inspections at both required sizes. The original M12 occurrence remains separately excepted. |
| 7 | Real economic and combat integration | PASS | Both final earned runs, conserved 400-credit ledgers, paid aircraft rocket damage/AA death and ordinary Rifle movement/fire against enemy power. |
| 8 | Preserved earlier systems and accurate validation reporting | PASS | All 92 final executions pass, including earlier regression suites; exact source correspondence, retained failures, current captures and saved documentation checks. No historical finding is closed by this matrix. |

### Preserved execution inventory

All 11 phase directories remain under `validation-output/m8/`; none was overwritten. Each phase retains its plan, source hashes/copy, results, summary and wrapper logs. Earlier counts are provenance and are **not added to the final 11,756**.

| Phase | Tests passed/completed/planned | Checks / failures | Preserved failed executions |
| --- | --- | --- | --- |
| `m15-smoke-01` | 0 / 0 / 2 | No test summary | `import`: engine exit 0 but 16 native error lines; runner rejects import and does not start tests. |
| `m15-smoke-02` | 0 / 0 / 2 | No test summary | `import`: engine exit 0 but 20 native error lines; runner rejects import and does not start tests. |
| `m15-smoke-03` | 2 / 3 / 3 | 285 / 1 | `headless-air_combat_checks`: 84 checks, one failure/native error line, exit 1. |
| `m15-visual-dev-01` | 2 / 2 / 2 | 225 / 0 | None; early visual evidence predates final corrections. |
| `m15-affected-dev-01` | 12 / 13 / 13 | 2,035 / 2 | `headless-combat_checks`: 183 checks, two failures/native error lines, exit 1. |
| `m15-recovery-core-01` | 3 / 5 / 5 | 423 / 0 | `headless-air_production_checks` and `headless-air_integration_checks`: parse failures, no test summary, both exit 1; four native error lines total. |
| `m15-recovery-economy-02` | 1 / 2 / 2 | 146 / 2 | `headless-air_production_checks`: 92 checks, two failures, exit 1. |
| `m15-production-timing-diagnostic-01` | 0 / 1 / 1 | 92 / 2 | `headless-air_production_checks`: unchanged timing failures, exit 1. |
| `m15-recovery-features-03` | 10 / 12 / 12 | 1,379 / 4 | `headless-air_ui_checks` (200 checks) and `graphical-air_ui_checks` (226): two layout failures each, both exit 1. |
| `m15-recovery-ui-04` | 2 / 2 / 2 | 426 / 0 | None; corrected interface and inspected captures match final tested source. |
| `m15-final-matrix-01` | 92 / 92 / 92 | 11,756 / 0 | None; fresh import also passes. |

The supported explanations and corrections are recorded above. The two demonstrated new regressions were malformed-weapon batch acceptance and the 720p full-queue overlap; both have final-source passing coverage. There is no outstanding M15 feature failure or unknown-attribution failure in the final matrix. Earlier native-error and parse failures remain failed even when their engine exit or assertion count alone looked successful.

### Tested-source correspondence and reused evidence

Before closeout documentation edits, all **354/354 current files** matched the final [SHA-256 manifest](../validation-output/m8/m15-final-matrix-01/source-hashes.json), with no missing or added source files. The final runner also recorded zero source differences after execution. The `m15-recovery-ui-04` manifest is identical to the final matrix manifest, so its already-inspected corrected captures remain current. Earlier visual-development captures predate the fixes and are retained as development history rather than used to certify the final layout.

Only `README.md`, `docs/roadmap.md` and this report changed during closeout. Runtime, resources, scenes, tests and tools remain exactly as tested. The [final handoff check record](../validation-output/m15/final-handoff-checks.json) records current hashes, differences for every retained phase, snapshot integrity, screenshot dimensions/hashes, documentation links/anchors and `git diff --check`. The supplemental [documentation whitespace record](../validation-output/m15/documentation-whitespace-checks.json) includes this untracked report, which ordinary `git diff --check` alone does not cover. These static checks pass; only the three handoff documents differ from the final matrix snapshot. Saved source copies were not modified.

This closeout reused the completed matrix, earned ledgers and prior visual observations. It ran no engine tests, screenshot reviews or post-matrix affected reruns. The earlier focused results corroborate corrections but are not extra unique coverage beyond the matrix. The baseline commit remains `18938abfd33c82aaac80395ea40753281201c1c6`; implementation and documentation remain uncommitted.

### Screenshots and visual handoff

The following **ten already-inspected current-source captures** are reused. Paths point to the exact observed artifacts, not substituted captures from a later execution. Recovery UI 04 and the final matrix have identical source manifests.

| Prior inspected capture | Resolution | Handoff coverage |
| --- | --- | --- |
| [Corrected full production queue and Help](../validation-output/m8/m15-recovery-ui-04/artifacts/graphical-air_ui_checks/m15/screenshots/air_paid_production_help_1280x720.png) | 1280×720 | All five paid jobs fit above minimap; Help and controls remain readable. |
| [Selected AA and Help](../validation-output/m8/m15-recovery-ui-04/artifacts/graphical-air_ui_checks/m15/screenshots/air_paid_selected_aa_help_1280x720.png) | 1280×720 | AA status/power and contextual controls. |
| [Recovery result](../validation-output/m8/m15-recovery-ui-04/artifacts/graphical-air_ui_checks/m15/screenshots/air_result_1920x1080.png) | 1920×1080 | Visible result and Restart. |
| [Normal builder and Help](../validation-output/m8/m15-recovery-ui-04/artifacts/graphical-air_ui_checks/m15/screenshots/air_normal_builder_help_1920x1080.png) | 1920×1080 | Normal opening, priced construction choices and expanded Help. |
| [Selected helicopter](../validation-output/m8/m15-recovery-ui-04/artifacts/graphical-air_ui_checks/m15/screenshots/air_paid_selected_helicopter_1280x720.png) | 1280×720 | Selection feedback, aircraft status and minimap clarity. |
| [Selected AA](../validation-output/m8/m15-recovery-ui-04/artifacts/graphical-air_ui_checks/m15/screenshots/air_paid_selected_aa_1920x1080.png) | 1920×1080 | AA marker/status and larger layout. |
| [Final normal builder, 720p](../validation-output/m8/m15-final-matrix-01/artifacts/graphical-air_ui_checks/m15/screenshots/air_normal_builder_1280x720.png) | 1280×720 | Normal scene configuration and collapsed Help layout. |
| [Final normal builder, 1080p](../validation-output/m8/m15-final-matrix-01/artifacts/graphical-air_ui_checks/m15/screenshots/air_normal_builder_1920x1080.png) | 1920×1080 | Normal scene configuration and collapsed Help layout. |
| [Final result, 720p](../validation-output/m8/m15-final-matrix-01/artifacts/graphical-air_ui_checks/m15/screenshots/air_result_1280x720.png) | 1280×720 | Result and accessible Restart. |
| [Final result, 1080p](../validation-output/m8/m15-final-matrix-01/artifacts/graphical-air_ui_checks/m15/screenshots/air_result_1920x1080.png) | 1920×1080 | Result and accessible Restart. |

The final UI artifact directory `validation-output/m8/m15-final-matrix-01/artifacts/graphical-air_ui_checks/m15/screenshots/` retains **26 UI-authored captures**: normal builder, placement preview, paid production, selected helicopter, selected AA and normal Restart, each at 1280×720 and 1920×1080 with Help collapsed/expanded, plus results at both sizes. Its additional `air_earned_ground_power_attack_1280x720.png` is a copied integration artifact, not another UI test or independent visual review. The capture inventory in the final static record includes all 27 files and their dimensions. Automated UI checks verify picking, mixed controls, groups, minimap markers, full-queue bounds, viewport Restart and restored normal opening; rendered captures do not certify the earned ledger or human playtesting.

Earned graphical evidence separately includes [real rocket ground damage](../validation-output/m8/m15-final-matrix-01/artifacts/graphical-air_integration_checks/m15/screenshots/air_earned_ground_damage_1280x720.png) and [ordinary ground power attack](../validation-output/m8/m15-final-matrix-01/artifacts/graphical-air_integration_checks/m15/screenshots/air_earned_ground_power_attack_1280x720.png), both 1280×720. Their saved integration assertions and ledgers establish the gameplay claims; no new screenshot inspection was needed at closeout.

### Historical exceptions and deferred findings

**Accepted historical interface exception:** the [original M12 group-3 occurrence](milestone-12.md#owner-authorized-interface-exception--2026-09-09) remains **OPEN / UNKNOWN**, with its criterion 7 **NOT VERIFIED**. Current mixed commands, Attack Move UI and control groups pass, but do not reconstruct or repair that occurrence.

**Deferred movement findings:** [movement issue records](movement-issue-records.md) remain **UNRESOLVED**. M14's graphical unit-7 stress execution, earlier failed movement runs and their unknown attribution are preserved. This matrix's passing movement checks do not close those failures or establish full historical movement acceptance. Neither historical investigation was reopened.

## Important files and limitations

- [Flight body](../scripts/attack_helicopter.gd), [helicopter scene](../scenes/attack_helicopter.tscn), [Air Assault field](../scripts/air_assault_field.gd) and [scene](../scenes/air_assault.tscn) add flight and the opt-in scenario. `scripts/rts_unit.gd` ground locomotion is unchanged.
- Existing construction manager/field/definitions, placement and RTSBuilding append Airfield/AA kinds, real builder construction, footprints and completed defaults. Existing production field/definition/queue add sphere deployment, takeoff reservations, source-independent aircraft and rally supersession.
- TeamRules, combat/attack-move controllers, weapon definitions/emitter, GuidedProjectile, LineOfFire, feedback and GroundDefenseBattery enforce domains, flight pursuit and AA aim without a second combat system. Enemy economy excludes the declared aircraft from ground population/rally accounting.
- Existing TestField batch commands, construction/production panels, Help and minimap integrate selection, domain-specific slots, queue controls and markers.
- [Flight](../tests/air_flight_checks.gd), [production](../tests/air_production_checks.gd), [combat](../tests/air_combat_checks.gd), [UI](../tests/air_ui_checks.gd), [earned integration](../tests/air_integration_checks.gd) and [shared fixture](../tests/fixtures/air_harness.gd) use the existing test infrastructure. [M15 matrix](../tools/validate-m15.ps1) uses the existing fresh-copy [runner](../tools/validate-m8.ps1) and external [timeout wrapper](../tools/run-godot.ps1).

Landing, rearming, fuel, fixed-wing aircraft and air-to-air combat remain explicitly outside M15. There is also no runway/taxiing, return-to-base service, repairs, transports, ammunition limits, splash/crash damage, armor multipliers, enemy air production/rebuilding, fog of war, multiplayer or general strategic AI. Static flat flight clearance and a small aircraft population are supported; complex aerial routing/congestion is not promised. The original M12 group-3 interface exception stays OPEN / UNKNOWN and its historical criterion 7 NOT VERIFIED; passing present tests do not repair that occurrence. Deferred movement findings remain unresolved. No engine upgrades, dependency installs, commits, tags, discarded work, hardware-stat overlays, walls, gates or superweapons were added during this continuation.
