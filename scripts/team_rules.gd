class_name TeamRules
extends RefCounted
## owner_id is the existing integer team identity; no parallel ownership property.


static func is_controlled(field: TestField, unit: RTSUnit, local_team: int) -> bool:
	return is_instance_valid(field) and field.contains_unit(unit) and unit.owner_id == local_team


static func is_combat_member(field: TestField, unit: RTSUnit) -> bool:
	return is_instance_valid(field) and field.gameplay_enabled and field.contains_unit(unit) and is_instance_valid(unit.combat)


static func is_hostile_target(field: TestField, source_team: int, target: Variant) -> bool:
	if not is_instance_valid(field) or not field.gameplay_enabled or not is_instance_valid(target):
		return false
	if target is RTSUnit:
		return is_combat_member(field, target) and source_team != target.owner_id
	if target is RTSBuilding and field is ProductionField:
		return field.contains_building(target) and target.can_take_damage() and source_team != target.owner_id
	return false


static func can_attack(field: TestField, source: RTSUnit, target: Variant) -> bool:
	return is_combat_member(field, source) and is_instance_valid(source.combat.weapon) and is_hostile_target(field, source.owner_id, target)


static func damage_target(field: TestField, source_team: int, target: Variant, amount: float, source: RTSUnit = null) -> float:
	if not is_hostile_target(field, source_team, target):
		return 0.0
	var health: UnitHealth = target.health if target is RTSBuilding else target.combat.health
	return health.apply_damage(amount, source if is_instance_valid(source) else null)


static func team_color(team: int) -> Color:
	return Color("42c5cc") if team == 1 else Color("ee7865")
