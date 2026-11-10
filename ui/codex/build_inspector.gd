class_name BuildInspector
extends Control
## Read-only player inspection. Owns only the pause acquired by this panel.
var player: Player
var can_open: Callable
var opened := false
var _mouse_mode := Input.MOUSE_MODE_CAPTURED
var _fade: Tween
var _background: ColorRect
var content: VBoxContainer
var tabs: HBoxContainer
var _close_button: Button
var _refresh_pending := false
var _closing := false
var _snapshot := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material_value := ShaderMaterial.new()
	material_value.shader = preload("res://ui/codex/inspection_blur.gdshader")
	_background.material = material_value
	add_child(_background)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.06
	panel.anchor_right = 0.94
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.93
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151820f2")
	style.border_color = Color("eee7d2")
	style.set_border_width_all(1)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	panel.add_child(column)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation",12)
	column.add_child(tabs)
	var title := label("心智矩阵",36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(title)
	_close_button = Button.new()
	_close_button.text = "返回 · %s / ESC" % KeyHint.of("inspect_build")
	_close_button.pressed.connect(close)
	tabs.add_child(_close_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	if is_instance_valid(player):
		player.boons.changed.connect(_request_refresh)
		player.stats.changed.connect(_request_refresh)
		player.fragments.changed.connect(_request_refresh)
		player.health.died.connect(_on_death)

func try_open() -> bool:
	if opened or _closing or get_tree().paused or RunState.fixture != null:
		return false
	if not is_instance_valid(player) or player.health.is_dead() or not player.is_physics_processing():
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	opened = true
	_mouse_mode = Input.mouse_mode
	_release_actions()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_close_button.text = "返回 · %s / ESC" % KeyHint.of("inspect_build")
	refresh()
	show()
	modulate.a = 0.0
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(self,"modulate:a",1.0,0.12)
	_close_button.grab_focus()
	return true

func close(immediate := false) -> void:
	if not opened or _closing:
		return
	_closing = true
	if is_instance_valid(_fade):
		_fade.kill()
	if immediate:
		_finish_close()
	else:
		_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_fade.tween_property(self,"modulate:a",0.0,0.1)
		_fade.tween_callback(_finish_close)

func _finish_close() -> void:
	opened = false
	_closing = false
	hide()
	_release_actions()
	if not is_instance_valid(player) or not player.health.is_dead():
		get_tree().paused = false
		Input.mouse_mode = _mouse_mode

func _on_death(_source: Node = null) -> void:
	# Death UI takes ownership of the pause and pointer.
	close(true)

func _exit_tree() -> void:
	if opened and (not is_instance_valid(player) or not player.health.is_dead()):
		get_tree().paused = false
		Input.mouse_mode = _mouse_mode

func _release_actions() -> void:
	for action in KeyBindings.actions():
		Input.action_release(action)

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if opened:
		if event.is_action_pressed("inspect_build") or event.is_action_pressed("pause"):
			close()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inspect_build") and try_open():
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if opened and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()

func _request_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		refresh.call_deferred()

func snapshot() -> Dictionary:
	var data := {"slots":[],"traits":[],"shards":player.fragments.shards.duplicate(),"stats":{}}
	for slot in player.boons.slots:
		data.slots.append(slot.data.id if slot.data != null else "")
	for card in player.boons.traits:
		data.traits.append(card.id)
	data.stats = {"max_health":player.health.max_health,
		"move_speed":player.jog_speed*player.stats.get_value(Stats.MOVE_SPEED)*player.stasis_multiplier()*player.realm_effects.move_multiplier,
		"crit_chance":player.stats.get_value(Stats.CRIT_CHANCE),
		"dash_charges":player.dash_charges(),"dash_capacity":player.dash_max_charges(),
		"dash_recharge":player.stats.get_value(Stats.DASH_RECHARGE),
		"impact":0.0 if player.fragments.deprivations.has(PsycheFragments.WRATH) else player.melee.blade_data.impact_force}
	return data

func refresh() -> void:
	_refresh_pending = false
	if not opened or not is_instance_valid(player):
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_snapshot = snapshot()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",12)
	content.add_child(grid)
	for slot in player.boons.slots:
		var card := slot.data
		var frame := PanelContainer.new()
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		var accent := BoonIdentity.accent(card) if card != null else Color("686a70")
		card_style.bg_color = Color(accent.r*0.075+0.04,accent.g*0.075+0.04,accent.b*0.075+0.045,1.0)
		card_style.border_color = Color(accent,0.7)
		card_style.set_border_width_all(1)
		card_style.border_width_left = 3
		card_style.content_margin_left = 16
		card_style.content_margin_right = 16
		card_style.content_margin_top = 12
		card_style.content_margin_bottom = 12
		frame.add_theme_stylebox_override("panel",card_style)
		grid.add_child(frame)
		var box := VBoxContainer.new()
		frame.add_child(box)
		box.add_child(label(BoonIdentity.SLOT_NAMES[slot.index],20,Color("c6c3bc")))
		add_card(box,card)
	content.add_child(label("次级特质 · %d" % player.boons.traits.size(),26))
	for card in player.boons.traits:
		add_card(content,card,true)
	if player.boons.traits.is_empty():
		content.add_child(label("尚未获得次级特质",18,Color("aaa7a0")))
	content.add_child(label("心魔碎片",26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",26)
	content.add_child(row)
	for i in 4:
		var item := HBoxContainer.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := TextureRect.new()
		icon.texture = BoonIdentity.ICONS[i]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.custom_minimum_size = Vector2(32,32)
		icon.modulate = Color.WHITE if player.fragments.has_shard(i) else Color(0.35,0.35,0.35)
		item.add_child(icon)
		var caption := label(["沉睡","警醒","锋芒","温润"][i]+(" · 已收集" if player.fragments.has_shard(i) else " · 未收集"),20,BoonIdentity.COLORS[i])
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(caption)
		row.add_child(item)
	var s: Dictionary = _snapshot.stats
	content.add_child(label("当前属性",26))
	content.add_child(label("生命上限 %.0f     基础移速 %.2f m/s     暴击率 %.0f%%\n冲刺 %d / %d     充能速率 ×%.2f     普通刀击退力度 %.2f" % [s.max_health,s.move_speed,s.crit_chance*100,s.dash_charges,s.dash_capacity,s.dash_recharge,s.impact],22))

static func label(value: String,font_size: int,color := Color("eeeae2")) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

static func add_card(parent: Control,card: BoonData,trait_card := false) -> void:
	if card == null:
		parent.add_child(label("空槽",22,Color("8a8988")))
		return
	parent.add_child(label(card.name+(" ×1" if trait_card else ""),23,BoonIdentity.accent(card)))
	parent.add_child(label(card.description,18))
	if not card.stat_modifiers.is_empty():
		var parts: PackedStringArray = []
		for key in card.stat_modifiers:
			var modifier: Dictionary = card.stat_modifiers[key]
			var names := {"max_health":"生命上限","move_speed":"移速","damage":"枪伤","melee_damage":"刀伤","fire_rate":"射速","reload_speed":"重组速度","crit_chance":"暴击率","dash_recharge":"冲刺充能","damage_taken":"受到伤害","melee_speed":"挥刃速度","melee_range":"刀击距离","crit_multiplier":"暴击伤害","magazine_size":"弹匣容量","clock_progress":"敲钟进度","clock_window":"完美窗口","armor":"护甲"}
			parts.append("%s  +%.2f / ×%.2f" % [names.get(key,"能力增幅"),modifier.get("add",0),modifier.get("mul",1)])
		parent.add_child(label(" · ".join(parts),16,Color("aaa7a0")))
