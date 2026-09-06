class_name EngineErrorProbe
extends Logger
## Test-only error capture. Engine logger callbacks may arrive from worker threads.

var _errors: int = 0
var _mutex := Mutex.new()


func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	_mutex.lock()
	_errors += 1
	_mutex.unlock()


func error_count() -> int:
	_mutex.lock()
	var count := _errors
	_mutex.unlock()
	return count
