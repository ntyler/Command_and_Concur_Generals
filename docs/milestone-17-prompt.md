# IMPLEMENT MILESTONE 17 — BUILDABLE SUPERWEAPON FACILITY

Work in:
D:\GitHub\Command_and_Concur_Generals

This document is the complete Milestone 17 implementation specification. It authorizes the scope below; no additional roadmap specification or attachment is required.

First save this specification as `docs/milestone-17-prompt.md` and identify Milestone 17 in the roadmap. Then implement it. Do not stop after saving the specification, preparing a plan, or repeating the baseline.

The facility is named **Tempest Array** for this prototype.

## 1. Starting state and development policy

Read applicable AGENTS.md files, README.md, the roadmap, the M16 report, existing issue records, and `docs/superweapon-facility-baseline.md`.

Inspect the current builder, construction, power, health/damage, target registration, HUD/minimap input, and match-result/Restart systems. Inspect git status and preserve unrelated changes.

The reported baseline already includes a clean fresh-copy import, 271 construction checks, and 314 builder checks. Reuse these 585 checks where their source and dependencies still match. They are baseline evidence, not superweapon acceptance.

M16 is accepted for continued development. Its group-7 verification gap and unknown movement attribution remain unchanged. Preserve historical failures and preview reruns separately.

Do not reopen historical movement/interface investigations, weaken assertions, or automatically classify new failures as pre-existing.

Do not upgrade the engine, install dependencies, commit, tag, reset the repository, or discard work unless separately instructed.

Use one lead agent for final integration and serial validation. Ordinary implementation and harness corrections within this specification are authorized. Do not stop merely to request permission for the next local edit/test step.

## 2. Exact prototype values

| Setting                  |                                                              Value |
| ------------------------ | -----------------------------------------------------------------: |
| Construction cost        |                                              5,000 integer credits |
| Construction duration    |                         45 simulated seconds of valid builder work |
| Maximum health           |                                                              1,200 |
| Operational power demand |                                                                  8 |
| Power generation         |                                                                  0 |
| Charge/recharge duration |                          180 accumulated powered simulated seconds |
| Launch-to-impact warning |                                                6 simulated seconds |
| Blast radius             |                                        10 world units horizontally |
| Damage                   |                         1,000 per eligible ground target at impact |
| Facility limit           | One unfinished or completed facility per owner in the active field |
| Launch cost              |                   No additional credits; consumes the ready charge |

Construction requires a living, completed, registered, owned **Vehicle Factory OR Airfield**.

Check the prerequisite when accepting construction. Losing the prerequisite afterward does not cancel an accepted site or disable a completed facility. Power is still required independently.

These are this project's prototype rules, not an exact reproduction of another game's balance. Preserve existing building, unit, weapon, economy, and power values.

## 3. Included and excluded behavior

Implement:

* Paid Bulldozer construction.
* Per-owner facility limits and normal destruction.
* Power-dependent charging.
* Manual battlefield/minimap ground targeting.
* A visible six-second warning.
* One instantaneous area-damage event at the fixed target position.
* Recharge, counterplay, result handling, and Restart.

Do not add a Technology Center, research tree, multiple superweapon types, enemy superweapon AI, strategic rebuilding, interception, fallout, persistent damage, terrain deformation, physics blast impulses, fog of war, multiplayer, save/load, or a simulated long-range missile path.

The strike is a scheduled ground-area effect, not a new guided projectile. Preserve the existing helicopter/rocket collision systems.

Primitive visuals, a suitable footprint, and narrow helper/file organization consistent with the repository are implementation choices you may make. Do not invent additional gameplay prerequisites or stop because the old roadmap entry was brief.

## 4. Builder construction and registration

Add Tempest Array to the selected Bulldozer's building choices in the new scenario.

Reuse existing placement validation, protected access, payment, builder travel/work, pause/resume, cancellation/refunds, navigation preparation, and completion.

Keep the existing unfinished-site concurrency limit. The per-owner Tempest limit is an additional eligibility check, not permission to create more concurrent sites.

The entire footprint must fit valid construction space with a reachable external builder work position. Do not trap or teleport the builder.

Preview and unfinished site:

* Do not charge, launch, or contribute operational power demand.
* Follow existing unfinished-site collision and damageability rules.
* Reserve the owner's facility slot only after accepted paid placement.

Completion:

* Activates a damageable GROUND building with 1,200 maximum health.
* Adds 8 demand exactly once.
* Starts charge at zero.
* Releases the builder normally.
* Creates no production queue or unit recipes.

Display actual rejection reasons: missing prerequisite, insufficient funds, existing facility/site, invalid owner, or invalid placement.

Enforce these rules in the API as well as the UI. Duplicate callbacks or placement clicks cannot double-spend or create two facilities.

Cancellation/destruction releases the facility reservation once through the normal lifecycle. Do not release it prematurely while a departing site could still complete. Rebuilding starts a new facility with no inherited charge.

## 5. Charging and power

Use the existing owner grid. The completed facility contributes its full 8 demand while charging, ready, unpowered, and recharging.

Charge advances only while the facility is eligible, the match is active, and its owner has sufficient generation for total demand.

* Low power pauses charge without erasing it.
* Restored power resumes from the retained value.
* Readiness occurs after 180 accumulated powered seconds.
* Clamp at one ready charge; do not bank extra launches.
* A ready facility remains charged during a shortage but cannot launch.
* Accepted launch consumes readiness and starts recharging from zero.
* Source damage does not reduce output or charge rate before death.

Do not remove demand when charging stops or change production/defense shortage rules.

UI charge and remaining-time values must derive from authoritative state. A paused charge must not display a continuously decreasing countdown.

Use simulation time, not wall-clock time. Declare the physics-processing boundary for charge, launch, and impact checks so tests compare coherent phases.

## 6. Manual targeting and launch commitment

Selecting an owned facility shows health, charge, power state, and Launch when eligible. No new keyboard shortcut is required.

Launch enters a ground-targeting mode without consuming charge.

* Show a radius preview on valid battlefield ground.
* Battlefield left-click confirms a valid ground target.
* Minimap left-click confirms the mapped ground target instead of panning.
* Right-click or Escape cancels without spending charge or issuing world orders.
* UI clicks do not leak through.
* Invalid targets preserve readiness and produce clear feedback.
* Do not overlap this mode with building placement or pending Q attack-move.
* Cancel pending targeting on source invalidation, power loss, incompatible selection change, focus loss, result, or Restart.

The target is fixed at commitment. It does not follow a unit afterward.

Revalidate source identity, ownership, membership, life, completion, readiness, current power, active match, and in-bounds target at the commit point.

Accept a target center inside map bounds even if part of its radius extends beyond the map. Apply only to eligible objects within the active field; do not move the center silently.

On acceptance:

1. Create one match-scoped strike with a stable ID and captured target, owner attribution, damage, radius, and impact time.
2. Consume the ready charge once and reset charge to zero.
3. Publish coherent committed state and warning feedback.

Repeated or reentrant activation cannot launch twice from one charge. A rejected request changes no charge, money, or strike state.

Already committed strikes are independent of their source node. Subsequent source destruction, power loss, selection changes, or unit commands do not cancel or retarget them.

Do not retain an unsafe source reference for later impact attribution.

## 7. Warning and authoritative impact

Show a readable ground marker and countdown for six simulated seconds. Deal no damage during preview, charge, or warning.

At impact, evaluate current positions, not launch-time positions.

Eligible targets:

* Living registered GROUND units.
* Living registered GROUND structures that are damageable under existing rules.
* Every owner, including the launcher: friendly fire is intentional.

Ineligible targets:

* AIR units, including helicopters during takeoff.
* Resources, decorations, previews, dead/departed objects, and non-damageable sites.

Use each target's existing ground aim/selection anchor for horizontal distance. Include anchors at or within 10 units, with only a small documented numerical tolerance. This is an anchor-based area effect, not collider-overlap damage.

Walls do not provide blast cover. Do not run ordinary line-of-fire checks for this area effect or change normal weapon obstruction behavior.

Take one eligible object snapshot for the impact, retaining safe object identity. Revalidate existence before each damage application because callbacks may remove participants.

* Apply 1,000 damage once per eligible surviving object through existing health/damage APIs.
* Multiple colliders must not cause multiple applications.
* Do not include a replacement object that reuses an identifier during a callback.
* Existing health rules clamp remaining HP and emit death once.
* Units moving out before impact avoid damage; units moving in are evaluated at impact.

Mark the strike's impact/terminal state before callbacks or effects can reenter it.

Complete the single impact's intended damage batch consistently with existing same-physics-tick result evaluation. Both HQs dying in that batch must produce a draw rather than whichever owner was visited first.

Do not suppress health/death signals globally, unfreeze a completed match, or apply remaining damage to a replacement field. If the field is destroyed/replaced, stop safely.

A strike whose match finished before impact is cancelled under the existing result-freeze policy. Source independence does not authorize damage after match completion.

## 8. Counterplay and lifecycle

Ordinary combat can destroy the facility.

Before launch:

* Destruction loses its current charge.
* Removing sufficient power pauses charge or prevents a ready launch.
* Cancelling an unfinished site follows existing refunds.

After launch:

* Destroying the source does not erase the warning or committed strike in an ongoing match.
* Units can escape the warning radius.
* No completed-facility destruction refund is added.

Rebuilding starts a new facility at zero charge.

Handle immediate/deferred deletion, detachment, same-field reparenting according to existing rules, power callbacks, launch reentrancy, and simultaneous building destruction.

Use existing serialized navigation cleanup for destroyed buildings. Do not let multiple blast deaths leave stale footprints or issue obsolete map updates into another field.

Result freeze stops charging and new launches and removes/cancels unresolved strike work as specified.

Restart clears charges, facility reservations, targets, warnings, scheduled impacts, and old listeners. Reused numeric IDs must not connect old strikes to new objects.

Do not build a general transaction framework to achieve these local guarantees.

## 9. Playable scenario and resource feasibility

Add a directly launchable scene, preferably:
`res://scenes/superweapon_assault.tscn`

Reuse the fortified builder/economy/air composition. Preserve all earlier scenes and their defaults.

Player opening:

* Existing HQ, initial builder, credits, and starting force.
* No free Tempest Array.
* Normal depot, collector, producer, and power construction paths.
* Facility availability subject to the specified funds and prerequisite.

Enemy:

* Existing paid economy, defenses, ground waves, and declared aircraft.
* No enemy superweapon, free rebuilding, or new strategic logic.

Before implementing the earned test, calculate the finite resource budget for the opening, required producer, adequate power, and 5,000-credit facility.

If the existing accessible supplies are insufficient, add one finite neutral cache to this new scene, with a documented amount justified by that budget. This local resource addition is authorized; do not grant hidden credits or alter shared cache definitions/earlier scenes.

Verify legal facility and power-building positions and workable access without weakening protected deposit, launch, or exit areas.

The strike does not bypass normal victory rules. Do not reduce HQ health or force victory simply to make one launch end the match.

Keep the HUD compact:

* Selected-facility charge and power information.
* Launch and ready feedback.
* Targeting-radius preview and impact warning.
* Distinct minimap facility/strike markers.
* Brief Help text explicitly stating friendly fire and ground-only damage.

Check 1280×720 and 1920×1080, with Help expanded and collapsed. No permanent debug paragraphs or hardware overlays.

## 10. Required tests

Use existing test infrastructure, physics-phase-aware simulation-time assertions, and external process deadlines.

### Construction and eligibility

* Actual paid builder work, duration, pause/resume, and cancellation.
* Valid producer prerequisite and rejection without it.
* Insufficient funds and duplicate facility/site requests reject without spending.
* Completion contributes demand and begins charge once.
* Destroying the prerequisite later does not invalidate accepted construction.

### Charge and power

* Actual 180 powered seconds to readiness.
* Low-power pause/resume without lost progress.
* Ready-but-unpowered launch rejection retains charge.
* Demand remains present in every operational charge state.
* Rebuild starts at zero and owners remain isolated.

### Input and launch

* Viewport button, battlefield, and minimap interactions.
* Cancellation, invalid target, focus loss, and no click-through.
* Double activation and synchronous source changes cannot duplicate commitment.
* Actual six-second warning with no early damage.
* Source destruction or power loss after launch does not erase an ongoing-match strike.

### Damage and results

* Exactly-once damage to enemy and friendly ground targets.
* No damage to AIR, resource, or outside-radius targets.
* Boundary inclusion and moving-in/moving-out behavior.
* No wall cover, duplicate-collider damage, or reused-ID substitution.
* Safe callback deletion and multiple building deaths.
* Same-impact destruction of both HQs yields a draw.
* Prior match result cancels an unresolved strike; Restart leaves no old impact.

### Real earned integration

Use normal gameplay to establish the economy, earn funds, construct the prerequisite and sufficient power, pay for and build the facility, accumulate charge, and launch through the supported input/API path against an actual hostile ground building.

Verify damage, credit accounting, source lifecycle, and relevant result/Restart behavior. Do not substitute direct charge assignment, free buildings, forced damage, or hidden credits.

The isolated earned fixture may declare a longer enemy-assault delay to keep the match active long enough. Keep that override local and document it; do not change the normal playable scenario's schedule.

Short configured durations may help isolated lifecycle tests, but they do not replace separate checks of the real 180-second charge and six-second warning. Use the existing simulation/test stepping facilities rather than waiting three wall-clock minutes per assertion.

## 11. Validation and final delivery

Fix ordinary code and fixture errors within this task. Preserve every failed execution and its supported explanation.

Run focused mechanics, integration, and UI suites headlessly and graphically; affected builder/power/damage/input/lifecycle checks; the normal complete regression matrix once after integration; and fresh-copy import plus superweapon integration.

Settle edits before the final matrix and save its run identity and source snapshot. Use existing runners and timeout wrappers, not another validation framework.

After a narrow late correction, rerun affected dependencies rather than automatically repeating the entire matrix.

If disconnected, recover the existing process and results; do not launch a duplicate or repeat completed work.

Distinguish feature failures, demonstrated new regressions, accepted historical exceptions, deferred movement findings, and unknown attribution. Do not retry indefinitely for a green result or weaken assertions.

Save `docs/milestone-17.md`, README, and roadmap updates before the final chat handoff. Include exact commands, counts, exits, source correspondence, reused versus new evidence, screenshots, defaults, and limitations. Do not double-count focused checks already included in the matrix.

Run documentation-link and whitespace checks. Do not claim a human playtest unless one occurred.

## 12. Acceptance criteria and required final response

Report PASS, FAIL, or NOT VERIFIED for:

1. Paid builder construction, producer prerequisite, and per-owner facility limit.
2. Correct power demand, charging, pause, and restoration.
3. Manual targeting and exactly-once launch commitment.
4. Delayed, correctly filtered, exactly-once area damage.
5. Counterplay, callbacks, destruction, freeze, and Restart.
6. Real earned construction-to-strike integration.
7. Preserved earlier gameplay and readable HUD.
8. Honest focused and regression validation with final source correspondence.

A baseline import and builder test pass is not completion of this feature. Implementation and the checks above are required.

Save the completed report first, then return a handoff under 200 words:

* Milestone 17: COMPLETE or INCOMPLETE.
* Actual playable scene and launch instructions.
* Implemented charge/strike rules.
* Final feature and full-regression results, distinguished accurately.
* Any outstanding requirement.
* Completed report path.

Do not finish with another scope proposal or baseline-only response.
Do not begin Milestone 18.

Implement, validate, save the handoff, and stop.
