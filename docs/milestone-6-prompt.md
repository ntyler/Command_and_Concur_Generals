# Milestone 6 implementation prompt — playable base assault

Feature specification. The [current roadmap decision](roadmap.md) governs this work; implementation status and actual validation are recorded separately in [the Milestone 6 report](milestone-6.md).

---

Implement **Milestone 6: a small playable base-assault match with damageable buildings, victory/defeat and restart**, building on existing construction, harvesting, production and combat.

Use the current working implementation as the baseline. Preserve validated movement/projection repairs, existing tests and assertions, fixtures and all recorded failures and diagnostic evidence. Outstanding movement issues are deferred known limitations with engineering status UNRESOLVED. They do not automatically block this feature. Do not claim full movement acceptance or resolution of those issues. Do not begin movement investigation, historical replay, recorder expansion or repair unless I request it or you demonstrate that it directly prevents this milestone's required behavior.

## Required behavior

1. Add `scenes/base_assault.tscn`, reusing the flat construction field and systems. Start the player with one HQ, two collectors, finite supplies, existing starting credits and a small Rifle force, with no barracks. Add one enemy HQ and a small fixed Rifle force. Provide buildable space and ordinary routes between bases. Keep earlier scenes and their defaults available.
2. Support the complete loop: place/complete barracks, harvest/deposit supplies into the existing wallet, train Rifles through the existing queue, set rallies and attack hostile units/buildings. Reuse prices, timings, placement rules and command semantics. Earned supplies must fund actual construction or production in the integration check.
3. Enable configurable health and damage for HQs and completed barracks in this scenario. Legacy buildings remain non-damageable by default; unfinished sites retain existing cancellation rules for this milestone. Show readable building health. Right-click hostile damageable buildings to Attack; collectors stay unarmed and owned-HQ clicks still deposit. Friendly, dead, detached and foreign-field targets reject safely without replacing valid orders.
4. Extend existing Rifle/Rocket targeting, facing, range, cooldown, obstruction and projectile behavior to buildings. A target building must be hittable despite its own blocker collider; intervening buildings/terrain still block fire. Preserve unit-target behavior and reuse the health/damage authority. Pursuit uses legal ground outside footprints and existing bounded movement.
5. Make destruction terminal and idempotent. Remove target/selection/producer eligibility, end dependent attacks safely, and remove collision, weapon obstruction and the authoritative footprint through serialized navigation updates. Completed buildings give no construction refund. Undeployed jobs follow the existing captured-price departure refund policy exactly once; deployed units cannot refund. Preserve cargo/missing-HQ behavior where applicable. Handle destruction during navigation updates and synchronous callbacks without stale references, duplicate refunds or stuck construction slots.
6. Give the enemy force one scripted assault through ordinary combat commands after a configurable preparation delay. This is a bounded scenario trigger using existing order-failure behavior, with no strategic AI, enemy economy, repeated order resets or endless waves.
7. Resolve the result once after each physics tick's destruction events: enemy HQ destroyed means victory; player HQ destroyed means defeat; both destroyed that tick means draw. Stop gameplay mutations/new orders after the result and show a usable Restart control. Restart restores fresh scene-local credits, supplies, queues, construction, units, health and outcome without old callbacks affecting the new match.

## Boundaries

Use installed Godot, typed GDScript, primitive visuals, existing ownership/membership checks and field-local state. Add only target/lifecycle support and UI needed for this feature. Preserve historical batch acceptance and supersession semantics. Do not use movement tuning, relaxed thresholds, teleportation or test-only success paths to make the scenario pass.

Exclude builders, repair/capture/sale, new units/recipes, power, technology, fog, attack-move, strategic AI, multiplayer, persistence and large-map work. Do not expand historical recording infrastructure. Document the map, building health and assault delay; tune only new scenario parameters for the build/harvest/train/defend/attack loop.

## Acceptance and regression testing

- Add focused checks for hostile building input/attacks, both weapons, intervening blockers, legacy invulnerability, destruction cleanup, refunds, navigation readiness, target departure/reentrancy, end-state ordering and restart. Exercise relevant UI through the viewport.
- Demonstrate the complete loop through public gameplay APIs and actual movement: construct a barracks, earn/deposit supplies, spend earned credits on normal production, deploy/rally troops and destroy the enemy HQ. Separately demonstrate player-HQ defeat and same-tick draw. Use real damage and lifecycle transitions, not direct result flags, cargo/credit injection or forced arrival.
- Before source edits, run applicable ordinary regressions once against the current baseline. After implementation, run affected suites and new checks headless and graphical through `tools/run-godot.ps1`. Include construction/cleanup, harvesting, production, combat/repair/load, line of fire, spherical projectiles, movement controls, retained Issue A/projection/boundary/gate repair checks and the ordinary full movement stress sequence. Do not reopen closed historical replay or continuous-recorder batches.
- Choose output paths that preserve existing evidence. Record source revision/diff, commands, checks, exits and failures. Separate documented deferred cases, new failures and unknown attribution. Do not weaken assertions, retry until green or classify a failure as pre-existing without baseline evidence. Deferred status cannot excuse failure of this milestone's requirements. Additional checks need a reason grounded in changes or new evidence.
- Run import/parser validation and `git diff --check`. Inspect the rendered scene and result/restart UI. State whether human keyboard-and-mouse playtesting occurred; automated viewport playback is not one.

Deliver the playable scene, implementation, tests, launch instructions and a Milestone 6 report covering behavior, validation and limitations. Update the roadmap with actual feature status while keeping movement issues deferred and unresolved unless separately proven otherwise. Complete this feature without substituting another Milestone 5 corrective investigation.
