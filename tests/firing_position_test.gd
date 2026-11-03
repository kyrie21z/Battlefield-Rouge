extends Node
## Headless check of firing positions and hammer noise (issue #40). Run from
## the project root:
##   godot --headless --path . res://tests/firing_position_test.tscn
## Prints one line per check. Exits 1 if a check failed or the run stopped
## before the last check.

const ZONE := "res://maps/zone_1.tscn"

var _failures := 0
var _finished := false
var _elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures, "" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 180.0 and not _finished:
		push_error("firing position test timed out")
		get_tree().quit(1)


func _run() -> void:
	print("== reinforcements behind the building find a firing position")
	await _behind_the_building()

	print("== several reinforcements keep their spots apart")
	await _spots_stay_apart()

	print("== hammering wakes idle guards in hearing range only")
	await _hammer_noise()

	print("== the same input picks the same spots")
	await _deterministic_picks()

	get_tree().paused = false
	_finished = true


func _behind_the_building() -> void:
	var scene := await _open_zone(ZONE, 0, 40040)
	_choose_entry(scene)
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	_place_player_behind(point, player)

	_freeze_guards(scene)
	await _settle_navigation()
	_kill_guards(scene)
	await get_tree().physics_frame
	var first := _reinforcements(scene)
	_check("the first wave spawns", first.size() == 2)
	# Spawns now include flank and rear-corner markers, so the building no longer
	# blocks every one of them. The rule is the player's view: a spawn is hidden
	# when it is outside the view cone or a WORLD ray from the eye is blocked.
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var hidden := not director.reinforcement_spawn_log.is_empty()
	for spawn in director.reinforcement_spawn_log:
		var eye := player.eye_position()
		var target: Vector3 = spawn + Vector3.UP * ZoneDirector.SPAWN_MARKER_HEIGHT
		var direction := (target - eye).normalized()
		if player.view_forward().angle_to(direction) > deg_to_rad(ZoneDirector.SPAWN_VIEW_HALF_ANGLE_DEG):
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, target, CollisionLayers.WORLD)
		if scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			hidden = false
	_check("the first wave spawns out of the player's view", hidden)
	var seeking := not first.is_empty()
	for enemy in first:
		if enemy.state == Enemy.State.IDLE or enemy.firing_position == Vector3.INF:
			seeking = false
	_check("reinforcements pick a firing position on spawn", seeking)
	var sample: Enemy = first[0] if not first.is_empty() else null
	var min_distance := sample.min_engage_distance if sample != null else 6.0
	var eye_height := sample.eye_height if sample != null else 1.55

	var shots: Array[Vector3] = []
	var on_shot := func(position: Vector3) -> void: shots.append(position)
	Events.gunshot.connect(on_shot)
	var waited := 0.0
	while shots.is_empty() and waited < 15.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	Events.gunshot.disconnect(on_shot)
	_check("a reinforcement fires within 15 s", not shots.is_empty())
	var closest := INF
	for shot in shots:
		closest = minf(closest, shot.distance_to(player.global_position))
	_check("it does not fire from arm's length (closest %.2f m)" % closest,
		not shots.is_empty() and closest >= min_distance - 0.1)
	if not shots.is_empty():
		var query := PhysicsRayQueryParameters3D.create(shots[0] + Vector3.UP * eye_height,
			_player_point(player), CollisionLayers.WORLD)
		_check("the shot comes from a spot with a clear line of sight",
			scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	await _close(scene)


func _spots_stay_apart() -> void:
	var scene := await _open_zone(ZONE, 0, 40041)
	_choose_entry(scene)
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	_place_player_behind(point, player)
	var tuned := director.reinforcement_config.duplicate() as ReinforcementConfig
	tuned.interval_seconds = 0.25
	tuned.per_wave = 2
	tuned.max_alive = 6
	director.reinforcement_config = tuned
	_freeze_guards(scene)
	await _settle_navigation()
	_kill_guards(scene)

	var waited := 0.0
	while _reinforcements(scene).size() < 4 and waited < 8.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	var living: Array[Enemy] = []
	for enemy in _reinforcements(scene):
		if enemy.state != Enemy.State.DEAD and enemy.firing_position != Vector3.INF:
			living.append(enemy)
	_check("four reinforcements reserved firing positions (%d)" % living.size(), living.size() >= 4)
	var spacing: float = (living[0] as Enemy).seek_spacing if not living.is_empty() else 3.5
	var min_gap := INF
	var within_ring := true
	for i in living.size():
		var spot := living[i].firing_position
		if Vector2(spot.x - player.global_position.x, spot.z - player.global_position.z).length() < 8.0 - 0.1 \
				or Vector2(spot.x - player.global_position.x, spot.z - player.global_position.z).length() > 20.0 + 0.1:
			within_ring = false
		for j in range(i + 1, living.size()):
			var other := living[j].firing_position
			min_gap = minf(min_gap, Vector2(spot.x - other.x, spot.z - other.z).length())
	_check("spots stay on the 8-20 m ring", living.size() >= 4 and within_ring)
	_check("spots are at least %.1f m apart (closest %.2f m)" % [spacing, min_gap],
		living.size() >= 2 and min_gap >= spacing - 0.05)
	await _close(scene)


func _hammer_noise() -> void:
	var scene := await _open_zone(ZONE, 0, 40042)
	_choose_entry(scene)
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	_place_player_behind(point, player)
	var guards := _enemies(scene)
	_check("the zone starts with four guards", guards.size() == 4)
	for index in range(2, guards.size()):
		guards[index].health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	var near := guards[0]
	var far := guards[1]
	_take_position(near, point.global_position + Vector3(0.0, 0.0, -5.0), 0.0)
	_take_position(far, Vector3(25.0, 0.0, 25.0), -PI * 0.5)
	await _settle_navigation()
	_check("the close guard starts idle", near.state == Enemy.State.IDLE)
	_check("the far guard starts idle", far.state == Enemy.State.IDLE)
	_check("the close guard is inside hearing range (%.1f m)" % near.global_position.distance_to(point.global_position),
		near.global_position.distance_to(point.global_position) <= near.hearing_range)
	_check("the far guard is outside hearing range (%.1f m)" % far.global_position.distance_to(point.global_position),
		far.global_position.distance_to(point.global_position) > far.hearing_range)
	point.open()
	point.player_in_reach = true
	point.resolve_swing(2.0)
	await get_tree().physics_frame
	_check("hammering wakes the close idle guard", near.state != Enemy.State.IDLE)
	_check("hammering leaves the far idle guard alone", far.state == Enemy.State.IDLE)
	await _close(scene)


func _deterministic_picks() -> void:
	var first := await _pick_positions(40043)
	var second := await _pick_positions(40043)
	_check("both runs spawn the first wave", first.size() == 2 and second.size() == 2)
	_check("both runs pick the same positions", first.size() >= 2 and str(first) == str(second))


func _pick_positions(run_seed: int) -> Array[Vector3]:
	var scene := await _open_zone(ZONE, 0, run_seed)
	_choose_entry(scene)
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	_place_player_behind(point, player)
	_freeze_guards(scene)
	await _settle_navigation()
	_kill_guards(scene)
	await get_tree().physics_frame
	var spots: Array[Vector3] = []
	for enemy in _reinforcements(scene):
		spots.append(enemy.firing_position)
	await _close(scene)
	return spots


func _place_player_behind(point: CapturePoint, player: Player) -> void:
	player.health.max_health = 100000.0
	player.health.health = 100000.0
	player.health.invulnerable = true
	player.set_physics_process(false)
	player.global_position = point.global_position + Vector3(0.0, 0.0, 3.5)


func _take_position(enemy: Enemy, position: Vector3, yaw: float) -> void:
	enemy.global_position = position
	enemy.rotation.y = yaw
	enemy.velocity = Vector3.ZERO


func _settle_navigation() -> void:
	for _frame in 2:
		await get_tree().physics_frame


## Keeps the guards from reacting to the scripted player while the navmesh syncs.
func _freeze_guards(scene: Node) -> void:
	for enemy in _enemies(scene):
		enemy.set_physics_process(false)


func _kill_guards(scene: Node) -> void:
	for enemy in _enemies(scene):
		if not enemy.name.begins_with("Reinforcement"):
			enemy.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)


func _player_point(player: Player) -> Vector3:
	return player.global_position + Vector3.UP * Enemy.AIM_HEIGHT


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


func _spawns(scene: Node) -> Array[Marker3D]:
	var found: Array[Marker3D] = []
	for node in get_tree().get_nodes_in_group("reinforcement_spawn"):
		if scene.is_ancestor_of(node):
			found.append(node as Marker3D)
	return found


func _reinforcements(scene: Node) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if scene.is_ancestor_of(enemy) and enemy.name.begins_with("Reinforcement"):
			found.append(enemy)
	return found


func _enemies(scene: Node) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if scene.is_ancestor_of(node):
			found.append(node as Enemy)
	return found


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
