extends Node
## Headless check of the settings store, the crosshair styles, the mouse look
## scaling and the pause menu:
##   godot --headless --path . res://tests/settings_test.tscn
## Uses a temp user:// path; never the player's real settings.cfg.

const TEMP := "user://settings_test.cfg"

var _failures := 0
var _finished := false
var _player: Player
var _hud
var _cross: Crosshair
var _director: ZoneDirector
var _menu: PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_remove_temp()
	await _run()
	for voice in find_children("*", "AudioStreamPlayer", true, false):
		voice.stop()
		voice.stream = null
	for child in get_children():
		child.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	PauseMenu.allow_headless = false
	GameSettings.settings_path = GameSettings.DEFAULT_PATH
	_remove_temp()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_test_defaults_and_files()
	GameSettings.settings_path = TEMP
	var scene := await _open_zone("res://maps/zone_1.tscn", 0, 24680)
	_choose_entry(scene)
	await _frames(3)
	_player = scene.get_node("Player") as Player
	_hud = scene.get_node("HUD")
	_cross = _hud.get_node("Crosshair") as Crosshair
	_director = scene.get_node("ZoneDirector") as ZoneDirector
	_menu = _hud.get_node("PauseLayer/PauseMenu") as PauseMenu
	await _test_defaults_in_game()
	_test_clamp()
	await _test_mouse_look()
	await _test_styles()
	await _test_pause()
	scene.queue_free()
	await _frames(3)
	await get_tree().create_timer(0.15).timeout
	_finished = true


func _test_defaults_and_files() -> void:
	print("== defaults and files")
	var settings := GameSettings.new()
	_check("sensitivity multiplier defaults to 1", is_equal_approx(settings.mouse_sensitivity, 1.0))
	_check("ADS multiplier defaults to 1", is_equal_approx(settings.ads_sensitivity, 1.0))
	_check("crosshair style defaults to cross+dot", settings.crosshair_style == Crosshair.Style.CROSS_DOT)
	_check("white, size 1, 1.5 px, 0.9 alpha, dynamic gap",
		settings.crosshair_color == Color.WHITE and is_equal_approx(settings.crosshair_size, 1.0)
		and is_equal_approx(settings.crosshair_thickness, 1.5) and is_equal_approx(settings.crosshair_alpha, 0.9)
		and settings.dynamic_gap)

	settings.mouse_sensitivity = 2.5
	settings.ads_sensitivity = 0.5
	settings.crosshair_style = Crosshair.Style.RING
	settings.crosshair_color = Color(0.35, 0.95, 0.45)
	settings.crosshair_size = 1.5
	settings.crosshair_thickness = 3.0
	settings.crosshair_alpha = 0.5
	settings.dynamic_gap = false
	_check("save to a temp file", settings.save_to(TEMP) == OK)
	var loaded := GameSettings.new()
	_check("load the temp file", loaded.load_from(TEMP))
	_check("round trip keeps every value",
		is_equal_approx(loaded.mouse_sensitivity, 2.5) and is_equal_approx(loaded.ads_sensitivity, 0.5)
		and loaded.crosshair_style == Crosshair.Style.RING
		and loaded.crosshair_color == Color(0.35, 0.95, 0.45)
		and is_equal_approx(loaded.crosshair_size, 1.5) and is_equal_approx(loaded.crosshair_thickness, 3.0)
		and is_equal_approx(loaded.crosshair_alpha, 0.5) and not loaded.dynamic_gap)


func _test_defaults_in_game() -> void:
	print("== the game still looks the same")
	_check("crosshair defaults are unchanged", _cross.line_length == 5.0 and _cross.thickness == 1.5
		and _cross.color == Color(1, 1, 1, 0.9) and _cross.dot_size == 3.0 and _cross.outline == 1.0
		and _cross.min_gap == 2.0 and _cross.max_gap == 24.0 and _cross.style == Crosshair.Style.CROSS_DOT)
	_check("player look defaults are unchanged", is_equal_approx(_player.mouse_sensitivity, 0.0022)
		and is_equal_approx(_player.ads_sensitivity, 1.0))
	_check("the HUD owns settings and does not read a real file in headless",
		_hud.settings != null and is_equal_approx(_hud.settings.mouse_sensitivity, 1.0))


func _test_clamp() -> void:
	print("== clamping")
	var config := ConfigFile.new()
	config.set_value("input", "mouse_sensitivity", 99.0)
	config.set_value("input", "ads_sensitivity", 0.01)
	config.set_value("crosshair", "style", 9)
	config.set_value("crosshair", "size", 9.0)
	config.set_value("crosshair", "thickness", 0.0)
	config.set_value("crosshair", "alpha", 0.0)
	config.save(TEMP)
	var settings := GameSettings.new()
	settings.load_from(TEMP)
	_check("values clamp to their ranges", is_equal_approx(settings.mouse_sensitivity, GameSettings.SENS_MAX)
		and is_equal_approx(settings.ads_sensitivity, GameSettings.ADS_MIN)
		and settings.crosshair_style == Crosshair.Style.RING
		and is_equal_approx(settings.crosshair_size, GameSettings.SIZE_MAX)
		and is_equal_approx(settings.crosshair_thickness, GameSettings.THICKNESS_MIN)
		and is_equal_approx(settings.crosshair_alpha, GameSettings.ALPHA_MIN))


func _test_mouse_look() -> void:
	print("== mouse look")
	var base := _player.mouse_sensitivity
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(100.0, 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player.global_rotation = Vector3.ZERO
	_player.set_look_sensitivity(base, 1.0)
	_player._unhandled_input(event)
	var one := absf(_player.rotation.y)
	_player.global_rotation = Vector3.ZERO
	_player.set_look_sensitivity(base * 2.0, 1.0)
	_player._unhandled_input(event)
	var two := absf(_player.rotation.y)
	_check("2x mouse sensitivity doubles the yaw delta", is_equal_approx(two, one * 2.0))

	_player.weapon.aiming = true
	(_player.get_node("Head/Camera3D") as Camera3D).fov = _player.weapon.data.ads_fov
	_player.global_rotation = Vector3.ZERO
	_player.set_look_sensitivity(base, 1.0)
	_player._unhandled_input(event)
	var ads_one := absf(_player.rotation.y)
	_player.global_rotation = Vector3.ZERO
	_player.set_look_sensitivity(base, 0.5)
	_player._unhandled_input(event)
	var ads_half := absf(_player.rotation.y)
	_check("ADS 0.5 halves the look while zoomed", is_equal_approx(ads_half, ads_one * 0.5))
	_player.weapon.aiming = false
	_player.global_rotation = Vector3.ZERO
	_player._unhandled_input(event)
	var hip := absf(_player.rotation.y)
	_check("and does nothing while not aiming", is_equal_approx(hip * _player.weapon.data.ads_fov / _player.base_fov, ads_one))
	_player.weapon.aiming = false
	_player.set_look_sensitivity(base, 1.0)


func _test_styles() -> void:
	print("== crosshair styles")
	var styles := [Crosshair.Style.CROSS, Crosshair.Style.CROSS_DOT, Crosshair.Style.DOT, Crosshair.Style.RING]
	for style in styles:
		_hud.settings.crosshair_style = style
		_hud.settings.changed.emit()
		await _frames(2)
		_check("style %d draws" % style, _cross.style == style and _cross.size.x > 0.0)
	var ring_before := _cross.ring_draws
	_hud.settings.crosshair_style = Crosshair.Style.RING
	_hud.settings.changed.emit()
	await _frames(3)
	_check("the ring style draws a ring", _cross.ring_draws > ring_before)
	var dot_before := _cross.dot_draws
	_hud.settings.crosshair_style = Crosshair.Style.CROSS
	_hud.settings.changed.emit()
	await _frames(3)
	_check("the cross style draws lines but no dot", _cross.dot_draws == dot_before
		and _cross.line_draws > 0)
	_hud.settings.crosshair_style = Crosshair.Style.CROSS_DOT
	_hud.settings.changed.emit()
	await _frames(2)


func _test_pause() -> void:
	print("== pause menu")
	PauseMenu.allow_headless = true
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	_menu._unhandled_input(event)
	_check("pause opens the menu and pauses", _menu.is_open() and get_tree().paused and _menu.visible)
	_menu._unhandled_input(event)
	_check("pause again closes it and unpauses", not _menu.is_open() and not get_tree().paused)
	if DisplayServer.get_name() == "headless":
		_check("resume asks for mouse capture", _menu.capture_requests == 1)
	else:
		_check("and the mouse is captured again", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	_director.phase = ZoneDirector.Phase.BUFF_SELECT
	get_tree().paused = true
	_check("it opens over a buff selection", _menu.try_open())
	_menu.close()
	_check("closing over a buff selection keeps the tree paused",
		get_tree().paused and _director.phase == ZoneDirector.Phase.BUFF_SELECT)
	_director.phase = ZoneDirector.Phase.CLEAR_GUARDS
	_check("it refuses while paused outside a buff selection", not _menu.try_open())
	get_tree().paused = false
	RunState.fixture = RunFixture.by_id("FX-001")
	_check("it refuses under a fixture", not _menu.try_open())
	RunState.fixture = null
	_check("the temp settings file was written on close", FileAccess.file_exists(TEMP))


func _open_zone(path: String, zone_index: int, run_seed: int) -> Node:
	get_tree().paused = false
	RunState.clear_fixture()
	RunState.zone_index = zone_index
	RunState.buffs.clear()
	RunState.selection_history.clear()
	RunState.run_seed = run_seed
	BuffPool.reset(run_seed)
	var scene := (load(path) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	return scene


func _choose_entry(scene: Node) -> void:
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	if is_instance_valid(director.selection):
		(director.selection.get_node("Center/Box/Choices/Choice1") as Button).pressed.emit()


func _remove_temp() -> void:
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
