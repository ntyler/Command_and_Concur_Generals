class_name DefenseAssaultField
extends PowerAssaultField
## The normal powered economy with one explicit, limited-approach enemy defense.

const ENEMY_DEFENSE := Rect2(9, -8, 6, 5)
var enemy_battery: GroundDefenseBattery


func _build_field() -> void:
	# Western center approach is guarded; the east edge and northern approach to
	# the Power Plant remain outside this battery's twelve-unit firing range.
	obstacles.append(ENEMY_DEFENSE)
	super._build_field()


func _build_obstacle(index: int, rectangle: Rect2) -> void:
	if rectangle != ENEMY_DEFENSE:
		super._build_obstacle(index, rectangle)
		return
	enemy_battery = GroundDefenseBattery.new()
	enemy_battery.name = "EnemyGroundDefenseBattery"
	enemy_battery.owner_id = 2
	enemy_battery.kind = RTSBuilding.Kind.GROUND_DEFENSE_BATTERY
	enemy_battery.definition = defense_definition
	enemy_battery.recipe = null
	enemy_battery.footprint = rectangle.size
	enemy_battery.building_height = defense_definition.height
	enemy_battery.position = Vector3(rectangle.get_center().x, 0, rectangle.get_center().y)
	add_child(enemy_battery)
	register_building(enemy_battery)
