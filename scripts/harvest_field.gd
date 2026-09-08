class_name HarvestField
extends ProductionField
## Fixed resource geometry, contextual dispatch, and small per-target access claims.

const CACHE_FOOTPRINTS: Array[Rect2] = [Rect2(-9, -17.5, 4, 3), Rect2(4, -18.5, 4, 3)]
const COLLECTOR_STARTS: Array[Vector3] = [Vector3(-14.5, 0, -8), Vector3(-14.5, 0, -4)]
@export var cache_supplies: int = 2000
var caches: Array[SupplyCache] = []
var collectors: Array[CollectorTruck] = []
var harvest_panel: HarvestPanel
var _caches: Dictionary[int, WeakRef] = {}
var _access_claims: Dictionary = {} # target instance ID -> at most eight weak occupants.
var _interaction_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_next_unit = STARTS.size() + COLLECTOR_STARTS.size()
	_interaction_query.collision_mask = 4 | LineOfFire.BLOCKER_MASK
	_interaction_query.hit_from_inside = true
	super._ready()
	selection.harvest_requested.connect(issue_harvest)
	selection.deposit_requested.connect(issue_deposit)
	headquarters.tree_exiting.connect(_release_target.bind(headquarters.get_instance_id()))
	harvest_panel = HarvestPanel.new()
	harvest_panel.field = self
	get_node("ControlsFeedback").add_child(harvest_panel)
	(info_panel.get_child(0).get_child(0) as Label).text = "FIELDWORK  /  HARVESTING"
	var controls := info_panel.get_child(0).get_child(1) as Label
	controls.text += "\nCollectors + right click · Harvest / deposit"


func _build_field() -> void:
	obstacles.append_array(CACHE_FOOTPRINTS)
	super._build_field()


func _unit_count() -> int:
	return STARTS.size() + COLLECTOR_STARTS.size()


func _create_unit(index: int) -> RTSUnit:
	if index < STARTS.size():
		return super._create_unit(index)
	var unit := CollectorTruck.new()
	unit.unit_id = index + 1
	unit.name = "Collector%02d" % unit.unit_id
	unit.position = COLLECTOR_STARTS[index - STARTS.size()]
	collectors.append(unit)
	return unit


func _build_obstacle(index: int, rectangle: Rect2) -> void:
	if index < BASE_OBSTACLES.size():
		super._build_obstacle(index, rectangle)
		return
	var cache := SupplyCache.new()
	cache.cache_id = index - BASE_OBSTACLES.size() + 1
	cache.name = "Supply%d" % cache.cache_id
	cache.initial_supplies = cache_supplies
	cache.footprint = rectangle.size
	cache.position = Vector3(rectangle.get_center().x, 0, rectangle.get_center().y)
	add_child(cache)
	caches.append(cache)
	register_cache(cache)


func _live_descendant(node: Node) -> bool:
	if _closing or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(node) or not node.is_inside_tree():
		return false
	var ancestor := node
	while ancestor != null and ancestor != self:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return ancestor == self


func harvest_member(unit: CollectorTruck) -> bool:
	return gameplay_enabled and is_instance_valid(unit) and contains_unit(unit) and _live_descendant(unit)


func contains_cache(cache: SupplyCache) -> bool:
	return is_instance_valid(cache) and _live_descendant(cache) and _caches.has(cache.get_instance_id())


func register_cache(cache: SupplyCache) -> void:
	if not _live_descendant(cache):
		return
	var id := cache.get_instance_id()
	_caches[id] = weakref(cache)
	var exiting := _cache_exiting.bind(id)
	if not cache.tree_exiting.is_connected(exiting):
		cache.tree_exiting.connect(exiting)
		cache.tree_entered.connect(register_cache.bind(cache))


func _cache_exiting(id: int) -> void:
	_caches.erase(id)
	_release_target(id)


func registered_caches() -> Array[SupplyCache]:
	var members: Array[SupplyCache] = []
	for entry in _caches.values():
		var cache := (entry as WeakRef).get_ref() as SupplyCache
		if is_instance_valid(cache) and contains_cache(cache):
			members.append(cache)
	return members


func _release_target(id: int) -> void:
	_access_claims.erase(id)


func valid_dropoff(building: RTSBuilding, owner: int) -> bool:
	return is_instance_valid(building) and contains_building(building) and building.kind == RTSBuilding.Kind.HEADQUARTERS and building.owner_id == owner


func _valid_access_target(target: Node3D, owner: int) -> bool:
	if target is SupplyCache:
		return contains_cache(target as SupplyCache)
	return target is RTSBuilding and valid_dropoff(target as RTSBuilding, owner)


func access_positions(target: Node3D) -> Array[Dictionary]:
	var footprint: Vector2 = target.footprint
	var positions: Array[Dictionary] = []
	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var side := Vector3(-axis.z, 0, axis.x)
		var extent := footprint.x / 2.0 if axis.x != 0 else footprint.y / 2.0
		for offset in [-1.0, 1.0]:
			var dock: Vector3 = target.global_position + axis * (extent + 0.1) + side * offset
			positions.append({"point": dock + axis * 1.2, "dock": dock, "slot": positions.size(), "target": target.get_instance_id()})
	return positions


func plan_access(unit: CollectorTruck, target: Node3D) -> Dictionary:
	if not harvest_member(unit) or not is_instance_valid(target) or not _valid_access_target(target, unit.owner_id):
		return {}
	var id := target.get_instance_id()
	var claims: Dictionary = _access_claims.get(id, {})
	var best: Dictionary = {}
	var distance := INF
	# Eight candidates, queried only on commands/trip boundaries. Ties use slot order.
	for candidate in access_positions(target):
		var occupant: CollectorTruck = claims[candidate["slot"]].get_ref() as CollectorTruck if claims.has(candidate["slot"]) else null
		if is_instance_valid(occupant) and harvest_member(occupant) and occupant != unit:
			continue
		var point: Vector3 = candidate["point"]
		var length := unit.global_position.distance_squared_to(point)
		if length < distance and valid_rally(unit.global_position, point):
			best = candidate
			distance = length
	return best


func claim_access(unit: CollectorTruck, access: Dictionary) -> void:
	if not _access_claims.has(access["target"]):
		_access_claims[access["target"]] = {}
	_access_claims[access["target"]][access["slot"]] = weakref(unit)


func release_access(unit: CollectorTruck) -> void:
	# Bounded by scene targets and eight slots, at departures/interruption only.
	for id in _access_claims.keys():
		var claims: Dictionary = _access_claims[id]
		for slot in claims.keys():
			var occupant := claims[slot].get_ref() as CollectorTruck
			if not is_instance_valid(occupant) or occupant == unit:
				claims.erase(slot)
		if claims.is_empty():
			_access_claims.erase(id)


func can_interact(unit: CollectorTruck, target: Node3D, access: Dictionary) -> bool:
	if not Engine.is_in_physics_frame() or not harvest_member(unit) or not is_instance_valid(target) or not _valid_access_target(target, unit.owner_id) or access.is_empty():
		return false
	var id := target.get_instance_id()
	var claims: Dictionary = _access_claims.get(id, {})
	if access["target"] != id or not claims.has(access["slot"]) or claims[access["slot"]].get_ref() != unit:
		return false
	var point: Vector3 = access["point"]
	if unit.moving or unit.movement_state != RTSUnit.MovementState.ARRIVED or unit.global_position.distance_to(point) > unit.interaction_distance or not _nav_point(point):
		return false
	# End just outside the target's face. Include the target and inside hits;
	# neither a wall nor standing inside a collider can grant remote interaction.
	_interaction_query.from = unit.global_position + Vector3.UP * 0.6
	_interaction_query.to = access["dock"] + Vector3.UP * 0.6
	return get_world_3d().direct_space_state.intersect_ray(_interaction_query).is_empty()


func issue_harvest(cache: SupplyCache) -> CommandBatchResult:
	return _issue_resource(cache, true)


func issue_deposit(building: RTSBuilding) -> CommandBatchResult:
	return _issue_resource(building, false)


func _issue_resource(target: Node3D, automatic: bool) -> CommandBatchResult:
	var result := _new_batch()
	var selected := _batch_selection(result)
	if result.superseded or selected.is_empty():
		return result
	var eligible := false
	for unit in selected:
		if unit is CollectorTruck and (unit as CollectorTruck).harvesting.can_order(target, automatic):
			eligible = true
	if not eligible:
		status_label.text = "Harvest rejected · select collector, nonempty supply and owned HQ"
		return result
	_command_version = result.generation
	for i in selected.size():
		if not is_instance_valid(self) or _command_version != result.generation:
			break
		var unit := selected[i]
		if not is_instance_valid(unit) or not unit is CollectorTruck or not is_instance_valid(target):
			continue
		if (unit as CollectorTruck).harvesting.issue(target, automatic):
			result.accepted_ids.append(result.intended_ids[i])
	if not is_instance_valid(self):
		result.superseded = true
		return result
	return _finish_batch(result, "Harvest" if automatic else "Deposit once")


func _exit_tree() -> void:
	_access_claims.clear()
	_caches.clear()
	super._exit_tree()
