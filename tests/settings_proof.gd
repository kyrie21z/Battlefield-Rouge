extends Node
## Native-window proof frames for the pause menu and crosshair settings:
##   godot --path . res://tests/settings_proof.tscn -- --out=docs/proof/settings-menu
## Frames: 01 the open pause menu, 02 a bigger green cross+dot in game,
## 03 the ring style. Needs a real display.

const ZONE := "res://maps/zone_1.tscn"
const PROOF_SETTINGS := "user://settings_proof.cfg"

var _out_dir := "res://docs/proof/settings-menu"
var _player: Player
var _hud


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("settings proof needs a native display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	GameSettings.settings_path = PROOF_SETTINGS
	if FileAccess.file_exists(PROOF_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROOF_SETTINGS))

	# A real run (not a fixture), so the pause menu is allowed to open.
	RunState.clear_fixture()
	RunState.zone_index = 0
	RunState.buffs.clear()
	RunState.selection_history.clear()
	RunState.run_seed = 1001
	BuffPool.reset(1001)
	var scene: Node = load(ZONE).instantiate()
	add_child(scene)
	await _frames(3)
	await _press_one()
	get_tree().paused = false
	_player = scene.get_node("Player") as Player
	_hud = scene.get_node("HUD")
	_player.health.max_health = 100000.0
	_player.health.health = 100000.0
	_player.set_physics_process(false)
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)
	await _frames(3)

	var menu := _hud.get_node("PauseMenu") as PauseMenu
	menu.try_open()
	await _frames(3)
	_shot("01_pause_menu")
	menu.close()
	await _frames(3)

	var settings: GameSettings = _hud.settings
	settings.crosshair_style = Crosshair.Style.CROSS_DOT
	settings.crosshair_color = GameSettings.COLOR_PRESETS[1]
	settings.crosshair_size = 1.7
	settings.crosshair_thickness = 2.5
	settings.crosshair_alpha = 1.0
	settings.changed.emit()
	await _frames(4)
	_shot("02_green_cross")

	settings.crosshair_style = Crosshair.Style.RING
	settings.crosshair_color = GameSettings.COLOR_PRESETS[4]
	settings.changed.emit()
	await _frames(4)
	_shot("03_ring")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROOF_SETTINGS))
	print("proof frames written to %s" % _out_dir)
	get_tree().quit(0)


func _press_one() -> void:
	var choose := InputEventKey.new()
	choose.physical_keycode = KEY_1
	choose.pressed = true
	Input.parse_input_event(choose)
	await _frames(2)
	choose.pressed = false
	Input.parse_input_event(choose)
	await _frames(3)


func _shot(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_jpg("%s/%s.jpg" % [_out_dir, name], 0.88)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
