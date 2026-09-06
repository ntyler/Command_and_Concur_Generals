class_name LineOfFire
extends RefCounted
## Field-owned, physics-step-only queries against explicitly marked static solids.

const BLOCKER_MASK: int = 1 << 3 # Physics layer 4: Weapon Blockers.
const CONTACT_EPSILON: float = 0.0001
const BODY_HEIGHT: float = 0.6
const MUZZLE_HEIGHT: float = 0.9
const AIM_HEIGHT: float = 0.75

class Trace extends RefCounted:
	var available: bool = false
	var blocked: bool = false
	var position: Vector3
	var collider_id: int = 0
	var from_position: Vector3
	var to_position: Vector3
	func is_clear() -> bool:
		return available and not blocked

var clearance_queries: int = 0
var segment_queries: int = 0
var physics_queries: int = 0
var _ray := PhysicsRayQueryParameters3D.new()
var _point := PhysicsShapeQueryParameters3D.new()


func _init() -> void:
	_ray.collision_mask = BLOCKER_MASK
	_ray.hit_from_inside = true
	_ray.collide_with_areas = false
	var probe := SphereShape3D.new()
	probe.radius = CONTACT_EPSILON
	_point.shape = probe
	_point.margin = 0.0
	_point.collision_mask = BLOCKER_MASK
	_point.collide_with_areas = false


static func muzzle(unit: RTSUnit) -> Vector3:
	return unit.global_position + Vector3.UP * MUZZLE_HEIGHT


static func aim(unit: RTSUnit) -> Vector3:
	return unit.global_position + Vector3.UP * AIM_HEIGHT


func firing_line(source: RTSUnit, target: RTSUnit) -> Trace:
	clearance_queries += 1
	var world := source.get_world_3d()
	# The centerline muzzle stays within the body footprint. Also validate the
	# short vertical attachment so geometry between body and muzzle cannot bypass.
	var attachment := segment(world, source.global_position + Vector3.UP * BODY_HEIGHT, muzzle(source))
	if not attachment.is_clear():
		return attachment
	return segment(world, muzzle(source), aim(target))


func segment(world: World3D, from: Vector3, to: Vector3) -> Trace:
	var result := Trace.new()
	result.from_position = from
	result.to_position = to
	result.position = to
	# Commands/input may run outside physics. Unavailable is never clear.
	if not Engine.is_in_physics_frame() or world == null:
		return result
	segment_queries += 1
	result.available = true
	var space := world.direct_space_state
	_point.transform = Transform3D(Basis.IDENTITY, from)
	physics_queries += 1
	var origin_hits := space.intersect_shape(_point, 1)
	if not origin_hits.is_empty():
		result.blocked = true
		result.position = from
		result.collider_id = origin_hits[0]["collider_id"]
		return result
	if from != to:
		_ray.from = from
		_ray.to = to # Never extend past the target or intended next position.
		physics_queries += 1
		var hit := space.intersect_ray(_ray)
		if not hit.is_empty():
			result.blocked = true
			result.position = hit["position"]
			result.collider_id = hit["collider_id"]
			return result
	# Conservative numerical tie at the endpoint, including a zero-length step.
	# This 0.1 mm skin is not the visible rocket's radius.
	_point.transform.origin = to
	physics_queries += 1
	var endpoint_hits := space.intersect_shape(_point, 1)
	if not endpoint_hits.is_empty():
		result.blocked = true
		result.position = to
		result.collider_id = endpoint_hits[0]["collider_id"]
	return result
