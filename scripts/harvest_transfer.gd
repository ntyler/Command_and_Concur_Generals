class_name HarvestTransfer
extends RefCounted
## Historical value result, valid even after callbacks spend funds or free nodes.

enum Kind { LOAD, DEPOSIT }
var kind: Kind
var amount: int = 0
var collector_id: int
var owner_id: int
var target_id: int
var generation: int


func committed() -> bool:
	return amount > 0
