extends "res://tests/unit41_boundary_probe.gd"
## Apply the actual selector/guard seams to every participant, with completion hooks.

func _on_avoidance_velocity(safe_velocity: Vector3) -> void:
	var lifetime: WeakRef = weakref(self)
	var observation := recorder
	super._on_avoidance_velocity(safe_velocity)
	if lifetime.get_ref() != null and is_instance_valid(observation):
		observation.complete_motion(self)


func _move_on_navigation(desired_velocity: Vector3, delta: float) -> void:
	var lifetime: WeakRef = weakref(self)
	var observation := recorder
	super._move_on_navigation(desired_velocity, delta)
	if lifetime.get_ref() != null and is_instance_valid(observation):
		observation.complete_motion(self, true)
