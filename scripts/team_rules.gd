class_name TeamRules
extends RefCounted
## owner_id is the existing integer team identity; no parallel ownership property.

enum TargetDomain { GROUND, AIR }


static func is_controlled(field: TestField, unit: RTSUnit, local_team: int) -> bool:
	return is_instance_valid(field) and field.contains_unit(unit) and unit.owner_id == local_team


static func is_combat_member(field: TestField, unit: RTSUnit) -> bool:
	if not is_instance_valid(field) or not field.is_inside_tree() or field.is_queued_for_deletion() or not field.gameplay_enabled or not field.contains_unit(unit) or unit.gameplay_field != field or not is_instance_valid(unit.combat):
		return false
	var ancestor := unit.get_parent()
	while ancestor != null and ancestor != field:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return ancestor == field


static func is_hostile_target(field: TestField, source_team: int, target: Variant) -> bool:
	if not is_instance_valid(field) or not field.gameplay_enabled or not is_instance_valid(target):
		return false
	if target is RTSUnit:
		return is_combat_member(field, target) and source_team != target.owner_id
	if target is RTSBuilding and field is ProductionField:
		return field.contains_building(target) and target.can_take_damage() and source_team != target.owner_id
	return false


static func is_hostile_ground_unit(field: TestField, source_team: int, target: Variant) -> bool:
	return target is RTSUnit and target_domain(target) == TargetDomain.GROUND and is_hostile_target(field, source_team, target)


static func target_domain(target: Variant) -> TargetDomain:
	# The deployed gameplay body determines its domain, including a safe climb.
	# Existing mobile actors and every building keep the ground default.
	if is_instance_valid(target) and target is RTSUnit and target.has_method("is_airborne_unit") and bool(target.call("is_airborne_unit")):
		return TargetDomain.AIR
	return TargetDomain.GROUND


static func weapon_can_target(field: TestField, source_team: int, target: Variant, domain: int = TargetDomain.GROUND, ground_mobile_only: bool = false) -> bool:
	return is_hostile_target(field, source_team, target) and target_domain(target) == domain and (not ground_mobile_only or target is RTSUnit)


static func can_attack(field: TestField, source: Node3D, target: Variant, notify_power: bool = true) -> bool:
	if source is RTSUnit:
		if not is_combat_member(field, source) or not is_instance_valid(source.combat.weapon):
			return false
		var data: WeaponDefinition = source.combat.weapon.definition
		return data != null and data.is_valid() and weapon_can_target(field, source.owner_id, target, data.target_domain, data.ground_mobile_only)
	if source is GroundDefenseBattery:
		# Reading current power can notify listeners that remove/change either actor.
		return source.source_authorized(notify_power) and is_instance_valid(source) and source.gameplay_field == field and source.target_available(target)
	return false


static func damage_target(field: TestField, source_team: int, target: Variant, amount: float, source: Node3D = null) -> float:
	if not is_hostile_target(field, source_team, target):
		return 0.0
	var health: UnitHealth = target.health if target is RTSBuilding else target.combat.health
	return health.apply_damage(amount, source if is_instance_valid(source) else null)


static func team_color(team: int) -> Color:
	return Color("42c5cc") if team == 1 else Color("ee7865")
