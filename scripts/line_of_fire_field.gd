class_name LineOfFireField
extends TestField
## Fixed geometry lab; T is a manual fixture control, not autonomous target AI.

const RIFLE: WeaponDefinition = preload("res://weapons/rifle.tres")
const ROCKET: WeaponDefinition = preload("res://weapons/rocket.tres")
const STARTS: Array[Vector3] = [
	Vector3(-22, 0, -5), Vector3(-8, 0, -12), Vector3(8, 0, -12), Vector3(-22, 0, 10),
	Vector3(-8, 0, 8), Vector3(14, 0, 8),
	Vector3(-16, 0, -5), Vector3(-2, 0, -12), Vector3(14, 0, -12), Vector3(-16, 0, 10),
	Vector3(0, 0, 8), Vector3(22, 0, 8),
]
const WALLS: Array[Rect2] = [
	Rect2(-5.15, -14, 0.3, 4), # Blocked rifle; target can move south into clearance.
	Rect2(10.85, -18, 0.3, 4), Rect2(10.85, -10, 0.3, 3), # Opening.
	Rect2(-14.15, 8, 0.3, 4), # Behind the southern rifle target.
	Rect2(-4.15, 8.3, 0.3, 6), # Rocket target can enter this wall's shadow.
	Rect2(18.0, 10, 0.02, 4), # Thin wall: narrower than a fast projectile step.
]
var _shadow_far: bool = false


func _ready() -> void:
	obstacles = WALLS.duplicate()
	super._ready()
	_on_selection_changed(0)
	var labels := ["RIFLE · CLEAR", "RIFLE · BLOCKED", "OPENING", "WALL BEHIND TARGET", "ROCKET · LAUNCH THEN T", "ROCKET · THIN WALL"]
	for i in labels.size():
		var label := Label3D.new()
		label.text = labels[i]
		label.font_size = 26
		label.pixel_size = 0.025
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = (STARTS[i] + STARTS[i + 6]) * 0.5 + Vector3(0, 0.1, 3.2)
		add_child(label)
	var hint := Label.new()
	hint.text = "FIRE LAB · T: move marked rocket target into/out of wall shadow"
	hint.position = Vector2(20, 750)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$ControlsFeedback.add_child(hint)


func _on_selection_changed(count: int) -> void:
	if not is_instance_valid(status_label):
		return
	var alpha := 0
	for unit in units: # Membership/selection notification, never a per-frame scan.
		if TeamRules.is_controlled(self, unit, selection.friendly_owner_id):
			alpha += 1
	status_label.text = "%02d selected  /  Alpha: %d  /  Bravo: %d" % [count, alpha, units.size() - alpha]


func _create_unit(index: int) -> RTSUnit:
	var unit := RTSUnit.new()
	unit.unit_id = index + 1
	unit.name = "FireUnit%02d" % unit.unit_id
	unit.owner_id = 1 if index < 6 else 2
	unit.position = STARTS[index]
	unit.combat_weapon = RIFLE if index % 6 < 4 else ROCKET
	unit.maximum_health = 100.0 if index % 6 < 4 else 150.0
	return unit


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.physical_keycode == KEY_T and event.pressed and not event.echo:
		for unit in units: # One manual fixture command, never a per-frame scan.
			if unit.unit_id == 11 and contains_unit(unit):
				_shadow_far = not _shadow_far
				unit.move_to(Vector3(0, 0, 14 if _shadow_far else 8))
				break
		get_viewport().set_input_as_handled()
