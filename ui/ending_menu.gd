extends Control
## Epilogue menu (Scheme B: Architectural Editorial gallery poster).

var _archive_reader: Control
var _archive_button: Button
var _menu_box: Control


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EditorialStyle.apply_theme(self)

	var background := ColorRect.new()
	background.color = EditorialStyle.PAPER
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(600, 0)
	var style := EditorialStyle.plaque(Color("ffffff"), EditorialStyle.INK, 2, Vector2(10, 10), Color(EditorialStyle.INK, 0.90), 54, 46)
	style.border_width_top = 8
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)
	_menu_box = frame

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	frame.add_child(box)

	var eye_wrap := CenterContainer.new()
	box.add_child(eye_wrap)
	eye_wrap.add_child(EditorialStyle.make_eyebrow("MIND FREAK   //   EPILOGUE", 13))

	var title := EditorialStyle.make_label("不再完美，但终于完整。", 34, EditorialStyle.INK, 800, false, 3)
	title.add_theme_font_override("font", EditorialStyle.font_serif(700))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := EditorialStyle.make_label("FROM PERFECTION TO WHOLENESS", 13, EditorialStyle.SLATE, 700, true, 3)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	box.add_child(EditorialStyle.make_rule(EditorialStyle.PAPER_DIM, 2))

	var start := Button.new()
	start.text = "开启新的挑战  →"
	start.custom_minimum_size = Vector2(360, 56)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	EditorialStyle.style_button(start, true, true, 20)
	start.pressed.connect(_start_new_challenge)
	box.add_child(start)

	var hub_button := Button.new()
	hub_button.text = "返回静滞之门"
	hub_button.custom_minimum_size = Vector2(360, 48)
	hub_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	EditorialStyle.style_button(hub_button, false, true, 18)
	hub_button.pressed.connect(_start_new_challenge)
	box.add_child(hub_button)

	_archive_button = Button.new()
	_archive_button.text = "心象日记"
	_archive_button.custom_minimum_size = Vector2(360, 52)
	_archive_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	EditorialStyle.style_button(_archive_button, false, true, 19)
	_archive_button.pressed.connect(_open_archive)
	box.add_child(_archive_button)

	var title_button := Button.new()
	title_button.text = "返回标题画面"
	title_button.custom_minimum_size = Vector2(360, 48)
	title_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	EditorialStyle.style_button(title_button, false, true, 18)
	title_button.pressed.connect(RunDirector.return_to_title, CONNECT_DEFERRED)
	box.add_child(title_button)

	var quit_button := Button.new()
	quit_button.text = "退出"
	quit_button.custom_minimum_size = Vector2(360, 48)
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	EditorialStyle.style_button(quit_button, false, true, 18)
	quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_button)

	start.grab_focus()


func _start_new_challenge() -> void:
	RunDirector.enter_hub.call_deferred("epilogue")


func _open_archive() -> void:
	if is_instance_valid(_archive_reader):
		return
	var reader := load("res://ui/codex/archive_reader.gd").new() as Control
	reader.set("archive", MetaProgression.archive_snapshot())
	reader.connect("closed", _close_archive)
	_archive_reader = reader
	_menu_box.hide()
	add_child(reader)


func _close_archive() -> void:
	if is_instance_valid(_archive_reader):
		_archive_reader.queue_free()
	_archive_reader = null
	_menu_box.show()
	_archive_button.grab_focus()
