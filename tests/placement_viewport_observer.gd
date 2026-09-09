extends SceneTree
## Passive evidence collection for manual/native viewport placement verification.
## Launch with --script res://tests/placement_viewport_observer.gd --
## --placement-capture-dir=<absolute directory>. Gameplay is never overridden.

const SCENE_PATH := "res://scenes/fortified_assault.tscn"
const MAX_CAPTURES := 24

class ViewportInputObserver extends Node:
	var observer: SceneTree

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			observer.record_input(event)

var world: FortifiedAssaultField
var capture_dir := ""
var evidence_file: FileAccess
var started_msec := 0
var last_preview := ""
var last_capture_preview := ""
var last_result_id := 0
var last_match_result := -1
var site_states: Dictionary = {}
var capture_queue: Array[Dictionary] = []
var capture_count := 0
var capture_running := false
var poll_elapsed := 0.0


func _initialize() -> void:
	started_msec = Time.get_ticks_msec()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--placement-capture-dir="):
			capture_dir = argument.trim_prefix("--placement-capture-dir=")
	if not capture_dir.is_empty():
		var error := DirAccess.make_dir_recursive_absolute(capture_dir)
		if error == OK:
			evidence_file = FileAccess.open(capture_dir.path_join("placement-evidence.jsonl"), FileAccess.WRITE)
		else:
			push_error("Unable to create placement capture directory: %s" % error)
	_start.call_deferred()


func _start() -> void:
	world = load(SCENE_PATH).instantiate() as FortifiedAssaultField
	root.add_child(world)
	current_scene = world
	var input_observer := ViewportInputObserver.new()
	input_observer.name = "ReadOnlyPlacementInputObserver"
	input_observer.observer = self
	root.add_child(input_observer)
	var definitions: Array = []
	for definition in [world.supply_depot_definition, world.construction_definition, world.power_plant_definition]:
		definitions.append({"name": definition.display_name(), "resource": definition.resource_path,
			"cost": definition.credit_cost, "duration": definition.duration, "footprint": definition.footprint})
	var buildings: Array = []
	for building in world.registered_buildings():
		buildings.append({"object": building, "owner_id": building.owner_id,
			"kind": RTSBuilding.Kind.keys()[building.kind], "point": building.global_position,
			"footprint": building.footprint, "exit": building.exit_position()})
	_emit("scene_start", {"scene": SCENE_PATH, "starting_credits": world.starting_credits,
		"wallet": world.credits.balance(1), "time_scale": Engine.time_scale,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"assault_delay": world.assault_delay, "enemy_config": world.enemy_config.resource_path,
		"enemy_first_wave_time": world.enemy_config.first_wave_time,
		"enemy_wave_interval": world.enemy_config.wave_interval,
		"enemy_breach_enabled": world.enemy_config.breach_enabled,
		"build_area": world.construction_area(), "physical_map": world.field_bounds,
		"camera_pan_bounds": world.camera_rig.map_bounds, "clearance": TestField.CLEARANCE,
		"builder_construction_enabled": world.builder_construction_enabled,
		"builder": world.initial_builder, "builder_point": world.initial_builder.global_position,
		"viewport_size": root.size, "camera_point": world.camera_rig.global_position,
		"camera_zoom": world.camera_rig.zoom, "edge_scrolling_enabled": world.camera_rig.edge_scrolling_enabled,
		"definitions": definitions, "buildings": buildings, "reservations": _regions(),
		"unvalidated_candidate_screen_points": {
			"depot_near_hq": world.camera_rig.camera.unproject_position(Vector3(-10.1, 0, -6)),
			"barracks_south_east_of_hq": world.camera_rig.camera.unproject_position(Vector3(-12, 0, 3)),
			"power_south_of_hq": world.camera_rig.camera.unproject_position(Vector3(-21, 0, 3)),
			"hq_approach_rejection": world.camera_rig.camera.unproject_position(Vector3(-11, 0, -6)),
			"hq_delivery_rejection": world.camera_rig.camera.unproject_position(Vector3(-20.5, 0, 1))}})
	_queue_capture("scene_start")


func _process(delta: float) -> bool:
	if not is_instance_valid(world) or not is_instance_valid(world.placement):
		return false
	poll_elapsed += delta
	if poll_elapsed < 0.1:
		return false
	poll_elapsed = 0.0
	_observe_preview()
	_observe_sites()
	if int(world.result) != last_match_result:
		last_match_result = int(world.result)
		_emit("match_result", {"result": BaseAssaultField.Result.keys()[world.result]})
	return false


func record_input(event: InputEventMouseButton) -> void:
	if not is_instance_valid(world):
		return
	_emit("viewport_mouse_press", {"button": event.button_index, "position": event.position,
		"placement_active": world.placement.active,
		"preview": _preview_data(), "selected_units": world.selection.selected_units()})


func _observe_preview() -> void:
	var placement := world.placement
	var choice := placement.definition.display_name() if placement.definition != null else ""
	var key := "%s|%s|%s|%s|%.1f|%.1f" % [placement.active, placement.preview.visible,
		choice, placement.reason, snappedf(placement.point.x, 0.5), snappedf(placement.point.z, 0.5)]
	if key != last_preview:
		last_preview = key
		_emit("placement_preview", _preview_data())
	var capture_key := "%s|%s|%s" % [placement.active, choice, placement.reason]
	if capture_key != last_capture_preview and placement.active and placement.preview.visible:
		last_capture_preview = capture_key
		_queue_capture("preview_" + ("valid" if placement.valid else "rejected"), _preview_data())
	var result := placement.last_result
	if result != null and result.get_instance_id() != last_result_id:
		last_result_id = result.get_instance_id()
		_emit("placement_result", {"accepted": result.accepted, "reason": result.reason,
			"site_id": result.site_id, "paid": result.paid, "wallet": world.credits.balance(1)})


func _preview_data() -> Dictionary:
	var placement := world.placement
	var data := {"active": placement.active, "visible": placement.preview.visible,
		"valid": placement.valid, "reason": placement.reason, "point": placement.point,
		"pointer": placement._pointer, "status_text": placement.status.text,
		"wallet": world.credits.balance(1)}
	if placement.definition == null:
		return data
	data["definition"] = placement.definition.display_name()
	data["cost"] = placement.definition.credit_cost
	data["orientation"] = placement.orientation_degrees
	var footprint := placement.definition.oriented_footprint(placement.orientation_degrees)
	var rectangle := Rect2(Vector2(placement.point.x, placement.point.z) - footprint / 2.0, footprint)
	var clearance := rectangle.grow(TestField.CLEARANCE)
	data["footprint"] = rectangle
	data["clearance_margin"] = TestField.CLEARANCE
	data["clearance_rectangle"] = clearance
	data["boundary_conflict"] = placement.boundary_conflict
	data["overlapping_regions"] = []
	for region in _regions():
		var area: Rect2 = region.get("rectangle", region.get("rect", Rect2()))
		if clearance.intersects(area, true):
			var overlap: Dictionary = region.duplicate()
			overlap["intersection"] = clearance.intersection(area)
			overlap["footprint_intersects"] = rectangle.intersects(area, true)
			data["overlapping_regions"].append(overlap)
	return data


func _regions() -> Array:
	if world.has_method("protected_regions"):
		return world.call("protected_regions")
	var regions: Array = []
	var index := 0
	for rectangle in world.protected_areas():
		regions.append({"index": index, "rectangle": rectangle, "metadata_available": false})
		index += 1
	return regions


func _observe_sites() -> void:
	for site: ConstructionSite in world.construction.sites.values():
		var state := "%d|%d" % [site.state, int(site.elapsed / 2.0)]
		if site_states.get(site.site_id, "") == state:
			continue
		var is_new := not site_states.has(site.site_id)
		site_states[site.site_id] = state
		var body := site.building()
		var builder := site.builder()
		var data := {"site_id": site.site_id, "state": ConstructionSite.State.keys()[site.state],
			"reason": site.reason, "rectangle": site.rectangle, "point": site.rectangle.get_center(),
			"building": body, "definition": body.definition.display_name() if body is ConstructionBuilding else "",
			"paid": site.paid, "duration": site.duration, "elapsed": site.elapsed,
			"builder": builder, "builder_point": builder.global_position if is_instance_valid(builder) else null,
			"builder_required": site.builder_required, "work_access": site.work_access,
			"navigation_blocked": world.construction.navigation.blocked,
			"wallet": world.credits.balance(1), "refunded": site.refunded}
		_emit("construction_site", data)
		if is_new or site.state == ConstructionSite.State.OPERATIONAL:
			_queue_capture("site_%d_%s" % [site.site_id, data["state"]], data)
	for identity in site_states.keys():
		if not world.construction.sites.has(identity):
			site_states.erase(identity)
			_emit("site_removed", {"site_id": identity, "wallet": world.credits.balance(1)})


func _queue_capture(label: String, context: Dictionary = {}) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless" or capture_count >= MAX_CAPTURES:
		return
	capture_count += 1
	capture_queue.append({"sequence": capture_count, "label": label, "context": context})
	if not capture_running:
		capture_running = true
		_capture_frames.call_deferred()


func _capture_frames() -> void:
	# GPU readback runs after a rendered frame, never in a physics callback.
	while not capture_queue.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		var item: Dictionary = capture_queue.pop_front()
		var path := capture_dir.path_join("%02d_%s.png" % [item["sequence"], item["label"]])
		var screenshot := root.get_texture().get_image()
		var error := screenshot.save_png(path)
		_emit("viewport_capture", {"path": path, "error": error, "context": item["context"]})
	capture_running = false


func _emit(kind: String, data: Dictionary) -> void:
	var record := {"event": kind, "wall_seconds": (Time.get_ticks_msec() - started_msec) / 1000.0,
		"physics_frame": Engine.get_physics_frames(), "data": _json_value(data)}
	if is_instance_valid(world):
		record["scene_seconds"] = world.elapsed
	var line := JSON.stringify(record)
	print("PLACEMENT_EVIDENCE " + line)
	if evidence_file != null:
		evidence_file.store_line(line)
		evidence_file.flush()


func _json_value(value: Variant) -> Variant:
	if value is Rect2:
		return {"position": _json_value(value.position), "size": _json_value(value.size), "end": _json_value(value.end)}
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is Vector3 or value is Vector3i:
		return [value.x, value.y, value.z]
	if value is Dictionary:
		var dictionary := {}
		for key in value:
			dictionary[str(key)] = _json_value(value[key])
		return dictionary
	if value is Array:
		var array: Array = []
		for item in value:
			array.append(_json_value(item))
		return array
	if value is WeakRef:
		return _json_value(value.get_ref())
	if value is Node:
		return {"name": str(value.name), "path": str(value.get_path()), "instance_id": value.get_instance_id()}
	if value is Object:
		return str(value)
	return value
