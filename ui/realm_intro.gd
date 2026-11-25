class_name RealmIntro
extends Control
## One-time explanation of a realm's shared mechanic (Scheme B: Architectural Editorial).

signal dismissed

const PANEL_SIZE := Vector2(760, 460)
const BACKDROP := Color(0.055, 0.062, 0.082, 0.80)

## Realm index matches BoonData.Sin, so the caller just passes stage.realm.
const INTRO := [
	{
		"title": "琥珀时钟",
		"lines": [
			"打中敌人时，它头顶会挂一个钟",
			"钟走完炸 60 伤",
			"钟还在的时候，敌人移动速度 −40%",
		],
		"note": "这个领域的天赋都围着这个钟转",
	},
	{
		"title": "弱点与发慌",
		"lines": [
			"每个敌人身上都有一块发紫的弱点",
			"打中必暴击，弱点多半在后背",
			"被打中的敌人会发慌，发慌时它开火会打偏",
		],
		"note": "绕到背后，或者趁它发慌",
	},
	{
		"title": "撞墙",
		"lines": [
			"你把敌人打飞，撞到墙就会炸",
			"撞得越狠，炸得越痛",
			"它飞出去撞不到墙，就什么都不会发生",
		],
		"note": "看到墙，就想着把人推过去",
	},
	{
		"title": "湿与泪晶",
		"lines": [
			"打中敌人会让它变湿",
			"湿满 5 层会掉一颗泪晶",
			"你捡起来回护盾，还能炸一圈",
		],
		"note": "湿透的敌人出手更慢、子弹也更慢",
	},
]

var _previous_mouse := Input.MOUSE_MODE_VISIBLE
var _title: Label
var _body: VBoxContainer
var _note: Label
var _top_bar: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	EditorialStyle.apply_theme(self)
	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	get_tree().paused = true


func setup(realm_id: int) -> void:
	var data: Dictionary = INTRO[clampi(realm_id, 0, INTRO.size() - 1)]
	var accent := _accent(realm_id)
	_top_bar.color = accent
	_title.text = data["title"]
	_title.add_theme_color_override("font_color", EditorialStyle.INK)
	for line: String in data["lines"]:
		var row := EditorialStyle.make_label("▪   " + line, 24, Color("242830"), 600)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(PANEL_SIZE.x - 110, 0)
		_body.add_child(row)
	_note.text = data["note"]
	_note.add_theme_color_override("font_color", accent)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	panel.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(8, 8), Color(EditorialStyle.INK, 0.90), 0, 0))
	add_child(panel)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 0)
	panel.add_child(shell)

	_top_bar = ColorRect.new()
	_top_bar.color = EditorialStyle.GOLD
	_top_bar.custom_minimum_size.y = 7
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(_top_bar)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	shell.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	column.add_child(EditorialStyle.make_label("REALM MECHANIC   //   领域机制", 12, EditorialStyle.SLATE, 700, true, 2))

	_title = EditorialStyle.make_label("", 40, EditorialStyle.INK, 800, false, 2)
	column.add_child(_title)

	column.add_child(EditorialStyle.make_rule(EditorialStyle.INK, 2))

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	column.add_child(_body)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_note = EditorialStyle.make_label("", 20, EditorialStyle.GOLD, 700)
	column.add_child(_note)

	var button := Button.new()
	button.text = "知道了  →"
	button.custom_minimum_size = Vector2(210, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	EditorialStyle.style_button(button, true, true, 21)
	button.pressed.connect(_dismiss)
	column.add_child(button)
	button.grab_focus()


func _dismiss() -> void:
	get_tree().paused = false
	GamePointer.restore(_previous_mouse, get_window())
	dismissed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()


func _accent(realm_id: int) -> Color:
	return EditorialStyle.realm_accent(realm_id)
