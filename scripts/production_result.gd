class_name ProductionResult
extends RefCounted
## Historical acceptance; a notification may already have cancelled this job.

var accepted: bool = false
var reason: String = ""
var job_id: int = 0


static func reject(message: String) -> ProductionResult:
	var result := ProductionResult.new()
	result.reason = message
	return result


static func accept(id: int) -> ProductionResult:
	var result := ProductionResult.new()
	result.accepted = true
	result.job_id = id
	return result
