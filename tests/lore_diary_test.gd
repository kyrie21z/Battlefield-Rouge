extends Node
var checks := 0
var failures := 0
var diary: LoreDiary

func _ready() -> void:
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(2))
	check("autoload selected an isolated profile before this scene", MetaProgression.isolated_profile and MetaProgression.save_path() != MetaProgressionStore.SAVE_PATH)
	var archive := {"visited_realms": [], "defeated_realms": [], "reconciled": false}
	var snapshot := archive.duplicate(true)
	var paused := get_tree().paused
	var mouse := Input.mouse_mode
	diary = preload("res://ui/codex/lore_diary.tscn").instantiate()
	diary.setup(archive) # Injection is also valid before _ready.
	add_child(diary)
	await frames()
	check("five locked diary slots and four locked dossier slots", LoreEntries.project(archive).size() == 5 and LoreEntries.project(archive, true).size() == 4)
	check("empty archive exposes no authored bodies or titles", no_unearned_copy(archive))
	check("projection and UI never mutate the injected archive", archive == snapshot)
	for realm in [3, 1, 0, 2]:
		archive.visited_realms.append(realm)
		diary.refresh()
		var diaries := LoreEntries.project(archive)
		var dossiers := LoreEntries.project(archive, true)
		check("visit %d unlocks its diary and crown voice only" % realm, diaries[realm].body == LoreEntries.DIARIES[realm].body and dossiers[realm].crown == LoreEntries.DOSSIERS[realm].crown and dossiers[realm].human.is_empty() and dossiers[realm].value.is_empty())
		check("visit %d cannot leak any future copy through pages/tooltips" % realm, no_unearned_copy(archive))
		archive.defeated_realms.append(realm)
		diary.refresh()
		check("defeat %d reveals corresponding human value" % realm, LoreEntries.project(archive, true)[realm].human == LoreEntries.DOSSIERS[realm].human)
		check("defeat %d leaves other gates intact" % realm, no_unearned_copy(archive))
	check("all four defeats still cannot open the ending", LoreEntries.project(archive)[4].body.is_empty())
	archive.reconciled = true
	diary.refresh()
	diary._change_section(false)
	diary._select(4)
	await frames()
	check("reconciliation displays the entire final first-person diary", all_text(diary).contains(LoreEntries.DIARIES[4].body) and diary._count.text.begins_with("05 / 05"))
	check("public copy never names Pride", not all_text(diary).contains("Pride"))
	await input_checks()
	# A fresh/replaced profile must remove all previously displayed authored text.
	diary.setup({})
	await frames()
	check("profile replacement scrubs previously unlocked ending", no_unearned_copy({}) and not all_text(diary).contains(LoreEntries.DIARIES[4].title) and diary._buttons[4].text.is_empty())
	check("a defeat alone is not inferred to be a visit", no_unearned_copy({"defeated_realms": [0, 1, 2, 3]}))
	check("reader does not own pause or mouse capture", get_tree().paused == paused and Input.mouse_mode == mouse)
	diary.free()
	await frames()
	print("LORE DIARY: %d checks, %d failed" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func no_unearned_copy(archive: Dictionary) -> bool:
	var visited: Array = archive.get("visited_realms", [])
	var defeated: Array = archive.get("defeated_realms", [])
	var final_open := bool(archive.get("reconciled", false))
	for dossier in [false, true]:
		diary.setup(archive)
		diary._change_section(dossier)
		for index in diary._pages.size():
			diary._select(index)
			var text := all_text(diary)
			for realm in 4:
				if not visited.has(realm):
					if text.contains(LoreEntries.DIARIES[realm].body) or text.contains(LoreEntries.DIARIES[realm].title) or text.contains(LoreEntries.DOSSIERS[realm].crown):
						return false
				if not visited.has(realm) or not defeated.has(realm):
					if text.contains(LoreEntries.DOSSIERS[realm].human) or text.contains(LoreEntries.DOSSIERS[realm].value):
						return false
			if not final_open and (text.contains(LoreEntries.DIARIES[4].body) or text.contains(LoreEntries.DIARIES[4].title)):
				return false
	return true

func input_checks() -> void:
	# Force real local sizes rather than relying on the project's canvas stretch.
	for dimensions in [Vector2(1280, 720), Vector2(1920, 1080)]:
		diary.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		diary.size = dimensions
		diary._change_section(false)
		diary._select(4)
		await frames(5)
		check("%s keeps directory and reader within the page" % dimensions, within(diary._nav) and within(diary._reader) and within(diary._footer) and diary._reader.size.x > 600)
		check("%s wraps body without horizontal overflow" % dimensions, diary._paper.size.x <= diary._reader.size.x + 1 and diary._reader.get_h_scroll_bar().max_value <= diary._reader.size.x + 1)
		diary._reader.grab_focus()
		await press_action("ui_end")
		check("%s End reaches final line through local scroll input" % dimensions, diary._reader.scroll_vertical > 0)
		await press_action("ui_home")
		check("%s Home returns to the top" % dimensions, diary._reader.scroll_vertical == 0)
	diary._buttons[0].grab_focus()
	await press_action("ui_right")
	check("keyboard direction enters reading pane", diary._reader.has_focus())
	await press_action("ui_left")
	check("keyboard direction returns to selected entry", diary._buttons[4].has_focus())
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_DPAD_UP
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event.pressed = false
	Input.parse_input_event(event)
	check("gamepad D-pad navigates directory", diary._buttons[3].has_focus())
	event = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()
	check("gamepad confirm selects the focused entry", diary._selected == 3)
	# The newly selected short diary fits at 1080p; use the long ending for scroll.
	diary._select(4)
	await press_action("ui_right")
	await press_action("ui_end")
	check("gamepad reading pane owns focus", diary._reader.has_focus())
	event = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_DPAD_UP
	event.pressed = true
	var before := diary._reader.scroll_vertical
	Input.parse_input_event(event)
	await frames()
	event.pressed = false
	Input.parse_input_event(event)
	check("gamepad D-pad scrolls the reading pane", before > diary._reader.scroll_vertical)
	await press_action("ui_left")
	for index in 5:
		await press_action("ui_up")
	check("directory can return focus to section tabs without a mouse", diary._tabs[0].has_focus())
	await press_action("ui_right")
	check("directional focus reaches the dossier tab", diary._tabs[1].has_focus())
	event = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()
	check("gamepad confirm switches diary/dossier sections", diary._dossier and diary._pages.size() == 4)

func within(control: Control) -> bool:
	var rect := Rect2(control.global_position - diary.global_position, control.size)
	return Rect2(Vector2.ZERO, diary.size + Vector2.ONE).encloses(rect)

func press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func all_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += node.text + "\n"
	if node is Control:
		result += node.tooltip_text + "\n"
	for child in node.get_children():
		result += all_text(child)
	return result

func frames(count: int = 3) -> void:
	for index in count:
		await get_tree().process_frame

func check(description: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("[PASS] " if passed else "[FAIL] ", description)
