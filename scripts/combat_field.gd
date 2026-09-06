class_name CombatField
extends TestField
## Fixed two-team layout. Hostiles retaliate only after damage; no idle scanning.

const RIFLE: WeaponDefinition = preload("res://weapons/rifle.tres")
const ROCKET: WeaponDefinition = preload("res://weapons/rocket.tres")
const STARTS: Array[Vector3] = [
	Vector3(-18, 0, -4), Vector3(-18, 0, 0), Vector3(-18, 0, 4), Vector3(-18, 0, 8),
	Vector3(-23, 0, 0), Vector3(-23, 0, 6),
	Vector3(17, 0, -6), Vector3(17, 0, -2), Vector3(17, 0, 2), Vector3(17, 0, 6),
	Vector3(22, 0, -4), Vector3(22, 0, 4),
]


func _ready() -> void:
	obstacles = [Rect2(-5, -12, 4, 6), Rect2(4, 5, 5, 6)]
	super._ready()
	_on_selection_changed(0)


func _on_selection_changed(count: int) -> void:
	if not is_instance_valid(status_label):
		return
	var alpha: int = 0
	for unit in units:
		if TeamRules.is_controlled(self, unit, selection.friendly_owner_id):
			alpha += 1
	status_label.text = "%02d selected  /  Team Alpha: %d  /  Team Bravo: %d" % [count, alpha, units.size() - alpha]


func _create_unit(index: int) -> RTSUnit:
	var unit := RTSUnit.new()
	unit.unit_id = index + 1
	unit.name = "CombatUnit%02d" % unit.unit_id
	unit.owner_id = 1 if index < 6 else 2
	unit.position = STARTS[index]
	unit.combat_weapon = RIFLE if index % 6 < 4 else ROCKET
	unit.maximum_health = 100.0 if index % 6 < 4 else 150.0
	unit.retaliation_enabled = index >= 6
	return unit
