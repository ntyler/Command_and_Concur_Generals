class_name PlayerCredits
extends RefCounted
## One wallet per field. Mutations are silent until the queue commits its side.

signal changed(owner_id: int)

var _balances: Dictionary[int, int] = {}
var active: bool = true


func _init(owners: Array[int], starting: int, owner_starts: Dictionary = {}) -> void:
	for owner_id in owners:
		_balances[owner_id] = maxi(0, int(owner_starts.get(owner_id, starting)))


func balance(owner_id: int) -> int:
	return _balances.get(owner_id, 0)


func spend(owner_id: int, amount: int) -> bool:
	if not active or amount < 0 or not _balances.has(owner_id) or balance(owner_id) < amount:
		return false
	_balances[owner_id] -= amount
	return true


func refund(owner_id: int, amount: int) -> void:
	if active and amount >= 0 and _balances.has(owner_id):
		_balances[owner_id] += amount


func credit(owner_id: int, amount: int) -> bool:
	# Silent deposit: the caller clears cargo before publishing either side.
	if not active or amount <= 0 or not _balances.has(owner_id) or balance(owner_id) > 9223372036854775807 - amount:
		return false
	_balances[owner_id] += amount
	return true


func publish(owner_id: int) -> void:
	if active:
		changed.emit(owner_id)
