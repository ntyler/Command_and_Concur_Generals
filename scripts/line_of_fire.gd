class_name LineOfFire
extends RefCounted
## Field-owned, physics-step-only queries against explicitly marked static solids.

const BLOCKER_MASK: int = 1 << 3 # Physics layer 4: Weapon Blockers.
const CONTACT_EPSILON: float = 0.0001
const SPHERE_QUERY_MARGIN: float = 0.0001 # Conservative skin; separate from radius.
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
	var center_position: Vector3 # Safe sphere center, distinct from surface contact.
	var travel_fraction: float = 1.0
	func is_clear() -> bool:
		return available and not blocked

var clearance_queries: int = 0
var segment_queries: int = 0
var physics_queries: int = 0
var sphere_queries: int = 0
var _ray := PhysicsRayQueryParameters3D.new()
var _point := PhysicsShapeQueryParameters3D.new()
var _sphere := SphereShape3D.new()
var _sphere_query := PhysicsShapeQueryParameters3D.new()


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
	_sphere_query.shape = _sphere
	_sphere_query.margin = SPHERE_QUERY_MARGIN
	_sphere_query.collision_mask = BLOCKER_MASK
	_sphere_query.collide_with_areas = false


static func target_exclusions(target: Node3D) -> Array[RID]:
	# Only the intended building is excluded. Every intervening blocker remains solid.
	var exclusions: Array[RID] = []
	if target is RTSBuilding:
		exclusions.append(target.get_rid())
	return exclusions


static func muzzle(unit: Node3D) -> Vector3:
	if unit is GroundDefenseBattery:
		return unit.weapon_origin()
	return unit.global_position + Vector3.UP * MUZZLE_HEIGHT


static func aim(unit: Node3D) -> Vector3:
	return unit.global_position + Vector3.UP * AIM_HEIGHT


func weapon_clearance(source: Node3D, target: Node3D, definition: WeaponDefinition) -> Trace:
	var line := firing_line(source, target)
	if not line.is_clear() or definition.mode != WeaponDefinition.Mode.GUIDED_PROJECTILE:
		return line
	# Only the launch volume is tested here. A clear line can still graze during
	# spherical flight; hitscan always retains its original line-only policy.
	var launch := sweep_sphere(source.get_world_3d(), muzzle(source), muzzle(source), definition.projectile_collision_radius)
	return line if launch.is_clear() else launch


func firing_line(source: Node3D, target: Node3D) -> Trace:
	clearance_queries += 1
	var world := source.get_world_3d()
	# The centerline muzzle stays within the body footprint. Also validate the
	# short vertical attachment so geometry between body and muzzle cannot bypass.
	var exclusions: Array[RID] = []
	var attachment_start := source.global_position + Vector3.UP * BODY_HEIGHT
	if source is GroundDefenseBattery:
		# The committed stationary footprint is still a blocker to every other
		# weapon. Only its own attachment/shot excludes its own collision RID.
		exclusions.append(source.get_rid())
		attachment_start = source.weapon_attachment()
	var attachment := segment(world, attachment_start, muzzle(source), exclusions)
	if not attachment.is_clear():
		return attachment
	exclusions.append_array(target_exclusions(target))
	return segment(world, muzzle(source), aim(target), exclusions)


func segment(world: World3D, from: Vector3, to: Vector3, exclusions: Array[RID] = []) -> Trace:
	var result := Trace.new()
	result.from_position = from
	result.to_position = to
	result.position = to
	# Commands/input may run outside physics. Unavailable is never clear.
	if not Engine.is_in_physics_frame() or world == null or not from.is_finite() or not to.is_finite():
		return result
	_ray.exclude = exclusions
	_point.exclude = exclusions
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


func sweep_sphere(world: World3D, from: Vector3, to: Vector3, radius: float, exclusions: Array[RID] = []) -> Trace:
	var result := Trace.new()
	result.from_position = from
	result.to_position = to
	result.position = to
	result.center_position = to
	if not Engine.is_in_physics_frame() or world == null or not is_finite(radius) or radius <= 0.0:
		return result
	_sphere_query.exclude = exclusions
	sphere_queries += 1
	result.available = true
	if _sphere.radius != radius:
		_sphere.radius = radius
	_sphere_query.transform = Transform3D(Basis.IDENTITY, from)
	_sphere_query.motion = Vector3.ZERO
	var space := world.direct_space_state
	physics_queries += 1
	var initial := space.intersect_shape(_sphere_query, 1)
	if not initial.is_empty():
		result.blocked = true
		result.travel_fraction = 0.0
		result.center_position = from
		result.collider_id = initial[0]["collider_id"]
		_sphere_contact(space, result, from)
		return result
	if from == to:
		return result
	_sphere_query.motion = to - from
	physics_queries += 1
	var fractions := space.cast_motion(_sphere_query)
	if fractions.size() != 2:
		result.available = false # Never manufacture clearance from a failed query.
		return result
	if fractions[0] < 1.0:
		result.blocked = true
		result.travel_fraction = fractions[0]
		result.center_position = from.lerp(to, fractions[0])
		# Safe fraction controls movement; unsafe fraction locates presentation.
		_sphere_contact(space, result, from.lerp(to, fractions[1]))
		return result
	# Inclusive endpoint contact/ties use the same radius and margin as the sweep.
	_sphere_query.motion = Vector3.ZERO
	_sphere_query.transform.origin = to
	physics_queries += 1
	var endpoint := space.intersect_shape(_sphere_query, 1)
	if not endpoint.is_empty():
		result.blocked = true
		result.collider_id = endpoint[0]["collider_id"]
		_sphere_contact(space, result, to)
	return result


func _sphere_contact(space: PhysicsDirectSpaceState3D, result: Trace, probe_center: Vector3) -> void:
	_sphere_query.motion = Vector3.ZERO
	_sphere_query.transform.origin = probe_center
	physics_queries += 1
	var info := space.get_rest_info(_sphere_query)
	result.position = result.center_position # Safe fallback if a contact has no rest point.
	if not info.is_empty():
		result.position = info["point"]
		result.collider_id = info["collider_id"]
