class_name WeaponEmitter
extends Node
## Cooldown and damage/launch authority. Visuals never apply damage.

signal fired(target: Node3D, projectile: GuidedProjectile)

var unit: RTSUnit
var definition: WeaponDefinition
var cooldown_remaining: float = 0.0
var shots_fired: int = 0
var last_fire_line: LineOfFire.Trace


func advance(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


func try_fire(target: Variant) -> bool:
	last_fire_line = null
	if not Engine.is_in_physics_frame():
		return false # Direct firing is supported only during a physics step.
	if not definition.is_valid() or not TeamRules.can_attack(unit.gameplay_field, unit, target):
		return false
	if unit.moving or cooldown_remaining > 0.000001 or unit.global_position.distance_to(target.global_position) > definition.attack_range:
		return false
	if unit.facing_error(target.global_position) > deg_to_rad(definition.facing_tolerance_degrees):
		return false
	last_fire_line = unit.gameplay_field.fire_query.weapon_clearance(unit, target, definition)
	if not last_fire_line.is_clear():
		return false
	# No notification between this authoritative geometry check and commitment.
	var muzzle := LineOfFire.muzzle(unit)
	var aim := LineOfFire.aim(target)
	cooldown_remaining = definition.cooldown
	shots_fired += 1
	var projectile: GuidedProjectile
	if definition.mode == WeaponDefinition.Mode.GUIDED_PROJECTILE:
		projectile = GuidedProjectile.new()
		projectile.configure(unit.gameplay_field, unit, target, definition)
		unit.gameplay_field.add_child(projectile)
		projectile.global_position = muzzle
	else:
		unit.combat.feedback.show_tracer(muzzle, aim)
		TeamRules.damage_target(unit.gameplay_field, unit.owner_id, target, definition.damage, unit)
		# Damage callbacks may immediately free the source and this emitter.
		# Cooldown/count and damage already committed; returning that local fact
		# must not require accessing the destroyed instance or its notification.
		if not is_instance_valid(self):
			return true
	fired.emit(target if is_instance_valid(target) else null, projectile)
	return true
