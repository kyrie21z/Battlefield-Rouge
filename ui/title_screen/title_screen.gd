class_name TitleScreen
extends Control

signal action_requested(action: Action)

enum Action { START, RESET, RESUME, HUB, ABANDON }

const TAGLINE := "在停摆的那一刻，醒来。"
const RECONCILED_TAGLINE := "不再完美，但终于完整。"
const REALM_NAMES := ["怠惰", "恐惧", "愤怒", "悲伤"]
const CROWN_HOVER := 0.14

@onready var _gallery: Node3D = $Gallery
@onready var _body: ProtagonistBody = $Gallery/Portrait/Body
@onready var _camera: Camera3D = $Gallery/Camera
@onready var _crown_light: OmniLight3D = $Gallery/Portrait/CrownLight
var _crown: CrownModel
var _flow: KintsugiFlow
var _time := 0.0
var _parallax := Vector2.ZERO
var _camera_rest: Vector3
var _settings := GameSettings.new()
var _menu: VBoxContainer
var _options: VBoxContainer
var _tagline: Label
var _summary: Label
var _error: Label
var _primary: Button
var _buttons: Dictionary
var _pips: Array[ColorRect] = []
var _pip_row: HBoxContainer
var _pause_menu: PauseMenu
var _confirmation: ConfirmationDialog
var _confirm_action: Action
var _primary_action: Action
var _modal_focus: Button


func _ready() -> void:
	EditorialStyle.apply_theme(self)
	_build_gallery()
	_build_menu()
	_camera_rest = _camera.position
	_crown = CrownModel.new()
	_crown.show_when_worn = true
	_body.add_child(_crown)
	_settings.load_from(GameSettings.settings_path)
	_pause_menu.setup(_settings)
	_settings.changed.connect(_apply_motion)
	MetaProgression.changed.connect(refresh_from_store.bind(MetaProgression))
	refresh_from_store(MetaProgression)
	_apply_motion()
	resized.connect(_position_gallery)
	_position_gallery()
	_primary.grab_focus()


func refresh_from_store(store: MetaProgressionStore) -> void:
	var archive := store.archive_snapshot()
	var reconciled: bool = archive.reconciled
	var defeated: Array = archive.defeated_realms
	var crowned := store.opening_completed or reconciled
	var level := clampi(defeated.size(), 0, 4) if crowned and not reconciled else 0
	if reconciled:
		if not is_instance_valid(_flow):
			_flow = KintsugiFlow.attach(_body, BodyReassembly.COLORS)
			_flow.reduced_motion = _settings.reduced_motion
	else:
		if is_instance_valid(_flow):
			_body.remove_child(_flow)
			_flow.queue_free()
			_flow = null
		_body.set_fracture_level(level)
	_crown.set_worn(crowned)
	_crown.set_emission_strength(0.55 if reconciled else 0.5 * pow(2.4, level))
	_crown_light.light_energy = minf(_crown.emission_strength * 0.065, 0.65)
	_tagline.text = RECONCILED_TAGLINE if reconciled else TAGLINE
	_pip_row.visible = crowned
	for index in _pips.size():
		var lit := crowned and (reconciled or defeated.has(index))
		_pips[index].color = BodyReassembly.COLORS[index] if lit else Color("c4c2bc")
	_update_pose()

	var has_profile := store.has_profile()
	var checkpoint := store.active_run
	_buttons.Reset.visible = has_profile
	_buttons.Abandon.visible = not checkpoint.is_empty()
	if not checkpoint.is_empty():
		_primary_action = Action.RESUME
		_primary.text = "继续当前挑战"
		var floor_index: int = checkpoint.floor_index
		_summary.text = "终局返程回廊" if floor_index == 4 else "第 %d 层 · %s 房 %d/3" % [
			floor_index + 1, REALM_NAMES[checkpoint.order[floor_index]], int(checkpoint.room_index) + 1]
	elif has_profile:
		_primary_action = Action.HUB
		_primary.text = "继续游戏"
		_summary.text = "静滞之门 · 第 %d 次 · %d/4 心魔 · %d 碎屑" % [
			store.history.run_count, defeated.size(), store.will_shards]
	else:
		_primary_action = Action.START
		_primary.text = "开始游戏"
		_summary.text = ""
	_summary.visible = not _summary.text.is_empty()
	_link_focus()


func bust_state() -> Dictionary:
	return {
		"crown_hovering": not _crown.worn,
		"crown_emission": _crown.emission_strength,
		"fracture_level": _body.fracture_level,
		"kintsugi": is_instance_valid(_flow),
		"tagline": _tagline.text,
		"lit_realms": _pips.filter(func(pip: ColorRect): return pip.color != Color("c4c2bc")).size(),
	}


func reduced_motion_enabled() -> bool:
	return _settings.reduced_motion


func set_routing(routing: bool) -> void:
	_options.process_mode = Node.PROCESS_MODE_DISABLED if routing else Node.PROCESS_MODE_INHERIT
	_pause_menu.process_mode = Node.PROCESS_MODE_DISABLED if routing else Node.PROCESS_MODE_ALWAYS
	for button: Button in _buttons.values():
		button.disabled = routing
	if not routing:
		_primary.grab_focus()


func show_error(message: String) -> void:
	_error.text = "无法进入，请重试。" if message.is_empty() else message
	_error.show()


func _position_gallery() -> void:
	# Keep the same portrait size and centre as the viewport grows sideways.
	var aspect := size.x / maxf(size.y, 1.0)
	_camera.h_offset = -0.205 * _camera.size * aspect
	_update_pose()


func _process(delta: float) -> void:
	_time += delta
	var pointer := get_local_mouse_position() / size - Vector2(0.5, 0.5)
	var target := pointer.clamp(-Vector2.ONE, Vector2.ONE) * 0.017
	_parallax = _parallax.lerp(target, 1.0 - exp(-delta * 4.0))
	_update_pose()


func _apply_motion() -> void:
	set_process(not _settings.reduced_motion)
	_body.set_portrait_motion(not _settings.reduced_motion)
	_body.fracture.set_process(not _settings.reduced_motion)
	if is_instance_valid(_flow):
		_flow.reduced_motion = _settings.reduced_motion
		_flow._process(0.0)
	if _settings.reduced_motion:
		_time = 0.0
		_parallax = Vector2.ZERO
	_update_pose()


func _update_pose() -> void:
	var hover := (CROWN_HOVER + 0.012 * sin(_time * 1.25)) if not _crown.worn else 0.0
	_crown.position = _body.portrait_crown_position() + Vector3.UP * hover
	_crown_light.position = _crown.position + Vector3(-0.05, 0.08, -0.12)
	_camera.position = _camera_rest + Vector3(_parallax.x, _parallax.y, 0)


func _build_gallery() -> void:
	var world: WorldEnvironment = $Gallery/WorldEnvironment
	var environment := world.environment.duplicate() as Environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("f9f9f7")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f0edeb")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.32
	world.environment = environment
	var stone := CrownModel.material(Color.WHITE, 0.0, 0.96)
	_stone(Vector3(0, -0.1, 3), Vector3(18, 0.2, 18), stone)
	for index in 7:
		var x := -2.65 + index * 0.62
		_stone(Vector3(x, 1.13, 2.8), Vector3(0.16, 2.26, 0.48), stone)
		_stone(Vector3(x, 2.03, 2.8), Vector3(0.21, 0.12, 0.56), stone)
	_stone(Vector3(0, 2.19, 2.8), Vector3(11, 0.22, 0.72), stone)


func _stone(center: Vector3, dimensions: Vector3, material: Material) -> void:
	var block := CrownModel.slab(dimensions, material)
	block.position = center
	_gallery.add_child(block)


func _build_menu() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.405, 0.52, 1.0])
	gradient.colors = PackedColorArray([Color("fbfaf7"), Color("fbfaf7"), Color("fbfaf700"), Color("fbfaf700")])
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.width = 1024
	wash.height = 1
	var scrim := TextureRect.new()
	scrim.texture = wash
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 17)
	add_child(_menu)
	_menu.anchor_left = 0.066
	_menu.anchor_right = 0.395
	_menu.anchor_top = 0.174
	_menu.add_child(EditorialStyle.make_label("THRESHOLD // 静滞之门", 23, Color("786340"), 700, true))
	var heading := EditorialStyle.make_label("MIND FREAK", 82, EditorialStyle.INK, 900)
	_menu.add_child(heading)
	_tagline = EditorialStyle.make_label("", 28, EditorialStyle.INK_MUTED, 500)
	_menu.add_child(_tagline)
	_menu.add_child(EditorialStyle.make_rule(Color("b4aa9a")))
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 8)
	_menu.add_child(_options)
	_primary = _button("Primary", "", _request_primary, true)
	_summary = EditorialStyle.make_label("", 20, EditorialStyle.INK_MUTED, 500)
	_options.add_child(_summary)
	_button("Abandon", "返回静滞之门", _confirm.bind(Action.ABANDON))
	_button("Reset", "新游戏", _confirm.bind(Action.RESET))
	_button("Settings", "设置与按键", func(): _pause_menu.try_open())
	_button("Quit", "退出游戏", func(): get_tree().quit())
	_error = EditorialStyle.make_label("", 20, Color("8a3131"), 600)
	_error.hide()
	_menu.add_child(_error)

	_pip_row = HBoxContainer.new()
	_pip_row.add_theme_constant_override("separation", 23)
	add_child(_pip_row)
	_pip_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pip_row.offset_left = -222
	_pip_row.offset_top = 70
	for realm in REALM_NAMES:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(20, 20)
		var pip := ColorRect.new()
		pip.size = Vector2(11, 11)
		pip.position = Vector2(4.5, 4.5)
		pip.pivot_offset = pip.size * 0.5
		pip.rotation = PI / 4
		cell.tooltip_text = realm
		_pip_row.add_child(cell)
		cell.add_child(pip)
		_pips.append(pip)

	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	_pause_menu.opened.connect(func(): _options.hide())
	_pause_menu.closed.connect(func():
		_options.show()
		_buttons.Settings.grab_focus())

	_confirmation = ConfirmationDialog.new()
	_confirmation.name = "Confirmation"
	_confirmation.exclusive = true
	_confirmation.cancel_button_text = "取消"
	_confirmation.confirmed.connect(func(): action_requested.emit(_confirm_action))
	_confirmation.canceled.connect(func():
		if is_instance_valid(_modal_focus):
			_modal_focus.grab_focus.call_deferred())
	add_child(_confirmation)
	_confirmation.theme = theme
	_confirmation.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	EditorialStyle.style_label(_confirmation.get_label(), 23, EditorialStyle.PAPER)
	EditorialStyle.style_button(_confirmation.get_cancel_button(), false, false, 20)
	EditorialStyle.style_button(_confirmation.get_ok_button(), true, false, 20)


func _button(id: String, label: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.name = id
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 70 if primary else 53
	EditorialStyle.style_button(button, primary, true, 26 if primary else 23)
	if not primary:
		var flat := EditorialStyle.button_box(Color.TRANSPARENT, Color("d8d1c5"), 1)
		flat.border_width_left = 0
		flat.border_width_right = 0
		flat.border_width_top = 0
		button.add_theme_stylebox_override("normal", flat)
	button.pressed.connect(callback)
	_options.add_child(button)
	_buttons[id] = button
	return button


func _link_focus() -> void:
	var visible_buttons := _buttons.values().filter(func(button: Button): return button.visible)
	for index in visible_buttons.size():
		var button: Button = visible_buttons[index]
		button.focus_neighbor_top = button.get_path_to(visible_buttons[posmod(index - 1, visible_buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(visible_buttons[(index + 1) % visible_buttons.size()])


func _request_primary() -> void:
	action_requested.emit(_primary_action)


func _confirm(action: Action) -> void:
	_confirm_action = action
	var reset := action == Action.RESET
	_modal_focus = _buttons.Reset if reset else _buttons.Abandon
	_confirmation.title = "开启新游戏？" if reset else "放弃当前挑战？"
	_confirmation.dialog_text = (
		"当前进度、解锁与未完挑战将被重置。原存档会保留为 .bak 备份。"
		if reset else "将结算已保存至房间起点的碎屑与锚点。当前挑战将结束，未保存的本房收益将丢失。")
	_confirmation.ok_button_text = "重置并开始" if reset else "结算并返回"
	_confirmation.popup_centered(Vector2i(660, 230))
	_confirmation.get_cancel_button().grab_focus.call_deferred()
