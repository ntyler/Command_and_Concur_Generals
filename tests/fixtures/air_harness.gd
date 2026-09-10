extends "res://tests/fixtures/defense_harness.gd"
## Load fixture assets per runner instance: compile-time preloads across this
## inherited harness retain the cyclic gameplay script graph at engine shutdown.
## M15 focused fixtures. Extra funds/paused hostiles are declared instance-only;
## the earned integration passes1000 and uses ordinary finite-supply deposits.

var AIRFIELD: ConstructionDefinition = load("res://construction/airfield.tres")
var AIR_DEFENSE: ConstructionDefinition = load("res://construction/air_defense_battery.tres")
var HELICOPTER_RECIPE: ProductionDefinition = load("res://production/attack_helicopter.tres")
var air: AirAssaultField


func _fresh_air(funds: int = 6000, live_enemy: bool = false, defer_wave: bool = false) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	air = load("res://scenes/air_assault.tscn").instantiate() as AirAssaultField
	air.starting_credits = funds
	if defer_wave or not live_enemy:
		air.enemy_config = air.enemy_config.duplicate(true) as EnemyEconomyConfig
		air.enemy_config.first_wave_time = 600.0
		air.sortie_delay = 600.0
	_adopt_defense(air)
	root.add_child(air)
	current_scene = air
	air.camera_rig.edge_scrolling_enabled = false
	if not live_enemy:
		air.enemy_controller.set_physics_process(false)
		air.enemy_battery.set_physics_process(false)
		air.enemy_air_defense.set_physics_process(false)
		for actor in air.units:
			if actor.owner_id == 2:
				actor.stop()
				actor.set_physics_process(false)
	await _until(_builder_navigation_current, 2, "air opening synchronizes inherited navigation")
	await physics_frame
	_check(air.airfield_definition == AIRFIELD and air.air_defense_definition == AIR_DEFENSE and air.builder_construction_enabled and air.power_enabled, "air scenario composes builder and shared owner power")
	_check(_grid_is(1, 0, 0) and _grid_is(2, 10, 8), "opening player has zero demand; enemy plant powers Barracks, ground defense and AA normally")
	_check(air.credits.balance(1) == funds and air.construction.sites.is_empty() and _player_aircraft().is_empty(), "configured opening has no prebuilt player Airfield or aircraft")
	_check(air.contains_unit(air.enemy_helicopter) and air.enemy_helicopter.global_position == AirAssaultField.ENEMY_AIR_START and not air.enemy_helicopter.call("is_taking_off"), "exactly one declared enemy helicopter starts genuinely airborne")
	_check(air.flight_plane_clearance(), "entire y8 cruise plane clears all static collision geometry by aircraft radius0.5")


func _player_aircraft() -> Array[RTSUnit]:
	var actors: Array[RTSUnit] = []
	for actor in air.units:
		if air.contains_unit(actor) and actor.owner_id == 1 and actor.has_method("is_taking_off"):
			actors.append(actor)
	return actors


func _air_fixture_building(definition: ConstructionDefinition, point: Vector3 = FIRST, owner: int = 1) -> RTSBuilding:
	# Explicit completion fixture for flight/combat isolation only.
	var body: RTSBuilding = GroundDefenseBattery.new() if definition.kind == RTSBuilding.Kind.AIR_DEFENSE_BATTERY else RTSBuilding.new()
	body.kind = definition.kind
	body.definition = definition
	body.owner_id = owner
	body.footprint = definition.footprint
	body.building_height = definition.height
	body.position = point
	body.recipe = HELICOPTER_RECIPE if definition.kind == RTSBuilding.Kind.AIRFIELD else null
	air.add_child(body)
	air.register_building(body)
	return body


func _air_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m15/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/m15/screenshots/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual M15 viewport " + label)
