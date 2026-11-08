extends Node
## Headless check of small-zone reinforcements, the flag shockwave and the
## buff pedestal (issue #25). Run from the project root:
##   godot --headless --path . res://tests/reinforcement_test.tscn

const CONFIG_PATH := "res://zone/reinforcement_config.tres"

var _failures := 0
var _checks := 0
var _finished := false
var _elapsed := 0.0
var _first_wave_player := Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	# Fixed-fps headless frames can outpace the audio worker. Every test scene
	# is already freed; allow its queued playback stops to drain before exit.
	OS.delay_msec(100)
	await get_tree().process_frame
	var ok := _failures == 0 and _finished
	print("%s (%d checks, %d failed%s)" % ["ALL PASSED" if ok else "FAIL", _checks, _failures, "" if _finished else ", run did not finish"])
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
	_check("a wave is every 10 s", is_equal_approx(config.interval_seconds, 10.0))
	_check("a wave is four enemies, twice the original two", config.per_wave == 4)
	_check("two full four-enemy waves can stay out", config.max_alive == 8)

	print("== layout")
	await _check_layout("res://maps/zone_1.tscn", 0, 5)
	await _check_layout("res://maps/zone_2.tscn", 1, 9)

	print("== same seed, same spawns")
	var first := await _first_wave(424242)
	var second := await _first_wave(424242)
	_check("four enemies spawn when the point opens", first.size() == 4 and second.size() == 4)
	_check("the spawn sequence matches", _flats(first) == _flats(second))
	# Spawns are now picked out of sight round the whole arena, not only behind.
	_check("all four spawns stay at least 14 m from the player", first.all(
		func(v: Vector3): return _flat_distance(v,_first_wave_player) >= ZoneDirector.MIN_SPAWN_DISTANCE))
	_check("all four spawns use different markers", _unique_positions(first) == 4)

	print("== two full production waves, cap and refill")
	await _production_wave_capacity()

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
	var exit_court := scene.get_node("Geometry/RoomGeometry/WalkableShell/ExitCourt") as MeshInstance3D
	var entry_court := scene.get_node("Geometry/RoomGeometry/WalkableShell/EntryCourt") as MeshInstance3D
	var rear_bounds: Vector4 = exit_court.get_meta("surface_bounds")
	var front_bounds: Vector4 = entry_court.get_meta("surface_bounds")
	# The compact objective sits on the shared rear-court/ramp edge, as in the
	# original short run-in. Its center may lie exactly on the closed boundary.
	_check("%s building stands in the rear court" % path.get_file(),
		point.global_position.x>=rear_bounds.x and point.global_position.x<=rear_bounds.z
		and point.global_position.z>=rear_bounds.y and point.global_position.z<=rear_bounds.w)
	_check("%s player enters from the front" % path.get_file(), player.global_position.z > point.global_position.z + 15.0)
	var spawns := _spawns(scene)
	_check("%s has spawn markers round the arena" % path.get_file(), spawns.size() >= 6)
	var spread := true
	var behind := 0
	for marker in spawns:
		# Flank and rear-corner markers are intentional: waves must have
		# somewhere out of the player's sight. Only keep them inside the walls
		# and clear of the building; the old "all behind, <=18 m" rule is gone.
		if not _inside(marker.global_position,Vector4(rear_bounds.x,rear_bounds.y,front_bounds.z,front_bounds.w)):
			spread = false
		if marker.global_position.distance_to(point.global_position) < 10.0:
			spread = false
		if marker.global_position.z < point.global_position.z - 8.0:
			behind += 1
	_check("%s spawns are spread inside the arena, clear of the building" % path.get_file(), spread)
	_check("%s still has a rear marker and both flanks" % path.get_file(), behind >= 1
		and spawns.any(func(marker: Marker3D):return marker.global_position.x < point.global_position.x-10.0)
		and spawns.any(func(marker: Marker3D):return marker.global_position.x > point.global_position.x+10.0))
	var guards := _enemies(scene)
	_check("%s guard count" % path.get_file(), guards.size() == guard_count)
	var capsule := guards[0].get_node("CollisionShape3D") as CollisionShape3D
	var blocked_spawns: Array[String] = []
	var off_nav: Array[String] = []
	var nav_map := player.get_world_3d().navigation_map
	for marker in spawns:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule.shape
		query.transform = (marker.global_transform*capsule.transform).translated(Vector3.UP*0.02)
		query.collision_mask = CollisionLayers.WORLD
		query.collide_with_areas = false
		if not player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			blocked_spawns.append(marker.name)
		var closest := NavigationServer3D.map_get_closest_point(nav_map,marker.global_position)
		if Vector2(closest.x-marker.global_position.x,closest.z-marker.global_position.z).length()>0.75 \
				or absf(closest.y-marker.global_position.y)>1.1:
			off_nav.append(marker.name)
	_check("%s leaves each real reinforcement capsule clear of WORLD (%s)" % [path.get_file(),blocked_spawns],blocked_spawns.is_empty())
	_check("%s keeps every reinforcement marker on its intended navigation floor (%s)" % [path.get_file(),off_nav],off_nav.is_empty())
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
	_first_wave_player = (scene.get_node("Player") as Player).global_position
	var guards := _enemies(scene)
	for index in guards.size() - 1:
		guards[index].health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	_check("still locked with one guard up", (scene.get_node("CapturePoint") as CapturePoint).locked and director.reinforcement_spawn_log.is_empty())
	guards[-1].health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	var log := director.reinforcement_spawn_log.duplicate()
	await _close(scene)
	return log


func _production_wave_capacity() -> void:
	var scene := await _open_zone("res://maps/zone_1.tscn",0,82424)
	_choose_entry(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	var point := scene.get_node("CapturePoint") as CapturePoint
	player.health.invulnerable = true
	player.global_position = point.global_position + Vector3(0.0,0.1,3.5)
	await _wait(0.6)
	player.set_physics_process(false)
	# Observe actual 10-second waves with live AI, not a frozen-spawn fixture.
	# This also catches a later wave appearing inside an actor still at a marker.
	var overlaps: Array[String] = []
	var on_spawn := func(_at: Vector3) -> void:
		var actor: Enemy = director._reinforcements.back()
		var capsule := actor.get_node("CollisionShape3D") as CollisionShape3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule.shape
		query.transform = capsule.global_transform
		query.collision_mask = CollisionLayers.ENEMIES
		query.collide_with_areas = false
		query.exclude = [actor.get_rid()]
		if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			overlaps.append(str(actor.name))
	director.reinforcement_spawned.connect(on_spawn)
	for enemy in _enemies(scene):
		enemy.health.apply_damage(99999.0,Hitbox.BodyPart.BODY)
	_check("production opening wave contains four live actors",director.reinforcement_count()==4
		and director.reinforcement_spawn_log.size()==4)
	_check("the first production wave uses four different markers",_unique_positions(director.reinforcement_spawn_log)==4)
	await _wait(9.8)
	_check("production cadence does not add a wave before ten seconds",director.reinforcement_spawn_log.size()==4)
	await _wait(0.3)
	_check("the next production wave adds four, reaching eight",director.reinforcement_count()==8
		and director.reinforcement_spawn_log.size()==8)
	_check("the second production wave also uses four different markers",
		_unique_positions(director.reinforcement_spawn_log.slice(4,8))==4)
	_check("live ten-second waves do not spawn inside an existing movement capsule (%s)" % [overlaps],overlaps.is_empty())
	await _wait(10.05)
	_check("a full eight-actor field rejects another production wave",director.reinforcement_count()==8
		and director.reinforcement_spawn_log.size()==8)
	var before_progress := point.progress
	var live := _enemies(scene).filter(func(enemy: Enemy): return enemy.state!=Enemy.State.DEAD)
	for index in 2:
		(live[index] as Enemy).health.apply_damage(99999.0,Hitbox.BodyPart.BODY)
	_check("two real kills free exactly two reinforcement slots",director.reinforcement_count()==6
		and is_equal_approx(point.progress,before_progress))
	await _wait(10.05)
	_check("a partially full field refills only its two free slots",director.reinforcement_count()==8
		and director.reinforcement_spawn_log.size()==10)
	_check("refilling does not lock or reduce the held point",not point.locked
		and is_equal_approx(point.progress,before_progress))
	# An exhausted safe-spawn pool must skip spawning rather than overlap a
	# living body. The movement layer is blocked only for this safety fixture.
	var remaining := _enemies(scene).filter(func(enemy: Enemy): return enemy.state!=Enemy.State.DEAD)
	for index in 4:
		(remaining[index] as Enemy).health.apply_damage(99999.0,Hitbox.BodyPart.BODY)
	var blockers: Array[StaticBody3D] = []
	for marker in _spawns(scene):
		var body := StaticBody3D.new()
		body.collision_layer = CollisionLayers.ENEMIES
		body.collision_mask = 0
		var capsule := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.height = 1.8
		shape.radius = 0.4
		capsule.shape = shape
		capsule.position.y = 0.9
		body.add_child(capsule)
		scene.add_child(body)
		body.global_position = marker.global_position
		blockers.append(body)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before_blocked := director.reinforcement_spawn_log.size()
	director._wave_used_markers.clear()
	_check("all occupied markers leave no safe candidate or fallback",director._pick_spawn_marker()==null)
	director._spawn_wave()
	_check("an occupied pool cannot create overlapping reinforcements",director.reinforcement_count()==4
		and director.reinforcement_spawn_log.size()==before_blocked)
	for body in blockers:
		body.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	director._spawn_wave()
	_check("cleared markers allow a complete four-actor refill",director.reinforcement_count()==8
		and director.reinforcement_spawn_log.size()==before_blocked+4)
	_check("all production and refill births remain physically separate (%s)" % [overlaps],overlaps.is_empty())
	print("WAVE_CAPACITY | first=4 second=4 full=8 partial_refill=2 occupied_pool=0 cleared_refill=4")
	director.reinforcement_spawned.disconnect(on_spawn)
	await _close(scene)


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
	tuned.per_wave = 4
	tuned.max_alive = 8
	director.reinforcement_config = tuned
	# Give the actual navigation routes enough walking time. A slow ranged
	# caster from the high gallery cannot cross this courtyard in five seconds.
	await _wait(0.05)
	var longest_route := 0.0
	var routes_valid := true
	for marker in _spawns(scene):
		var path := NavigationServer3D.map_get_path(player.get_world_3d().navigation_map,
			marker.global_position,player.global_position,true)
		routes_valid = routes_valid and not path.is_empty()
		var length := 0.0
		for index in range(1,path.size()):length += path[index-1].distance_to(path[index])
		longest_route = maxf(longest_route,length)
	_check("every reinforcement marker has a route toward the held building",routes_valid)
	var reference: Enemy = director.living_enemies()[0]
	var walking_time := longest_route/reference.run_speed
	var wave_time := tuned.interval_seconds*ceilf(float(tuned.max_alive)/tuned.per_wave)
	var allowance := walking_time+reference.seek_timeout+wave_time
	print("APPROACH_BUDGET | route=%.1fm speed=%.1fm/s allowance=%.1fs" % [longest_route,reference.run_speed,allowance])
	var history := {}
	var starts := {}
	var jitter := 0
	for _frame in ceili(60.0*allowance):
		await get_tree().physics_frame
		for enemy in _enemies(scene):
			if not enemy.name.begins_with("Reinforcement") or enemy.state == Enemy.State.DEAD:
				continue
			var id := enemy.get_instance_id()
			if not history.has(id):
				history[id] = []
				starts[id] = enemy.global_position
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
		print("APPROACH_SAMPLE | ",enemy.name," | start=",starts.get(enemy.get_instance_id(),Vector3.INF)," | now=",enemy.global_position," | player_gap=",enemy.global_position.distance_to(player.global_position)," | state=",enemy.state," | seek=",enemy.firing_position)
		# Reaching a valid ranged fighting position is the pursuit contract.
		# Merely being near the point, but blocked from the player, does not pass.
		if enemy.global_position.distance_to(player.global_position) <= enemy.engage_range+0.75 \
				and bool(enemy.get("_sees_target")) and enemy.state == Enemy.State.ENGAGE:
			close += 1
	_check("no reinforcement jitters in a corner", jitter == 0)
	_check("most reinforcements reach a visible firing position in the route budget (%d/%d)" % [close, alive], alive >= 2 and close * 4 >= alive * 3)
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
	tuned.per_wave = 4
	tuned.max_alive = 8
	tuned.flee_timeout_seconds = 0.35
	director.reinforcement_config = tuned
	for enemy in _enemies(scene):
		enemy.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	_check("opening the building spawns a four-enemy wave", director.reinforcement_count() == 4 and director.phase == ZoneDirector.Phase.HAMMER_POINT)
	point.player_in_reach = true
	point.resolve_swing(2.0)
	var held := point.progress
	var sample: Enemy = _enemies(scene).filter(func(e: Enemy): return e.name.begins_with("Reinforcement"))[0]
	var sample_health := sample.health.health
	sample.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	_check("killing a reinforcement does not move progress", is_equal_approx(point.progress, held) and point.progress > 0.0)
	_check("the building stays open", director.phase == ZoneDirector.Phase.HAMMER_POINT and not point.locked)
	await _wait(0.9)
	_check("later waves stop at the eight-enemy cap", director.reinforcement_count() == 8)
	_check("nine bodies were spawned to hold eight after one kill", director.reinforcement_spawn_log.size() == 9)
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


func _unique_positions(log: Array) -> int:
	var seen := {}
	for at in log:
		seen[at] = true
	return seen.size()

func _inside(position: Vector3,bounds: Vector4) -> bool:
	return position.x>bounds.x and position.x<bounds.z and position.z>bounds.y and position.z<bounds.w

func _flat_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
