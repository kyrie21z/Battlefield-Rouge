extends Node
var checks := 0
var failures := 0
var output := ""
var complete := false

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for index in count: await get_tree().physics_frame

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(label+" native capture",get_viewport().get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
	get_tree().paused = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	await run()
	check("all morph and slope scenarios finish",complete)
	get_tree().paused = false
	await frames(3)
	OS.delay_msec(250)
	print("FEAR MORPH CRAWLER: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func run() -> void:
	var room := load("res://maps/realms/fear_2.tscn").instantiate() as RealmStage
	add_child(room)
	var crawler: FearRealmEnemy
	var master: FearReaper
	for actor in room.enemies:
		actor.set_physics_process(false)
		if actor is FearRealmEnemy and actor.variant == 2: crawler = actor
		if actor is FearReaper: master = actor
	var player := room.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.health.max_health = 1000
	player.health.health = 1000
	master._summon()
	var ghost := master.living_wisps()[0]
	for wisp in master.living_wisps(): wisp.set_physics_process(false)
	ghost.position = Vector3(0,1.4,13.7)
	ghost._face(player.position-ghost.position,100)
	player.aim_at(ghost.position)
	ghost.visual.advance(0,0,false)
	check("calm face keeps a small mouth and hides fangs",ghost.visual.threat == 0 and not ghost.visual.teeth.visible and ghost.visual.mouth.scale.y < 0.04)
	await frames(3)
	await capture("ghost-calm")
	var last := 0.0
	var monotonic := true
	for step in 11:
		ghost.visual.advance(0.055,step/10.0,false)
		monotonic = monotonic and ghost.visual.mouth.scale.y >= last
		last = ghost.visual.mouth.scale.y
		if step == 5: await capture("ghost-changing")
		if not output.is_empty() and DisplayServer.get_name() != "headless": await capture("morph-%02d" % step)
	check("one continuous windup opens mouth without a mesh swap",monotonic and ghost.visual.threat == 1 and ghost.visual.teeth.visible and ghost.visual.tongue.visible)
	var anchored := true
	for tooth in ghost.visual.fang_meshes:
		var upper := bool(tooth.get_meta("upper"))
		var socket := tooth.get_parent() as Node3D
		var base := tooth.position.y+(0.325 if upper else -0.325)*tooth.scale.y
		var tip := socket.position.y+tooth.position.y+(-0.325 if upper else 0.325)*tooth.scale.y
		anchored = anchored and absf(base) < 0.001 and socket.position.length() < 0.94
		anchored = anchored and (tip > 0.0 and tip < socket.position.y if upper else tip < 0.0 and tip > socket.position.y)
	check("all fang roots stay embedded at the lip and tips point inward",anchored)
	var query := PhysicsRayQueryParameters3D.create(ghost.position+Vector3(0,0.6,1.5),ghost.position+Vector3(0,0.6,-0.5),CollisionLayers.HITBOXES)
	var hit := room.get_world_3d().direct_space_state.intersect_ray(query)
	check("enlarged upper face remains a real shootable hitbox",not hit.is_empty() and hit.collider == ghost.get_node("TorsoHitbox"))
	await capture("ghost-maw")
	var clock := ghost.visual.visual_time
	ghost.set_physics_process(true)
	get_tree().paused = true
	await frames(10)
	check("pause freezes shroud, mouth and tongue time",ghost.visual.visual_time == clock)
	get_tree().paused = false
	ghost.boon_stunned = true
	await frames(8)
	check("stun freezes animation with the actual ghost",ghost.visual.visual_time == clock)
	ghost.boon_stunned = false
	master._dismiss_wisps()
	await frames(2)
	for side in [-1,1]:
		for end in [-1,1]:
			crawler.position = Vector3(side*9,0.05,end*8)
			crawler.velocity = Vector3.ZERO
			crawler._finish_attack(999)
			player.position = Vector3(side*9,1.25,0)
			crawler.set_physics_process(true)
			for tick in 250:
				await frames(1)
				if crawler.position.y > 1.1 and absf(crawler.position.z) < 2: break
			check("crawler climbs actual slope side=%d end=%d" % [side,end],crawler.position.y > 1.1 and absf(crawler.position.z) < 2)
			if side == 1 and end == 1:
				player.aim_at(crawler.position+Vector3.UP*0.7)
				await capture("crawler-on-balcony")
			var hp := player.health.health
			crawler.attack_cooldown = 0
			for tick in 150:
				await frames(1)
				if player.health.health < hp: break
			check("crawler really damages player above the ramp side=%d end=%d" % [side,end],player.health.health < hp)
			crawler.set_physics_process(false)
	check("crawler has stronger pursuit and shorter recovery without higher damage",crawler.run_speed == 5 and is_equal_approx(crawler.windup(),0.65))
	# Reverse the route: gravity and navigation must also follow the slope down.
	crawler.position = Vector3(9,1.24,0)
	crawler.velocity = Vector3.ZERO
	crawler._finish_attack(999)
	player.position = Vector3(9,0.1,9)
	crawler.set_physics_process(true)
	for tick in 300:
		await frames(1)
		if crawler.position.z > 7: break
	check("crawler can descend from the balcony too",crawler.position.z > 7 and crawler.position.y < 0.5)
	crawler._finish_attack(0)
	var hits := crawler.pounce_hits
	await frames(330)
	check("nearby crawler attacks repeatedly instead of waiting long gaps",crawler.pounce_hits-hits >= 2)
	room.queue_free()
	await frames(3)
	complete = true
