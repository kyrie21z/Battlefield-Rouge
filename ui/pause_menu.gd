class_name PauseMenu
extends Control
## Esc menu with the look and crosshair settings inline. It pauses the tree,
## releases the mouse and saves on close. It refuses while another screen owns
## the pause, under a fixture and headless (tests opt in with `allow_headless`).

static var allow_headless := false

var capture_requests := 0
var _settings: GameSettings
var _player: Player
var _director: ZoneDirector
var _open := false
var _updating := false
var _preview: Crosshair
var _style: OptionButton
var _dynamic: CheckButton
var _colors: Array[Button] = []
var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _fields: Dictionary = {}


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
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _settings != null and (DisplayServer.get_name() != "headless" or allow_headless):
		_settings.save_to(GameSettings.settings_path)
	get_tree().paused = false
	capture_requests += 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _can_open() -> bool:
	if get_tree().paused or RunState.fixture != null:
		return false
	if DisplayServer.get_name() == "headless" and not allow_headless:
		return false
	if _player == null or _player.health.is_dead():
		return false
	return _director == null or _director.phase != ZoneDirector.Phase.BUFF_SELECT


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause"):
		return
	if _open:
		close()
		get_viewport().set_input_as_handled()
	elif try_open():
		get_viewport().set_input_as_handled()


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
	panel.offset_left = -410.0
	panel.offset_top = -370.0
	panel.offset_right = 410.0
	panel.offset_bottom = 370.0
	var style := StyleBoxFlat.new()
	style.bg_color = HudStyle.DARK
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
	var rows := [
		["mouse", "鼠标灵敏度", GameSettings.SENS_MIN, GameSettings.SENS_MAX, 0.05, "mouse_sensitivity"],
		["ads", "开镜灵敏度", GameSettings.ADS_MIN, GameSettings.ADS_MAX, 0.05, "ads_sensitivity"],
		["size", "准星大小", GameSettings.SIZE_MIN, GameSettings.SIZE_MAX, 0.05, "crosshair_size"],
		["thickness", "准星粗细", GameSettings.THICKNESS_MIN, GameSettings.THICKNESS_MAX, 0.5, "crosshair_thickness"],
		["alpha", "准星透明度", GameSettings.ALPHA_MIN, GameSettings.ALPHA_MAX, 0.05, "crosshair_alpha"]]
	for row in rows:
		_slider(box, row[0], row[1], row[2], row[3], row[4], row[5])

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
	box.add_child(style_row)

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
	box.add_child(color_row)

	_dynamic = CheckButton.new()
	_dynamic.text = "动态准星（随扩散张开）"
	_dynamic.add_theme_color_override("font_color", HudStyle.TEXT)
	_dynamic.toggled.connect(func(on: bool) -> void:
		if not _updating:
			_settings.dynamic_gap = on
			_after())
	box.add_child(_dynamic)

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
	box.add_child(preview_row)

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
	_refresh()


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
	_updating = false


func _format(key: String, value: float) -> String:
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
