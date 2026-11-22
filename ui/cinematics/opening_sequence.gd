class_name OpeningSequence
extends Node3D
## One production Player and one ViewCamera from blackout to walking through the gate.
signal combat_entry_requested
signal phase_changed(phase: int)
enum Phase { TITLE, FALL, BLINK, BODY, ENCOUNTER, CROWNING, PLAYABLE, COMPLETE }
const BLINK_SHADER := preload("res://ui/cinematics/shaders/eye_blink.gdshader")
const LINES := [
	["wake", "醒了吗？感觉好点了吗？别怕，我在这里。"],
	["care", "别去想刚才的意外。那不是你的水平。你比任何人以为的，都要优秀。"],
	["obstacle", "只是那些潜伏在深处的老毛病，又在关键时刻绊了我们一跤。"],
	["better", "听我说，你可以做到更好。你生来就是属于顶峰的。"],
	["invitation", "来，我们一起把那些拖慢脚步的心魔清理干净。下一次，让他们心服口服。"]]
var phase := Phase.TITLE
var phase_time := 0.0
var player: Player
var camera: Camera3D
var crown: CrownModel
var audio: AudioStreamPlayer
var stress_audio: AudioStreamPlayer
var crown_voice_dsp: CrownVoiceDSP
var overlay: ColorRect
var mask: ShaderMaterial
var subtitle: Label
var title_panel: PanelContainer
var skip_button: Button
var motion_button: CheckButton
var doors: Array[StaticBody3D] = []
var clips: Dictionary = {}
var spoken: Array[String] = []
var blink_count := 0
var entry_count := 0
var reduced_motion := false
var control_released := false
var _line_index := -1
var _speech_duration := 0.0
var _voice_bus := ""
var _lowpass: AudioEffectLowPassFilter
var _base_eye_y := 0.0

func _ready() -> void:
	_make_world()
	player = preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.position = Vector3(0, 0.02, 4)
	camera = player.view_camera
	camera.make_current()
	_base_eye_y = player._head.position.y
	_set_control(false)
	player.weapon.hide()
	player.melee.hide()
	crown = CrownModel.new()
	crown.position = Vector3(0, 1.75, 1.35)
	crown.hide()
	add_child(crown)
	_make_audio()
	_make_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _make_world() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = preload("res://environments/default_env.tres").duplicate() as Environment
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.86, 0.88, 0.89)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.77, 0.81, 0.89)
	environment.environment.ambient_light_energy = 0.7
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled = true
	add_child(environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52, -32, 0)
	sunlight.light_energy = 1.4
	sunlight.shadow_enabled = true
	add_child(sunlight)
	var white := CrownModel.material(Color(0.84, 0.86, 0.88), 0.0, 0.85)
	var shade := CrownModel.material(Color(0.52, 0.58, 0.64), 0.0, 0.8)
	_box(Vector3(0, -0.35, -5), Vector3(26, 0.7, 36), shade)
	for side in [-1.0, 1.0]:
		for index in 6:
			_box(Vector3(side * (8 + index % 2), 4.0 + index * 0.3, 7 - index * 5), Vector3(1.2, 8 + index * 0.6, 1.8), white)
			_box(Vector3(side * 6.7, 0.02, 4 - index * 4.5), Vector3(0.06, 0.025, 3), white)
		_box(Vector3(side * 4.0, 3, -12), Vector3(1.2, 6, 1.5), white)
		var door := _box(Vector3(side * 1.65, 2.8, -12), Vector3(3.25, 5.6, 0.38), white)
		doors.append(door)
	_box(Vector3(0, 6, -12), Vector3(9.2, 0.8, 1.5), white)
	_box(Vector3(0, 0.02, -12), Vector3(7.5, 0.04, 0.14), white)
	var sign := Label3D.new()
	sign.text = "THRESHOLD / 心智之门"
	sign.position = Vector3(0, 5.1, -11.75)
	sign.pixel_size = 0.007
	sign.font_size = 46
	sign.modulate = Color(0.20, 0.24, 0.30)
	add_child(sign)

func _box(point: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.position = point
	body.add_child(CrownModel.slab(size, mat))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _make_audio() -> void:
	for name in ["interview", "wake", "care", "obstacle", "better", "invitation"]:
		clips[name] = load("res://assets/audio/crown/opening/%s.wav" % name) as AudioStream
	for line in LINES:
		_speech_duration += (clips[line[0]] as AudioStream).get_length() + 0.55
	_voice_bus = "OpeningVoice_%d" % get_instance_id()
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, _voice_bus)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 16000
	AudioServer.add_bus_effect(index, _lowpass)
	audio = AudioStreamPlayer.new()
	audio.bus = _voice_bus
	audio.volume_db = -4
	add_child(audio)
	stress_audio = AudioStreamPlayer.new()
	stress_audio.volume_db = -15
	stress_audio.stream = _stress_stream()
	add_child(stress_audio)

func _stress_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 22050
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var samples := PackedByteArray()
	samples.resize(22050 * 9 * 2)
	for index in 22050 * 9:
		var t := float(index) / 22050
		var beat := fmod(t, 0.83)
		var pulse := exp(-beat * 23) + 0.45 * exp(-absf(beat - 0.16) * 36)
		var heart := sin(TAU * 53 * t) * pulse * 0.55
		var tinnitus := sin(TAU * 1750 * t) * 0.045 * minf(t, 1.0)
		var envelope := clampf((9 - t) / 2, 0, 1)
		samples.encode_s16(index * 2, int((heart + tinnitus) * envelope * 25000))
	stream.data = samples
	return stream

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask = ShaderMaterial.new()
	mask.shader = BLINK_SHADER
	overlay.material = mask
	layer.add_child(overlay)

	subtitle = EditorialStyle.make_label("", 26, EditorialStyle.PAPER, 600, false, 1)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_top = -140
	subtitle.offset_bottom = -52
	subtitle.offset_left = 140
	subtitle.offset_right = -140
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_shadow_color", Color(0.04, 0.05, 0.07, 0.92))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(subtitle)

	skip_button = Button.new()
	skip_button.text = "跳过演出  ·  SKIP"
	skip_button.custom_minimum_size = Vector2(200, 44)
	skip_button.position = Vector2(28, 28)
	EditorialStyle.style_button(skip_button, false, false, 16)
	skip_button.pressed.connect(skip)
	layer.add_child(skip_button)

	motion_button = CheckButton.new()
	motion_button.text = "减少镜头移动 / 无模糊"
	motion_button.position = Vector2(28, 82)
	motion_button.add_theme_font_override("font", EditorialStyle.font_sans(600))
	motion_button.add_theme_font_size_override("font_size", 16)
	motion_button.add_theme_color_override("font_color", EditorialStyle.INK)
	motion_button.add_theme_color_override("font_hover_color", EditorialStyle.INK)
	motion_button.add_theme_color_override("font_pressed_color", EditorialStyle.INK)
	motion_button.add_theme_stylebox_override("normal",
		EditorialStyle.plaque(Color(EditorialStyle.PAPER, 0.92), EditorialStyle.INK, 2, Vector2(3, 3), Color(EditorialStyle.INK, 0.4), 12, 6))
	motion_button.add_theme_stylebox_override("hover",
		EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(3, 3), Color(EditorialStyle.GOLD, 0.7), 12, 6))
	motion_button.add_theme_stylebox_override("pressed",
		EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(3, 3), Color(EditorialStyle.INK, 0.4), 12, 6))
	motion_button.toggled.connect(func(value: bool): reduced_motion = value)
	layer.add_child(motion_button)

	title_panel = PanelContainer.new()
	title_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_panel.offset_left = -310
	title_panel.offset_top = -156
	title_panel.offset_right = 310
	title_panel.offset_bottom = 156
	var title_style := EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(8, 8), Color(EditorialStyle.GOLD, 0.85), 0, 0)
	title_panel.add_theme_stylebox_override("panel", title_style)

	var title_shell := VBoxContainer.new()
	title_shell.add_theme_constant_override("separation", 0)
	title_panel.add_child(title_shell)

	var crown_bar := ColorRect.new()
	crown_bar.color = EditorialStyle.GOLD
	crown_bar.custom_minimum_size.y = 7
	crown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_shell.add_child(crown_bar)

	var title_pad := MarginContainer.new()
	title_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		title_pad.add_theme_constant_override("margin_" + side, 42)
	for side in ["top", "bottom"]:
		title_pad.add_theme_constant_override("margin_" + side, 30)
	title_shell.add_child(title_pad)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	title_pad.add_child(column)

	var eye_wrap := CenterContainer.new()
	eye_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(eye_wrap)
	eye_wrap.add_child(EditorialStyle.make_eyebrow("THRESHOLD  //  心智之门", 13))

	var title := EditorialStyle.make_label("MIND FREAK", 40, EditorialStyle.INK, 800, true, 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var tagline := EditorialStyle.make_label("在停摆的那一刻，醒来。", 20, EditorialStyle.SLATE, 600, false, 2)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)

	var begin := Button.new()
	begin.text = "开始挑战  →"
	begin.custom_minimum_size = Vector2(280, 56)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	EditorialStyle.style_button(begin, true, true, 22)
	begin.pressed.connect(start)
	column.add_child(begin)
	layer.add_child(title_panel)
	skip_button.hide()

func start() -> void:
	if phase != Phase.TITLE:
		return
	title_panel.hide()
	skip_button.show()
	_enter(Phase.FALL)

func skip() -> void:
	if phase in [Phase.PLAYABLE, Phase.COMPLETE]:
		return
	title_panel.hide()
	audio.stop()
	stress_audio.stop()
	_enter(Phase.CROWNING)
	phase_time = duration(Phase.CROWNING)
	_apply_frame()
	_release_control()

func duration(value: int) -> float:
	match value:
		Phase.FALL: return maxf(7.0, (clips["interview"] as AudioStream).get_length())
		Phase.BLINK: return 4.0
		Phase.BODY: return 5.0
		Phase.ENCOUNTER: return _speech_duration
		Phase.CROWNING: return 6.0
	return INF

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if get_tree().paused or phase in [Phase.TITLE, Phase.COMPLETE]:
		return
	if phase == Phase.PLAYABLE:
		crown.global_transform = CrownModel.worn_transform(player._head)
		if player.position.z < -13.0:
			phase = Phase.COMPLETE
			entry_count += 1
			combat_entry_requested.emit()
		return
	phase_time += delta
	_apply_frame()
	if phase_time >= duration(phase):
		if phase == Phase.CROWNING:
			_release_control()
		else:
			_enter(phase + 1)

func _enter(value: int) -> void:
	phase = value
	phase_time = 0.0
	phase_changed.emit(phase)
	if phase == Phase.FALL:
		audio.stream = clips["interview"]
		audio.play()
		spoken.append("interview")
		stress_audio.play()
		subtitle.text = "请用一分钟解释，为什么我们应该选你？"
	elif phase == Phase.BLINK:
		audio.stop()
		stress_audio.stop()
		subtitle.text = ""
	elif phase == Phase.BODY:
		subtitle.text = ""
	elif phase == Phase.ENCOUNTER:
		if not is_instance_valid(crown_voice_dsp):
			crown_voice_dsp = CrownVoiceDSP.new()
			crown_voice_dsp.setup(audio,0.5)
			add_child(crown_voice_dsp)
		_lowpass.cutoff_hz = 16000
		audio.pitch_scale = 1.0
		audio.volume_db = -4
		crown.show()
	elif phase == Phase.CROWNING:
		audio.stop()
		if is_instance_valid(crown_voice_dsp): crown_voice_dsp.flush_tail()
		subtitle.text = ""
	_apply_frame()

func _apply_frame() -> void:
	var t := phase_time
	var openness := 1.0
	var defocus := 0.0
	var whiteout := 0.0
	var flash := 0.0
	match phase:
		Phase.FALL:
			openness = 0.0
			var sink := smoothstep(1.5, duration(phase), t)
			_lowpass.cutoff_hz = lerpf(16000, 420, sink)
			audio.pitch_scale = lerpf(1.0, 0.78, sink)
			audio.volume_db = lerpf(-4, -24, sink)
			subtitle.modulate.a = 1.0 - smoothstep(2.0, 5.0, t)
		Phase.BLINK:
			openness = smoothstep(0.35, 1.25, t) * (1.0 - smoothstep(1.3, 1.6, t)) + smoothstep(2.0, 3.4, t)
			blink_count = (1 if t > 0.35 else 0) + (1 if t > 2.0 else 0)
			defocus = (1.0 - smoothstep(2.6, 4.0, t)) * 4.0
			whiteout = (1.0 - smoothstep(2.8, 4.0, t)) * 0.75
		Phase.BODY:
			player._pitch = lerpf(0, deg_to_rad(-58 if reduced_motion else -72), smoothstep(0, 2.0, t))
			player._apply_look()
		Phase.ENCOUNTER:
			player._pitch = lerpf(deg_to_rad(-58 if reduced_motion else -72), 0, smoothstep(0, 1.8, t))
			player._apply_look()
			crown.scale = Vector3.ONE
			crown.position = Vector3(0, 1.75 + (0.0 if reduced_motion else sin(t * 1.3) * 0.035), 1.35)
			var end := 0.0
			for index in LINES.size():
				end += (clips[LINES[index][0]] as AudioStream).get_length() + 0.55
				if t < end:
					if _line_index != index:
						_line_index = index
						audio.stream = clips[LINES[index][0]]
						audio.play()
						spoken.append(LINES[index][0])
						subtitle.text = LINES[index][1]
					break
			subtitle.modulate.a = 1.0
		Phase.CROWNING:
			crown.show()
			var p := smoothstep(0, 3.7, t)
			crown.global_position = Vector3(0,1.75,1.35).lerp(CrownModel.worn_transform(player._head).origin,p) + Vector3.UP * sin(p * PI) * 0.55
			if p > 0.92 and not crown.worn:
				crown.set_worn(true)
			crown.scale = Vector3.ONE
			camera.position.y = 0.0 if reduced_motion else -sin(clampf((t - 3.4) / 0.65, 0, 1) * PI) * 0.055
			flash = sin(clampf((t - 3.5) / 0.8, 0, 1) * PI) * 0.35
			var assembly := smoothstep(3.8, 5.5, t)
			player.weapon.visible = assembly > 0
			player.weapon._view.scale = Vector3.ONE * maxf(0.01, assembly)
			player.weapon._view.set_reassembly_progress(lerpf(0.45, 1.0, assembly))
			_open_doors(smoothstep(4.0, 6.0, t))
	mask.set_shader_parameter("openness", openness)
	mask.set_shader_parameter("defocus", 0.0 if reduced_motion else defocus)
	mask.set_shader_parameter("whiteout", whiteout)
	mask.set_shader_parameter("crown_flash", flash)

func _open_doors(amount: float) -> void:
	for index in doors.size():
		doors[index].position.x = (-1.0 if index == 0 else 1.0) * lerpf(1.65, 5.3, amount)

func _release_control() -> void:
	phase = Phase.PLAYABLE
	control_released = true
	phase_changed.emit(phase)
	mask.set_shader_parameter("openness", 1.0)
	mask.set_shader_parameter("defocus", 0.0)
	mask.set_shader_parameter("whiteout", 0.0)
	mask.set_shader_parameter("crown_flash", 0.0)
	camera.position = Vector3.ZERO
	player._pitch = 0.0
	player._apply_look()
	player.weapon.show()
	player.melee.show()
	player.weapon._view.scale = Vector3.ONE
	player.weapon._view.set_reassembly_progress(1.0)
	crown.set_worn(true)
	crown.global_transform = CrownModel.worn_transform(player._head)
	crown.reparent(player, true)
	_open_doors(1.0)
	skip_button.hide()
	motion_button.hide()
	subtitle.text = "WASD 移动 · 向前穿过心智之门"
	subtitle.modulate.a = 1.0
	_set_control(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _set_control(enabled: bool) -> void:
	player.set_process(enabled)
	player.set_physics_process(enabled)
	player.set_process_unhandled_input(enabled)
	for component in [player.weapon, player.melee, player.dash, player.shield, player.combat_traits]:
		component.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	var voice := player.get_node_or_null("CrownVoiceSystem")
	if voice != null:
		voice.process_mode = Node.PROCESS_MODE_DISABLED
		if voice.has_method("set_cinematic_hidden"):
			voice.call("set_cinematic_hidden", true)
		elif voice is Node3D:
			voice.hide()

func _exit_tree() -> void:
	for source in [audio, stress_audio]:
		if is_instance_valid(source):
			source.stop()
			source.stream = null
	var index := AudioServer.get_bus_index(_voice_bus)
	if index > 0:
		AudioServer.remove_bus(index)
