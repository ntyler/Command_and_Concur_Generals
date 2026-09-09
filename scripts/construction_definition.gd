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
@export var gate_opening: float = 6.0


func is_barrier() -> bool:
	return kind in [RTSBuilding.Kind.WALL, RTSBuilding.Kind.GATE]


func oriented_footprint(orientation: int = 0) -> Vector2:
	return Vector2(footprint.y, footprint.x) if is_barrier() and orientation == 90 else footprint


func is_valid() -> bool:
	var supported := kind in [RTSBuilding.Kind.BARRACKS, RTSBuilding.Kind.VEHICLE_FACTORY, RTSBuilding.Kind.SUPPLY_DEPOT, RTSBuilding.Kind.POWER_PLANT, RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIRFIELD, RTSBuilding.Kind.AIR_DEFENSE_BATTERY, RTSBuilding.Kind.WALL, RTSBuilding.Kind.GATE]
	var defense_valid := kind not in [RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIR_DEFENSE_BATTERY] or (weapon_data != null and weapon_data.is_valid() and weapon_data.mode == WeaponDefinition.Mode.HITSCAN and is_finite(acquisition_interval) and acquisition_interval > 0.0 and is_finite(turret_turn_speed) and turret_turn_speed > 0.0)
	var footprint_valid := footprint == Vector2(6, 5)
	if is_barrier():
		footprint_valid = footprint.is_finite() and footprint.x > 0.0 and footprint.y > 0.0 and power_generated == 0 and power_required == 0 and weapon_data == null
		if kind == RTSBuilding.Kind.GATE:
			footprint_valid = footprint_valid and is_finite(gate_opening) and gate_opening > 2.0 * TestField.CLEARANCE and gate_opening < footprint.x
	return supported and defense_valid and credit_cost > 0 and is_finite(duration) and duration > 0 and footprint_valid and is_finite(height) and height > 1.0 and power_generated >= 0 and power_required >= 0 and is_finite(maximum_health) and maximum_health > 0.0


func display_name() -> String:
	if kind == RTSBuilding.Kind.WALL:
		return "Wall"
	if kind == RTSBuilding.Kind.GATE:
		return "Gate"
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
