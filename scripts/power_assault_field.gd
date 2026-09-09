class_name PowerAssaultField
extends BuilderAssaultField
## Power is explicit to this builder/economy extension; the enemy pays normally.

const ENEMY_POWER_PLANT := Rect2(23, -6, 6, 5)
var enemy_power_plant: RTSBuilding


func _physics_process(delta: float) -> void:
	# Commit current membership before construction and this tick's producer work.
	# A synchronous listener may tear down or Restart this field.
	refresh_power()
	if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion():
		return
	super._physics_process(delta)


func _build_field() -> void:
	obstacles.append(ENEMY_POWER_PLANT)
	super._build_field()


func _build_obstacle(index: int, rectangle: Rect2) -> void:
	if rectangle != ENEMY_POWER_PLANT:
		super._build_obstacle(index, rectangle)
		return
	enemy_power_plant = RTSBuilding.new()
	enemy_power_plant.name = "EnemyPowerPlant"
	enemy_power_plant.owner_id = 2
	enemy_power_plant.kind = RTSBuilding.Kind.POWER_PLANT
	enemy_power_plant.definition = power_plant_definition
	enemy_power_plant.recipe = null
	enemy_power_plant.footprint = rectangle.size
	enemy_power_plant.building_height = power_plant_definition.height
	enemy_power_plant.position = Vector3(rectangle.get_center().x, 0, rectangle.get_center().y)
	add_child(enemy_power_plant)
	register_building(enemy_power_plant)
