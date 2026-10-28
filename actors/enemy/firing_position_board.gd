class_name FiringPositionBoard
extends RefCounted
## One per zone. Enemies reserve the firing position they picked so the others
## do not crowd onto the same spot (issue #40). The zone director owns it and
## hands it to each enemy through setup(); a claim is dropped when its owner is
## freed, even if the owner forgot to release it.

var _claims: Dictionary = {}


func claim(owner: Object, point: Vector3) -> void:
	_claims[owner] = point


func release(owner: Object) -> void:
	_claims.erase(owner)


## Whether another owner has reserved a spot within `spacing` metres on the
## ground plane. Freed owners are skipped without touching the dictionary.
func is_taken(point: Vector3, spacing: float, except: Object = null) -> bool:
	var spacing_sq := spacing * spacing
	for owner in _claims:
		if owner == except or not is_instance_valid(owner):
			continue
		var claimed: Vector3 = _claims[owner]
		if Vector2(claimed.x - point.x, claimed.z - point.z).length_squared() < spacing_sq:
			return true
	return false
