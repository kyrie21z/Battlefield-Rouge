class_name BoonPicker
extends CanvasLayer
## Paused reward presentation (Scheme B: Architectural Editorial ivory cards).
## The zone owns offer RNG and reroll currency.

signal chosen(boon: BoonData)
signal reroll_requested
signal skipped

class SelectionAudio extends AudioStreamPlayer:
	func _exit_tree() -> void:
		stop()
		stream = null

const TEXT := EditorialStyle.PAPER
const MUTED := EditorialStyle.ASH
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
	layer = 25
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
	dim.color = Color(0.055, 0.062, 0.082, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EditorialStyle.apply_theme(center)
	add_child(center)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var eyebrow_wrap := CenterContainer.new()
	eyebrow_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(eyebrow_wrap)
	eyebrow_wrap.add_child(EditorialStyle.make_eyebrow("MIND FREAK   //   心魔馈赠", 14))

	_title = EditorialStyle.make_label("选择心魔的馈赠", 38, TEXT, 800, false, 3)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	# 机制说明栏：悬停哪张卡就显示哪个领域的机制，放在标题与卡片之间且参与布局。
	_mechanic = EditorialStyle.make_label(IDLE_HINT, 16, MUTED, 500)
	_mechanic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mechanic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mechanic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mechanic.custom_minimum_size = Vector2(0, 44)
	box.add_child(_mechanic)

	_choices = HBoxContainer.new()
	_choices.name = "Choices"
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 24)
	box.add_child(_choices)

	_owned = EditorialStyle.make_label("", 16, EditorialStyle.ASH, 600, true, 1)
	_owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_owned)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	box.add_child(footer)

	_notice = EditorialStyle.make_label("", 16, MUTED, 600)
	footer.add_child(_notice)

	_reroll = Button.new()
	_reroll.name = "Reroll"
	_reroll.custom_minimum_size = Vector2(228, 46)
	EditorialStyle.style_button(_reroll, false, false, 17)
	_reroll.pressed.connect(_request_reroll)
	footer.add_child(_reroll)

	_continue = Button.new()
	_continue.name = "Continue"
	_continue.text = "继续前进"
	_continue.custom_minimum_size = Vector2(196, 46)
	EditorialStyle.style_button(_continue, false, false, 17)
	_continue.pressed.connect(_skip_empty)
	footer.add_child(_continue)
	_continue.hide()

	_build_confirmation()
	_audio = SelectionAudio.new()
	_audio.stream = ProceduralAudio.generate("hit_tink")
	_audio.volume_db = -13.0
	add_child(_audio)


func _card_style(bg: Color, border: Color, top_color: Color, shadow_offset: Vector2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.border_width_top = 6
	if border == EditorialStyle.INK:
		style.border_color = border
	style.set_corner_radius_all(0)
	style.shadow_color = Color(EditorialStyle.INK, 0.90)
	style.shadow_size = 1
	style.shadow_offset = shadow_offset
	# Keep border_color crisp ink; the top accent strip is drawn as a dedicated ColorRect
	# so top bar uses realm color while the outer 2px frame stays sharp carbon ink.
	style.border_width_top = 2
	style.border_color = border if top_color == Color.TRANSPARENT else border
	return style


func _make_card(data: BoonData, index: int) -> Button:
	var accent := BoonPresentation.paper_accent(data)
	var button := Button.new()
	button.name = "Choice%d" % (index + 1)
	var viewport := get_viewport().get_visible_rect().size
	var card_height := clampf(viewport.y - 400.0, 412.0, 540.0)
	button.custom_minimum_size = Vector2(clampf((viewport.x - 160.0) / 3.0, 290.0, 396.0), card_height)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	button.add_theme_stylebox_override("normal",
		_card_style(EditorialStyle.PAPER, EditorialStyle.INK, accent, Vector2(6, 6)))
	button.add_theme_stylebox_override("hover",
		_card_style(Color("ffffff"), accent, accent, Vector2(8, 8)))
	button.add_theme_stylebox_override("focus",
		_card_style(Color("ffffff"), EditorialStyle.GOLD, accent, Vector2(8, 8)))
	button.add_theme_stylebox_override("pressed",
		_card_style(EditorialStyle.PAPER_SOFT, EditorialStyle.INK, accent, Vector2(2, 2)))

	button.pressed.connect(_choose.bind(data))
	button.mouse_entered.connect(_hover_help.bind(data))
	button.mouse_exited.connect(_reset_help)
	button.button_down.connect(func(): button.scale = Vector2.ONE * 0.98)
	button.button_up.connect(func(): button.scale = Vector2.ONE)

	# Child 0 MUST remain the main VBoxContainer whose last child is the replacement/CTA Label
	# (verified by tests/boon_picker_test.gd).
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 0
	content.offset_right = 0
	content.offset_top = 0
	content.offset_bottom = 0

	# Top realm color architectural band
	var top_bar := ColorRect.new()
	top_bar.color = accent
	top_bar.custom_minimum_size.y = 6
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(top_bar)

	# Inner padded editorial body
	var body_margin := MarginContainer.new()
	body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 24)
	body_margin.add_theme_constant_override("margin_right", 24)
	body_margin.add_theme_constant_override("margin_top", 12)
	body_margin.add_theme_constant_override("margin_bottom", 8)
	content.add_child(body_margin)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 10)
	body_margin.add_child(body)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(row)
	var identity := EditorialStyle.make_label(BoonPresentation.identity(data), 16, accent, 800, false, 1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	var rarity_label := EditorialStyle.make_label(BoonPresentation.RARITIES[data.rarity], 13, EditorialStyle.SLATE, 700, true, 1)
	row.add_child(rarity_label)

	# Architectural dark emblem tile so bright/pale SVG icons read crisply on ivory paper
	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(icon_center)
	var icon_frame := PanelContainer.new()
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.INK, accent, 2, Vector2(3, 3), Color(EditorialStyle.INK, 0.25), 10, 10))
	icon_center.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.texture = BoonPresentation.icon(data)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon)

	var title := EditorialStyle.make_label(data.name, 26, EditorialStyle.INK, 800, false, 1)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)

	var slot_badge := EditorialStyle.make_label(("◆  " if data.core else "◇  ") + BoonPresentation.SLOT_NAMES[data.slot] + ("核心槽" if data.core else "特性"), 15, accent, 700)
	body.add_child(slot_badge)

	body.add_child(EditorialStyle.make_rule(EditorialStyle.PAPER_DIM, 1))

	var description := EditorialStyle.make_label(data.description, 17, Color("2a2e36"), 500)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_constant_override("line_spacing", 5)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(description)

	# Bottom inverted full-bleed carbon-ink CTA strip (last child of `content` for test contract)
	var old := _replaced(data)
	var is_replace := old != null
	var cta_text := "替换「%s」" % old.name if is_replace else "[ %d ]   接受馈赠  →" % (index + 1)
	var warning := EditorialStyle.make_label(cta_text, 16, EditorialStyle.PAPER, 700, false, 1)
	warning.custom_minimum_size.y = 44
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cta_bg := EditorialStyle.WARNING if is_replace else EditorialStyle.INK
	warning.add_theme_stylebox_override("normal",
		EditorialStyle.plaque(cta_bg, cta_bg, 0, Vector2.ZERO, Color.TRANSPARENT, 16, 10))
	content.add_child(warning)
	return button


func _animate_cards() -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2(0.92, 0.92)
		button.modulate.a = 0.0
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tweens.append(tween)
		tween.tween_interval(i * 0.08)
		tween.set_parallel(true)
		tween.tween_property(button, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 1.0, 0.20)
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
	_confirmation.custom_minimum_size = Vector2(600, 250)
	var conf_style := EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(8, 8), Color(EditorialStyle.INK, 0.92), 30, 26)
	conf_style.border_width_top = 6
	conf_style.border_color = EditorialStyle.WARNING
	_confirmation.add_theme_stylebox_override("panel", conf_style)
	overlay.add_child(_confirmation)
	_confirmation.hide()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_confirmation.add_child(box)
	box.add_child(EditorialStyle.make_label("替换现有核心槽位？", 26, EditorialStyle.WARNING, 800, false, 1))
	_confirm_text = EditorialStyle.make_label("", 19, EditorialStyle.INK, 500)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size.x = 536
	box.add_child(_confirm_text)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for accept in [false, true]:
		var button := Button.new()
		button.name = "Confirm" if accept else "Cancel"
		button.text = "确认替换" if accept else "保留原赐福"
		button.custom_minimum_size = Vector2(258, 48)
		EditorialStyle.style_button(button, accept, true, 18)
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
		BoonPresentation.accent(data).lightened(0.28))


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
	GamePointer.restore(Input.MOUSE_MODE_CAPTURED, get_window())
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
	GamePointer.restore(Input.MOUSE_MODE_CAPTURED, get_window())
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
		GamePointer.restore(_previous_mouse, get_window())


func dismiss_for_transition() -> void:
	# The incoming end screen/scene already owns the pause and mouse state.
	_selected = true
	_completed = true
	if _pending != null and is_instance_valid(manager):
		manager.confirm_replace(false)
	queue_free()
