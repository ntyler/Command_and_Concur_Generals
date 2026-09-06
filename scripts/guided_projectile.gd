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


func _ready() -> void:
	add_to_group("combat_projectiles")
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
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
	age += delta
	var field := _field.get_ref() as TestField
	var target := target_unit()
	if age >= lifetime:
		_finish(Outcome.EXPIRED) # Lifetime has priority at the start of this tick.
		return
	if not TeamRules.is_hostile_target(field, source_team, target):
		_finish(Outcome.INVALIDATED)
		return
	var aim := LineOfFire.aim(target)
	last_segment_start = global_position
	last_segment_end = global_position.move_toward(aim, speed * delta)
	var contact := field.fire_query.segment(get_world_3d(), last_segment_start, last_segment_end)
	if not contact.available:
		return
	if contact.blocked:
		global_position = contact.position
		_finish(Outcome.WORLD)
		return
	global_position = last_segment_end
	# The segment ends at the aim point without overshoot or a proximity shortcut.
	# World contact, including an endpoint numerical tie, is resolved first.
	if global_position == aim:
		_finish(Outcome.TARGET)


func _finish(terminal: Outcome) -> void:
	if spent:
		return
	spent = true # Resolve once, before damage callbacks can reenter.
	outcome = terminal
	contact_position = global_position
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
