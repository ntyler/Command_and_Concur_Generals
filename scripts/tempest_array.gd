class_name TempestArray
extends ConstructionBuilding
## The match's TempestStrikes node advances this charge at physics priority 500.
## Completion/launch frames never contribute pre-completion/pre-reset time.

signal status_changed

var charge: float = 0.0
var authority_generation: int = 0
var _charge_initialized: bool = false
var _charge_started_frame: int = -1
var _last_charge_frame: int = -1


func _init() -> void:
	definition = load("res://construction/tempest_array.tres") as ConstructionDefinition
	# The optional in-progress enum/resource may not yet be installed.
	kind = Kind.get("TEMPEST_ARRAY", -1)
	recipe = null
	if definition != null:
		footprint = definition.footprint
		building_height = definition.height


func display_name() -> String:
	return "Tempest Array site %d" % site.site_id if site != null and not operational else "Tempest Array"


func _ready() -> void:
	availability_changed.connect(_on_availability_changed)
	super._ready()
	# A compact four-pylon array stays inside the normal solid footprint.
	for x in [-1.8, 1.8]:
		for z in [-1.3, 1.3]:
			_mesh(Vector3(0.5, 0.95, 0.5), Vector3(x, building_height + 0.45, z), Color("7db8ce"))
	_mesh(Vector3(2.8, 0.3, 2.0), Vector3(0, building_height + 0.22, 0), Color("a6dfff"))
	_identity_label.position.y = building_height + 1.7
	refresh_construction()


func refresh_construction() -> void:
	super.refresh_construction()
	if not operational:
		charge = 0.0
		_charge_initialized = false
	elif not _charge_initialized:
		# This is also called by the normal paid construction completion commit.
		charge = 0.0
		_charge_initialized = true
		_charge_started_frame = Engine.get_physics_frames()


func _physics_process(_delta: float) -> void:
	# No production queue and no independent clock; the match manager owns time.
	pass


func charge_duration() -> float:
	return definition.charge_duration if definition != null else 180.0


func charge_remaining() -> float:
	return maxf(0.0, charge_duration() - charge)


func is_ready() -> bool:
	return _charge_initialized and charge >= charge_duration()


func base_available() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and operational and is_alive() and is_instance_valid(health) and health.is_alive() and health.damage_enabled and is_instance_valid(gameplay_field) and gameplay_field.gameplay_enabled and not gameplay_field._closing and gameplay_field.contains_building(self) and definition != null and definition.kind == Kind.get("TEMPEST_ARRAY", -1) and definition.is_valid()


func power_available(notify: bool = true) -> bool:
	if not base_available() or not gameplay_field.power_enabled or gameplay_field.power_grid == null:
		return false
	var active_field := gameplay_field
	var grid := active_field.power_grid
	var identity := owner_id
	var generation := authority_generation
	var powered := grid.firing_eligible(identity, notify)
	# A power listener can delete, reparent or change the owner twice.
	return powered and is_instance_valid(self) and base_available() and gameplay_field == active_field and owner_id == identity and authority_generation == generation and active_field.power_grid == grid and grid.active


func status_text() -> String:
	if not operational:
		return "Under construction"
	if not base_available():
		return "Unavailable"
	if not power_available(false):
		return "Ready · no power" if is_ready() else "Charge paused · no power"
	return "Ready to launch" if is_ready() else "Charging · %ds remaining" % ceili(charge_remaining())


func advance_charge(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	var frame := Engine.get_physics_frames()
	if _last_charge_frame == frame or not is_finite(delta) or delta <= 0.0:
		return
	_last_charge_frame = frame
	if not operational:
		refresh_construction()
		return
	if not _charge_initialized:
		refresh_construction()
	if frame <= _charge_started_frame or not base_available() or is_ready():
		return
	var generation := authority_generation
	if not power_available() or not is_instance_valid(self) or authority_generation != generation:
		return
	var old_remaining := ceili(charge_remaining())
	charge = minf(charge_duration(), charge + delta)
	# Floating sums can stop a fraction of a nanosecond below an exact duration.
	if charge_duration() - charge <= 0.0000001:
		charge = charge_duration()
	if ceili(charge_remaining()) != old_remaining:
		status_changed.emit() # State is committed before observers run.


func consume_charge() -> void:
	# Only TempestStrikes calls this after its final silent eligibility check.
	charge = 0.0
	_charge_started_frame = Engine.get_physics_frames()


func _on_availability_changed() -> void:
	authority_generation += 1
	status_changed.emit()


func _on_died(source: Node) -> void:
	charge = 0.0
	authority_generation += 1
	super._on_died(source)
