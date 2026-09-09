class_name BuilderAssaultField
extends EconomyAssaultField
## Intended builder opening; all enemy economy and wave settings are inherited.

var initial_builder: Bulldozer


func _unit_count() -> int:
	return STARTS.size() + 1 + ENEMY_COLLECTORS.size()


func _create_unit(index: int) -> RTSUnit:
	if index < STARTS.size():
		return super._create_unit(index)
	if index == STARTS.size():
		initial_builder = load("res://scenes/bulldozer.tscn").instantiate() as Bulldozer
		initial_builder.unit_id = index + 1
		initial_builder.name = "StartingBulldozer"
		initial_builder.owner_id = 1
		initial_builder.position = COLLECTOR_STARTS[0]
		return initial_builder
	# Preserve the two enemy collectors' original IDs, positions and configuration.
	return super._create_unit(index + 1)


func register_building(building: RTSBuilding) -> void:
	if is_instance_valid(building) and building.kind == RTSBuilding.Kind.HEADQUARTERS and building.owner_id == 1:
		building.recipe = load("res://production/bulldozer.tres") as ProductionDefinition
	super.register_building(building)


func _ready() -> void:
	super._ready()
	# IDs 9 and 10 remain assigned to the unchanged enemy collectors.
	_next_unit = maxi(_next_unit, STARTS.size() + COLLECTOR_STARTS.size() + ENEMY_COLLECTORS.size())
	selection.select_clicked(initial_builder, false)
