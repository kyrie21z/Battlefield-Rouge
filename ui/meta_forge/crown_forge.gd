class_name CrownForge
extends CanvasLayer
## The forge spends through the store transaction API; it never grants currency.
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

func setup(value: MetaProgressionStore,owner_player: Player = null) -> void:
	store = value
	player = owner_player
	store.changed.connect(_refresh)
	if is_instance_valid(player):
		store.apply_to_player(player)
	_refresh()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color("0e1019")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(1340,0)
	panel.add_theme_constant_override("separation",16)
	center.add_child(panel)
	var eyebrow := BoonPresentation.label("THE CROWN'S FORGE   /   静滞之门",18,Color("bca575"))
	panel.add_child(eyebrow)
	var heading := BoonPresentation.label("皇冠锻造台",42,Color("f1e5c9"))
	panel.add_child(heading)
	_wallet = BoonPresentation.label("",24,Color("e3c27d"))
	panel.add_child(_wallet)
	_slots = BoonPresentation.label("",19,Color("a8b8c7"))
	panel.add_child(_slots)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",14)
	panel.add_child(grid)
	for id in ["resolve","reflex","focus","reroll","defiance","first_edge"]:
		grid.add_child(_card(id))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation",18)
	panel.add_child(bottom)
	bottom.add_child(_card("keepsake_slots"))
	var summary := VBoxContainer.new()
	summary.custom_minimum_size = Vector2(860,0)
	bottom.add_child(summary)
	_notice = BoonPresentation.label("每次升级立即保存。死亡带回全部已结算货币。",18,Color("a9b0bd"))
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(_notice)
	var button := Button.new()
	button.text = "返回静滞之门   /   Esc"
	button.custom_minimum_size = Vector2(360,48)
	button.pressed.connect(close)
	summary.add_child(button)

func _card(id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(436,186)
	panel.add_theme_stylebox_override("panel",BoonPresentation.panel(Color("191e29"),Color("635941"),1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	panel.add_child(box)
	var title := BoonPresentation.label(MetaProgressionStore.NAMES[id],25,Color("efe4cb"))
	box.add_child(title)
	var description := BoonPresentation.label("",17,Color("b6becb"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(398,52)
	box.add_child(description)
	var button := Button.new()
	button.custom_minimum_size = Vector2(398,42)
	button.pressed.connect(_purchase.bind(id))
	box.add_child(button)
	_cards[id] = {"title":title,"description":description,"button":button}
	return panel

func _refresh() -> void:
	if not is_instance_valid(store):
		return
	_wallet.text = "意志碎屑  %d     ◇     现实锚点  %d" % [store.will_shards,store.reality_anchors]
	_slots.text = "高阶信物槽  %d / %d 已用   ·   新局生命 %d   ·   重抽 %d 次" % [store.slots_used(),store.slots_capacity(),store.maximum_health(),store.starting_rerolls()]
	for id: String in _cards:
		var card: Dictionary = _cards[id]
		card.title.text = "%s   %d / %d" % [MetaProgressionStore.NAMES[id],store.level(id),MetaProgressionStore.MAX_LEVEL[id]]
		card.description.text = store.describe(id)
		var blocker := store.purchase_blocker(id)
		var cost := store.cost(id)
		card.button.disabled = not blocker.is_empty()
		card.button.text = blocker if not blocker.is_empty() else "锻造 · %d 碎屑 / %d 锚点" % [cost.x,cost.y]
		card.button.tooltip_text = "下一等级：%d 意志碎屑 + %d 现实锚点" % [cost.x,cost.y]
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
	Input.mouse_mode = _previous_mouse
	closed.emit()
	queue_free()

func _exit_tree() -> void:
	if not _closed and get_tree()!=null:
		get_tree().paused = _was_paused
		Input.mouse_mode = _previous_mouse
