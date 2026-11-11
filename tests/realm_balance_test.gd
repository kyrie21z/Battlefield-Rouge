extends Node
var checks := 0
var failures := 0
var output := ""
var sections := 0

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check("native capture "+name,get_viewport().get_texture().get_image().save_png(output.path_join(name+".png")) == OK)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	await _wrath()
	await _sorrow()
	check("both production realm scenarios finish",sections == 2)
	await get_tree().process_frame
	# Fixed-FPS tests advance timers faster than the audio server's stop queue.
	OS.delay_msec(250)
	print("REALM BALANCE: %s (%d checks, %d failures)" % ["ALL PASSED" if failures == 0 else "FAIL",checks,failures])
	get_tree().quit.call_deferred(0 if failures == 0 else 1)

func _wrath() -> void:
	var stage := load("res://maps/realms/wrath_boss.tscn").instantiate() as RealmStage
	add_child(stage)
	var boss := stage.boss as WrathSpire
	var player := stage.player
	player.set_physics_process(false)
	player.dash.set_physics_process(false)
	player.health.max_health = 200
	player.health.health = 200
	player.aim_at(boss.global_position+Vector3.UP*2)
	boss.begin_move(WrathSpire.Move.VOLLEY)
	var bullets := boss.spawned_bullets
	var hp := player.health.health
	await frames(20)
	check("ranged volley has a real locked windup before any shot",boss.spawned_bullets == bullets and is_instance_valid(boss._aim_tell))
	var deadline := boss.attack_left
	get_tree().paused = true
	await frames(4)
	check("pause freezes new ranged windup",boss.attack_left == deadline)
	get_tree().paused = false
	await frames(65)
	await capture("wrath-volley")
	await frames(90)
	check("three aimed fans launch fifteen actual ricochets",boss.spawned_bullets-bullets == 15)
	check("ranged fan deals real damage to a distant player",player.health.health < hp)
	check("ranged attack retains a full punish recovery",boss.attack_phase == WrathRealmEnemy.Attack.RECOVER)
	boss.set_physics_process(false)
	boss._clear_bullets()
	await frames(3)
	player.position = boss.global_position+Vector3(0,0,18)
	boss.begin_move(WrathSpire.Move.VORTEX)
	check("distant player replaces wasted melee charge with ranged pressure",boss.move_kind == WrathSpire.Move.VOLLEY)
	var aim := boss._locked_aim
	player.position.x += 5
	await frames(3)
	check("volley locks direction rather than tracking after its tell",boss._locked_aim.is_equal_approx(aim))
	boss._clear_bullets()
	player.position = Vector3(0,0.02,10)
	player.aim_at(boss.global_position+Vector3.UP*2)
	var eruptions := boss.spawned_eruptions
	boss.begin_move(WrathSpire.Move.ERUPTION)
	await frames(5)
	check("eruption lays three distinct locked ground warnings",boss.spawned_eruptions-eruptions == 3)
	# An elevated review camera shows all three real ground markers together.
	var review := Camera3D.new()
	stage.add_child(review)
	review.global_position = Vector3(12,13,19)
	review.look_at(Vector3(0,0,10))
	review.make_current()
	await capture("wrath-eruption-warning")
	player.view_camera.make_current()
	review.queue_free()
	var hazards: Array[SpireEruption] = []
	for node in stage.get_children():
		if node is SpireEruption: hazards.append(node)
	var time := hazards[0].elapsed
	boss.boon_time_scale = 0
	await frames(8)
	check("local time stop also freezes eruption warnings",hazards[0].elapsed == time)
	boss.boon_time_scale = 1
	boss.warnings_enabled = false
	await frames(2)
	check("Fear deprivation hides warnings while preserving the attack",not hazards[0].marker.visible and not hazards[0].released)
	boss.warnings_enabled = true
	hp = player.health.health
	player.set_physics_process(true)
	await frames(45)
	var grounded := player.is_on_floor()
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	var peak := 0.0
	for tick in 24:
		await get_tree().physics_frame
		peak = maxf(peak,player.position.y)
	check("actual default jump avoids the ground eruption at its release",grounded and peak > 0.45 and player.health.health == hp)
	player.set_physics_process(false)
	await frames(40)
	player.position = Vector3(0,0.02,10)
	boss.begin_move(WrathSpire.Move.ERUPTION)
	await frames(80)
	check("standing inside the locked eruption takes eighteen HP once",is_equal_approx(hp-player.health.health,18))
	await frames(35)
	check("eruption cannot keep damaging after its single release",is_equal_approx(hp-player.health.health,18))
	# A real wall separates a blast origin from a target still inside its radius.
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2,3,3)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0.6,1.5,10)
	stage.add_child(wall)
	player.position = Vector3(1.2,0.02,10)
	var covered := SpireEruption.new()
	covered.source = boss
	covered.target = player
	covered.warning_seconds = 0.05
	covered.position = Vector3(0,0,10)
	stage.add_child(covered)
	hp = player.health.health
	await frames(8)
	check("WORLD cover blocks eruption damage inside the nominal radius",player.health.health == hp and not covered.hit_player)
	wall.queue_free()
	covered.queue_free()
	boss.begin_move(WrathSpire.Move.ERUPTION)
	boss.set_physics_process(true)
	player.health.apply_damage(100000,Hitbox.BodyPart.BODY,null,{"true_damage":true})
	await frames(3)
	check("target death stops pending ranged attacks immediately",boss._owned_bullets.is_empty() and not stage.get_children().any(func(node): return node is SpireEruption))
	boss.health.apply_damage(100000,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	await frames(3)
	check("boss death removes every owned pending projectile and eruption",boss._owned_bullets.is_empty() and not stage.get_children().any(func(node): return node is SpireEruption))
	stage.queue_free()
	await frames(3)
	sections += 1

func _sorrow() -> void:
	var stage := load("res://maps/realms/sorrow_1.tscn").instantiate() as RealmStage
	add_child(stage)
	var player := stage.player
	player.set_physics_process(false)
	player.dash.set_physics_process(false)
	for enemy in stage.enemies: enemy.set_physics_process(false)
	var mourner := stage.enemies[2] as SorrowRealmEnemy
	player.position = mourner.position+Vector3(0,0,8)
	player.aim_at(mourner.global_position+Vector3.UP)
	mourner.release_cry()
	var cry: SorrowCry
	for node in stage.get_children():
		if node is SorrowCry: cry = node
	await frames(20)
	var material := cry.ring.material_override as StandardMaterial3D
	check("actual Mourner expanding wave is blue in both color and emission",material.albedo_color == SorrowCry.WAVE_BLUE and material.emission == SorrowCry.WAVE_BLUE)
	check("attack blue is independent of warm scene lighting",material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
	await capture("sorrow-blue-wave")
	await frames(30)
	check("blue wave retains its actual debuff on contact",player.realm_effects.monochrome > 0)
	var tide := SorrowTide.new()
	tide.source = mourner
	stage.add_child(tide)
	check("boss tide uses the same blue family",(tide.ring.material_override as StandardMaterial3D).albedo_color == SorrowCry.WAVE_BLUE)
	stage.queue_free()
	await frames(3)
	sections += 1
