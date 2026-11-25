class_name CrownForge
extends CanvasLayer
## The forge spends through the store transaction API; it never grants currency.
## Styled in Scheme B (Architectural Editorial ivory catalog on carbon gallery backdrop).

signal closed
var store: MetaProgressionStore
var player: Player
var _wallet: Label
var _slots: Label
var _notice: Label
var _cards: Dictionary = {}
var _was_paused := false
var _previous_mouse := Input.MOUSE_MODE_VISIBLE
var _closed := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	_previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()


func setup(value: MetaProgressionStore, owner_player: Player = null) -> void:
	store = value
	player = owner_player
	store.changed.connect(_refresh)
	if is_instance_valid(player):
		store.apply_to_player(player)
	_refresh()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color("111317")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EditorialStyle.apply_theme(center)
	add_child(center)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(1320, 0)
	panel.add_theme_constant_override("separation", 16)
	center.add_child(panel)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 20)
	panel.add_child(header_row)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 4)
	header_row.add_child(title_col)

	var eye := EditorialStyle.make_label("THE CROWN'S FORGE   //   静滞之门", 13, EditorialStyle.GOLD_BRIGHT, 700, true, 2)
	title_col.add_child(eye)
	var heading := EditorialStyle.make_label("皇冠锻造台", 38, EditorialStyle.PAPER, 800, false, 4)
	title_col.add_child(heading)

	var wallet_box := PanelContainer.new()
	wallet_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet_box.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(4, 4), Color(EditorialStyle.GOLD, 0.85), 22, 12))
	header_row.add_child(wallet_box)
	_wallet = EditorialStyle.make_label("", 20, EditorialStyle.INK, 800, true, 1)
	wallet_box.add_child(_wallet)

	_slots = EditorialStyle.make_label("", 15, EditorialStyle.ASH, 600, true, 1)
	panel.add_child(_slots)
	panel.add_child(EditorialStyle.make_rule(EditorialStyle.INK_TRACK, 2))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	panel.add_child(grid)
	for id in ["resolve", "reflex", "focus", "reroll", "defiance", "first_edge"]:
		grid.add_child(_card(id))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 20)
	panel.add_child(bottom)
	bottom.add_child(_card("keepsake_slots"))

	var summary_card := PanelContainer.new()
	summary_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_card.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.INK_SOFT, EditorialStyle.INK_TRACK, 2, Vector2.ZERO, Color.TRANSPARENT, 24, 20))
	bottom.add_child(summary_card)

	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 16)
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_card.add_child(summary)

	_notice = EditorialStyle.make_label("每次升级立即保存。死亡带回全部已结算货币。", 17, EditorialStyle.ASH, 500)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(_notice)

	var button := Button.new()
	button.text = "返回静滞之门   /   ESC"
	button.custom_minimum_size = Vector2(360, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	EditorialStyle.style_button(button, true, false, 18)
	button.pressed.connect(close)
	summary.add_child(button)


func _card(id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(428, 182)
	var style := EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(5, 5), Color(EditorialStyle.INK, 0.9), 0, 0)
	panel.add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	var accent_bar := ColorRect.new()
	accent_bar.color = EditorialStyle.GOLD
	accent_bar.custom_minimum_size.y = 5
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(accent_bar)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	outer.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := EditorialStyle.make_label(MetaProgressionStore.NAMES[id], 22, EditorialStyle.INK, 800)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var level_tag := EditorialStyle.make_label("0 / 0", 15, EditorialStyle.SLATE, 700, true)
	head.add_child(level_tag)

	var description := EditorialStyle.make_label("", 15, Color("2e323b"), 500)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.custom_minimum_size = Vector2(380, 46)
	box.add_child(description)

	var button := Button.new()
	button.custom_minimum_size = Vector2(380, 42)
	EditorialStyle.style_button(button, true, true, 16)
	button.pressed.connect(_purchase.bind(id))
	box.add_child(button)
	_cards[id] = {"title": title, "level": level_tag, "description": description, "button": button, "bar": accent_bar}
	return panel


func _refresh() -> void:
	if not is_instance_valid(store):
		return
	_wallet.text = "意志碎屑 %d   //   现实锚点 %d" % [store.will_shards, store.reality_anchors]
	_slots.text = "高阶信物槽  %d / %d 已用   ·   新局生命 %d   ·   重抽 %d 次" % [store.slots_used(), store.slots_capacity(), store.maximum_health(), store.starting_rerolls()]
	for id: String in _cards:
		var card: Dictionary = _cards[id]
		var lvl := store.level(id)
		var max_lvl: int = MetaProgressionStore.MAX_LEVEL[id]
		card.title.text = MetaProgressionStore.NAMES[id]
		card.level.text = "%d / %d" % [lvl, max_lvl]
		card.bar.color = EditorialStyle.INK if lvl >= max_lvl else EditorialStyle.GOLD
		card.description.text = store.describe(id)
		var blocker := store.purchase_blocker(id)
		var cost := store.cost(id)
		card.button.disabled = not blocker.is_empty()
		card.button.text = blocker if not blocker.is_empty() else "锻造  ·  %d 碎屑 / %d 锚点" % [cost.x, cost.y]
		card.button.tooltip_text = "下一等级：%d 意志碎屑 + %d 现实锚点" % [cost.x, cost.y]
	if store.load_status == "recovered_backup":
		_notice.text = "主存档校验失败，已读取上次有效备份。"
	elif store.load_status == "invalid":
		_notice.text = "存档校验失败；原文件已保留，升级已锁定。"


func _purchase(id: String) -> void:
	if not is_instance_valid(store):
		return
	if store.purchase(id):
		_notice.text = "已锻造「%s」· 本地存档已保存" % MetaProgressionStore.NAMES[id]
	else:
		_notice.text = store.last_error
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if _closed:
		return
	_closed = true
	if is_instance_valid(store):
		store.save()
	get_tree().paused = _was_paused
	GamePointer.restore(_previous_mouse, get_window())
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if not _closed and get_tree() != null:
		get_tree().paused = _was_paused
		GamePointer.restore(_previous_mouse, get_window())
