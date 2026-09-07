class_name CollectorTruck
extends RTSUnit
## Harvesting submits ordinary movement orders; only RTSUnit moves this body.

@export var cargo_capacity: int = 100
@export var loading_amount: int = 25
@export var loading_interval: float = 1.0
@export var unloading_duration: float = 1.0
@export var interaction_distance: float = 0.3
var harvesting: CollectorHarvest


func _init() -> void:
	damageable = true
	unit_display_name = "Collector"
	maximum_health = 150.0
	movement_speed = 4.0
	combat_weapon = null
	retaliation_enabled = false


func _ready() -> void:
	super._ready()
	harvesting = CollectorHarvest.new(self)
	availability_changed.connect(harvesting.on_availability_changed)


func _build_visual() -> void:
	_add_box(Vector3(0.85, 0.25, 1.5), Vector3(0, 0.38, 0), Color("42c5cc"))
	_add_box(Vector3(0.8, 0.6, 0.6), Vector3(0, 0.8, -0.46), Color("b3e7df"))
	_add_box(Vector3(0.78, 0.35, 0.75), Vector3(0, 0.67, 0.33), Color("ffd680"))
	for x in [-0.46, 0.46]:
		for z in [-0.5, 0.5]:
			_add_box(Vector3(0.22, 0.32, 0.32), Vector3(x, 0.24, z), Color("263c49"))


func move_to(destination: Vector3, combat_pursuit: bool = false) -> bool:
	if not TeamRules.is_combat_member(gameplay_field, self):
		return false
	var work := harvesting
	var version := work.interrupt()
	var accepted := super.move_to(destination, combat_pursuit)
	work.publish(version)
	return accepted


func stop() -> bool:
	if not TeamRules.is_combat_member(gameplay_field, self):
		return false
	var work := harvesting
	var version := work.interrupt()
	var accepted := super.stop()
	work.publish(version)
	return accepted


func harvest_move(point: Vector3) -> bool:
	return super.move_to(point)


func _physics_process(delta: float) -> void:
	var work := harvesting
	super._physics_process(delta)
	if work != null and is_instance_valid(self) and (not navigation_suspended or movement_state == MovementState.FAILED):
		work.advance(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and harvesting != null:
		harvesting.close()
