class_name ConstructionDefinition
extends Resource
## Supported fixed-footprint buildings. Accepted sites capture these values.

@export var kind: RTSBuilding.Kind = RTSBuilding.Kind.BARRACKS
@export var credit_cost: int = 400
@export var duration: float = 10.0
@export var footprint := Vector2(6, 5)
@export var height: float = 2.6
@export_range(0, 1000, 1) var power_generated: int = 0
@export_range(0, 1000, 1) var power_required: int = 0
@export var maximum_health: float = 450.0
@export var weapon_data: WeaponDefinition
@export var acquisition_interval: float = 0.25
@export var turret_turn_speed: float = 3.0


func is_valid() -> bool:
	var supported := kind in [RTSBuilding.Kind.BARRACKS, RTSBuilding.Kind.VEHICLE_FACTORY, RTSBuilding.Kind.SUPPLY_DEPOT, RTSBuilding.Kind.POWER_PLANT, RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIRFIELD, RTSBuilding.Kind.AIR_DEFENSE_BATTERY]
	var defense_valid := kind not in [RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIR_DEFENSE_BATTERY] or (weapon_data != null and weapon_data.is_valid() and weapon_data.mode == WeaponDefinition.Mode.HITSCAN and is_finite(acquisition_interval) and acquisition_interval > 0.0 and is_finite(turret_turn_speed) and turret_turn_speed > 0.0)
	return supported and defense_valid and credit_cost > 0 and is_finite(duration) and duration > 0 and footprint == Vector2(6, 5) and is_finite(height) and height > 1.0 and power_generated >= 0 and power_required >= 0 and is_finite(maximum_health) and maximum_health > 0.0


func display_name() -> String:
	if kind == RTSBuilding.Kind.AIRFIELD:
		return "Airfield"
	if kind == RTSBuilding.Kind.AIR_DEFENSE_BATTERY:
		return "Air Defense Battery"
	if kind == RTSBuilding.Kind.GROUND_DEFENSE_BATTERY:
		return "Ground Defense Battery"
	if kind == RTSBuilding.Kind.POWER_PLANT:
		return "Power Plant"
	if kind == RTSBuilding.Kind.SUPPLY_DEPOT:
		return "Supply Depot"
	return "Vehicle Factory" if kind == RTSBuilding.Kind.VEHICLE_FACTORY else "Barracks"
