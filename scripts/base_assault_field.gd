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
@export var attack_move_enabled: bool = false
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
var home_button: Button
var help_panel: RTSHelpPanel
var pause_menu: RTSPauseMenu

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
	get_window().title = "Fieldwork — Match"
	# A test/host may itself process while paused; the match always pauses.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	super._ready()
	selection.attack_move_enabled = attack_move_enabled
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
		_compact_help()
	# Last child owns unhandled Escape, after ordinary GUI has had first refusal.
	pause_menu = RTSPauseMenu.new()
	pause_menu.field = self
	add_child(pause_menu)


func _compact_help() -> void:
	# Keep the existing command feedback label and all its acceptance semantics.
	status_label.reparent(objective_label.get_parent())
	status_label.add_theme_font_size_override("font_size", 13)
	var old_guide := info_panel
	old_guide.get_parent().remove_child(old_guide)
	old_guide.queue_free()
	# The layer has no full-screen Control and cannot catch battlefield clicks.
	var layer := CanvasLayer.new()
	layer.name = "HelpHUD"
	layer.layer = 1
	add_child(layer)
	help_panel = RTSHelpPanel.new()
	help_panel.field = self
	layer.add_child(help_panel)
	info_panel = help_panel
	help_panel.resized.connect(_layout_placement_status)
	production_panel.resized.connect(_layout_placement_status)
	get_viewport().size_changed.connect(_layout_placement_status)
	_layout_placement_status.call_deferred()


func _layout_placement_status() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(help_panel) or not help_panel.is_inside_tree() or not is_instance_valid(production_panel) or not production_panel.is_inside_tree() or not is_instance_valid(placement) or not is_instance_valid(placement.status):
		return
	var left := help_panel.get_global_rect().end.x + 20.0
	var right := production_panel.get_global_rect().position.x - 20.0
	var width := minf(460.0, maxf(100.0, right - left))
	placement.status.position = Vector2(left + (right - left - width) * 0.5, 20)
	placement.status.size = Vector2(width, 70)


func _exit_tree() -> void:
	# Leaving a paused match must never leave its replacement globally frozen.
	if manual_pause_active:
		manual_pause_active = false
		get_tree().paused = false
	if get_viewport().size_changed.is_connected(_layout_placement_status):
		get_viewport().size_changed.disconnect(_layout_placement_status)
	if is_instance_valid(help_panel) and help_panel.resized.is_connected(_layout_placement_status):
		help_panel.resized.disconnect(_layout_placement_status)
	if is_instance_valid(production_panel) and production_panel.resized.is_connected(_layout_placement_status):
		production_panel.resized.disconnect(_layout_placement_status)
	super._exit_tree()


func _physics_process(delta: float) -> void:
	if manual_pause_active:
		return # Manual callbacks must not advance even topology while paused.
	if not gameplay_enabled:
		# Finish only the already committed destruction's topology cleanup.
		construction.navigation.advance(delta)
		return
	super._physics_process(delta)
	if not is_instance_valid(self) or not gameplay_enabled:
		return
	elapsed += delta
	if uses_scripted_assault() and not assault_issued and elapsed >= maxf(0.0, assault_delay):
		assault_issued = true # Commit before issuing commands/signals; never retry/reset orders.
		for unit in units.duplicate():
			if not is_instance_valid(self) or not gameplay_enabled:
				return
			if contains_unit(unit) and unit.owner_id == 2 and unit.combat.issue_attack(headquarters):
				assault_acceptances += 1
	_update_objective()


func uses_scripted_assault() -> bool:
	return true


func destroy_building(building: RTSBuilding) -> void:
	if not is_instance_valid(building) or not building.destroyed or not _buildings.has(building.get_instance_id()):
		return
	# Record the objective loss before cleanup can synchronously notify listeners.
	if building == headquarters or building == enemy_headquarters:
		_lost_headquarters[building.owner_id] = Engine.get_physics_frames()
	super.destroy_building(building)


func resolve_result() -> void:
	if manual_pause_active or result != Result.RUNNING or _lost_headquarters.is_empty() or is_queued_for_deletion():
		return
	var own_lost := _lost_headquarters.has(1)
	var enemy_lost := _lost_headquarters.has(2)
	result = Result.DRAW if own_lost and enemy_lost else (Result.DEFEAT if own_lost else Result.VICTORY)
	gameplay_enabled = false
	credits.active = false
	construction.pause_all()
	_clear_uncommitted_input()
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
	if is_instance_valid(help_panel):
		help_panel.set_open(false)
		help_panel.hide()
	if is_instance_valid(pause_menu):
		pause_menu.close()
	result_label.text = ["", "VICTORY", "DEFEAT", "DRAW"][result]
	result_overlay.show()
	_update_objective()
	match_finished.emit(result) # Final notification; no state writes after callbacks.


func pause_match() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or _restarting or manual_pause_active or not gameplay_enabled or result != Result.RUNNING:
		return false
	# Block signal/deferred commands before cancelling only uncommitted input.
	manual_pause_active = true
	get_tree().paused = true
	_clear_uncommitted_input()
	if is_instance_valid(help_panel):
		help_panel.set_open(false)
	pause_menu.open()
	return true


func resume_match() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or _restarting or not manual_pause_active or result != Result.RUNNING:
		return false
	_clear_uncommitted_input()
	pause_menu.close()
	manual_pause_active = false
	get_tree().paused = false
	return true


func _clear_uncommitted_input() -> void:
	placement.cancel()
	selection.cancel_gesture()
	selection.cancel_attack_move_targeting()
	selection._pending_picks.clear()
	if is_instance_valid(selection.tempest_targeting):
		selection.tempest_targeting.cancel()
	if is_instance_valid(control_groups):
		control_groups.reset_input_timing()
	if is_instance_valid(tactical_minimap):
		tactical_minimap.cancel_pending_input()
	if is_instance_valid(camera_rig):
		camera_rig.cancel_pending_input()


func restart_match() -> bool:
	if (result == Result.RUNNING and not manual_pause_active) or _restarting or not is_inside_tree() or is_queued_for_deletion():
		return false
	return _leave_match(restart_scene)


func return_to_home() -> bool:
	if (result == Result.RUNNING and not manual_pause_active) or _restarting or not is_inside_tree() or is_queued_for_deletion():
		return false
	return _leave_match("res://scenes/home_screen.tscn")


func _leave_match(destination: String) -> bool:
	_restarting = true
	_clear_uncommitted_input()
	if is_instance_valid(control_groups):
		control_groups.clear_groups()
	var tree := get_tree()
	var error := tree.change_scene_to_file(destination)
	if error != OK:
		_restarting = false
		return false
	# change_scene removes the old scene immediately; its _exit_tree also clears
	# the pause. New scene instantiation happens at frame end, with fresh input.
	tree.paused = false
	return true


func _update_objective() -> void:
	if not is_instance_valid(objective_label):
		return
	var phase := "Enemy assault underway" if assault_issued else "Enemy assault in %ds" % ceili(maxf(0, assault_delay - elapsed))
	objective_label.text = "Destroy enemy HQ · Protect your HQ\n" + phase


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
	objective.offset_right = 540
	objective.offset_top = -102 if tactical_interface_enabled else -78
	objective.offset_bottom = -20
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.085, 0.11, 0.96)
	style.set_content_margin_all(12)
	objective.add_theme_stylebox_override("panel", style)
	layout.add_child(objective)
	var objective_column := VBoxContainer.new()
	objective_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective.add_child(objective_column)
	objective_label = Label.new()
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.add_theme_color_override("font_color", Color("ffce78"))
	objective_column.add_child(objective_label)
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
	home_button = Button.new()
	home_button.text = "Return to Home"
	home_button.custom_minimum_size = Vector2(320, 52)
	home_button.pressed.connect(return_to_home)
	column.add_child(home_button)
	result_overlay.hide()
