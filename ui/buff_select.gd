extends CanvasLayer
## Pauses the game and offers buffs as buttons. Emits `chosen` once.

signal chosen(buff: Buff)

@onready var _choices: HBoxContainer = $Center/Box/Choices


func setup(buffs: Array[Buff]) -> void:
	for i in buffs.size():
		var buff := buffs[i]
		var button := Button.new()
		button.text = "%d. %s\n\n%s" % [i + 1, buff.title, buff.description]
		button.custom_minimum_size = Vector2(280, 160)
		button.add_theme_font_size_override("font_size", 26)
		button.add_theme_stylebox_override("normal", _card(Color(0.12, 0.13, 0.15, 0.95)))
		button.add_theme_stylebox_override("hover", _card(Color(0.2, 0.32, 0.5, 0.95)))
		button.add_theme_stylebox_override("focus", _card(Color(0.2, 0.32, 0.5, 0.95)))
		button.add_theme_stylebox_override("pressed", _card(Color(0.25, 0.45, 0.7, 0.95)))
		button.pressed.connect(_choose.bind(buff))
		_choices.add_child(button)


func _ready() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_school_directions()


## Identity row for the three schools. Not a buff offer and not the 9-entry pool.
func _show_school_directions() -> void:
	var box := $Center/Box as VBoxContainer
	var block := VBoxContainer.new()
	block.name = "Schools"
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", 8)

	var caption := Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = "流派方向"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", SchoolBadge.TEXT)
	block.add_child(caption)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for school in SchoolCatalog.all():
		var badge := SchoolBadge.new()
		badge.setup(school)
		row.add_child(badge)
	block.add_child(row)

	box.add_child(block)
	box.move_child(block, 1)


func _unhandled_input(event: InputEvent) -> void:
	# Number keys 1-3 pick a buff too.
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < _choices.get_child_count():
			_choices.get_child(index).pressed.emit()


func _card(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	return style


func _choose(buff: Buff) -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chosen.emit(buff)
	queue_free()
