extends SceneTree
## Asset composition must stay visual-only and keep recipe admission intact.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)


func _run() -> void:
	var probe := EngineErrorProbe.new()
	OS.add_logger(probe)
	var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generals/source.json"))
	for key in sources:
		var model := GeneralsVisuals.create(key, Vector3(4, 3, 5), 1)
		root.add_child(model)
		var box := GeneralsVisuals.bounds(model)
		_check(box.position.is_finite() and box.size.is_finite() and box.size.x > 0 and box.size.y > 0 and box.size.z > 0, key + " has finite visible geometry")
		_check(box.size.x <= 4.001 and box.size.y <= 3.001 and box.size.z <= 5.001 and absf(box.position.y) < 0.001, key + " fits requested bounds and rests on ground")
		var visual_only := true
		for child in model.find_children("*", "", true, false):
			visual_only = visual_only and not child is CollisionObject3D and not child is CollisionShape3D and child.get_script() == null
		_check(visual_only, key + " imports no gameplay scripts or collision")
		model.free()
	var alpha := GeneralsVisuals.create("headquarters", Vector3(6, 2.6, 5), 1)
	var bravo := GeneralsVisuals.create("headquarters", Vector3(6, 2.6, 5), 2)
	var alpha_parts := alpha.find_children("HOUSECOLOR*", "MeshInstance3D", true, false)
	var bravo_parts := bravo.find_children("HOUSECOLOR*", "MeshInstance3D", true, false)
	_check(not alpha_parts.is_empty() and alpha_parts.size() == bravo_parts.size(), "both owners retain original team panels")
	GeneralsVisuals.show_construction(alpha, false)
	var unfinished := (alpha_parts[0] as MeshInstance3D).get_active_material(0) as StandardMaterial3D
	_check(unfinished.albedo_color.is_equal_approx(Color("b99557")), "unfinished imported building retains the existing construction tint")
	GeneralsVisuals.show_construction(alpha, true)
	for index in alpha_parts.size():
		var first := (alpha_parts[index] as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		var second := (bravo_parts[index] as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		_check(first != second and first.albedo_color.is_equal_approx(TeamRules.team_color(1)) and second.albedo_color.is_equal_approx(TeamRules.team_color(2)), "team materials are isolated between owner instances")
	alpha.free()
	bravo.free()
	for defense in ["ground_defense_battery", "air_defense_battery"]:
		var battery := GroundDefenseBattery.new()
		battery.definition = load("res://construction/%s.tres" % defense)
		battery.kind = battery.definition.kind
		root.add_child(battery)
		_check(is_instance_valid(battery.weapon) and is_instance_valid(battery.turret) and is_instance_valid(battery._muzzle), defense + " initializes its actual weapon and original-model turret")
		battery.free()
	var aircraft := load("res://scenes/attack_helicopter.tscn").instantiate() as AttackHelicopter
	root.add_child(aircraft)
	_check(aircraft._rotor.get_child_count() == 2, "actual helicopter rotor owns the original hub and alpha-blended rotor disc")
	aircraft.free()
	for scene_name in ["rifle_unit", "collector_truck"]:
		var actor := load("res://scenes/%s.tscn" % scene_name).instantiate() as RTSUnit
		var peer := load("res://scenes/%s.tscn" % scene_name).instantiate() as RTSUnit
		root.add_child(actor)
		root.add_child(peer)
		var feedback := actor.combat.feedback
		_check(not feedback._body_materials.is_empty() or not feedback._team_shaders.is_empty(), scene_name + " registers nested model materials for damage feedback")
		actor.combat.health.apply_damage(1.0)
		var visible_flash := feedback._body_materials[0].emission_enabled if not feedback._body_materials.is_empty() else float(feedback._team_shaders[0].get_shader_parameter("hit_flash")) > 0.0
		_check(feedback.flash_remaining > 0.0 and visible_flash and peer.combat.feedback.flash_remaining == 0.0, scene_name + " actual health damage flashes only the damaged instance")
		feedback._physics_process(0.2)
		actor.owner_id = 2
		if not feedback._team_shaders.is_empty():
			var color: Color = feedback._team_shaders[0].get_shader_parameter("team_color")
			_check(color.is_equal_approx(TeamRules.team_color(2)) and feedback._team_shaders[0] != peer.combat.feedback._team_shaders[0], "Ranger team mask follows ownership without sharing mutable shader state")
		else:
			_check(feedback._team_materials[0].albedo_color.is_equal_approx(TeamRules.team_color(2)) and feedback._body_materials[0] != peer.combat.feedback._body_materials[0], "truck panels follow ownership without sharing mutable materials")
		actor.free()
		peer.free()
	for recipe_name in ["rifle", "rocket_vehicle", "collector_truck", "bulldozer", "attack_helicopter"]:
		var recipe := load("res://production/%s.tres" % recipe_name) as ProductionDefinition
		_check(recipe.is_valid(), recipe_name + " still passes unchanged production admission")
	await process_frame
	_check(root.get_children().is_empty(), "asset inspection releases every runtime node")
	OS.remove_logger(probe)
	_check(probe.error_count() == 0, "asset composition has no native errors or warnings")
	print("GENERALS_ASSET_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, probe.error_count()])
	quit(0 if failures == 0 else 1)
