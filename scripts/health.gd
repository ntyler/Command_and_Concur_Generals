class_name UnitHealth
extends Node
## Damage authority; independent of teams, orders and presentation.

signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var maximum: float = 100.0
var current: float = 0.0
var damage_enabled: bool = true


func _ready() -> void:
	if not is_finite(maximum) or maximum <= 0.0:
		maximum = 1.0
	current = maximum


func is_alive() -> bool:
	return current > 0.0


func apply_damage(amount: float, source: Node = null) -> float:
	# Invalid/nonpositive damage is a rejected no-op, never healing.
	if not damage_enabled or not is_alive() or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var applied := minf(amount, current)
	current = maxf(0.0, current - applied)
	var lethal := current == 0.0
	# Health is already dead before any callback. Reentrant damage cannot kill twice.
	damaged.emit(applied, source if is_instance_valid(source) else null)
	if not is_instance_valid(self):
		return applied
	if lethal:
		died.emit(source if is_instance_valid(source) else null)
	return applied
