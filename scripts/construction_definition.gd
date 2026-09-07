class_name ConstructionDefinition
extends Resource
## Barracks-only prototype data. Accepted sites capture these values.

@export var credit_cost: int = 400
@export var duration: float = 10.0
@export var footprint := Vector2(6, 5)
@export var height: float = 2.6


func is_valid() -> bool:
	return credit_cost > 0 and is_finite(duration) and duration > 0 and footprint == Vector2(6, 5) and is_finite(height) and height > 1.0
