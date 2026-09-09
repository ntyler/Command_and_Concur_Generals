class_name ConstructionDefinition
extends Resource
## Supported fixed-footprint buildings. Accepted sites capture these values.

@export var kind: RTSBuilding.Kind = RTSBuilding.Kind.BARRACKS
@export var credit_cost: int = 400
@export var duration: float = 10.0
@export var footprint := Vector2(6, 5)
@export var height: float = 2.6


func is_valid() -> bool:
	return kind in [RTSBuilding.Kind.BARRACKS, RTSBuilding.Kind.VEHICLE_FACTORY, RTSBuilding.Kind.SUPPLY_DEPOT] and credit_cost > 0 and is_finite(duration) and duration > 0 and footprint == Vector2(6, 5) and is_finite(height) and height > 1.0


func display_name() -> String:
	if kind == RTSBuilding.Kind.SUPPLY_DEPOT:
		return "Supply Depot"
	return "Vehicle Factory" if kind == RTSBuilding.Kind.VEHICLE_FACTORY else "Barracks"
