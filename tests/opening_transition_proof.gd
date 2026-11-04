extends Node
## Native-window timing proof for the opening -> zone handoff:
##   godot --path . res://tests/opening_transition_proof.tscn -- [--old] [--out=<dir>]
## Default mode plays the real opening for 8 s, then fades and loads.
## --old skips the opening and fade and does the direct synchronous
## change_scene_to_file, to compare the entry cost in a separate process.
## Needs a real display (the screenshots are the point).

const BOOT := "res://ui/game_start.tscn"
const WATCH_USEC := 8_000_000
const LIMIT_MSEC := 60_000

var _out_dir := "res://docs/proof/opening-transition"
var _old := false
var _measuring := false
## Wall-clock gap between process frames. Engine deltas are clamped, so a
## synchronous multi-second load would not show up in them.
var _max_gap_ms := 0.0
var _last_frame_usec := 0


func _ready() -> void:
	if get_tree().current_scene == self:
		# The proof must outlive the scene changes it drives.
		var session := Node.new()
		session.set_script(get_script())
		session.process_mode = Node.PROCESS_MODE_ALWAYS
		session.name = "OpeningTransitionProofSession"
		get_tree().root.add_child.call_deferred(session)
		get_tree().current_scene = null
		queue_free()
		return
	_start()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _measuring and _last_frame_usec > 0:
		_max_gap_ms = maxf(_max_gap_ms, (now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now


func _start() -> void:
	_parse_args()
	if DisplayServer.get_name() == "headless":
		push_error("opening transition proof needs a native display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame
	RunState.clear_fixture()
	RunState.start_new_run()
	get_tree().paused = false
	if _old:
		await _run_old()
	else:
		await _run_new()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--old":
			_old = true
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)


func _run_new() -> void:
	var path := RunState.zone_scene()
	get_tree().change_scene_to_file(BOOT)
	await get_tree().scene_changed
	await get_tree().process_frame
	var boot := get_tree().current_scene
	if boot == null or not is_instance_valid(boot.opening):
		push_error("the opening did not start")
		get_tree().quit(1)
		return

	# Watch the opening without starting a background scene/script request.
	var watch_start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - watch_start < WATCH_USEC:
		await get_tree().process_frame
	print("TIMING mode=new watched_ms=8000 background_zone_load=false")

	_begin_measuring()
	var t0 := Time.get_ticks_usec()
	boot._enter_game()
	var deadline := Time.get_ticks_msec() + LIMIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == path:
			break
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var first_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("TIMING mode=new entry_to_zone_first_frame_ms=%.1f" % first_ms)

	var mid_ms := -1.0
	deadline = Time.get_ticks_msec() + LIMIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var overlay := _find_fade()
		if overlay == null:
			break
		var alpha: float = overlay.alpha()
		if alpha > 0.15 and alpha < 0.85:
			await _capture("01-mid-fade.jpg")
			mid_ms = (Time.get_ticks_usec() - t0) / 1000.0
			break
		await get_tree().process_frame
	print("TIMING mode=new mid_fade_captured_ms=%.1f" % mid_ms)

	var gone := false
	deadline = Time.get_ticks_msec() + LIMIT_MSEC
	while Time.get_ticks_msec() < deadline:
		if _find_fade() == null:
			gone = true
			break
		await get_tree().process_frame
	var kept := _check_current(path)
	await _frames(8)
	await _capture("02-game-visible.jpg")
	_measuring = false
	print("TIMING mode=new overlay_gone=%s" % gone)
	print("TIMING mode=new longest_frame_during_switch_ms=%.1f" % _max_gap_ms)
	print("SHOT start=%s" % _out_dir)
	get_tree().quit(0 if gone and kept else 1)


func _run_old() -> void:
	# Old entry: no opening warm-up and no preload. The zone loads synchronously
	# inside change_scene_to_file, then the deferred switch shows its first frame.
	var path := RunState.zone_scene()
	_begin_measuring()
	var t0 := Time.get_ticks_usec()
	get_tree().change_scene_to_file(path)
	var deadline := Time.get_ticks_msec() + LIMIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == path:
			break
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var first_ms := (Time.get_ticks_usec() - t0) / 1000.0
	await _frames(8)
	_measuring = false
	print("TIMING mode=old entry_to_zone_first_frame_ms=%.1f" % first_ms)
	print("TIMING mode=old longest_frame_during_switch_ms=%.1f" % _max_gap_ms)
	get_tree().quit(0)


## Resets the gap baseline here: the coroutine resumes on process_frame, before
## this frame's _process, so the first gap must be measured from now.
func _begin_measuring() -> void:
	_max_gap_ms = 0.0
	_last_frame_usec = Time.get_ticks_usec()
	_measuring = true


func _find_fade() -> SceneFade:
	for child in get_tree().root.get_children():
		if child is SceneFade:
			return child
	return null


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_jpg(_out_dir.path_join(name), 0.88)
	print("SHOT %s result=%d bytes=%d" % [_out_dir.path_join(name), result, image.get_data().size()])


func _check_current(path: String) -> bool:
	var current := get_tree().current_scene
	if current == null or current.scene_file_path != path:
		push_error("the zone did not stay current")
		return false
	return true


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
