extends Node
## Actual Fear campaign, physical bridge route, gate input, fatal fall and retry.
var checks := 0
var failures := 0
var output := ""

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func choose(stage: RealmStage) -> void:
	if not is_instance_valid(stage.selection): return
	var picker := stage.selection
	if picker._offered.is_empty(): picker._skip_empty()
	else:
		picker._choose(picker._offered[0])
		picker.confirm_replacement(true)
	await frames(2)

func stop_attacks(stage: RealmStage) -> void:
	for enemy in stage.enemies: enemy.set_physics_process(false)
	# Scripted walking/aiming must not be rotated by the real desktop mouse.
	stage.player.set_process_unhandled_input(false)
	stage.player.health.invulnerable = true

func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await get_tree().create_timer(0.7,true,false,true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check("native capture " + name,get_viewport().get_texture().get_image().save_png(output.path_join(name+".png")) == OK)

func walk_to_gate(stage: RealmStage) -> void:
	stage.player.rotation.y = 0
	stage.player._pitch = 0
	stage.player._visual_kick = Vector2.ZERO
	stage.player._apply_look()
	var approach_z := stage.gate.position.z + 1.9
	Input.action_press("move_forward")
	for tick in 780:
		if stage.player.position.z <= approach_z or stage.fallen: break
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await frames(2)
	check("real Player walks across Fear bridges to reachable gate",not stage.fallen and stage.player.position.z < approach_z + 0.1 and stage.player.position.y > -1)
	if stage.player.position.z >= approach_z + 0.1: print("WALK STOP: ",stage.player.position)

func interact() -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	event = InputEventAction.new()
	event.action = &"interact"
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func wait_stage(previous: Node) -> void:
	for frame in 600:
		if is_instance_valid(RunDirector.current_stage) and RunDirector.current_stage != previous: return
		await get_tree().process_frame

func _ready() -> void:
	# the realm intro panel is a UI concern; these tests only care about the flow
	MetaProgression.introduced_realms.assign([0,1,2,3])
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	await get_tree().process_frame
	get_tree().current_scene = null
	RunDirector.randomize_realm_order = false
	RunDirector.begin_run(19140)
	check("explicit Fear diagnostic route keeps its focused order",RunDirector.order == [1,0,2,3] and RunDirector.scene_path().ends_with("fear_1.tscn"))
	check("actual first Fear stage installs",RunDirector.install_stage(load(RunDirector.scene_path())) == OK)
	for room in 3:
		await frames(8)
		var stage := RunDirector.current_stage as RealmStage
		if stage == null:
			check("campaign stage remains available",false)
			break
		stop_attacks(stage)
		await choose(stage)
		check("Fear room %d retains intended progression" % room,stage.realm == 1 and stage.room_index == room and not stage.request_exit())
		for enemy in stage.enemies:
			enemy.health.apply_damage(100000,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
		await frames(4)
		if not stage.boss_room:
			if stage.orb_pending():
				stage.claim_talent()
				for _f in 4:
					await get_tree().physics_frame
			check("clear offers reward before gate unlock",stage.cleared and is_instance_valid(stage.selection) and not stage.exit_ready)
			await choose(stage)
			check("all convex fragment shapes were prepared before combat",FearShatter._collision_shapes.size() == 56)
			var bursts: Array[FearShatter] = []
			for child in stage.get_children():
				if child is FearShatter: bursts.append(child)
			check("deaths share immutable collision shapes with independent bodies",bursts.size() >= 2 and bursts[0].pieces[0] != bursts[1].pieces[0] and bursts[0].pieces[0].get_child(1).shape == bursts[1].pieces[0].get_child(1).shape)
		else:
			check("Fear boss requires real shard before next realm",is_instance_valid(stage.shard) and not stage.exit_ready)
			if is_instance_valid(stage.shard): stage.player.position = stage.shard.position
			await frames(5)
		check("reward or shard reveals explicit next-room portal",stage.exit_ready and stage._gate_label.text.contains("下一关"))
		if room == 0: await capture("exit-guide")
		await walk_to_gate(stage)
		await capture("gate-room-%d" % room)
		check("HUD marks unlocked portal and interaction",stage.hud._exit_hint.visible and stage.hud._exit_hint.text.contains("进入"))
		await interact()
		await wait_stage(stage)
		check("real interaction advances room without teleporting to gate",RunDirector.current_stage != stage)
	await frames(8)
	var next := RunDirector.current_stage as RealmStage
	check("third Fear exit loads Sloth next with Fear shard retained",is_instance_valid(next) and next.realm == 0 and next.player.fragments.has_shard(1))
	await capture("next-realm")
	# Fall outside the finite Area: actual gravity must still kill through shields.
	RunDirector.begin_run(19141)
	RunDirector.install_stage(load(RunDirector.scene_path()))
	await frames(8)
	var falling := RunDirector.current_stage as RealmStage
	stop_attacks(falling)
	await choose(falling)
	falling.player.health.dash_invulnerable = true
	falling.player.health.grant_shield(500)
	falling.player.health.lethal_guard = func(_context): return 100.0
	var before_fall := falling.player.health.health
	falling.player.position = Vector3(130,3,0)
	for tick in 180:
		if falling.player.health.health < before_fall: break
		await get_tree().physics_frame
	await frames(3)
	check("Area-external fall costs exactly thirty HP despite immunity and shield",not falling.fallen and is_equal_approx(falling.player.health.health,before_fall-30) and falling.player.position.y > -1)
	await frames(45)
	check("one fall cannot charge repeated HP penalties",is_equal_approx(falling.player.health.health,before_fall-30))
	await capture("fall-recovered")
	falling.player.health.health = 25
	falling.player.position = Vector3(130,3,0)
	for tick in 180:
		if falling.fallen: break
		await get_tree().physics_frame
	await frames(3)
	check("insufficient HP still records one genuine abyss death",falling.fallen and falling.player.health.is_dead() and RunDirector.last_death_cause == &"abyss")
	check("fatal fall displays clear death and retry feedback",falling.hud._death_panel.visible and falling.hud._death_reason.text.contains("坠入深渊"))
	await capture("fatal-fall")
	falling.hud._death_panel.get_child(0).get_child(1).pressed.emit()
	for frame in 900:
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.scene_file_path == "res://ui/game_start.tscn":
			var forge := scene.get_node_or_null("CrownForge") as CrownForge
			if is_instance_valid(forge): forge.close()
		if is_instance_valid(RunDirector.current_stage) and RunDirector.current_stage != falling: break
		await get_tree().process_frame
	check("death button restarts the explicit Fear diagnostic route",is_instance_valid(RunDirector.current_stage) and RunDirector.current_stage != falling and RunDirector.scene_path().ends_with("fear_1.tscn") and not RunDirector._dead)
	get_tree().paused = false
	if is_instance_valid(RunDirector.current_stage): RunDirector.current_stage.queue_free()
	RunDirector.current_stage = null
	get_tree().current_scene = null
	RunDirector.active = false
	await frames(3)
	OS.delay_msec(250)
	print("FEAR PLAYTEST: %s (%d checks, %d failures)" % ["ALL PASSED" if failures == 0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
