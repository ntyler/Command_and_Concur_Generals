extends "res://tests/harvesting_checks.gd"
## Real physics, queries and viewport input; inherited 180s wall watchdog.

class FailingConstructionField extends ConstructionField:
	var refuse_mesh: bool = true
	func prepare_construction_mesh(rectangles: Array[Rect2]) -> NavigationMesh:
		return null if refuse_mesh else super.prepare_construction_mesh(rectangles)

class UnsynchronizedConstructionField extends ConstructionField:
	var stale_mesh: bool = true
	func prepare_construction_mesh(rectangles: Array[Rect2]) -> NavigationMesh:
		return navigation_region.navigation_mesh if stale_mesh else super.prepare_construction_mesh(rectangles)

const FIRST := Vector3(-12, 0, 3)
const SECOND := Vector3(-3, 0, 16)
var world: ConstructionField


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--construction-case="):
			chosen = argument.trim_prefix("--construction-case=")
	var cases := ["placement", "accounting", "navigation", "integration", "failure", "earned"]
	_check(chosen == "all" or cases.has(chosen), "recognized construction case")
	for case in cases:
		if chosen != "all" and chosen != case:
			continue
		var before := checks
		var failed := failures
		match case:
			"placement": await _placement_checks()
			"accounting": await _construction_accounting_checks()
			"navigation": await _construction_navigation_checks()
			"integration": await _construction_integration_checks()
			"failure": await _construction_failure_checks()
			"earned": await _earned_construction_checks()
		print("CONSTRUCTION_CASE: %s; checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(world):
		world.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "construction teardown leaves no field, preview, controls or projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "construction callbacks and teardown have no native errors or warnings")
	print("CONSTRUCTION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_construction(starting: int = 1000, supplies: int = 2000, failing: bool = false) -> void:
	if is_instance_valid(world):
		world.queue_free()
		await _frames(4)
	world = FailingConstructionField.new() if failing else load("res://scenes/construction_test.tscn").instantiate() as ConstructionField
	world.starting_credits = starting
	world.cache_supplies = supplies
	field = world
	harvest = world
	root.add_child(world)
	current_scene = world
	world.camera_rig.edge_scrolling_enabled = false
	await _frames(5)
	_check(world.credits.balance(1) == starting and world.construction.sites.is_empty() and world._producers.is_empty(), "fresh construction has configured credits, no sites or preplaced barracks")
	_check(world.units.size() == 8 and world.caches.size() == 2 and world.obstacles.size() == 5 and world._access_claims.is_empty(), "fresh construction preserves units/resources and has no stale claims")
	_check(NavigationServer3D.map_get_iteration_id(world.get_world_3d().get_navigation_map()) > 0, "fresh construction navigation synchronized")


func _place(point: Vector3 = FIRST) -> ConstructionResult:
	await physics_frame
	return world.construction.place(1, world.headquarters, world.construction_definition, point)


func _site(result: ConstructionResult) -> ConstructionSite:
	return world.construction.sites.get(result.site_id) as ConstructionSite


func _ready_site(result: ConstructionResult) -> ConstructionSite:
	_check(result.accepted, "ordinary physics placement accepted: " + result.reason)
	var site := _site(result)
	if site == null:
		return null
	if not await _until(func() -> bool: return site.state == ConstructionSite.State.CONSTRUCTING, 5.5, "site waits for synchronized navigation then begins construction"):
		return null
	print("CONSTRUCTION_PREPARATION: build_usec=%d ready_wall_usec=%d ready_sim_seconds=%.6f" % [world.construction.navigation.last_build_usec, world.construction.navigation.last_prepare_usec, world.construction.navigation.last_prepare_seconds])
	return site


func _complete_site(site: ConstructionSite) -> bool:
	if site == null: return false
	return await _until(func() -> bool: return site.state == ConstructionSite.State.OPERATIONAL, site.duration + 0.1, "site becomes operational within configured construction duration plus one tick")


func _cleanup_site(site: ConstructionSite) -> void:
	var result := world.construction.cancel(1, site.site_id)
	_check(result.accepted, "unfinished site cancellation accepted")
	await _until(func() -> bool: return site.state == ConstructionSite.State.CANCELLED and not world.construction.navigation.blocked, 5.5, "cancellation releases slot only after restored map is ready")


func _placement_checks() -> void:
	await _fresh_construction()
	var manager := world.construction
	var panel := world.production_panel as ConstructionPanel
	await _click(_world_screen(world.headquarters.global_position + Vector3.UP * 2), MOUSE_BUTTON_LEFT)
	_check(world.selection.selected_building() == world.headquarters and panel.build_button.visible and not panel.build_button.disabled, "viewport HQ selection exposes owned Build Barracks control")
	await _click(panel.build_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(world.placement.active and world.selection.placement_active, "GUI Build button enters placement without a world click")
	_motion(_world_screen(FIRST))
	await _frames(8)
	_check(world.placement.preview.visible and world.placement.valid and world.placement.point.distance_to(FIRST) < 0.02, "pointer tracks actual terrain with valid translucent footprint preview")
	_check(world.placement.status.text.contains("Valid") and world.placement.preview.mesh is BoxMesh and (world.placement.preview.mesh as BoxMesh).size == Vector3(6, 2.6, 5), "preview has textual validity and the real fixed footprint")
	_check(manager.sites.is_empty() and manager.navigation.submissions == 0 and world._producers.is_empty() and world.credits.balance(1) == 1000, "preview does not spend, register producers or rebuild navigation")
	await _capture("construction_valid_preview")
	await _click(panel.credit_label.global_position + Vector2(5, 5), MOUSE_BUTTON_LEFT)
	_check(world.placement.active and manager.sites.is_empty(), "UI clicks cannot confirm world placement")
	var camera_before := world.camera_rig.position
	_motion(_world_screen(FIRST))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_S
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(10)
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(2)
	_check(world.camera_rig.position.z > camera_before.z and world.placement.active, "S camera pan remains available during placement")
	var zoom := world.camera_rig.target_zoom
	await _click(_world_screen(FIRST), MOUSE_BUTTON_WHEEL_UP)
	_check(world.camera_rig.target_zoom < zoom and world.placement.active, "wheel zoom remains available during placement")
	await _click(_world_screen(FIRST), MOUSE_BUTTON_RIGHT)
	_check(not world.placement.active and not world.placement.preview.visible and manager.sites.is_empty() and world.last_command_result == null, "right click cancels free preview without leaking a move or rally order")
	world.placement.begin(world.headquarters)
	key = InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key, true)
	key.pressed = false
	root.push_input(key, true)
	_check(not world.placement.active and world.credits.balance(1) == 1000, "Escape cancels free preview without refunding unspent credits")
	world.placement.begin(world.headquarters)
	await _click(_world_screen(Vector3(-25, 0, 18)), MOUSE_BUTTON_LEFT)
	_check(world.placement.active and manager.sites.is_empty() and world.credits.balance(1) == 1000 and not world.placement.last_result.accepted, "footprint edge outside build area is rejected even with center on terrain")
	# The preceding pan/zoom still changes the world point under a fixed pixel.
	# Wait for ordinary camera settling, then aim again and observe an actual
	# advisory approval. A fixed eight frames can sample "Checking placement".
	if not await _until(func() -> bool: return world.camera_rig.pan_velocity.length() < 0.001 and absf(world.camera_rig.zoom - world.camera_rig.target_zoom) < 0.001, 2.0, "stale-preview setup lets ordinary pan and zoom settle"):
		return
	_motion(_world_screen(FIRST))
	if not await _until(func() -> bool: return world.placement.valid and world.placement.preview.visible and world.placement.point.distance_to(FIRST) < 0.02 and world.placement.point.is_equal_approx(world.placement._checked_point), 0.3, "stale-preview setup obtains current approval at the intended footprint"):
		return
	_check(world.placement.valid and world.placement.reason.is_empty() and world.placement.status.text.begins_with("Valid"), "stale-preview fixture initially valid")
	await physics_frame
	_check(manager.validate(1, world.headquarters, world.construction_definition, world.placement.point).is_empty() and manager.validate(1, world.headquarters, world.construction_definition, FIRST).is_empty(), "stale-preview footprint is authoritatively valid before unit entry")
	var previous_result := world.placement.last_result
	var approved_point := world.placement._checked_point
	var visitor := world.units[0]
	visitor.global_position = FIRST + Vector3(2.9, 0, 0)
	visitor.halt_motion()
	# No refreshed advisory preview between occupancy and click.
	_check(world.placement.valid and world.placement._checked_point == approved_point, "unit enters while the prior advisory approval is still cached")
	_button(_world_screen(FIRST), MOUSE_BUTTON_LEFT, true)
	_button(_world_screen(FIRST), MOUSE_BUTTON_LEFT, false)
	await _frames(2)
	_check(world.placement.last_result != previous_result and not world.placement.last_result.accepted and world.placement.last_result.reason.to_lower().contains("occup") and world.placement.active and manager.sites.is_empty() and world.credits.balance(1) == 1000, "authoritative confirm rejects unit entering the footprint after valid preview")
	visitor.global_position = ProductionField.STARTS[0]
	await _frames(3)
	for position in [Vector3(-20, 0, -7), Vector3(-7, 0, -16), Vector3(-1, 0, -6), Vector3(7, 0, -10), Vector3(0, 1, 17), Vector3(INF, 0, 0)]:
		var denied := await _place(position)
		_check(not denied.accepted and not denied.reason.is_empty() and world.credits.balance(1) == 1000 and manager.sites.is_empty(), "invalid full geometry/access/terrain leaves wallet and world unchanged: " + str(position))
	await physics_frame
	_check(not manager.place(2, world.headquarters, world.construction_definition, FIRST).accepted, "construction API rejects enemy requester despite sufficient enemy credits")
	_check(not manager.place(1, world.headquarters, ConstructionDefinition.new(), FIRST).accepted, "construction API rejects unsupported definition identity")
	var stale := RTSBuilding.new()
	stale.kind = RTSBuilding.Kind.HEADQUARTERS
	_check(not manager.place(1, stale, world.construction_definition, FIRST).accepted, "detached unregistered HQ cannot authorize placement")
	stale.free()
	# Two press/release pairs in one input batch must only make one site.
	_motion(_world_screen(FIRST))
	for i in 2:
		_button(_world_screen(FIRST), MOUSE_BUTTON_LEFT, true)
		_button(_world_screen(FIRST), MOUSE_BUTTON_LEFT, false)
	await _frames(2)
	_check(manager.sites.size() == 1 and world._producers.size() == 1 and world.credits.balance(1) == 600 and not world.placement.active, "rapid viewport confirmations create one charged selectable site")
	var site := manager.sites.values()[0] as ConstructionSite
	_check(world.selection.selected_building() == site.building() and panel.cancel_site_button.visible and not panel.train_button.visible, "unfinished site selection shows Cancel/progress and hides training")
	await _capture("construction_selected_site")
	await _click(panel.cancel_site_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _until(func() -> bool: return manager.unfinished_id == 0, 5.5, "GUI cancellation performs refundable synchronized cleanup")
	_check(world.credits.balance(1) == 1000 and world.selection.selected_building() == null, "GUI cancel refunds once and clears unavailable building selection")
	await _click(_screen(world.units[0]), MOUSE_BUTTON_LEFT)
	_check(world.selection.selected_units() == [world.units[0]], "normal viewport unit selection returns after placement")
	world.headquarters.queue_free()
	await physics_frame
	_check(not manager.place(1, world.headquarters, world.construction_definition, FIRST).accepted, "queued departing HQ cannot authorize construction")


func _construction_accounting_checks() -> void:
	await _fresh_construction()
	var manager := world.construction
	var result := await _place()
	var site := _site(result)
	_check(result.accepted and result.site_id > 0 and result.paid == 400 and site.paid == 400 and world.credits.balance(1) == 600, "accepted identity and captured paid cost accompany exactly one debit")
	_check(site.state == ConstructionSite.State.PREPARING and site.elapsed == 0 and not site.building().operational and manager.navigation.busy, "commit has collision/footprint and preparation but no construction time or production")
	_check(world.obstacles.has(site.rectangle) and site.building().collision_layer & LineOfFire.BLOCKER_MASK != 0 and not site.building().production.enqueue(1, site.building().recipe).accepted, "unfinished API rejects production while authoritative footprint blocks the world")
	var duplicate := manager.place(1, world.headquarters, world.construction_definition, SECOND)
	_check(not duplicate.accepted and manager.sites.size() == 1 and world.credits.balance(1) == 600, "one unfinished slot prevents duplicate debit at a different position")
	await _cleanup_site(site)
	_check(world.credits.balance(1) == 1000 and not manager.cancel(1, site.site_id).accepted and manager.sites.is_empty(), "cancellation refunds exactly once and rejects stale IDs")
	result = await _place()
	site = await _ready_site(result)
	if site == null: return
	var body := site.building()
	var producer := body.production
	var revision := manager.navigation.submissions
	var start := site.started_frame
	await _frames(598)
	_check(site.state == ConstructionSite.State.CONSTRUCTING and not producer.is_available() and site.elapsed < 10.0, "598 post-ready ticks cannot finish ten simulated seconds")
	if not await _complete_site(site): return
	var ticks := Engine.get_physics_frames() - start
	_check(ticks >= 600 and ticks <= 602 and site.elapsed == 10 and body.operational, "operational boundary requires 600 full simulation ticks, independent of prep")
	_check(site.building() == body and body.production == producer and producer.is_available() and site.site_id == result.site_id and body.owner_id == 1, "completion preserves building/site/owner and activates the same ordinary producer")
	_check(manager.navigation.submissions == revision and manager.unfinished_id == 0, "completion changes no footprint and causes no navigation rebuild")
	_check(not manager.cancel(1, site.site_id).accepted and world.credits.balance(1) == 600, "completion wins boundary: no selling or post-completion refund")
	await _frames(60)
	_check(manager.navigation.submissions == revision and world.credits.balance(1) == 600, "settled completed building does not repeat charge or activation")
	await _fresh_construction()
	manager = world.construction
	result = await _place()
	site = await _ready_site(result)
	if site == null: return
	await _frames(598)
	await _cleanup_site(site)
	await _frames(5)
	_check(site.state == ConstructionSite.State.CANCELLED and world.credits.balance(1) == 1000 and world._producers.is_empty(), "cancellation before completion boundary cannot resurrect production")
	await _construction_callback_checks()
	await _fresh_construction()
	world.construction_definition = world.construction_definition.duplicate() as ConstructionDefinition
	result = await _place()
	site = _site(result)
	world.construction_definition.credit_cost = 900
	world.construction_definition.duration = 1
	_check(site.paid == 400 and site.duration == 10, "committed site captures original cost/time rather than reading later definition edits")
	await _cleanup_site(site)
	_check(world.credits.balance(1) == 1000, "refund uses original 400 even after configured price changes to 900")


func _construction_callback_checks() -> void:
	for mode in ["cancel", "spend", "free_site", "free_field", "selection"]:
		await _fresh_construction()
		var manager := world.construction
		var wallet := world.credits
		var observed := {"calls": 0, "coherent": false, "nested_refund": false}
		var saved_field: WeakRef = weakref(world)
		var callback := func(_owner: int) -> void:
			observed["calls"] += 1
			if observed["calls"] != 1: return
			var current := saved_field.get_ref() as ConstructionField
			var current_site := manager.sites.get(manager.unfinished_id) as ConstructionSite
			observed["coherent"] = wallet.balance(1) == 600 and current_site != null and current.contains_building(current_site.building()) and current.obstacles.has(current_site.rectangle) and manager.navigation.busy
			match mode:
				"cancel":
					observed["nested_refund"] = manager.cancel(1, current_site.site_id).accepted and not manager.cancel(1, current_site.site_id).accepted
				"spend": wallet.spend(1, 600)
				"free_site": current_site.building().free()
				"free_field": current.free()
				"selection": current.selection.select_clicked(current.units[0], false)
		wallet.changed.connect(callback)
		var result := await _place()
		wallet.changed.disconnect(callback)
		_check(result.accepted and result.paid == 400 and observed["coherent"], "wallet notification sees fully committed state before reentrant " + mode)
		await _frames(6)
		if mode == "free_field":
			_check(manager.closed and manager.sites.is_empty() and not manager.navigation.busy and not wallet.active, "immediate field deletion invalidates manager, wallet and pending work safely")
		elif mode in ["cancel", "free_site"]:
			await _until(func() -> bool: return manager.unfinished_id == 0, 5.5, "callback removal restores terrain")
			_check(wallet.balance(1) == 1000 and manager.sites.is_empty() and (mode != "cancel" or observed["nested_refund"]), "callback cancellation/removal refunds original price exactly once")
		else:
			_check(wallet.balance(1) == (0 if mode == "spend" else 600) and manager.sites.size() == 1, "callback spending/selection cannot double-debit construction")
			await _cleanup_site(_site(result))
			_check(wallet.balance(1) == (400 if mode == "spend" else 1000), "captured refund survives callback changes to remaining balance")
	for remove in [false, true]:
		await _fresh_construction()
		var manager := world.construction
		var wallet := world.credits
		var result := await _place()
		var site := _site(result)
		var observed := {"calls": 0, "coherent": false}
		var owner_ref: WeakRef = weakref(world)
		var on_refund := func(_owner: int) -> void:
			observed["calls"] += 1
			observed["coherent"] = wallet.balance(1) == 1000 and site.refunded and site.state == ConstructionSite.State.CANCELLING and not manager.cancel(1, site.site_id).accepted
			if remove:
				(owner_ref.get_ref() as ConstructionField).free()
			else:
				wallet.spend(1, 1000)
		wallet.changed.connect(on_refund)
		var cancelled := manager.cancel(1, site.site_id)
		wallet.changed.disconnect(on_refund)
		await _frames(5)
		_check(cancelled.accepted and observed["calls"] == 1 and observed["coherent"], "refund callback observes cleanup commit and cannot recursively refund")
		_check(manager.closed if remove else wallet.balance(1) == 0, "refund callback safely removes field or spends the complete refund")
	# Exercise the actual placement input continuation after a wallet listener
	# immediately destroys its field/placement Node, not just the manager API.
	await _fresh_construction()
	var wallet := world.credits
	var manager := world.construction
	var owner_ref: WeakRef = weakref(world)
	var remove_on_confirm := func(_owner: int) -> void: (owner_ref.get_ref() as ConstructionField).free()
	wallet.changed.connect(remove_on_confirm)
	world.placement.begin(world.headquarters)
	await _click(_world_screen(FIRST), MOUSE_BUTTON_LEFT)
	wallet.changed.disconnect(remove_on_confirm)
	_check(manager.closed and not is_instance_valid(world) and not wallet.active, "viewport-confirm continuation tolerates immediate field/placement deletion")
	for remove_field in [false, true]:
		await _fresh_construction()
		manager = world.construction
		wallet = world.credits
		var result := await _place()
		var site := _site(result)
		var producer := site.building().production
		var seen := {"calls": 0, "coherent": false}
		var saved: WeakRef = weakref(world)
		producer.changed.connect(func() -> void:
			seen["calls"] += 1
			var current := saved.get_ref() as ConstructionField
			seen["coherent"] = wallet.balance(1) == 1000 and site.refunded and site.state == ConstructionSite.State.CANCELLING and not current.obstacles.has(site.rectangle) and site.nav_generation == manager.navigation.generation and manager.navigation.busy and not current.contains_building(site.building())
			if remove_field: current.free()
			else: site.building().free())
		var cancelled := manager.cancel(1, site.site_id)
		_check(cancelled.accepted and seen["calls"] == 1 and seen["coherent"], "producer-close notification follows complete refund/footprint/navigation cancellation commit")
		await _frames(5)
		if remove_field:
			_check(manager.closed and not wallet.active, "producer-close listener can immediately remove its field")
		else:
			await _until(func() -> bool: return manager.unfinished_id == 0, 5.5, "producer-close listener can immediately free body without interrupting restoration")
			_check(wallet.balance(1) == 1000 and world._nav_point(FIRST), "producer-close callback retains exactly one refund and restored terrain")


func _path(origin: Vector3, destination: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(world.get_world_3d().get_navigation_map(), origin, destination, true)


func _length(path: PackedVector3Array) -> float:
	var result := 0.0
	for i in range(1, path.size()): result += path[i - 1].distance_to(path[i])
	return result


func _construction_navigation_checks() -> void:
	await _fresh_construction()
	var start := Vector3(-22, 0, 3)
	var finish := Vector3(0, 0, 3)
	_check(absf(_length(_path(start, finish)) - 22.0) < 0.02, "fixture initially has direct route through future barracks")
	var mover := world.units[0]
	mover.global_position = start
	mover.halt_motion()
	await _frames(3)
	world.selection.select_clicked(mover, false)
	var batch := world.issue_move(finish)
	_expect_batch(batch, [mover.unit_id], [mover.unit_id], CommandBatchResult.Acceptance.COMPLETE)
	await _frames(15)
	var version := mover.order_version
	var deadline := mover.command_elapsed
	var attempts := mover.recovery_attempts
	var result := await _place()
	_check(result.accepted and mover.navigation_suspended and mover.order_version == version and mover.command_elapsed >= deadline and mover.recovery_attempts == attempts, "committed obstacle suspends existing order without resetting its identity/deadline/recovery budget")
	var site := await _ready_site(result)
	if site == null: return
	var route := _path(start, finish)
	_check(route.size() > 2 and _length(route) > 23 and route[-1].distance_to(finish) < 0.02, "actual synchronized path detours around committed footprint to original destination")
	var safe := true
	for i in 600:
		await _frames(1)
		safe = safe and not site.rectangle.grow(RTSUnit.BODY_RADIUS - 0.01).has_point(Vector2(mover.global_position.x, mover.global_position.z))
		if not mover.moving: break
	_check(safe and mover.movement_state == RTSUnit.MovementState.ARRIVED and mover.global_position.distance_to(finish) <= mover.stopping_distance and mover.order_version == version, "actual previously travelling unit follows detour without penetration and arrives under original order")
	_check(site.state == ConstructionSite.State.CONSTRUCTING, "navigation traversal finished while site remains unfinished")
	await _cleanup_site(site)
	_check(absf(_length(_path(start, finish)) - 22.0) < 0.02 and world._nav_point(FIRST), "cancellation restores real direct route and formerly occupied center")
	# An assigned destination consumed by a legal placement must fail, not move its slot.
	mover.global_position = start
	mover.halt_motion()
	await _frames(3)
	mover.move_to(FIRST)
	version = mover.order_version
	result = await _place()
	site = await _ready_site(result)
	if site == null: return
	_check(mover.movement_state == RTSUnit.MovementState.FAILED and not mover.moving and mover.order_version == version and mover.assigned_destination == FIRST, "invalidated destination fails once at readiness without projection or new player command")
	await _cleanup_site(site)
	_check(mover.move_to(finish), "FAILED mover still accepts a later player order")
	mover.stop()
	# Rapid cancellation before submission and while submission is awaiting sync.
	for submit_first in [false, true]:
		result = await _place()
		site = _site(result)
		_check(site != null, "rapid cancellation fixture accepted")
		if site == null: return
		if submit_first: await _frames(1)
		var manager := world.construction
		var old_generation := site.nav_generation
		var cancelled := manager.cancel(1, site.site_id)
		_check(cancelled.accepted and manager.unfinished_id == site.site_id and not world.obstacles.has(site.rectangle), "cancel immediately removes reservation but holds unfinished cleanup slot")
		await physics_frame
		_check(not manager.place(1, world.headquarters, world.construction_definition, SECOND).accepted, "new placement cannot race cancellation cleanup")
		manager._navigation_ready(old_generation)
		_check(site.state == ConstructionSite.State.CANCELLING, "late preparation generation cannot reactivate cancelled site")
		await _until(func() -> bool: return manager.unfinished_id == 0, 5.5, "serialized latest cancellation map becomes ready")
		_check(world._nav_point(FIRST) and absf(_length(_path(start, finish)) - 22) < 0.02 and world.credits.balance(1) == 1000, "rapid cancellation restores traversal and exact credits")
	# Detached unit must not carry an old field's navigation suspension.
	result = await _place()
	site = _site(result)
	_check(mover.navigation_suspended, "departure fixture starts with paused unit")
	world.remove_child(mover)
	_check(not mover.navigation_suspended and not world.contains_unit(mover), "unit departure removes old field suspension immediately")
	mover.free()
	await _cleanup_site(site)
	# A completed building leaving while another site prepares must retarget the
	# pending site's generation to the latest combined geometry update.
	var completed := await _ready_site(await _place())
	if completed == null or not await _complete_site(completed): return
	result = await _place(SECOND)
	site = _site(result)
	completed.building().free()
	await _until(func() -> bool: return site.state == ConstructionSite.State.CONSTRUCTING, 5.5, "completed-building departure cannot strand another site's pending generation")
	_check(world._nav_point(FIRST) and not world._nav_point(SECOND) and world.construction.sites.size() == 1, "latest geometry removes departed building while keeping current site footprint")
	await _cleanup_site(site)


func _construction_integration_checks() -> void:
	await _fresh_construction()
	var first := await _ready_site(await _place())
	if first == null or not await _complete_site(first): return
	var second := await _ready_site(await _place(SECOND))
	if second == null or not await _complete_site(second): return
	var a := first.building()
	var b := second.building()
	_check(a.production != b.production and world._producers.size() == 2 and world.credits.balance(1) == 200, "two completed barracks own independent queues and share construction wallet")
	await physics_frame
	var blocked_exit := await _place(Vector3(-5.5, 0, 3))
	_check(not blocked_exit.accepted, "new footprint cannot overlap an existing barracks exit neighborhood")
	_check(a.production.set_rally(1, Vector3(1, 0, 1)).accepted and b.production.set_rally(1, Vector3(6, 0, 18)).accepted, "built producers use existing authorized rally validation")
	var original_count := world.units.size()
	var deployment: Array[Dictionary] = []
	for building in [a, b]:
		building.production.deployed.connect(func(job_id: int, unit_id: int, rally: bool) -> void: deployment.append({"job": job_id, "unit": unit_id, "rally": rally}))
	var job_a := a.production.enqueue(1, a.recipe)
	var job_b := b.production.enqueue(1, b.recipe)
	_check(job_a.accepted and job_b.accepted and a.production.count() == 1 and b.production.count() == 1 and world.credits.balance(1) == 0, "independent Rifle requests debit shared final 200 credits once")
	await _frames(298)
	_check(world.units.size() == original_count and deployment.is_empty(), "ordinary built queues preserve five-second training deadline")
	await _until(func() -> bool: return deployment.size() == 2, 2, "both built producers deploy through ordinary safe spawn paths")
	_check(world.units.size() == original_count + 2 and deployment[0]["unit"] != deployment[1]["unit"] and deployment[0]["rally"] and deployment[1]["rally"], "both deployments are uniquely registered and accept their separate rallies")
	var produced: Array[RTSUnit] = []
	for unit in world.units:
		if unit.unit_id > 8: produced.append(unit)
	await _until(func() -> bool: return produced.all(func(unit: RTSUnit) -> bool: return not unit.moving), 8, "produced Rifles actually finish their rally routes")
	_check(produced.all(func(unit: RTSUnit) -> bool: return unit.owner_id == 1 and unit.movement_state == RTSUnit.MovementState.ARRIVED and world.contains_unit(unit)), "built Rifles preserve ownership, arrival and selection membership")
	world.selection.select_building(a)
	await _capture("construction_two_operational")
	await _construction_weapon_checks()
	await _fresh_construction()
	var mover := world.units[0]
	world.selection.select_clicked(mover, false)
	var batch := world.issue_move(Vector3(-20, 0, 18))
	_expect_batch(batch, [1], [1], CommandBatchResult.Acceptance.COMPLETE)
	world.placement.begin(world.headquarters)
	_motion(Vector2(600, 700))
	_key_x()
	await _frames(2)
	_check(not mover.moving and world.placement.active, "unhandled X still stops selected units during placement")
	var consumer := StopConsumer.new()
	consumer.focus_mode = Control.FOCUS_ALL
	consumer.position = Vector2(500, 100)
	consumer.size = Vector2(160, 40)
	root.add_child(consumer)
	consumer.grab_focus()
	mover.move_to(Vector3(-20, 0, 18))
	var version := mover.order_version
	_key_x()
	await _frames(2)
	_check(consumer.consumed == 1 and mover.moving and mover.order_version == version, "GUI-consumed X cannot leak into a Stop while placing")
	consumer.release_focus()
	consumer.queue_free()
	world.placement.cancel()
	await _frames(2)


func _construction_weapon_checks() -> void:
	await _fresh_construction()
	var source := world.units[0]
	var target := world.units[3]
	source.global_position = Vector3(-12, 0, 7)
	target.global_position = Vector3(-12, 0, -1)
	source.halt_motion()
	target.halt_motion()
	target.combat.retaliation_enabled = false
	await _frames(3)
	_align(source, target)
	world.placement.begin(world.headquarters)
	_motion(_world_screen(FIRST))
	await _frames(8)
	var health := target.combat.health.current
	await physics_frame
	_check(source.combat.weapon.try_fire(target) and target.combat.health.current < health, "real hitscan passes through visible preview ghost")
	_check(absf(_length(_path(Vector3(-22, 0, 3), Vector3(0, 0, 3))) - 22) < 0.02 and world._buildings.size() == 1, "ghost leaves real path and selection registration unchanged")
	var ghost_rocket := GuidedProjectile.new()
	ghost_rocket.configure(world, source, target, LineOfFireField.ROCKET)
	ghost_rocket.position = source.global_position + Vector3.UP * 0.75
	var ghost_shot := {"resolved": false, "outcome": GuidedProjectile.Outcome.NONE}
	ghost_rocket.resolved.connect(func(_damage: float) -> void:
		ghost_shot["resolved"] = true
		ghost_shot["outcome"] = ghost_rocket.outcome)
	world.add_child(ghost_rocket)
	await _until(func() -> bool: return ghost_shot["resolved"], 2, "real spherical projectile travels through visible preview")
	_check(ghost_shot["outcome"] == GuidedProjectile.Outcome.TARGET, "preview contributes no spherical world collision")
	var walker := world.units[1]
	walker.global_position = Vector3(-22, 0, 3)
	walker.halt_motion()
	await _frames(3)
	_check(walker.move_to(Vector3(0, 0, 3)), "preview traversal accepts ordinary movement")
	var crossed_ghost := false
	for tick in 330:
		await _frames(1)
		crossed_ghost = crossed_ghost or walker.global_position.distance_to(FIRST) < 0.3
		if not walker.moving: break
	_check(crossed_ghost and walker.movement_state == RTSUnit.MovementState.ARRIVED and world.placement.active and world.construction.navigation.submissions == 0, "actual unit passes through preview center and arrives without collision or navigation updates")
	world.placement.cancel()
	var result := await _place()
	var site := await _ready_site(result)
	if site == null: return
	await _until(func() -> bool: return source.combat.weapon.cooldown_remaining == 0, 1, "ghost shot finishes its ordinary weapon cooldown before blocker assertion")
	health = target.combat.health.current
	await physics_frame
	_check(not source.combat.weapon.try_fire(target) and source.combat.weapon.last_fire_line.blocked and target.combat.health.current == health, "real hitscan cannot fire through unfinished construction geometry")
	_check(site.building().get_node_or_null("Health") == null and site.building().collision_layer & LineOfFire.BLOCKER_MASK != 0, "construction uses indestructible building world-blocker policy")
	await _rocket_against_site(source, target, site)
	if not await _complete_site(site): return
	await physics_frame
	_check(not source.combat.weapon.try_fire(target) and source.combat.weapon.last_fire_line.blocked, "operational barracks retains identical hitscan obstruction")
	await _rocket_against_site(source, target, site)


func _rocket_against_site(source: RTSUnit, target: RTSUnit, site: ConstructionSite) -> void:
	var rocket := GuidedProjectile.new()
	rocket.configure(world, source, target, LineOfFireField.ROCKET)
	rocket.position = source.global_position + Vector3.UP * 0.75
	var seen := {"count": 0, "outcome": GuidedProjectile.Outcome.NONE, "damage": 0.0, "point": Vector3.ZERO}
	rocket.resolved.connect(func(damage: float) -> void:
		seen["count"] += 1
		seen["outcome"] = rocket.outcome
		seen["damage"] = damage
		seen["point"] = rocket.contact_position)
	var health := target.combat.health.current
	world.add_child(rocket)
	await _until(func() -> bool: return seen["count"] > 0, 3, "actual moving spherical rocket resolves against placed building")
	_check(seen["count"] == 1 and seen["outcome"] == GuidedProjectile.Outcome.WORLD and seen["damage"] == 0 and target.combat.health.current == health and absf((seen["point"] as Vector3).z - site.rectangle.end.y) < 0.02, "spherical collision reports world contact at building face with no target damage")
	await _frames(15)
	_check(not is_instance_valid(rocket), "building impact leaves no projectile behind")


func _construction_failure_checks() -> void:
	await _fresh_construction(1000, 2000, true)
	var manager := world.construction
	var result := await _place()
	var site := _site(result)
	_check(result.accepted and site != null, "failure fixture commits ordinary paid site first")
	await _until(func() -> bool: return site.state == ConstructionSite.State.FAILED, 1, "simulated geometry preparation failure reaches visible FAILED state")
	world.selection.select_building(site.building())
	_check(world.credits.balance(1) == 600 and site.paid == 400 and not site.refunded and not site.building().production.is_available() and not site.building().production.enqueue(1, site.building().recipe).accepted, "failed preparation retains one paid refundable footprint with no usable producer")
	_check((world.production_panel as ConstructionPanel).site_status.text.contains("failed") and (world.production_panel as ConstructionPanel).cancel_site_button.visible, "selected failed site shows reason and cancellation control")
	await _frames(120)
	_check(site.state == ConstructionSite.State.FAILED and manager.navigation.submissions == 0 and world.credits.balance(1) == 600, "failure does not infinitely retry, charge again or count construction time")
	(world as FailingConstructionField).refuse_mesh = false
	await _cleanup_site(site)
	_check(world.credits.balance(1) == 1000 and world._nav_point(FIRST) and world._producers.is_empty() and world.obstacles.size() == 5, "failed-site cancellation restores wallet, geometry and producer registry")
	result = await _place()
	site = _site(result)
	var old_generation := site.nav_generation
	var old_nav := manager.navigation
	var old_wallet := world.credits
	world.placement.begin(world.headquarters) # Rejected because the slot is occupied.
	world.free()
	await _frames(3)
	_check(manager.closed and manager.sites.is_empty() and not old_nav.busy and not old_wallet.active, "teardown during preparation closes old field generation and wallet")
	await _fresh_construction()
	var new_version := NavigationServer3D.map_get_iteration_id(world.get_world_3d().get_navigation_map())
	manager._navigation_ready(old_generation)
	old_nav.advance(10)
	_check(world.credits.balance(1) == 1000 and world.construction.sites.is_empty() and world._producers.is_empty() and not world.placement.active and world._nav_point(FIRST), "late old-field readiness/work cannot alter replacement scene state")
	_check(NavigationServer3D.map_get_iteration_id(world.get_world_3d().get_navigation_map()) == new_version, "old generation does not submit geometry into replacement map")
	# Callback cancellation on the readiness signal cannot be followed by a timer tick.
	manager = world.construction
	var cancel_on_ready := func(identity: int) -> void:
		var current := manager.sites.get(identity) as ConstructionSite
		if current != null and current.state == ConstructionSite.State.CONSTRUCTING:
			manager.cancel(1, identity)
	manager.changed.connect(cancel_on_ready)
	result = await _place()
	site = _site(result)
	await _until(func() -> bool: return site.state == ConstructionSite.State.CANCELLED, 5.5, "readiness listener can cancel before first construction tick")
	_check(site.elapsed == 0 and world.credits.balance(1) == 1000 and manager.sites.is_empty(), "readiness cancellation cannot resurrect or advance cancelled site")
	manager.changed.disconnect(cancel_on_ready)
	# Same mesh is intentionally returned: preparation succeeds, synchronization
	# does not. This catches implementations that equate assignment with readiness.
	world.queue_free()
	await _frames(4)
	world = UnsynchronizedConstructionField.new()
	field = world
	harvest = world
	root.add_child(world)
	current_scene = world
	world.camera_rig.edge_scrolling_enabled = false
	await _frames(5)
	manager = world.construction
	result = await _place()
	site = _site(result)
	await _frames(298)
	_check(site.state == ConstructionSite.State.PREPARING and site.elapsed == 0 and not site.building().operational, "constructed but unsynchronized mesh cannot start timer or production before deadline")
	await _until(func() -> bool: return site.state == ConstructionSite.State.FAILED, 0.2, "explicit synchronization deadline reaches failed state without arbitrary success delay")
	_check(site.reason.contains("timed out") and manager.navigation.submissions == 1, "sync failure records one submission and clear timeout reason")
	(world as UnsynchronizedConstructionField).stale_mesh = false
	await _cleanup_site(site)
	_check(world.credits.balance(1) == 1000 and world._nav_point(FIRST), "timed-out preparation remains cancellable with exact refund and restored route")


func _earned_construction_checks() -> void:
	await _fresh_construction(0, 500)
	# The exact 500-credit ledger deliberately isolates one selected cache.
	for unit in world.collectors: unit.collection_radius = 0.0
	var denied := await _place()
	_check(not denied.accepted and world.construction.sites.is_empty() and world.credits.balance(1) == 0, "zero-funded supported fixture cannot afford a barracks")
	var truck := _select_collector()
	var cache := world.caches[0]
	var work := truck.harvesting
	var ledger := {"loads": 0, "deposits": 0, "coherent": true}
	work.transferred.connect(func(transfer: HarvestTransfer) -> void:
		if transfer.kind == HarvestTransfer.Kind.LOAD: ledger["loads"] += transfer.amount
		else: ledger["deposits"] += transfer.amount
		ledger["coherent"] = ledger["coherent"] and cache.remaining + work.cargo + ledger["deposits"] == 500)
	_check(_complete(world.issue_harvest(cache)), "real collector accepts earning route for construction")
	if not await _until(func() -> bool: return world.credits.balance(1) >= 400, 65, "real trips earn barracks cost without granted credits"): return
	var result := await _place()
	_check(result.accepted and world.credits.balance(1) == ledger["deposits"] - 400, "earned construction debits exactly 400 from real deposited supplies")
	var site := await _ready_site(result)
	if site == null or not await _complete_site(site): return
	if not await _until(func() -> bool: return ledger["deposits"] == 500 and work.cargo == 0, 25, "collector continues through construction topology update and deposits final load"): return
	_check(ledger["loads"] == 500 and ledger["coherent"] and cache.remaining == 0 and world.credits.balance(1) == 100 and work.state == CollectorHarvest.State.WAITING, "all 500 finite supplies conserved across navigation update with exactly 100 left for Rifle")
	var producer := site.building().production
	_check(producer.set_rally(1, Vector3(1, 0, 1)).accepted, "earned barracks accepts ordinary rally")
	var seen := {"unit": 0, "rally": false}
	producer.deployed.connect(func(_job: int, identity: int, rally: bool) -> void:
		seen["unit"] = identity
		seen["rally"] = rally)
	_check(producer.enqueue(1, site.building().recipe).accepted and world.credits.balance(1) == 0, "last 100 earned credits fund existing Rifle recipe")
	if not await _until(func() -> bool: return seen["unit"] > 0, 6, "earned Rifle completes ordinary training and safe deployment"): return
	var rifle: RTSUnit
	for unit in world.units:
		if unit.unit_id == seen["unit"]: rifle = unit
	_check(is_instance_valid(rifle) and seen["rally"] and world.contains_unit(rifle), "earned deployment supplies usable owned registered Rifle")
	if not is_instance_valid(rifle): return
	await _until(func() -> bool: return not rifle.moving, 6, "earned Rifle actually reaches configured rally")
	_check(rifle.movement_state == RTSUnit.MovementState.ARRIVED and rifle.global_position.distance_to(Vector3(1, 0, 1)) <= rifle.stopping_distance, "earned unit arrives at requested rally without fixture teleportation")
	var target := world.units[3]
	var health := target.combat.health.current
	world.selection.select_clicked(rifle, false)
	var batch := world.issue_attack(target)
	_expect_batch(batch, [rifle.unit_id], [rifle.unit_id], CommandBatchResult.Acceptance.COMPLETE)
	await _until(func() -> bool: return target.combat.health.current < health, 15, "produced and rallied earned Rifle pursues original hostile and deals real combat damage")
	_check(world.credits.balance(1) == 0 and ledger["deposits"] == 500 and ledger["coherent"], "end-to-end conservation: 500 earned = 400 barracks + 100 Rifle, no direct credit grants")
