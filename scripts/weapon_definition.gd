class_name WeaponDefinition
extends Resource

enum Mode { HITSCAN, GUIDED_PROJECTILE }

@export var display_name: String = "Rifle Unit"
@export var mode: Mode = Mode.HITSCAN
@export var damage: float = 12.0
@export var attack_range: float = 8.0
@export var cooldown: float = 0.75
@export var facing_tolerance_degrees: float = 8.0
@export var projectile_speed: float = 9.0
@export var projectile_lifetime: float = 6.0
@export_range(0.01, 1.0, 0.01) var projectile_collision_radius: float = 0.1


func is_valid() -> bool:
	if mode != Mode.HITSCAN and mode != Mode.GUIDED_PROJECTILE:
		return false
	return is_finite(damage) and damage > 0.0 and is_finite(attack_range) and attack_range > 0.0 and is_finite(cooldown) and cooldown > 0.0 and is_finite(facing_tolerance_degrees) and facing_tolerance_degrees >= 0.0 and (mode == Mode.HITSCAN or (is_finite(projectile_speed) and projectile_speed > 0.0 and is_finite(projectile_lifetime) and projectile_lifetime > 0.0 and is_finite(projectile_collision_radius) and projectile_collision_radius > 0.0))
