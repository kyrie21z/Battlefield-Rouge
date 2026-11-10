extends Control
func _ready()->void:
	get_tree().paused=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var background:=ColorRect.new()
	background.color=Color("e7e5de")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",30)
	center.add_child(box)
	var title:=Label.new()
	title.text="MIND FREAK\n不再完美，但终于完整。"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",32)
	title.add_theme_color_override("font_color",Color("30343a"))
	box.add_child(title)
	var start:=Button.new()
	start.text="开启新的挑战"
	start.pressed.connect(func():RunDirector.begin_run();get_tree().change_scene_to_file("res://ui/game_start.tscn"))
	box.add_child(start)
	var quit_button:=Button.new()
	quit_button.text="退出"
	quit_button.pressed.connect(func():get_tree().quit())
	box.add_child(quit_button)
