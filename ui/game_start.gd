extends Node
## Entry only. The existing RunState and ZoneDirector still own the whole run.
const OPENING := preload("res://ui/pride_opening/opening.tscn")
const FADE := preload("res://ui/scene_fade.gd")
## The opening warms the first zone while the player reads. The entry then only
## fades, waits for that load and holds black over the new scene's first frames.
## Fixture / --skip-opening keep the plain synchronous entry (ADR 0005/0009).
##
## The warm-up requests one resource at a time: Godot 4.7.2's threaded loader
## can deadlock while a single request spawns several heavy dependencies at
## once (reproduced on maps/zone_1.tscn, progress frozen forever). Loading the
## scene's direct dependencies sequentially, cached one by one, has been
## reliable; the zone request that follows then has almost nothing left to do.
const BLACK_SECONDS := 0.45
const REVEAL_SECONDS := 0.6
const HOLD_FRAMES := 3
var opening: Node3D
var _load_requested := false
var _zone_path := ""
var _fade: SceneFade
var _preload_queue: Array[String] = []
var _preload_path := ""
var _preload_active := false
var _preload_done := false
var _packed: PackedScene


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if RunState.fixture != null or "--skip-opening" in OS.get_cmdline_user_args():
		_enter_game.call_deferred()
		return
	opening = OPENING.instantiate()
	opening.combat_entry_requested.connect(_enter_game, CONNECT_ONE_SHOT)
	add_child(opening)
	opening.flow.start()
	_start_zone_preload()


func _start_zone_preload() -> void:
	_zone_path = RunState.zone_scene()
	for dependency in ResourceLoader.get_dependencies(_zone_path):
		_preload_queue.append(String(dependency))
	if _preload_queue.is_empty():
		push_error("Cannot read the dependencies of the first zone: " + _zone_path)
		_preload_done = true
		return
	_warm_zone()


func _warm_zone() -> void:
	while not _preload_queue.is_empty():
		var path: String = _preload_queue.pop_front()
		var loaded: Resource = await _request(path, "")
		if loaded == null:
			push_error("Cannot preload a zone dependency: " + path)
	var zone: Resource = await _request(_zone_path, "PackedScene")
	_packed = zone as PackedScene
	if _packed == null:
		push_error("Cannot preload the first zone: " + _zone_path)
	_preload_done = true


## Requests `path`, waits for it without blocking the main thread and collects
## the result. Returns null when the loader reports anything but LOADED.
func _request(path: String, type_hint: String) -> Resource:
	var result := ResourceLoader.load_threaded_request(path, type_hint, true)
	if result != OK:
		return null
	_preload_active = true
	_preload_path = path
	var status := ResourceLoader.load_threaded_get_status(path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)
	_preload_active = false
	_preload_path = ""
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(path)


func _enter_game() -> void:
	# A later-zone --fixture may also be redirected by RunState's existing
	# deferred startup. Whichever loads first owns it; never warm a second zone.
	if _load_requested or not is_inside_tree():
		return
	if get_tree().current_scene != self:
		return
	_load_requested = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var target := RunState.zone_scene()
	if _zone_path.is_empty() or _zone_path != target:
		# Fixture and --skip-opening enter exactly as before: no fade, no threads.
		_enter_synchronously(target)
		return
	_enter_from_opening(target)


func _enter_synchronously(target: String) -> void:
	var result := get_tree().change_scene_to_file(target)
	if result != OK:
		_load_requested = false
		push_error("Cannot enter the existing game: " + target)


func _enter_from_opening(target: String) -> void:
	_fade = FADE.new()
	get_tree().root.add_child(_fade)
	var audio: AudioStreamPlayer = opening.get("audio") if is_instance_valid(opening) else null
	var start_db := audio.volume_db if is_instance_valid(audio) else 0.0
	var fade_audio := func(progress: float) -> void:
		if is_instance_valid(audio):
			audio.volume_db = lerpf(start_db, -60.0, progress)
	await _fade.fade_to_black(BLACK_SECONDS, fade_audio)
	if is_instance_valid(audio):
		audio.stop()

	if not _preload_done:
		_fade.show_loading()
		while not _preload_done:
			await get_tree().process_frame
	if not is_instance_valid(_packed):
		push_error("Background zone load failed, entering synchronously: " + target)
		_fade.discard()
		_enter_synchronously(target)
		return

	# The overlay lives on the root, so the scene change cannot take it away.
	# Keep a local: the scene change may free this node on the next frame.
	var fade := _fade
	var packed := _packed
	var result := get_tree().change_scene_to_packed(packed)
	if result != OK:
		_load_requested = false
		push_error("Cannot enter the existing game: " + target)
		fade.discard()
		return
	fade.reveal(HOLD_FRAMES, REVEAL_SECONDS)
