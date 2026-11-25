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
	check(label+" native capture",get_viewport().get_texture().get_image().save_jpg(output.path_join(label+".jpg"), 0.91) == OK)

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
	check(name+" the raised exit landing reaches the rear castle wall",
		is_equal_approx(stage.gate.position.y, FearRealm.LANDING_HEIGHT)
		and stage.gate.position.z < -25.0 and realm.has_node("ChancelBackWall"))
	check(name+" retains the three trap slabs",realm.tiles.size() == 3)
	var entry := realm.get_node("Entry") as StaticBody3D
	var entry_shape := (entry.get_child(1) as CollisionShape3D).shape as BoxShape3D
	check(name+" the spawn has an eleven metre stable entry platform",
		is_equal_approx(entry_shape.size.z, 11.0) and realm.player_spawn().z > 17.0)
	check(name+" uses the castle lighting and violet depth fog",player.view_camera.environment == realm.sanctum.environment and realm.sanctum.environment.fog_enabled)
	var scenery_bodies := realm.sanctum.scenery.find_children("*","PhysicsBody3D",true,false)
	check(name+" grand scenery contributes no physics or navigation bodies",scenery_bodies.is_empty())
	check(name+" bounds static decorative mesh work",realm.sanctum.decor_instances < 220)
	var windows := realm.sanctum.scenery.find_children("Lancet*", "MeshInstance3D", false, false)
	check(name+" has glazed lancets and a rose window built into the castle walls",
		windows.size() == 20 and realm.sanctum.scenery.has_node("RoseWindow")
		and realm.sanctum.scenery.has_node("BatchedMasonry"))
	check(name+" the floor and flip slabs share the castle masonry material",
		realm.tiles.all(func(tile: FearFlipTile): return tile.stone_material == realm.sanctum.walk_stone))
	check(name+" six airborne spirits stay outside combat systems",realm.sanctum.ghosts.size() == 6 and realm.sanctum.ghosts.all(func(ghost):return ghost.position.y >= 7 and ghost.find_children("*","CollisionObject3D",true,false).is_empty()))
	var ghost := realm.sanctum.ghosts[0]
	var before := ghost.position
	await frames(86)
	check(name+" spirits patrol through the hall instead of hovering in place",ghost.position.distance_to(before) > 2.5)
	get_tree().paused = true
	before = ghost.position
	await frames(10)
	check(name+" pause freezes spirits",ghost.position.is_equal_approx(before))
	get_tree().paused = false
	var ray := PhysicsRayQueryParameters3D.create(Vector3(15,3,0),Vector3(15,-3,0),CollisionLayers.WORLD)
	check(name+" keeps the abyss outside combat genuinely empty",stage.get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
	player.aim_at(Vector3(0,7.0,-16))
	await capture(name)
	if name == "fear_2" and not output.is_empty():
		player.recover_from_fall(Vector3(0, 0.08, -2.9))
		player.aim_at(Vector3(0, 5.3, -25.3))
		await capture("fear_rear_stair")
	await _walk_off_entry(name, realm, player)
	await _climb_stairs(name, stage, realm, player)
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
		check(name+" second chamber changes the layout of the reliquaries",realm.chamber_style == (1 if name == "fear_2" else 0))
		var ray_to_cover := PhysicsRayQueryParameters3D.create(
			Vector3(5.28, 0.8, 7.0), Vector3(5.28, 0.8, 11.0), CollisionLayers.WORLD)
		var cover := stage.get_world_3d().direct_space_state.intersect_ray(ray_to_cover).get("collider") as Node
		check(name+" a reliquary blocks the actual combat ray", is_instance_valid(cover)
			and cover.name.begins_with("ReliquaryCover") and cover.is_in_group("navigation_geometry"))
		if name == "fear_2":
			player.position = Vector3(9,1.25,2.8)
			player.aim_at(Vector3(0,-1.25,-2))
			await capture("fear_balcony")
	else:
		check("Boss keeps the original combat dais and no balcony obstruction",realm.sanctum.combat.get_child_count() == 0 and is_instance_valid(stage.boss))
	stage.queue_free()
	await frames(3)
	finished += 1


func _walk_off_entry(name: String, realm: FearRealm, player: Player) -> void:
	player.recover_from_fall(realm.player_spawn() + Vector3.UP * 0.06)
	player.aim_at(Vector3(0, player.eye_position().y, 8))
	await frames(15)
	var hp := player.health.health
	Input.action_press("move_right")
	for tick in 185:
		await get_tree().physics_frame
		if player.health.health < hp:
			break
	Input.action_release("move_right")
	check(name+" a real fall from the entry costs 30 HP and returns to the bridge",
		is_equal_approx(player.health.health, hp - 30.0) and absf(player.position.x) <= 4.5
		and player.position.y > -0.15)


func _climb_stairs(name: String, stage: RealmStage, realm: FearRealm, player: Player) -> void:
	player.recover_from_fall(Vector3(0, 0.08, -11.5))
	player.aim_at(Vector3(0, player.eye_position().y, -26.0))
	await frames(5)
	Input.action_press("move_forward")
	for tick in 340:
		await get_tree().physics_frame
		if player.position.z < -25.5:
			break
	Input.action_release("move_forward")
	check(name+" Player climbs the eighteen steps to the raised landing without jumping",
		player.position.z < -25.5 and player.position.y > FearRealm.LANDING_HEIGHT - 0.05)
	var stair_ground := stage.get_world_3d().direct_space_state
	var central_stairs := true
	for x: float in [-4.8, 4.8]:
		var center_ray := PhysicsRayQueryParameters3D.create(Vector3(x, 5.5, -18.5),
			Vector3(x, -2.0, -18.5), CollisionLayers.WORLD)
		var edge_x := signf(x) * 7.5
		var void_ray := PhysicsRayQueryParameters3D.create(Vector3(edge_x, 5.5, -18.5),
			Vector3(edge_x, -2.0, -18.5), CollisionLayers.WORLD)
		central_stairs = central_stairs and stair_ground.intersect_ray(center_ray).get("collider") == realm.get_node("ExitSlope")
		central_stairs = central_stairs and stair_ground.intersect_ray(void_ray).is_empty()
	check(name+" central stairs are physically supported with exposed void on both sides", central_stairs)
	var path := NavigationServer3D.map_get_path(stage._region.get_navigation_map(),
		Vector3(0, 0, -11.5), realm.exit_position() + Vector3.FORWARD, true)
	check(name+" rear stairs connect the bridge and landing in the AI navigation mesh",
		path.size() > 1 and path[-1].y > FearRealm.LANDING_HEIGHT - 0.22 and path[-1].z < -26.2)
