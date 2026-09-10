# Portions adapted from Command & Conquer Generals Zero Hour, Copyright 2025 EA.
# GPL-3.0-or-later; see licenses/EA-GENERALS-GPL-3.0.md and source provenance.
class_name GeneralsAITiming
extends RefCounted
## Port of AISkirmishPlayer::doBaseBuilding/doTeamBuilding scheduling only.
## Queue/base selection callbacks remain explicit engine integration dependencies.

const LOGIC_FPS: int = 30
var ready: bool = false
var timer: int = 0
var delay: int = 0


func step_base(enabled: bool, process_base: Callable) -> void:
	if not enabled:
		return
	if not ready:
		timer -= 1
		if timer <= 0:
			ready = true
			delay = 0
		if timer > 3 * LOGIC_FPS:
			timer = 3 * LOGIC_FPS
	delay -= 1
	if delay < 1:
		if ready:
			process_base.call()
		if delay < 1:
			delay = 2 * LOGIC_FPS


func step_team(enabled: bool, update_queues: Callable, process_team: Callable) -> void:
	if not enabled:
		return
	if not ready:
		timer -= 1
		if timer <= 0:
			ready = true
			delay = 0
		if timer > 3 * LOGIC_FPS:
			timer = 3 * LOGIC_FPS
	delay -= 1
	if delay < 1:
		update_queues.call()
		if ready:
			process_team.call()
		delay = 2 * LOGIC_FPS


static func duration_frames(milliseconds: int) -> int:
	# INI::parseDurationUnsignedInt uses Real(float32) arithmetic before ceilf.
	var factor: float = PackedFloat32Array([0.03])[0]
	var original_real: float = PackedFloat32Array([milliseconds])[0]
	return ceili(PackedFloat32Array([original_real * factor])[0])


static func guard_should_exit(has_target: bool, flags: int, frame: int, give_up_frame: int, target_from_center: Vector3, owner_from_center: Vector3, radius_squared: float, standard_guard_range: float) -> bool:
	# GuardRetaliateExitConditions::shouldExit: original X/Y becomes Godot X/Z.
	if not has_target:
		return (flags & 4) != 0
	if (flags & 2) != 0 and frame >= give_up_frame:
		return true
	if (flags & 1) != 0:
		var target_squared := _horizontal_length_squared(target_from_center)
		var owner_squared := _horizontal_length_squared(owner_from_center)
		# Original fields/return values are Real before multiplication/comparison.
		var original_radius_squared: float = PackedFloat32Array([radius_squared])[0]
		var original_guard_range: float = PackedFloat32Array([standard_guard_range])[0]
		var guard_squared: float = PackedFloat32Array([original_guard_range * original_guard_range])[0]
		if target_squared > original_radius_squared or owner_squared > guard_squared:
			return true
	return false


static func _horizontal_length_squared(delta: Vector3) -> float:
	var x_squared: float = PackedFloat32Array([delta.x * delta.x])[0]
	var z_squared: float = PackedFloat32Array([delta.z * delta.z])[0]
	return PackedFloat32Array([x_squared + z_squared])[0]
