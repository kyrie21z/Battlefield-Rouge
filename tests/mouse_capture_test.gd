extends Node
## Run natively with --free-mouse. The auxiliary window exercises Windows focus loss.
const PLAYER := preload("res://actors/player/player.tscn")
var _checks := 0
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		print("MOUSE CAPTURE: skipped; requires a native window")
		get_tree().quit()
		return
	await get_tree().process_frame
	var window := get_window()
	window.gui_embed_subwindows = false
	window.grab_focus()
	await _until_focus(window)
	GameSettings.settings_path = "user://settings_test_mouse_%d.json" % OS.get_process_id()
	var player := PLAYER.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var menu := PauseMenu.new()
	add_child(menu)
	menu.setup(GameSettings.new(), player)
	await _frames(4)
	_check("a free-mouse test launch starts with an unconfined cursor", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)

	var ammo := player.weapon.ammo
	await _click()
	_check("the first gameplay click captures the pointer without firing",
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.weapon.ammo == ammo)

	_check("Escape menu opens and releases the pointer", menu.try_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	menu.close()
	_check("resuming a focused game restores the captured pointer", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	var release := InputEventKey.new()
	release.physical_keycode = KEY_F10
	release.pressed = true
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _frames(2)
	release = release.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	_check("F10 frees the cursor without pausing the game",
		Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not get_tree().paused)
	await _click()
	_check("clicking the play area resumes mouse look", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	var other := Window.new()
	other.title = "Mouse focus verification"
	other.size = Vector2i(330, 160)
	other.position = window.position + Vector2i(70, 70)
	other.visible = false
	add_child(other)
	other.show()
	other.grab_focus()
	await _until_focus(other)
	_check("focusing a second native window releases the pointer",
		other.has_focus() and not window.has_focus() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	other.hide()
	window.grab_focus()
	await _until_focus(window)
	GamePointer.restore(Input.MOUSE_MODE_CAPTURED, window)
	_check("refocusing and simulating a stale modal restore leave the cursor free",
		window.has_focus() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await _click()
	_check("click after focus returns recaptures the pointer without firing",
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.weapon.ammo == ammo)

	await _click()
	_check("a fresh click still fires after pointer capture", player.weapon.ammo == ammo - 1)

	GamePointer.release_until_click()
	if FileAccess.file_exists(GameSettings.settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.settings_path))
	print("MOUSE CAPTURE: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures else 0)


func _click() -> void:
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.position = get_viewport().get_visible_rect().size * 0.5
		button.pressed = pressed
		Input.parse_input_event(button)
		Input.flush_buffered_events()
		await _frames(3)


func _until_focus(window: Window) -> void:
	for tick in 90:
		if window.has_focus():
			await _frames(3)
			return
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
