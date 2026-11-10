class_name ArchiveReader
extends Control
## Menu reader. No player, pause or campaign mutation; receives a snapshot.
signal closed
var archive: Dictionary = {}
var diary: Control
var _back: Button
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color("141923")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	margin.add_child(column)
	_back = Button.new()
	_back.text = "返回 · ESC"
	_back.size_flags_horizontal = Control.SIZE_SHRINK_END
	_back.pressed.connect(func():closed.emit())
	column.add_child(_back)
	diary = load("res://ui/codex/lore_diary.tscn").instantiate() as Control
	diary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diary.call("setup",archive)
	column.add_child(diary)
	_back.grab_focus()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		closed.emit()
		get_viewport().set_input_as_handled()
