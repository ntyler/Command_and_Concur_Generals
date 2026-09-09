class_name FortifiedAssaultField
extends AirAssaultField
## Air Assault's opening and paid opponent, with manual player fortifications.

var enemy_barriers: Array[BarrierBuilding] = []


func _ready() -> void:
	# Duplicate settings before economy creation; never change the earlier scenario.
	enemy_config = enemy_config.duplicate() as EnemyEconomyConfig
	enemy_config.breach_enabled = true
	super._ready()
	# Starting barriers participate in dynamic navigation through their registry.
	# Retaining their initial rectangles here would resurrect a destroyed wall.
	for barrier in enemy_barriers:
		for rectangle in barrier.navigation_footprints():
			static_footprints.erase(rectangle)


func _build_field() -> void:
	super._build_field()
	# A small, initially open demonstration line on the southeastern approach.
	# Neither base, resources, producer exits nor the enemy staging area is enclosed.
	_add_starting_barrier(wall_definition, Vector3(0, 0, 18), false)
	_add_starting_barrier(gate_definition, Vector3(6, 0, 18), true)
	_add_starting_barrier(wall_definition, Vector3(12, 0, 18), false)


func _add_starting_barrier(choice: ConstructionDefinition, point: Vector3, opened: bool) -> void:
	var barrier := BarrierBuilding.new()
	barrier.kind = choice.kind
	barrier.definition = choice
	barrier.recipe = null
	barrier.owner_id = 2
	barrier.position = point
	barrier.footprint = choice.footprint
	barrier.building_height = choice.height
	barrier.initial_open = opened
	barrier.name = "Enemy%s%d" % [choice.display_name(), enemy_barriers.size()]
	add_child(barrier)
	register_building(barrier)
	enemy_barriers.append(barrier)
	obstacles.append_array(barrier.navigation_footprints())


func _exit_tree() -> void:
	enemy_barriers.clear()
	super._exit_tree()
