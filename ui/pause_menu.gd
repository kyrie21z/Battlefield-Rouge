class_name PauseMenu
extends Control
## Esc menu with the look, crosshair and key-binding settings on two tabs. It
## pauses the tree, releases the mouse and saves on close. It refuses while
## another screen owns the pause (run-end), under a fixture and headless (tests
## opt in with `allow_headless`); it may open over the buff-select screen, and
## closing there keeps the pause so the choice stays in control.

static var allow_headless := false

var capture_requests := 0
var _settings: GameSettings
var _player: Player
var _director: ZoneDirector
var _open := false
## Whether the tree was already paused when the menu opened (buff screen).
var _was_paused := false
var _prev_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _updating := false
var _preview: Crosshair
var _style: OptionButton
var _dynamic: CheckButton
var _colors: Array[Button] = []
var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _fields: Dictionary = {}
var _settings_box: VBoxContainer
var _bindings_box: VBoxContainer
var _tab_settings: Button
var _tab_bindings: Button
var _status: Label
var _bind_buttons: Dictionary = {}
var _awaiting_action := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func setup(settings: GameSettings, player: Player, director: ZoneDirector) -> void:
	_settings = settings
	_player = player
	_director = director
	_refresh()


func is_open() -> bool:
	return _open


func try_open() -> bool:
	if _open or not _can_open():
		return false
	_open = true
	visible = true
	_was_paused = get_tree().paused
	_prev_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if not _awaiting_action.is_empty():
		_end_capture()
	if _settings != null and (DisplayServer.get_name() != "headless" or allow_headless):
		_settings.save_to(GameSettings.settings_path)
	if _was_paused:
		# Opened over the buff screen: it stays paused with the mouse visible.
		return
	get_tree().paused = false
	capture_requests += 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _can_open() -> bool:
	# Paused outside a buff selection means the run-end screen owns the pause.
	if get_tree().paused and (_director == null or _director.phase != ZoneDirector.Phase.BUFF_SELECT):
		return false
	if RunState.fixture != null:
		return false
	if DisplayServer.get_name() == "headless" and not allow_headless:
		return false
	if _player == null or _player.health.is_dead():
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if _open:
		if event.is_action_pressed("pause"):
			close()
			get_viewport().set_input_as_handled()
		elif (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
			# Keys or clicks that fell through the panel must not reach the
			# buff screen's 1/2/3 or anything else behind the menu.
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and try_open():
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if not _awaiting_action.is_empty():
		if event is InputEventKey and event.is_echo():
			return
		if event is InputEventMouseButton and event.is_pressed():
			var clicked := _bind_button_at((event as InputEventMouseButton).position)
			if not clicked.is_empty() and clicked != _awaiting_action:
				# A click on another binding row switches the capture target
				# instead of binding the mouse button that clicked it.
				_end_capture()
				_on_bind_pressed(clicked)
				get_viewport().set_input_as_handled()
				return
		if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
			_capture_binding(event)
			get_viewport().set_input_as_handled()
		return
	# While the menu is open, keys never get past it (mouse buttons are stopped
	# by the panel and the dim layer); Esc passes on to close the menu.
	if event is InputEventKey and event.is_pressed() and not event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()


## The binding row under a viewport position, or "" when none is hit.
func _bind_button_at(pos: Vector2) -> String:
	for action: String in _bind_buttons:
		var button := _bind_buttons[action] as Button
		if button.get_global_rect().has_point(pos):
			return action
	return ""


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -450.0
	panel.offset_top = -470.0
	panel.offset_right = 450.0
	panel.offset_bottom = 470.0
	var style := StyleBoxFlat.new()
	# Nearly opaque: the buff cards must not show through the menu.
	style.bg_color = Color(HudStyle.DARK, 0.98)
	style.border_color = HudStyle.PANEL_LINE
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	box.add_child(_text("暂停", 40, HudStyle.TEXT))
	box.add_child(_text("Esc 继续游戏 · 设置改动立即生效，关闭时保存", 20, HudStyle.MUTED))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for row in [["设置", false], ["按键绑定", true]]:
		var tab := Button.new()
		tab.text = row[0]
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size = Vector2(180.0, 42.0)
		tab.add_theme_font_size_override("font_size", 22)
		tab.add_theme_color_override("font_pressed_color", HudStyle.ACCENT)
		var is_bindings: bool = row[1]
		tab.button_pressed = not is_bindings
		tab.toggled.connect(_on_tab.bind(is_bindings))
		tabs.add_child(tab)
		if is_bindings:
			_tab_bindings = tab
		else:
			_tab_settings = tab
	box.add_child(tabs)

	_settings_box = VBoxContainer.new()
	_settings_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_box.add_theme_constant_override("separation", 10)
	box.add_child(_settings_box)
	_build_settings(_settings_box)

	_bindings_box = VBoxContainer.new()
	_bindings_box.visible = false
	_bindings_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bindings_box.add_theme_constant_override("separation", 10)
	box.add_child(_bindings_box)
	_build_bindings(_bindings_box)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var reset := _button("恢复默认", 180.0)
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	var resume := _button("继续", 180.0)
	resume.pressed.connect(close)
	buttons.add_child(resume)
	box.add_child(buttons)


## The look-and-crosshair tab, the settings the menu had before the tabs.
func _build_settings(parent: VBoxContainer) -> void:
	var rows := [
		["mouse", "鼠标灵敏度", GameSettings.SENS_MIN, GameSettings.SENS_MAX, 0.05, "mouse_sensitivity"],
		["ads", "开镜灵敏度", GameSettings.ADS_MIN, GameSettings.ADS_MAX, 0.05, "ads_sensitivity"],
		["size", "准星大小", GameSettings.SIZE_MIN, GameSettings.SIZE_MAX, 0.05, "crosshair_size"],
		["thickness", "准星粗细", GameSettings.THICKNESS_MIN, GameSettings.THICKNESS_MAX, 0.5, "crosshair_thickness"],
		["alpha", "准星透明度", GameSettings.ALPHA_MIN, GameSettings.ALPHA_MAX, 0.05, "crosshair_alpha"],
		["music", "音乐音量", 0.0, 1.0, 0.05, "music_volume"]]
	for row in rows:
		_slider(parent, row[0], row[1], row[2], row[3], row[4], row[5])

	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 12)
	var style_label := _text("准星样式", 22, HudStyle.TEXT)
	style_label.custom_minimum_size.x = 170.0
	_style = OptionButton.new()
	_style.custom_minimum_size = Vector2(260.0, 40.0)
	for name in GameSettings.STYLE_NAMES:
		_style.add_item(name)
	_style.item_selected.connect(func(index: int) -> void:
		if not _updating:
			_settings.crosshair_style = index
			_after())
	style_row.add_child(style_label)
	style_row.add_child(_style)
	parent.add_child(style_row)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 10)
	var color_label := _text("准星颜色", 22, HudStyle.TEXT)
	color_label.custom_minimum_size.x = 170.0
	color_row.add_child(color_label)
	for i in GameSettings.COLOR_PRESETS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(42.0, 36.0)
		button.tooltip_text = GameSettings.COLOR_NAMES[i]
		button.pressed.connect(_on_color.bind(i))
		color_row.add_child(button)
		_colors.append(button)
	parent.add_child(color_row)

	_dynamic = CheckButton.new()
	_dynamic.text = "动态准星（随扩散张开）"
	_dynamic.add_theme_color_override("font_color", HudStyle.TEXT)
	_dynamic.toggled.connect(func(on: bool) -> void:
		if not _updating:
			_settings.dynamic_gap = on
			_after())
	parent.add_child(_dynamic)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 16)
	preview_row.add_child(_text("准星预览", 22, HudStyle.MUTED))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(160.0, 150.0)
	_preview = Crosshair.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_preview)
	preview_row.add_child(holder)
	parent.add_child(preview_row)


## The key-binding tab: two columns of label + button rows, every action on
## screen at once (no scrolling).
func _build_bindings(parent: VBoxContainer) -> void:
	var hint := _text("点击后按下新按键或鼠标键 · Esc 取消 · 与其它动作冲突时自动互换", 20, HudStyle.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)
	_status = _text("", 20, HudStyle.ACCENT)
	parent.add_child(_status)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(columns)
	var grid: Array[VBoxContainer] = [VBoxContainer.new(), VBoxContainer.new()]
	for column in grid:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 6)
		columns.add_child(column)
	for i in KeyBindings.REBINDABLE.size():
		var row: Array = KeyBindings.REBINDABLE[i]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var label := _text(row[1], 22, HudStyle.TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.custom_minimum_size = Vector2(170.0, 38.0)
		button.add_theme_font_size_override("font_size", 20)
		var action: String = row[0]
		button.pressed.connect(_on_bind_pressed.bind(action))
		line.add_child(label)
		line.add_child(button)
		grid[0 if i < 8 else 1].add_child(line)
		_bind_buttons[action] = button


func _on_tab(on: bool, bindings: bool) -> void:
	if _settings_box == null or _bindings_box == null:
		return
	_settings_box.visible = not (bindings and on)
	_bindings_box.visible = bindings and on


func _text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 48.0)
	return button


func _slider(parent: VBoxContainer, key: String, text: String, min_value: float,
		max_value: float, step: float, field: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _text(text, 22, HudStyle.TEXT)
	label.custom_minimum_size.x = 170.0
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size.x = 240.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := _text("", 20, HudStyle.MUTED)
	value.custom_minimum_size.x = 62.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value)
	parent.add_child(row)
	_sliders[key] = slider
	_labels[key] = value
	_fields[key] = field
	slider.value_changed.connect(func(v: float) -> void:
		if _updating:
			return
		_settings.set(field, v)
		value.text = _format(key, v)
		_after())


func _after() -> void:
	_settings.clamp_values()
	_settings.changed.emit()
	_update_preview()
	_update_colors()


func _on_color(index: int) -> void:
	_settings.crosshair_color = GameSettings.COLOR_PRESETS[index]
	_after()


func _on_reset() -> void:
	_settings.reset_defaults()
	KeyBindings.apply(_settings.bindings)
	_set_status("", HudStyle.ACCENT)
	_refresh()


func _on_bind_pressed(action: String) -> void:
	if not _awaiting_action.is_empty():
		_end_capture()
	_awaiting_action = action
	(_bind_buttons[action] as Button).text = "按下按键…"
	_set_status("", HudStyle.ACCENT)


## The next key or mouse press while waiting: Esc cancels, reserved inputs are
## refused, anything bindable lands on the action (swapping on conflict).
func _capture_binding(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_end_capture()
		_set_status("已取消", HudStyle.MUTED)
		return
	if not KeyBindings.can_bind(event):
		_set_status("该按键被保留（Esc / F3 / 滚轮），请换一个", HudStyle.WARNING)
		return
	var action := _awaiting_action
	var swapped := KeyBindings.assign(_settings.bindings, action, event)
	_end_capture()
	KeyBindings.apply(_settings.bindings)
	if not swapped.is_empty():
		_set_status("已与「%s」互换" % _label_of(swapped), HudStyle.ACCENT)
	else:
		_set_status("", HudStyle.ACCENT)
	_settings.changed.emit()
	_refresh_bindings()


func _end_capture() -> void:
	_awaiting_action = ""
	_refresh_bindings()


func _refresh_bindings() -> void:
	if _bind_buttons.is_empty():
		return
	for action: String in _bind_buttons:
		(_bind_buttons[action] as Button).text = KeyHint.of(action)


func _set_status(text: String, color: Color) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _label_of(action: String) -> String:
	for row in KeyBindings.REBINDABLE:
		if row[0] == action:
			return row[1]
	return action


func _refresh() -> void:
	if _settings == null or _sliders.is_empty():
		return
	_updating = true
	for key in _sliders:
		var value: float = _settings.get(_fields[key])
		(_sliders[key] as HSlider).value = value
		(_labels[key] as Label).text = _format(key, value)
	_style.selected = _settings.crosshair_style
	_dynamic.button_pressed = _settings.dynamic_gap
	_update_colors()
	_update_preview()
	_refresh_bindings()
	_updating = false


func _format(key: String, value: float) -> String:
	if key == "music":
		return "%d%%" % roundi(value * 100.0)
	return "%.1f px" % value if key == "thickness" else "%.2f" % value


func _update_colors() -> void:
	for i in _colors.size():
		var chosen: bool = _settings.crosshair_color == GameSettings.COLOR_PRESETS[i]
		var style := StyleBoxFlat.new()
		style.bg_color = GameSettings.COLOR_PRESETS[i]
		style.border_color = HudStyle.ACCENT if chosen else Color(0.0, 0.0, 0.0, 0.5)
		style.set_border_width_all(3 if chosen else 1)
		_colors[i].add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.border_color = Color(0.85, 0.95, 1.0)
		_colors[i].add_theme_stylebox_override("hover", hover)


func _update_preview() -> void:
	if _preview == null or _settings == null:
		return
	_preview.style = _settings.crosshair_style
	_preview.line_length = 5.0 * _settings.crosshair_size
	_preview.thickness = _settings.crosshair_thickness
	_preview.color = Color(_settings.crosshair_color, _settings.crosshair_alpha)
	_preview.show_lines = true
	_preview.gap = _preview.min_gap
	_preview.pivot_offset = Vector2(80.0, 75.0)
	_preview.scale = Vector2(3.0, 3.0)
	_preview.queue_redraw()
