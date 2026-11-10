extends Node
## Headless checks for the opening -> campaign handoff and isolated fixture entry:
##   godot --headless --path . res://tests/opening_transition_test.tscn

const BOOT := preload("res://ui/game_start.tscn")
const FADE := preload("res://ui/scene_fade.gd")
const FAILING_BOOT := preload("res://tests/support/failing_game_start.gd")

var _checks := 0
var _failures := 0
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	get_tree().paused = false
	var ok := _failures == 0 and _finished
	print("%s (%d checks, %d failed%s)" % ["ALL PASSED" if ok else "FAIL", _checks, _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	await get_tree().process_frame
	_check("the registered store isolates transition tests from the real save",
		MetaProgression.isolated_profile and MetaProgression.save_path() != MetaProgression.SAVE_PATH)
	await _test_fade()
	await _test_opening_entry()
	for empty_scene in [false, true]:
		await _test_loading_failure_retry(empty_scene)
	await _test_fixture_entry()
	_finished = true


func _test_fade() -> void:
	print("== scene fade")
	var fade: SceneFade = FADE.new()
	get_tree().root.add_child(fade)
	await _frames(1)
	_check("the overlay sits on layer 100 and runs while paused",
		fade.layer == 100 and fade.process_mode == Node.PROCESS_MODE_ALWAYS)
	_check("it starts transparent and never takes input",
		fade.alpha() <= 0.001 and fade._rect.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and fade._label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("it covers the whole viewport",
		fade._rect.size.is_equal_approx(get_viewport().get_visible_rect().size))
	fade.fade_to_black(0.05)
	var black := await _wait_for(func() -> bool: return fade.is_black())
	_check("it fades to black", black and fade.alpha() >= 0.999)
	fade.show_loading()
	_check("the loading label is centred, readable and says 加载中…",
		fade.is_loading() and fade._label.text == "加载中…"
		and fade._label.get_theme_font_size("font_size") >= 28
		and fade._label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	await _frames(20)
	_check("it stays black and keeps the hint up while loading",
		fade.is_black() and fade.is_loading())
	get_tree().paused = true
	fade.reveal(3, 0.05)
	var freed := await _wait_for(func() -> bool: return _fade_nodes().is_empty())
	get_tree().paused = false
	_check("a paused tree still fades out and frees the overlay", freed)
	await _frames(2)


func _start_campaign() -> void:
	RunState.clear_fixture()
	RunState.start_new_run()
	# Each route exercises the first-run cinematic in this process-local test profile.
	# Real later runs still skip it and are covered by opening_boot/meta_campaign.
	RunDirector.run_count = 0
	RunDirector.begin_run(146001)
	get_tree().paused = false


func _test_opening_entry() -> void:
	print("== opening path")
	_start_campaign()
	var path := RunDirector.scene_path()
	var boot := BOOT.instantiate()
	get_tree().root.add_child(boot)
	get_tree().current_scene = boot
	_check("the opening records its destination without loading the zone",
		boot._zone_path == path and boot._packed == null)
	_check("the opening starts no background request for the zone",
		ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	_check("only the opening owns the screen before departure",
		is_instance_valid(boot.opening) and get_tree().current_scene == boot)
	await _frames(5)
	_check("reading the opening leaves the zone unloaded and starts no threaded work",
		boot._packed == null
		and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)

	boot.opening.combat_entry_requested.emit()
	await _close_starting_forge(boot)
	var black := false
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var overlays := _fade_nodes()
		if not overlays.is_empty() and overlays[0].is_black():
			black = true
			break
		if not is_instance_valid(boot):
			break
		await get_tree().process_frame
	_check("entering from the opening fades to black first", black)
	var switched := false
	var loading_frames := 0
	deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		var overlays := _fade_nodes()
		if not overlays.is_empty() and overlays[0].is_loading():
			loading_frames += 1
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == path:
			switched = true
			break
		await get_tree().process_frame
	_check("the loading hint is presented before synchronous scene loading", loading_frames >= 2)
	_check("the campaign stage becomes the current scene", switched
		and get_tree().current_scene == RunDirector.current_stage)
	var covered := _fade_nodes()
	_check("the fade survives the scene change and covers its first frames",
		covered.size() == 1 and covered[0].is_black())
	var gone := await _wait_for(func() -> bool: return _fade_nodes().is_empty())
	_check("the overlay fades out on its own and frees itself", gone)
	_check("the zone is still current after the fade", get_tree().current_scene != null
		and get_tree().current_scene.scene_file_path == path)
	await _close_current_scene()


func _test_loading_failure_retry(empty_scene: bool) -> void:
	print("== loading %s failure and retry" % ["empty scene" if empty_scene else "missing resource"])
	_start_campaign()
	var path := RunDirector.scene_path()
	var original_seed := RunDirector.run_seed
	# Run the actual error/retry flow for both a missing resource and a resource
	# that loads but cannot instantiate. Avoid preloading a combat class.
	var observations := {"attempts": 0, "loading_visible": [], "empty_scene": empty_scene}
	var boot := FAILING_BOOT.new()
	boot.observations = observations
	get_tree().root.add_child(boot)
	get_tree().current_scene = boot
	boot.opening.combat_entry_requested.emit()
	boot._enter_game()
	await _close_starting_forge(boot)
	var failed := await _wait_for(func() -> bool:
		return observations["attempts"] == 1 and not boot._load_requested, 5000)
	_check("the failed read finishes and duplicate entry does not start another load", failed)
	if not failed:
		await _close_current_scene()
		for overlay in _fade_nodes():
			overlay.discard()
		await _frames(2)
		return
	var overlays := _fade_nodes()
	_check("failure keeps a single black overlay over the opening", overlays.size() == 1
		and overlays[0].is_black() and get_tree().current_scene == boot)
	if overlays.is_empty():
		await _close_current_scene()
		return
	var fade: SceneFade = overlays[0]
	_check("failure replaces the loading hint with an available retry button",
		not fade.is_loading() and not fade._label.visible
		and fade._retry_button.is_visible_in_tree() and not fade._retry_button.disabled)
	_check("failure also offers a visible exit button",
		fade._quit_button.is_visible_in_tree() and not fade._quit_button.disabled)
	if not empty_scene:
		await _capture_loading_error()
	_check("the actual resource read follows the loading hint", observations["loading_visible"] == [true])
	_check("failed entry leaves run state intact and releases its guard",
		RunDirector.run_seed == original_seed and RunDirector.boons.is_empty()
		and RunDirector.selections.is_empty() and not boot._load_requested)
	await _frames(3)
	_check("failure waits for the player without automatically retrying", observations["attempts"] == 1)
	# Use the real error button, not a second call to the private entry path.
	fade._retry_button.pressed.emit()
	fade._retry_button.pressed.emit()
	var switched := await _wait_for(func() -> bool:
		var current := get_tree().current_scene
		return current != null and current.scene_file_path == path, 30000)
	_check("the retry button successfully enters the intended zone", switched)
	_check("repeated retry input starts just one further read", observations["attempts"] == 2)
	_check("every read presents the loading hint first", observations["loading_visible"] == [true, true])
	var gone := await _wait_for(func() -> bool: return _fade_nodes().is_empty(), 5000)
	_check("successful retry removes the error and fade overlays", gone)
	_check("successful retry preserves the seed and initial selection state",
		RunDirector.run_seed == original_seed and RunDirector.boons.is_empty()
		and RunDirector.selections.is_empty())
	await _close_current_scene()


func _close_starting_forge(boot: Node) -> void:
	var offered := await _wait_for(func() -> bool:
		return is_instance_valid(boot.forge), 5000)
	_check("departure offers the real Forge before loading the first room", offered)
	if not offered:
		return
	var forge: CrownForge = boot.forge
	_check("the Forge pauses the opening without starting a resource read or fade",
		get_tree().paused and boot._packed == null and _fade_nodes().is_empty()
		and get_tree().current_scene == boot and RunDirector.current_stage == null)
	boot._enter_game()
	_check("repeated departure input leaves exactly one Forge awaiting the player",
		boot.forge == forge and boot.find_children("CrownForge", "", false, false).size() == 1)
	forge.close()
	_check("closing the real Forge prepares departure exactly once",
		RunDirector.forge_visited and RunDirector._departure_prepared)


func _test_fixture_entry() -> void:
	print("== fixture path")
	RunDirector.active = false
	RunState.start_fixture(RunFixture.by_id("FX-001"))
	get_tree().paused = false
	var path := RunState.zone_scene()
	var boot := BOOT.instantiate()
	get_tree().root.add_child(boot)
	get_tree().current_scene = boot
	_check("the fixture path starts no background load", boot._zone_path.is_empty())
	_check("and creates no fade overlay", _fade_nodes().is_empty())
	var switched := false
	var overlay_seen := false
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		overlay_seen = overlay_seen or not _fade_nodes().is_empty()
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == path:
			switched = true
			break
		await get_tree().process_frame
	_check("the fixture path still enters the zone synchronously", switched and not RunDirector.active)
	_check("it never creates a fade overlay", not overlay_seen and _fade_nodes().is_empty())
	await _close_current_scene()
	RunState.clear_fixture()


func _capture_loading_error() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--error-proof="):
			var output := argument.trim_prefix("--error-proof=")
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			_check("saved the real retry and exit screen", frame.save_jpg(output.path_join("load-error.jpg"), 0.82) == OK)


func _close_current_scene() -> void:
	get_tree().paused = false
	var current := get_tree().current_scene
	get_tree().current_scene = null
	if is_instance_valid(current):
		current.queue_free()
	await _frames(2)


func _fade_nodes() -> Array:
	var found := []
	for child in get_tree().root.get_children():
		if child is SceneFade:
			found.append(child)
	return found


func _wait_for(condition: Callable, timeout_ms: int = 30000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	return false


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
