extends Node
## Opt-in test observer. Never loaded by a gameplay scene. No movement writes.
## 4 Hz, 128 snapshots (32 seconds), plus 256 state transitions. No path queries
## or pair searches in sampling; command/end inspection runs outside movement.

const CAPACITY := 128
const EVENT_CAPACITY := 256
var field: TestField
var members: Array[RTSUnit] = []
var history: Array = []
var events: Array = []
var initial: Dictionary
var command: Dictionary = {}
var safe: Dictionary = {}
var connections: Array = []
var first_frame: int
var tick: int = 0
var cursor: int = 0
var event_cursor: int = 0
var supports_suspension: bool = false


static func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func begin(source: TestField) -> void:
	field = source
	members = field.units.duplicate()
	first_frame = Engine.get_physics_frames()
	for property in members[0].get_property_list():
		if property.name == "navigation_suspended":
			supports_suspension = true
	initial = inspect()
	for unit in members:
		var state_callback := _state_changed.bind(unit)
		var velocity_callback := _velocity_computed.bind(unit.unit_id)
		unit.movement_state_changed.connect(state_callback)
		unit.agent.velocity_computed.connect(velocity_callback)
		connections.append([unit, state_callback, velocity_callback])


func _velocity_computed(value: Vector3, id: int) -> void:
	# Production callback is connected first; retain its input without applying it.
	safe[id] = value


func _state_changed(_state: int, unit: RTSUnit) -> void:
	var event := {"frame": Engine.get_physics_frames() - first_frame, "unit": record(unit)}
	if events.size() < EVENT_CAPACITY:
		events.append(event)
	else:
		events[event_cursor] = event
		event_cursor = (event_cursor + 1) % EVENT_CAPACITY


func _physics_process(_delta: float) -> void:
	if command.is_empty() and field.last_command_result != null:
		var batch := field.last_command_result
		var assignments := {}
		for id in batch.assignments:
			assignments[id] = vector(batch.assignments[id])
		command = {"generation": batch.generation, "intended_ids": batch.intended_ids.duplicate(),
			"accepted_ids": batch.accepted_ids.duplicate(), "superseded": batch.superseded,
			"assignments": assignments, "units": records()}
	if tick % 15 == 0:
		var snapshot := {"frame": Engine.get_physics_frames() - first_frame,
			"map_iteration": NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()),
			"group_generation": field._command_version, "units": records()}
		if history.size() < CAPACITY:
			history.append(snapshot)
		else:
			history[cursor] = snapshot
			cursor = (cursor + 1) % CAPACITY
	tick += 1


func records() -> Array:
	var result := []
	for unit in members:
		result.append(record(unit) if is_instance_valid(unit) else {"departed": true})
	return result


func record(unit: RTSUnit) -> Dictionary:
	var path := unit.agent.get_current_navigation_path()
	var path_remaining := 0.0
	var previous := unit.global_position
	for index in range(unit.agent.get_current_navigation_path_index(), path.size()):
		path_remaining += previous.distance_to(path[index])
		previous = path[index]
	return {"id": unit.unit_id, "instance_id": unit.get_instance_id(), "member": field.contains_unit(unit),
		"position": vector(unit.global_position), "assigned": vector(unit.assigned_destination),
		"agent_target": vector(unit.agent.target_position), "next_waypoint": vector(unit.next_waypoint),
		"requested_velocity": vector(unit.agent.velocity), "applied_velocity": vector(unit.velocity),
		"last_safe_callback": vector(safe.get(unit.unit_id, Vector3.ZERO)),
		"state": RTSUnit.MovementState.keys()[unit.movement_state], "moving": unit.moving,
		"order_version": unit.order_version, "submitted_order": unit._submitted_order,
		"last_movement_frame": unit._last_movement_frame, "elapsed": unit.command_elapsed,
		"progress_baseline": unit._progress_remaining if is_finite(unit._progress_remaining) else -1.0,
		"cached_agent_path_remaining": path_remaining, "path_size": path.size(),
		"path_index": unit.agent.get_current_navigation_path_index(), "stall": unit.stalled_for,
		"recoveries": unit.recovery_attempts, "recovery_active": unit.recovery_active,
		"recovery_target": vector(unit.recovery_target), "recovery_elapsed": unit._recovery_elapsed,
		"last_recovery_time": unit.last_recovery_time if is_finite(unit.last_recovery_time) else -1.0,
		"avoidance": unit.agent.avoidance_enabled, "radius": unit.agent.radius,
		"priority": unit.agent.avoidance_priority, "max_speed": unit.agent.max_speed,
		"neighbors": unit.agent.max_neighbors, "neighbor_distance": unit.agent.neighbor_distance,
		"horizon": unit.agent.time_horizon_agents,
		"suspended": unit.get("navigation_suspended") if supports_suspension else false}


func inspect() -> Dictionary:
	var map := field.get_world_3d().get_navigation_map()
	var mesh := field.navigation_region.navigation_mesh
	var geometry := {"vertices": [], "polygons": []}
	for point in mesh.get_vertices():
		geometry.vertices.append(vector(point))
	for index in mesh.get_polygon_count():
		geometry.polygons.append(Array(mesh.get_polygon(index)))
	var obstacles := []
	for rectangle in field.obstacles:
		obstacles.append([rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y])
	var paths := []
	for unit in members:
		var path := NavigationServer3D.map_get_path(map, unit.global_position, unit.assigned_destination, true)
		var length := 0.0
		for index in range(1, path.size()):
			length += path[index - 1].distance_to(path[index])
		paths.append({"id": unit.unit_id, "length": length, "size": path.size(),
			"endpoint": vector(path[-1]) if not path.is_empty() else [],
			"projection": vector(NavigationServer3D.map_get_closest_point(map, unit.assigned_destination))})
	return {"units": records(), "paths_to_assigned": paths, "field_script": field.get_script().resource_path,
		"registry_count": field._registered.size(), "tree_group_count": get_tree().get_nodes_in_group("controllable_units").size(),
		"map_iteration": NavigationServer3D.map_get_iteration_id(map), "map_regions": NavigationServer3D.map_get_regions(map).size(),
		"region_iteration": NavigationServer3D.region_get_iteration_id(field.navigation_region.get_rid()),
		"geometry_sha256": JSON.stringify(geometry).sha256_text(), "obstacles": obstacles,
		"group_generation": field._command_version, "next_generation": field._next_command_generation,
		"engine": Engine.get_version_info(), "arguments": Array(OS.get_cmdline_args()),
		"user_arguments": Array(OS.get_cmdline_user_args()), "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"physics_engine_setting": ProjectSettings.get_setting("physics/3d/physics_engine"),
		"physics_ticks": Engine.physics_ticks_per_second, "max_physics_steps": Engine.max_physics_steps_per_frame,
		"physics_jitter_fix": Engine.physics_jitter_fix, "time_scale": Engine.time_scale,
		"viewport": [get_viewport().size.x, get_viewport().size.y]}


func finish(failed: bool, metrics: Dictionary, prefix: String) -> void:
	set_physics_process(false)
	for connection in connections:
		var unit: RTSUnit = connection[0]
		if is_instance_valid(unit):
			unit.movement_state_changed.disconnect(connection[1])
			unit.agent.velocity_computed.disconnect(connection[2])
	connections.clear()
	var result := {"initial": initial, "command": command, "final": inspect(), "failed": failed, "metrics": metrics}
	if failed:
		result["history"] = history.slice(cursor) + history.slice(0, cursor)
		result["events"] = events.slice(event_cursor) + events.slice(0, event_cursor)
	var file := FileAccess.open(prefix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
