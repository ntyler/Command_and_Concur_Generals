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
var collision_radius: float
var spent: bool = false
var outcome: Outcome = Outcome.NONE
var contact_position: Vector3
var last_segment_start: Vector3
var last_segment_end: Vector3
var _target: WeakRef
var _source: WeakRef
var _field: WeakRef


func configure(field: TestField, source: RTSUnit, target: RTSUnit, definition: WeaponDefinition) -> void:
	_field = weakref(field)
	_source = weakref(source)
	_target = weakref(target)
	source_team = source.owner_id
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
	return _target.get_ref() as RTSUnit if _target != null else null


func _physics_process(delta: float) -> void:
	if spent:
		return
	var remaining := lifetime - age
	var field := _field.get_ref() as TestField
	var target := target_unit()
	if remaining <= 0.0:
		_finish(Outcome.EXPIRED)
		return
	if not TeamRules.is_hostile_target(field, source_team, target):
		_finish(Outcome.INVALIDATED)
		return
	var aim := LineOfFire.aim(target)
	var step := minf(delta, remaining)
	if step <= 0.0:
		return
	last_segment_start = global_position
	last_segment_end = global_position.move_toward(aim, speed * step)
	var travel_time := last_segment_start.distance_to(last_segment_end) / speed
	var contact := field.fire_query.sweep_sphere(get_world_3d(), last_segment_start, last_segment_end, collision_radius)
	if not contact.available:
		return
	if contact.blocked:
		age = minf(lifetime, age + travel_time * contact.travel_fraction)
		global_position = contact.center_position
		_finish(Outcome.WORLD, contact.position)
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
	contact_position = world_contact if terminal == Outcome.WORLD else global_position
	set_physics_process(false)
	hide()
	queue_free()
	var applied: float = 0.0
	if terminal == Outcome.WORLD:
		var field := _field.get_ref() as TestField
		if is_instance_valid(field) and field.is_inside_tree() and not field.is_queued_for_deletion():
			CombatFeedback.world_impact(field, contact_position)
	elif terminal == Outcome.TARGET:
		applied = TeamRules.damage_target(_field.get_ref() as TestField, source_team, target_unit(), damage, _source.get_ref() as RTSUnit)
	if not is_instance_valid(self):
		return
	resolved.emit(applied)
