class_name BaseAssaultField
extends ConstructionField
## One small match, built from the existing construction/economy/combat field.

enum Result { RUNNING, VICTORY, DEFEAT, DRAW }
signal match_finished(result: Result)
const ENEMY_BASE := Rect2(16.5, -15, 7, 6)
@export var headquarters_health: float = 1200.0
@export var barracks_health: float = 450.0
@export var assault_delay: float = 90.0
@export_file("*.tscn") var restart_scene: String = "res://scenes/base_assault.tscn"
@export var tactical_interface_enabled: bool = false
var tactical_minimap: TacticalMinimap
var control_groups: ControlGroups
var enemy_headquarters: RTSBuilding
var result: Result = Result.RUNNING
var elapsed: float = 0.0
var assault_issued: bool = false
var assault_acceptances: int = 0
var _lost_headquarters: Dictionary[int, int] = {}
var _restarting: bool = false
var objective_label: Label
var result_overlay: ColorRect
var result_label: Label
var restart_button: Button

class ResultResolver extends Node:
	var field: BaseAssaultField
	func _ready() -> void:
		process_physics_priority = 1000 # After combat, projectiles and ordinary physics actors.
	func _physics_process(_delta: float) -> void:
		field.resolve_result()


func _build_field() -> void:
	obstacles.append(ENEMY_BASE)
	super._build_field()


func _build_obstacle(index: int, rectangle: Rect2) -> void:
	if rectangle != ENEMY_BASE:
		super._build_obstacle(index, rectangle)
		return
	enemy_headquarters = RTSBuilding.new()
	enemy_headquarters.name = "EnemyHeadquarters"
	enemy_headquarters.owner_id = 2
	enemy_headquarters.kind = RTSBuilding.Kind.HEADQUARTERS
	enemy_headquarters.footprint = rectangle.size
	enemy_headquarters.building_height = 3.2
	enemy_headquarters.position = Vector3(rectangle.get_center().x, 0, rectangle.get_center().y)
	add_child(enemy_headquarters)
	register_building(enemy_headquarters)


func register_building(building: RTSBuilding) -> void:
	super.register_building(building)
	if is_instance_valid(building) and contains_building(building):
		building.enable_damage(headquarters_health if building.kind == RTSBuilding.Kind.HEADQUARTERS else barracks_health)


func _ready() -> void:
	super._ready()
	_build_match_ui()
	var resolver := ResultResolver.new()
	resolver.field = self
	resolver.name = "EndOfPhysicsResult"
	add_child(resolver)
	(info_panel.get_child(0).get_child(0) as Label).text = "FIELDWORK  /  BASE ASSAULT"
	if vehicle_factory_definition != null:
		(info_panel.get_child(0).get_child(0) as Label).text = "FIELDWORK  /  COMBINED ARMS"
		var controls := info_panel.get_child(0).get_child(1) as Label
		controls.text = controls.text.replace("Barracks + right click", "Producer + right click")
	selection.select_building(headquarters)
	_update_objective()
	if tactical_interface_enabled:
		control_groups = ControlGroups.new()
		control_groups.field = self
		add_child(control_groups)
		tactical_minimap = TacticalMinimap.new()
		tactical_minimap.field = self
		tactical_minimap.groups = control_groups
		get_node("ControlsFeedback").add_child(tactical_minimap)


func _physics_process(delta: float) -> void:
	if not gameplay_enabled:
		# Finish only the already committed destruction's topology cleanup.
		construction.navigation.advance(delta)
		return
	super._physics_process(delta)
	if not is_instance_valid(self) or not gameplay_enabled:
		return
	elapsed += delta
	if not assault_issued and elapsed >= maxf(0.0, assault_delay):
		assault_issued = true # Commit before issuing commands/signals; never retry/reset orders.
		for unit in units.duplicate():
			if not is_instance_valid(self) or not gameplay_enabled:
				return
			if contains_unit(unit) and unit.owner_id == 2 and unit.combat.issue_attack(headquarters):
				assault_acceptances += 1
	_update_objective()


func destroy_building(building: RTSBuilding) -> void:
	if not is_instance_valid(building) or not building.destroyed or not _buildings.has(building.get_instance_id()):
		return
	# Record the objective loss before cleanup can synchronously notify listeners.
	if building == headquarters or building == enemy_headquarters:
		_lost_headquarters[building.owner_id] = Engine.get_physics_frames()
	super.destroy_building(building)


func resolve_result() -> void:
	if result != Result.RUNNING or _lost_headquarters.is_empty() or is_queued_for_deletion():
		return
	var own_lost := _lost_headquarters.has(1)
	var enemy_lost := _lost_headquarters.has(2)
	result = Result.DRAW if own_lost and enemy_lost else (Result.DEFEAT if own_lost else Result.VICTORY)
	gameplay_enabled = false
	credits.active = false
	placement.cancel()
	selection.cancel_gesture()
	selection._pending_picks.clear()
	selection.process_mode = Node.PROCESS_MODE_DISABLED
	for unit in units.duplicate():
		if not is_instance_valid(self):
			return
		if contains_unit(unit):
			unit.combat.health.damage_enabled = false
			unit.combat.prepare_order(CombatController.PlayerCommand.STOP)
			unit.halt_motion()
			if is_instance_valid(unit):
				unit.process_mode = Node.PROCESS_MODE_DISABLED
	for entry in _buildings.values():
		var building := (entry as WeakRef).get_ref() as RTSBuilding
		if is_instance_valid(building):
			building.health.damage_enabled = false
			building.process_mode = Node.PROCESS_MODE_DISABLED
	for child in get_children():
		if child is GuidedProjectile:
			child.process_mode = Node.PROCESS_MODE_DISABLED
	production_panel.hide()
	harvest_panel.hide()
	result_label.text = ["", "VICTORY", "DEFEAT", "DRAW"][result]
	result_overlay.show()
	_update_objective()
	match_finished.emit(result) # Final notification; no state writes after callbacks.


func restart_match() -> bool:
	if result == Result.RUNNING or _restarting or not is_inside_tree() or is_queued_for_deletion():
		return false
	_restarting = true
	if is_instance_valid(control_groups):
		control_groups.clear_groups()
	return get_tree().change_scene_to_file(restart_scene) == OK


func _update_objective() -> void:
	if not is_instance_valid(objective_label):
		return
	var phase := "Enemy assault underway" if assault_issued else "Enemy assault in %ds" % ceili(maxf(0, assault_delay - elapsed))
	objective_label.text = "DESTROY THE CORAL HQ · PROTECT YOUR HQ\nBuild barracks → harvest supplies → train Rifles → attack\n" + phase
	if vehicle_factory_definition != null:
		objective_label.text = "DESTROY THE CORAL HQ · PROTECT YOUR HQ\nHarvest → build barracks + factory → train Rifles + Rockets\n" + phase


func _build_match_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MatchHUD"
	layer.layer = 10
	add_child(layer)
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(layout)
	var objective := PanelContainer.new()
	objective.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	objective.offset_left = 20
	objective.offset_right = 650
	objective.offset_top = -102
	objective.offset_bottom = -20
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.085, 0.11, 0.96)
	style.set_content_margin_all(12)
	objective.add_theme_stylebox_override("panel", style)
	layout.add_child(objective)
	objective_label = Label.new()
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.add_theme_color_override("font_color", Color("ffce78"))
	objective.add_child(objective_label)
	result_overlay = ColorRect.new()
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.color = Color(0.025, 0.05, 0.075, 0.88)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layout.add_child(result_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 44)
	result_label.add_theme_color_override("font_color", Color("ffce78"))
	column.add_child(result_label)
	var detail := Label.new()
	detail.text = "The battle is over. Start a fresh base assault."
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.custom_minimum_size = Vector2(320, 56)
	restart_button.pressed.connect(restart_match)
	column.add_child(restart_button)
	result_overlay.hide()
