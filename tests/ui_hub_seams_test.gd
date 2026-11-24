extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	_check("test uses an isolated player profile", MetaProgression.isolated_profile)
	PauseMenu.allow_headless = true
	var previous_settings_path := GameSettings.settings_path
	GameSettings.settings_path = "user://ui_hub_seams_%d.cfg" % OS.get_process_id()
	_test_standalone_settings()
	await _test_archive()
	await _test_realm_hud()
	DirAccess.remove_absolute(GameSettings.settings_path)
	GameSettings.settings_path = previous_settings_path
	PauseMenu.allow_headless = false
	print("UI HUB SEAMS: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_standalone_settings() -> void:
	var menu := PauseMenu.new()
	var settings := GameSettings.new()
	menu.setup(settings)
	add_child(menu)
	var previous_mouse := Input.mouse_mode
	_check("title settings open without player or director", menu.try_open()
		and get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	_check("title settings offer close and hide the title exit", not menu._title_exit.visible
		and not menu._exit_note.visible and menu._resume.text == "关闭")
	menu._sliders["mouse"].value = 2.5
	menu._sliders["ads"].value = 0.5
	menu._sliders["size"].value = 1.5
	menu._sliders["alpha"].value = 0.5
	menu._sliders["thickness"].value = 3.0
	menu._style.item_selected.emit(Crosshair.Style.RING)
	menu._colors[2].pressed.emit()
	menu._dynamic.button_pressed = false
	menu._sliders["music"].value = 0.4
	var music_bus := AudioServer.get_bus_index(&"Music")
	_check("music slider applies without a combat HUD",
		is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.4)))
	_check("crosshair preview follows the current configuration", menu._preview.style == Crosshair.Style.RING
		and is_equal_approx(menu._preview.line_length, 7.5)
		and is_equal_approx(menu._preview.thickness, 3.0)
		and menu._preview.color.is_equal_approx(Color(GameSettings.COLOR_PRESETS[2], 0.5)))
	menu._tab_bindings.button_pressed = true
	(menu._bind_buttons["interact"] as Button).pressed.emit()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_L
	key.pressed = true
	get_viewport().push_input(key)
	_check("rebind updates the live input map", KeyHint.of("interact") == "L")
	menu._resume.pressed.emit()
	_check("closing title settings restores pause and mouse state", not menu.is_open()
		and not get_tree().paused and Input.mouse_mode == previous_mouse)
	var saved := GameSettings.new()
	var loaded := saved.load_from(GameSettings.settings_path)
	_check("close persists all edited settings", loaded and is_equal_approx(saved.mouse_sensitivity, 2.5)
		and is_equal_approx(saved.ads_sensitivity, 0.5) and saved.crosshair_style == Crosshair.Style.RING
		and saved.crosshair_color.is_equal_approx(GameSettings.COLOR_PRESETS[2])
		and is_equal_approx(saved.crosshair_size, 1.5) and is_equal_approx(saved.crosshair_alpha, 0.5)
		and is_equal_approx(saved.crosshair_thickness, 3.0) and not saved.dynamic_gap
		and is_equal_approx(saved.music_volume, 0.4) and saved.bindings.get("interact") == "key:%d" % KEY_L)

	menu.configure_exit_button(true)
	var clean_exit: Array[bool] = []
	menu.return_to_title_requested.connect(func():
		clean_exit.append(not menu.is_open() and not get_tree().paused
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE))
	_check("hub settings expose a title exit without a room note", menu.try_open()
		and menu._title_exit.visible and menu._title_exit.text == "返回标题画面" and not menu._exit_note.visible)
	var reset := menu._resume.get_parent().get_child(2) as Button
	reset.pressed.emit()
	_check("reset restores defaults and live bindings", is_equal_approx(settings.mouse_sensitivity, 1.0)
		and settings.dynamic_gap and settings.bindings.is_empty() and KeyHint.of("interact") == "F")
	menu._title_exit.pressed.emit()
	_check("hub exit emits once after releasing modal input and saves reset defaults",
		clean_exit == [true] and saved.load_from(GameSettings.settings_path)
		and saved.bindings.is_empty() and is_equal_approx(saved.music_volume, GameSettings.MUSIC_DEFAULT))
	menu.free()


func _test_archive() -> void:
	var known: Array[String] = []
	for kind in 5:
		for card in BoonCatalog.all():
			var page := 0 if card.rarity == BoonData.Rarity.DUAL else card.sin + 1
			if page == kind:
				known.append(card.id)
				break
	MetaProgression.discovered_boons.assign(known)
	MetaProgression.visited_realms.assign([0])
	var profile := MetaProgression._payload().duplicate(true)
	var saved_hash := FileAccess.get_sha256(MetaProgression.save_path()) if FileAccess.file_exists(MetaProgression.save_path()) else ""
	var writes: Array[bool] = []
	var on_change := func(): writes.append(true)
	MetaProgression.changed.connect(on_change)
	var previous_mouse := Input.mouse_mode
	var archive := StasisArchiveModal.new()
	archive.setup(MetaProgression.archive_snapshot(), MetaProgression.discovered_boons)
	add_child(archive)
	var closes: Array[bool] = []
	archive.closed.connect(func(): closes.append(get_tree().paused))
	_check("archive pauses and takes visible mouse only once", archive.try_open()
		and not archive.try_open() and get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await get_tree().process_frame
	_check("archive initially shows diary with a focusable tab bar", archive._diary.is_visible_in_tree()
		and not archive._codex.is_visible_in_tree() and archive._diary._pages[0].unlocked
		and not archive._diary._pages[1].unlocked and archive._tabs[0].has_focus()
		and archive._tabs[0].text == "01 心象日记" and archive._tabs[1].text == "02 赐福图鉴")
	_send_action(&"ui_right")
	_send_action(&"ui_accept")
	_check("direction and accept input switch to the codex tab", archive._tabs[1].has_focus()
		and archive._codex.is_visible_in_tree() and not archive._diary.is_visible_in_tree())
	var codex := archive._codex
	var topology := codex._topology
	_check("null manager renders four nodes and six selectable resonance routes",
		topology._nodes.size() == 4 and topology._edges.size() == 6 and topology.cores.is_empty()
		and not topology.eligible.values().has(true))
	var all_cards := {}
	for page in 5:
		codex._tabs[page].pressed.emit()
		var known_count := 0
		var unknown_count := 0
		for id: String in codex._buttons:
			var button := codex._buttons[id] as Button
			all_cards[id] = true
			known_count += int(known.has(id) and button.text.contains("已发现"))
			unknown_count += int(not known.has(id) and button.text.contains("未发现"))
		var expected_count := 6 if page == 0 else 12
		_check("codex page %d shows %d cards with discovery states" % [page, expected_count],
			known_count == 1 and unknown_count == expected_count - 1)
	_check("all 54 card IDs are unique across the displayed pages", all_cards.size() == 54)
	var edge := topology._edges[known[0]] as Button
	edge.pressed.emit()
	_check("topology opens a real dual card and its prerequisites", codex._selected.id == known[0]
		and codex._detail_status.text == "已发现" and not codex._requirements.text.is_empty())
	archive._tabs[1].grab_focus()
	_send_joy_button(JOY_BUTTON_DPAD_LEFT)
	_send_joy_button(JOY_BUTTON_A)
	await get_tree().process_frame
	_check("gamepad switches back to diary and keeps tab focus", archive._diary.is_visible_in_tree()
		and not archive._codex.is_visible_in_tree() and archive._tabs[0].has_focus()
		and archive._tabs[0].button_pressed and not archive._tabs[1].button_pressed)
	_send_escape()
	_check("Escape closes archive and restores input before emitting closed", closes == [false]
		and not archive.visible and not get_tree().paused and Input.mouse_mode == previous_mouse)
	get_tree().paused = true
	archive.try_open()
	_send_escape()
	_check("closing preserves a pause acquired by the host", closes == [false, true]
		and get_tree().paused and Input.mouse_mode == previous_mouse)
	get_tree().paused = false
	archive.try_open()
	archive.free()
	_check("removing an open archive restores input", not get_tree().paused and Input.mouse_mode == previous_mouse)
	var final_hash := FileAccess.get_sha256(MetaProgression.save_path()) if FileAccess.file_exists(MetaProgression.save_path()) else ""
	_check("archive leaves the whole profile and save file untouched", writes.is_empty()
		and MetaProgression._payload() == profile and final_hash == saved_hash)
	MetaProgression.changed.disconnect(on_change)


func _test_realm_hud() -> void:
	MetaProgression.introduced_realms.assign([0, 1, 2, 3])
	RunState.fixture = RunFixture.by_id("FX-001")
	var stage := preload("res://maps/realms/sloth_2.tscn").instantiate() as RealmStage
	stage.campaign = true
	add_child(stage)
	var menu := stage.hud.pause_menu
	_check("fixture hides campaign title button and the room note", RunState.fixture != null
		and not menu._title_exit.visible and not menu._exit_note.visible and not menu.try_open())
	RunState.fixture = null
	var title_requests: Array[RealmStage] = []
	var hub_requests: Array[RealmStage] = []
	var retries: Array[RealmStage] = []
	stage.title_requested.connect(func(sender): title_requests.append(sender))
	stage.hub_requested.connect(func(sender): hub_requests.append(sender))
	stage.retry_requested.connect(func(sender): retries.append(sender))
	_check("campaign pause shows title exit and room checkpoint note", menu.try_open()
		and menu._title_exit.visible and menu._exit_note.visible
		and menu._exit_note.text == "进度已保存至本房间起点")
	menu._title_exit.pressed.emit()
	_check("campaign pause exit delegates to the stage and releases modal input", title_requests == [stage]
		and not menu.is_open() and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)

	stage.player.health.apply_damage(100000, Hitbox.BodyPart.BODY, null, {"true_damage": true})
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := stage.hud._death_panel
	var column := panel.get_child(0) as VBoxContainer
	var retry := column.get_child(1) as Button
	var hub := column.get_child(2) as Button
	_check("death panel preserves its VBox and first two children", panel.visible and panel.get_child_count() == 1
		and column.get_child_count() == 3 and column.get_child(0) == stage.hud._death_reason
		and retry.text.contains("重新挑战") and not stage.hud._death_reason.text.is_empty())
	_check("hub exit shows no forge hint with an empty wallet", hub.text == "返回静滞之门")
	MetaProgression.will_shards = MetaProgression.cost("resolve").x
	MetaProgression.changed.emit()
	_check("hub exit adds forge hint when a real upgrade is affordable", hub.text == "返回静滞之门 · 可锻造")
	retry.pressed.emit()
	hub.pressed.emit()
	_check("both death buttons emit the correct stage and distinct signals",
		retries == [stage] and hub_requests == [stage] and title_requests == [stage])
	_check("HUD exits leave campaign routing to their subscribers", not RunDirector.active)
	stage.queue_free()
	await get_tree().process_frame


func _send_action(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)


func _send_escape() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	get_viewport().push_input(event)


func _send_joy_button(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		get_viewport().push_input(event)


func _check(label: String, ok: bool) -> void:
	_checks += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
