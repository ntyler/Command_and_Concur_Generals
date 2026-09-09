class_name ConstructionPanel
extends ProductionPanel

var build_button: Button
var factory_button: Button
var depot_button: Button
var power_plant_button: Button
var defense_button: Button
var airfield_button: Button
var air_defense_button: Button
var wall_button: Button
var gate_button: Button
var orientation_button: Button
var gate_action_button: Button
var gate_state_label: Label
var _pending_gate: WeakRef
var _pending_gate_open: bool = false
var _pending_gate_owner: int = 0
var site_status: Label
var site_progress: ProgressBar
var cancel_site_button: Button
var _displayed_site: ConstructionSite


func _ready() -> void:
	super._ready()
	var column := get_child(0) as VBoxContainer
	build_button = Button.new()
	build_button.focus_mode = Control.FOCUS_NONE
	build_button.add_theme_font_size_override("font_size", 14)
	column.add_child(build_button)
	build_button.pressed.connect(_begin)
	factory_button = Button.new()
	factory_button.focus_mode = Control.FOCUS_NONE
	factory_button.add_theme_font_size_override("font_size", 14)
	column.add_child(factory_button)
	factory_button.pressed.connect(_begin_factory)
	depot_button = Button.new()
	depot_button.focus_mode = Control.FOCUS_NONE
	depot_button.add_theme_font_size_override("font_size", 14)
	column.add_child(depot_button)
	depot_button.pressed.connect(_begin_depot)
	power_plant_button = Button.new()
	power_plant_button.focus_mode = Control.FOCUS_NONE
	power_plant_button.add_theme_font_size_override("font_size", 14)
	column.add_child(power_plant_button)
	power_plant_button.pressed.connect(_begin_power_plant)
	defense_button = Button.new()
	defense_button.focus_mode = Control.FOCUS_NONE
	defense_button.add_theme_font_size_override("font_size", 14)
	column.add_child(defense_button)
	defense_button.pressed.connect(_begin_defense)
	airfield_button = Button.new()
	airfield_button.focus_mode = Control.FOCUS_NONE
	airfield_button.add_theme_font_size_override("font_size", 14)
	column.add_child(airfield_button)
	airfield_button.pressed.connect(_begin_airfield)
	air_defense_button = Button.new()
	air_defense_button.focus_mode = Control.FOCUS_NONE
	air_defense_button.add_theme_font_size_override("font_size", 14)
	column.add_child(air_defense_button)
	air_defense_button.pressed.connect(_begin_air_defense)
	wall_button = Button.new()
	gate_button = Button.new()
	for button in [wall_button, gate_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 14)
		column.add_child(button)
	wall_button.pressed.connect(_begin_barrier.bind(false))
	gate_button.pressed.connect(_begin_barrier.bind(true))
	if (field as ConstructionField).airfield_definition != null:
		var choices := GridContainer.new()
		choices.columns = 2
		choices.add_theme_constant_override("h_separation", 6)
		column.add_child(choices)
		for button in [build_button, factory_button, depot_button, power_plant_button, defense_button, airfield_button, air_defense_button, wall_button, gate_button]:
			button.reparent(choices)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orientation_button = Button.new()
	orientation_button.focus_mode = Control.FOCUS_NONE
	orientation_button.add_theme_font_size_override("font_size", 14)
	column.add_child(orientation_button)
	orientation_button.pressed.connect(_rotate_barrier)
	gate_state_label = _label(column, "")
	gate_state_label.add_theme_font_size_override("font_size", 14)
	gate_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gate_action_button = Button.new()
	gate_action_button.focus_mode = Control.FOCUS_NONE
	gate_action_button.add_theme_font_size_override("font_size", 14)
	column.add_child(gate_action_button)
	gate_action_button.pressed.connect(_gate_action)
	site_status = _label(column, "")
	site_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	site_status.add_theme_font_size_override("font_size", 14)
	site_progress = ProgressBar.new()
	site_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(site_progress)
	cancel_site_button = Button.new()
	cancel_site_button.text = "Cancel construction · full refund"
	cancel_site_button.focus_mode = Control.FOCUS_NONE
	cancel_site_button.add_theme_font_size_override("font_size", 14)
	column.add_child(cancel_site_button)
	cancel_site_button.pressed.connect(_cancel_site)
	(field as ConstructionField).construction.changed.connect(_construction_changed)
	_refresh()


func _refresh() -> void:
	if not _context_active():
		return
	super._refresh()
	if not _context_active():
		return
	refresh_construction()


func refresh_construction() -> void:
	if not _context_active() or not is_instance_valid(build_button):
		return
	var world := field as ConstructionField
	var building := field.selection.selected_building()
	var builder := field.selection.selected_builder() if world.builder_construction_enabled else null
	if not _context_active():
		return
	var source: Node3D = builder if world.builder_construction_enabled else building
	build_button.visible = builder != null if world.builder_construction_enabled else building != null and building.kind == RTSBuilding.Kind.HEADQUARTERS
	build_button.text = "Build Barracks · %d cr · %s s" % [world.construction_definition.credit_cost, str(world.construction_definition.duration)]
	var factory := world.vehicle_factory_definition
	factory_button.visible = build_button.visible and factory != null
	if factory != null:
		factory_button.text = "Build Vehicle Factory · %d cr · %s s" % [factory.credit_cost, str(factory.duration)]
		factory_button.disabled = not world.construction.can_begin(field.selection.friendly_owner_id, source, factory).is_empty()
	var depot := world.supply_depot_definition
	depot_button.visible = build_button.visible and depot != null
	if depot != null:
		depot_button.text = "Build Supply Depot · %d cr · %s s" % [depot.credit_cost, str(depot.duration)]
		depot_button.disabled = not world.construction.can_begin(field.selection.friendly_owner_id, source, depot).is_empty()
	var plant := world.power_plant_definition
	power_plant_button.visible = world.power_enabled and world.builder_construction_enabled and build_button.visible and plant != null
	if plant != null:
		power_plant_button.text = "Build Power Plant · %d cr · %s s" % [plant.credit_cost, str(plant.duration)]
		power_plant_button.disabled = not world.construction.can_begin(field.selection.friendly_owner_id, source, plant).is_empty()
	var defense := world.defense_definition
	defense_button.visible = world.power_enabled and world.builder_construction_enabled and build_button.visible and defense != null
	if defense != null:
		defense_button.text = "Build Ground Defense · %d cr · %s s" % [defense.credit_cost, str(defense.duration)]
		defense_button.tooltip_text = "Ground Defense Battery · %d power · attacks hostile ground units" % defense.power_required
		defense_button.disabled = not world.construction.can_begin(field.selection.friendly_owner_id, source, defense).is_empty()
	var airfield := world.airfield_definition
	airfield_button.visible = build_button.visible and airfield != null
	if airfield != null:
		airfield_button.text = "Build Airfield · %d cr · %s s" % [airfield.credit_cost, str(airfield.duration)]
		airfield_button.tooltip_text = "Airfield · 3 power · produces Attack Helicopters only"
		airfield_button.disabled = not world.construction.can_begin(field.selection.friendly_owner_id, source, airfield).is_empty()
	var air_defense := world.air_defense_definition
	air_defense_button.visible = build_button.visible and air_defense != null
	if air_defense != null:
		air_defense_button.text = "Build Air Defense · %d cr · %s s" % [air_defense.credit_cost, str(air_defense.duration)]
		air_defense_button.tooltip_text = "Air Defense Battery · 3 power · attacks hostile aircraft only"
		air_defense_button.disabled = not world.construction.can_begin(field.selection.friendly_owner_id, source, air_defense).is_empty()
	if airfield != null:
		for button in [build_button, factory_button, depot_button, power_plant_button, defense_button, airfield_button, air_defense_button]:
			button.text = button.text.replace("Build ", "").replace(" cr", "").replace(" s", "s")
	for item in [[wall_button, world.wall_definition], [gate_button, world.gate_definition]]:
		var button: Button = item[0]
		var choice: ConstructionDefinition = item[1]
		button.visible = build_button.visible and world.builder_construction_enabled and choice != null
		if choice != null:
			button.text = "%s · %d · %ss" % [choice.display_name(), choice.credit_cost, str(choice.duration)]
			button.tooltip_text = "%s · %d HP · no power · one site at a time" % [choice.display_name(), choice.maximum_health]
			button.disabled = not world.construction.can_begin(field.selection.friendly_owner_id, source, choice).is_empty()
	_refresh_barrier_controls()
	if build_button.visible:
		var reason := world.construction.can_begin(field.selection.friendly_owner_id, source, world.construction_definition)
		build_button.disabled = not reason.is_empty()
		var any_available := not build_button.disabled or (factory_button.visible and not factory_button.disabled) or (depot_button.visible and not depot_button.disabled) or (power_plant_button.visible and not power_plant_button.disabled) or (defense_button.visible and not defense_button.disabled) or (airfield_button.visible and not airfield_button.disabled) or (air_defense_button.visible and not air_defense_button.disabled) or (wall_button.visible and not wall_button.disabled) or (gate_button.visible and not gate_button.disabled)
		var hint := "Choose a building, then place it." if any_available else reason
		if builder != null:
			feedback.text = "Right-click ground · Move    X · Stop\n" + hint + "\nRight-click owned unfinished site · Resume"
			if world.power_enabled:
				feedback.text = "Right-click ground · Move    X · Stop\nRight-click owned unfinished site · Resume" if any_available else reason
		else:
			feedback.text = hint
	elif world.builder_construction_enabled and field.selection.has_selected_builder():
		feedback.text = ("" if field.selection.attack_move_targeting else _commands(field.selection.selected_units()) + "\n") + "Select exactly one owned Bulldozer to place or resume construction."
	feedback.visible = not feedback.text.is_empty()
	var site: ConstructionSite = (building as ConstructionBuilding).site if building is ConstructionBuilding else null
	if builder != null and builder.assigned_site_id != 0:
		site = world.construction.sites.get(builder.assigned_site_id) as ConstructionSite
		# Ordinary movement becomes idle at arrival; construction has its own
		# current activity below, so do not label a working builder "Idle".
		selection_details.text = _health_text(builder.combat.health)
	_displayed_site = site
	var unfinished := site != null and site.state != ConstructionSite.State.OPERATIONAL
	site_status.visible = unfinished or (builder != null and not world.power_enabled)
	site_progress.visible = unfinished
	# Cancelling the selected site refunds it. Builder X Stop instead pauses it;
	# keeping that distinction in the contextual UI avoids accidental refunds.
	cancel_site_button.visible = unfinished and building is ConstructionBuilding
	if unfinished:
		train_button.hide()
		progress_bar.hide()
		rows.hide()
		if builder == null:
			feedback.text = "Paid %d credits · refundable until completion" % site.paid
		site_status.text = site.reason
		site_progress.value = site.progress() * 100.0
		cancel_site_button.disabled = not site.cancellable()
	else:
		rows.show()
		if builder != null:
			site_status.text = "No construction assignment"
	_layout.call_deferred()


func _process(delta: float) -> void:
	super._process(delta)
	if _context_active() and is_instance_valid(orientation_button):
		_refresh_barrier_controls()
	if is_instance_valid(site_progress) and site_progress.visible:
		if _displayed_site != null:
			site_progress.value = _displayed_site.progress() * 100.0


func _refresh_barrier_controls() -> void:
	var world := field as ConstructionField
	var placing := is_instance_valid(world.placement) and world.placement.active and world.placement.definition != null and world.placement.definition.is_barrier()
	orientation_button.visible = placing
	if placing:
		orientation_button.text = "Orientation %d° · Rotate R" % world.placement.orientation_degrees
	var gate := field.selection.selected_building() as BarrierBuilding
	var operable := gate != null and gate.kind == RTSBuilding.Kind.GATE and gate.operational
	gate_state_label.visible = operable
	gate_action_button.visible = operable
	if operable:
		gate_state_label.text = gate.gate_status()
		gate_action_button.text = "Close Gate" if gate.physical_open else "Open Gate"
		gate_action_button.disabled = not field.gameplay_enabled or gate.navigation_pending or not gate.effective_ready or world.construction.navigation.blocked


func _begin_barrier(gate: bool) -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var world := field as ConstructionField
	var choice := world.gate_definition if gate else world.wall_definition
	if choice != null and is_instance_valid(world.placement):
		world.placement.begin(_placement_source(), choice)


func _rotate_barrier() -> void:
	if _context_active():
		(field as ConstructionField).placement.rotate_orientation()


func _gate_action() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var gate := field.selection.selected_building() as BarrierBuilding
	if gate == null:
		return
	_pending_gate = weakref(gate)
	_pending_gate_open = not gate.physical_open
	_pending_gate_owner = field.selection.friendly_owner_id


func _physics_process(_delta: float) -> void:
	var request := _pending_gate
	_pending_gate = null
	if request == null or not _context_active():
		return
	var gate := request.get_ref() as BarrierBuilding
	if is_instance_valid(gate):
		gate.request_gate(_pending_gate_owner, _pending_gate_open)


func _construction_changed(_site_id: int) -> void:
	_refresh()


func _begin() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var world := field as ConstructionField
	if is_instance_valid(world.placement):
		world.placement.begin(_placement_source())


func _begin_factory() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var world := field as ConstructionField
	if world.vehicle_factory_definition != null and is_instance_valid(world.placement):
		world.placement.begin(_placement_source(), world.vehicle_factory_definition)


func _begin_depot() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var world := field as ConstructionField
	if world.supply_depot_definition != null and is_instance_valid(world.placement):
		world.placement.begin(_placement_source(), world.supply_depot_definition)


func _begin_power_plant() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var world := field as ConstructionField
	if world.power_enabled and world.builder_construction_enabled and world.power_plant_definition != null and is_instance_valid(world.placement):
		world.placement.begin(_placement_source(), world.power_plant_definition)


func _placement_source() -> Node3D:
	return field.selection.selected_builder() if (field as ConstructionField).builder_construction_enabled else field.selection.selected_building()


func _begin_defense() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var world := field as ConstructionField
	if world.power_enabled and world.builder_construction_enabled and world.defense_definition != null and is_instance_valid(world.placement):
		world.placement.begin(_placement_source(), world.defense_definition)


func _begin_airfield() -> void:
	if _context_active() and field.gameplay_enabled:
		var world := field as ConstructionField
		if world.airfield_definition != null and is_instance_valid(world.placement):
			world.placement.begin(_placement_source(), world.airfield_definition)


func _begin_air_defense() -> void:
	if _context_active() and field.gameplay_enabled:
		var world := field as ConstructionField
		if world.air_defense_definition != null and is_instance_valid(world.placement):
			world.placement.begin(_placement_source(), world.air_defense_definition)


func _cancel_site() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var building := field.selection.selected_building() as ConstructionBuilding
	if building != null and building.site != null:
		(field as ConstructionField).construction.cancel(field.selection.friendly_owner_id, building.site.site_id)


func _exit_tree() -> void:
	_pending_gate = null
	_displayed_site = null
	if is_instance_valid(field) and (field as ConstructionField).construction.changed.is_connected(_construction_changed):
		(field as ConstructionField).construction.changed.disconnect(_construction_changed)
	super._exit_tree()
