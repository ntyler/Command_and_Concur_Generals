class_name EconomyAssaultField
extends BaseAssaultField
## Narrow combined-arms extension; older scenes keep their scripted assault.

const ENEMY_BARRACKS := Rect2(14, 8, 6, 5)
const ENEMY_CACHE := Rect2(15, -22, 4, 3)
const ENEMY_COLLECTORS: Array[Vector3] = [Vector3(22, 0, -18), Vector3(24, 0, -18)]
@export var enemy_config: EnemyEconomyConfig = preload("res://scenarios/enemy_economy.tres")
var enemy_barracks: RTSBuilding
var enemy_cache: SupplyCache
var enemy_controller: EnemyEconomyController


func create_credits() -> PlayerCredits:
	return PlayerCredits.new([1, 2], starting_credits, {2: enemy_config.starting_credits})


func _build_field() -> void:
	obstacles.append_array([ENEMY_BARRACKS, ENEMY_CACHE])
	super._build_field()


func _build_obstacle(index: int, rectangle: Rect2) -> void:
	if rectangle == ENEMY_BARRACKS:
		enemy_barracks = RTSBuilding.new()
		enemy_barracks.name = "EnemyBarracks"
		enemy_barracks.owner_id = 2
		enemy_barracks.footprint = rectangle.size
		enemy_barracks.position = Vector3(rectangle.get_center().x, 0, rectangle.get_center().y)
		add_child(enemy_barracks)
		register_building(enemy_barracks)
	elif rectangle == ENEMY_CACHE:
		enemy_cache = SupplyCache.new()
		enemy_cache.name = "EnemyAssignedSupply"
		enemy_cache.cache_id = 3
		enemy_cache.initial_supplies = enemy_config.cache_contents
		enemy_cache.footprint = rectangle.size
		enemy_cache.position = Vector3(rectangle.get_center().x, 0, rectangle.get_center().y)
		add_child(enemy_cache)
		caches.append(enemy_cache)
		register_cache(enemy_cache)
	else:
		super._build_obstacle(index, rectangle)


func _unit_count() -> int:
	return super._unit_count() + ENEMY_COLLECTORS.size()


func _create_unit(index: int) -> RTSUnit:
	if index < 8:
		return super._create_unit(index)
	var unit := CollectorTruck.new()
	unit.owner_id = 2
	unit.unit_id = index + 1
	unit.name = "EnemyCollector%d" % unit.unit_id
	unit.position = ENEMY_COLLECTORS[index - 8]
	collectors.append(unit)
	return unit


func _ready() -> void:
	super._ready()
	_next_unit = maxi(_next_unit, _unit_count())
	enemy_controller = EnemyEconomyController.new()
	enemy_controller.name = "EnemyEconomy"
	enemy_controller.configure(self, enemy_config)
	add_child(enemy_controller)
	_update_objective()


func uses_scripted_assault() -> bool:
	return false


func _update_objective() -> void:
	if is_instance_valid(objective_label):
		var phase := "Enemy reinforcements active"
		if elapsed < enemy_config.first_wave_time:
			phase = "Earliest enemy assault in %ds" % ceili(enemy_config.first_wave_time - elapsed)
		objective_label.text = "Destroy enemy HQ · Protect your HQ\n" + phase


func protected_areas() -> Array[Rect2]:
	var areas := super.protected_areas()
	if is_instance_valid(enemy_headquarters) and contains_building(enemy_headquarters):
		for access in access_positions(enemy_headquarters):
			var point: Vector3 = access["point"]
			var dock: Vector3 = access["dock"]
			areas.append(Rect2(Vector2(point.x, point.z), Vector2(dock.x - point.x, dock.z - point.z)).abs().grow(0.7))
	if is_instance_valid(enemy_barracks) and contains_building(enemy_barracks):
		areas.append(exit_area(ENEMY_BARRACKS))
	areas.append(Rect2(Vector2(enemy_config.staging_point.x, enemy_config.staging_point.z) - Vector2.ONE * enemy_config.staging_radius, Vector2.ONE * enemy_config.staging_radius * 2))
	return areas

