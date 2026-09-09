class_name AttackMoveOrder
extends Node
## Retains the player's destination while the existing mover/combat own each leg.

enum Status { IDLE, TRAVELLING, ENGAGING, COMPLETE, FAILED, CANCELLED }
signal changed

@export var acquisition_interval: float = 0.25
@export var acquisition_radius: float = 12.0
@export var engagement_leash: float = 16.0
@export var blocked_fire_duration: float = 2.0
@export var ignore_duration: float = 3.0

var unit: RTSUnit
var active: bool = false
var parent_order_id: int = -1
var final_destination: Vector3
var final_slot: Vector3
var status: Status = Status.IDLE
var end_reason: String = ""
var scan_count: int = 0
var activity: String:
	get:
		if active:
			return "Engaging" if status == Status.ENGAGING else "Attack-moving"
		return "Attack-move failed" if status == Status.FAILED else "Idle"

var _generation: int = 0
var _command_owner: int = -1
var _target: WeakRef
var _acquisition_origin: Vector3
var _scan_wait: float = 0.0
var _elapsed: float = 0.0
var _blocked_since: float = -1.0
var _ignored: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	process_physics_priority = -20 # Release/acquire before combat submits locomotion.
	unit.availability_changed.connect(_on_source_availability_changed)


func target_actor() -> Node3D:
	return _target.get_ref() as Node3D if _target != null else null


func issue(destination: Vector3, slot: Vector3, parent_id: int, owner: int = -1) -> bool:
	# No mutation or notification until every check passes. Batch dispatch also
	# checks terrain/formation atomically before any participating unit accepts.
	if not _source_available(owner) or not destination.is_finite() or not slot.is_finite():
		return false
	if not unit.gameplay_field.field_bounds.has_point(Vector2(destination.x, destination.z)):
		return false
	if TeamRules.target_domain(unit) == TeamRules.TargetDomain.AIR:
		var flight_slot: Vector3 = unit.call("flight_destination", slot)
		if not flight_slot.is_finite() or not flight_slot.is_equal_approx(slot) or not bool(unit.call("flight_destination_valid", flight_slot)):
			return false
	else:
		var map := unit.agent.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			return false
		var path := NavigationServer3D.map_get_path(map, unit.global_position, slot, true)
		if path.is_empty() or path[-1].distance_to(slot) > 0.1:
			return false
	_generation += 1
	var version := _generation
	active = true
	parent_order_id = parent_id
	_command_owner = owner if owner >= 0 else unit.gameplay_field.selection.friendly_owner_id
	final_destination = destination
	final_slot = slot
	status = Status.TRAVELLING
	end_reason = ""
	_target = null
	_acquisition_origin = Vector3.ZERO
	_scan_wait = 0.0
	_elapsed = 0.0
	_blocked_since = -1.0
	scan_count = 0
	_ignored.clear()
	# A distinct explicit argument preserves only this internal operation. A
	# synchronous listener's manual replacement still cancels the parent.
	unit.move_to(final_slot, false, true)
	if is_instance_valid(self) and _current(version):
		_notify_changed()
	return true # Historical acceptance survives synchronous supersession.


func cancel(reason: String = "cancelled") -> void:
	# Intent-only cancellation. The accepting manual command (or lifecycle
	# owner) replaces/stops combat and movement after staging this clean state.
	_generation += 1
	active = false
	parent_order_id = -1
	final_destination = Vector3.ZERO
	final_slot = Vector3.ZERO
	status = Status.CANCELLED
	end_reason = reason
	_target = null
	_acquisition_origin = Vector3.ZERO
	_scan_wait = 0.0
	_elapsed = 0.0
	_blocked_since = -1.0
	scan_count = 0
	_ignored.clear()
	_notify_changed()


func is_ignoring(target: Variant) -> bool:
	if not is_instance_valid(target):
		return false
	var identity: int = target.get_instance_id()
	return _ignored.has(identity) and float(_ignored[identity]["until"]) > _elapsed and _target_available(target)


func ignored_target_count() -> int:
	_clean_ignored()
	return _ignored.size()


func _physics_process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	if not active:
		return # No idle acquisition or timer work.
	if not _source_available():
		end_if_source_unavailable()
		return
	if unit.navigation_suspended:
		return
	if unit.has_method("is_taking_off") and bool(unit.call("is_taking_off")):
		return # Hold the replaceable parent intent while physical takeoff finishes.
	_elapsed += delta
	_scan_wait += delta
	_clean_ignored()
	if _target != null:
		_update_engagement()
		return
	if not unit.moving:
		if unit.movement_state == RTSUnit.MovementState.FAILED:
			_finish(Status.FAILED, "final_travel_failed")
		elif unit.global_position.distance_to(final_slot) <= unit.stopping_distance:
			_finish(Status.COMPLETE, "arrived")
		else:
			_finish(Status.FAILED, "final_travel_interrupted")
		return
	if _scan_wait + 0.000001 < maxf(acquisition_interval, 0.001):
		return
	_scan_wait = 0.0
	scan_count += 1
	var candidate := _nearest_candidate()
	if candidate != null:
		_engage(candidate)


func _update_engagement() -> void:
	var target := target_actor()
	if not _target_available(target):
		_release_target("target_unavailable", false)
		return
	if _horizontal_distance_squared(_acquisition_origin, target.global_position) > engagement_leash * engagement_leash:
		_release_target("leash_exceeded", true)
		return
	if unit.combat.target_actor() != target:
		var reason := unit.combat.end_reason
		_release_target(reason if not reason.is_empty() else "engagement_ended", true)
		return
	if _scan_wait + 0.000001 < maxf(acquisition_interval, 0.001):
		return
	_scan_wait = 0.0
	# Reuse exactly the weapon's geometry at any range, including pursuit. The
	# weapon separately rechecks clearance immediately before each actual shot.
	var trace := unit.gameplay_field.fire_query.weapon_clearance(unit, target, unit.combat.weapon.definition)
	if trace.is_clear():
		_blocked_since = -1.0
	elif _blocked_since < 0.0:
		_blocked_since = _elapsed
	elif _elapsed - _blocked_since + 0.000001 >= blocked_fire_duration:
		_release_target("fire_line_blocked", true)


func _nearest_candidate() -> Node3D:
	var nearest: Node3D
	var best_distance := acquisition_radius * acquisition_radius
	var candidates: Array[Node3D] = []
	for candidate in unit.gameplay_field.units:
		if is_instance_valid(candidate):
			candidates.append(candidate)
	if unit.gameplay_field is ProductionField:
		for candidate in unit.gameplay_field.registered_buildings():
			if is_instance_valid(candidate):
				candidates.append(candidate)
	for candidate in candidates:
		if not _target_available(candidate) or is_ignoring(candidate):
			continue
		var distance := _horizontal_distance_squared(unit.global_position, candidate.global_position)
		if distance > best_distance:
			continue # Distance/ownership filter precedes any obstruction query.
		if nearest != null and distance == best_distance and not _identity_precedes(candidate, nearest):
			continue
		if not unit.gameplay_field.fire_query.weapon_clearance(unit, candidate, unit.combat.weapon.definition).is_clear():
			continue
		nearest = candidate
		best_distance = distance
	return nearest


func _engage(target: Node3D) -> void:
	var version := _generation
	_target = weakref(target)
	_acquisition_origin = unit.global_position
	status = Status.ENGAGING
	_blocked_since = -1.0
	_scan_wait = 0.0
	var accepted := unit.combat.issue_attack(target, false, true)
	if not is_instance_valid(self) or not _current(version):
		return
	if not accepted:
		_release_target("acquisition_rejected", true)
		return
	_notify_changed()


func _release_target(reason: String, temporarily_ignore: bool) -> void:
	var target := target_actor()
	if temporarily_ignore and _target_available(target):
		_ignored[target.get_instance_id()] = {"target": weakref(target), "until": _elapsed + maxf(ignore_duration, 0.0)}
	var version := _generation
	_target = null
	_acquisition_origin = Vector3.ZERO
	_blocked_since = -1.0
	_scan_wait = 0.0
	status = Status.TRAVELLING
	end_reason = reason
	# move_to prepares combat and disconnects its target listener before movement
	# publishes anything. No delayed callback can restore this temporary target.
	var accepted := unit.move_to(final_slot, false, true)
	if not is_instance_valid(self) or not _current(version):
		return
	if not accepted:
		_finish(Status.FAILED, "final_travel_rejected")
		return
	_notify_changed()


func _finish(result: Status, reason: String) -> void:
	_generation += 1
	active = false
	status = result
	end_reason = reason
	_target = null
	_acquisition_origin = Vector3.ZERO
	_scan_wait = 0.0
	_blocked_since = -1.0
	_ignored.clear()
	_notify_changed()


func _source_available(owner: int = -1) -> bool:
	if not is_instance_valid(unit) or not is_instance_valid(unit.gameplay_field):
		return false
	var authority := owner if owner >= 0 else (_command_owner if active else unit.gameplay_field.selection.friendly_owner_id)
	return unit.gameplay_field.can_attack_move_for(authority, unit)


func _target_available(target: Variant) -> bool:
	if not _source_available() or not TeamRules.can_attack(unit.gameplay_field, unit, target):
		return false
	var cursor: Node = target
	while cursor != unit.gameplay_field:
		if not is_instance_valid(cursor) or cursor.is_queued_for_deletion():
			return false
		cursor = cursor.get_parent()
	return true


func _clean_ignored() -> void:
	for identity in _ignored.keys():
		var entry: Dictionary = _ignored[identity]
		var target: Object = (entry["target"] as WeakRef).get_ref()
		if float(entry["until"]) <= _elapsed or not _target_available(target):
			_ignored.erase(identity)


func _current(version: int) -> bool:
	return is_instance_valid(self) and active and version == _generation and _source_available()


func _on_source_availability_changed() -> void:
	end_if_source_unavailable()


func end_if_source_unavailable() -> bool:
	if not active or _source_available():
		return false
	# An automatic leg must stop with its parent even when ordinary combat still
	# regards a changed-owner unit as a field member. Stage both controllers before
	# halt notifies observers; a synchronous newer order retains its own authority.
	var actor := unit
	cancel("source_unavailable")
	if not is_instance_valid(actor):
		return true
	var controller := actor.combat
	var combat_version := controller.prepare_order(CombatController.PlayerCommand.NONE, true) if is_instance_valid(controller) else -1
	actor.halt_motion()
	if is_instance_valid(controller) and combat_version >= 0:
		controller.publish_state(combat_version)
	return true


func _exit_tree() -> void:
	cancel("source_departed")


func _notify_changed() -> void:
	# A cancellation is staged inside another controller's prepare_order. Defer
	# this UI notification until that whole operation has committed; suppress an
	# obsolete generation and make no writes after synchronous observers run.
	_publish_changed.call_deferred(_generation)


func _publish_changed(version: int) -> void:
	if is_inside_tree() and version == _generation:
		changed.emit()


static func _horizontal_distance_squared(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_squared_to(Vector2(b.x, b.z))


static func _identity_precedes(a: Node3D, b: Node3D) -> bool:
	# Unit ids are stable gameplay identities. Buildings use their lifetime-stable
	# instance id in a separate namespace, never colliding with a unit id.
	if (a is RTSUnit) != (b is RTSUnit):
		return a is RTSUnit
	if a is RTSUnit:
		return a.unit_id < b.unit_id
	return a.get_instance_id() < b.get_instance_id()
