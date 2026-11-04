extends Node
## One route per fresh engine process. Keep this harness free of gameplay
## script types and preloads: compiling the proof must not warm the battle.
## --route=skip or --route=confirm; headless runs all checks without screenshots.

const ENTRY_PATH := "res://ui/game_start.tscn"
const ZONE_PATH := "res://maps/zone_1.tscn"
const ENTRY_SCRIPT := "res://ui/game_start.gd"
const FADE_SCRIPT := "res://ui/scene_fade.gd"
const DIRECTOR_SCRIPT := "res://zone/zone_director.gd"
const ACTOR_SCRIPT := "res://actors/player/player.gd"
const WATCHDOG_MS := 65000
const MAX_JPEG_BYTES := 150000

var _route := "skip"
var _out := "res://docs/proof/loading-stall"
var _checks := 0
var _failures := 0
var _started_ms := 0
var _last_ms := 0
var _max_gap_ms := 0
var _frame := 0
var _directors_added := 0
var _actors_added := 0
var _confirmed := false
var _early_combat := false
var _loading_observed := false
var _loading_rendered := false
var _loading_saved := false
var _finished := false
var _trace: FileAccess


func _ready() -> void:
	if get_tree().current_scene == self:
		# The observer must survive the exact scene changes used by the game.
		var observer := Node.new()
		observer.set_script(get_script())
		observer.name = "ColdOpeningObserver"
		observer.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(observer)
		get_tree().current_scene = null
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--route="):
			_route = arg.trim_prefix("--route=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _route not in ["skip", "confirm"]:
		push_error("Use --route=skip or --route=confirm")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_trace = FileAccess.open(_out.path_join(_route + "-frames.jsonl"), FileAccess.WRITE)
	_started_ms = Time.get_ticks_msec()
	_last_ms = _started_ms
	get_tree().node_added.connect(_on_node_added)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
		RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _started_ms <= 0 or _finished:
		return
	var now := Time.get_ticks_msec()
	_max_gap_ms = maxi(_max_gap_ms, now - _last_ms)
	_last_ms = now
	_frame += 1
	var scene := get_tree().current_scene
	var boot_path := ""
	var requested := false
	if scene != null and _script_path(scene) == ENTRY_SCRIPT:
		boot_path = str(scene.get("_zone_path"))
		requested = bool(scene.get("_load_requested"))
	var fade := _find_fade()
	var phase := -1
	var alpha := 0.0
	var loading := false
	if fade != null:
		phase = int(fade.get("_phase"))
		alpha = float(fade.call("alpha"))
		loading = bool(fade.call("is_loading"))
		_loading_observed = _loading_observed or loading
	if _trace != null:
		_trace.store_line(JSON.stringify({"frame": _frame, "ms": now - _started_ms,
			"scene": scene.scene_file_path if scene != null else "", "boot_zone_path": boot_path,
			"load_requested": requested, "fade_phase": phase, "fade_alpha": alpha,
			"loading": loading, "loading_rendered": _loading_rendered,
			"directors_added": _directors_added, "actors_added": _actors_added}))
		_trace.flush()
	if now - _started_ms > WATCHDOG_MS:
		_check("65-second cold-entry watchdog", false)
		_finish()


func _run() -> void:
	_check("target battle resource is not cached before normal entry", not ResourceLoader.has_cached(ZONE_PATH))
	_check("entry resource is not preloaded by this observer", not ResourceLoader.has_cached(ENTRY_PATH))
	var result := get_tree().change_scene_to_file(ENTRY_PATH)
	_check("normal entry scene change is accepted", result == OK)
	await get_tree().scene_changed
	await get_tree().process_frame
	var boot: Node = get_tree().current_scene
	var opening: Node = boot.get("opening")
	_check("normal startup reaches the five-line opening", is_instance_valid(opening)
		and int(opening.get("flow").get("state")) == 1)
	if not is_instance_valid(opening):
		_finish()
		return
	_check("battle resource remains cold while the opening is visible", not ResourceLoader.has_cached(ZONE_PATH))
	_check("no combat actor or director runs behind the opening", _actors_added == 0 and _directors_added == 0
		and get_tree().get_nodes_in_group("player").is_empty())
	await _capture("01-opening")
	var flow: Object = opening.get("flow")
	if _route == "skip":
		opening.get("skip_button").emit_signal("pressed")
	else:
		for line in 5:
			_check("dialogue line %d is reached in order" % (line + 1), int(flow.get("step_index")) == line)
			await _key(KEY_ENTER)
	_check("route reaches the explicit departure decision", int(flow.get("state")) == 2)
	_check("decision still has no hidden combat scene", _actors_added == 0 and _directors_added == 0)
	_confirmed = true
	var panels: Dictionary = opening.get("panels")
	var decision: Node = panels["decision"]
	decision.get_child(2).emit_signal("pressed")
	# Repeated confirmation cannot create another accepted handoff.
	decision.get_child(2).emit_signal("pressed")
	while not _finished:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == ZONE_PATH:
			break
		await get_tree().process_frame
	if _finished:
		return
	_check("confirmation enters the actual first battle exactly once", get_tree().current_scene.scene_file_path == ZONE_PATH
		and _directors_added == 1 and _actors_added == 1 and not _early_combat)
	_check("loading state is exposed before the synchronous scene load", _loading_observed)
	if DisplayServer.get_name() != "headless":
		_check("the loading label was actually rendered before the battle", _loading_rendered and _loading_saved)
	while _find_fade() != null and not _finished:
		await get_tree().process_frame
	if _finished:
		return
	var first_scene := get_tree().current_scene
	var first_id := first_scene.get_instance_id()
	var director: Node = first_scene.get_node("ZoneDirector")
	_check("original entry card selection is paused and offered once", get_tree().paused
		and str(director.get("selection_context")) == "enter" and int(director.get("selection_count")) == 1)
	await _key(KEY_1)
	_check("KEY1 chooses the real entry card and starts combat", not get_tree().paused
		and str(director.get("selection_context")).is_empty())
	var actor: Node = get_tree().get_first_node_in_group("player")
	var weapon: Object = actor.get("weapon")
	var ammo_before := int(weapon.get("ammo"))
	var fired := bool(weapon.call("try_fire"))
	_check("a real gun shot succeeds after the cold transition", fired and int(weapon.get("ammo")) == ammo_before - 1)
	await _capture("03-combat-visible")
	# A numeric body slot avoids importing any gameplay enum into this harness.
	actor.get("health").call("apply_damage", 99999.0, 1)
	await get_tree().process_frame
	var end_screen: Node
	for child in director.get_children():
		if child.has_signal("restart_pressed"):
			end_screen = child
	_check("the actual death screen is shown", is_instance_valid(end_screen) and get_tree().paused)
	if not is_instance_valid(end_screen):
		_finish()
		return
	await _key(KEY_R)
	while not _finished:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == ZONE_PATH and current.get_instance_id() != first_id:
			break
		await get_tree().process_frame
	if _finished:
		return
	_check("death restart returns directly to a new first battle", get_tree().current_scene.scene_file_path == ZONE_PATH
		and _directors_added == 2 and _actors_added == 2 and _find_opening(get_tree().root) == null)
	print("COLD TIMING route=%s elapsed_ms=%d longest_frame_ms=%d frames=%d" % [_route,
		Time.get_ticks_msec() - _started_ms, _max_gap_ms, _frame])
	_finish()


func _on_node_added(node: Node) -> void:
	var path := _script_path(node)
	if path == DIRECTOR_SCRIPT:
		_directors_added += 1
	elif path == ACTOR_SCRIPT:
		_actors_added += 1
	else:
		return
	if not _confirmed:
		_early_combat = true


func _script_path(node: Node) -> String:
	var script: Resource = node.get_script()
	return script.resource_path if script != null else ""


func _find_fade() -> Node:
	for child in get_tree().root.get_children():
		if _script_path(child) == FADE_SCRIPT:
			return child
	return null


func _find_opening(parent: Node) -> Node:
	if _script_path(parent) == "res://ui/pride_opening/opening.gd":
		return parent
	for child in parent.get_children():
		var found := _find_opening(child)
		if found != null:
			return found
	return null


func _on_frame_drawn() -> void:
	var fade := _find_fade()
	if fade != null and bool(fade.call("is_loading")) and bool(fade.call("is_black")):
		_loading_rendered = true
		if not _loading_saved:
			_loading_saved = _save_frame("02-loading-rendered")


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	await RenderingServer.frame_post_draw
	_save_frame(name)


func _save_frame(name: String) -> bool:
	var frame := get_viewport().get_texture().get_image()
	var path := _out.path_join(_route + "-" + name + ".jpg")
	var quality := 0.82
	var result := frame.save_jpg(path, quality)
	var bytes := FileAccess.get_file_as_bytes(path).size() if result == OK else 0
	while result == OK and bytes > MAX_JPEG_BYTES and quality > 0.5:
		quality -= 0.05
		result = frame.save_jpg(path, quality)
		bytes = FileAccess.get_file_as_bytes(path).size() if result == OK else 0
	var saved := result == OK and bytes > 0 and bytes <= MAX_JPEG_BYTES
	_check("saved native proof " + path, saved)
	print("SCREENSHOT %s (%dx%d, %d bytes)" % [path, frame.get_width(), frame.get_height(), bytes])
	return saved


func _key(code: int) -> void:
	await get_tree().process_frame
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in 2:
		await get_tree().process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s" % ["ok" if ok else "FAIL", label])


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _trace != null:
		_trace.flush()
		_trace.close()
	print("COLD OPENING %s: %d checks, %d failed" % [_route, _checks, _failures])
	# Let the driving coroutine return and release its flow/resource locals,
	# then drain queued scene cleanup before asking the engine to exit.
	var scene := get_tree().current_scene
	if scene != null:
		scene.queue_free()
		get_tree().current_scene = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)
