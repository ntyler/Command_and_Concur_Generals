class_name GeneralsLogicClock
extends Node
## Original logic cadence, independent of render rate. No simulation authority yet.

signal logic_tick(frame: int)
const LOGIC_FPS: int = 30
var frame: int = 0
var paused: bool = false
var closed: bool = false
var _seconds: float = 0.0


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if closed or paused or not is_finite(delta) or delta <= 0.0:
		return
	_seconds += delta
	while _seconds + 0.000000001 >= 1.0 / LOGIC_FPS:
		_seconds -= 1.0 / LOGIC_FPS
		frame += 1
		logic_tick.emit(frame)
		if closed or paused:
			return


func close() -> void:
	closed = true
	_seconds = 0.0
	set_physics_process(false)
	for connection in logic_tick.get_connections():
		logic_tick.disconnect(connection.callable)
