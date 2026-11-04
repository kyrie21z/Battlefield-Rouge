extends Node
## Headless checks for the opening -> zone handoff:
##   godot --headless --path . res://tests/opening_transition_test.tscn

const BOOT := preload("res://ui/game_start.tscn")
const FADE := preload("res://ui/scene_fade.gd")

var _failures := 0
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	get_tree().paused = false
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	await get_tree().process_frame
	await _test_fade()
	await _test_opening_entry()
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


func _test_opening_entry() -> void:
	print("== opening path")
	RunState.clear_fixture()
	RunState.start_new_run()
	get_tree().paused = false
	var path := RunState.zone_scene()
	var boot := BOOT.instantiate()
	get_tree().root.add_child(boot)
	get_tree().current_scene = boot
	_check("the opening starts a threaded warm-up for the first zone",
		boot._zone_path == path and boot._preload_active
		and not boot._preload_path.is_empty()
		and ResourceLoader.load_threaded_get_status(boot._preload_path)
		!= ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	_check("the warm-up loads the zone's own dependencies first",
		boot._preload_path in ResourceLoader.get_dependencies(path))
	_check("the opening, not a zone, owns the screen during the load",
		is_instance_valid(boot.opening) and get_tree().current_scene == boot)

	boot.opening.combat_entry_requested.emit()
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
	if black and is_instance_valid(boot) and not boot._preload_done:
		var showing_label := func() -> bool:
			var overlays := _fade_nodes()
			return not overlays.is_empty() and overlays[0].is_loading()
		var showing := await _wait_for(showing_label, 5000)
		_check("it shows the loading hint while the warm-up is still running", showing)

	var switched := false
	deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == path:
			switched = true
			break
		await get_tree().process_frame
	_check("the zone becomes the current scene", switched)
	var covered := _fade_nodes()
	_check("the fade survives the scene change and stays black for the warm-up",
		covered.size() == 1 and covered[0].is_black())
	var gone := await _wait_for(func() -> bool: return _fade_nodes().is_empty())
	_check("the overlay fades out on its own and frees itself", gone)
	_check("the zone is still current after the fade", get_tree().current_scene != null
		and get_tree().current_scene.scene_file_path == path)
	await _close_current_scene()


func _test_fixture_entry() -> void:
	print("== fixture path")
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
	_check("the fixture path still enters the zone synchronously", switched)
	_check("it never creates a fade overlay", not overlay_seen and _fade_nodes().is_empty())
	await _close_current_scene()
	RunState.clear_fixture()


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
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
