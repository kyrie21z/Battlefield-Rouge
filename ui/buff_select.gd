extends CanvasLayer
## A paused, single-choice offer. Players can keep one school or mix upgrades.

signal chosen(buff: Buff)

const TEXT := Color("e9eff7")
const MUTED := Color("a8b8ce")

var _selected := false
var _offered: Array[Buff] = []

@onready var _choices: HBoxContainer = $Center/Box/Choices
@onready var _title: Label = $Center/Box/Title
@onready var _owned: Label = $Center/Box/Owned


func setup(buffs: Array[Buff], context: String = "选择本局增益") -> void:
	if _selected:
		return
	_title.text = context
	_offered.assign(buffs)
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for i in buffs.size():
		_choices.add_child(_make_choice(buffs[i], i))
	_refresh_owned()
	if _choices.get_child_count() > 0:
		_choices.get_child(0).grab_focus()


func _ready() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_school_directions()
	_refresh_owned()


func _make_choice(buff: Buff, index: int) -> Button:
	var school := SchoolCatalog.find(buff.school_id)
	var accent := school.accent if school != null else Color("91a9cf")
	var button := Button.new()
	button.name = "Choice%d" % (index + 1)
	button.custom_minimum_size = Vector2(430, 520)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s：%s" % [buff.title, buff.description]
	button.add_theme_stylebox_override("normal", _card(Color("162133"), accent.darkened(0.52)))
	button.add_theme_stylebox_override("hover", _card(Color("22334b"), accent))
	button.add_theme_stylebox_override("focus", _card(Color("203049"), accent))
	button.add_theme_stylebox_override("pressed", _card(Color("2b405c"), accent.lightened(0.25)))
	button.pressed.connect(_choose.bind(buff))

	var content := VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 12)
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 28
	content.offset_top = 24
	content.offset_right = -28
	content.offset_bottom = -24

	content.add_child(_label("[ %d ]   %s" % [index + 1, school.title if school != null else "本局增益"], 23, accent))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = buff.icon
	icon.custom_minimum_size = Vector2(104, 104)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	content.add_child(_label(buff.title, 32, TEXT))
	var description := _label(buff.description, 23, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 86
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(description)
	var stacks := _stack_count(buff)
	var stack_text := "本局未获得  →  选择后 1 层" if stacks == 0 \
		else "本局已有 %d 层  →  选择后 %d 层" % [stacks, stacks + 1]
	content.add_child(_label(stack_text, 21, accent))
	return button


## Shared identity badges also support the existing icon comparison scene.
func _show_school_directions() -> void:
	var box := $Center/Box as VBoxContainer
	var block := VBoxContainer.new()
	block.name = "Schools"
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	for school in SchoolCatalog.all():
		var badge := SchoolBadge.new()
		badge.setup(school)
		badge.custom_minimum_size.x = 360
		row.add_child(badge)
	block.add_child(row)
	box.add_child(block)
	box.move_child(block, 2)


func _refresh_owned() -> void:
	var counts: Dictionary = {}
	var titles: Dictionary = {}
	for buff: Buff in RunState.buffs:
		var key := _buff_key(buff)
		counts[key] = int(counts.get(key, 0)) + 1
		titles[key] = buff.title
	var parts: PackedStringArray = []
	for key: String in counts:
		parts.append("%s ×%d" % [titles[key], counts[key]])
	_owned.text = "本局构筑：" + "  /  ".join(parts) if not parts.is_empty() \
		else "本局构筑：尚未获得增益，从任一流派开始。"


func _stack_count(buff: Buff) -> int:
	var count := 0
	for owned: Buff in RunState.buffs:
		if _buff_key(owned) == _buff_key(buff):
			count += 1
	return count


func _buff_key(buff: Buff) -> String:
	return String(buff.id) if buff.id != &"" else buff.resource_path + buff.title


func _unhandled_input(event: InputEvent) -> void:
	if _selected:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < _offered.size():
			get_viewport().set_input_as_handled()
			_choose(_offered[index])


func _card(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	return style


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _choose(buff: Buff) -> void:
	# Lock before emitting so multiple input events in one frame apply only once.
	if _selected or not _offered.has(buff):
		return
	_selected = true
	for button: Button in _choices.get_children():
		button.disabled = true
	get_viewport().set_input_as_handled()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chosen.emit(buff)
	queue_free()
