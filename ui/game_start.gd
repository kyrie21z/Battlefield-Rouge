extends Node
## Entry only. The existing RunState and ZoneDirector still own the whole run.
const OPENING := preload("res://ui/pride_opening/opening.tscn")
var opening: Node3D
var _load_requested := false


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
	var result := get_tree().change_scene_to_file(target)
	if result != OK:
		_load_requested = false
		push_error("Cannot enter the existing game: " + target)
