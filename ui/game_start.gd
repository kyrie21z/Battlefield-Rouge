## The boot entry owns the title and opening handoff. RunDirector owns the campaign.
extends Node
const TITLE := "res://ui/title_screen/title_screen.tscn"
const OPENING := "res://ui/cinematics/opening_sequence.tscn"

var allow_cli_bypass := true
var title_screen: TitleScreen
var opening: OpeningSequence
var _routing := false


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if RunState.fixture != null or (allow_cli_bypass and "--skip-opening" in OS.get_cmdline_user_args()):
		_enter_direct.call_deferred()
		return
	title_screen = (load(TITLE) as PackedScene).instantiate() as TitleScreen
	title_screen.action_requested.connect(_route, CONNECT_DEFERRED)
	add_child(title_screen)


func _enter_direct() -> void:
	if not is_inside_tree() or get_tree().current_scene != self:
		return
	if RunState.fixture != null:
		get_tree().change_scene_to_file(RunState.zone_scene())
	elif RunDirector.begin_run():
		RunDirector.install_stage(load(RunDirector.scene_path()) as PackedScene)


func _route(action: TitleScreen.Action) -> void:
	if _routing or get_tree().current_scene != self:
		return
	_routing = true
	title_screen.set_routing(true)
	var fade := SceneFade.new()
	get_tree().root.add_child(fade)
	await fade.fade_to_black(0.22)
	if not is_inside_tree() or get_tree().current_scene != self:
		fade.discard()
		return

	var success := true
	match action:
		TitleScreen.Action.START:
			_start_opening()
		TitleScreen.Action.RESET:
			success = RunDirector.reset_campaign()
			if success:
				_start_opening()
		TitleScreen.Action.RESUME:
			success = RunDirector.resume_run()
		TitleScreen.Action.HUB:
			RunDirector.enter_hub("title")
			success = get_tree().current_scene != self
		TitleScreen.Action.ABANDON:
			success = RunDirector.abandon_active_run()
			if success:
				RunDirector.enter_hub("abandoned")
				success = get_tree().current_scene != self
	fade.reveal(0, 0.35)
	if not success:
		_routing = false
		title_screen.set_routing(false)
		title_screen.show_error(MetaProgression.last_error)


func _start_opening() -> void:
	var reduced_motion := title_screen.reduced_motion_enabled()
	remove_child(title_screen)
	title_screen.queue_free()
	title_screen = null
	opening = (load(OPENING) as PackedScene).instantiate() as OpeningSequence
	opening.reduced_motion = reduced_motion
	opening.combat_entry_requested.connect(_complete_opening)
	add_child(opening)
	opening.start()


func _complete_opening() -> void:
	if not RunDirector.start_opening_run(opening.audio):
		opening.allow_entry_retry()
