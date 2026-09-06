class_name GroupDestinations
extends Node
## Generates navigable, separated slots, then assigns them once per command.

@export var slot_spacing: float = 1.5
@export_range(2.0, 40.0, 0.5) var maximum_radius: float = 18.0
@export_range(1.0, 3.0, 0.1) var radius_scale: float = 1.85
@export_range(1, 6) var improvement_passes: int = 3
@export_range(100, 4000) var candidate_budget: int = 1600

var last_generation_usec: int = 0
var last_assignment_usec: int = 0


func generate_slots(map: RID, clicked: Vector3, count: int, reserved: PackedVector3Array = PackedVector3Array()) -> PackedVector3Array:
	var started := Time.get_ticks_usec()
	var slots := PackedVector3Array()
	if count <= 0 or NavigationServer3D.map_get_iteration_id(map) == 0:
		return slots
	var center := NavigationServer3D.map_get_closest_point(map, clicked)
	var spacing := maxf(slot_spacing, 0.1)
	var radius := minf(maximum_radius, spacing * maxf(2.0, sqrt(float(count)) * radius_scale))
	var rings := mini(ceili(radius / spacing), floori((sqrt(float(candidate_budget)) - 1.0) * 0.5))
	var offsets: Array[Vector2i] = []
	for x in range(-rings, rings + 1):
		for z in range(-rings, rings + 1):
			if Vector2(x, z).length() * spacing <= radius:
				offsets.append(Vector2i(x, z))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.length_squared() != b.length_squared():
			return a.length_squared() < b.length_squared()
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	# Spatial buckets reject clamped duplicates without scanning every accepted slot.
	var occupied: Dictionary[Vector2i, Array] = {}
	for point in reserved:
		var cell := Vector2i(floori(point.x / spacing), floori(point.z / spacing))
		if not occupied.has(cell):
			occupied[cell] = []
		occupied[cell].append(point)
	for offset in offsets:
		var proposed := center + Vector3(offset.x * spacing, 0, offset.y * spacing)
		var candidate := NavigationServer3D.map_get_closest_point(map, proposed)
		if candidate.distance_to(center) > radius + 0.001:
			continue
		var cell := Vector2i(floori(candidate.x / spacing), floori(candidate.z / spacing))
		if not _separated(candidate, cell, occupied, spacing):
			continue
		var path := NavigationServer3D.map_get_path(map, center, candidate, true)
		if path.is_empty() or path[path.size() - 1].distance_to(candidate) > 0.1:
			continue
		slots.append(candidate)
		if not occupied.has(cell):
			occupied[cell] = []
		occupied[cell].append(candidate)
		if slots.size() == count:
			last_generation_usec = Time.get_ticks_usec() - started
			return slots
	# All-or-nothing: a cramped/disconnected map must not collapse or reuse slots.
	last_generation_usec = Time.get_ticks_usec() - started
	return PackedVector3Array()


func _separated(point: Vector3, cell: Vector2i, occupied: Dictionary[Vector2i, Array], spacing: float) -> bool:
	for x in range(-1, 2):
		for z in range(-1, 2):
			for accepted: Vector3 in occupied.get(cell + Vector2i(x, z), []):
				if point.distance_squared_to(accepted) < pow(spacing - 0.001, 2):
					return false
	return true


func assign_slots(units: Array[RTSUnit], slots: PackedVector3Array) -> PackedVector3Array:
	var started := Time.get_ticks_usec()
	var assigned := PackedVector3Array()
	if units.size() != slots.size():
		return assigned
	assigned.resize(units.size())
	var unit_order: Array[int] = []
	var slot_order: Array[int] = []
	for i in units.size():
		unit_order.append(i)
		slot_order.append(i)
	unit_order.sort_custom(func(a: int, b: int) -> bool:
		return _position_before(units[a].global_position, units[b].global_position, a, b))
	slot_order.sort_custom(func(a: int, b: int) -> bool:
		return _position_before(slots[a], slots[b], a, b))
	for rank in units.size():
		assigned[unit_order[rank]] = slots[slot_order[rank]]
	# A fixed number of pair-swap passes is O(n²), unlike repeated all-pair greedy
	# searches or n improvement passes. Stable indices break all equal-cost ties.
	for _pass in range(improvement_passes):
		var improved := false
		for a in units.size():
			for b in range(a + 1, units.size()):
				var current := units[a].global_position.distance_to(assigned[a]) + units[b].global_position.distance_to(assigned[b])
				var swapped := units[a].global_position.distance_to(assigned[b]) + units[b].global_position.distance_to(assigned[a])
				if swapped + 0.001 < current:
					var temporary := assigned[a]
					assigned[a] = assigned[b]
					assigned[b] = temporary
					improved = true
		if not improved:
			break
	last_assignment_usec = Time.get_ticks_usec() - started
	return assigned


func _position_before(a: Vector3, b: Vector3, a_index: int, b_index: int) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.z != b.z:
		return a.z < b.z
	return a_index < b_index
