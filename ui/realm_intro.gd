class_name RealmIntro
extends Control
## One-time explanation of a realm's shared mechanic, shown the first time the
## player is about to pick a card from that realm. Every card in a realm leans on
## the same noun (the clock, the flaw, the wall, the wet), so explaining it once
## between picking up the orb and opening the three-card offer keeps the cards
## themselves short.

signal dismissed

const PANEL_SIZE := Vector2(760, 460)
const BACKDROP := Color(0.02, 0.025, 0.04, 0.82)

## Realm index matches BoonData.Sin, so the caller just passes stage.realm.
const INTRO := [
	{
		"title": "琥珀时钟",
		"lines": [
			"打中敌人时，它头顶会挂一个钟",
			"钟走完炸 60 伤",
			"钟还在的时候，敌人一直慢 40%",
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The game runs with the cursor captured, so the panel has to hand it back or
	# the player cannot click "知道了".
	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	get_tree().paused = true


func setup(realm_id: int) -> void:
	var data: Dictionary = INTRO[clampi(realm_id, 0, INTRO.size() - 1)]
	_title.text = data["title"]
	_title.add_theme_color_override("font_color", _accent(realm_id))
	for line: String in data["lines"]:
		var row := Label.new()
		row.text = line
		row.add_theme_font_size_override("font_size", 26)
		row.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(PANEL_SIZE.x - 120, 0)
		_body.add_child(row)
	_note.text = data["note"]
	_note.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	# anchor to the middle of the screen and let the offsets carry the size, so the
	# panel stays centred no matter what resolution the game runs at
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.07, 0.97)
	style.border_color = Color(0.35, 0.42, 0.55, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 46)
	column.add_child(_title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(0.35, 0.42, 0.55, 0.45)
	column.add_child(rule)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	column.add_child(_body)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 22)
	column.add_child(_note)

	var button := Button.new()
	button.text = "知道了"
	button.custom_minimum_size = Vector2(200, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(_dismiss)
	column.add_child(button)
	button.grab_focus()


func _dismiss() -> void:
	get_tree().paused = false
	Input.mouse_mode = _previous_mouse
	dismissed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()


## Realm colours come from BoonPalette so the panel matches the card accents.
func _accent(realm_id: int) -> Color:
	return BoonPalette.COLORS[clampi(realm_id, 0, BoonPalette.COLORS.size() - 1)].lightened(0.15)
