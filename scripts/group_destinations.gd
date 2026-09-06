class_name GroupDestinations
extends Node
## Generates navigable, separated slots, then assigns them once per command.

@export var slot_spacing: float = 1.5
@export var search_rings: int = 64


func generate_slots(map: RID, clicked: Vector3, count: int) -> PackedVector3Array:
	var slots := PackedVector3Array()
	if count <= 0 or NavigationServer3D.map_get_iteration_id(map) == 0:
		return slots
	var center := NavigationServer3D.map_get_closest_point(map, clicked)
	var spacing := maxf(slot_spacing, 0.1)
	for ring in range(search_rings + 1):
		var offsets: Array[Vector2i] = []
		for x in range(-ring, ring + 1):
			for z in range(-ring, ring + 1):
				if maxi(absi(x), absi(z)) == ring:
					offsets.append(Vector2i(x, z))
		offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if a.length_squared() != b.length_squared():
				return a.length_squared() < b.length_squared()
			return a.x < b.x or (a.x == b.x and a.y < b.y))
		for offset in offsets:
			var proposed := center + Vector3(offset.x * spacing, 0, offset.y * spacing)
			var candidate := NavigationServer3D.map_get_closest_point(map, proposed)
			var separated := true
			for accepted in slots:
				if candidate.distance_to(accepted) < spacing - 0.001:
					separated = false
					break
			if not separated:
				continue
			var path := NavigationServer3D.map_get_path(map, center, candidate, true)
			if path.is_empty() or path[path.size() - 1].distance_to(candidate) > 0.1:
				continue
			slots.append(candidate)
			if slots.size() == count:
				return slots
	# All-or-nothing: a cramped/disconnected map must not collapse or reuse slots.
	return PackedVector3Array()


func assign_slots(units: Array[RTSUnit], slots: PackedVector3Array) -> PackedVector3Array:
	var assigned := PackedVector3Array()
	if units.size() != slots.size():
		return assigned
	assigned.resize(units.size())
	var remaining_units: Array[int] = []
	var remaining_slots: Array[int] = []
	for i in units.size():
		remaining_units.append(i)
		remaining_slots.append(i)
	while not remaining_units.is_empty():
		var best_unit: int = remaining_units[0]
		var best_slot: int = remaining_slots[0]
		var best_cost: float = INF
		for unit_index in remaining_units:
			for slot_index in remaining_slots:
				var cost := units[unit_index].global_position.distance_squared_to(slots[slot_index])
				if cost < best_cost:
					best_cost = cost
					best_unit = unit_index
					best_slot = slot_index
		assigned[best_unit] = slots[best_slot]
		remaining_units.erase(best_unit)
		remaining_slots.erase(best_slot)
	# Deterministic pair swaps reduce travel and obvious crossing; no ongoing reassignment.
	for _pass in range(units.size()):
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
	return assigned
