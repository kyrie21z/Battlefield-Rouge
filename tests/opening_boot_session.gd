extends Node
## Real GameStart -> authored first-person sequence -> current shuffled RealmStage.
## Also retains the two legacy fixture entry routes, isolated from the campaign.
const BOOT := "res://ui/game_start.tscn"
var checks := 0
var failures := 0
var output := ""
var route_filter := ""
var elapsed := 0.0
var longest_frame_ms := 0
var last_tick := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--opening-proof="): output = arg.trim_prefix("--opening-proof=")
		elif arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		elif arg.begins_with("--route="): route_filter = arg.trim_prefix("--route=")
	_run.call_deferred()
func _process(delta: float) -> void:
	elapsed += delta
	var now := Time.get_ticks_msec()
	if last_tick > 0: longest_frame_ms = maxi(longest_frame_ms, now - last_tick)
	last_tick = now
	if elapsed > 180:
		push_error("Opening integration timed out")
		get_tree().quit(1)
func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
func _run() -> void:
	var routes := ["confirm", "skip"] if route_filter.is_empty() else [route_filter]
	for route in routes:
		RunState.clear_fixture()
		RunState.start_new_run()
		RunDirector.run_count = 0
		RunDirector.begin_run(50897)
		var seed_before := RunDirector.run_seed
		var target := RunDirector.scene_path()
		check(route + ": target realm starts cold", not ResourceLoader.has_cached(target) if route == routes[0] else true)
		get_tree().change_scene_to_file(BOOT)
		await get_tree().scene_changed
		await get_tree().process_frame
		var opening: OpeningSequence = get_tree().current_scene.opening
		opening.set_process(false)
		check("first normal entry starts reality blackout", opening.phase == OpeningSequence.Phase.FALL)
		check("only the cinematic Player exists before battle", get_tree().get_nodes_in_group("player").size() == 1 and get_tree().get_nodes_in_group("enemy").is_empty())
		if route == "confirm":
			while opening.phase != OpeningSequence.Phase.PLAYABLE: opening.advance(0.1)
		else:
			opening.skip_button.pressed.emit()
		check(route + ": sequence returns control at an open physical gate", opening.control_released and opening.entry_count == 0)
		await capture(route + "-opening.png")
		opening.player.position.z = -13.2
		opening.advance(0.1)
		while get_tree().current_scene.scene_file_path != target:
			await get_tree().process_frame
		for frame in 4: await get_tree().process_frame
		var stage := get_tree().current_scene
		var stage_id := stage.get_instance_id()
		check("exactly one actual realm is installed", stage == RunDirector.current_stage and get_tree().get_nodes_in_group("player").size() == 1)
		check("opening preserves seed and initial shard/deprivation state", RunDirector.run_seed == seed_before and RunDirector.shards.is_empty() and RunDirector.deprivations.is_empty())
		check("real initial reward UI is offered once", is_instance_valid(stage.selection) and stage._reward_context == "enter")
		stage.selection._buttons[0].pressed.emit()
		await get_tree().process_frame
		var actor: Player = stage.player
		var ammo := actor.weapon.ammo
		check("real pistol fires after the scene handoff", actor.weapon.try_fire() and actor.weapon.ammo == ammo - 1)
		await capture(route + "-combat.png")
		actor.health.apply_damage(99999, Hitbox.BodyPart.BODY)
		await get_tree().process_frame
		check("real death records historical depth and cause", RunDirector._dead and RunDirector.last_death_depth == 1)
		RunDirector.restart()
		await get_tree().scene_changed
		while not is_instance_valid(RunDirector.current_stage) or RunDirector.current_stage.get_instance_id() == stage_id:
			await get_tree().process_frame
		check("death re-entry bypasses the fixed cinematic for dynamic Crown voice", RunDirector.run_count == 2 and get_tree().current_scene.get_node_or_null("OpeningSequence") == null and get_tree().current_scene.get_instance_id() != stage_id)
		get_tree().paused = false
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
		await get_tree().process_frame
	for fixture_id in ["FX-001", "FX-002"]:
		RunDirector.active = false
		RunState.start_fixture(RunFixture.by_id(fixture_id))
		get_tree().change_scene_to_file(BOOT)
		await get_tree().scene_changed
		await get_tree().scene_changed
		check(fixture_id + ": bypasses the new cinematic and campaign", get_tree().current_scene.scene_file_path == RunState.zone_scene() and not RunDirector.active)
		get_tree().paused = false
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
		await get_tree().process_frame
	print("OPENING BOOT: %s (%d checks, longest frame %d ms)" % ["ALL PASSED" if failures == 0 else "FAIL", checks, longest_frame_ms])
	get_tree().quit(0 if failures == 0 else 1)
func capture(filename: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check("save " + filename, get_viewport().get_texture().get_image().save_png(output.path_join(filename)) == OK)
