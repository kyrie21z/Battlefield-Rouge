extends Node
## Real-map navigation, blocked sight and reserved-space checks for the more
## active encounter. Integration separately observes unmodified opening waves.

var checks := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.clear_fixture()
	RunState.start_new_run()
	RunState.zone_index = 1
	var scene := load("res://maps/zone_2.tscn").instantiate() as Node3D
	add_child(scene)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		(enemy as Enemy).set_physics_process(false)
	var player := scene.get_node("Player") as Player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.health.max_health = 100000.0
	player.health.health = 100000.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in 3: await get_tree().physics_frame
	var anchor := scene.get_node("Enemy6") as SlothEnemy
	_check("fixture uses the actual Anchor beside full WORLD cover", anchor.kind == SlothEnemy.Kind.ANCHOR)
	player.global_position = Vector3(19,0.05,-1.5)
	anchor.setup(player, anchor.cover_points, null)
	anchor._update_sight()
	_check("binding the combat target starts pursuit without a gunshot", anchor.state == Enemy.State.CHASE)
	_check("full cover initially blocks the target", not anchor._sees_target)
	_check("blocked sight does not create an attack", not is_instance_valid(anchor.active_attack))
	var start := anchor.global_position
	anchor.set_physics_process(true)
	var saw_attack := false
	var clear_cast := false
	var ticks := 0
	for frame in 6*60:
		await get_tree().physics_frame
		ticks += 1
		if is_instance_valid(anchor.active_attack):
			saw_attack = true
			var query := PhysicsRayQueryParameters3D.create(anchor.global_position+Vector3.UP*anchor.eye_height,
				player.global_position+Vector3.UP*Enemy.AIM_HEIGHT,CollisionLayers.WORLD)
			clear_cast = anchor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
			break
	_check("Anchor moves around cover instead of waiting indefinitely", anchor.global_position.distance_to(start)>0.75)
	_check("Anchor acquires a real attack within six seconds", saw_attack)
	_check("Anchor only begins the warning after gaining line of sight", clear_cast)
	print("PURSUIT | moved_m=",anchor.global_position.distance_to(start)," | first_cast_seconds=",float(ticks)/60.0)
	anchor.set_physics_process(false)
	anchor._cancel_attack()

	var lingerer := scene.get_node("Enemy1") as SlothEnemy
	player.global_position = Vector3(0,-1.1,-4)
	lingerer.global_position = Vector3(0,0.05,14)
	var board := FiringPositionBoard.new()
	var blocker := Node.new()
	add_child(blocker)
	board.claim(blocker, lingerer.global_position)
	lingerer.setup(player, lingerer.cover_points, board)
	lingerer.cooldown_left = 0.0
	lingerer._update_sight()
	_check("the early-cast fixture has a real unobstructed shot", lingerer._sees_target)
	lingerer.set_physics_process(true)
	for frame in 3: await get_tree().physics_frame
	_check("a reserved neighbour prevents early stopping and casting", not is_instance_valid(lingerer.active_attack))
	board.release(blocker)
	for frame in 3: await get_tree().physics_frame
	_check("a clear free position attacks without finishing a long seek", is_instance_valid(lingerer.active_attack))
	_check("early stopping reserves the actual fighting position", lingerer.firing_position.distance_to(lingerer.global_position)<0.2)
	_check("the authored cast retains its full two-second warning", is_instance_valid(lingerer.active_attack)
		and is_equal_approx(lingerer.active_attack.warning_time(),2.0) and lingerer.active_attack.phase==0)
	lingerer.set_physics_process(false)
	lingerer._cancel_attack()
	blocker.free()
	get_tree().paused = false
	scene.free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	print("SLOTH PURSUIT: %s (%d checks, %d failed)" % ["ALL PASSED" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL",label])
