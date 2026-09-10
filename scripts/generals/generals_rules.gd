class_name GeneralsRules
extends RefCounted
## Original ordered rule data. Importing a field does not implement its behavior.

var definitions: Dictionary = {}
var source_count: int = 0
var error: String = ""


func load_database(path: String = "res://assets/generals_rules/zero_hour_rules.json") -> bool:
	definitions.clear()
	source_count = 0
	error = ""
	if not FileAccess.file_exists(path):
		error = "Original rules file is missing: " + path
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		error = "Invalid original rules file: " + path
		return false
	var data: Dictionary = parser.data
	if data.get("format_version") != 1 or not data.get("sources") is Array:
		error = "Unsupported original rules format"
		return false
	for source in data.sources:
		source_count += 1
		for record in source.records:
			var kind: String = record.key
			if not definitions.has(kind):
				definitions[kind] = []
			var entry: Dictionary = record.duplicate(true)
			entry["source"] = source.path
			entry["source_sha256"] = source.sha256
			definitions[kind].append(entry)
	return true


func records(kind: String) -> Array:
	return definitions.get(kind, [])


func find_definition(kind: String, name: String) -> Dictionary:
	var found: Dictionary = {}
	for record in records(kind):
		if str(record.value).get_slice(" ", 0) == name:
			found = record
	return found


static func values(record: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	for entry in record.get("entries", []):
		if entry.key == key and not entry.has("entries"):
			result.append(str(entry.value))
	return result


static func value(record: Dictionary, key: String, fallback: String = "") -> String:
	var found := values(record, key)
	return fallback if found.is_empty() else found[-1]


static func blocks(record: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in record.get("entries", []):
		if entry.key == key and entry.has("entries"):
			result.append(entry)
	return result


func global_value(kind: String, key: String, fallback: String = "") -> String:
	var result := fallback
	for record in records(kind):
		result = value(record, key, result)
	return result


func declared_playable_factions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in records("PlayerTemplate"):
		if value(record, "PlayableSide").to_lower() == "yes":
			result.append(record)
	return result


func command_slots(command_set: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in find_definition("CommandSet", command_set).get("entries", []):
		if not str(entry.key).is_valid_int():
			continue
		var command := find_definition("CommandButton", entry.value)
		result.append({"slot": int(entry.key), "name": entry.value, "definition": command})
	return result
