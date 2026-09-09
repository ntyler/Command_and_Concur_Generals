extends "res://tests/builder_checks.gd"
## M14 isolated fixtures: normal scene with extra configured funds and frozen
## enemy scheduler, registered stationary bodies/mobile targets on clear south
## ground, and labelled physical walls. No shared resources/timers are changed.
## Construction tests use real paid travel/work. The separate earned suite uses
## the original wallet, a paid Collector and finite-cache income without grants.

const DEFENSE: ConstructionDefinition = preload("res://construction/ground_defense_battery.tres")
const POWER_PLANT: ConstructionDefinition = preload("res://construction/power_plant.tres")
const POWER_BARRACKS: ConstructionDefinition = preload("res://construction/barracks.tres")
const POWER_RIFLE: ProductionDefinition = preload("res://production/rifle.tres")
const DEFENSE_POINT := Vector3(-18, 0, 16)
const DEFENSE_TARGET := Vector3(-10, 0, 16)
var defended: DefenseAssaultField
var powered: PowerAssaultField
var _defense_next_id: int = 400

func _fresh_defense(funds: int = 4000, live_enemy: bool = false, defer_wave: bool = false) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	defended = load("res://scenes/defense_assault.tscn").instantiate() as DefenseAssaultField
	defended.starting_credits = funds
	if defer_wave:
		# Explicit instance-only integration isolation; normal scene stays at90s.
		defended.enemy_config = defended.enemy_config.duplicate(true) as EnemyEconomyConfig
		defended.enemy_config.first_wave_time = 600.0
	_adopt_defense(defended)
	root.add_child(defended)
	current_scene = defended
	defended.camera_rig.edge_scrolling_enabled = false
	if not live_enemy:
		defended.enemy_controller.set_physics_process(false)
		defended.enemy_battery.set_physics_process(false)
		for actor in defended.units:
			if actor.owner_id == 2:
				actor.stop()
				actor.set_physics_process(false)
	await _until(_builder_navigation_current, 2, "defense navigation synchronizes actual opening actors")
	_check(defended.defense_definition == DEFENSE and defended.power_enabled and defended.builder_construction_enabled, "defense scenario opts into configured battery, real power and builder authority")
	_check(_grid_is(1, 0, 0) and _grid_is(2, 10, 5), "opening has no player demand and enemy plant normally powers Barracks plus one battery")
	_check(defended.credits.balance(1) == funds and _player_builders().size() == 1 and defended.construction.sites.is_empty(), "fresh defense fixture retains configured wallet, original builder and no sites")
	_check(defended.registered_buildings().filter(func(body: RTSBuilding) -> bool: return body is GroundDefenseBattery and body.owner_id == 1).is_empty(), "player starts without a prebuilt battery")


func _adopt_defense(value: DefenseAssaultField) -> void:
	defended = value
	powered = value
	builders = value
	battle = value
	world = value
	harvest = value
	field = value


func _grid_is(owner: int, generation: int, demand: int) -> bool:
	var value := powered.power_snapshot(owner)
	return value.generated == generation and value.required == demand and value.low_power == (generation < demand) and is_equal_approx(value.multiplier, 0.5 if generation < demand else 1.0)


func _power_fixture_building(definition: ConstructionDefinition, owner: int = 1, point: Vector3 = FIRST) -> RTSBuilding:
	# Explicit isolated accounting/timing fixture; actual body/health/grid rules.
	var body := RTSBuilding.new()
	body.name = "DefensePowerFixture"
	body.kind = definition.kind
	body.definition = definition
	body.owner_id = owner
	body.footprint = definition.footprint
	body.building_height = definition.height
	body.position = point
	match definition.kind:
		RTSBuilding.Kind.POWER_PLANT: body.recipe = null
		RTSBuilding.Kind.VEHICLE_FACTORY: body.recipe = ROCKET_RECIPE
		RTSBuilding.Kind.SUPPLY_DEPOT: body.recipe = COLLECTOR_RECIPE
		_: body.recipe = POWER_RIFLE
	powered.add_child(body)
	powered.register_building(body)
	return body


func _power_build(actor: Bulldozer, definition: ConstructionDefinition, point: Vector3 = FIRST) -> ConstructionBuilding:
	var site := await _builder_arrival(await _builder_place(actor, definition, point))
	if site == null or not await _builder_complete(site): return null
	return site.building() as ConstructionBuilding


func _defense_fixture(owner: int = 1, point: Vector3 = DEFENSE_POINT) -> GroundDefenseBattery:
	# Isolated completion fixture: real stationary body/health/grid registration.
	var battery := GroundDefenseBattery.new()
	battery.name = "IsolatedDefenseBattery"
	battery.owner_id = owner
	battery.kind = DEFENSE.kind
	battery.definition = DEFENSE
	battery.footprint = DEFENSE.footprint
	battery.building_height = DEFENSE.height
	battery.recipe = null
	battery.position = point
	defended.add_child(battery)
	defended.register_building(battery)
	return battery


func _defense_mobile(point: Vector3 = DEFENSE_TARGET, owner: int = 2, kind: String = "rifle") -> RTSUnit:
	# Explicit isolated unit/layout fixture; normal behavior and weapon data.
	var actor: RTSUnit
	match kind:
		"collector": actor = CollectorTruck.new()
		"builder": actor = Bulldozer.new()
		_: actor = RTSUnit.new()
	_defense_next_id += 1
	actor.unit_id = _defense_next_id
	actor.owner_id = owner
	actor.position = point
	if kind == "rocket": actor.combat_weapon = load("res://weapons/rocket.tres")
	elif kind == "rifle": actor.combat_weapon = load("res://weapons/rifle.tres")
	actor.retaliation_enabled = false
	defended.add_child(actor)
	defended.register_unit(actor)
	actor.set_physics_process(false)
	return actor


func _defense_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m14/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/m14/screenshots/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual M14 viewport " + label)


