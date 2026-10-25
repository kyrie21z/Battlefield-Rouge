extends Node
## Comparison board for AC-06, then the same badges on the buff select screen.
## Needs a display (same as tests/capture_proof.gd). From the project root:
##   godot --path . res://tests/school_icons_proof.tscn -- --out=<dir>

const PLATE := Color("1e2430")
const TEXT := Color("e7eaef")

var _out := "user://proof"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	await _run()
	get_tree().quit()


func _run() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = PLATE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 28)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 72
	root.offset_top = 36
	root.offset_right = -72
	root.offset_bottom = -36

	var title := _label("AC-06  三个流派", 48, TEXT)
	root.add_child(title)
	var sub := _label("先看剪影，再看颜色。方向写在图标旁边。效果数值 Design-TBD。", 22, TEXT)
	root.add_child(sub)

	var cols := HBoxContainer.new()
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_theme_constant_override("separation", 40)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	for school in SchoolCatalog.all():
		cols.add_child(_column(school))

	for i in 3:
		await get_tree().process_frame
	await _shot("01_three_schools")

	layer.visible = false
	var sky := CanvasLayer.new()
	sky.layer = 0
	add_child(sky)
	var sky_fill := ColorRect.new()
	sky_fill.color = Color(0.62, 0.7, 0.76)
	sky.add_child(sky_fill)
	sky_fill.set_anchors_preset(Control.PRESET_FULL_RECT)

	var select := (load("res://ui/buff_select.tscn") as PackedScene).instantiate()
	add_child(select)
	var offered: Array[Buff] = []
	for i in 3:
		offered.append(BuffPool.ALL[i])
	select.setup(offered)
	for i in 3:
		await get_tree().process_frame
	await _shot("02_buff_select")


func _column(school: School) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var badge := SchoolBadge.new()
	badge.setup(school, 96)
	col.add_child(badge)

	var sizes := HBoxContainer.new()
	sizes.alignment = BoxContainer.ALIGNMENT_CENTER
	sizes.add_theme_constant_override("separation", 24)
	for px in [48, 32]:
		var bit := VBoxContainer.new()
		bit.alignment = BoxContainer.ALIGNMENT_CENTER
		bit.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.texture = school.icon
		icon.custom_minimum_size = Vector2(px, px)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bit.add_child(icon)
		bit.add_child(_label("%d px" % px, 16, TEXT))
		sizes.add_child(bit)
	col.add_child(sizes)
	var accent := school.accent.to_html(false).to_upper()
	var shade := school.shade.to_html(false).to_upper()
	col.add_child(_label("#%s  /  #%s" % [accent, shade], 18, school.accent))
	return col


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	print("== %s -> %s" % [shot_name, path])
