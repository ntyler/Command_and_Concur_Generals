extends "res://tests/fixtures/fortification_harness.gd"
## M17 isolated mechanics fixtures retain the real field, health, power and
## physics authorities. Extra funds, completed bodies and shorter configured
## timers are explicit fixtures only; tempest_integration_checks earns its path.

const TEMPEST: ConstructionDefinition = preload("res://construction/tempest_array.tres")
const TEMPEST_POINT := Vector3(-14, 0, 17)
const TEMPEST_TARGET := Vector3(0, 0, 16)
var tempest: SuperweaponAssaultField


func _adopt_tempest(value: SuperweaponAssaultField) -> void:
	tempest = value
	_adopt_fort(value)


func _fresh_tempest(funds: int = 12000, live_enemy: bool = false, defer_wave: bool = false) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	_adopt_tempest(load("res://scenes/superweapon_assault.tscn").instantiate() as SuperweaponAssaultField)
	tempest.starting_credits = funds
	if defer_wave or not live_enemy:
		tempest.enemy_config = tempest.enemy_config.duplicate(true) as EnemyEconomyConfig
		tempest.enemy_config.first_wave_time = 600.0
		tempest.sortie_delay = 600.0
	root.add_child(tempest)
	current_scene = tempest
	tempest.camera_rig.edge_scrolling_enabled = false
	if not live_enemy:
		tempest.enemy_controller.set_physics_process(false)
		tempest.enemy_battery.set_physics_process(false)
		tempest.enemy_air_defense.set_physics_process(false)
		for actor in tempest.units:
			if actor.owner_id == 2:
				actor.stop()
				actor.set_physics_process(false)
	await _until(func() -> bool: return not tempest.construction.navigation.blocked and _builder_navigation_current(), 3, "Tempest opening synchronizes inherited navigation")
	_check(tempest.tempest_definition == TEMPEST and tempest.tempest_strikes != null and tempest.power_enabled and tempest.builder_construction_enabled, "new scenario composes Tempest with original builder and owner grid")
	_check(tempest.credits.balance(1) == funds and tempest.construction.sites.is_empty() and _player_builders().size() == 1, "Tempest fixture starts with declared wallet, original builder and no sites")
	_check(_tempest_facilities(1).is_empty() and _grid_is(1, 0, 0) and _grid_is(2, 10, 8), "opening has no free facility and preserves original owner power totals")


func _tempest_facilities(owner: int) -> Array[RTSBuilding]:
	return tempest.registered_buildings().filter(func(body: RTSBuilding) -> bool: return body is TempestArray and body.owner_id == owner)


func _tempest_fixture(point: Vector3 = TEMPEST_POINT, owner: int = 1, charge_seconds: float = 180.0, warning_seconds: float = 6.0) -> TempestArray:
	# Explicit completed-body fixture; never used by real earned integration.
	var definition := TEMPEST.duplicate(true) as ConstructionDefinition
	definition.charge_duration = charge_seconds
	definition.strike_warning = warning_seconds
	var body := TempestArray.new()
	body.name = "IsolatedTempestArray"
	body.definition = definition
	body.kind = definition.kind
	body.owner_id = owner
	body.footprint = definition.footprint
	body.building_height = definition.height
	body.recipe = null
	body.position = point
	tempest.add_child(body)
	tempest.register_building(body)
	return body


func _tempest_power(owner: int = 1) -> Array[RTSBuilding]:
	return [_power_fixture_building(POWER_PLANT, owner, Vector3(-21, 0, 3)), _power_fixture_building(POWER_PLANT, owner, Vector3(-23, 0, 17))]


func _tempest_ready(source: TempestArray) -> bool:
	return await _until(func() -> bool: return is_instance_valid(source) and source.is_ready(), source.definition.charge_duration + 0.2, "configured Tempest earns readiness through real powered physics ticks")


func _tempest_ground(point: Vector3, owner: int = 2, hitpoints: float = 1500.0) -> RTSUnit:
	# High-health stationary unit is an explicitly isolated damage-count fixture.
	var actor := RTSUnit.new()
	_defense_next_id += 1
	actor.unit_id = _defense_next_id
	actor.owner_id = owner
	actor.position = point
	actor.damageable = true
	actor.maximum_health = hitpoints
	actor.combat_weapon = null
	actor.retaliation_enabled = false
	tempest.add_child(actor)
	tempest.register_unit(actor)
	actor.set_physics_process(false)
	actor.combat.set_physics_process(false)
	return actor


func _tempest_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m17/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/m17/screenshots/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual M17 viewport " + label)
