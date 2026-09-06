class_name GuidedProjectile
extends Node3D
## A shot owns its launch data and weak references, independently of source orders.

signal resolved(damage_applied: float)

var age: float = 0.0
var speed: float
var lifetime: float
var damage: float
var source_team: int
var spent: bool = false
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
	if age >= lifetime or not TeamRules.is_hostile_target(field, source_team, target):
		_finish(false)
		return
	var aim := target.global_position + Vector3.UP * 0.75
	global_position = global_position.move_toward(aim, speed * delta)
	if global_position.distance_to(aim) <= 0.05:
		_finish(true)


func _finish(impact: bool) -> void:
	if spent:
		return
	spent = true # Resolve once, before damage callbacks can reenter.
	set_physics_process(false)
	hide()
	queue_free()
	var applied: float = 0.0
	if impact:
		applied = TeamRules.damage_target(_field.get_ref() as TestField, source_team, target_unit(), damage, _source.get_ref() as RTSUnit)
	resolved.emit(applied)
