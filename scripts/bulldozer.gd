class_name Bulldozer
extends RTSUnit
## Construction owns site state; this ordinary registered unit owns only its order.

@export_range(0.22, 0.5, 0.01) var work_tolerance: float = 0.3
var assigned_site_id: int = 0:
	set(value):
		assigned_site_id = value
		if value == 0:
			_construction_field_ref = null
		elif is_instance_valid(gameplay_field):
			# unregister_unit clears gameplay_field before emitting availability.
			# Keep only a weak reference so departure still releases the original site.
			_construction_field_ref = weakref(gameplay_field)
var work_point := Vector3.ZERO
var _construction_field_ref: WeakRef


func _init() -> void:
	damageable = true
	unit_display_name = "Bulldozer"
	maximum_health = 200.0
	movement_speed = 3.5
	combat_weapon = null
	retaliation_enabled = false


func _ready() -> void:
	super._ready()
	availability_changed.connect(_release_assignment)


func _build_visual() -> void:
	# Keep the recipe's controller-only scene; the model scene is editor-viewable.
	var model := load("res://scenes/bulldozer_model.tscn").instantiate() as Node3D
	_visual.add_child(model)
	for part in model.find_children("HOUSECOLOR*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
		material.albedo_color = TeamRules.team_color(owner_id)
		mesh.material_override = material


func move_to(destination: Vector3, combat_pursuit: bool = false, preserve_attack_move: bool = false) -> bool:
	if not TeamRules.is_combat_member(gameplay_field, self):
		return false
	var previous_order := order_version
	_release_assignment()
	# Releasing a site may synchronously publish a replacement command.
	if not is_instance_valid(self) or order_version != previous_order or assigned_site_id != 0:
		return false
	return super.move_to(destination, combat_pursuit, preserve_attack_move)


func stop() -> bool:
	if not TeamRules.is_combat_member(gameplay_field, self):
		return false
	var previous_order := order_version
	_release_assignment()
	if not is_instance_valid(self) or order_version != previous_order or assigned_site_id != 0:
		return false
	return super.stop()


func construction_move(point: Vector3) -> bool:
	# Called once per committed approach; never reset bounded recovery each frame.
	return super.move_to(point)


func clear_construction(site_id: int, stop_motion: bool = true) -> void:
	if assigned_site_id != site_id:
		return
	assigned_site_id = 0
	work_point = Vector3.ZERO
	if stop_motion and TeamRules.is_combat_member(gameplay_field, self):
		super.stop() # Terminal notification; callbacks may start a new assignment.


func _release_assignment() -> void:
	if assigned_site_id == 0:
		return
	var field := _construction_field_ref.get_ref() as ConstructionField if _construction_field_ref != null else null
	if is_instance_valid(field) and field.construction != null:
		field.construction.release_builder(self)
	else:
		assigned_site_id = 0
		work_point = Vector3.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_assignment()
