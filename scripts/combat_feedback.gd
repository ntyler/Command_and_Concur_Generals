class_name CombatFeedback
extends Node3D
## Team, health and hit presentation only. No command or damage authority.

var unit: RTSUnit
var health: UnitHealth
var display_name: String
var health_fill: MeshInstance3D
var health_label: Label3D
var flash_remaining: float = 0.0
var _body_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	for child in unit._visual.get_children(): # Construction only, never a physics search.
		if child is MeshInstance3D:
			_body_materials.append(child.material_override as StandardMaterial3D)
	health_fill = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.8, 0.18)
	health_fill.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("91f4ad")
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_fill.material_override = material
	health_fill.position.y = 1.8
	add_child(health_fill)
	health_label = Label3D.new()
	health_label.font_size = 32
	health_label.outline_size = 4
	health_label.pixel_size = 0.02
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.position.y = 2.7
	add_child(health_label)
	health.damaged.connect(_on_damaged)
	unit.availability_changed.connect(_refresh_team)
	_refresh_team()
	_refresh_health()
	set_physics_process(false)


func _refresh_team() -> void:
	for material in _body_materials:
		material.albedo_color = TeamRules.team_color(unit.owner_id)


func _refresh_health() -> void:
	health_fill.scale.x = maxf(0.001, health.current / health.maximum)
	health_label.text = "%s\n%d / %d" % [display_name, ceili(health.current), ceili(health.maximum)]


func _on_damaged(_amount: float, _source: Node) -> void:
	_refresh_health()
	flash_remaining = 0.12
	for material in _body_materials:
		material.albedo_color = Color.WHITE
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	flash_remaining = maxf(0.0, flash_remaining - delta)
	if flash_remaining == 0.0:
		_refresh_team()
		set_physics_process(false)


func show_tracer(aim: Vector3) -> void:
	var muzzle := unit.global_position + Vector3.UP * 0.9
	var trace := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.045, 0.045, muzzle.distance_to(aim))
	trace.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff0a0")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trace.material_override = material
	unit.gameplay_field.add_child(trace)
	trace.global_position = (muzzle + aim) * 0.5
	if not muzzle.is_equal_approx(aim):
		trace.look_at(aim)
	var tween := trace.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(0.12)
	tween.tween_callback(trace.queue_free)
