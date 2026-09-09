class_name WeaponEmitter
extends Node
## Cooldown and damage/launch authority. Visuals never apply damage.

signal fired(target: Node3D, projectile: GuidedProjectile)

var unit: Node3D # Existing mobile source or the small stationary building adapter.
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
	if not is_instance_valid(unit) or not (unit is RTSUnit or unit is GroundDefenseBattery) or definition == null or not definition.is_valid():
		return false
	var source := unit
	var field: TestField = source.gameplay_field
	var source_owner: int = source.owner_id
	var shot_definition := definition
	var version: int = source.authority_generation if source is GroundDefenseBattery else -1
	if not TeamRules.can_attack(field, source, target) or not is_instance_valid(self):
		return false
	if not _same_source(source, field, source_owner, version):
		return false
	if (source is RTSUnit and source.moving) or cooldown_remaining > 0.000001 or source.global_position.distance_to(target.global_position) > definition.attack_range:
		return false
	if source.facing_error(target.global_position) > deg_to_rad(definition.facing_tolerance_degrees):
		return false
	var query_origin := LineOfFire.muzzle(source)
	var query_aim := LineOfFire.aim(target)
	var query_attachment: Vector3 = source.weapon_attachment() if source is GroundDefenseBattery else source.global_position + Vector3.UP * LineOfFire.BODY_HEIGHT
	var line := field.fire_query.weapon_clearance(source, target, definition)
	if not is_instance_valid(self):
		return false
	last_fire_line = line
	if not line.is_clear():
		return false
	# Queries and current-power reads may be instrumented or notify callbacks.
	# Cached controller eligibility never authorizes damage at this boundary.
	if not _same_source(source, field, source_owner, version) or not TeamRules.can_attack(field, source, target, false) or not is_instance_valid(self):
		return false
	if not _same_source(source, field, source_owner, version) or definition != shot_definition or not is_instance_valid(target) or (source is RTSUnit and source.moving) or cooldown_remaining > 0.000001 or source.global_position.distance_to(target.global_position) > definition.attack_range or source.facing_error(target.global_position) > deg_to_rad(definition.facing_tolerance_degrees):
		return false
	var muzzle := LineOfFire.muzzle(source)
	var aim := LineOfFire.aim(target)
	var attachment: Vector3 = source.weapon_attachment() if source is GroundDefenseBattery else source.global_position + Vector3.UP * LineOfFire.BODY_HEIGHT
	if muzzle != query_origin or aim != query_aim or attachment != query_attachment:
		return false # Geometry changed during a callback; next tick queries afresh.
	# No notifications between the final validated boundary and commitment.
	cooldown_remaining = definition.cooldown
	shots_fired += 1
	var projectile: GuidedProjectile
	if definition.mode == WeaponDefinition.Mode.GUIDED_PROJECTILE:
		# This remains the existing mobile spherical-projectile launch path.
		projectile = GuidedProjectile.new()
		projectile.configure(field, source as RTSUnit, target, definition)
		field.add_child(projectile)
		projectile.global_position = muzzle
	else:
		TeamRules.damage_target(field, source_owner, target, definition.damage, source)
		# Damage callbacks may immediately free the source and this emitter.
		# Cooldown/count and damage already committed; returning that local fact
		# must not require accessing the destroyed instance or its notification.
		if not is_instance_valid(self):
			return true
		if is_instance_valid(field) and field.is_inside_tree() and not field.is_queued_for_deletion():
			CombatFeedback.world_tracer(field, muzzle, aim)
		if not is_instance_valid(self):
			return true
	fired.emit(target if is_instance_valid(target) else null, projectile)
	return true


func _same_source(source: Node3D, field: TestField, owner: int, version: int) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(field) or unit != source or source.gameplay_field != field or source.owner_id != owner:
		return false
	if source is GroundDefenseBattery:
		return source.authority_generation == version and source.weapon == self
	return source is RTSUnit and is_instance_valid(source.combat) and source.combat.weapon == self
