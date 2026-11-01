extends Node3D
## Pride opening, for Sloth issue #45. GameStart owns the real level handoff.
signal combat_entry_requested
const Flow = preload("res://ui/pride_opening/opening_flow.gd")
const Avatar = preload("res://ui/pride_opening/crown_avatar.gd")
const DATA = preload("res://ui/pride_opening/dialogue.json")
const GRADIENT = preload("res://ui/pride_opening/gray_gradient.gdshader")
const INK = Color("212a2d")
var flow := Flow.new()
var camera: Camera3D
var ui: Control
var panels: Dictionary = {}
var title_button: Button
var pause_button: Button
var skip_button: Button
var ready_button: Button
var objective: Label
var subtitle: Label
var next_button: Button
var shot_label: Label
var progress: ColorRect
var avatar: Control
var crown: Sprite3D
var crown_return: float = 1.0
var handoff_elapsed: float = 0.0
var replay_button: Button
var previous_state: int = -1
var previous_serial: int = -1
var reticle: Label
var footer: Label
var muted: bool = false
var reduced_motion: bool = false
var audio: AudioStreamPlayer
var yaw: float = 0.0
var pitch: float = 0.0
var last_shot: int = -1
var seen: bool = false
var proof: bool = false
var proof_stage: int = 0
var proof_wait: float = 0.0
var proof_dir: String = ""

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--proof="):
			proof = true
			proof_dir = argument.trim_prefix("--proof=")
	var config := ConfigFile.new()
	if not proof and config.load("user://opening.cfg") == OK:
		seen = config.get_value("opening", "confirmed", false)
	flow.step_count = DATA.data.shots.size()
	_make_world()
	_make_ui()
	_sync_ui_layout()
	get_viewport().size_changed.connect(_sync_ui_layout)
	flow.changed.connect(_on_changed)
	flow.entry_requested.connect(_on_entry_requested)
	_on_changed()

func _on_entry_requested() -> void:
	combat_entry_requested.emit()

func _exit_tree() -> void:
	# The standalone preview can be discarded when a real level is loaded.
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
	if is_instance_valid(crown): crown.texture = null
	if flow.changed.is_connected(_on_changed):
		flow.changed.disconnect(_on_changed)
	if flow.entry_requested.is_connected(_on_entry_requested):
		flow.entry_requested.disconnect(_on_entry_requested)

func _material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRADIENT
	material.set_shader_parameter("base_color", color)
	return material

func _box(pos: Vector3, dimensions: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = pos
	(parent if parent != null else self).add_child(node)
	return node

func _rod(a: Vector3, b: Vector3, thickness: float = 0.04) -> void:
	var rod := _box((a + b) / 2.0, Vector3(thickness, thickness, a.distance_to(b)), Color("555f64"))
	if a.distance_to(b) > 0.01:
		rod.look_at(b, Vector3.UP if absf((b-a).normalized().y) < 0.99 else Vector3.RIGHT)

func _make_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("c8ced0")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d2d9de")
	settings.ambient_light_energy = 0.45
	settings.fog_enabled = true
	settings.fog_light_color = Color("bac6cd")
	settings.fog_density = 0.0035
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("fff3de")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	# A continuous, readable floor, with tall negative spaces and a fixed landmark.
	_box(Vector3(0, -0.4, -19), Vector3(11, 0.8, 60), Color("7b8890"))
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 5.3, 0.25, -18), Vector3(0.22, 0.5, 58), Color("3a454c"))
		for i in range(6):
			var z := 7.0 - i * 8.0
			var height := 8.0 + float(i % 3) * 2.0
			_box(Vector3(side * 8.4, height / 2, z), Vector3(1.5, height, 1.8), Color("c4cdcf"))
			_box(Vector3(side * 8.5, 0.05, z - 2), Vector3(5, 0.1, 5), Color("77838a"))
			_box(Vector3(side * 11.0, 11 + i % 3, z - 3), Vector3(3, 2, 3), Color("d8dcda"))
			_rod(Vector3(side * 11, 0, z - 3), Vector3(side * 11, 10, z - 3))
		for i in range(6):
			_box(Vector3(side * (13.0 + i * 0.65), 1 + i * 0.65, -21 - i * 1.9), Vector3(5, 0.45, 1.8), Color("e5e5de"))
		# Deliberately offset slabs freeze mid-fall; they do not animate in the intro.
		for i in range(4):
			var slab := _box(Vector3(side * (15 + i * 2), 7 + i * 2.4, -42 - i * 5), Vector3(4, 1.3, 4), Color("aeb8bb"))
			slab.rotation_degrees = Vector3(i * 11, i * 8, side * 12)
	for i in range(13):
		_box(Vector3(0, 0.015, 5 - i * 3.6), Vector3(0.16, 0.035, 1.8), Color("d9dedc"))
	# Layered plinths and incomplete frames break up the corridor's repeated rhythm.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 15, 0.7, -32), Vector3(10, 1.4, 13), Color("65747d"))
		_box(Vector3(side * 15, 2.0, -33), Vector3(7, 1.2, 10), Color("9ca9b0"))
		_box(Vector3(side * 20, 11, -46), Vector3(2, 18, 3), Color("dce1df"))
		_box(Vector3(side * 16, 20, -46), Vector3(10, 1, 3), Color("c5cecf"))
		_box(Vector3(side * 6.5, 1.1, -15), Vector3(1.1, 2.2, 3.5), Color("b8c4c9"))
	_box(Vector3(0, 8.5, 0), Vector3(17, 1.4, 2), Color("e3e4dd"))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 12.3
	torus.outer_radius = 13.2
	torus.rings = 64
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = _material(Color("58656c"))
	ring.position = Vector3(0, 18, -63)
	ring.rotation_degrees.x = 90
	add_child(ring)
	_rod(Vector3(0, 29, -63), Vector3(4.8, 11, -63), 0.18)
	var pendulum := _box(Vector3(4.8, 10.5, -63), Vector3(3, 3, 1), Color("d7dcd9"))
	pendulum.rotation_degrees.z = 45
	# The gate is a direction marker, not a restorative amber light source.
	_box(Vector3(-3.6, 3, -38), Vector3(1.0, 6, 1.5), Color("505e64"))
	_box(Vector3(3.6, 3, -38), Vector3(1.0, 6, 1.5), Color("505e64"))
	_box(Vector3(0, 6, -38), Vector3(8.2, 0.7, 1.5), Color("505e64"))
	_box(Vector3(0, 0.05, -39), Vector3(6.2, 0.1, 5), Color("dce3df"))
	var sign := Label3D.new()
	sign.text = "01  /  入口"
	sign.font_size = 72
	sign.pixel_size = 0.008
	sign.position = Vector3(0, 5.25, -37.2)
	sign.modulate = Color("e6eee9")
	add_child(sign)
	camera = Camera3D.new()
	camera.fov = 72
	camera.position = Vector3(0, 1.7, 7)
	add_child(camera)
	camera.current = true
	var portrait_view := SubViewport.new()
	portrait_view.size = Vector2i(384, 300)
	portrait_view.transparent_bg = true
	portrait_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(portrait_view)
	avatar = Avatar.new()
	avatar.size = Vector2(384, 300)
	portrait_view.add_child(avatar)
	crown = Sprite3D.new()
	crown.texture = portrait_view.get_texture()
	crown.pixel_size = 0.0065
	crown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crown.position = Vector3(0, 1.8, -2.0)
	camera.add_child(crown)
	audio = AudioStreamPlayer.new()
	audio.volume_db = -20
	add_child(audio)

func _label(text: String, rect: Rect2, font_size: int = 20, parent: Control = null) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent != null else ui).add_child(node)
	return node

func _button(text: String, rect: Rect2, action: Callable, parent: Control = null) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.pressed.connect(action)
	(parent if parent != null else ui).add_child(node)
	return node

func _panel(key: String, rect: Rect2) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.14, 0.96)
	style.border_color = Color("7b8a8b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	node.add_theme_stylebox_override("panel", style)
	ui.add_child(node)
	panels[key] = node
	return node

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.size = Vector2(1280, 720)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 20
	ui.theme = theme
	_label("M I N D  F R E A K     /     FLOOR  I", Rect2(40, 24, 600, 32), 17).add_theme_color_override("font_color", INK)
	shot_label = _label("THE THRESHOLD / 静滞之门", Rect2(40, 60, 700, 30), 15)
	shot_label.add_theme_color_override("font_color", INK)
	pause_button = _button("暂停 [Esc]", Rect2(994, 25, 120, 38), flow.toggle_pause)
	skip_button = _button("跳过演出", Rect2(1124, 25, 116, 38), flow.skip)
	objective = _label("", Rect2(40, 108, 660, 72), 22)
	objective.add_theme_color_override("font_color", INK)
	var title := _panel("title", Rect2(60, 224, 510, 326))
	_label("静滞之门", Rect2(30, 24, 450, 58), 42, title)
	_label("一切都停在了半途。\n只有你，还能向前。", Rect2(30, 100, 450, 80), 23, title)
	title_button = _button("重看开场" if seen else "观看开场", Rect2(30, 212, 212, 55), flow.start, title)
	_button("直接查看目标", Rect2(256, 212, 220, 55), flow.skip, title)
	_label("5 句引导 · 点击推进 · 随时跳过", Rect2(30, 281, 450, 28), 15, title)
	var dialogue := _panel("dialogue", Rect2(240, 520, 1000, 128))
	_label("P R I D E    /    头顶的皇冠", Rect2(24, 13, 920, 28), 16, dialogue)
	subtitle = _label("", Rect2(24, 48, 700, 66), 25, dialogue)
	next_button = _button("下一句 [Enter]", Rect2(755, 47, 220, 57), flow.advance, dialogue)
	var decision := _panel("decision", Rect2(732, 266, 508, 374))
	_label("准备好前进了吗？", Rect2(26, 22, 460, 45), 29, decision)
	_label("目标：消灭 Sloth\n穿过眼前的入口，进入停滞广场。", Rect2(26, 82, 454, 85), 23, decision)
	_button("确定，开始行动", Rect2(26, 184, 454, 57), flow.confirm, decision)
	_button("我再看看", Rect2(26, 253, 454, 49), flow.observe, decision)
	_label("选择只决定出发时间，不改变属性或难度。", Rect2(26, 322, 454, 40), 16, decision)
	var pause := _panel("pause", Rect2(430, 174, 420, 386))
	_label("已暂停", Rect2(30, 22, 360, 48), 32, pause)
	_button("继续 [Esc]", Rect2(30, 84, 360, 47), flow.toggle_pause, pause)
	var mute := CheckButton.new()
	mute.text = "静音"
	mute.position = Vector2(30, 151)
	mute.size = Vector2(360, 46)
	mute.toggled.connect(func(value: bool):
		muted = value
		if muted: audio.stop())
	pause.add_child(mute)
	var reduced := CheckButton.new()
	reduced.text = "减少移动（镜头 / 皇冠）"
	reduced.position = Vector2(30, 212)
	reduced.size = Vector2(370, 48)
	reduced.toggled.connect(func(value: bool): reduced_motion = value)
	pause.add_child(reduced)
	_button("从头重播", Rect2(30, 294, 360, 48), flow.start, pause)
	replay_button = _button("重看开场", Rect2(1090, 608, 150, 49), flow.start)
	ready_button = _button("准备好了，查看选择 [E]", Rect2(940, 608, 300, 49), flow.decision)
	footer = _label("", Rect2(40, 669, 1200, 34), 17)
	footer.add_theme_color_override("font_color", INK)
	reticle = _label("·", Rect2(630, 343, 24, 30), 26)
	reticle.add_theme_color_override("font_color", INK)
	progress = ColorRect.new()
	progress.color = Color("b69a56")
	progress.position = Vector2(40, 709)
	progress.size = Vector2(0, 3)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(progress)

func _on_changed() -> void:
	var entering := previous_state != flow.state
	var restarting := previous_serial != flow.play_serial
	previous_state = flow.state
	previous_serial = flow.play_serial
	for key in panels:
		panels[key].hide()
	if flow.paused:
		panels.pause.show()
	else:
		match flow.state:
			Flow.State.TITLE: panels.title.show()
			Flow.State.CINEMATIC: panels.dialogue.show()
			Flow.State.DECISION: panels.decision.show()
	pause_button.visible = flow.state != Flow.State.TITLE
	replay_button.visible = flow.state == Flow.State.COMPLETE and not flow.paused
	skip_button.visible = flow.state == Flow.State.CINEMATIC and not flow.paused
	ready_button.visible = flow.state == Flow.State.OBSERVING and not flow.paused
	reticle.visible = flow.can_move()
	crown.visible = flow.state in [Flow.State.CINEMATIC, Flow.State.DECISION] or (flow.state == Flow.State.WALKING and crown_return < 1.0)
	avatar.motion_enabled = not flow.paused and not reduced_motion
	avatar.speaking = flow.state == Flow.State.CINEMATIC
	if flow.state == Flow.State.CINEMATIC:
		var step_changed := last_shot != flow.step_index or restarting
		last_shot = flow.step_index
		if step_changed: avatar.clock = 0.0
		if restarting:
			objective.text = ""
			camera.position = Vector3(0, 1.7, 7)
			camera.look_at(Vector3(0, 9, -63))
			yaw = 0.0
			pitch = 0.0
			crown.position = Vector3(0, 1.8, -2.0)
			crown.rotation.z = 0.0
			_chime(520)
		var current: Dictionary = DATA.data.shots[flow.step_index]
		subtitle.text = current.line
		avatar.pose = current.pose
		next_button.text = "准备出发 [Enter]" if flow.step_index == flow.step_count - 1 else "下一句 [Enter]"
		if flow.step_index >= 2:
			objective.text = "目标：消灭 Sloth · 穿过巨环下的入口"
	if flow.state == Flow.State.DECISION and entering:
		_reset_player_camera()
		shot_label.text = "THE THRESHOLD / 行动前确认"
		objective.text = "目标：" + DATA.data.objective + "\n" + DATA.data.direction
		avatar.pose = "waiting"
	if flow.state == Flow.State.WALKING and entering:
		handoff_elapsed = 0.0
		crown_return = 0.0
		crown.show()
		if not proof:
			var config := ConfigFile.new()
			config.set_value("opening", "confirmed", true)
			config.save("user://opening.cfg")
		_chime(660.0)
	if flow.state == Flow.State.COMPLETE and entering:
		crown_return = 1.0
		crown.hide()
		# Keep the doorway view until GameStart replaces this scene.
		yaw = 0
		pitch = 0
		camera.rotation = Vector3.ZERO
		shot_label.text = "即将进入战区"
		objective.text = "开场结束，正在进入战区……"
	if flow.paused or not flow.can_move():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if flow.paused:
		audio.stream_paused = true
	else:
		audio.stream_paused = false
	# Keep keyboard focus on a safe button after every modal change.
	if flow.paused:
		panels.pause.get_child(1).grab_focus()
	elif flow.state == Flow.State.TITLE:
		shot_label.text = "THE THRESHOLD / 静滞之门"
		title_button.grab_focus()
	elif flow.state == Flow.State.DECISION:
		panels.decision.get_child(2).grab_focus()
	elif flow.state == Flow.State.CINEMATIC:
		next_button.grab_focus()
	else:
		var focus := get_viewport().gui_get_focus_owner()
		if focus: focus.release_focus()

func _reset_player_camera() -> void:
	camera.position = Vector3(0, 1.7, -34.5)
	yaw = 0
	pitch = 0
	camera.rotation = Vector3.ZERO

func _process(delta: float) -> void:
	flow.tick(delta)
	if flow.state == Flow.State.CINEMATIC:
		var shot := flow.step_index
		var current: Dictionary = DATA.data.shots[shot]
		shot_label.text = "%s / %s   ·   %d / %d" % [current.id, current.title, shot + 1, flow.step_count]
		avatar.speaking = flow.step_elapsed < 1.5
		if not flow.paused:
			if reduced_motion:
				camera.position = Vector3(0, 1.7, 3)
				camera.look_at(Vector3(0, 10, -63))
				crown.position = Vector3(-1, 0.6, -3.5)
				crown.rotation.z = 0.0
			else:
				var targets: Array[Vector3] = [Vector3(0, 9, -63), Vector3(-7, 10, -43), Vector3(0, 15, -63), Vector3(0, 3, -38), Vector3(0, 6, -52)]
				var desired := Transform3D(Basis.IDENTITY, camera.position).looking_at(targets[shot])
				camera.transform = camera.transform.interpolate_with(desired, minf(delta * 3.5, 1.0))
				var p: Array = current.position
				var destination := Vector3(p[0], p[1] + sin(flow.step_elapsed * 2.5) * 0.055, p[2])
				crown.position = crown.position.lerp(destination, minf(delta * 4, 1.0))
				crown.rotation.z = sin(flow.step_elapsed * 2.0) * 0.04
		progress.size.x = 1200.0 * float(shot + 1) / flow.step_count
	elif flow.can_move():
		_move(delta)
		if flow.state == Flow.State.OBSERVING: shot_label.text = "THE THRESHOLD / 静滞之门"
	elif flow.state == Flow.State.TITLE:
		camera.position = Vector3(0, 1.7, 7)
		camera.look_at(Vector3(0, 12, -63))
	if flow.state == Flow.State.DECISION and not flow.paused:
		var waiting_position := Vector3(-1.1, 0.15, -3.5)
		crown.position = waiting_position if reduced_motion else crown.position.lerp(waiting_position, minf(delta * 5.0, 1.0))
	avatar.motion_enabled = not flow.paused and not reduced_motion
	progress.visible = flow.state == Flow.State.CINEMATIC
	footer.text = "WASD 移动 · 方向键 / 按住右键观察 · E 出发选择 · Esc 暂停" if flow.can_move() else "Esc 暂停 · Tab 选择 · Enter 确认"
	if flow.state in [Flow.State.TITLE, Flow.State.COMPLETE]: footer.text = "Tab 选择 · Enter 确认"
	if flow.state == Flow.State.WALKING:
		footer.text = "正在进入第一关……"
		if not flow.paused:
			handoff_elapsed = 0.35 if reduced_motion else handoff_elapsed + delta
			camera.position.z = lerpf(-34.5, -40.0, smoothstep(0.0, 0.35, handoff_elapsed))
			if handoff_elapsed >= 0.35:
				flow.enter()
				return # An entry listener may replace or free this scene.
		if not flow.paused and crown_return < 1.0:
			crown_return = minf(crown_return + delta * 1.5, 1.0)
			crown.position = crown.position.lerp(Vector3(0, 2, -1), minf(delta * 5, 1.0))
			crown.visible = crown_return < 1.0
	if flow.state == Flow.State.COMPLETE:
		footer.text = "正在进入战区……"
	if flow.state == Flow.State.CINEMATIC:
		footer.text = "点击画面 / 下一句，或按 Enter / 空格推进 · Esc 暂停 · 右上角可跳过整段"
	if proof: _proof_step(delta)

func _move(delta: float) -> void:
	var x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var z := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var direction := Vector3(x, 0, z).normalized().rotated(Vector3.UP, yaw)
	camera.position += direction * 4.5 * delta
	if flow.state == Flow.State.COMPLETE:
		camera.position.x = clampf(camera.position.x, -5.0, 5.0)
		camera.position.z = clampf(camera.position.z, -65.0, -43.0)
	else:
		camera.position.x = clampf(camera.position.x, -4.4, 4.4)
		camera.position.z = clampf(camera.position.z, -36.5, 8.0)
	yaw += (float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))) * delta * 1.1
	pitch += (float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))) * delta
	pitch = clampf(pitch, -0.6, 0.7)
	camera.rotation = Vector3(pitch, yaw, 0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.echo:
			if key in [KEY_ESCAPE, KEY_E, KEY_ENTER, KEY_SPACE]:
				get_viewport().set_input_as_handled()
			return
		if key == KEY_ESCAPE:
			flow.toggle_pause()
			get_viewport().set_input_as_handled()
		elif key == KEY_E and flow.state == Flow.State.OBSERVING and not flow.paused:
			flow.decision()
			get_viewport().set_input_as_handled()
		elif key in [KEY_ENTER, KEY_SPACE] and flow.state == Flow.State.CINEMATIC and not flow.paused:
			flow.advance()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not flow.paused and flow.state == Flow.State.CINEMATIC and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		flow.advance()
	if flow.can_move() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if flow.can_move() and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -0.6, 0.7)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(ui):
		if not flow.paused and flow.state != Flow.State.TITLE:
			flow.toggle_pause()

func _chime(hz: float) -> void:
	if muted: return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(6615 * 2)
	for i in range(6615):
		var t := i / 22050.0
		var envelope := sin(PI * i / 6615.0) * exp(-t * 12.0)
		samples.encode_s16(i * 2, int(sin(t * TAU * hz) * envelope * 9000))
	stream.data = samples
	audio.stream = stream
	audio.play()

func _proof_step(delta: float) -> void:
	proof_wait += delta
	if proof_wait < 0.8: return
	proof_wait = 0
	match proof_stage:
		0: flow.start()
		1:
			flow.advance()
			flow.advance()
		2:
			_capture("01-frozen-vista.jpg")
			flow.advance()
		3: _capture("02-pride-wave.jpg")
		4: flow.skip()
		5: _capture("03-confirm-choice.jpg")
		6:
			flow.observe()
			if not _proof_check(flow.can_move(), "Observe did not restore control"): return
			flow.decision()
			flow.confirm()
		7:
			if not _proof_check(flow.state == Flow.State.COMPLETE and flow.entry_count == 1, "First-room handoff failed"): return
			_capture("04-entry-handoff.jpg")
		8:
			print("NATIVE PROOF PASS: vista, choice, observe-return, confirm, entry; entry_count=", flow.entry_count)
			get_tree().quit()
	proof_stage += 1

func _capture(filename: String) -> void:
	if not _proof_check(DirAccess.make_dir_recursive_absolute(proof_dir) == OK, "Cannot create proof directory"): return
	var image := get_viewport().get_texture().get_image()
	var result := image.save_jpg(proof_dir.path_join(filename), 0.82)
	if not _proof_check(result == OK, "Cannot save " + filename): return
	print("Captured ", filename)

func _proof_check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		set_process(false)
		get_tree().quit(1)
	return condition


func _sync_ui_layout() -> void:
	# The game uses a 1920 x 1080 canvas; the animatic was authored at 1280 x 720.
	var area := get_viewport().get_visible_rect().size
	var factor := minf(area.x / 1280.0, area.y / 720.0)
	ui.scale = Vector2.ONE * factor
	ui.position = (area - Vector2(1280, 720) * factor) / 2.0
