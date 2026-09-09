class_name EnemyEconomyController
extends Node
## A bounded owner-2 reinforcement coordinator. Existing components own all work.

signal job_accepted(job_id: int, paid: int)
signal troop_deployed(job_id: int, unit_id: int)
signal wave_launched(time: float, result: CommandBatchResult)
signal breach_started(target_id: int, result: CommandBatchResult)
signal breach_resumed(result: CommandBatchResult)
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
var breach_dispatches: int = 0
var breach_resumptions: int = 0
var breach_reassessments: int = 0
var breach_candidate_checks: int = 0
var _breach_clock: float = 0.0
var _objectives: Array[Dictionary] = [] # Higher-level intent survives a rejected move.


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
	if config.breach_enabled:
		_breach_clock += delta
		if _breach_clock + 0.000001 >= maxf(0.5, config.breach_reassessment_interval):
			_breach_clock = 0.0
			_reassess_breaches()
			if not is_instance_valid(self) or not _live(): return
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
		if field.contains_unit(unit) and TeamRules.target_domain(unit) == TeamRules.TargetDomain.GROUND and unit.owner_id == OWNER and is_instance_valid(unit.combat) and is_instance_valid(unit.combat.weapon):
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
		if field.contains_unit(unit) and TeamRules.target_domain(unit) == TeamRules.TargetDomain.GROUND: reserved.append(field._reserved_command_destination(unit))
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
	var prior: Dictionary[int, Vector2i] = {}
	for unit in ready:
		prior[unit.unit_id] = Vector2i(unit.order_version, unit.combat.order_version)
	_dispatching = true
	var result := field.issue_attack_move_for(OWNER, ready, config.assault_approach)
	if not is_instance_valid(self): return
	_dispatching = false
	if generation != _generation or not _live(): return
	last_wave = result
	if config.breach_enabled and not result.superseded:
		_retain_objective(ready, result, prior)
	if not result.has_acceptance():
		status = "Wave destination rejected; retaining approach" if config.breach_enabled else "Wave destination rejected"
		return
	for id in result.accepted_ids:
		if _troops.has(id): _troops[id]["dispatched"] = true
	_last_launch = field.elapsed
	_waiting_since = -1.0
	launches += 1
	status = "Reinforcements active"
	print("ENEMY_WAVE: time=%.3f accepted=%s intended=%s superseded=%s" % [_last_launch, result.accepted_ids, result.intended_ids, result.superseded])
	wave_launched.emit(_last_launch, result)


func _retain_objective(recipients: Array[RTSUnit], result: CommandBatchResult, prior: Dictionary[int, Vector2i]) -> void:
	var members: Dictionary[int, Dictionary] = {}
	for unit in recipients:
		if not is_instance_valid(unit) or not _troops.has(unit.unit_id) or not field_node().can_attack_move_for(OWNER, unit):
			continue
		var accepted := result.accepted_ids.has(unit.unit_id)
		if accepted and (not unit.attack_move.active or unit.attack_move.parent_order_id != result.generation):
			continue # Accepted then synchronously superseded is historical only.
		if not accepted and prior[unit.unit_id] != Vector2i(unit.order_version, unit.combat.order_version):
			continue
		members[unit.unit_id] = {"unit": weakref(unit), "mode": "approach" if accepted else "waiting", "move": unit.order_version, "combat": unit.combat.order_version, "parent": result.generation}
		_troops[unit.unit_id]["dispatched"] = true
	if members.is_empty():
		return
	_objectives.append({"members": members, "objective": config.assault_approach, "target": null, "attempted": [], "route_nav": field_node().construction.navigation.generation})
	# Reserving an unsuccessful wave prevents repeated rejected commands and
	# preserves the normal interval for subsequent paid groups, without claiming
	# a movement acceptance or emitting a successful launch event.
	if not result.has_acceptance():
		_last_launch = field_node().elapsed
		_waiting_since = -1.0


func retained_objective_count() -> int:
	return _objectives.size()


func active_breach_target() -> BarrierBuilding:
	for objective in _objectives:
		if objective["target"] is WeakRef:
			var target := (objective["target"] as WeakRef).get_ref() as BarrierBuilding
			if is_instance_valid(target): return target
	return null


func _reassess_breaches() -> void:
	if _dispatching or _planning or not _live() or not Engine.is_in_physics_frame():
		return
	var field := field_node()
	if field.construction.navigation.blocked:
		return # Destruction/opening must synchronize before a resume is admitted.
	breach_reassessments += 1
	var generation := _generation
	for objective in _objectives.duplicate():
		var members: Dictionary = objective["members"]
		var target: BarrierBuilding = (objective["target"] as WeakRef).get_ref() as BarrierBuilding if objective["target"] is WeakRef else null
		var recipients: Array[RTSUnit] = []
		var waiting: Array[RTSUnit] = []
		for id in members.keys():
			var entry: Dictionary = members[id]
			var unit := (entry["unit"] as WeakRef).get_ref() as RTSUnit
			if not is_instance_valid(unit) or not field.can_attack_move_for(OWNER, unit):
				members.erase(id)
				continue
			match entry["mode"]:
				"approach":
					if unit.attack_move.active:
						if unit.attack_move.parent_order_id != entry["parent"]:
							members.erase(id)
							continue
					elif unit.attack_move.status == AttackMoveOrder.Status.FAILED:
						entry["mode"] = "waiting"
						entry["move"] = unit.order_version
						entry["combat"] = unit.combat.order_version
					else:
						members.erase(id) # Arrival or a newer Stop/Move/Attack owns it.
						continue
				"waiting":
					if entry["move"] != unit.order_version or entry["combat"] != unit.combat.order_version:
						members.erase(id)
						continue
				"breach":
					if unit.combat.order_version != entry["combat"] or unit.combat.target_actor() != target:
						if unit.combat.end_reason in ["target_unavailable", "pursuit_unreachable", "pursuit_budget_exhausted"] and unit.combat.player_command == CombatController.PlayerCommand.NONE:
							entry["mode"] = "waiting"
							entry["move"] = unit.order_version
							entry["combat"] = unit.combat.order_version
						else:
							members.erase(id)
							continue
			recipients.append(unit)
			if entry["mode"] == "waiting": waiting.append(unit)
		if recipients.is_empty():
			_objectives.erase(objective)
			continue
		var route := _approach_reachable(recipients, objective["objective"])
		if route and (is_instance_valid(target) or not waiting.is_empty()):
			var nav_generation: int = field.construction.navigation.generation
			if int(objective["route_nav"]) != nav_generation:
				objective["route_nav"] = nav_generation
				_resume_objective(objective, recipients)
				if not is_instance_valid(self) or generation != _generation or not _live(): return
			continue
		if route:
			continue # Existing attack-move owns an ordinary available route.
		if is_instance_valid(target) and TeamRules.is_hostile_target(field, OWNER, target) and target.barrier_blocks_ground():
			if waiting.size() == recipients.size(): status = "Breach waiting: exterior attack failed"
			continue # Stable target; never restart pursuit/fire/recovery each tick.
		objective["target"] = null
		var candidate := _blocking_candidate(recipients, objective)
		if candidate == null:
			status = "Breach waiting: no reachable blocking structure"
			continue
		var eligible: Array[RTSUnit] = []
		var already_engaging := false
		for unit in recipients:
			if not _exterior_fire_reachable(unit, candidate): continue
			if unit.attack_move.active and unit.attack_move.target_actor() == candidate and unit.combat.target_actor() == candidate:
				already_engaging = true # Existing acquisition already owns this hit.
			else:
				eligible.append(unit)
		if eligible.is_empty() and not already_engaging: continue
		(objective["attempted"] as Array).append(candidate.get_instance_id())
		if already_engaging:
			objective["target"] = weakref(candidate)
			status = "Attack Move breaching blocking " + candidate.display_name()
		if eligible.is_empty(): continue # Do not reset a valid automatic engagement.
		_dispatching = true
		var result := field.issue_attack_for(OWNER, eligible, candidate)
		if not is_instance_valid(self): return
		_dispatching = false
		if generation != _generation or not _live(): return
		if result.superseded:
			_objectives.erase(objective)
			continue
		if result.has_acceptance() and is_instance_valid(candidate):
			objective["target"] = weakref(candidate)
			for unit in eligible:
				if is_instance_valid(unit) and result.accepted_ids.has(unit.unit_id) and unit.combat.target_actor() == candidate:
					members[unit.unit_id]["mode"] = "breach"
					members[unit.unit_id]["combat"] = unit.combat.order_version
			breach_dispatches += 1
			status = "Breaching blocking " + candidate.display_name()
			print("ENEMY_BREACH: time=%.3f target=%d accepted=%s objective=%s" % [field.elapsed, candidate.get_instance_id(), result.accepted_ids, objective["objective"]])
			breach_started.emit(candidate.get_instance_id(), result)
			if not is_instance_valid(self) or generation != _generation or not _live(): return


func _approach_reachable(recipients: Array[RTSUnit], destination: Vector3) -> bool:
	var map := field_node().get_world_3d().get_navigation_map()
	if not destination.is_finite() or not field_node().field_bounds.has_point(Vector2(destination.x, destination.z)) or NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_closest_point(map, destination).distance_to(destination) > 0.1:
		return false
	for unit in recipients:
		var path := NavigationServer3D.map_get_path(map, unit.global_position, destination, true)
		if path.is_empty() or path[-1].distance_to(destination) > 0.1:
			return false
	return true


func _blocking_candidate(recipients: Array[RTSUnit], objective: Dictionary) -> BarrierBuilding:
	var field := field_node()
	var checked: Dictionary[int, bool] = {}
	# Only the first real world obstruction along a troop-to-objective approach
	# can be relevant. Nearby walls, friendly barriers and deeper layers do not
	# become candidates merely through distance. At most eight distinct hits.
	for unit in recipients:
		if checked.size() >= clampi(config.breach_candidate_limit, 1, 8): break
		var destination: Vector3 = objective["objective"] + Vector3.UP * LineOfFire.AIM_HEIGHT
		var trace := field.fire_query.segment(field.get_world_3d(), LineOfFire.muzzle(unit), destination)
		if not trace.available or not trace.blocked or checked.has(trace.collider_id): continue
		checked[trace.collider_id] = true
		breach_candidate_checks += 1
		var body := instance_from_id(trace.collider_id) as BarrierBuilding
		if body == null or (objective["attempted"] as Array).has(trace.collider_id) or not body.barrier_blocks_ground() or not TeamRules.can_attack(field, unit, body): continue
		if _exterior_fire_reachable(unit, body): return body
	return null


func _exterior_fire_reachable(unit: RTSUnit, target: BarrierBuilding) -> bool:
	var field := field_node()
	if not TeamRules.can_attack(field, unit, target): return false
	var data := unit.combat.weapon.definition
	if unit.global_position.distance_to(target.global_position) <= data.attack_range:
		return field.fire_query.weapon_clearance(unit, target, data).is_clear()
	# Match existing combat pursuit's first exterior standoff, then independently
	# require its full path and actual firing geometry. No special move speed,
	# slot teleport, synthetic damage or alternate wall weapon is introduced.
	var map := unit.agent.get_navigation_map()
	var away := (unit.global_position - target.global_position).normalized()
	var proposed := target.global_position + away * data.attack_range * unit.combat.pursuit_range_fraction
	var point := NavigationServer3D.map_get_closest_point(map, proposed)
	if point.distance_to(proposed) > 0.25 or point.distance_to(target.global_position) > data.attack_range: return false
	var path := NavigationServer3D.map_get_path(map, unit.global_position, point, true)
	if path.is_empty() or path[-1].distance_to(point) > 0.1: return false
	var line := field.fire_query.segment(field.get_world_3d(), point + Vector3.UP * LineOfFire.MUZZLE_HEIGHT, LineOfFire.aim(target))
	if not LineOfFire.accept_intended_contact(line, target).is_clear(): return false
	return data.mode != WeaponDefinition.Mode.GUIDED_PROJECTILE or field.fire_query.sweep_sphere(field.get_world_3d(), point + Vector3.UP * LineOfFire.MUZZLE_HEIGHT, point + Vector3.UP * LineOfFire.MUZZLE_HEIGHT, data.projectile_collision_radius).is_clear()


func _resume_objective(objective: Dictionary, recipients: Array[RTSUnit]) -> void:
	var field := field_node()
	var generation := _generation
	_dispatching = true
	var result := field.issue_attack_move_for(OWNER, recipients, objective["objective"])
	if not is_instance_valid(self): return
	_dispatching = false
	if generation != _generation or not _live(): return
	if result.superseded:
		_objectives.erase(objective)
		return
	if not result.has_acceptance():
		status = "Breach waiting: resumed approach rejected"
		return
	var members: Dictionary = objective["members"]
	for unit in recipients:
		if is_instance_valid(unit) and result.accepted_ids.has(unit.unit_id) and unit.attack_move.active and unit.attack_move.parent_order_id == result.generation:
			members[unit.unit_id]["mode"] = "approach"
			members[unit.unit_id]["parent"] = result.generation
	objective["target"] = null
	breach_resumptions += 1
	status = "Breach cleared: resuming retained HQ approach"
	print("ENEMY_BREACH_RESUME: time=%.3f accepted=%s objective=%s" % [field.elapsed, result.accepted_ids, objective["objective"]])
	breach_resumed.emit(result)


func _on_result(_result: BaseAssaultField.Result) -> void:
	stop()


func stop() -> void:
	_stopped = true
	_generation += 1
	_jobs.clear()
	_troops.clear()
	_early_deployments.clear()
	_objectives.clear()
	_breach_clock = 0.0
	status = "Stopped"


func _exit_tree() -> void:
	stop()
	if _producer != null and _producer.deployed.is_connected(_on_deployed): _producer.deployed.disconnect(_on_deployed)
	var field := field_node()
	if is_instance_valid(field) and field.match_finished.is_connected(_on_result): field.match_finished.disconnect(_on_result)
	_producer = null
	_field = null
	_cache = null
