class_name SlothFeedback
extends CanvasLayer
## UI belongs to this effect: a small stand-still clock plus desaturated time
## veil. The centre stays legible. No environment or camera settings are saved.
var time_strength := 0.0
var _veil: ColorRect
var _clock: Label
var _sound: AudioStreamPlayer


func _ready() -> void:
	layer = 11
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest; uniform float strength = 0.0; void fragment(){vec4 c=texture(screen_tex,SCREEN_UV); float gray=dot(c.rgb,vec3(0.299,0.587,0.114)); vec3 cool=vec3(gray*0.78,gray*0.90,gray*1.08); COLOR=vec4(mix(c.rgb,cool,strength),1.0);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	_veil.material = material
	add_child(_veil)
	_clock = Label.new()
	_clock.text = "◷  静定  −40%"
	_clock.add_theme_color_override("font_color", LatencyStatus.AMBER)
	_clock.add_theme_font_size_override("font_size", 18)
	_clock.position = Vector2(28, 170)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.visible = false
	add_child(_clock)
	_sound = AudioStreamPlayer.new()
	_sound.stream = _make_sound()
	_sound.volume_db = -14.0
	add_child(_sound)


func _process(_delta: float) -> void:
	_veil.visible = time_strength > 0.0
	(_veil.material as ShaderMaterial).set_shader_parameter("strength", time_strength)


func show_stillness(enabled: bool) -> void:
	if is_instance_valid(_clock):
		_clock.visible = enabled


func freeze_pulse() -> void:
	if is_instance_valid(_sound):
		_sound.play()


func _exit_tree() -> void:
	if is_instance_valid(_sound):
		_sound.stop()
		_sound.stream = null


static func _make_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(22050)
	for index in 11025:
		var t := float(index) / 22050.0
		var amplitude := exp(-t * 10.0) * (sin(t * TAU * 110.0) + 0.25 * sin(t * TAU * 783.99))
		samples.encode_s16(index * 2, int(clampf(amplitude * 10000.0, -32767.0, 32767.0)))
	stream.data = samples
	return stream
