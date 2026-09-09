class_name EnemyEconomyController
extends Node
## A bounded owner-2 reinforcement coordinator. Existing components own all work.

signal job_accepted(job_id: int, paid: int)
signal troop_deployed(job_id: int, unit_id: int)
signal wave_launched(time: float, result: CommandBatchResult)
const OWNER: int = 2
var config: EnemyEconomyConfig
var _field: WeakRef
var _producer: UnitProduction
var _cache: WeakRef
var _clock: float = 0.0
var _waiting_since: float = -1.0
var _last_launch: float = -INF
var _planning: bool = false
var _dispatching: bool = false
var _stopped: bool = false
var _initialized: bool = false
var _generation: int = 0
var _jobs: Dictionary[int, bool] = {}
var _troops: Dictionary[int, Dictionary] = {} # Weak live produced units only.
var _enqueue_active: bool = false
var _early_deployments: Array[Vector2i] = []
var plans: int = 0
var accepted_jobs: int = 0
var deployments: int = 0
var launches: int = 0
var harvest_assignments: int = 0
var last_wave: CommandBatchResult
var status: String = "Waiting for navigation"


func configure(field: EconomyAssaultField, settings: EnemyEconomyConfig) -> void:
	_field = weakref(field)
	config = settings
	_producer = field.enemy_barracks.production
	_cache = weakref(field.enemy_cache)


func field_node() -> EconomyAssaultField:
	return _field.get_ref() as EconomyAssaultField if _field != null else null


func _ready() -> void:
	process_physics_priority = 100 # After normal queues and movement; before results.
	field_node().match_finished.connect(_on_result)
	_producer.deployed.connect(_on_deployed)


func _live() -> bool:
	var field := field_node()
	return not _stopped and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(field) and field._attack_move_context_active() and field.enemy_controller == self and field.result == BaseAssaultField.Result.RUNNING and not field._restarting and field._lost_headquarters.is_empty()


func _owned_producer() -> bool:
	return _live() and _producer != null and _producer.is_available() and _producer.building().owner_id == OWNER and _producer.building().kind == RTSBuilding.Kind.BARRACKS and _producer.building().recipe == preload("res://production/rifle.tres")


func _physics_process(delta: float) -> void:
	if not _live():
		return
	_clock += delta
	if _clock + 0.000001 < maxf(0.01, config.planning_interval):
		return
	_clock = 0.0
	plan()


func plan() -> void:
	if _planning or not _live():
		return
	_planning = true
	plans += 1
	_plan()
	if is_instance_valid(self):
		_planning = false


func _plan() -> void:
	var field := field_node()
	if field.construction.navigation.blocked or NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) == 0:
		return
	if not _initialized:
		_initialized = true # One assignment attempt; bounded trip failures remain visible.
		var recipients: Array = []
		for unit in field.units:
			if unit is CollectorTruck and TeamRules.is_controlled(field, unit, OWNER):
				recipients.append(unit)
		var cache := _cache.get_ref() as SupplyCache
		if is_instance_valid(cache):
			var assigned := field.issue_harvest_for(OWNER, recipients, cache)
			if not is_instance_valid(self) or not _live(): return
			harvest_assignments += assigned.accepted_ids.size()
	_prune()
	if _owned_producer():
		# Reserve one normal rally slot for the next deployment. Refresh only when
		# absent or after deployment; never retarget an already deployed actor.
		if not _producer.has_rally:
			_prepare_rally()
		if not is_instance_valid(self) or not _live(): return
		# At most queue capacity enqueues in this plan, even with recursive callbacks.
		var budget := _producer.building().queue_capacity if _owned_producer() else 0
		for attempt in budget:
			if not _owned_producer() or not _producer.has_rally: break
			if population() >= config.population_limit: break
			var recipe := _producer.building().recipe
			_enqueue_active = true
			var accepted := _producer.enqueue(OWNER, recipe)
			if not is_instance_valid(self): return
			_enqueue_active = false
			if not _live(): return
			if not accepted.accepted: break
			accepted_jobs += 1
			_jobs[accepted.job_id] = true
			var pending := _early_deployments.duplicate()
			_early_deployments.clear()
			for pair in pending:
				_record_deployment(pair.x, pair.y)
				if not is_instance_valid(self) or not _live(): return
			job_accepted.emit(accepted.job_id, recipe.credit_cost)
			if not is_instance_valid(self) or not _live(): return
	if _live():
		launch_ready()


func population() -> int:
	var field := field_node()
	if not is_instance_valid(field): return 0
	var total := 0
	for unit in field.units:
		if field.contains_unit(unit) and unit.owner_id == OWNER and is_instance_valid(unit.combat) and is_instance_valid(unit.combat.weapon):
			total += 1
	for producer in field._producers.values():
		for job in producer.jobs():
			if job["payer"] == OWNER: total += 1
	return total


func _prepare_rally() -> void:
	if not _owned_producer(): return
	var field := field_node()
	var reserved := PackedVector3Array()
	for unit in field.units:
		if field.contains_unit(unit): reserved.append(field._reserved_command_destination(unit))
	var slots := field.destinations.generate_slots(field.get_world_3d().get_navigation_map(), config.staging_point, 1, reserved)
	if not slots.is_empty() and slots[0].distance_to(config.staging_point) <= config.staging_radius:
		_producer.set_rally(OWNER, slots[0])


func _on_deployed(job_id: int, unit_id: int, _rally_accepted: bool) -> void:
	if not _live(): return
	if _enqueue_active:
		_early_deployments.append(Vector2i(job_id, unit_id))
		return
	_record_deployment(job_id, unit_id)


func _record_deployment(job_id: int, unit_id: int) -> void:
	if not _live() or not _jobs.has(job_id): return
	_jobs.erase(job_id)
	var field := field_node()
	for unit in field.units:
		if unit.unit_id == unit_id and field.can_attack_move_for(OWNER, unit):
			_troops[unit_id] = {"unit": weakref(unit), "dispatched": false, "job": job_id}
			deployments += 1
			break
	if _owned_producer(): _prepare_rally()
	if is_instance_valid(self) and _live(): troop_deployed.emit(job_id, unit_id)


func _prune() -> void:
	var field := field_node()
	for id in _troops.keys():
		var unit: RTSUnit = (_troops[id]["unit"] as WeakRef).get_ref() as RTSUnit
		if not is_instance_valid(unit) or not field.can_attack_move_for(OWNER, unit): _troops.erase(id)
	var queued: Dictionary[int, bool] = {}
	if _producer != null:
		for job in _producer.jobs(): queued[job["id"]] = true
	for id in _jobs.keys():
		if not queued.has(id): _jobs.erase(id)


func assembled() -> Array[RTSUnit]:
	var ready: Array[RTSUnit] = []
	if not _live(): return ready
	_prune()
	for id in _troops:
		var entry: Dictionary = _troops[id]
		var unit: RTSUnit = (entry["unit"] as WeakRef).get_ref() as RTSUnit
		if not entry["dispatched"] and not unit.attack_move.active and unit.combat.target_actor() == null and not unit.moving and unit.movement_state == RTSUnit.MovementState.ARRIVED and unit.position.distance_to(config.staging_point) <= config.staging_radius:
			ready.append(unit)
	ready.sort_custom(func(a: RTSUnit, b: RTSUnit) -> bool: return a.unit_id < b.unit_id)
	return ready


func launch_ready() -> void:
	if _dispatching or not _live(): return
	var ready := assembled()
	var field := field_node()
	if ready.is_empty():
		_waiting_since = -1.0
		return
	if _waiting_since < 0.0: _waiting_since = field.elapsed
	if field.elapsed + 0.000001 < config.first_wave_time or field.elapsed - _last_launch + 0.000001 < config.wave_interval: return
	var maximum := maxi(1, config.maximum_wave_size)
	var preferred := clampi(config.preferred_wave_size, 1, maximum)
	if ready.size() < preferred and field.elapsed - _waiting_since + 0.000001 < config.partial_wait: return
	ready.resize(mini(ready.size(), maximum))
	var generation := _generation
	_dispatching = true
	var result := field.issue_attack_move_for(OWNER, ready, config.assault_approach)
	if not is_instance_valid(self): return
	_dispatching = false
	if generation != _generation or not _live(): return
	last_wave = result
	if not result.has_acceptance():
		status = "Wave destination rejected"
		return
	for id in result.accepted_ids:
		if _troops.has(id): _troops[id]["dispatched"] = true
	_last_launch = field.elapsed
	_waiting_since = -1.0
	launches += 1
	status = "Reinforcements active"
	print("ENEMY_WAVE: time=%.3f accepted=%s intended=%s superseded=%s" % [_last_launch, result.accepted_ids, result.intended_ids, result.superseded])
	wave_launched.emit(_last_launch, result)


func _on_result(_result: BaseAssaultField.Result) -> void:
	stop()


func stop() -> void:
	_stopped = true
	_generation += 1
	_jobs.clear()
	_troops.clear()
	_early_deployments.clear()
	status = "Stopped"


func _exit_tree() -> void:
	stop()
	if _producer != null and _producer.deployed.is_connected(_on_deployed): _producer.deployed.disconnect(_on_deployed)
	var field := field_node()
	if is_instance_valid(field) and field.match_finished.is_connected(_on_result): field.match_finished.disconnect(_on_result)
	_producer = null
	_field = null
	_cache = null
