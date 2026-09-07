extends "res://tests/cluster_diagnostic_history.gd"
## Issue B observation only. Retain the complete route even when it passes.
## Candidate probes are explicitly recomputed diagnostics, never test oracles.

const HISTORICAL_GOAL := Vector3(33, 0, 22)
const HISTORICAL_STOP := Vector3(31.41587, 0, 19.78682)
var route_history: Array = []
var focused_frames: Array = []
var route_events: Array = []
var recovery_probes: Array = []
var callbacks: Dictionary = {}
var history_truncated := false
var units_by_id: Dictionary = {}
var supports_waypoint_counter := false


func begin(source: TestField) -> void:
	super.begin(source)
	for unit in members:
		units_by_id[unit.unit_id] = unit
	for property in members[0].get_property_list():
		supports_waypoint_counter = supports_waypoint_counter or property.name == "_recovery_waypoints"


func record(unit: RTSUnit) -> Dictionary:
	var result := super.record(unit)
	result["recovery_waypoints"] = int(unit.get("_recovery_waypoints")) if supports_waypoint_counter else -1
	return result


func _focused(unit: RTSUnit) -> bool:
	return unit.unit_id == 4 or unit.assigned_destination.distance_to(HISTORICAL_GOAL) < 0.001


func _velocity_computed(value: Vector3, id: int) -> void:
	super._velocity_computed(value, id)
	var unit: RTSUnit = units_by_id.get(id)
	if is_instance_valid(unit) and _focused(unit):
		callbacks[id] = {"frame": Engine.get_physics_frames() - first_frame, "absolute_frame": Engine.get_physics_frames(),
			"phase": "after_production_avoidance_callback", "safe": vector(value),
			"requested_now": vector(unit.agent.velocity), "applied": vector(unit.velocity),
			"position": vector(unit.global_position), "order": unit.order_version,
			"submitted_order": unit._submitted_order, "movement_frame": unit._last_movement_frame,
			"contacts": _contacts(unit)}


func _contacts(unit: RTSUnit) -> Array:
	var result := []
	for index in unit.get_slide_collision_count():
		var contact := unit.get_slide_collision(index)
		var body := contact.get_collider()
		result.append({"collider": str(body.get_path()) if is_instance_valid(body) and body is Node else str(body),
			"point": vector(contact.get_position()), "normal": vector(contact.get_normal()),
			"travel": vector(contact.get_travel()), "remainder": vector(contact.get_remainder())})
	return result


func _state_changed(state: int, unit: RTSUnit) -> void:
	super._state_changed(state, unit)
	if route_events.size() < 1024:
		route_events.append({"frame": Engine.get_physics_frames() - first_frame, "unit": record(unit)})
	else:
		history_truncated = true
	if state == RTSUnit.MovementState.RECOVERING and _focused(unit):
		recovery_probes.append(_probe_recovery(unit))


func _physics_process(delta: float) -> void:
	# The inherited observer records the accepted batch after the synchronous
	# command, and keeps its phase-labelled most recent avoidance input.
	super._physics_process(delta)
	var frame := Engine.get_physics_frames() - first_frame
	if (tick - 1) % 15 == 0:
		if route_history.size() < 320: # Entire 75-second route + three-second settling.
			route_history.append({"frame": frame, "units": records(),
				"group_generation": field._command_version,
				"map_iteration": NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()),
				"region_iteration": NavigationServer3D.region_get_iteration_id(field.navigation_region.get_rid())})
		else:
			history_truncated = true
	if focused_frames.size() >= 4800:
		history_truncated = true
		return
	var samples := []
	for unit in members:
		if not is_instance_valid(unit) or not _focused(unit):
			continue
		var neighbors := []
		for other in members:
			if is_instance_valid(other) and other != unit and unit.global_position.distance_to(other.global_position) <= unit.neighbor_distance + 0.7:
				neighbors.append({"id": other.unit_id, "position": vector(other.global_position),
					"assigned": vector(other.assigned_destination), "state": RTSUnit.MovementState.keys()[other.movement_state],
					"moving": other.moving, "radius": other.agent.radius, "priority": other.agent.avoidance_priority,
					"velocity": vector(other.velocity), "order": other.order_version, "member": field.contains_unit(other)})
		var path := []
		for point in unit.agent.get_current_navigation_path():
			path.append(vector(point))
		samples.append({"unit": record(unit), "cached_path": path, "neighbors": neighbors,
			"last_callback": callbacks.get(unit.unit_id, {}), "contacts": _contacts(unit),
			"distance_to_historical_stop": unit.global_position.distance_to(HISTORICAL_STOP)})
	focused_frames.append({"frame": frame, "phase": "observer_physics", "units": samples})


func _probe_recovery(unit: RTSUnit) -> Dictionary:
	# Query after the transition: selected target is an actual production result.
	# Other candidates/reasons are recomputed from this synchronous state. They
	# do not mutate the mover or assert equivalence to hidden navigation/RVO state.
	var map := unit.agent.get_navigation_map()
	var selected_path := []
	for point in NavigationServer3D.map_get_path(map, unit.global_position, unit.recovery_target, true):
		selected_path.append(vector(point))
	var candidates := []
	var forward := (unit.assigned_destination - unit.global_position).normalized()
	for index in unit.recovery_candidates:
		var proposed := unit.global_position + forward.rotated(Vector3.UP, TAU * index / unit.recovery_candidates) * unit.recovery_radius
		var candidate := NavigationServer3D.map_get_closest_point(map, proposed)
		var path := NavigationServer3D.map_get_path(map, unit.global_position, candidate, true)
		var length := 0.0
		var points := []
		for segment in path.size():
			points.append(vector(path[segment]))
			if segment > 0:
				length += path[segment - 1].distance_to(path[segment])
		var shape := SphereShape3D.new()
		shape.radius = unit.settling_radius
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = candidate + Vector3.UP * 0.6
		query.collision_mask = 2
		query.exclude = [unit.get_rid()]
		var occupied := not unit.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
		var ray := PhysicsRayQueryParameters3D.create(unit.global_position + Vector3.UP * 0.6, candidate + Vector3.UP * 0.6, 2 | 4, [unit.get_rid()])
		var hit := unit.get_world_3d().direct_space_state.intersect_ray(ray)
		var intrusions := []
		for other in members:
			if not is_instance_valid(other) or other == unit or other.moving or not other.agent.avoidance_enabled:
				continue
			var distance := INF
			for segment in range(1, path.size()):
				distance = minf(distance, Geometry3D.get_closest_point_to_segment(other.global_position, path[segment - 1], path[segment]).distance_to(other.global_position))
			if distance < unit.agent.radius + other.agent.radius:
				intrusions.append({"id": other.unit_id, "distance": distance, "radii_sum": unit.agent.radius + other.agent.radius,
					"initial_distance": unit.global_position.distance_to(other.global_position)})
		var reasons := []
		if candidate.distance_to(proposed) > unit.recovery_projection_slack:
			reasons.append("projection")
		if candidate.distance_to(unit.global_position) < unit.recovery_radius * 0.6:
			reasons.append("too_short")
		if occupied:
			reasons.append("occupied_endpoint")
		if not hit.is_empty():
			reasons.append("center_ray_hit")
		if path.is_empty() or path[-1].distance_to(candidate) > 0.1:
			reasons.append("unreached_endpoint")
		if length > unit.recovery_radius * unit.recovery_path_factor:
			reasons.append("path_too_long")
		candidates.append({"index": index, "proposed": vector(proposed), "projected": vector(candidate),
			"path": points, "path_length": length, "original_selector_rejection_reasons": reasons,
			"parked_path_intrusions": intrusions, "score": candidate.distance_to(unit.assigned_destination) + length * 0.2,
			"matches_observed_target": candidate.distance_to(unit.recovery_target) < 0.001})
	return {"frame": Engine.get_physics_frames() - first_frame, "unit": record(unit),
		"all_units": records(), "selected_path": selected_path, "recomputed_candidates": candidates,
		"assigned_projection": vector(NavigationServer3D.map_get_closest_point(map, unit.assigned_destination)),
		"map_iteration": NavigationServer3D.map_get_iteration_id(map)}


func finish(failed: bool, metrics: Dictionary, prefix: String) -> void:
	# The inherited finish disconnects every state/velocity listener.
	super.finish(failed, metrics, prefix + "-summary")
	var result := {"trace_schema": 2, "first_physics_frame": first_frame,
		"historical_goal": vector(HISTORICAL_GOAL), "historical_stop": vector(HISTORICAL_STOP),
		"initial": initial, "command": command, "final": inspect(), "failed": failed, "metrics": metrics,
		"history_truncated": history_truncated, "group_history_4hz": route_history,
		"focused_frames_60hz": focused_frames, "events": route_events, "recovery_probes": recovery_probes,
		"limitations": "Controlled observation, not hidden-state replay. Callback and physics records carry distinct phases/frames. Candidate diagnostics are recomputed after transition. Instrumentation can perturb timing."}
	var file := FileAccess.open(prefix + "-trace.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
