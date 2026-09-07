class_name ConstructionSite
extends RefCounted
## Instance state only, separate from both shared definitions and live nodes.

enum State { PREPARING, CONSTRUCTING, OPERATIONAL, FAILED, CANCELLING, CANCELLED }
var site_id: int
var owner_id: int
var paid: int
var duration: float
var rectangle: Rect2
var state: State = State.PREPARING
var elapsed: float = 0.0
var started_frame: int = -1
var nav_generation: int = 0
var refunded: bool = false
var reason: String = "Preparing navigation"
var body_ref: WeakRef


func building() -> RTSBuilding:
	return body_ref.get_ref() as RTSBuilding if body_ref != null else null


func cancellable() -> bool:
	return state in [State.PREPARING, State.CONSTRUCTING, State.FAILED]


func progress() -> float:
	return elapsed / duration if duration > 0.0 else 0.0
