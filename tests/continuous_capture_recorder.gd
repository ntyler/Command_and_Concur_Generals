extends "res://tests/full_sequence_recorder.gd"
## Append-only test stream. Every frame is retained; inherited legacy capture is unused.
signal capture_failed(message: String)

const STREAM_VERSION := 1
const STREAM_MAX_FRAMES := 10000
const STREAM_MAX_BYTES := 1073741824
var stream_mode := ""
var stream_path := ""
var stream_error := ""
var stream_started := false
var stream_finished := false
var cluster_commands := 0
var frame_count := 0
var max_frames := STREAM_MAX_FRAMES
var max_bytes := STREAM_MAX_BYTES
var _stream: FileAccess
var _hash := HashingContext.new()
var _sequence := 0
var _bytes_written := 0
var _frame := -1
var _initial_frame := -1
var _rows := {}
var _pending := {}
var _cached_paths := {}
var _admission_sequence := 0
var _totals := {}
var _observation_sequence := 0


func open_stream(path: String, mode: String, fixture_hash: String, first_frame: int) -> bool:
	if mode not in ["synthetic_contract", "parked_wiring", "route"] or FileAccess.file_exists(path):
		return false
	stream_path = path
	stream_mode = mode
	_stream = FileAccess.open(path, FileAccess.WRITE)
	if _stream == null:
		return false
	_hash.start(HashingContext.HASH_SHA256)
	_frame = first_frame
	_initial_frame = first_frame
	for id in range(1, 51):
		_totals[id] = {"id": id, "callbacks_received": 0, "callbacks_completed": 0, "direct_received": 0, "direct_completed": 0}
	return _write_line({"type": "header", "schema_version": STREAM_VERSION, "mode": mode,
		"run_id": run_id, "source_sha256": source_id, "fixture_sha256": fixture_hash,
		"expected_ids": range(1, 51), "physics_ticks": 60, "start_frame": first_frame,
		"limits": {"max_frames": max_frames, "max_bytes": max_bytes},
		"state_phase": "each row is its unit's latest completed observation in this frame; not a simultaneous native RVO snapshot",
		"sequence_provenance": "serialized order; callback admission_sequence separately orders nested delegate admission"})


func _compact(value: Dictionary) -> Dictionary:
	if value.is_empty():
		return {}
	var result := {}
	for key in ["id", "position", "assigned", "next_waypoint", "moving", "state", "radius", "priority", "requested_velocity", "last_movement_frame", "elapsed", "stall", "recoveries", "recovery_target", "avoidance_enabled", "recovery_active", "recovery_elapsed", "recovery_waypoints", "progress_elapsed", "progress_baseline", "progress_baseline_finite", "last_recovery_time", "last_recovery_time_finite", "submitted_order", "agent_target"]:
		result[key] = value.get(key)
	result["order"] = value.get("order_version", value.get("order", 0))
	result["movement_speed"] = 5.0
	result["velocity"] = value.get("applied_velocity", value.get("velocity", [0.0, 0.0, 0.0]))
	return result


func _new_row(unit: RTSUnit) -> Dictionary:
	var observed := _compact(state(unit))
	observed.movement_speed = unit.movement_speed
	return {"id": unit.unit_id, "instance_id": unit.get_instance_id(), "state": observed,
		"physics_observed": false, "callbacks": [], "direct_movements": []}


func watch(unit: RTSUnit) -> void:
	super.watch(unit)
	_rows[unit.unit_id] = _new_row(unit)


func begin_continuous() -> bool:
	if _units.size() != 50 or _rows.size() != 50 or not stream_error.is_empty():
		_fail_stream("continuous capture must begin with all50 normally watched participants")
		return false
	stream_started = true
	var initial_states := []
	for id in range(1, 51):
		if int(_rows[id].state.order) != 0:
			_fail_stream("initial state must precede all public commands")
			return false
		initial_states.append(_rows[id].state.duplicate(true))
	event_group("continuous_initial_state", {"states": initial_states, "before_commands": true})
	return true


func event(kind: String, unit: RTSUnit, before: Dictionary, details: Dictionary = {}, _important: bool = false) -> void:
	if not live or _stream == null or stream_finished:
		return
	var frame := Engine.get_physics_frames()
	if stream_started and not _advance_frame(frame):
		return
	var after := _compact(state(unit))
	var id: Variant = after.get("id")
	_observation_sequence += 1
	if kind == "move_command_result" and bool(details.get("accepted", false)) and int(after.get("order", 0)) >= 2:
		cluster_commands += 1
		if stream_mode == "parked_wiring":
			_fail_stream("parked wiring must never dispatch a cluster command")
			return
	if id != null and _rows.has(id):
		_rows[id].state = after
		_rows[id]["state_observation_sequence"] = _observation_sequence
	_write_line({"type": "event", "frame": frame, "kind": kind, "id": id,
		"observation_sequence": _observation_sequence,
		"before": _compact(before), "after": after, "details": _clean(details, false)})


func motion(unit: RTSUnit, record: Dictionary) -> void:
	if not live or not stream_started:
		return
	if not _advance_frame(int(record.absolute_frame)):
		return
	var id := unit.unit_id
	if _pending.has(id):
		_fail_stream("nested unfinished motion for unit%d" % id)
		return
	_admission_sequence += 1
	_observation_sequence += 1
	record["admission_sequence"] = _observation_sequence
	record["motion_receipt_sequence"] = _admission_sequence
	_totals[id]["callbacks_received" if record.kind == "avoidance_callback" else "direct_received"] += 1
	# Keep actual shared dictionary until the probe explicitly signals completion.
	_pending[id] = record


func complete_motion(unit: RTSUnit, direct_only: bool = false) -> void:
	if not live or not _pending.has(unit.unit_id):
		return
	var record: Dictionary = _pending[unit.unit_id]
	if direct_only and record.kind != "direct_movement_call":
		return
	if not bool(record.get("delegation_returned", false)) or record.get("after") == null:
		_fail_stream("motion completed without returned delegate/after state")
		return
	for movement in record.movement_calls:
		if not bool(movement.get("delegation_returned", false)) or movement.get("position_after") == null:
			_fail_stream("movement completed without returned delegate/end position")
			return
	if int(record.absolute_frame) != _frame:
		_fail_stream("late completed movement crossed a frame boundary")
		return
	var row: Dictionary = _rows[unit.unit_id]
	_observation_sequence += 1
	record["completion_sequence"] = _observation_sequence
	if record.kind == "avoidance_callback":
		row.callbacks.append(record.duplicate(true))
		_totals[unit.unit_id].callbacks_completed += 1
		_last_safe[unit.get_instance_id()] = {"value": record.callback_input, "absolute_frame": _frame,
			"observer_local_callback_sequence": record.observer_local_callback_sequence}
	else:
		row.direct_movements.append(record.duplicate(true))
		_totals[unit.unit_id].direct_completed += 1
	row.state = _compact(state(unit))
	row.state.movement_speed = unit.movement_speed
	row["state_observation_sequence"] = _observation_sequence
	_pending.erase(unit.unit_id)


func physics(unit: RTSUnit, before: Dictionary) -> void:
	if not live or not stream_started or not _advance_frame(Engine.get_physics_frames()):
		return
	var row: Dictionary = _rows[unit.unit_id]
	if row.physics_observed:
		_fail_stream("duplicate physics observation for unit%d frame%d" % [unit.unit_id, _frame])
		return
	row.physics_observed = true
	_observation_sequence += 1
	row.state = _compact(state(unit))
	row.state.movement_speed = unit.movement_speed
	row["state_observation_sequence"] = _observation_sequence
	row["physics"] = {"before": _compact(before), "after": row.state.duplicate(true), "observation_sequence": _observation_sequence}
	# Read cached path/index only; this does not request/advance navigation.
	var points := []
	for point in unit.agent.get_current_navigation_path():
		points.append(_vector(point))
	var cached := {"points": points, "index": unit.agent.get_current_navigation_path_index()}
	if _cached_paths.get(unit.unit_id) != cached:
		_cached_paths[unit.unit_id] = cached.duplicate(true)
		cached["provenance"] = "already cached path/index after production physics; no native query"
		event("cached_path_changed", unit, {}, cached)
	_last_states[unit.get_instance_id()] = state(unit)


func _advance_frame(frame: int) -> bool:
	if frame == _frame:
		return true
	if frame != _frame + 1:
		_fail_stream("noncontiguous observed physics frame %d after%d" % [frame, _frame])
		return false
	if not _flush_frame():
		return false
	_frame = frame
	for id in _rows:
		var row: Dictionary = _rows[id]
		_rows[id] = {"id": id, "instance_id": row.instance_id, "state": row.state,
			"physics_observed": false, "callbacks": [], "direct_movements": []}
	return true


func _flush_frame() -> bool:
	if not _pending.is_empty() or _rows.size() != 50:
		_fail_stream("cannot flush missing participants or unfinished delegates")
		return false
	if frame_count >= max_frames:
		_fail_stream("continuous frame capacity exhausted; no history was evicted")
		return false
	var rows := []
	for id in range(1, 51):
		if not _rows.has(id) or (_frame != _initial_frame and not bool(_rows[id].physics_observed)):
			_fail_stream("missing unit physics observation id%d frame%d" % [id, _frame])
			return false
		rows.append(_rows[id])
	if not _write_line({"type": "frame", "frame": _frame, "phase": "initial" if _frame == _initial_frame else "physics", "route": route_label, "rows": rows}):
		return false
	frame_count += 1
	return true


func finish_stream(precluster_teardown: bool = false, route_finished: bool = false) -> Dictionary:
	if stream_finished:
		return {"complete": false, "reason": "already finished"}
	if _stream == null:
		stream_finished = true
		live = false
		return {"complete": false, "reason": "stream never opened"}
	var complete := stream_error.is_empty() and stream_started and _flush_frame()
	var totals := []
	for id in range(1, 51):
		totals.append(_totals[id])
	var footer := {"type": "footer", "last_frame": _frame, "frames": frame_count, "totals": totals,
		"complete": complete, "errors": [] if stream_error.is_empty() else [stream_error],
		"pending_delegates": _pending.size(), "reason": "normal validation boundary" if complete else stream_error,
		"cluster_commands": cluster_commands, "precluster_teardown": precluster_teardown,
		"route_finished": route_finished, "sha256": _hash.finish().hex_encode()}
	if not _write_line(footer, false):
		footer.complete = false
		footer.reason = "footer write failed"
	_stream.flush()
	if _stream.get_error() != OK:
		footer.complete = false
		footer.reason = "stream flush failed"
	_stream.close()
	stream_finished = true
	live = false
	return footer


func contract_frame(frame: int, rows: Array) -> bool:
	# Serializer contract testing only: never accepts a live unit or drives movement.
	if stream_mode != "synthetic_contract" or not _units.is_empty():
		_fail_stream("synthetic rows forbidden for a live/route recorder")
		return false
	if stream_started and not _advance_frame(frame):
		return false
	_rows.clear()
	for row in rows:
		_rows[int(row.id)] = row.duplicate(true)
		for callback in row.callbacks:
			_totals[int(row.id)].callbacks_received += 1
			_totals[int(row.id)].callbacks_completed += int(bool(callback.delegation_returned))
		for direct in row.direct_movements:
			_totals[int(row.id)].direct_received += 1
			_totals[int(row.id)].direct_completed += int(bool(direct.delegation_returned))
	stream_started = true
	return true


func _write_line(value: Dictionary, hash_line: bool = true) -> bool:
	if _stream == null:
		return false
	value["seq"] = _sequence
	var bytes := (JSON.stringify(value) + "\n").to_utf8_buffer()
	if hash_line and _bytes_written + bytes.size() > max_bytes:
		_fail_stream("continuous byte capacity exhausted; file retained incomplete")
		return false
	_stream.store_buffer(bytes)
	if _stream.get_error() != OK:
		_fail_stream("continuous stream write failed")
		return false
	if hash_line:
		_hash.update(bytes)
	_sequence += 1
	_bytes_written += bytes.size()
	return true


func _fail_stream(message: String) -> void:
	if stream_error.is_empty():
		stream_error = message
		live = false
		capture_failed.emit(message)


func _error(message: String) -> void:
	_fail_stream(message)
