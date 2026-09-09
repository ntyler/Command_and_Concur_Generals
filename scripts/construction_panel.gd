class_name ConstructionPanel
extends ProductionPanel

var build_button: Button
var factory_button: Button
var depot_button: Button
var site_status: Label
var site_progress: ProgressBar
var cancel_site_button: Button


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
	refresh_construction()


func refresh_construction() -> void:
	if not _context_active() or not is_instance_valid(build_button):
		return
	var world := field as ConstructionField
	var building := field.selection.selected_building()
	build_button.visible = building != null and building.kind == RTSBuilding.Kind.HEADQUARTERS
	build_button.text = "Build Barracks · %d cr · %s s" % [world.construction_definition.credit_cost, str(world.construction_definition.duration)]
	var factory := world.vehicle_factory_definition
	factory_button.visible = build_button.visible and factory != null
	if factory != null:
		factory_button.text = "Build Vehicle Factory · %d cr · %s s" % [factory.credit_cost, str(factory.duration)]
		factory_button.disabled = not world.construction.can_begin(field.selection.friendly_owner_id, building, factory).is_empty()
	var depot := world.supply_depot_definition
	depot_button.visible = build_button.visible and depot != null
	if depot != null:
		depot_button.text = "Build Supply Depot · %d cr · %s s" % [depot.credit_cost, str(depot.duration)]
		depot_button.disabled = not world.construction.can_begin(field.selection.friendly_owner_id, building, depot).is_empty()
	if build_button.visible:
		var reason := world.construction.can_begin(field.selection.friendly_owner_id, building, world.construction_definition)
		build_button.disabled = not reason.is_empty()
		var any_available := not build_button.disabled or (factory_button.visible and not factory_button.disabled) or (depot_button.visible and not depot_button.disabled)
		feedback.text = "Choose a building, then place it." if any_available else reason
	var site := (building as ConstructionBuilding).site if building is ConstructionBuilding else null
	var unfinished := site != null and site.state != ConstructionSite.State.OPERATIONAL
	site_status.visible = unfinished
	site_progress.visible = unfinished
	cancel_site_button.visible = unfinished
	if unfinished:
		train_button.hide()
		progress_bar.hide()
		rows.hide()
		feedback.text = "Paid %d credits · refundable until completion" % site.paid
		site_status.text = site.reason
		cancel_site_button.disabled = not site.cancellable()
	else:
		rows.show()
	_layout.call_deferred()


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(site_progress) and site_progress.visible:
		var building := field.selection.selected_building() as ConstructionBuilding
		if building != null:
			site_progress.value = building.site.progress() * 100.0


func _construction_changed(_site_id: int) -> void:
	_refresh()


func _begin() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var world := field as ConstructionField
	if is_instance_valid(world.placement):
		world.placement.begin(field.selection.selected_building())


func _begin_factory() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var world := field as ConstructionField
	if world.vehicle_factory_definition != null and is_instance_valid(world.placement):
		world.placement.begin(field.selection.selected_building(), world.vehicle_factory_definition)


func _begin_depot() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var world := field as ConstructionField
	if world.supply_depot_definition != null and is_instance_valid(world.placement):
		world.placement.begin(field.selection.selected_building(), world.supply_depot_definition)


func _cancel_site() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var building := field.selection.selected_building() as ConstructionBuilding
	if building != null:
		(field as ConstructionField).construction.cancel(field.selection.friendly_owner_id, building.site.site_id)


func _exit_tree() -> void:
	if is_instance_valid(field) and (field as ConstructionField).construction.changed.is_connected(_construction_changed):
		(field as ConstructionField).construction.changed.disconnect(_construction_changed)
	super._exit_tree()
