extends Node

const BOOT := preload("res://ui/game_start.tscn")
const REALM_CHECKPOINT := {
	"run_id": "portrait-proof", "run_seed": 275, "order": [0, 1, 2, 3],
	"floor_index": 3, "room_index": 1, "defeated": [0, 1, 2], "deprivations": [0, 1, 2],
	"shards": [0, 1, 2], "hp": 95.0, "boon_ids": [], "fragment_state": {}, "rerolls": 2,
	"selections": [], "entry_reward_claimed": true, "earned_will": 45, "earned_anchors": 2,
	"defiance_consumed": false,
}
var _checks := 0
var _failures := 0
var _proof_dir := ""
var _boot: Node
var _title: TitleScreen
var _dialog: ConfirmationDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--title-proof-dir="):
			_proof_dir = argument.trim_prefix("--title-proof-dir=")
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.create_timer(90).timeout.connect(func(): tree.quit(2))
	tree.current_scene = null
	PauseMenu.allow_headless = true
	var original_path := GameSettings.settings_path
	GameSettings.settings_path = "user://title_settings_%d.cfg" % OS.get_process_id()
	_boot = BOOT.instantiate()
	tree.root.add_child(_boot)
	tree.current_scene = _boot
	_title = _boot.title_screen
	_dialog = _title.get_node("Confirmation") as ConfirmationDialog
	_check("normal boot is read-only", not RunDirector.active and RunDirector.run_count == 0
		and not MetaProgression.has_profile() and tree.get_nodes_in_group("player").is_empty())
	_check_menu(["开始游戏", "设置与按键", "退出游戏"])
	var state := _title.bust_state()
	_check("fresh white body and low-emission hovering crown", state.crown_hovering and not state.kintsugi
		and state.fracture_level == 0 and is_equal_approx(state.crown_emission, 0.5)
		and state.tagline == "在停摆的那一刻，醒来。" and state.lit_realms == 0)
	await _capture("fresh")

	_button("Settings").pressed.emit()
	var settings_menu := _title.get_node("PauseMenu") as PauseMenu
	_check("title settings work standalone", settings_menu.is_open() and tree.paused
		and settings_menu._player == null and not settings_menu._title_exit.visible)
	settings_menu._sliders.mouse.value = 1.45
	settings_menu._reduced_motion.button_pressed = true
	settings_menu.close()
	var reloaded := GameSettings.new()
	_check("standalone settings persist and reduce portrait movement", not tree.paused
		and reloaded.load_from(GameSettings.settings_path) and is_equal_approx(reloaded.mouse_sensitivity, 1.45)
		and reloaded.reduced_motion and _title.reduced_motion_enabled() and not _title.is_processing())

	_check("existing profile is saved", MetaProgression.mark_opening_completed()
		and MetaProgression.record_history(3, 0, "") and MetaProgression.settle_run("title-budget", 74, 0))
	for realm in 3:
		MetaProgression.record_archive(realm, true)
	_check_menu(["继续游戏", "新游戏", "设置与按键", "退出游戏"])
	_check("hub summary reflects saved progress", _title._summary.text == "静滞之门 · 第 3 次 · 3/4 心魔 · 74 碎屑")
	_check("checkpoint is valid", MetaProgression.save_active_run(REALM_CHECKPOINT))
	_check_menu(["继续当前挑战", "返回静滞之门", "新游戏", "设置与按键", "退出游戏"])
	state = _title.bust_state()
	_check("exploring body has visible seated crown, three fractures and three realm pips",
		not state.crown_hovering and not state.kintsugi and state.fracture_level == 3
		and is_equal_approx(state.crown_emission, 0.5 * pow(2.4, 3))
		and state.lit_realms == 3 and state.tagline == "在停摆的那一刻，醒来。")
	_check("room summary uses checkpoint order and indices", _title._summary.text == "第 4 层 · 悲伤 房 2/3")
	_button("Primary").grab_focus()
	await _capture("mid")

	_button("Abandon").pressed.emit()
	_check("abandonment requires explicit confirmation", _dialog.visible
		and _dialog.dialog_text.contains("结算") and MetaProgression.has_active_run())
	_dialog.get_cancel_button().pressed.emit()
	await tree.process_frame
	_check("canceling abandonment keeps the checkpoint", not _dialog.visible and MetaProgression.has_active_run())

	_button("Primary").pressed.emit()
	while not is_instance_valid(RunDirector.current_stage):
		await tree.process_frame
	var stage := RunDirector.current_stage as RealmStage
	_check("resume action installs the saved room with its original seed",
		stage == tree.current_scene and stage.realm == 3 and RunDirector.floor_index == 3
		and RunDirector.room_index == 1 and RunDirector.run_seed == 275 and RunDirector.earned_will == 45)
	stage.request_title()
	await tree.process_frame
	_boot = tree.current_scene
	_title = _boot.title_screen
	_dialog = _title.get_node("Confirmation") as ConfirmationDialog
	_check("returning from combat remounts the active-run title with the same checkpoint",
		_button("Primary").text == "继续当前挑战" and MetaProgression.active_run == REALM_CHECKPOINT)

	_button("Abandon").pressed.emit()
	_dialog.get_ok_button().pressed.emit()
	while not tree.current_scene is StasisHub:
		await tree.process_frame
	var hub := tree.current_scene as StasisHub
	_check("confirmed abandonment banks only checkpointed income", hub.hub_reason == "abandoned"
		and MetaProgression.will_shards == 119 and MetaProgression.reality_anchors == 2
		and not MetaProgression.has_active_run() and MetaProgression.settled_runs.has("portrait-proof"))

	hub.title_requested.emit()
	await tree.process_frame
	_boot = tree.current_scene
	_title = _boot.title_screen
	_dialog = _title.get_node("Confirmation") as ConfirmationDialog
	MetaProgression.record_archive(3, true, true)
	state = _title.bust_state()
	_check("reconciled bust restores kintsugi with calm crown and epilogue tagline",
		state.kintsugi and not state.crown_hovering and state.fracture_level == 0
		and is_equal_approx(state.crown_emission, 0.55) and state.lit_realms == 4
		and state.tagline == "不再完美，但终于完整。")
	await _capture("reconciled")

	_button("Reset").pressed.emit()
	_check("new game confirmation explains the backup", _dialog.visible
		and _dialog.dialog_text.contains(".bak") and MetaProgression.reconciled)
	_dialog.get_cancel_button().pressed.emit()
	await tree.process_frame
	_check("canceling reset preserves progression", not _dialog.visible and MetaProgression.reconciled)
	_button("Reset").pressed.emit()
	var old_bytes := FileAccess.get_file_as_bytes(MetaProgression.save_path())
	_dialog.get_ok_button().pressed.emit()
	while _boot.opening == null:
		await tree.process_frame
	_check("confirmed reset saves original backup and enters opening with a clean director",
		not MetaProgression.has_profile() and RunDirector.run_count == 0 and not RunDirector.active
		and RunDirector.run_id.is_empty() and _boot.opening.reduced_motion
		and not old_bytes.is_empty() and FileAccess.get_file_as_bytes(MetaProgression.save_path() + ".bak") == old_bytes)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.settings_path))
	GameSettings.settings_path = original_path
	tree.current_scene = null
	_boot.queue_free()
	await tree.process_frame
	# Give the audio thread time to retire the opening streams after cleanup.
	OS.delay_msec(250)
	await tree.process_frame
	print("TITLE SCREEN: %d checks, %d failures" % [_checks, _failures])
	tree.quit(1 if _failures else 0)


func _button(id: String) -> Button:
	return _title.find_child(id, true, false) as Button


func _check_menu(expected: Array) -> void:
	var labels: Array[String] = []
	for id in ["Primary", "Abandon", "Reset", "Settings", "Quit"]:
		var button := _button(id)
		if button.visible:
			labels.append(button.text)
	_check("menu: " + " / ".join(expected), labels == expected)


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print(("PASS " if passed else "FAIL ") + label)


func _capture(id: String) -> void:
	if _proof_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_proof_dir)
	var path := _proof_dir.path_join(id + ".png")
	_check("native screenshot " + path, get_viewport().get_texture().get_image().save_png(path) == OK)
