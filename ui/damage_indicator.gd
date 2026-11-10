class_name DamageIndicator
extends Control
## Red arcs at the screen edge pointing at recent attackers. Stores the
## attacker's world position at hit time (the attacker may die), then turns it
## into an angle against the player's yaw every frame. Straight ahead is the
## top of the circle, behind is the bottom.

## Seconds an arc stays on screen.
const LIFE := 1.0
## Hits this close in angle refresh the same arc instead of adding one.
const MERGE_ARC_DEGREES := 20.0
## Width of the drawn arc.
const ARC_DEGREES := 40.0
## Arc radius as a share of the viewport height, so it scales with the screen.
const RADIUS_FRACTION := 0.18
const THICKNESS := 6.0
## Dark border drawn under the red arc, in pixels on each side.
const OUTLINE := 3.0
const MAX_ENTRIES := 4
## Alpha at the smallest hit; a hit of FULL_ALPHA_DAMAGE reaches full alpha.
const MIN_ALPHA := 0.35
const FULL_ALPHA_DAMAGE := 25.0
const ARC_COLOR := Color(0.95, 0.12, 0.08)
const OUTLINE_COLOR := Color(0.12, 0.0, 0.0, 0.85)

var _player: Player
var _entries: Array[Dictionary] = []


## The HUD calls this once; the player is only read, never changed.
func setup(player: Player) -> void:
	_player = player


## 0 = straight ahead (top of the circle), +PI/2 = right, +/-PI = behind.
func add_hit(source: Node3D, damage: float) -> void:
	if _player == null or not is_instance_valid(source):
		return
	if _player.realm_effects != null and not _player.realm_effects.warnings_enabled:
		return
	var point := source.global_position
	var angle := _angle_to(point)
	for entry in _entries:
		var other: Vector3 = entry["position"]
		if absf(wrapf(angle - _angle_to(other), -PI, PI)) <= deg_to_rad(MERGE_ARC_DEGREES):
			entry["position"] = point
			entry["damage"] = maxf(entry["damage"], damage)
			entry["life"] = LIFE
			queue_redraw()
			return
	if _entries.size() >= MAX_ENTRIES:
		_entries.pop_front()
	_entries.append({"position": point, "damage": damage, "life": LIFE})
	queue_redraw()


## Direction of each stored hit in the player's frame, for tests and proofs.
func entry_angle(index: int) -> float:
	if index < 0 or index >= _entries.size():
		return 0.0
	var point: Vector3 = _entries[index]["position"]
	return _angle_to(point)


func entry_count() -> int:
	return _entries.size()


func clear() -> void:
	_entries.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _player != null and _player.realm_effects != null and not _player.realm_effects.warnings_enabled:
		if not _entries.is_empty():
			clear()
		return
	if _entries.is_empty():
		return
	for index in range(_entries.size() - 1, -1, -1):
		var entry := _entries[index]
		entry["life"] = float(entry["life"]) - delta
		if float(entry["life"]) <= 0.0:
			_entries.remove_at(index)
	queue_redraw()


func _angle_to(point: Vector3) -> float:
	if _player == null:
		return 0.0
	var to := point - _player.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 0.0
	var forward := -_player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := _player.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return atan2(to.normalized().dot(right), to.normalized().dot(forward))


func _draw() -> void:
	if _player == null or _entries.is_empty():
		return
	var centre := get_viewport_rect().size * 0.5 if size.y <= 0.0 else size * 0.5
	var radius := (get_viewport_rect().size.y if size.y <= 0.0 else size.y) * RADIUS_FRACTION
	var half := deg_to_rad(ARC_DEGREES) * 0.5
	for entry in _entries:
		var point: Vector3 = entry["position"]
		var fade := clampf(float(entry["life"]) / LIFE, 0.0, 1.0)
		var strength := lerpf(MIN_ALPHA, 1.0, clampf(float(entry["damage"]) / FULL_ALPHA_DAMAGE, 0.0, 1.0))
		var alpha := fade * strength
		# draw_arc measures from +X; our angle is clockwise from -Y (up).
		var middle := _angle_to(point) - PI * 0.5
		draw_arc(centre, radius, middle - half, middle + half, 20,
			Color(OUTLINE_COLOR, OUTLINE_COLOR.a * alpha), THICKNESS + OUTLINE * 2.0, true)
		draw_arc(centre, radius, middle - half, middle + half, 20,
			Color(ARC_COLOR, alpha), THICKNESS, true)
