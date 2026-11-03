extends Node
## Headless check of small-zone reinforcements, the flag shockwave and the
## buff pedestal (issue #25). Run from the project root:
##   godot --headless --path . res://tests/reinforcement_test.tscn

const CONFIG_PATH := "res://zone/reinforcement_config.tres"

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
	if _elapsed > 90.0 and not _finished:
		push_error("reinforcement test timed out")
		get_tree().quit(1)


func _run() -> void:
	print("== config")
	var config := load(CONFIG_PATH) as ReinforcementConfig
	_check("cadence resource is zone/reinforcement_config.tres", config != null and config.resource_path == CONFIG_PATH)
	_check("a wave is every 8 s", is_equal_approx(config.interval_seconds, 8.0))
	_check("a wave is 2 enemies", config.per_wave == 2)
	_check("at most 6 reinforcements stay out", config.max_alive == 6)

	print("== layout")
	await _check_layout("res://maps/zone_1.tscn", 0, 4)
	await _check_layout("res://maps/zone_2.tscn", 1, 6)

	print("== same seed, same spawns")
	var first := await _first_wave(424242)
	var second := await _first_wave(424242)
	_check("two enemies spawn on capture", first.size() == 2 and second.size() == 2)
	_check("the spawn sequence matches", _flats(first) == _flats(second))
	# Spawns are now picked out of sight round the whole arena, not only behind.
	_check("both spawns stay at least 14 m from the player", first.all(
		func(v: Vector3): return Vector2(v.x, v.z).distance_to(Vector2(0.0, 14.0)) >= ZoneDirector.MIN_SPAWN_DISTANCE))
	_check("the two spawns use different markers", _flats(first)[0] != _flats(first)[1])

	print("== reinforcements reach the building without corner jitter")
	await _approach_without_jitter()

	print("== rhythm, shockwave, pedestal")
	await _rhythm_and_pedestal()

	print("== boss zone")
	await _boss_skips_all_of_it()
	get_tree().paused = false
	_finished = true


func _check_layout(path: String, zone_index: int, guard_count: int) -> void:
	var scene := await _open_zone(path, zone_index, 1001)
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	_check("%s building is back near z=-8 (%.2f)" % [path.get_file(), point.global_position.z], absf(point.global_position.z + 8.0) < 1.0)
	_check("%s player enters from the front" % path.get_file(), player.global_position.z > point.global_position.z + 15.0)
	var spawns := _spawns(scene)
	_check("%s has spawn markers round the arena" % path.get_file(), spawns.size() >= 6)
	var spread := true
	var behind := 0
	for marker in spawns:
		# Flank and rear-corner markers are intentional: waves must have
		# somewhere out of the player's sight. Only keep them inside the walls
		# and clear of the building; the old "all behind, <=18 m" rule is gone.
		if absf(marker.global_position.x) > 29.0 or absf(marker.global_position.z) > 29.0:
			spread = false
		if marker.global_position.distance_to(point.global_position) < 10.0:
			spread = false
		if marker.global_position.z < point.global_position.z - 8.0:
			behind += 1
	_check("%s spawns are spread inside the arena, clear of the building" % path.get_file(), spread)
	_check("%s still has rear markers" % path.get_file(), behind >= 2)
	var guards := _enemies(scene)
	_check("%s guard count" % path.get_file(), guards.size() == guard_count)
	# Since issue #42 the guards are spread over the whole approach instead of
	# ringing the building: none inside the hammer reach, but at least one close
	# enough to defend the point and one out in the battlefield.
	var nearest := INF
	var farthest := 0.0
	var clear := true
	for enemy in guards:
		var gap := enemy.global_position.distance_to(point.global_position)
		nearest = minf(nearest, gap)
		farthest = maxf(farthest, gap)
		if gap < 3.2:
			clear = false
	_check("%s guards stay out of the hammer reach (nearest %.1f m)" % [path.get_file(), nearest], clear)
	_check("%s guards defend the point and the approach (%.1f-%.1f m)" % [
		path.get_file(), nearest, farthest], nearest <= 16.0 and farthest > 15.0)
	_check("%s uses the cadence resource" % path.get_file(), director.reinforcement_config != null and director.reinforcement_config.resource_path == CONFIG_PATH)
	_check("%s has not spawned yet" % path.get_file(), director.reinforcement_spawn_log.is_empty())
	await _close(scene)


func _first_wave(run_seed: int) -> Array[Vector3]:
	var scene := await _open_zone("res://maps/zone_1.tscn", 0, run_seed)
	_choose_entry(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var guards := _enemies(scene)
	for index in guards.size() - 1:
		guards[index].health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	_check("still locked with one guard up", (scene.get_node("CapturePoint") as CapturePoint).locked and director.reinforcement_spawn_log.is_empty())
	guards[-1].health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	var log := director.reinforcement_spawn_log.duplicate()
	await _close(scene)
	return log


func _approach_without_jitter() -> void:
	var scene := await _open_zone("res://maps/zone_1.tscn", 0, 1001)
	_choose_entry(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	player.health.max_health = 1000000.0
	player.health.health = 1000000.0
	player.set_physics_process(false)
	player.global_position = point.global_position + Vector3(0.0, 0.0, 2.4)
	for enemy in _enemies(scene):
		enemy.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	var tuned := director.reinforcement_config.duplicate() as ReinforcementConfig
	tuned.interval_seconds = 0.35
	tuned.per_wave = 2
	tuned.max_alive = 8
	director.reinforcement_config = tuned
	var history := {}
	var jitter := 0
	for _frame in 60 * 5:
		await get_tree().physics_frame
		for enemy in _enemies(scene):
			if not enemy.name.begins_with("Reinforcement") or enemy.state == Enemy.State.DEAD:
				continue
			var id := enemy.get_instance_id()
			if not history.has(id):
				history[id] = []
			var samples: Array = history[id]
			samples.append({"p": enemy.global_position, "v": Vector3(enemy.velocity.x, 0.0, enemy.velocity.z)})
			if samples.size() > 45:
				samples.pop_front()
			if samples.size() < 40:
				continue
			var moved: float = (samples[0].p as Vector3).distance_to(samples[-1].p)
			var flips := 0
			for i in range(1, samples.size()):
				var a: Vector3 = samples[i - 1].v
				var b: Vector3 = samples[i].v
				if a.length() > 0.6 and b.length() > 0.6 and a.normalized().dot(b.normalized()) < 0.0:
					flips += 1
			var far := enemy.global_position.distance_to(point.global_position) > 6.0
			if far and moved < 0.45 and flips >= 4:
				jitter += 1
				samples.clear()
	var close := 0
	var alive := 0
	for enemy in _enemies(scene):
		if not enemy.name.begins_with("Reinforcement") or enemy.state == Enemy.State.DEAD:
			continue
		alive += 1
		if enemy.global_position.distance_to(point.global_position) <= 16.0:
			close += 1
	_check("no reinforcement jitters in a corner", jitter == 0)
	_check("most reinforcements close on the building (%d/%d)" % [close, alive], alive >= 2 and close * 4 >= alive * 3)
	await _close(scene)


func _rhythm_and_pedestal() -> void:
	var scene := await _open_zone("res://maps/zone_1.tscn", 0, 777)
	_choose_entry(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	player.health.invulnerable = true
	var tuned := director.reinforcement_config.duplicate() as ReinforcementConfig
	tuned.interval_seconds = 0.25
	tuned.per_wave = 2
	tuned.max_alive = 4
	tuned.flee_timeout_seconds = 0.35
	director.reinforcement_config = tuned
	for enemy in _enemies(scene):
		enemy.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	_check("opening the building spawns one wave", director.reinforcement_count() == 2 and director.phase == ZoneDirector.Phase.HAMMER_POINT)
	point.player_in_reach = true
	point.resolve_swing(2.0)
	var held := point.progress
	var sample: Enemy = _enemies(scene).filter(func(e: Enemy): return e.name.begins_with("Reinforcement"))[0]
	var sample_health := sample.health.health
	sample.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	_check("killing a reinforcement does not move progress", is_equal_approx(point.progress, held) and point.progress > 0.0)
	_check("the building stays open", director.phase == ZoneDirector.Phase.HAMMER_POINT and not point.locked)
	await _wait(0.9)
	_check("later waves stop at the cap", director.reinforcement_count() == 4)
	_check("five bodies were spawned to hold four", director.reinforcement_spawn_log.size() == 5)
	var spawned := director.reinforcement_spawn_log.size()
	var kills := [0]
	var on_kill := func(_enemy: Node) -> void: kills[0] += 1
	Events.enemy_killed.connect(on_kill)
	var living := _enemies(scene).filter(func(e: Enemy): return e.state != Enemy.State.DEAD)
	var health_before := {}
	for enemy in living:
		health_before[enemy.get_instance_id()] = enemy.health.health
	while not point.is_captured():
		point.resolve_swing(point.beat_time())
	_check("flag is planted", director.phase == ZoneDirector.Phase.FLAG_PLANTED)
	_check("shockwave mesh is in the scene", scene.get_node_or_null("Shockwave") != null)
	_check("shockwave audio plays", point.get_node_or_null("ShockwaveAudio") != null)
	_check("nothing was killed by the shockwave", kills[0] == 0)
	var fleeing := true
	var unhurt := true
	for enemy in living:
		if not is_instance_valid(enemy):
			fleeing = false
			continue
		if enemy.state != Enemy.State.FLEE:
			fleeing = false
		if not is_equal_approx(enemy.health.health, health_before[enemy.get_instance_id()]):
			unhurt = false
	_check("every living minion is retreating", fleeing)
	_check("the shockwave dealt no damage", unhurt)
	_check("the reward is not up yet", director.selection == null and not get_tree().paused)
	_check("the objective names the pedestal", "按 F" in director.objective)
	await _wait(0.5)
	_check("reinforcements despawn without a kill", director.reinforcement_count() == 0 and kills[0] == 0)
	_check("spawning stopped when the flag went up", director.reinforcement_spawn_log.size() == spawned)
	Events.enemy_killed.disconnect(on_kill)
	var pedestal := director.buff_pedestal
	_check("pedestal exists", pedestal != null)
	player.global_position = pedestal.global_position + Vector3(10.0, 0.0, 0.0)
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	_check("interact out of range does nothing", director.selection == null and not get_tree().paused)
	# change_scene_to_file only replaces the root's current scene.
	scene.get_parent().remove_child(scene)
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	player.global_position = pedestal.global_position
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().process_frame
	_check("interact at the pedestal opens the choice and pauses",
		director.selection_context == "clear" and get_tree().paused and director.selection != null)
	_choose(director, 0)
	for _frame in 40:
		await get_tree().process_frame
		if RunState.zone_index == 1 and get_tree().current_scene != null and get_tree().current_scene.name == "Zone2":
			break
	_check("the chosen card loads the next zone", RunState.zone_index == 1 and get_tree().current_scene != null and get_tree().current_scene.name == "Zone2")
	get_tree().paused = false
	if get_tree().current_scene != null and get_tree().current_scene != self:
		get_tree().current_scene.free()
	await get_tree().process_frame


func _boss_skips_all_of_it() -> void:
	var scene := await _open_zone("res://maps/boss.tscn", 2, 2002)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var point := scene.get_node("CapturePoint") as CapturePoint
	for enemy in _enemies(scene):
		enemy.set_physics_process(false)
	_check("boss has no reinforcement markers", scene.get_node_or_null("ReinforcementSpawns") == null)
	_check("boss has no reinforcement config", director.reinforcement_config == null)
	_check("boss does not spawn", director.reinforcement_spawn_log.is_empty() and director.reinforcement_count() == 0)
	point.player_in_reach = true
	point.resolve_swing(2.5)
	_check("the core stays shut while the boss lives", point.locked and point.progress == 0.0)
	(scene.get_node("Boss") as Enemy).health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	point.resolve_swing(2.5)
	_check("boss flag has no pedestal", director.buff_pedestal == null)
	_check("boss flag has no shockwave", scene.get_node_or_null("Shockwave") == null)
	await get_tree().create_timer(ZoneDirector.FLAG_RAISE_TIME + 0.2).timeout
	_check("boss still wins with no buff offer", director.get_children().any(func(c: Node): return c.has_signal("restart_pressed"))
		and not director.get_children().any(func(c: Node): return c.has_signal("chosen")))
	await _close(scene)


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
	# queue_free waits until the end of the frame, so the next zone would still
	# see this one's spawn markers and draw a different reinforcement sequence.
	if is_instance_valid(scene):
		scene.free()
	await get_tree().process_frame


func _choose_entry(scene: Node) -> void:
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	if is_instance_valid(director.selection):
		(director.selection.get_node("Center/Box/Choices/Choice1") as Button).pressed.emit()


func _choose(director: ZoneDirector, index: int) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1 + index
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _spawns(scene: Node) -> Array[Marker3D]:
	var found: Array[Marker3D] = []
	for node in get_tree().get_nodes_in_group("reinforcement_spawn"):
		if scene.is_ancestor_of(node):
			found.append(node as Marker3D)
	return found


func _enemies(scene: Node) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if scene.is_ancestor_of(node):
			found.append(node as Enemy)
	return found


func _flats(log: Array[Vector3]) -> Array:
	var flats: Array = []
	for point in log:
		flats.append([snappedf(point.x, 0.01), snappedf(point.z, 0.01)])
	return flats


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
