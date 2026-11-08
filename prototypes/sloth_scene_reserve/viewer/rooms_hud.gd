extends "res://viewer_hud.gd"
## Review controls for the two room variants, confined to the reserve viewer.
var room_title: Label
var room_description: Label
var room_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	for child in _root.find_children("*", "Label", true, false):
		if child.text == "云上静滞圣殿": room_title = child
	var choices := HBoxContainer.new()
	choices.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	choices.position = Vector2(-214,32)
	choices.add_theme_constant_override("separation",10)
	_root.add_child(choices)
	for i in range(2):
		var button := Button.new()
		button.text = ["F1 · 第一关", "F2 · 第二关"][i]
		button.custom_minimum_size = Vector2(176,40)
		button.add_theme_font_size_override("font_size",16)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): get_parent().set_room(i))
		choices.add_child(button)
		room_buttons.append(button)
	room_description = _label("",13,Color("d5e1e4"))
	room_description.position = Vector2(34,164)
	room_description.add_theme_color_override("font_shadow_color",Color("233d4d"))
	room_description.add_theme_constant_override("shadow_offset_y",1)
	_root.add_child(room_description)

func set_room_name(title: String, description: String) -> void:
	if room_title != null: room_title.text = title
	if room_description != null: room_description.text = description
	for i in range(room_buttons.size()):
		room_buttons[i].modulate = Color("e5c88f") if get_parent().room_index==i else Color.WHITE
