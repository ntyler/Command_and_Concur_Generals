class_name ConstructionResult
extends RefCounted
## Historical acceptance survives cancellation, spending and node deletion.

var accepted: bool = false
var reason: String
var site_id: int = 0
var paid: int = 0


static func reject(message: String) -> ConstructionResult:
	var result := ConstructionResult.new()
	result.reason = message
	return result


static func accept(identity: int, amount: int, message: String) -> ConstructionResult:
	var result := ConstructionResult.new()
	result.accepted = true
	result.site_id = identity
	result.paid = amount
	result.reason = message
	return result
