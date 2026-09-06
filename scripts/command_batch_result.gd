class_name CommandBatchResult
extends RefCounted
## Historical acceptance, not a claim that these orders are still active.
## Value identities survive member deletion and synchronous replacement.

enum Acceptance { NONE, PARTIAL, COMPLETE }

var generation: int
var intended_ids: Array[int] = []
var accepted_ids: Array[int] = []
var assignments: Dictionary[int, Vector3] = {} # Accepted movement destinations only.
var superseded: bool = false
var acceptance: Acceptance:
	get:
		if accepted_ids.is_empty():
			return Acceptance.NONE
		return Acceptance.COMPLETE if accepted_ids.size() == intended_ids.size() else Acceptance.PARTIAL


func is_complete() -> bool:
	return acceptance == Acceptance.COMPLETE


func has_acceptance() -> bool:
	return not accepted_ids.is_empty()
