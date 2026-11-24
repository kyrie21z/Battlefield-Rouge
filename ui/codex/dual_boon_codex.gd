class_name DualBoonCodex
extends Control
## Injected, read-only codex (Scheme B: Architectural Editorial).
## Host owns visibility, pause, input capture and discovery persistence.

const PAPER := EditorialStyle.PAPER
const INK := EditorialStyle.INK
const MUTED := EditorialStyle.SLATE
const GOLD := EditorialStyle.GOLD
const PAGE_NAMES := ["共鸣合成谱", "怠惰", "恐惧", "暴怒", "悲伤"]

var _manager: BoonManager
var _discovered: Array[String] = []
var _catalog: Array[BoonData] = []
var _duals: Array[BoonData] = []
var _page := 0
var _selected: BoonData
var _buttons: Dictionary = {}
var _tabs: Array[Button] = []
var _topology: CodexTopology
var _summary: Label
var _count: Label
var _core_summary: Label
var _list_scroll: ScrollContainer
var _grid: GridContainer
var _detail_scroll: ScrollContainer
var _detail_title: Label
var _detail_meta: Label
var _detail_body: Label
var _detail_status: Label
var _requirements: Label


func setup(manager: BoonManager, discovered: Array[String]) -> void:
	_disconnect_manager()
	_manager = manager
	_discovered = discovered.duplicate()
	if is_instance_valid(_manager):
		_manager.changed.connect(refresh)
	if is_node_ready():
		refresh()


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorialStyle.apply_theme(self)
	_catalog = BoonCatalog.all()
	for card in _catalog:
		if card.rarity == BoonData.Rarity.DUAL:
			_duals.append(card)
	_build()
	visibility_changed.connect(_on_visibility_changed)
	refresh()


func _exit_tree() -> void:
	_disconnect_manager()


func _disconnect_manager() -> void:
	if is_instance_valid(_manager) and _manager.changed.is_connected(refresh):
		_manager.changed.disconnect(refresh)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var available := {}
	var held := {}
	var ready_count := 0
	var core_lines: Array[String] = []
	var has_build := is_instance_valid(_manager)
	if has_build:
		for slot in _manager.slots:
			if slot.data != null:
				held[slot.data.sin] = true
				core_lines.append("%s  /  %s" % [BoonIdentity.SIN_NAMES[slot.data.sin], slot.data.name])
	for card in _duals:
		available[card.id] = has_build and _manager.can_equip(card)
		if available[card.id]:
			ready_count += 1
	_summary.text = "%d 张心魔赐福  /  %d 组双重共鸣" % [_catalog.size() - _duals.size(), _duals.size()]
	if has_build:
		_summary.text += "  /  %d 组当前可获得" % ready_count
		_core_summary.text = "当前核心  /  " + (" · ".join(core_lines) if not core_lines.is_empty() else "尚未持有核心 · 从右侧查看构筑路线")
	else:
		_core_summary.text = "档案阅览 · 选择连线查看合成路线"
	_update_cards()
	_topology.update_state(_duals, available, held, _selected.id if _selected != null else "")
	_topology.style_edges()
	_update_detail()


func _build() -> void:
	var background := ColorRect.new()
	background.color = PAPER
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var heading := HBoxContainer.new()
	root.add_child(heading)
	var title := EditorialStyle.make_label("双重共鸣 · 心智合成谱", 26, INK, 800, false, 2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var hint := EditorialStyle.make_label("LB / RB 切页   ·   方向键 浏览   ·   A / Enter 详情", 14, MUTED, 600, true)
	heading.add_child(hint)

	_summary = _label("", 16, MUTED)
	root.add_child(_summary)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for index in PAGE_NAMES.size():
		var button := Button.new()
		button.text = "%02d   %s" % [index + 1, PAGE_NAMES[index]]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 40
		var tab_accent := GOLD if index == 0 else EditorialStyle.realm_accent(index - 1)
		_style_tab_button(button, tab_accent)
		button.pressed.connect(func(): _set_page(index))
		tabs.add_child(button)
		_tabs.append(button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root.add_child(body)

	var map_column := VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.size_flags_stretch_ratio = 0.9
	map_column.add_theme_constant_override("separation", 8)
	body.add_child(map_column)
	map_column.add_child(EditorialStyle.make_label("四种心魔，六条相遇的路径", 18, INK, 700))

	var topo_frame := PanelContainer.new()
	topo_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	topo_frame.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(INK, INK, 2, Vector2(4, 4), Color(INK, 0.25), 8, 8))
	map_column.add_child(topo_frame)

	_topology = CodexTopology.new()
	_topology.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_topology.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topology.card_selected.connect(_select_from_map)
	topo_frame.add_child(_topology)

	var legend := _label("彩色框：已持有核心   ·   金色连线：当前可获得\n共鸣需要两种心魔的核心，特质不能替代。", 15, MUTED)
	map_column.add_child(legend)
	_core_summary = EditorialStyle.make_label("", 15, INK, 700)
	_core_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_column.add_child(_core_summary)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 560
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.25
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)

	_count = EditorialStyle.make_label("", 16, INK, 700, true)
	right.add_child(_count)

	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.follow_focus = true
	right.add_child(_list_scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_list_scroll.add_child(_grid)

	var detail := PanelContainer.new()
	detail.custom_minimum_size.y = 215
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(Color("ffffff"), INK, 2, Vector2(4, 4), Color(INK, 0.25), 18, 14))
	right.add_child(detail)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.focus_mode = Control.FOCUS_ALL
	_detail_scroll.gui_input.connect(_scroll_detail)
	detail.add_child(_detail_scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	_detail_scroll.add_child(content)

	_detail_title = EditorialStyle.make_label("", 24, INK, 800)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_meta = _label("", 14, MUTED)
	_detail_status = EditorialStyle.make_label("", 15, Color("8a5d10"), 700)
	_detail_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body = _label("", 17, INK)
	_requirements = _label("", 15, Color("3c4350"))
	for lbl in [_detail_title, _detail_meta, _detail_status, _detail_body, _requirements]:
		content.add_child(lbl)

	root.add_child(_label("未发现的卡同样可以查阅。图鉴仅显示路线，实际获取仍需遇见对应赐福。", 14, MUTED))


func _label(value: String, font_size: int, color: Color) -> Label:
	var result := EditorialStyle.make_label(value, font_size, color, 500)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


func _style_tab_button(button: Button, accent: Color) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", EditorialStyle.font_sans(700, 1))
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", EditorialStyle.button_box(EditorialStyle.PAPER_SOFT, INK, 1, Vector2.ZERO, Color.TRANSPARENT, 10, 6))
	button.add_theme_stylebox_override("hover", EditorialStyle.button_box(INK, INK, 2, Vector2.ZERO, Color.TRANSPARENT, 10, 6))
	button.add_theme_stylebox_override("pressed", EditorialStyle.button_box(INK, accent, 2, Vector2.ZERO, Color.TRANSPARENT, 10, 6))
	button.add_theme_stylebox_override("focus", EditorialStyle.button_box(PAPER, GOLD, 2, Vector2.ZERO, Color.TRANSPARENT, 10, 6))


func _style_card_button(button: Button, accent: Color, is_selected: bool) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", EditorialStyle.font_sans(600))
	button.add_theme_font_size_override("font_size", 16)
	var bg := INK if is_selected else Color("ffffff")
	var fg := PAPER if is_selected else INK
	var normal := EditorialStyle.plaque(bg, accent if is_selected else INK, 2 if is_selected else 1, Vector2(3, 3) if is_selected else Vector2.ZERO, Color(accent, 0.7), 12, 8)
	normal.border_width_left = 5
	normal.border_color = accent
	button.add_theme_stylebox_override("normal", normal)
	var hover := EditorialStyle.plaque(INK_SOFT if is_selected else EditorialStyle.PAPER_SOFT, accent, 2, Vector2(3, 3), Color(INK, 0.2), 12, 8)
	hover.border_width_left = 5
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", EditorialStyle.plaque(bg, GOLD, 2, Vector2.ZERO, Color.TRANSPARENT, 12, 8))
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", PAPER if is_selected else INK)
	button.add_theme_color_override("font_focus_color", fg)


const INK_SOFT := EditorialStyle.INK_SOFT


func _page_cards() -> Array[BoonData]:
	var cards: Array[BoonData] = []
	for card in _catalog:
		if (_page == 0 and card.rarity == BoonData.Rarity.DUAL) or (_page > 0 and card.rarity != BoonData.Rarity.DUAL and card.sin == _page - 1):
			cards.append(card)
	return cards


func _update_cards() -> void:
	var cards := _page_cards()
	if _buttons.is_empty():
		for card in cards:
			var button := Button.new()
			button.custom_minimum_size = Vector2(0, 74)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.clip_text = true
			button.pressed.connect(func(): _select(card))
			button.focus_entered.connect(func(): _select(card))
			_grid.add_child(button)
			_buttons[card.id] = button
	if _selected == null or not cards.has(_selected):
		_selected = cards[0] if not cards.is_empty() else null
	for i in cards.size():
		var button: Button = _buttons[cards[i].id]
		button.focus_neighbor_top = _tabs[_page].get_path() if i < 2 else _buttons[cards[i - 2].id].get_path()
		button.focus_neighbor_bottom = _buttons[cards[i + 2].id].get_path() if i + 2 < cards.size() else _detail_scroll.get_path()
		button.focus_neighbor_left = _buttons[cards[maxi(i - 1, 0)].id].get_path()
		button.focus_neighbor_right = _buttons[cards[mini(i + 1, cards.size() - 1)].id].get_path()
	for tab in _tabs:
		tab.focus_neighbor_bottom = _buttons[cards[0].id].get_path() if not cards.is_empty() else _detail_scroll.get_path()
	if not cards.is_empty():
		_detail_scroll.focus_neighbor_top = _buttons[cards.back().id].get_path()

	var known_count := 0
	for card in cards:
		var button: Button = _buttons[card.id]
		var known := _discovered.has(card.id)
		known_count += int(known)
		var owned := is_instance_valid(_manager) and _manager.has(card.id)
		var eligible := is_instance_valid(_manager) and _manager.can_equip(card)
		button.text = "%s\n%s · %s" % [card.name, "已发现" if known else "未发现", "已持有" if owned else ("可获得" if eligible else "查看前置")]
		_style_card_button(button, BoonPresentation.paper_accent(card), _selected == card)

	_count.text = "%s  /  %d 张  ·  已发现 %d / %d" % [PAGE_NAMES[_page], cards.size(), known_count, cards.size()]
	for index in _tabs.size():
		var tab_accent := GOLD if index == 0 else EditorialStyle.realm_accent(index - 1)
		var active := index == _page
		_tabs[index].add_theme_stylebox_override("normal",
			EditorialStyle.button_box(INK if active else EditorialStyle.PAPER_SOFT, tab_accent if active else INK, 2 if active else 1, Vector2(2, 2) if active else Vector2.ZERO, Color(tab_accent, 0.7), 10, 6))
		_tabs[index].add_theme_color_override("font_color", PAPER if active else INK)


func _select(card: BoonData) -> void:
	_selected = card
	_detail_scroll.scroll_vertical = 0
	refresh()


func _select_from_map(card: BoonData) -> void:
	if _page != 0:
		_set_page(0, false)
	_select(card)
	_list_scroll.ensure_control_visible(_buttons[card.id])


func _update_detail() -> void:
	if _selected == null:
		return
	var card := _selected
	_detail_title.text = card.name
	var identity := BoonIdentity.identity(card)
	if card.rarity == BoonData.Rarity.DUAL:
		var names: Array[String] = []
		for sin_type in card.required_sins:
			names.append(BoonIdentity.SIN_NAMES[sin_type])
		identity = " × ".join(names)
	_detail_meta.text = "%s  /  %s  /  %s" % [identity, BoonIdentity.RARITIES[card.rarity], "核心 · " + BoonIdentity.SLOT_NAMES[card.slot] if card.core else "次级特质"]
	var owned := is_instance_valid(_manager) and _manager.has(card.id)
	var eligible := is_instance_valid(_manager) and _manager.can_equip(card)
	_detail_status.text = "已发现" if _discovered.has(card.id) else "未发现 · 可预览完整效果"
	if is_instance_valid(_manager):
		_detail_status.text += "  /  " + ("当前已持有" if owned else ("当前可获得" if eligible else "当前不可获得"))
	_detail_body.text = card.description
	_requirements.text = "合成 / 获取前置\n" + "\n".join(CodexRequirements.describe(card, _manager, _catalog))


func _set_page(index: int, move_focus: bool = true) -> void:
	_page = posmod(index, PAGE_NAMES.size())
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_selected = null
	_list_scroll.scroll_vertical = 0
	_detail_scroll.scroll_vertical = 0
	refresh()
	if move_focus:
		_tabs[_page].grab_focus()


func _scroll_detail(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_down"):
		_detail_scroll.scroll_vertical += 48
		_detail_scroll.accept_event()
	elif event.is_action_pressed(&"ui_up") and _detail_scroll.scroll_vertical > 0:
		_detail_scroll.scroll_vertical = maxi(0, _detail_scroll.scroll_vertical - 48)
		_detail_scroll.accept_event()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		_set_page(_page + (-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1))
		get_viewport().set_input_as_handled()
