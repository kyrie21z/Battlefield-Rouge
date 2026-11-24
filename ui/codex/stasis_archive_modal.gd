class_name StasisArchiveModal
extends Control
## Displays snapshots supplied by the hub and owns the modal input state.

signal closed

var _archive: Dictionary = {}
var _discovered: Array[String] = []
var _opened := false
var _was_paused := false
var _mouse_mode := Input.MOUSE_MODE_VISIBLE
var _previous_focus: Control
var _diary: LoreDiary
var _codex: DualBoonCodex
var _tabs: Array[Button] = []


func setup(archive: Dictionary, discovered: Array[String]) -> void:
	_archive = archive.duplicate(true)
	_discovered = discovered.duplicate()
	if is_node_ready():
		_diary.setup(_archive)
		_codex.setup(null, _discovered)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EditorialStyle.apply_theme(self)
	hide()

	var background := ColorRect.new()
	background.color = EditorialStyle.PAPER
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var shell := VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 0)
	add_child(shell)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", EditorialStyle.plaque(
		EditorialStyle.INK, EditorialStyle.INK, 0, Vector2.ZERO, Color.TRANSPARENT, 28, 16))
	shell.add_child(header)

	var heading := HBoxContainer.new()
	header.add_child(heading)
	var title := EditorialStyle.make_label("静滞档案", 28, EditorialStyle.PAPER, 800, false, 2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var back := Button.new()
	back.text = "返回  ·  ESC"
	back.custom_minimum_size = Vector2(180, 44)
	EditorialStyle.style_button(back, false, false, 17)
	back.pressed.connect(close)
	heading.add_child(back)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	shell.add_child(margin)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	margin.add_child(tab_row)
	var titles := ["01 心象日记", "02 赐福图鉴"]
	var group := ButtonGroup.new()
	for index in titles.size():
		var tab := Button.new()
		tab.text = titles[index]
		tab.custom_minimum_size = Vector2(180, 42)
		tab.toggle_mode = true
		tab.button_group = group
		EditorialStyle.style_tab(tab, true, 18)
		tab.pressed.connect(_show_page.bind(index))
		tab_row.add_child(tab)
		_tabs.append(tab)
	_tabs[0].focus_neighbor_right = _tabs[0].get_path_to(_tabs[1])
	_tabs[1].focus_neighbor_left = _tabs[1].get_path_to(_tabs[0])

	shell.add_child(EditorialStyle.make_rule(EditorialStyle.PAPER_DIM, 2))
	_diary = LoreDiary.new()
	_diary.setup(_archive)
	shell.add_child(_diary)
	_codex = DualBoonCodex.new()
	_codex.setup(null, _discovered)
	shell.add_child(_codex)


func try_open() -> bool:
	if _opened or not is_node_ready():
		return false
	_opened = true
	_was_paused = get_tree().paused
	_mouse_mode = Input.mouse_mode
	_previous_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page(0)
	show()
	_tabs[0].grab_focus.call_deferred()
	return true


func close() -> void:
	if not _opened:
		return
	hide()
	_restore_input()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	closed.emit()


func _exit_tree() -> void:
	if _opened:
		_restore_input()


func _restore_input() -> void:
	_opened = false
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode


func _show_page(index: int) -> void:
	_diary.visible = index == 0
	_codex.visible = index == 1
	_tabs[index].button_pressed = true
	if visible:
		_tabs[index].grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _opened and event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not _opened:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		var button := get_viewport().gui_get_focus_owner() as Button
		if is_instance_valid(button) and is_ancestor_of(button) and not button.disabled:
			button.pressed.emit()
