extends "res://tests/vehicle_production_checks.gd"
## M8 uses the existing real-physics/viewport harness. The integrated case pays
## normal costs, builds and trains through gameplay APIs, and never spawns or
## relocates actors. Only its assault delay is extended to bound feature coverage.


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tactical-case="):
			chosen = argument.trim_prefix("--tactical-case=")
	var cases := ["mapping", "input", "markers", "loop"]
	_check(chosen == "all" or cases.has(chosen), "recognized tactical interface case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"mapping": await _tactical_mapping()
			"input": await _tactical_input()
			"markers": await _tactical_markers()
			"loop": await _tactical_loop()
		print("TACTICAL_CASE: %s; checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(battle): battle.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "tactical teardown removes field, minimap, groups, previews and projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "tactical checks and teardown have no native errors or warnings")
	print("TACTICAL_INTERFACE_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _tactical_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m8/tactical")
	var screenshot := root.get_texture().get_image()
	var result := screenshot.save_png("res://validation-output/m8/tactical/%s.png" % label)
	_check(result == OK and screenshot.get_size() == root.size, "rendered %s at actual %s saved" % [label, root.size])


func _minimap_point(point: Vector3) -> Vector2:
	return battle.tactical_minimap.global_position + battle.tactical_minimap.mapping.world_to_content(point)


func _tactical_key(number: int, control: bool = false) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_0 + number
	key.physical_keycode = KEY_0 + number
	key.ctrl_pressed = control
	key.pressed = true
	root.push_input(key, true)
	key.pressed = false
	root.push_input(key, true)
	await _frames(2)


func _marker(identity: int) -> Dictionary:
	for marker in battle.tactical_minimap.markers:
		if marker["identity"] == identity: return marker
	return {}


func _marker_count(kind: String) -> int:
	var count := 0
	for marker in battle.tactical_minimap.markers:
		if marker["kind"] == kind: count += 1
	return count


func _tactical_mapping() -> void:
	var mapping := MinimapMapping.new()
	var bounds := Rect2(-40, -10, 80, 20)
	var area := Rect2(7, 11, 320, 180)
	mapping.configure(bounds, area, 2.0)
	_check(mapping.content_rect == Rect2(7, 61, 320, 80), "non-square map preserves aspect ratio and centers letterboxing")
	var corners: Array[Vector2] = [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y), bounds.get_center()]
	for corner in corners:
		var point := Vector3(corner.x, 2, corner.y)
		var pixel := mapping.world_to_content(point)
		var restored: Variant = mapping.content_to_world(pixel)
		_check(restored is Vector3 and (restored as Vector3).distance_to(point) < 0.0001, "world/minimap round trip includes corner or center %s" % corner)
	_check(mapping.world_to_content(Vector3(-40, 2, -10)) == mapping.content_rect.position and mapping.world_to_content(Vector3(40, 2, 10)) == mapping.content_rect.end, "fixed orientation maps +X right and +Z down")
	_check(mapping.content_to_world(Vector2(8, 12)) == null and mapping.content_to_world(Vector2(6, 90)) == null and mapping.content_to_world(Vector2(328, 90)) == null, "letterbox and outside borders reject input")
	mapping.configure(bounds, Rect2(20, 30, 180, 320), 2.0)
	_check(mapping.content_rect == Rect2(20, 167.5, 180, 45), "resized portrait panel retains world aspect and accounts for content offset")
	var resized: Variant = mapping.content_to_world(mapping.world_to_content(Vector3(13, 2, -3)))
	_check(resized is Vector3 and (resized as Vector3).distance_to(Vector3(13, 2, -3)) < 0.0001, "mapping after resize uses the new scale and letterbox")
	for invalid in [Rect2(), Rect2(0, 0, 0, 30), Rect2(0, 0, 30, 0)]:
		mapping.configure(bounds, invalid)
		_check(mapping.content_to_world(Vector2.ZERO) == null, "zero-sized layout safely rejects input: %s" % invalid)
	mapping.configure(Rect2(), area)
	_check(mapping.content_to_world(area.get_center()) == null, "zero-sized world bounds safely reject input")
	await _fresh_combined(2000, 600) # Isolated paid full-queue layout fixture.
	_check(is_instance_valid(battle.tactical_minimap) and is_instance_valid(battle.control_groups), "combined scene explicitly enables both tactical components")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _frames(8)
		var minimap := battle.tactical_minimap
		var panel := minimap.get_global_rect()
		_check(root.get_visible_rect().encloses(panel) and panel.size.x >= 160 and panel.size.y >= 140, "compact minimap is inside viewport at %s" % dimensions)
		_check(not panel.intersects(battle.production_panel.get_global_rect()) and not panel.intersects(battle.info_panel.get_global_rect()) and not panel.intersects(battle.objective_label.get_global_rect()), "minimap does not overlap economy/actions/help/objective at %s" % dimensions)
		var actual: Variant = minimap.mapping.content_to_world(_minimap_point(Vector3(9, 0, -3)) - minimap.global_position)
		_check(actual is Vector3 and (actual as Vector3).distance_to(Vector3(9, 0, -3)) < 0.001, "live layout has correct input offsets at %s" % dimensions)
		await _tactical_capture("m8_layout_%dx%d_hq" % [dimensions.x, dimensions.y])
		battle.selection.select_clicked(battle.units[0], false)
		await _tactical_key(1, true)
		await _frames(7)
		await _tactical_capture("m8_layout_%dx%d_group" % [dimensions.x, dimensions.y])
		battle.selection.select_clicked(battle.collectors[0], false)
		battle.selection.select_clicked(battle.collectors[1], true)
		await physics_frame
		_check(_complete(battle.issue_harvest(battle.caches[0])), "layout collectors have ordinary active supply feedback")
		await _frames(8)
		_check(not minimap.get_global_rect().intersects(battle.harvest_panel.get_global_rect()), "both collector cargo/supply details remain uncovered at %s" % dimensions)
		await _tactical_capture("m8_layout_%dx%d_collectors" % [dimensions.x, dimensions.y])
		for truck in battle.collectors: truck.stop()
		battle.selection.select_building(battle.headquarters)
	var factory := await _factory()
	if factory == null: return
	battle.selection.select_building(factory)
	for job in 5:
		_check(factory.production.enqueue(1, factory.recipe).accepted, "layout fixture pays ordinary full-capacity queue entry %d" % (job + 1))
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _frames(8)
		_check(factory.production.count() == 5 and battle.production_panel.cancel_buttons.size() == 5 and not battle.tactical_minimap.get_global_rect().intersects(battle.production_panel.get_global_rect()), "full Rocket queue and all five cancellation buttons remain uncovered at %s" % dimensions)
		await _tactical_capture("m8_layout_%dx%d_full_queue" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	await _frames(8)
	var minimap := battle.tactical_minimap
	var original := minimap.footprint.duplicate()
	_check(original.size() >= 3, "actual initial camera ground-view polygon is available")
	battle.camera_rig.center_on_ground(Vector3(18, 0, -12))
	await _frames(3)
	var panned := minimap.footprint.duplicate()
	_check(panned.size() >= 3 and panned != original, "camera footprint responds to actual camera pan")
	battle.camera_rig.target_zoom = 25
	await _frames(90)
	_check(minimap.footprint.size() >= 3 and minimap.footprint != panned, "camera footprint responds to actual camera zoom")
	var inside := true
	for pixel in minimap.footprint:
		inside = inside and minimap.mapping.content_rect.grow(0.001).has_point(pixel)
	_check(inside, "camera footprint polygon is clipped to real map content bounds")
	var legacy := load("res://scenes/base_assault.tscn").instantiate() as BaseAssaultField
	root.add_child(legacy)
	await _frames(3)
	_check(legacy.tactical_minimap == null and legacy.control_groups == null, "earlier base-assault scene retains its tactical-interface defaults")
	legacy.queue_free()
	await _frames(3)


func _tactical_input() -> void:
	await _fresh_combined()
	var first := battle.units[0]
	var second := battle.units[1]
	battle.selection.select_clicked(first, false)
	battle.selection.select_clicked(second, true)
	await physics_frame
	_check(_complete(battle.issue_move(Vector3(-11, 0, 16))), "focused minimap fixture starts ordinary active movement")
	var selection := battle.selection.selected_units()
	var versions := [first.order_version, second.order_version]
	var destinations := [first.assigned_destination, second.assigned_destination]
	var zoom := battle.camera_rig.zoom
	var angle := battle.camera_rig.camera.rotation
	var batch := battle.last_command_result
	await _click(_minimap_point(Vector3(11, 0, -7)), MOUSE_BUTTON_LEFT)
	_check(battle.camera_rig.position.distance_to(Vector3(11, 0, -7)) < 0.05 and battle.camera_rig.zoom == zoom and battle.camera_rig.camera.rotation == angle, "viewport minimap left-click centers existing camera while preserving angle and zoom")
	_check(battle.selection.selected_units() == selection and [first.order_version, second.order_version] == versions and [first.assigned_destination, second.assigned_destination] == destinations and battle.last_command_result == batch, "minimap navigation preserves selection and both active orders without a world-pick leak")
	await _click(_minimap_point(Vector3(12, 0, -4)), MOUSE_BUTTON_RIGHT)
	_check(battle.last_command_result != batch and _complete(battle.last_command_result) and battle.last_command_result.intended_ids.size() == 2 and battle.last_command_result.assignments.size() == 2, "viewport minimap right-click dispatches fresh complete CommandBatchResult for selected units")
	_check(first.order_version > versions[0] and second.order_version > versions[1] and first.assigned_destination.distance_to(second.assigned_destination) >= 1.0, "ordinary minimap Move replaces previous orders and keeps distinct destinations")
	_check(battle.selection.selected_units() == selection and battle.selection._pending_picks.is_empty() and not battle.selection._pressed, "handled minimap buttons leave no underlying selection or command input")
	versions = [first.order_version, second.order_version]
	destinations = [first.assigned_destination, second.assigned_destination]
	batch = battle.last_command_result
	# Isolated explicit slot refusal exercises the real ordinary command boundary.
	battle.destinations.maximum_radius = 0
	await _click(_minimap_point(Vector3(13, 0, -3)), MOUSE_BUTTON_RIGHT)
	_check(battle.last_command_result == batch and battle.status_label.text.contains("No room") and [first.order_version, second.order_version] == versions and [first.assigned_destination, second.assigned_destination] == destinations, "rejected minimap Move reports ordinary refusal and preserves both existing orders")
	battle.destinations.maximum_radius = 18
	await physics_frame
	_check(_complete(battle.issue_attack(battle.enemy_headquarters)), "focused minimap fixture starts ordinary persistent HQ Attack")
	await _click(_minimap_point(Vector3(12, 0, -4)), MOUSE_BUTTON_RIGHT)
	_check(_complete(battle.last_command_result) and first.combat.target_actor() == null and second.combat.target_actor() == null and first.moving and second.moving, "accepted minimap ground Move replaces active attack targets through the existing order path")
	batch = battle.last_command_result
	versions = [first.order_version, second.order_version]
	var camera := battle.camera_rig.position
	var border := battle.tactical_minimap.global_position + Vector2(2, 2)
	await _click(border, MOUSE_BUTTON_RIGHT)
	await _click(border, MOUSE_BUTTON_LEFT)
	_check(battle.last_command_result == batch and [first.order_version, second.order_version] == versions and battle.camera_rig.position == camera, "minimap panel border rejects commands and camera movement without leaking")
	battle.selection.select_building(battle.headquarters)
	await _click(_minimap_point(Vector3(-4, 0, -3)), MOUSE_BUTTON_RIGHT)
	_check(battle.last_command_result == batch and battle.selection.selected_building() == battle.headquarters, "minimap right-click with only a building selected is a harmless no-op")
	battle.selection.select_clicked(first, false)
	_check(battle.placement.begin(battle.headquarters), "normal placement starts for minimap input isolation")
	battle.camera_rig.center_on_ground(Vector3.ZERO)
	_motion(_world_screen(FIRST))
	await _frames(8)
	var preview := battle.placement.point
	camera = battle.camera_rig.position
	var balance := battle.credits.balance(1)
	var count := battle.tactical_minimap.markers.size()
	await _click(_minimap_point(Vector3(10, 0, 3)), MOUSE_BUTTON_LEFT)
	await _click(_minimap_point(Vector3(-10, 0, 6)), MOUSE_BUTTON_RIGHT)
	await _tactical_key(2, true)
	await _tactical_key(1)
	await _frames(8)
	_check(battle.placement.active and battle.construction.sites.is_empty() and battle.credits.balance(1) == balance, "minimap mouse input neither confirms nor cancels active building placement")
	_check(battle.placement.point == preview and battle.camera_rig.position == camera and battle.last_command_result == batch, "minimap placement input preserves preview point, camera and army orders")
	_check(battle.control_groups.group_members(2).is_empty() and battle.selection.selected_units() == [first], "group keys preserve active placement workflow")
	_check(battle.tactical_minimap.markers.size() == count and _marker_count("site") == 0, "placement preview never becomes a committed minimap building")
	await _tactical_capture("m8_placement")
	battle.placement.cancel()
	battle.camera_rig.edge_scrolling_enabled = true
	# Widen only this fixture's edge band to intersect the panel's 20px inset.
	battle.camera_rig.edge_margin = 32
	var minimap_rect := battle.tactical_minimap.get_global_rect()
	var hover := Vector2(minimap_rect.end.x - 1, minimap_rect.get_center().y)
	_check(battle.camera_rig.edge_direction(hover, root.get_visible_rect()) != Vector2.ZERO, "edge-hover fixture lies in actual viewport edge-scroll band")
	_motion(hover)
	camera = battle.camera_rig.position
	await _frames(30)
	_check(battle.camera_rig.position == camera and battle.camera_rig.pan_velocity == Vector2.ZERO, "hover over interactive minimap suppresses accidental edge scrolling")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_S
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(12)
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(2) # Drain parsed release before changing this event for X.
	_check(battle.camera_rig.position.z > camera.z and first.order_version == versions[0], "unconsumed S still pans while hovering minimap and does not Stop")
	_check(not Input.is_action_pressed("camera_back"), "synthetic S release leaves no held camera action in later fixtures")
	key = InputEventKey.new()
	key.physical_keycode = KEY_X
	key.pressed = true
	root.push_input(key, true)
	key.pressed = false
	root.push_input(key, true)
	await _frames(2)
	_check(not first.moving and first.order_version > versions[0], "existing X Stop still works while pointer hovers minimap")
	battle.camera_rig.edge_scrolling_enabled = false
	battle.camera_rig.edge_margin = 18
	var truck := battle.collectors[0]
	battle.selection.select_clicked(truck, false)
	_check(_complete(battle.issue_harvest(battle.caches[0])), "collector starts real harvest trip before minimap interruption")
	if not await _until(func() -> bool: return truck.harvesting.cargo >= 25, 15, "collector actually loads supplies for cargo-preservation input case"): return
	var cargo := truck.harvesting.cargo
	await _click(_minimap_point(Vector3(-10, 0, 16)), MOUSE_BUTTON_RIGHT)
	_check(_complete(battle.last_command_result) and truck.harvesting.state == CollectorHarvest.State.IDLE and not truck.harvesting.automatic and truck.harvesting.cargo == cargo and truck.moving, "minimap Move interrupts collector harvesting through existing rules and preserves carried cargo")


func _tactical_markers() -> void:
	await _fresh_combined(2000, 600)
	var minimap := battle.tactical_minimap
	minimap.refresh_markers()
	_check(_marker_count("unit") == battle.units.size() and _marker_count("headquarters") == 2 and _marker_count("supply") == 2 and minimap.markers.size() == 12, "initial markers match registered units, both HQs and finite caches")
	_check(minimap.marker_refresh_interval == 0.1 and minimap.static_rectangles.size() == 2, "default marker interval is 0.1 seconds and static map contains real terrain obstacles")
	var static_rebuilds := minimap.static_rebuilds
	for refresh in 3: minimap.refresh_markers()
	_check(minimap.static_rebuilds == static_rebuilds, "ordinary marker refreshes reuse cached unchanged static geometry")
	var first := battle.units[0]
	battle.selection.select_clicked(first, false)
	await _frames(8)
	var selected := _marker(first.get_instance_id())
	_check(not selected.is_empty() and selected["selected"] and selected["owner"] == 1 and selected["position"] == first.global_position, "marker refresh reflects selected-unit emphasis, ownership and world position")
	var hostile := battle.units[3]
	var marker := _marker(hostile.get_instance_id())
	_check(not marker.is_empty() and marker["owner"] == 2 and not marker["selected"], "hostile unit marker uses current ownership without friendly selection")
	var id := first.get_instance_id()
	first.queue_free()
	await _frames(8)
	_check(_marker(id).is_empty() and _marker_count("unit") == battle.units.size(), "queue_free removes departed unit marker through current field registry")
	var second := battle.units[0]
	id = second.get_instance_id()
	await physics_frame
	second.combat.health.apply_damage(10000, hostile)
	await _frames(8)
	_check(_marker(id).is_empty(), "actual combat death removes unit marker")
	var cache := battle.caches[0]
	id = cache.get_instance_id()
	cache.take_silent(cache.remaining)
	cache.refresh_presentation()
	cache.changed.emit()
	await _frames(8)
	marker = _marker(id)
	_check(not marker.is_empty() and marker["kind"] == "supply" and marker["depleted"] and battle.contains_cache(cache), "depleted cache retains a depleted marker and its original world footprint")
	var site := await _ready_site(await _place())
	if site == null: return
	id = site.building().get_instance_id()
	await _frames(8)
	_check(_marker_count("site") == 1 and _marker(id).get("kind") == "site", "paid committed construction site appears before completion")
	if not await _complete_site(site): return
	await _frames(8)
	_check(_marker_count("site") == 0 and _marker(id).get("kind") == "barracks", "construction completion changes same building marker into barracks")
	var pending := await _ready_site(await _place_factory(SECOND))
	if pending == null: return
	var pending_id := pending.building().get_instance_id()
	await _frames(8)
	_check(_marker(pending_id).get("kind") == "site", "factory construction uses a committed site marker")
	await _cleanup_site(pending)
	await _frames(8)
	_check(_marker(pending_id).is_empty(), "ordinary cancellation removes site marker without a ghost structure")
	await physics_frame
	TeamRules.damage_target(battle, 2, site.building(), 10000, hostile)
	await _frames(8)
	_check(_marker(id).is_empty() and _marker_count("barracks") == 0 and battle.result == BaseAssaultField.Result.RUNNING, "ordinary nonobjective structure destruction removes marker without ending match")


func _tactical_loop() -> void:
	# Normal 1000 credits, both normal building costs, normal training and actual
	# supply deposits. The 600s assault delay is the only scenario timing override.
	await _fresh_combined(1000, 600)
	root.size = Vector2i(1280, 720)
	var earned := {"amount": 0}
	for truck in battle.collectors:
		truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
			if transfer.kind == HarvestTransfer.Kind.DEPOSIT: earned["amount"] += transfer.amount)
		battle.selection.select_clicked(truck, truck != battle.collectors[0])
	_check(_complete(battle.issue_harvest(battle.caches[0])), "integrated existing collectors receive ordinary supply harvesting")
	var panel := battle.production_panel as ConstructionPanel
	battle.selection.select_building(battle.headquarters)
	await _click(panel.factory_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _click(_world_screen(FIRST), MOUSE_BUTTON_LEFT)
	var factory_site := await _ready_site(battle.placement.last_result)
	if factory_site == null: return
	await _frames(8)
	_check(_marker(factory_site.building().get_instance_id()).get("kind") == "site", "integrated viewport-built factory appears as committed site")
	if not await _complete_site(factory_site): return
	var factory := factory_site.building()
	var barrack_site := await _ready_site(await _place(SECOND))
	if barrack_site == null or not await _complete_site(barrack_site): return
	var barrack := barrack_site.building()
	await _frames(8)
	_check(_marker(factory.get_instance_id()).get("kind") == "vehicle_factory" and _marker(barrack.get_instance_id()).get("kind") == "barracks", "both normally completed producers have distinct structure markers")
	var army: Array[RTSUnit] = []
	for building in [barrack, factory]:
		if not await _until(func() -> bool: return battle.credits.balance(1) >= building.recipe.credit_cost, 40, "real deposits afford next integrated production purchase"): return
		var producer: UnitProduction = building.production
		_check(producer.set_rally(1, Vector3(-5 + army.size() * 2, 0, 2)).accepted, "integrated producer accepts normal clear rally")
		battle.selection.select_building(building)
		await _click(panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		_check(producer.count() == 1, "viewport Train pays for actual %s" % building.recipe.display_name)
		if not await _until(func() -> bool: return producer.count() == 0, 9, "actual timed production deploys %s" % building.recipe.display_name): return
		var unit := _last_unit(producer)
		if unit == null:
			_check(false, "integrated deployed unit remains registered")
			return
		army.append(unit)
		if army.size() == 1:
			battle.selection.select_clicked(unit, false)
			await _tactical_key(3, true)
	for truck in battle.collectors: truck.stop()
	_check(army.size() == 2 and army[0].combat_weapon == CombatField.RIFLE and army[1].combat_weapon == CombatField.ROCKET and battle.credits.balance(1) == 1000 + earned["amount"] - 1350, "ordinary construction and real paid Rifle/Rocket production conserve earned and starting credits")
	_check(battle.control_groups.group_members(3) == [army[0]], "newly produced Rocket never automatically joins the existing Rifle group")
	battle.selection.select_clicked(army[0], false)
	battle.selection.select_clicked(army[1], true)
	var versions := [army[0].order_version, army[1].order_version]
	await _tactical_key(3, true)
	battle.selection.select_building(factory)
	await _tactical_key(3)
	_check(battle.selection.selected_units() == army and battle.selection.selected_building() == null and [army[0].order_version, army[1].order_version] == versions, "viewport Ctrl+3 assignment and 3 recall select both produced types without mutating rally orders")
	await _click(_minimap_point(Vector3(12, 0, -5)), MOUSE_BUTTON_RIGHT)
	_check(_complete(battle.last_command_result) and battle.last_command_result.accepted_ids.size() == 2 and army[0].assigned_destination != army[1].assigned_destination, "recalled produced army accepts real distinct minimap ground Move")
	if not await _until(func() -> bool: return army.all(func(unit: RTSUnit) -> bool: return is_instance_valid(unit) and unit.movement_state == RTSUnit.MovementState.ARRIVED), 25, "produced army traverses actual navigation to minimap staging destinations"): return
	await _tactical_capture("m8_produced_army")
	var damage := {"rifle": 0.0, "rocket": 0.0}
	battle.enemy_headquarters.health.damaged.connect(func(amount: float, source: Node) -> void:
		if source is RTSUnit and army.has(source):
			damage["rocket" if source.combat_weapon == CombatField.ROCKET else "rifle"] += amount)
	_check(_complete(battle.issue_attack(battle.enemy_headquarters)), "produced group accepts ordinary existing HQ combat command")
	if not await _until(func() -> bool: return battle.result != BaseAssaultField.Result.RUNNING, 65, "produced Rifle and Rocket destroy full-health enemy HQ through actual weapons"): return
	_check(battle.result == BaseAssaultField.Result.VICTORY and battle.result_overlay.visible and damage["rifle"] > 0 and damage["rocket"] > 0, "integrated produced army inflicts both weapon types and reaches visible victory")
	await _frames(8)
	_check(_marker_count("headquarters") == 1, "destroyed enemy objective marker disappears at match result")
	var old_map: WeakRef = weakref(battle.tactical_minimap)
	var old_groups: WeakRef = weakref(battle.control_groups)
	var old_ids: Array[int] = []
	for marker in battle.tactical_minimap.markers: old_ids.append(marker["identity"])
	var batch := battle.last_command_result
	var camera := battle.camera_rig.position
	versions = [army[0].order_version, army[1].order_version]
	var selected := battle.selection.selected_units()
	await _click(_minimap_point(Vector3(-20, 0, 15)), MOUSE_BUTTON_LEFT)
	await _click(_minimap_point(Vector3(-20, 0, 15)), MOUSE_BUTTON_RIGHT)
	await _tactical_key(3)
	await _tactical_key(4, true)
	_check(not battle.gameplay_enabled and battle.camera_rig.position == camera and battle.last_command_result == batch and [army[0].order_version, army[1].order_version] == versions and battle.selection.selected_units() == selected, "frozen-result minimap and keyboard input cannot move camera, replace selection or dispatch orders")
	await _tactical_capture("m8_victory")
	await _click(battle.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(8)
	battle = current_scene as BaseAssaultField
	field = battle
	world = battle
	harvest = battle
	battle.camera_rig.edge_scrolling_enabled = false
	_check(old_map.get_ref() == null and old_groups.get_ref() == null, "viewport Restart disposes old minimap and group controllers")
	_check(battle.scene_file_path == "res://scenes/combined_arms_assault.tscn" and battle.result == BaseAssaultField.Result.RUNNING and battle.credits.balance(1) == 1000 and battle.units.size() == 8 and battle._producers.is_empty(), "Restart restores exact combined-arms playable defaults")
	var clean := battle.tactical_minimap.markers.size() == 12
	for marker in battle.tactical_minimap.markers: clean = clean and not old_ids.has(marker["identity"])
	for group in range(1, 10): clean = clean and battle.control_groups.group_members(group).is_empty()
	_check(clean, "Restart contains only fresh entity identities and all nine groups are empty")
	battle.selection.select_clicked(battle.units[0], false)
	camera = battle.camera_rig.position
	await _tactical_key(3)
	await _tactical_key(3)
	print("TACTICAL_RESTART_INPUT: selected=%s expected=%s camera=%s before=%s velocity=%s" % [battle.selection.selected_units(), battle.units[0], battle.camera_rig.position, camera, battle.camera_rig.pan_velocity])
	_check(battle.selection.selected_units() == [battle.units[0]] and battle.camera_rig.position == camera, "reused numeric unit IDs cannot restore previous groups or double-tap state")
	print("TACTICAL_LOOP: earned=%d spent=1350 rifle_damage=%.1f rocket_damage=%.1f" % [earned["amount"], damage["rifle"], damage["rocket"]])
	await _tactical_capture("m8_restarted")
