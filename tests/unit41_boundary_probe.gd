extends "res://tests/full_sequence_probe.gd"
## Test-only observations of actual inherited selection and Issue A guard calls.
## No copied selector, additional engine query, or movement-state write.
var boundary_selection_sequence := 0
var boundary_selection_active := false


func _choose_recovery_waypoint(neighbors: Array[Dictionary]) -> Vector3:
	var source := recorder
	var before := _capture(source)
	boundary_selection_sequence += 1
	boundary_selection_active = true
	var result := super._choose_recovery_waypoint(neighbors)
	boundary_selection_active = false
	_record(source, "boundary_selection_result", before, {
		"selection_sequence": boundary_selection_sequence, "actual_return": _vector(result),
		"neighbors": _boundary_neighbors(neighbors),
		"provenance": "actual unchanged inherited selector return; earlier inline rejection branches unavailable"})
	return result


func _recovery_path_clear(path: PackedVector3Array, neighbors: Array[Dictionary]) -> bool:
	var source := recorder
	var before := _capture(source)
	var result := super._recovery_path_clear(path, neighbors)
	var points := []
	for point in path:
		points.append(_vector(point))
	_record(source, "boundary_path_clear_result", before, {
		"selection_sequence": boundary_selection_sequence, "inside_selection": boundary_selection_active,
		"path": points, "neighbors": _boundary_neighbors(neighbors), "actual_return": result,
		"provenance": "actual unchanged inherited Issue A guard return on production supplied path/neighbors"})
	return result


func _boundary_neighbors(neighbors: Array[Dictionary]) -> Array:
	var observations := []
	for hit in neighbors:
		var other = hit.get("collider")
		if is_instance_valid(other) and other is RTSUnit:
			observations.append(_capture_neighbor(other))
	return observations


func _capture_neighbor(other: RTSUnit) -> Dictionary:
	return recorder.state(other) if is_instance_valid(recorder) and recorder.live else {}
