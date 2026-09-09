class_name GuidedProjectile
extends Node3D
## A shot owns its launch data and weak references, independently of source orders.

signal resolved(damage_applied: float)
enum Outcome { NONE, TARGET, WORLD, INVALIDATED, EXPIRED }

var age: float = 0.0
var speed: float
var lifetime: float
var damage: float
var source_team: int
var target_domain: int = TeamRules.TargetDomain.GROUND
var ground_mobile_only: bool = false
var collision_radius: float
var spent: bool = false
var outcome: Outcome = Outcome.NONE
var contact_position: Vector3
var last_segment_start: Vector3
var last_segment_end: Vector3
var _target: WeakRef
var _source: WeakRef
var _field: WeakRef


func configure(field: TestField, source: RTSUnit, target: Node3D, definition: WeaponDefinition) -> void:
	_field = weakref(field)
	_source = weakref(source)
	_target = weakref(target)
	source_team = source.owner_id
	target_domain = definition.target_domain
	ground_mobile_only = definition.ground_mobile_only
	speed = definition.projectile_speed
	lifetime = definition.projectile_lifetime
	damage = definition.damage
	collision_radius = definition.projectile_collision_radius


func _ready() -> void:
	add_to_group("combat_projectiles")
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = collision_radius
	mesh.height = collision_radius * 2.0
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffd27a")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	add_child(visual)


func target_unit() -> RTSUnit:
	return target_actor() as RTSUnit


func target_actor() -> Node3D:
	return _target.get_ref() as Node3D if _target != null else null


func _physics_process(delta: float) -> void:
	if spent:
		return
	var remaining := lifetime - age
	var field := _field.get_ref() as TestField
	var target := target_actor()
	if remaining <= 0.0:
		_finish(Outcome.EXPIRED)
		return
	if not TeamRules.weapon_can_target(field, source_team, target, target_domain, ground_mobile_only):
		_finish(Outcome.INVALIDATED)
		return
	var aim := LineOfFire.aim(target)
	var step := minf(delta, remaining)
	if step <= 0.0:
		return
	last_segment_start = global_position
	last_segment_end = global_position.move_toward(aim, speed * step)
	var travel_time := last_segment_start.distance_to(last_segment_end) / speed
	var contact := field.fire_query.sweep_sphere(get_world_3d(), last_segment_start, last_segment_end, collision_radius, LineOfFire.target_exclusions(target))
	if not contact.available:
		return
	if LineOfFire.hits_intended_barrier(contact, target):
		# At a joint, a different solid at the same/earlier spherical fraction
		# remains obstruction. Do not let physics contact ordering manufacture a
		# hit through an adjacent barrier or support belonging to another target.
		var exclusions: Array[RID] = [(target as BarrierBuilding).get_rid()]
		var other := field.fire_query.sweep_sphere(get_world_3d(), last_segment_start, last_segment_end, collision_radius, exclusions)
		if not other.available:
			return
		if other.blocked and other.travel_fraction <= contact.travel_fraction + 0.000001:
			contact = other
	if contact.blocked:
		age = minf(lifetime, age + travel_time * contact.travel_fraction)
		global_position = contact.center_position
		# Barriers retain their real solid shapes even as intended targets. A
		# target contact uses the same exactly-once impact authority as arrival;
		# any other collider remains a world obstruction with no collateral hit.
		_finish(Outcome.TARGET if LineOfFire.hits_intended_barrier(contact, target) else Outcome.WORLD, contact.position)
		return
	global_position = last_segment_end
	# Resolve contacts along the usable interval before expiration at its endpoint.
	# Sphere/world numerical ties win over the unchanged point target-hit model.
	if global_position == aim:
		age = minf(lifetime, age + travel_time)
		_finish(Outcome.TARGET)
		return
	age = minf(lifetime, age + step)
	if delta >= remaining:
		age = lifetime
		_finish(Outcome.EXPIRED)


func _finish(terminal: Outcome, world_contact: Vector3 = Vector3.ZERO) -> void:
	if spent:
		return
	spent = true # Resolve once, before damage callbacks can reenter.
	outcome = terminal
	contact_position = world_contact if terminal == Outcome.WORLD or world_contact != Vector3.ZERO else global_position
	set_physics_process(false)
	hide()
	queue_free()
	var applied: float = 0.0
	if terminal == Outcome.WORLD:
		var field := _field.get_ref() as TestField
		if is_instance_valid(field) and field.is_inside_tree() and not field.is_queued_for_deletion():
			CombatFeedback.world_impact(field, contact_position)
	elif terminal == Outcome.TARGET:
		var field := _field.get_ref() as TestField
		var target := target_actor()
		# Captured launch eligibility survives source deletion or later commands;
		# target ownership, membership and current domain are still authoritative.
		if TeamRules.weapon_can_target(field, source_team, target, target_domain, ground_mobile_only):
			applied = TeamRules.damage_target(field, source_team, target, damage, _source.get_ref() as RTSUnit)
		else:
			outcome = Outcome.INVALIDATED
	if not is_instance_valid(self):
		return
	resolved.emit(applied)
