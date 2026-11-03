extends Node
## Headless check of the key bindings: encode/decode, reserved inputs, the
## assign/apply/sanitize round trips, the menu capture flow and the Esc-over-
## buff-select rule:
##   godot --headless --path . res://tests/keybinding_test.tscn
## Uses a temp user:// path and restores the default InputMap at the end.

const TEMP := "user://keybinding_test.cfg"

var _failures := 0
var _finished := false
var _player: Player
var _hud
var _director: ZoneDirector
var _menu: PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_remove_temp()
	await _run()
	PauseMenu.allow_headless = false
	GameSettings.settings_path = GameSettings.DEFAULT_PATH
	KeyBindings.apply({})
	_remove_temp()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_test_encode_decode()
	_test_reserved()
	await _test_in_game()
	_finished = true


func _test_encode_decode() -> void:
	print("== encode and decode")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	var code := KeyBindings.encode(key)
	_check("a key encodes to key:<code>", code == "key:%d" % KEY_T)
	var back := KeyBindings.decode(code)
	_check("and decodes to the same event", back is InputEventKey
		and (back as InputEventKey).physical_keycode == KEY_T)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT
	var mouse_code := KeyBindings.encode(button)
	_check("a mouse button encodes to mouse:<button>", mouse_code == "mouse:%d" % MOUSE_BUTTON_RIGHT)
	var mouse_back := KeyBindings.decode(mouse_code)
	_check("and decodes to the same button", mouse_back is InputEventMouseButton
		and (mouse_back as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT)
	_check("garbage decodes to null", KeyBindings.decode("key:abc") == null
		and KeyBindings.decode("stick:3") == null)


func _test_reserved() -> void:
	print("== reserved inputs")
	_check("Esc cannot be bound", not KeyBindings.can_bind(_key_event(KEY_ESCAPE)))
	_check("F3 cannot be bound", not KeyBindings.can_bind(_key_event(KEY_F3)))
	_check("the wheel cannot be bound", not KeyBindings.can_bind(_mouse_event(MOUSE_BUTTON_WHEEL_UP))
		and not KeyBindings.can_bind(_mouse_event(MOUSE_BUTTON_WHEEL_DOWN)))
	_check("ordinary keys and buttons can", KeyBindings.can_bind(_key_event(KEY_T))
		and KeyBindings.can_bind(_mouse_event(MOUSE_BUTTON_XBUTTON1)))


func _test_in_game() -> void:
	print("== bindings in game")
	GameSettings.settings_path = TEMP
	var scene := await _open_zone("res://maps/zone_1.tscn", 0, 13579)
	_choose_entry(scene)
	await _frames(3)
	_player = scene.get_node("Player") as Player
	_hud = scene.get_node("HUD")
	_director = scene.get_node("ZoneDirector") as ZoneDirector
	_menu = _hud.get_node("PauseLayer/PauseMenu") as PauseMenu

	var settings := GameSettings.new()
	KeyBindings.assign(settings.bindings, "hammer", _key_event(KEY_T))
	KeyBindings.apply(settings.bindings)
	var first := InputMap.action_get_events("hammer")[0] as InputEventKey
	_check("assign + apply rebinds the action in the InputMap", first.physical_keycode == KEY_T)
	_check("KeyHint.of follows the new binding", KeyHint.of("hammer") == "T")

	var swapped := KeyBindings.assign(settings.bindings, "melee", _key_event(KEY_T))
	_check("a conflict swaps with the other action", swapped == "hammer"
		and KeyBindings.code_for(settings.bindings, "melee") == "key:%d" % KEY_T
		and KeyBindings.code_for(settings.bindings, "hammer") == "key:%d" % KEY_V)

	KeyBindings.assign(settings.bindings, "melee", _key_event(KEY_V))
	_check("binding back to the default drops the override", not settings.bindings.has("melee")
		and KeyBindings.code_for(settings.bindings, "melee") == KeyBindings.default_code("melee"))

	_check("save the temp file", settings.save_to(TEMP) == OK)
	var loaded := GameSettings.new()
	_check("load the temp file", loaded.load_from(TEMP))
	_check("bindings survive the round trip", loaded.bindings.get("hammer", "") == "key:%d" % KEY_T)
	_check("sanitize drops unknown actions", not loaded.bindings.has("weapon_next"))

	settings.reset_defaults()
	KeyBindings.apply(settings.bindings)
	var restored := InputMap.action_get_events("hammer")[0] as InputEventKey
	_check("reset_defaults restores the InputMap", restored.physical_keycode == KEY_E
		and settings.bindings.is_empty())

	await _test_menu_capture()
	await _test_menu_over_buff_select()
	_test_prompt_follows_binding()


## Opens the menu, clicks a binding row and feeds a key through _input.
func _test_menu_capture() -> void:
	print("== menu capture flow")
	PauseMenu.allow_headless = true
	_check("the menu opens in game", _menu.try_open() and _menu.is_open() and get_tree().paused)
	await _frames(2)
	_check("the menu opens on the settings tab", _menu._settings_box.visible
		and not _menu._bindings_box.visible
		and _menu._tab_settings.button_pressed and not _menu._tab_bindings.button_pressed)
	_menu._tab_settings.button_pressed = false
	_menu._tab_bindings.button_pressed = true
	_check("switching tabs keeps highlight and content in sync", _menu._bindings_box.visible
		and not _menu._settings_box.visible
		and _menu._tab_bindings.button_pressed and not _menu._tab_settings.button_pressed)
	await _frames(2)  # let the bindings grid lay out so the row rects are real

	_menu._on_bind_pressed("hammer")
	_check("the row asks for a key", _menu._awaiting_action == "hammer"
		and (_menu._bind_buttons["hammer"] as Button).text == "按下按键…")
	_menu._input(_key_event(KEY_T))
	_check("the captured key lands on the action",
		_hud.settings.bindings.get("hammer", "") == "key:%d" % KEY_T)
	_check("the InputMap and the row follow", KeyHint.of("hammer") == "T"
		and (_menu._bind_buttons["hammer"] as Button).text == "T")

	_menu._on_bind_pressed("reload")
	_menu._input(_key_event(KEY_ESCAPE))
	_check("Esc cancels the capture", _menu._awaiting_action == ""
		and not _hud.settings.bindings.has("reload"))

	_menu._on_bind_pressed("reload")
	_menu._input(_key_event(KEY_F3))
	_check("a reserved key is refused", _menu._awaiting_action == "reload"
		and not _hud.settings.bindings.has("reload"))
	_menu._end_capture()

	# While waiting, a click on another binding row switches the capture target
	# instead of binding the left button that clicked it.
	_menu._on_bind_pressed("hammer")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (_menu._bind_buttons["reload"] as Button).get_global_rect().get_center()
	_menu._input(click)
	_check("clicking another binding row switches the capture", _menu._awaiting_action == "reload"
		and _hud.settings.bindings.get("hammer", "") == "key:%d" % KEY_T
		and not _hud.settings.bindings.has("reload"))
	_menu._end_capture()

	# A left click away from the rows still binds 左键.
	_menu._on_bind_pressed("interact")
	var away := InputEventMouseButton.new()
	away.button_index = MOUSE_BUTTON_LEFT
	away.pressed = true
	away.position = Vector2(60.0, 60.0)
	_menu._input(away)
	_check("a left click elsewhere binds 左键", _menu._awaiting_action == ""
		and _hud.settings.bindings.get("interact", "") == "mouse:1"
		and KeyHint.of("interact") == "左键")

	_menu.close()
	_check("closing unpauses and asks for the mouse", not get_tree().paused
		and _menu.capture_requests >= 1)


func _test_menu_over_buff_select() -> void:
	print("== Esc over the buff screen")
	get_tree().paused = true
	_director.phase = ZoneDirector.Phase.BUFF_SELECT
	var pause := InputEventAction.new()
	pause.action = "pause"
	pause.pressed = true
	_menu._unhandled_input(pause)
	_check("Esc opens the menu over a buff selection", _menu.is_open() and get_tree().paused)
	_menu._unhandled_input(pause)
	_check("closing keeps the tree paused", not _menu.is_open() and get_tree().paused)
	_director.phase = ZoneDirector.Phase.CLEAR_GUARDS
	_check("it refuses while paused outside a buff selection", not _menu.try_open())
	get_tree().paused = false


## The hammer is bound to T at this point; the prompt must show it.
func _test_prompt_follows_binding() -> void:
	print("== prompts follow bindings")
	_director.phase = ZoneDirector.Phase.HAMMER_POINT
	_director.phase_changed.emit(ZoneDirector.Phase.HAMMER_POINT)
	var objective := _hud.get_node("Top") as ObjectivePanel
	_check("the objective panel shows the new key", objective._detail.text == "按 T 挥锤")


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


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
