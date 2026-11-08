extends CanvasLayer
## Small, edge-aligned exhibition UI; Tab hides it for clean photographs.

var _root: Control
var _location: Label
var _mode: Label
var _status: Label
var _proof_mode := false
var _show_ui := true
var _flying := false


func _ready() -> void:
	name = "ViewerHUD"
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	panel.position = Vector2(32.0, 29.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.09, 0.12, 0.65)
	style.border_color = Color(0.75, 0.67, 0.46, 0.65)
	style.border_width_left = 2
	style.content_margin_left = 19.0
	style.content_margin_right = 24.0
	style.content_margin_top = 15.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	var eyebrow := _label("M I N D   F R E A K   /   S L O T H", 12, Color(0.82, 0.76, 0.58))
	stack.add_child(eyebrow)
	stack.add_child(_label("云上静滞圣殿", 25, Color(0.95, 0.96, 0.95)))
	_location = _label("01  /  初见巨环", 13, Color(0.72, 0.81, 0.84))
	stack.add_child(_location)
	var top_right := VBoxContainer.new()
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-240.0, 34.0)
	top_right.size = Vector2(208.0, 75.0)
	top_right.add_theme_constant_override("separation", 5)
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_right)
	var badge := _label("场景样板  ·  独立备用", 12, Color(0.9, 0.92, 0.9))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(badge)
	_mode = _label("步行漫游", 12, Color(0.74, 0.83, 0.86))
	_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(_mode)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 32.0
	footer.offset_top = -72.0
	footer.offset_right = -32.0
	footer.offset_bottom = -24.0
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = Color(0.035, 0.075, 0.1, 0.68)
	footer_style.content_margin_left = 16.0
	footer_style.content_margin_right = 16.0
	footer_style.content_margin_top = 10.0
	footer_style.content_margin_bottom = 10.0
	footer.add_theme_stylebox_override("panel", footer_style)
	_root.add_child(footer)
	var controls := HBoxContainer.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_theme_constant_override("separation", 16)
	footer.add_child(controls)
	var primary := _label("WASD 移动   Shift 加速   鼠标 / 方向键观察", 13, Color(0.86, 0.9, 0.9))
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(primary)
	controls.add_child(_label("1 – 4 观景点    F 飞行    Tab 隐藏界面    Esc 释放鼠标", 12, Color(0.75, 0.83, 0.85)))
	_status = _label("单击进入漫游  /  按住右键也可观察", 12, Color(0.87, 0.88, 0.82))
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status.position = Vector2(34.0, -99.0)
	_root.add_child(_status)
	_update_visibility()


func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _process(_delta: float) -> void:
	if _status == null:
		return
	if _flying:
		_status.text = "飞行：Space / E 上升   Ctrl / Q 下降   F 回到步行   R 回到入口"
	else:
		_status.text = "M 环境运动预览   L 光雾切换   R 回到入口" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "单击进入漫游  /  按住右键也可观察"


func set_location(value: String) -> void:
	if _location != null:
		_location.text = value


func set_mode(value: String) -> void:
	_flying = value == "自由飞行"
	if _mode != null:
		_mode.text = value


func toggle_visibility() -> void:
	_show_ui = not _show_ui
	_update_visibility()


func set_proof_mode(enabled: bool) -> void:
	_proof_mode = enabled
	_update_visibility()


func _update_visibility() -> void:
	if _root != null:
		_root.visible = _show_ui and not _proof_mode
