extends Node
## AC-08 board of the nine actual card icons, then the live selection screen.
## Needs a display (same as tests/capture_proof.gd). From the project root:
##   godot --path . res://tests/school_icons_proof.tscn -- --out=<dir>

const PLATE := Color("1e2430")
const TEXT := Color("e7eaef")

var _out := "res://docs/proof/ac-04-ac-08"
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("Visual proof requires a native display")
		get_tree().quit(1)
		return
	_out = ProjectSettings.globalize_path(_out)
	if DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("Cannot create visual proof output directory")
		get_tree().quit(1)
		return
	await _run()
	print("SCHOOL ICONS VISUAL: %d failed" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = PLATE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	# A CanvasLayer supplies no Control layout rect, so size this plate from
	# the actual viewport instead of relying on anchors alone.
	bg.position = Vector2.ZERO
	bg.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(func(): bg.size = get_viewport().get_visible_rect().size)

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

	var title := _label("AC-08  三类加持 · 九条增益", 48, TEXT)
	root.add_child(title)
	var sub := _label("枪械加持、刀具加持、技能获得；每类三条独立增益。", 22, TEXT)
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
	await _shot("01_nine_buff_icons")

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
	BuffPool.reset(606)
	select.setup(BuffPool.pick(3), "进入小关 1 前：选择一个增益")
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

	for buff: Buff in BuffPool.for_school(school.id):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(500, 120)
		row.add_theme_constant_override("separation", 18)
		var icon := TextureRect.new()
		icon.texture = buff.icon
		icon.custom_minimum_size = Vector2(112, 112)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		var heading := _label(buff.title, 24, school.accent)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		words.add_child(heading)
		var description := _label(buff.description, 17, TEXT)
		description.custom_minimum_size.x = 360
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(description)
		row.add_child(words)
		col.add_child(row)
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
	var result := get_viewport().get_texture().get_image().save_png(path)
	if result != OK:
		_failures += 1
	print("== %s -> %s" % [shot_name, path])
