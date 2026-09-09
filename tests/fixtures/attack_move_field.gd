extends ProductionField
## Small empty navigation fixture. No copied scenario, economy loop or enemy AI.


func _unit_count() -> int:
	return 0


func _build_field() -> void:
	obstacles.clear()
	super._build_field()


func add_actor(identity: int, point: Vector3, team: int = 1, rocket: bool = false) -> RTSUnit:
	var unit := RTSUnit.new()
	unit.unit_id = identity
	unit.owner_id = team
	unit.position = point
	unit.combat_weapon = CombatField.ROCKET if rocket else CombatField.RIFLE
	unit.maximum_health = 150.0 if rocket else 100.0
	add_child(unit)
	register_unit(unit)
	return unit


func add_target_building(point: Vector3) -> RTSBuilding:
	var building := RTSBuilding.new()
	building.owner_id = 2
	building.position = point
	building.footprint = Vector2(2, 2)
	add_child(building)
	register_building(building)
	building.enable_damage(100.0)
	return building
