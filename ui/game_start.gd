extends Node
## Entry only. The existing RunState and ZoneDirector still own the whole run.
const OPENING := preload("res://ui/pride_opening/opening.tscn")
const FADE := preload("res://ui/scene_fade.gd")
## Finish the opening and draw the loading overlay before loading the zone.
## Godot 4.7.2 can leave threaded scene/script loads in IN_PROGRESS forever.
## No background request may own the same resource when we enter the game.
## Fixture / --skip-opening keep the original direct entry (ADR 0005/0009).
const BLACK_SECONDS := 0.45
const REVEAL_SECONDS := 0.6
const HOLD_FRAMES := 3
var opening: Node3D
var _load_requested := false
var _zone_path := ""
var _fade: SceneFade
var _packed: PackedScene


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if RunState.fixture == null and not RunDirector.active:
		RunDirector.begin_run()
	if RunState.fixture != null or "--skip-opening" in OS.get_cmdline_user_args():
		_enter_game.call_deferred()
		return
	opening = OPENING.instantiate()
	opening.combat_entry_requested.connect(_enter_game, CONNECT_ONE_SHOT)
	add_child(opening)
	opening.flow.start()
	_zone_path = _target_scene()


func _target_scene() -> String:
	return RunDirector.scene_path() if RunState.fixture == null and RunDirector.active else RunState.zone_scene()


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
	var target := _target_scene()
	if _zone_path.is_empty() or _zone_path != target:
		# Fixture and --skip-opening enter directly, without an opening fade.
		_enter_synchronously(target)
		return
	_enter_from_opening(target)


func _enter_synchronously(target: String) -> void:
	var result := _commit_scene(_load_zone(target))
	if result != OK:
		_load_requested = false
		push_error("Cannot enter the existing game: " + target)


func _enter_from_opening(target: String) -> void:
	if is_instance_valid(_fade):
		_fade.discard()
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

	# Give the black overlay and loading label an actual rendered frame before
	# the synchronous load. The opening stays smooth and no loader worker can
	# deadlock against the main thread while compiling gameplay scripts.
	_fade.show_loading()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or get_tree().current_scene != self:
		_fade.discard()
		return
	_packed = _load_zone(target)
	if _packed == null or not _packed.can_instantiate():
		_load_requested = false
		_fade.show_error("关卡加载失败，请重试。", _enter_game)
		return

	# The overlay lives on the root, so the scene change cannot take it away.
	# Keep a local: the scene change may free this node on the next frame.
	var fade := _fade
	var packed := _packed
	var result := _commit_scene(packed)
	if result != OK:
		_load_requested = false
		fade.show_error("关卡切换失败，请重试。", _enter_game)
		return
	fade.reveal(HOLD_FRAMES, REVEAL_SECONDS)


func _load_zone(target: String) -> PackedScene:
	return ResourceLoader.load(target, "PackedScene") as PackedScene


func _commit_scene(packed: PackedScene) -> Error:
	if RunState.fixture == null and RunDirector.active:
		return RunDirector.install_stage(packed)
	return get_tree().change_scene_to_packed(packed)
