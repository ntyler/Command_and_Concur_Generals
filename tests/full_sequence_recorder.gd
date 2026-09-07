extends RefCounted
## Test-only, field-owned recorder. Reading state never queries navigation or
## physics space. Motion dictionaries remain shared until their delegate returns.

const SCHEMA_VERSION := 1
const RECENT_FRAMES := 120
const MOTION_CAPACITY_PER_UNIT := 480
const MAX_ROUTINE_EVENTS := 24000
const MAX_EVENTS := 30000
const MAX_GROUP_SNAPSHOTS := 1500
const MAX_ARCHIVED_MOTION := 120000
const MAX_VALUE_NODES := 32000000
const MAX_SERIALIZED_BYTES := 268435456

var field: TestField
var live := true
var run_id := ""
var source_id := ""
var field_generation := 0
var run_first_frame := 0
var route_label := "setup"
var route_first_frame := 0
var metadata: Dictionary = {}
var expected_units := 0
var required_routes: Array[String] = []
var events: Array = []
var connections: Dictionary = {}
var recent_motion: Dictionary = {}
var archived_motion: Dictionary = {}

var _units: Dictionary = {}
var _watched: Dictionary = {}
var _last_safe: Dictionary = {}
var _last_states: Dictionary = {}
var _routes: Array = []
var _failures: Array = []
var _errors: Array = []
var _error_count := 0
var _drops := {"events": 0, "important_events": 0, "group_snapshots": 0,
	"recent_motion": 0, "archived_motion": 0, "value_budget": 0}
var _routine_count := 0
var _group_count := 0
var _value_nodes := 0
var _next_motion_id := 0
var _received_motion := 0
var _commands_without_watch := 0
var _first_frame := -1
var _last_frame := -1
var _closed := false
var _write_succeeded := false
var _serialized_bytes := 0
var _motion_validation := {"pending_delegates": 0, "frame_mismatches": 0}


func _clock(frame: int = -1) -> Dictionary:
	if frame < 0:
		frame = Engine.get_physics_frames()
	var ticks := Engine.physics_ticks_per_second
	return {"absolute_frame": frame, "run_frame": frame - run_first_frame,
		"route_frame": frame - route_first_frame,
		"run_first_absolute_frame": run_first_frame, "route_first_absolute_frame": route_first_frame,
		"run_seconds": float(frame - run_first_frame) / ticks,
		"route_seconds": float(frame - route_first_frame) / ticks,
		"physics_ticks_per_second": ticks, "route": route_label}


static func _number(value: float) -> Variant:
	return value if is_finite(value) else null


static func _vector(value: Vector3) -> Array:
	return [_number(value.x), _number(value.y), _number(value.z)]


func state(unit: RTSUnit) -> Dictionary:
	if not is_instance_valid(unit):
		return {}
	var identity := unit.get_instance_id()
	var agent := unit.agent
	var valid_agent := is_instance_valid(agent)
	var valid_field := is_instance_valid(field)
	var clock := _clock()
	var waypoint_count: Variant = null
	if bool(_watched.get(identity, {}).get("has_waypoint_counter", false)):
		waypoint_count = unit.get("_recovery_waypoints")
	return {"id": unit.unit_id, "instance_id": identity, "owner_id": unit.owner_id,
		"absolute_frame": clock.absolute_frame, "run_frame": clock.run_frame, "route_frame": clock.route_frame,
		"position": _vector(unit.global_position if unit.is_inside_tree() else unit.position),
		"position_space": "global" if unit.is_inside_tree() else "local_outside_tree",
		"assigned": _vector(unit.assigned_destination), "next_waypoint": _vector(unit.next_waypoint),
		"state": RTSUnit.MovementState.keys()[unit.movement_state], "moving": unit.moving,
		"order_version": unit.order_version,
		"group_generation": field._command_version if valid_field else null,
		"field_command_generation": field._command_version if valid_field else null,
		"group_generation_provenance": "field current command version; accepted assignments are in group_command_result",
		"elapsed": _number(unit.command_elapsed), "progress_baseline": _number(unit._progress_remaining),
		"progress_baseline_finite": is_finite(unit._progress_remaining),
		"progress_elapsed": _number(unit._progress_elapsed), "stall": _number(unit.stalled_for),
		"recoveries": unit.recovery_attempts, "recovery_attempts": unit.recovery_attempts,
		"recovery_active": unit.recovery_active, "recovery_target": _vector(unit.recovery_target),
		"recovery_elapsed": _number(unit._recovery_elapsed), "recovery_waypoints": waypoint_count,
		"last_recovery_time": _number(unit.last_recovery_time), "last_recovery_time_finite": is_finite(unit.last_recovery_time),
		"submitted_order": unit._submitted_order, "last_movement_frame": unit._last_movement_frame,
		"requested_velocity": _vector(agent.velocity) if valid_agent else null,
		"applied_velocity": _vector(unit.velocity),
		"applied_velocity_provenance": "CharacterBody3D velocity property; actual displacement is in movement_calls",
		"last_safe_callback": _last_safe.get(identity, null),
		"agent_target": _vector(agent.target_position) if valid_agent else null,
		"radius": agent.radius if valid_agent else null, "priority": agent.avoidance_priority if valid_agent else null,
		"max_speed": agent.max_speed if valid_agent else null, "crowd_enabled": unit.crowd_enabled,
		"avoidance_enabled": agent.avoidance_enabled if valid_agent else null,
		"navigation_suspended": unit.navigation_suspended, "navigation_progress": _number(unit._navigation_progress),
		"navigation_order": unit._navigation_order,
		"inside_tree": unit.is_inside_tree(), "queued_for_deletion": unit.is_queued_for_deletion(),
		"registered": field._registered.has(identity) if valid_field else null}


func watch(unit: RTSUnit) -> void:
	if not live or not is_instance_valid(unit):
		return
	var identity := unit.get_instance_id()
	if _units.has(identity):
		_error("duplicate watch for instance %s" % identity)
		return
	if _first_frame < 0:
		_first_frame = Engine.get_physics_frames()
	_units[identity] = unit
	var has_waypoints := false
	# Once at creation, never in state(), physics(), or a movement callback.
	for property in unit.get_property_list():
		has_waypoints = has_waypoints or property.name == "_recovery_waypoints"
	_watched[identity] = {"id": unit.unit_id, "instance_id": identity, "clock": _clock(),
		"order_version_at_watch": unit.order_version, "has_waypoint_counter": has_waypoints,
		"initial_state": {}, "commands": 0, "motion_received": 0, "exited": false}
	_watched[identity].initial_state = state(unit)
	recent_motion[identity] = {"records": [], "head": 0}
	var listener := Callable(self, "_on_state_changed").bind(identity)
	unit.movement_state_changed.connect(listener)
	connections[identity] = listener
	_last_states[identity] = state(unit)
	event("watch_started", unit, {}, {"before_field_registration": not bool(state(unit).registered)})


func unwatch(unit: RTSUnit) -> void:
	if not is_instance_valid(unit):
		return
	var identity := unit.get_instance_id()
	if not _units.has(identity):
		return
	if live:
		event("membership_tree_exit", unit, {}, {}, true)
	_disconnect(identity, unit)
	_watched[identity]["exited"] = true
	_watched[identity]["exit_clock"] = _clock()
	_units.erase(identity)
	recent_motion.erase(identity)
	_last_safe.erase(identity)
	_last_states.erase(identity)


func _disconnect(identity: int, unit: RTSUnit) -> void:
	if connections.has(identity) and is_instance_valid(unit):
		var listener: Callable = connections[identity]
		if unit.movement_state_changed.is_connected(listener):
			unit.movement_state_changed.disconnect(listener)
	connections.erase(identity)


func _on_state_changed(new_state: int, identity: int) -> void:
	if not live or not _units.has(identity):
		return
	var unit: RTSUnit = _units[identity]
	if not is_instance_valid(unit):
		_error("state signal from unavailable watched unit %s" % identity)
		return
	var before: Dictionary = _last_states.get(identity, {})
	event("state_transition", unit, before, {"signal_state": RTSUnit.MovementState.keys()[new_state],
		"before_provenance": "last observed event/physics state, not a production pre-emission hook"},
		new_state == RTSUnit.MovementState.RECOVERING or new_state == RTSUnit.MovementState.FAILED)


func physics(unit: RTSUnit, before: Dictionary) -> void:
	if not live or not is_instance_valid(unit):
		return
	var after := state(unit)
	var changed := []
	for key in ["radius", "agent_target", "recovery_target", "avoidance_enabled"]:
		if before.get(key) != after.get(key):
			changed.append(key)
	if not changed.is_empty():
		event("physics_property_change", unit, before, {"changed_properties": changed})
	_last_states[unit.get_instance_id()] = after


func event(kind: String, unit: RTSUnit, before: Dictionary, details: Dictionary = {}, important: bool = false) -> void:
	if not live:
		return
	_last_frame = Engine.get_physics_frames()
	var identity := unit.get_instance_id() if is_instance_valid(unit) else 0
	if kind == "move_command_requested":
		if not _watched.has(identity):
			_commands_without_watch += 1
		else:
			_watched[identity].commands += 1
	var after := state(unit)
	if kind == "terminal_requested" and details.get("requested_terminal_state") == "FAILED":
		_failures.append({"event_id": events.size(), "id": after.get("id"), "clock": _clock(),
			"order_version": before.get("order_version"), "requested_terminal_state": "FAILED"})
	if events.size() >= MAX_EVENTS or (not important and _routine_count >= MAX_ROUTINE_EVENTS) or _value_nodes >= MAX_VALUE_NODES:
		_drops.events += 1
		_drops.important_events += int(important)
		return
	var entry := {"event_id": events.size(), "kind": kind, "run_id": run_id, "source_id": source_id,
		"field_generation": field_generation, "clock": _clock(), "important": important,
		"before": _clean(before), "after": _clean(after), "details": _clean(details)}
	if important:
		entry["group_states"] = _group_states()
		entry["actor_recent_motion_ids"] = _archive_recent(identity)
		if identity == 0:
			var group_recent := {}
			for watched_identity in recent_motion:
				group_recent[str(watched_identity)] = _archive_recent(watched_identity)
			entry["group_recent_motion_ids"] = group_recent
		if is_instance_valid(unit) and is_instance_valid(unit.agent) and unit.agent.is_inside_tree():
			# Godot's already cached path only: never get_next_path_position or a
			# NavigationServer path query. This reads no new decision result.
			var cached := unit.agent.get_current_navigation_path()
			var path := []
			for index in mini(cached.size(), 512):
				path.append(_vector(cached[index]))
			entry["cached_agent_path"] = {"points": path, "index": unit.agent.get_current_navigation_path_index(),
				"total_points": cached.size(), "truncated": cached.size() > 512,
				"provenance": "already cached agent path read at event boundary; not an additional path query"}
			if cached.size() > 512:
				_error("cached path exceeded 512-point capture limit")
		else:
			entry["cached_agent_path"] = null
	else:
		_routine_count += 1
	events.append(entry)
	if identity != 0:
		_last_states[identity] = after


func event_group(kind: String, details: Dictionary = {}, important: bool = false) -> void:
	event(kind, null, {}, details, important)


func _group_states() -> Array:
	if _group_count >= MAX_GROUP_SNAPSHOTS or _value_nodes >= MAX_VALUE_NODES:
		_drops.group_snapshots += 1
		return []
	_group_count += 1
	var result := []
	# Cached registration/watch order; no group or scene-tree search.
	for identity in _units:
		var unit: RTSUnit = _units[identity]
		if is_instance_valid(unit):
			result.append(_clean(state(unit)))
		else:
			_error("invalid instance retained in watch cache %s" % identity)
	return result


func motion(unit: RTSUnit, record: Dictionary) -> void:
	if not live or not is_instance_valid(unit):
		return
	var identity := unit.get_instance_id()
	if not recent_motion.has(identity):
		_drops.recent_motion += 1
		return
	var frame: int = record.get("absolute_frame", Engine.get_physics_frames())
	_received_motion += 1
	_watched[identity].motion_received += 1
	_next_motion_id += 1
	var envelope := {"record_id": _next_motion_id, "identity": {"id": unit.unit_id, "instance_id": identity,
		"run_id": run_id, "source_id": source_id, "field_generation": field_generation},
		"clock": _clock(frame), "record": record}
	# Deliberately no duplicate(): the probe completes this exact record after
	# production returns, including a rejected callback and synchronous removal.
	var ring: Dictionary = recent_motion[identity]
	var records: Array = ring.records
	if records.size() < MOTION_CAPACITY_PER_UNIT:
		records.append(envelope)
	else:
		var head: int = ring.head
		if int(records[head].clock.absolute_frame) >= frame - RECENT_FRAMES + 1:
			_drops.recent_motion += 1
		records[head] = envelope
		ring.head = (head + 1) % MOTION_CAPACITY_PER_UNIT
	if record.get("callback_input") != null:
		_last_safe[identity] = {"value": record.callback_input, "absolute_frame": frame,
			"observer_local_callback_sequence": record.get("observer_local_callback_sequence"),
			"provenance": "last actually received callback input; application is recorded separately"}
	_last_frame = maxi(_last_frame, frame)


func _recent(identity: int) -> Array:
	var result := []
	if not recent_motion.has(identity):
		return result
	var ring: Dictionary = recent_motion[identity]
	var records: Array = ring.records
	var cutoff := Engine.get_physics_frames() - RECENT_FRAMES + 1
	for offset in records.size():
		var index: int = (int(ring.head) + offset) % records.size()
		var envelope: Dictionary = records[index]
		if int(envelope.clock.absolute_frame) >= cutoff:
			result.append(envelope)
	return result


func _archive_recent(identity: int) -> Array:
	var ids := []
	for envelope in _recent(identity):
		var key := str(envelope.record_id)
		if not archived_motion.has(key):
			if archived_motion.size() >= MAX_ARCHIVED_MOTION or _value_nodes >= MAX_VALUE_NODES:
				_drops.archived_motion += 1
				continue
			archived_motion[key] = envelope
			# Conservative admission charge; exact serialization size is also
			# checked before writing. No per-callback JSON serialization.
			_value_nodes += 256
		ids.append(envelope.record_id)
	return ids


func start_route(label: String) -> void:
	route_label = label
	route_first_frame = Engine.get_physics_frames()
	_routes.append({"label": label, "start": _clock(), "end": null})
	event_group("route_started", {"watched_ids": _covered_ids()}, true)


func end_route(metrics: Dictionary) -> void:
	event_group("route_finished", metrics, true)
	if not _routes.is_empty():
		_routes[-1]["end"] = _clock()
		_routes[-1]["metrics"] = _clean(metrics)


func _covered_ids() -> Array:
	var result := []
	for observation in _watched.values():
		result.append(observation.id)
	result.sort()
	return result


func coverage_snapshot() -> Dictionary:
	var ids := _covered_ids()
	var complete := _commands_without_watch == 0 and _error_count == 0
	complete = complete and _motion_validation.pending_delegates == 0 and _motion_validation.frame_mismatches == 0
	for count in _drops.values():
		complete = complete and int(count) == 0
	if expected_units > 0:
		complete = complete and ids.size() == expected_units
		for id in range(1, expected_units + 1):
			complete = complete and id in ids
	for observation in _watched.values():
		complete = complete and int(observation.order_version_at_watch) == 0
	for route in required_routes:
		var ended := false
		for observation in _routes:
			ended = ended or (observation.label == route and observation.end != null)
		complete = complete and ended
	var failure_ids := []
	for failure in _failures:
		if failure.id not in failure_ids:
			failure_ids.append(failure.id)
	return {"schema_version": SCHEMA_VERSION, "complete": complete, "run_id": run_id, "source_id": source_id,
		"field_generation": field_generation, "start_absolute_frame": _first_frame, "end_absolute_frame": _last_frame,
		"run_first_frame": run_first_frame, "covered_ids": ids, "covered_unit_ids": ids, "expected_units": expected_units,
		"required_routes": required_routes, "routes": _routes, "watched": _watched.values(),
		"commands_without_watch": _commands_without_watch, "dropped": _drops.duplicate(),
		"event_count": events.size(), "important_group_snapshots": _group_count,
		"motion_received": _received_motion, "archived_motion_count": archived_motion.size(),
		"motion_validation": _motion_validation.duplicate(),
		"failure_ids": failure_ids, "failed_events": _failures, "serialization_errors": _error_count,
		"errors": _errors.duplicate(), "logical_value_charge": _value_nodes,
		"serialized_bytes": _serialized_bytes, "artifact_write_succeeded": _write_succeeded,
		"closed": _closed, "active_listener_count": connections.size(), "active_unit_count": _units.size()}


func inspection() -> Dictionary:
	var current := {}
	for identity in recent_motion:
		current[str(identity)] = _recent(identity)
	return {"events": events, "motion_records": archived_motion, "recent_motion": current,
		"coverage": coverage_snapshot()}


func finish(prefix: String) -> Dictionary:
	# Boundary flush is synchronous and does not stop capture. Multiple boundaries
	# may be flushed; close() is the explicit listener/cache lifecycle boundary.
	_last_frame = Engine.get_physics_frames()
	_write_succeeded = false
	var final_recent := {}
	for identity in recent_motion:
		final_recent[str(identity)] = _archive_recent(identity)
	_motion_validation = {"pending_delegates": 0, "frame_mismatches": 0}
	for envelope in archived_motion.values():
		var observation: Dictionary = envelope.record
		_motion_validation.pending_delegates += int(not bool(observation.get("delegation_returned", false)))
		_motion_validation.frame_mismatches += int(envelope.clock.absolute_frame != observation.get("absolute_frame"))
		for movement in observation.get("movement_calls", []):
			_motion_validation.pending_delegates += int(not bool(movement.get("delegation_returned", false)))
			_motion_validation.frame_mismatches += int(movement.get("absolute_frame") != observation.get("absolute_frame"))
	var payload := {"schema_version": SCHEMA_VERSION, "run_id": run_id, "source_id": source_id,
		"field_generation": field_generation, "metadata": _clean(metadata, false),
		"time_mapping": {"run_first_absolute_frame": run_first_frame,
			"formula": "relative_frame = absolute_frame - origin; seconds = relative_frame / physics_ticks_per_second",
			"note": "simulation frame time, not wall time; each event carries its route origin mapping"},
		"limits": {"recent_frames": RECENT_FRAMES, "per_unit_callback_capacity": MOTION_CAPACITY_PER_UNIT,
			"routine_events": MAX_ROUTINE_EVENTS, "events": MAX_EVENTS, "group_snapshots": MAX_GROUP_SNAPSHOTS,
			"archived_motion": MAX_ARCHIVED_MOTION, "logical_value_nodes": MAX_VALUE_NODES,
			"serialized_bytes": MAX_SERIALIZED_BYTES,
			"logical_charge_note": "Admission budget, not measured RSS: snapshot scalar/container nodes plus 256 per unique archived motion; serialization of retained data is not charged again."},
		"unavailable": ["Engine-native avoidance submission identity is not exposed; callback sequence is observer-local.",
			"Internal candidate rejection and terminal/clear guard branches are not instrumented.",
			"last_safe_callback is null until an actual callback is received; body velocity is not displacement.",
			"Historical source has no additional-waypoint counter; recovery_waypoints is null there.",
			"Routine motion older than the 120-frame window is intentionally retained only when referenced by an important event."],
		"events": events, "motion_records": _clean(archived_motion, false), "final_recent_motion_ids": final_recent}
	payload["coverage"] = coverage_snapshot()
	var serialized := JSON.stringify(payload)
	_serialized_bytes = serialized.to_utf8_buffer().size()
	if _serialized_bytes > MAX_SERIALIZED_BYTES:
		_error("serialized capture exceeds %d bytes; full capture not written" % MAX_SERIALIZED_BYTES)
		payload = {"schema_version": SCHEMA_VERSION, "coverage": coverage_snapshot(), "events": [],
			"omission": "explicit artifact byte limit; original in-memory events were not silently overwritten"}
		serialized = JSON.stringify(payload)
	var file := FileAccess.open(prefix + "-capture.json", FileAccess.WRITE)
	if file == null:
		_error("capture open failed: %s" % FileAccess.get_open_error())
	else:
		file.store_string(serialized)
		file.flush()
		var write_error := file.get_error()
		file.close()
		if write_error != OK:
			_error("capture write failed: %s" % write_error)
		else:
			_write_succeeded = true
	var coverage := coverage_snapshot()
	coverage["complete"] = bool(coverage.complete) and _write_succeeded
	# Separate small receipt describes the outcome of writing the larger payload.
	var receipt := FileAccess.open(prefix + "-coverage.json", FileAccess.WRITE)
	if receipt == null:
		_error("coverage receipt open failed: %s" % FileAccess.get_open_error())
		coverage = coverage_snapshot()
		coverage["complete"] = false
	else:
		receipt.store_string(JSON.stringify(coverage))
		receipt.flush()
		var receipt_error := receipt.get_error()
		receipt.close()
		if receipt_error != OK:
			_error("coverage receipt write failed: %s" % receipt_error)
			coverage = coverage_snapshot()
			coverage["complete"] = false
	return coverage


func close() -> void:
	if _closed:
		return
	if live:
		event_group("recorder_closed", {"reason": "explicit capture boundary; later original private-fault fixtures are outside capture"})
	live = false
	for identity in _units:
		_disconnect(identity, _units[identity])
	_units.clear()
	recent_motion.clear()
	_last_states.clear()
	_last_safe.clear()
	field = null
	_closed = true


func _error(message: String) -> void:
	_error_count += 1
	if _errors.size() < 100:
		_errors.append(message)


func _clean(value: Variant, charge: bool = true) -> Variant:
	if charge:
		_value_nodes += 1
		if _value_nodes > MAX_VALUE_NODES:
			_drops.value_budget += 1
			return null
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return value
		TYPE_FLOAT:
			return _number(value)
		TYPE_VECTOR3:
			return _vector(value)
		TYPE_ARRAY:
			var array := []
			for item in value:
				array.append(_clean(item, charge))
			return array
		TYPE_DICTIONARY:
			var dictionary := {}
			for key in value:
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT]:
					_error("unsupported dictionary key type %s" % typeof(key))
					continue
				dictionary[str(key)] = _clean(value[key], charge)
			return dictionary
		_:
			_error("unsupported serialized value type %s; replaced by explicit null" % typeof(value))
			return null
