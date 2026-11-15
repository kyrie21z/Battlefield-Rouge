extends Node
var checks := 0
var failures := 0
var output := ""
var finished := 0

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for index in count: await get_tree().physics_frame

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(label+" native capture",get_viewport().get_texture().get_image().save_png(output.path_join(label+".png")) == OK)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	for name in ["fear_1","fear_2","fear_boss"]: await _room(name)
	check("all three production rooms finish",finished == 3)
	OS.delay_msec(250)
	print("FEAR SANCTUM: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _room(name: String) -> void:
	var stage := load("res://maps/realms/"+name+".tscn").instantiate() as RealmStage
	add_child(stage)
	var realm := stage.geometry as FearRealm
	var player := stage.player
	player.set_process_unhandled_input(false)
	for actor in stage.enemies: actor.set_physics_process(false)
	player.health.invulnerable = true
	await frames(5)
	check(name+" keeps the original 36m entry-to-exit distance",realm.player_spawn().distance_to(realm.exit_position()) == 36)
	check(name+" retains the three trap slabs",realm.tiles.size() == 3)
	check(name+" uses the dedicated purple-distance environment",player.view_camera.environment == realm.sanctum.environment and realm.sanctum.environment.fog_enabled)
	var scenery_bodies := realm.sanctum.scenery.find_children("*","PhysicsBody3D",true,false)
	check(name+" grand scenery contributes no physics or navigation bodies",scenery_bodies.is_empty())
	check(name+" bounds static decorative mesh work",realm.sanctum.decor_instances < 220)
	check(name+" six airborne spirits stay outside combat systems",realm.sanctum.ghosts.size() == 6 and realm.sanctum.ghosts.all(func(ghost):return ghost.position.y >= 7 and ghost.find_children("*","CollisionObject3D",true,false).is_empty()))
	var ghost := realm.sanctum.ghosts[0]
	var before := ghost.position
	await frames(15)
	check(name+" spirits drift over time",not ghost.position.is_equal_approx(before))
	get_tree().paused = true
	before = ghost.position
	await frames(10)
	check(name+" pause freezes spirits",ghost.position.is_equal_approx(before))
	get_tree().paused = false
	var ray := PhysicsRayQueryParameters3D.create(Vector3(15,3,0),Vector3(15,-3,0),CollisionLayers.WORLD)
	check(name+" keeps the abyss outside combat genuinely empty",stage.get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
	player.aim_at(Vector3(0,8,-15))
	await capture(name)
	if not stage.boss_room:
		# Real body motion along the new ramps, without teleporting onto the balcony.
		for side in [-1,1]:
			player.position = Vector3(side*9,0.1,8.7)
			player.velocity = Vector3.ZERO
			player.rotation.y = 0
			player._pitch = 0
			player._apply_look()
			Input.action_press("move_forward")
			var peak := 0.0
			for tick in 350:
				await get_tree().physics_frame
				peak = maxf(peak,player.position.y)
				if player.position.z < -8: break
			Input.action_release("move_forward")
			print("ROUTE %s side=%d peak=%.3f finish=%s" % [name,side,peak,player.position])
			check(name+" actual Player traverses side %d without jumping" % side,peak > 1.1 and player.position.z < -7 and player.position.y > -1)
		var map := stage._region.get_navigation_map()
		var path := NavigationServer3D.map_get_path(map,Vector3(9,0,8),Vector3(9,1.2,0),true)
		check(name+" AI navigation reaches the upper balcony",path.size() > 1 and Array(path).any(func(point):return point.y > 1))
		check(name+" second chamber has its own broken architecture",realm.chamber_style == (1 if name == "fear_2" else 0))
		if name == "fear_2":
			player.position = Vector3(9,1.25,0)
			player.aim_at(Vector3(-5,7,-9))
			await capture("fear_balcony")
	else:
		check("Boss keeps the original open dais and no balcony obstruction",realm.sanctum.combat.get_child_count() == 0 and is_instance_valid(stage.boss))
	stage.queue_free()
	await frames(3)
	finished += 1
