extends Node
const BOOT := "res://ui/game_start.tscn"
var checks := 0
var failures := 0
var directors_loaded := 0
var elapsed := 0.0
var output := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--opening-proof="):
			output = arg.trim_prefix("--opening-proof=")
	get_tree().node_added.connect(_node_added)
	_run.call_deferred()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 65.0:
		push_error("Opening integration timed out")
		get_tree().quit(1)

func _node_added(node: Node) -> void:
	if node is ZoneDirector: directors_loaded += 1

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _key(code: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	Input.parse_input_event(up)
	await get_tree().process_frame

func _run() -> void:
	await get_tree().process_frame
	for route in ["confirm", "skip"]:
		RunState.clear_fixture()
		RunState.start_new_run()
		var original_seed := RunState.run_seed
		get_tree().paused = false
		directors_loaded = 0
		get_tree().change_scene_to_file(BOOT)
		await get_tree().scene_changed
		await get_tree().process_frame
		var boot := get_tree().current_scene
		var opening: Node3D = boot.opening
		opening.proof = true
		opening.proof_wait = -10000
		_check(opening.flow.state == opening.Flow.State.CINEMATIC, route + ": auto-plays on normal startup")
		_check(get_tree().get_nodes_in_group("player").is_empty() and directors_loaded == 0, "No combat scene runs behind the intro")
		var area := get_viewport().get_visible_rect().size
		_check(is_equal_approx(opening.ui.scale.x, minf(area.x / 1280, area.y / 720)), "Opening UI fits the game canvas")
		if route == "confirm":
			for i in range(5):
				await _key(KEY_ENTER)
				if i == 2: await _capture("01-integrated-opening.jpg")
			opening.flow.observe()
			await get_tree().process_frame
			await _key(KEY_E)
		else:
			opening.skip_button.pressed.emit()
		_check(opening.flow.state == opening.Flow.State.DECISION, route + ": clear departure choice")
		opening.panels.decision.get_child(2).pressed.emit()
		await get_tree().scene_changed
		await get_tree().process_frame
		_check(get_tree().current_scene.scene_file_path == RunState.ZONE_SCENES[0], "Loads the original zone_1 scene")
		_check(directors_loaded == 1, "Loads exactly one real zone")
		_check(RunState.run_seed == original_seed and RunState.buffs.is_empty() and RunState.selection_history.is_empty(), "Opening preserves the original new-run state")
		var director := get_tree().get_first_node_in_group("zone_director") as ZoneDirector
		_check(director.selection_context == "enter" and director.selection_count == 1 and get_tree().paused, "Original entry buff choice still opens once")
		await _key(KEY_1)
		_check(not get_tree().paused and RunState.buffs.size() == 1 and RunState.selection_history.size() == 1, "Entry choice starts the original combat")
		var player := get_tree().get_first_node_in_group("player") as Player
		_check(player.weapon.data_set.size() == 1 and is_instance_valid(player.melee) and is_instance_valid(player.shield), "Pistol, legacy melee and shield remain available")
		if route == "confirm": await _capture("02-existing-game-after-opening.jpg")
		player.health.apply_damage(99999, Hitbox.BodyPart.BODY)
		await get_tree().process_frame
		var end_screen: Node
		for child in director.get_children():
			if child.has_signal("restart_pressed"): end_screen = child
		_check(is_instance_valid(end_screen), "Original death screen is shown")
		end_screen._on_restart()
		await get_tree().scene_changed
		await get_tree().process_frame
		_check(get_tree().current_scene.scene_file_path == RunState.ZONE_SCENES[0], "Death restarts the old game without replaying the opening")
	for fixture_id in ["FX-001", "FX-002"]:
		var fixture := RunFixture.by_id(fixture_id)
		RunState.start_fixture(fixture)
		get_tree().paused = false
		directors_loaded = 0
		get_tree().change_scene_to_file(BOOT)
		await get_tree().scene_changed
		if fixture.start_zone != 0:
			# Reproduce RunState winning the normal CLI startup before the
			# boot's already-queued callback. The detached boot must do nothing.
			RunState._start_fixture_zone()
		await get_tree().scene_changed
		await get_tree().process_frame
		_check(get_tree().current_scene.scene_file_path == RunState.zone_scene(), fixture_id + ": bypasses the opening")
		_check(directors_loaded == 1 and RunState.run_seed == fixture.run_seed, fixture_id + ": single zone, original seed")
		var director := get_tree().get_first_node_in_group("zone_director") as ZoneDirector
		_check((director.selection_context == "enter") == (fixture.start_zone == 0), fixture_id + ": original entry rules")
	get_tree().paused = false
	get_tree().current_scene.queue_free()
	get_tree().current_scene = null
	await get_tree().process_frame
	print("OPENING BOOT: ", checks, " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func _capture(filename: String) -> void:
	if output.is_empty(): return
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	var image := get_viewport().get_texture().get_image()
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	_check(image.save_jpg(output.path_join(filename), 0.82) == OK, "Saved native proof " + filename)
