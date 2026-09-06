class_name TeamRules
extends RefCounted
## owner_id is the existing integer team identity; no parallel ownership property.


static func is_controlled(field: TestField, unit: RTSUnit, local_team: int) -> bool:
	return is_instance_valid(field) and field.contains_unit(unit) and unit.owner_id == local_team


static func is_combat_member(field: TestField, unit: RTSUnit) -> bool:
	return is_instance_valid(field) and field.contains_unit(unit) and is_instance_valid(unit.combat)


static func is_hostile_target(field: TestField, source_team: int, target: RTSUnit) -> bool:
	return is_combat_member(field, target) and source_team != target.owner_id


static func can_attack(field: TestField, source: RTSUnit, target: RTSUnit) -> bool:
	return is_combat_member(field, source) and is_instance_valid(source.combat.weapon) and is_hostile_target(field, source.owner_id, target)


static func damage_target(field: TestField, source_team: int, target: RTSUnit, amount: float, source: RTSUnit = null) -> float:
	if not is_hostile_target(field, source_team, target):
		return 0.0
	return target.combat.health.apply_damage(amount, source if is_instance_valid(source) else null)


static func team_color(team: int) -> Color:
	return Color("42c5cc") if team == 1 else Color("ee7865")
