extends Node
## Headless check of the out-of-sight reinforcement spawn rule:
##   godot --headless --path . res://tests/spawn_sight_test.tscn
## A wave must not appear within 14 m of the player or where the player can see
## it; the fallback is the farthest marker, and the pick is deterministic.

var _failures := 0
var _finished := false


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var scene := await _open_zone("res://maps/zone_1.tscn", 0, 98765)
	_choose_entry(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	var point := scene.get_node("CapturePoint") as CapturePoint
	player.set_physics_process(false)
	player.global_position = point.global_position + Vector3(0.0, 0.0, 4.0)
	player.global_rotation = Vector3.ZERO
	for enemy in _enemies(scene):
		enemy.set_physics_process(false)
	await _frames(2)

	var markers := director._spawn_points
	_check("the zone has several spawn markers (%d)" % markers.size(), markers.size() >= 6)
	var before := _visibility(player, markers)
	var log_start := director.reinforcement_spawn_log.size()
	director._reinforcing = true
	director._spawn_wave()
	director._reinforcing = false
	var picks := director.reinforcement_spawn_log.slice(log_start)
	_check("a wave spawns %d enemies" % picks.size(), picks.size() == 2)
	for position in picks:
		var at: Vector3 = position
		_check("spawn is at least %.0f m from the player" % ZoneDirector.MIN_SPAWN_DISTANCE,
			_flat(at, player.global_position) >= ZoneDirector.MIN_SPAWN_DISTANCE)
		_check("spawn is not visible from the player", not _marker_visible(player, at))
	_check("the two enemies use different markers", picks.size() == 2 and picks[0] != picks[1])

	player.global_rotation.y = PI
	await _frames(2)
	var after := _visibility(player, markers)
	_check("turning around changes which markers are visible", before != after)
	player.global_rotation.y = 0.0
	await _frames(2)

	# Every marker visible from high above: the fallback must be the farthest.
	player.global_position = Vector3(0.0, 20.0, 28.0)
	await _frames(2)
	director._wave_used_markers.clear()
	director._spawn_one()
	var expected := _farthest(markers, player.global_position)
	var last: Vector3 = director.reinforcement_spawn_log.back()
	if expected != null:
		_check("the fallback takes the farthest marker (%.1f m)" % _flat(last, player.global_position),
			last.is_equal_approx(expected.global_position))
	await _close(scene)

	# Same seed and setup, first wave again: the pick must repeat.
	var other := await _open_zone("res://maps/zone_1.tscn", 0, 98765)
	_choose_entry(other)
	var other_director := other.get_node("ZoneDirector") as ZoneDirector
	var other_player := other.get_node("Player") as Player
	other_player.set_physics_process(false)
	other_player.global_position = (other.get_node("CapturePoint") as CapturePoint).global_position + Vector3(0.0, 0.0, 4.0)
	other_player.global_rotation = Vector3.ZERO
	for enemy in _enemies(other):
		enemy.set_physics_process(false)
	await _frames(2)
	other_director._reinforcing = true
	other_director._spawn_wave()
	other_director._reinforcing = false
	_check("the same seed and setup pick the same spawns",
		_flats(other_director.reinforcement_spawn_log) == _flats(picks))
	await _close(other)
	_finished = true


func _visibility(player: Player, markers: Array[Node3D]) -> Array[bool]:
	var flags: Array[bool] = []
	for marker in markers:
		flags.append(_marker_visible(player, marker.global_position))
	return flags


func _marker_visible(player: Player, world: Vector3) -> bool:
	var eye := player.eye_position()
	var target := world + Vector3.UP * ZoneDirector.SPAWN_MARKER_HEIGHT
	var direction := target - eye
	if direction.length_squared() < 0.0001:
		return true
	if player.view_forward().angle_to(direction.normalized()) > deg_to_rad(ZoneDirector.SPAWN_VIEW_HALF_ANGLE_DEG):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, CollisionLayers.WORLD)
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _farthest(markers: Array[Node3D], from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance := -1.0
	for marker in markers:
		var distance := _flat(marker.global_position, from)
		if distance > best_distance:
			best = marker
			best_distance = distance
	return best


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _flats(log: Array) -> Array:
	var out: Array = []
	for point in log:
		out.append([snappedf(point.x, 0.01), snappedf(point.z, 0.01)])
	return out


func _open_zone(path: String, zone_index: int, run_seed: int) -> Node:
	get_tree().paused = false
	RunState.clear_fixture()
	RunState.zone_index = zone_index
	RunState.buffs.clear()
	RunState.selection_history.clear()
	RunState.run_seed = run_seed
	BuffPool.reset(run_seed)
	var scene := (load(path) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	return scene


func _close(scene: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(scene):
		scene.free()
	await get_tree().process_frame


func _choose_entry(scene: Node) -> void:
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	if is_instance_valid(director.selection):
		(director.selection.get_node("Center/Box/Choices/Choice1") as Button).pressed.emit()


func _enemies(scene: Node) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if scene.is_ancestor_of(node):
			found.append(node as Enemy)
	return found


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
