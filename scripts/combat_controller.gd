class_name CombatController
extends Node
## Per-unit orders coordinate the existing mover, health, weapon and feedback.

enum State { NONE, PURSUING, FACING, ATTACKING, TARGET_INVALIDATED }
enum PlayerCommand { NONE, MOVE, STOP, ATTACK }
signal state_changed(state: State)

@export var retaliation_enabled: bool = false
@export var turn_speed: float = 4.0 # Radians per simulated second.
@export var range_hysteresis: float = 0.75
@export var pursuit_interval: float = 0.5
@export var target_move_threshold: float = 1.0
@export var pursuit_range_fraction: float = 0.85

var unit: RTSUnit
var health: UnitHealth
var weapon: WeaponEmitter
var feedback: CombatFeedback
var state: State = State.NONE
var player_command: PlayerCommand = PlayerCommand.NONE
var order_version: int = 0
var pursuit_elapsed: float = 0.0
var pursuit_recoveries: int = 0
var pursuit_updates: int = 0
var end_reason: String = ""
var _target: WeakRef
var _pursuit_wait: float = 0.0
var _last_target_position: Vector3
var _has_chase: bool = false
var _last_recovery_count: int = 0
var _published_state: State = State.NONE
var _death_handled: bool = false


func _ready() -> void:
	process_physics_priority = -10 # Stop/submit chase before the unit's movement tick.
	health = UnitHealth.new()
	health.maximum = unit.maximum_health
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	weapon = WeaponEmitter.new()
	weapon.unit = unit
	weapon.definition = unit.combat_weapon
	add_child(weapon)
	feedback = CombatFeedback.new()
	feedback.unit = unit
	feedback.health = health
	feedback.display_name = weapon.definition.display_name
	unit.add_child(feedback)
	unit.availability_changed.connect(_on_own_availability_changed)


func target_unit() -> RTSUnit:
	return _target.get_ref() as RTSUnit if _target != null else null


func issue_attack(target: RTSUnit, explicit_player_order: bool = true) -> bool:
	if not TeamRules.can_attack(unit.gameplay_field, unit, target) or not weapon.definition.is_valid():
		return false
	var version := prepare_order(PlayerCommand.ATTACK if explicit_player_order else PlayerCommand.NONE)
	_target = weakref(target)
	target.availability_changed.connect(_on_target_availability_changed)
	state = State.FACING if unit.global_position.distance_to(target.global_position) <= weapon.definition.attack_range else State.PURSUING
	_pursuit_wait = pursuit_interval
	unit.halt_motion()
	if order_version != version:
		return true # Accepted, then synchronously superseded by a legitimate listener.
	publish_state(version)
	return true


func prepare_order(command: PlayerCommand) -> int:
	# Stage a coherent order before movement emits its own synchronous signals.
	order_version += 1
	var old_target := target_unit()
	if is_instance_valid(old_target) and old_target.availability_changed.is_connected(_on_target_availability_changed):
		old_target.availability_changed.disconnect(_on_target_availability_changed)
	_target = null
	player_command = command
	state = State.NONE
	pursuit_elapsed = 0.0
	pursuit_recoveries = 0
	pursuit_updates = 0
	_last_recovery_count = 0
	_pursuit_wait = 0.0
	_last_target_position = Vector3.ZERO
	_has_chase = false
	end_reason = ""
	# A fired weapon's cooldown survives order replacement; rapid commands cannot
	# bypass its fire rate. Already-launched projectiles belong to the field.
	return order_version


func publish_state(version: int) -> void:
	if version == order_version and state != _published_state:
		_published_state = state
		state_changed.emit(state)


func issue_stop() -> bool:
	if not TeamRules.is_combat_member(unit.gameplay_field, unit):
		return false
	var version := prepare_order(PlayerCommand.STOP)
	unit.halt_motion()
	publish_state(version)
	return true


func _end_order(reason: String) -> void:
	var version := prepare_order(PlayerCommand.NONE)
	state = State.TARGET_INVALIDATED
	end_reason = reason
	unit.halt_motion()
	publish_state(version)


func _physics_process(delta: float) -> void:
	if not TeamRules.is_combat_member(unit.gameplay_field, unit):
		return
	weapon.advance(delta)
	if state == State.NONE:
		if player_command == PlayerCommand.MOVE and not unit.moving:
			player_command = PlayerCommand.NONE
		return
	if state == State.TARGET_INVALIDATED:
		state = State.NONE
		publish_state(order_version)
		return
	var target := target_unit()
	if not TeamRules.can_attack(unit.gameplay_field, unit, target):
		_end_order("target_unavailable")
		return
	var version := order_version
	pursuit_recoveries += maxi(0, unit.recovery_attempts - _last_recovery_count)
	_last_recovery_count = unit.recovery_attempts
	var distance := unit.global_position.distance_to(target.global_position)
	var holding := state == State.FACING or state == State.ATTACKING
	if distance <= weapon.definition.attack_range or (holding and distance <= weapon.definition.attack_range + range_hysteresis):
		_has_chase = false
		if unit.moving:
			unit.halt_motion()
			if order_version != version:
				return
		unit.face_toward(target.global_position, turn_speed, delta)
		if distance > weapon.definition.attack_range or unit.facing_error(target.global_position) > deg_to_rad(weapon.definition.facing_tolerance_degrees):
			state = State.FACING
			publish_state(version)
			return
		state = State.ATTACKING
		publish_state(version)
		if order_version == version:
			weapon.try_fire(target)
		return
	state = State.PURSUING
	pursuit_elapsed += delta
	if unit.movement_state == RTSUnit.MovementState.FAILED or pursuit_elapsed >= unit.command_timeout or pursuit_recoveries >= unit.maximum_recoveries:
		_end_order("pursuit_budget_exhausted")
		return
	_pursuit_wait += delta
	if _pursuit_wait >= pursuit_interval:
		_pursuit_wait = 0.0
		if not _has_chase or target.global_position.distance_to(_last_target_position) >= target_move_threshold or not unit.moving:
			_update_pursuit(target, version)
	publish_state(version)


func _update_pursuit(target: RTSUnit, version: int) -> void:
	var map := unit.agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	var away := (unit.global_position - target.global_position).normalized()
	var proposed := target.global_position + away * weapon.definition.attack_range * pursuit_range_fraction
	var destination := NavigationServer3D.map_get_closest_point(map, proposed)
	var path := NavigationServer3D.map_get_path(map, unit.global_position, destination, true)
	if path.is_empty() or path[path.size() - 1].distance_to(destination) > 0.1:
		_end_order("pursuit_unreachable")
		return
	_last_target_position = target.global_position
	var refresh := _has_chase and unit.moving
	_has_chase = true
	pursuit_updates += 1
	if refresh:
		unit.retarget_pursuit(destination)
	else:
		_last_recovery_count = 0
		unit.move_to(destination, true)
	if order_version != version:
		return


func _on_target_availability_changed() -> void:
	if not TeamRules.can_attack(unit.gameplay_field, unit, target_unit()):
		_end_order("target_unavailable")


func _on_own_availability_changed() -> void:
	if _death_handled:
		return
	if not TeamRules.is_combat_member(unit.gameplay_field, unit):
		var version := prepare_order(PlayerCommand.NONE)
		unit.halt_motion()
		publish_state(version)
	elif target_unit() != null:
		_on_target_availability_changed()


func _on_damaged(_amount: float, source: Node) -> void:
	if retaliation_enabled and player_command == PlayerCommand.NONE and target_unit() == null and TeamRules.can_attack(unit.gameplay_field, unit, source as RTSUnit):
		issue_attack(source as RTSUnit, false)


func _on_died(_source: Node) -> void:
	if _death_handled:
		return
	_death_handled = true
	var version := prepare_order(PlayerCommand.NONE)
	unit.halt_motion()
	unit.collision_layer = 0
	unit.crowd_enabled = false
	unit.set_physics_process(false)
	set_physics_process(false)
	if is_instance_valid(unit.gameplay_field):
		unit.gameplay_field.unregister_unit(unit)
	unit.hide()
	unit.queue_free()
	publish_state(version)
