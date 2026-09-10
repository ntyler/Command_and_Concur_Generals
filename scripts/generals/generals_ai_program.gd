class_name GeneralsAIProgram
extends RefCounted
## Original serialized programs. Require explicit implementations for every opcode.

var document: Dictionary = {}
var scripts: Array[Dictionary] = []
var conditions: Dictionary = {}
var actions: Dictionary = {}
var teams: Array = []
var players: Array = []
var error: String = ""


func load_program(path: String = "res://assets/generals_rules/zero_hour_skirmishscripts.json") -> bool:
	document.clear()
	scripts.clear()
	conditions.clear()
	actions.clear()
	teams.clear()
	players.clear()
	error = ""
	if not FileAccess.file_exists(path):
		error = "Original AI program is missing: " + path
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		error = "Invalid original AI program"
		return false
	document = parser.data
	if document.get("format_version") != 1 or not document.get("chunks") is Array:
		document.clear()
		error = "Unsupported original AI program format"
		return false
	_index(document.chunks)
	return true


func _index(chunks: Array) -> void:
	for chunk in chunks:
		match str(chunk.label):
			"Script":
				scripts.append(chunk)
			"Condition":
				var name: String = chunk.get("internal_name", "legacy_condition_%s" % chunk.opcode)
				conditions[name] = int(conditions.get(name, 0)) + 1
			"ScriptAction", "ScriptActionFalse":
				var name: String = chunk.get("internal_name", "legacy_action_%s" % chunk.opcode)
				actions[name] = int(actions.get(name, 0)) + 1
			"ScriptTeams":
				teams.append_array(chunk.teams)
			"ScriptsPlayers":
				players.append_array(chunk.players)
		_index(chunk.get("children", []))


func missing_operations(condition_handlers: Dictionary, action_handlers: Dictionary) -> Dictionary:
	var missing_conditions: Array[String] = []
	var missing_actions: Array[String] = []
	for name in conditions:
		if not condition_handlers.get(name) is Callable or not condition_handlers[name].is_valid():
			missing_conditions.append(name)
	for name in actions:
		if not action_handlers.get(name) is Callable or not action_handlers[name].is_valid():
			missing_actions.append(name)
	missing_conditions.sort()
	missing_actions.sort()
	return {"conditions": missing_conditions, "actions": missing_actions}
