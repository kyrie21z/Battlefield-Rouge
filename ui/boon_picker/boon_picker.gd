class_name BoonPicker
extends CanvasLayer
## Paused reward presentation. The zone owns offer RNG and reroll currency.

signal chosen(boon: BoonData)
signal reroll_requested
signal skipped

class SelectionAudio extends AudioStreamPlayer:
	func _exit_tree() -> void:
		stop()
		stream = null

const TEXT := Color("f2eee7")
const MUTED := Color("a5a9b4")
const IDLE_HINT := "以心魔的力量改变你的枪、刃与步伐   ·   悬停卡片查看该领域机制"
var manager: BoonManager
var _offered: Array[BoonData] = []
var _selected := false
var _pending: BoonData
var _charges := 0
var _buttons: Array[Button] = []
var _tweens: Array[Tween] = []
var _confirmation: PanelContainer
var _confirm_text: Label
var _reroll: Button
var _continue: Button
var _notice: Label
var _title: Label
var _mechanic: Label
var _owned: Label
var _choices: HBoxContainer
var _audio: AudioStreamPlayer
var _previous_pause := false
var _previous_mouse := Input.MOUSE_MODE_VISIBLE
var _completed := false
var _built := false


func prebuild_ui() -> void:
	if _built:
		return
	_built = true
	_build()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_pause = get_tree().paused
	_previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prebuild_ui()


func setup(boons: Array[BoonData], owner_manager: BoonManager, title: String = "选择心魔的馈赠", charges: int = 0) -> void:
	manager = owner_manager
	_title.text = title
	update_offer(boons, charges)


func update_offer(boons: Array[BoonData], charges: int) -> void:
	if _selected or _pending != null:
		return
	_offered.assign(boons)
	_charges = maxi(0, charges)
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_buttons.clear()
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for i in _offered.size():
		var button := _make_card(_offered[i], i)
		_choices.add_child(button)
		_buttons.append(button)
	var all_replace := _all_replacements()
	_reroll.text = "重抽   /   剩余 %d 次" % _charges
	_reroll.disabled = _charges <= 0 or _offered.is_empty()
	_continue.visible = _offered.is_empty() or all_replace
	_continue.text = "继续前进" if _offered.is_empty() else "放弃这次馈赠"
	if _offered.is_empty():
		_notice.text = "当前没有可选赐福"
	elif all_replace:
		_notice.text = "三张都会替换现有赐福   ·   可以放弃   ·   R 重抽"
	else:
		_notice.text = "按 1 / 2 / 3 选择   ·   R 重抽"
	_refresh_owned()
	_reset_help()
	_animate_cards.call_deferred()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.018, 0.021, 0.032, 0.90)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var eyebrow := BoonPresentation.label("M I N D   F R E A K   /   心 魔 馈 赠", 17, Color("d0b780"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(eyebrow)
	_title = BoonPresentation.label("选择心魔的馈赠", 36, TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	# 机制说明栏：悬停哪张卡就显示哪个领域的机制。放在标题与卡片之间、参与布局，
	# 这样它永远不会像系统 tooltip 那样盖住卡面上的技能描述。
	_mechanic = BoonPresentation.label(IDLE_HINT, 17, MUTED)
	_mechanic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mechanic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mechanic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mechanic.custom_minimum_size = Vector2(0, 50)
	box.add_child(_mechanic)
	_choices = HBoxContainer.new()
	_choices.name = "Choices"
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 22)
	box.add_child(_choices)
	_owned = BoonPresentation.label("", 18, MUTED)
	_owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_owned)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 32)
	box.add_child(footer)
	_notice = BoonPresentation.label("", 18, MUTED)
	footer.add_child(_notice)
	_reroll = Button.new()
	_reroll.name = "Reroll"
	_reroll.custom_minimum_size = Vector2(220, 44)
	_reroll.pressed.connect(_request_reroll)
	footer.add_child(_reroll)
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.text = "继续前进"
	_continue.custom_minimum_size = Vector2(180, 44)
	_continue.pressed.connect(_skip_empty)
	footer.add_child(_continue)
	_continue.hide()
	_build_confirmation()
	_audio = SelectionAudio.new()
	_audio.stream = ProceduralAudio.generate("hit_tink")
	_audio.volume_db = -13.0
	add_child(_audio)


func _make_card(data: BoonData, index: int) -> Button:
	var accent := BoonPresentation.accent(data)
	var button := Button.new()
	button.name = "Choice%d" % (index + 1)
	var viewport := get_viewport().get_visible_rect().size
	# Cards now carry up to five lines of description, so the height has to track
	# the window instead of a fixed 500 or the accept row falls off the bottom.
	var card_height := clampf(viewport.y - 420.0, 408.0, 560.0)
	button.custom_minimum_size = Vector2(clampf((viewport.x - 140.0) / 3.0, 280.0, 400.0), card_height)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var border_width := 1 + mini(int(data.rarity), 3)
	var normal := BoonPresentation.panel(Color("12151e"), accent.darkened(0.4), border_width)
	normal.shadow_color = Color(accent, 0.13 + 0.045 * data.rarity)
	normal.shadow_size = 8 + int(data.rarity) * 3
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", BoonPresentation.panel(Color("20222e"), accent, border_width))
	button.add_theme_stylebox_override("focus", BoonPresentation.panel(Color("20222e"), accent, border_width))
	button.add_theme_stylebox_override("pressed", BoonPresentation.panel(Color("30303c"), accent.lightened(0.3), border_width))
	button.pressed.connect(_choose.bind(data))
	button.mouse_entered.connect(_hover_help.bind(data))
	button.mouse_exited.connect(_reset_help)
	button.button_down.connect(func(): button.scale = Vector2.ONE * 0.975)
	button.button_up.connect(func(): button.scale = Vector2.ONE)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 26
	content.offset_right = -26
	content.offset_top = 24
	content.offset_bottom = -24
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)
	var identity := BoonPresentation.label(BoonPresentation.identity(data), 20, accent)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	row.add_child(BoonPresentation.label(BoonPresentation.RARITIES[data.rarity], 16, accent))
	var icon := TextureRect.new()
	icon.texture = BoonPresentation.icon(data)
	icon.custom_minimum_size = Vector2(80, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var title := BoonPresentation.label(data.name, 28, TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	content.add_child(BoonPresentation.label("◇  " + BoonPresentation.SLOT_NAMES[data.slot] + ("槽位" if data.core else "特性"), 17, accent))
	var description := BoonPresentation.label(data.description, 18, Color("c9c9d1"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(description)
	var old := _replaced(data)
	var warning := BoonPresentation.label("替换「%s」" % old.name if old != null else "[ %d ]  接受馈赠" % (index + 1), 17, Color("ff8888") if old != null else accent)
	warning.custom_minimum_size.y = 26
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(warning)
	return button


func _animate_cards() -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2(0.02, 0.96)
		button.modulate.a = 0.0
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tweens.append(tween)
		tween.tween_interval(i * 0.09)
		tween.set_parallel(true)
		tween.tween_property(button, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 1.0, 0.22)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _build_confirmation() -> void:
	var overlay := CenterContainer.new()
	overlay.name = "ReplaceOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_confirmation = PanelContainer.new()
	_confirmation.name = "Confirmation"
	_confirmation.custom_minimum_size = Vector2(580, 240)
	_confirmation.add_theme_stylebox_override("panel", BoonPresentation.panel(Color("21171e"), Color("f08686"), 2))
	overlay.add_child(_confirmation)
	_confirmation.hide()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	_confirmation.add_child(box)
	box.add_child(BoonPresentation.label("替换现有槽位？", 28, Color("ffaaaa")))
	_confirm_text = BoonPresentation.label("", 21, TEXT)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size.x = 530
	box.add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for accept in [false, true]:
		var button := Button.new()
		button.name = "Confirm" if accept else "Cancel"
		button.text = "确认替换" if accept else "保留原赐福"
		button.custom_minimum_size = Vector2(250, 48)
		button.pressed.connect(confirm_replacement.bind(accept))
		row.add_child(button)


## 卡片悬浮说明：普通卡只讲自己那一系，双重卡把两系的机制都列出来。
func _help_for(data: BoonData) -> String:
	if data.rarity == BoonData.Rarity.DUAL and not data.required_sins.is_empty():
		var parts: PackedStringArray = []
		for sin in data.required_sins:
			parts.append(BoonPresentation.realm_help_inline(sin, 2))
		return "  ／  ".join(parts)
	return BoonPresentation.realm_help_inline(data.sin)


func _hover_help(data: BoonData) -> void:
	if not is_instance_valid(_mechanic):
		return
	_mechanic.text = _help_for(data)
	_mechanic.add_theme_color_override("font_color",
		BoonPresentation.accent(data).lightened(0.35))


func _reset_help() -> void:
	if not is_instance_valid(_mechanic):
		return
	_mechanic.text = IDLE_HINT
	_mechanic.add_theme_color_override("font_color", MUTED)


func _replaced(data: BoonData) -> BoonData:
	if manager == null or not data.core:
		return null
	var old: BoonData = manager.slots[data.slot].data
	return old if old != null and old.id != data.id else null


## 三张都会替换现有核心卡吗？是的话这一轮其实没有真正的选择。
func _all_replacements() -> bool:
	if _offered.is_empty() or manager == null:
		return false
	for card in _offered:
		if _replaced(card) == null:
			return false
	return true


func _choose(data: BoonData) -> void:
	if _selected or _pending != null or not _offered.has(data) or manager == null or not manager.can_equip(data):
		return
	var old := _replaced(data)
	if manager.request_equip(data):
		_accept(data)
	elif old != null:
		_pending = data
		_confirm_text.text = "「%s」将替换「%s」。旧槽位效果会移除；其余特性保留。" % [data.name, old.name]
		_confirmation.show()
		for button in _buttons:
			button.disabled = true
		_reroll.disabled = true
		(_confirmation.find_child("Cancel", true, false) as Button).grab_focus()


func confirm_replacement(accept: bool) -> void:
	if _pending == null or _selected:
		return
	var data := _pending
	_pending = null
	_confirmation.hide()
	var equipped := manager.confirm_replace(accept)
	if accept and equipped:
		_accept(data)
	else:
		for button in _buttons:
			button.disabled = false
		_reroll.disabled = _charges <= 0


func _accept(data: BoonData) -> void:
	_selected = true
	_completed = true
	for button in _buttons:
		button.disabled = true
	# Keep the click sound alive while the selection layer closes.
	remove_child(_audio)
	manager.add_child(_audio)
	_audio.play()
	_audio.finished.connect(_audio.queue_free)
	manager.feedback(manager.player.global_position + Vector3.UP, BoonPresentation.accent(data), 0.7)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chosen.emit(data)
	queue_free()


func _request_reroll() -> void:
	if _selected or _pending != null or _charges <= 0:
		return
	_reroll.disabled = true
	reroll_requested.emit()


func show_reroll_cost() -> void:
	_notice.text = "重抽消耗 −1   ·   余下 %d 次" % _charges
	_audio.play()


## 空池、或整轮都会替换现有构筑时都能直接放弃。
func _skip_empty() -> void:
	if _selected or not (_offered.is_empty() or _all_replacements()):
		return
	_selected = true
	_completed = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	skipped.emit()
	queue_free()


func _refresh_owned() -> void:
	var parts: PackedStringArray = []
	if manager != null:
		for i in 3:
			var data: BoonData = manager.slots[i].data
			parts.append(BoonPresentation.SLOT_NAMES[i] + " / " + (data.name if data != null else "未赋能"))
	_owned.text = "    ·    ".join(parts)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _selected:
		return
	if _pending != null:
		if event.physical_keycode == KEY_ESCAPE:
			confirm_replacement(false)
		get_viewport().set_input_as_handled()
		return
	var index: int = event.physical_keycode - KEY_1
	if index >= 0 and index < _offered.size():
		_choose(_offered[index])
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_R:
		_request_reroll()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if not _completed and is_inside_tree() and get_tree() != null:
		if _pending != null and is_instance_valid(manager):
			manager.confirm_replace(false)
		get_tree().paused = _previous_pause
		Input.mouse_mode = _previous_mouse


func dismiss_for_transition() -> void:
	# The incoming end screen/scene already owns the pause and mouse state.
	_selected = true
	_completed = true
	if _pending != null and is_instance_valid(manager):
		manager.confirm_replace(false)
	queue_free()
