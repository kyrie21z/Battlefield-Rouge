class_name LoreDiary
extends Control
## A read-only, embeddable editorial dossier page (Scheme B: Architectural Editorial).
## The host owns input capture, pause and persistence.

const PAPER := EditorialStyle.PAPER
const INK := EditorialStyle.INK
const MUTED := EditorialStyle.SLATE
const GOLD := EditorialStyle.GOLD

var _archive: Dictionary = {}
var _dossier := false
var _selected := 0
var _pages: Array[Dictionary] = []
var _margin: MarginContainer
var _layout: HBoxContainer
var _nav: VBoxContainer
var _buttons: Array[Button] = []
var _tabs: Array[Button] = []
var _reader: ScrollContainer
var _paper: MarginContainer
var _copy: VBoxContainer
var _count: Label
var _heading: Label
var _footer: Label
var _built := false
var _compact := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorialStyle.apply_theme(self)
	_build()
	_built = true
	resized.connect(_resize)
	visibility_changed.connect(_focus_when_shown)
	_resize()
	refresh()
	_focus_when_shown()


func setup(archive: Dictionary) -> void:
	_archive = archive
	refresh()


func refresh() -> void:
	if not _built:
		return
	_pages = LoreEntries.project(_archive, _dossier)
	_selected = clampi(_selected, 0, _pages.size() - 1)
	var unlocked := 0
	for page in _pages:
		if page.unlocked:
			unlocked += 1
	_count.text = "%02d / %02d  已显影" % [unlocked, _pages.size()]
	for index in _buttons.size():
		var button := _buttons[index]
		button.visible = index < _pages.size()
		if not button.visible:
			button.text = ""
			button.tooltip_text = ""
			continue
		var page := _pages[index]
		var selected := index == _selected
		button.text = "%02d    %s\n        %s" % [index + 1, page.realm, _nav_title(page)]
		button.set_pressed_no_signal(selected)
		button.add_theme_color_override("font_color", PAPER if selected else (INK if page.unlocked else MUTED))
		button.add_theme_color_override("font_pressed_color", PAPER)
		var accent: Color = page.color
		var nav_style := EditorialStyle.plaque(INK if selected else EditorialStyle.PAPER_SOFT, accent if selected else EditorialStyle.PAPER_DIM, 2 if selected else 1, Vector2(3, 3) if selected else Vector2.ZERO, Color(accent, 0.7), 12, 8)
		nav_style.border_width_left = 5 if selected else 2
		button.add_theme_stylebox_override("normal", nav_style)
		button.add_theme_stylebox_override("pressed", nav_style)
		button.tooltip_text = ""
		var above: Control = _tabs[1 if _dossier else 0] if index == 0 else _buttons[index - 1]
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(_buttons[(index + 1) % _pages.size()])
		button.focus_neighbor_right = button.get_path_to(_reader)
		button.focus_next = button.get_path_to(_reader)
	_reader.focus_neighbor_left = _reader.get_path_to(_buttons[_selected])
	_reader.focus_previous = _reader.get_path_to(_buttons[_selected])
	for tab in _tabs:
		tab.focus_neighbor_bottom = tab.get_path_to(_buttons[_selected])
	_tabs[0].focus_neighbor_right = _tabs[0].get_path_to(_tabs[1])
	_tabs[1].focus_neighbor_left = _tabs[1].get_path_to(_tabs[0])
	_show_page()


func _nav_title(page: Dictionary) -> String:
	if not page.unlocked:
		return "封存中"
	if _dossier:
		return "双面档案 · " + ("两面显影" if page.human_unlocked else "一面显影")
	return String(page.title).split("：")[0]


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = PAPER
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 14)
	_margin.add_child(shell)

	shell.add_child(EditorialStyle.make_label("PSYCHE ARCHIVES   //   心象档案", 13, MUTED, 700, true, 2))
	var masthead := HBoxContainer.new()
	shell.add_child(masthead)
	_heading = EditorialStyle.make_label("留在纸上的声音", 34, INK, 800, false, 2)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead.add_child(_heading)
	_count = EditorialStyle.make_label("", 15, MUTED, 700, true)
	_count.custom_minimum_size.x = 170
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	masthead.add_child(_count)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	shell.add_child(tab_row)
	for index in 2:
		var tab := _tab_button("现实心象日记" if index == 0 else "心魔双面档案")
		tab.custom_minimum_size = Vector2(194, 40)
		tab.pressed.connect(_change_section.bind(index == 1))
		tab.set_pressed_no_signal(index == 0)
		tab_row.add_child(tab)
		_tabs.append(tab)

	shell.add_child(EditorialStyle.make_rule(INK, 2))

	_layout = HBoxContainer.new()
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation", 28)
	shell.add_child(_layout)

	var nav_scroll := ScrollContainer.new()
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nav_scroll.follow_focus = true
	_layout.add_child(nav_scroll)

	_nav = VBoxContainer.new()
	_nav.add_theme_constant_override("separation", 10)
	nav_scroll.add_child(_nav)
	for index in 5:
		var button := _nav_button("")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 72
		button.pressed.connect(_select.bind(index))
		_nav.add_child(button)
		_buttons.append(button)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(Color("ffffff"), INK, 2, Vector2(5, 5), Color(INK, 0.22), 4, 4))
	_layout.add_child(panel)

	_reader = ScrollContainer.new()
	_reader.name = "ReadingScroll"
	_reader.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_reader.focus_mode = Control.FOCUS_ALL
	_reader.add_theme_stylebox_override("focus", EditorialStyle.plaque(Color.TRANSPARENT, GOLD, 2, Vector2.ZERO, Color.TRANSPARENT, 2, 2))
	_reader.gui_input.connect(_scroll_input)
	panel.add_child(_reader)

	_paper = MarginContainer.new()
	_paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader.add_child(_paper)

	_copy = VBoxContainer.new()
	_copy.add_theme_constant_override("separation", 20)
	_paper.add_child(_copy)

	_footer = EditorialStyle.make_label("↑ ↓ 选择篇目   ·   Enter / A 打开   ·   → 阅读   ·   滚轮 / 方向键 滚动   ·   ← 返回目录", 14, MUTED, 600, true)
	shell.add_child(_footer)


func _show_page() -> void:
	for child in _copy.get_children():
		child.free()
	_reader.scroll_vertical = 0
	var page := _pages[_selected]
	var accent: Color = page.color.darkened(0.18)
	_copy.add_child(EditorialStyle.make_label("%02d    //    %s" % [_selected + 1, "本能的两面" if _dossier else "现实心象"], 14, accent, 700, true, 2))
	var title_lbl := EditorialStyle.make_label(page.title, 26 if _compact else 32, INK, 800, false, 1)
	title_lbl.add_theme_font_override("font", EditorialStyle.font_serif(700))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy.add_child(title_lbl)
	_copy.add_child(_label(page.hint, 15, MUTED))
	_copy.add_child(EditorialStyle.make_rule(INK, 2))

	if not page.unlocked:
		var blank := Control.new()
		blank.custom_minimum_size.y = 36
		_copy.add_child(blank)
		_copy.add_child(EditorialStyle.make_label("纸页还没有留下文字。", 22, MUTED, 600))
		_copy.add_child(_label("此处只收录你已经走过的部分。", 17, MUTED))
	elif not _dossier:
		_copy.add_child(_body(page.body))
		_copy.add_child(EditorialStyle.make_label("—  我的手记", 16, accent, 700))
	else:
		_copy.add_child(EditorialStyle.make_label("皇冠眼中的绊脚石  /  " + page.obstacle, 19, accent, 800))
		_copy.add_child(_body(page.crown))
		_copy.add_child(EditorialStyle.make_rule(EditorialStyle.PAPER_DIM, 2))
		if page.human_unlocked:
			_copy.add_child(EditorialStyle.make_label("人性内核的保护价值  /  " + page.value, 19, accent, 800))
			_copy.add_child(_body(page.human))
		else:
			_copy.add_child(EditorialStyle.make_label("另一面 · 尚未显影", 19, MUTED, 700))
			_copy.add_child(_label("击败此境心魔后，再来翻开这一面。", 17, MUTED))
	_copy.add_child(_label("■   ■   ■", 12, EditorialStyle.PAPER_DIM))


func _change_section(dossier: bool) -> void:
	_dossier = dossier
	for index in _tabs.size():
		_tabs[index].set_pressed_no_signal((index == 1) == dossier)
	refresh()


func _select(index: int) -> void:
	_selected = index
	refresh()


func _button_input(event: InputEvent, button: Button) -> void:
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed and not event.is_action("ui_accept"):
		button.pressed.emit()
		button.accept_event()


func _resize() -> void:
	if not _built:
		return
	_compact = size.x < 1500 or size.y < 850
	var gutter := 16 if _compact else 28
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, gutter)
		_paper.add_theme_constant_override("margin_" + side, 24 if _compact else 40)
	_nav.custom_minimum_size.x = 270 if _compact else 330
	_heading.add_theme_font_size_override("font_size", 28 if _compact else 34)
	_layout.add_theme_constant_override("separation", 20 if _compact else 32)
	if not _pages.is_empty():
		_show_page()


func _focus_when_shown() -> void:
	if _built and is_visible_in_tree():
		_buttons[_selected].grab_focus.call_deferred()


func _scroll_input(event: InputEvent) -> void:
	var direction := 0
	if event.is_action_pressed("ui_down", true):
		direction = 60
	elif event.is_action_pressed("ui_up", true):
		direction = -60
	elif event.is_action_pressed("ui_page_down", true):
		direction = int(_reader.size.y * 0.8)
	elif event.is_action_pressed("ui_page_up", true):
		direction = -int(_reader.size.y * 0.8)
	elif event.is_action_pressed("ui_home"):
		_reader.scroll_vertical = 0
		_reader.accept_event()
	elif event.is_action_pressed("ui_end"):
		_reader.scroll_vertical = int(_reader.get_v_scroll_bar().max_value)
		_reader.accept_event()
	if direction != 0:
		_reader.scroll_vertical += direction
		_reader.accept_event()


func _body(text: String) -> Label:
	var lbl := _label(text, 18 if _compact else 21, Color("24272f"))
	lbl.add_theme_font_override("font", EditorialStyle.font_serif(400))
	lbl.add_theme_constant_override("line_spacing", 10 if _compact else 14)
	return lbl


static func _label(text: String, font_size: int, color: Color) -> Label:
	var lbl := EditorialStyle.make_label(text, font_size, color, 500)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _tab_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.gui_input.connect(_button_input.bind(button))
	EditorialStyle.style_tab(button, true, 16)
	return button


func _nav_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.gui_input.connect(_button_input.bind(button))
	EditorialStyle.style_tab(button, true, 16)
	return button
