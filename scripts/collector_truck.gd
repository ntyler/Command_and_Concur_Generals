class_name CollectorTruck
extends RTSUnit
## Harvesting submits ordinary movement orders; only RTSUnit moves this body.

@export var cargo_capacity: int = 100
@export var loading_amount: int = 25
@export var loading_interval: float = 1.0
@export var unloading_duration: float = 1.0
@export var interaction_distance: float = 0.3
@export var collection_radius: float = 24.0
var harvesting: CollectorHarvest
var _deployment_collection: Dictionary = {}


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
	_visual.add_child(GeneralsVisuals.create("collector", Vector3(1.15, 1.15, 1.8), owner_id))


func move_to(destination: Vector3, combat_pursuit: bool = false, preserve_attack_move: bool = false) -> bool:
	if not TeamRules.is_combat_member(gameplay_field, self):
		return false
	_cancel_deployment_collection()
	var work := harvesting
	var version := work.interrupt()
	var accepted := super.move_to(destination, combat_pursuit, preserve_attack_move)
	work.publish(version)
	return accepted


func stop() -> bool:
	if not TeamRules.is_combat_member(gameplay_field, self):
		return false
	_cancel_deployment_collection()
	var work := harvesting
	var version := work.interrupt()
	var accepted := super.stop()
	work.publish(version)
	return accepted


func harvest_move(point: Vector3) -> bool:
	return super.move_to(point)


func stage_deployment_collection(origin: Vector3, expected_order: int, expected_generation: int) -> void:
	if not origin.is_finite() or harvesting == null or order_version != expected_order or harvesting.generation != expected_generation or not gameplay_field is HarvestField:
		return
	# Capture values, not the producer: a deployed truck outlives its Supply Depot.
	_deployment_collection = {"origin": origin, "owner": owner_id, "order": expected_order, "generation": expected_generation, "retry": 0.0}


func deployment_collection_pending() -> bool:
	return not _deployment_collection.is_empty() and harvesting != null and order_version == _deployment_collection.order and harvesting.generation == _deployment_collection.generation


func _cancel_deployment_collection() -> void:
	if _deployment_collection.is_empty():
		return
	var generation: int = _deployment_collection.generation
	_deployment_collection.clear()
	if is_instance_valid(gameplay_field) and gameplay_field is HarvestField:
		(gameplay_field as HarvestField).release_collection_wait(self, generation)


func _advance_deployment_collection(delta: float) -> void:
	if _deployment_collection.is_empty():
		return
	var field := gameplay_field as HarvestField
	if not is_instance_valid(field) or not field.contains_unit(self) or not is_alive() or owner_id != _deployment_collection.owner or not deployment_collection_pending():
		_cancel_deployment_collection()
		return
	if not field.gameplay_enabled or navigation_suspended or moving:
		return
	# Finish the producer's ordinary rally before assigning work. A rejected or
	# blocked rally, and a producer with no rally, use the same local lane-clear
	# waiting positions as idle collectors and the existing movement controller.
	if movement_state == MovementState.ARRIVED and field.collection_wait_position_clear(self, global_position):
		var origin: Vector3 = _deployment_collection.origin
		_deployment_collection.clear()
		field.release_access(self)
		harvesting.start_local_collection(origin)
		return
	_deployment_collection.retry -= delta
	if _deployment_collection.retry > 0.0:
		return
	_deployment_collection.retry = 1.0
	var candidate := field.collection_wait_point(self)
	if candidate.is_empty():
		return
	var version := harvesting.generation
	var expected_order := order_version + 1
	# Store the expected version before movement can emit synchronous callbacks.
	_deployment_collection.order = expected_order
	var accepted := harvest_move(candidate[0])
	if not is_instance_valid(self):
		return
	if not accepted or harvesting.generation != version or order_version != expected_order:
		_cancel_deployment_collection()


func _physics_process(delta: float) -> void:
	var work := harvesting
	super._physics_process(delta)
	if work != null and is_instance_valid(self) and (not navigation_suspended or movement_state == MovementState.FAILED):
		_advance_deployment_collection(delta)
	if work != null and is_instance_valid(self) and (not navigation_suspended or movement_state == MovementState.FAILED):
		work.advance(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and harvesting != null:
		harvesting.close()
