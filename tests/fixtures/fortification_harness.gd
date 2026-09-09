extends "res://tests/fixtures/air_harness.gd"
## M16 fixtures reuse the existing simulation watchdog, input, layout, physics
## and paid builder helpers. Extra funds/paused enemies are instance-only.

const WALL: ConstructionDefinition = preload("res://construction/wall.tres")
const GATE: ConstructionDefinition = preload("res://construction/gate.tres")
const FORT_GATE_POINT := Vector3(-14, 0, 15)
const FORT_WALL_POINT := Vector3(-20, 0, 15)
var fort: FortifiedAssaultField


func _adopt_fort(value: FortifiedAssaultField) -> void:
	fort = value
	air = value
	_adopt_defense(value)


func _fresh_fort(funds: int = 6000, live_enemy: bool = false, defer_wave: bool = false) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	_adopt_fort(load("res://scenes/fortified_assault.tscn").instantiate() as FortifiedAssaultField)
	fort.starting_credits = funds
	if defer_wave or not live_enemy:
		fort.enemy_config = fort.enemy_config.duplicate(true) as EnemyEconomyConfig
		fort.enemy_config.first_wave_time = 600.0
		fort.sortie_delay = 600.0
	root.add_child(fort)
	current_scene = fort
	fort.camera_rig.edge_scrolling_enabled = false
	if not live_enemy:
		fort.enemy_controller.set_physics_process(false)
		fort.enemy_battery.set_physics_process(false)
		fort.enemy_air_defense.set_physics_process(false)
		for actor in fort.units:
			if actor.owner_id == 2:
				actor.stop()
				actor.set_physics_process(false)
	await _until(func() -> bool: return not fort.construction.navigation.blocked and _builder_navigation_current(), 3, "fortification opening synchronizes current navigation")
	_check(fort.wall_definition == WALL and fort.gate_definition == GATE and fort.builder_construction_enabled and fort.power_enabled, "fortification composes configurable barriers with inherited builder and power systems")
	_check(fort.credits.balance(1) == funds and fort.construction.sites.is_empty() and _player_builders().size() == 1 and _player_barriers().is_empty(), "opening has original builder, configured wallet and no free player perimeter")
	_check(_grid_is(1, 0, 0) and _grid_is(2, 10, 8), "barrier scenario preserves both inherited owner power totals")
	_check(fort.contains_unit(fort.enemy_helicopter) and fort.enemy_helicopter.global_position.y == 8, "declared original enemy aircraft remains airborne")


func _player_barriers() -> Array[RTSBuilding]:
	return fort.registered_buildings().filter(func(body: RTSBuilding) -> bool: return body.owner_id == 1 and body is BarrierBuilding)


func _fort_build(actor: Bulldozer, definition: ConstructionDefinition, point: Vector3 = FORT_GATE_POINT, orientation: int = 0) -> BarrierBuilding:
	fort.selection.select_clicked(actor, false)
	await physics_frame
	var result := fort.construction.place(1, actor, definition, point, orientation)
	var site := await _builder_arrival(result)
	if site == null or not await _builder_complete(site): return null
	var barrier := site.building() as BarrierBuilding
	_check(barrier != null and site.elapsed == definition.duration and barrier.health.current == definition.maximum_health, "paid barrier completes exact configured builder duration and health")
	_check(not site.rectangle.grow(actor.agent.radius).has_point(Vector2(actor.global_position.x, actor.global_position.z)) and actor.assigned_site_id == 0, "builder completes outside the full barrier footprint and releases its assignment")
	return barrier


func _fort_fixture(definition: ConstructionDefinition, point: Vector3 = FORT_GATE_POINT, owner: int = 1, orientation: int = 0, initially_open: bool = false) -> BarrierBuilding:
	# Explicit completed-body fixture for isolated combat/navigation/lifecycle.
	# Earned integration exclusively uses ordinary paid construction above.
	var body := BarrierBuilding.new()
	body.name = "IsolatedFortification"
	body.definition = definition
	body.kind = definition.kind
	body.owner_id = owner
	body.orientation_degrees = orientation
	body.footprint = definition.oriented_footprint(orientation)
	body.building_height = definition.height
	body.recipe = null
	body.position = point
	body.initial_open = initially_open
	fort.add_child(body)
	fort.register_building(body)
	fort.construction._request_navigation()
	return body


func _fort_gate_ready(gate: BarrierBuilding, opening: bool) -> bool:
	return is_instance_valid(gate) and fort.contains_building(gate) and gate.is_alive() and gate.physical_open == opening and gate.requested_open == opening and gate.effective_ready and not gate.navigation_pending and not fort.construction.navigation.blocked


func _fort_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m16/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/m16/screenshots/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual M16 viewport " + label)
