class_name DualBoonCodex
extends Control
## Injected, read-only codex. Host owns visibility, pause, input capture and discovery persistence.
const PAPER := Color("f2f0e9")
const INK := Color("141923")
const MUTED := Color("aeb8c7")
const GOLD := Color("e7ce8c")
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

## Refresh the injected snapshot; call setup again for a new discovery list.
## Equipment also updates automatically through manager.changed.
func refresh() -> void:
	if not is_node_ready():
		return
	var available := {}
	var held := {}
	var ready_count := 0
	var core_lines: Array[String] = []
	if is_instance_valid(_manager):
		for slot in _manager.slots:
			if slot.data != null:
				held[slot.data.sin] = true
				core_lines.append("%s  /  %s" % [BoonIdentity.SIN_NAMES[slot.data.sin], slot.data.name])
	for card in _duals:
		available[card.id] = is_instance_valid(_manager) and _manager.can_equip(card)
		if available[card.id]:
			ready_count += 1
	_summary.text = "48 张心魔赐福  /  6 组双重共鸣  /  %d 组当前可获得" % ready_count
	_core_summary.text = "当前核心  /  " + (" · ".join(core_lines) if not core_lines.is_empty() else "尚未持有核心 · 从右侧查看构筑路线")
	_update_cards()
	_topology.update_state(_duals, available, held, _selected.id if _selected != null else "")
	_topology.style_edges()
	_update_detail()

func _build() -> void:
	var background := ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	root.add_child(_label("MIND FREAK   /   BOON CODEX", 15, GOLD))
	var heading := HBoxContainer.new()
	root.add_child(heading)
	var title := _label("双重共鸣 · 心智合成谱", 30, PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var hint := _label("LB / RB  切页     方向键  浏览     A / Enter  详情", 17, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.add_child(hint)
	_summary = _label("", 18, MUTED)
	root.add_child(_summary)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for index in PAGE_NAMES.size():
		var button := Button.new()
		button.text = "%02d   %s" % [index + 1, PAGE_NAMES[index]]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		_style_button(button, GOLD if index == 0 else BoonIdentity.COLORS[index - 1])
		button.pressed.connect(func(): _set_page(index))
		tabs.add_child(button)
		_tabs.append(button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)
	var map_column := VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.size_flags_stretch_ratio = .9
	body.add_child(map_column)
	map_column.add_child(_label("四种心魔，六条相遇的路径", 20, PAPER))
	_topology = CodexTopology.new()
	_topology.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_topology.card_selected.connect(_select_from_map)
	map_column.add_child(_topology)
	var legend := _label("彩色框：已持有核心   ·   金色微光：当前可获得\n共鸣需要两种心魔的核心，特质不能替代。", 17, MUTED)
	map_column.add_child(legend)
	_core_summary = _label("", 17, PAPER)
	map_column.add_child(_core_summary)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 560
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.25
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_count = _label("", 18, PAPER)
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
	detail.custom_minimum_size.y = 220
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_stylebox_override("panel", BoonPresentation.panel(PAPER, Color("c9c6bc")))
	right.add_child(detail)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.focus_mode = Control.FOCUS_ALL
	_detail_scroll.gui_input.connect(_scroll_detail)
	detail.add_child(_detail_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	_detail_scroll.add_child(content)
	_detail_title = _label("", 25, INK)
	_detail_meta = _label("", 16, Color("4c5360"))
	_detail_status = _label("", 18, Color("5f461d"))
	_detail_body = _label("", 19, INK)
	_requirements = _label("", 17, Color("3d4653"))
	for label in [_detail_title, _detail_meta, _detail_status, _detail_body, _requirements]:
		content.add_child(label)
	root.add_child(_label("未发现的卡同样可以查阅。图鉴仅显示路线，实际获取仍需遇见对应赐福。", 16, MUTED))

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := BoonPresentation.label(value, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_panel(Color("1d2430"), accent.darkened(.45)))
	button.add_theme_stylebox_override("hover", _button_panel(Color("303947"), accent, 2))
	button.add_theme_stylebox_override("pressed", _button_panel(Color("303947"), accent, 2))
	button.add_theme_stylebox_override("focus", _button_panel(Color(0, 0, 0, 0), PAPER, 2))

func _button_panel(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := BoonPresentation.panel(background, border, width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

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
			button.custom_minimum_size = Vector2(0, 80)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.clip_text = true
			_style_button(button, BoonIdentity.accent(card))
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
		var accent := BoonIdentity.accent(card)
		button.add_theme_stylebox_override("normal", _button_panel(Color("29303a") if _selected == card else Color("1d2430"), accent if _selected == card else accent.darkened(.55), 2 if _selected == card else 1))
	_count.text = "%s  /  %d 张  ·  已发现 %d / %d" % [PAGE_NAMES[_page], cards.size(), known_count, cards.size()]
	for index in _tabs.size():
		_tabs[index].modulate = Color.WHITE if index == _page else Color("aeb8c7")

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
	_detail_status.text = ("已发现" if _discovered.has(card.id) else "未发现 · 可预览完整效果") + "  /  " + ("当前已持有" if owned else ("当前可获得" if eligible else "当前不可获得"))
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
	# ScrollContainer does not scroll JoypadButton arrows itself. Keep focus here
	# while reading; Up at the top falls through to the last card's focus route.
	if event.is_action_pressed(&"ui_down"):
		_detail_scroll.scroll_vertical += 48
		_detail_scroll.accept_event()
	elif event.is_action_pressed(&"ui_up") and _detail_scroll.scroll_vertical > 0:
		_detail_scroll.scroll_vertical = maxi(0, _detail_scroll.scroll_vertical - 48)
		_detail_scroll.accept_event()

func _input(event: InputEvent) -> void:
	# Local shoulder handling needs no global InputMap changes; hidden tabs never consume it.
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		_set_page(_page + (-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1))
		get_viewport().set_input_as_handled()
