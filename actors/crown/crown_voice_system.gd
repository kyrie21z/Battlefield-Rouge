class_name CrownVoiceSystem
extends Node3D
## Owned by Player; history and depth are injected by RunDirector/RealmStage.
signal line_started(key: String, text: String)
signal line_finished(key: String)
signal radiance_changed(level: int, strength: float)
const DATABASE: CrownDialogueDatabase = preload("res://actors/crown/crown_dialogue_database.tres")
const EMISSION := preload("res://actors/crown/crown_emission.gdshader")
const GLARE := preload("res://actors/crown/crown_glare.gdshader")
var player: Player
var model: CrownModel
var audio: AudioStreamPlayer
var subtitle: Label
var layer: CanvasLayer
var glow: OmniLight3D
var edge_meshes: Array[MeshInstance3D] = []
var material: ShaderMaterial
var glare: ShaderMaterial
var current_key := ""
var played_keys: Array[String] = []
var fracture_level := 0
var strength := 0.5
var run_count := 1
var last_depth := 0
var death_cause := ""
var floor_depth := 0
var reduced_motion := false
var elapsed := 0.0
var _pending_history := false
var _dead := false
var _announce_entry := true

func _ready() -> void:
	player = get_parent() as Player
	model = CrownModel.new()
	model.set_worn(true)
	add_child(model)
	material = ShaderMaterial.new()
	material.shader = EMISSION
	for child in model.find_children("*", "MeshInstance3D", true, false):
		if child.material_override == model.gold:
			child.material_override = material
	var camera := player.get_node("Head/Camera3D/ViewCamera") as Camera3D
	for sign_x in [-1.0, 1.0]:
		var corner := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.09, 0.19, 0.055)
		corner.mesh = prism
		corner.material_override = material
		corner.position = Vector3(sign_x * 0.62, 0.34, -0.55)
		corner.rotation.z = sign_x * -0.28
		corner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		camera.add_child(corner)
		edge_meshes.append(corner)
	glow = OmniLight3D.new()
	glow.omni_range = 2.2
	glow.light_color = Color(1.0, 0.87, 0.55)
	add_child(glow)
	audio = AudioStreamPlayer.new()
	audio.volume_db = -5
	audio.finished.connect(_on_audio_finished)
	add_child(audio)
	layer = CanvasLayer.new()
	add_child(layer)
	var light_overlay := ColorRect.new()
	light_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glare = ShaderMaterial.new()
	glare.shader = GLARE
	light_overlay.material = glare
	layer.add_child(light_overlay)
	subtitle = Label.new()
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_top = -135
	subtitle.offset_bottom = -65
	subtitle.offset_left = 130
	subtitle.offset_right = -130
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 27)
	subtitle.add_theme_color_override("font_color", Color(1, 0.94, 0.77))
	subtitle.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(subtitle)
	(player.get_node("Health") as Health).died.connect(_on_death)
	Events.sin_defeated.connect(set_fracture_level)
	set_fracture_level(fracture_level)

func configure_history(count: int, depth: int, cause: String, announce := true) -> void:
	_announce_entry = announce
	run_count = maxi(1, count)
	last_depth = maxi(0, depth)
	death_cause = cause
	stop_voice()
	_pending_history = announce
	_play_pending_history.call_deferred()

func _play_pending_history() -> void:
	if not _pending_history or _dead:
		return
	_pending_history = false
	play_line(DATABASE.history_key(run_count, last_depth, death_cause))

func enter_floor(depth: int) -> void:
	if floor_depth == depth or _dead or not _announce_entry:
		return
	floor_depth = depth
	if depth <= 1:
		return # Initial entry uses the injected historical response.
	_pending_history = false
	play_line("floor%d" % clampi(depth, 2, 5))

func play_line(key: String) -> bool:
	if _dead or not DATABASE.lines.has(key):
		return false
	# A single player makes replacement explicit; death/re-entry cannot overlap.
	stop_voice()
	var entry := DATABASE.line_for(key)
	current_key = key
	subtitle.text = "皇冠 · " + String(entry.text)
	audio.stream = entry.clip as AudioStream
	audio.play()
	played_keys.append(key)
	line_started.emit(key, entry.text)
	return true

func stop_voice() -> void:
	if is_instance_valid(audio):
		audio.stop()
	if is_instance_valid(subtitle):
		subtitle.text = ""
	current_key = ""

func _on_audio_finished() -> void:
	var finished := current_key
	current_key = ""
	subtitle.text = ""
	line_finished.emit(finished)

func set_fracture_level(count: int) -> void:
	fracture_level = clampi(count, 0, 4)
	strength = 0.5 * pow(2.4, fracture_level)
	if material != null:
		material.set_shader_parameter("emission_strength", strength)
	if glare != null:
		glare.set_shader_parameter("intensity", strength / 16.5888)
		glare.set_shader_parameter("fracture_level", fracture_level)
	if is_instance_valid(glow):
		glow.light_energy = minf(strength * 0.13, 2.1)
	radiance_changed.emit(fracture_level, strength)

func set_cinematic_hidden(hidden: bool) -> void:
	visible = not hidden
	layer.visible = not hidden
	for edge in edge_meshes:
		edge.visible = not hidden
	if hidden:
		_pending_history = false
		stop_voice()

func _process(delta: float) -> void:
	if _dead:
		return
	elapsed += delta
	var head := player.get_node("Head") as Node3D
	model.global_transform = head.global_transform * Transform3D(Basis.IDENTITY,CrownModel.WEAR_OFFSET)
	glow.position = model.position
	glare.set_shader_parameter("visual_time", elapsed)
	glare.set_shader_parameter("reduced_motion", reduced_motion)

func _on_death(_source: Node) -> void:
	_dead = true
	_pending_history = false
	stop_voice()
	layer.hide()
	for edge in edge_meshes:
		edge.hide()

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
	for edge in edge_meshes:
		if is_instance_valid(edge):
			edge.queue_free()
