class_name FearCriticalFeedback
extends Node3D
## Deterministic presentation: readable purple damage, sharp crystal partials.

var _elapsed := 0.0
var _label: Label3D
static var _sound: AudioStreamWAV
static var _overlay_2d_count := 0
var play_sound := true


static func register_2d_overlay() -> void:
	_overlay_2d_count += 1


static func unregister_2d_overlay() -> void:
	_overlay_2d_count = maxi(_overlay_2d_count - 1, 0)


static func spawn(parent: Node, point: Vector3, damage: float, with_sound := true) -> FearCriticalFeedback:
	var effect := FearCriticalFeedback.new()
	effect.play_sound = with_sound
	parent.add_child(effect)
	effect.global_position = point + Vector3.UP * 0.2
	effect._label.text = "%d!" % roundi(damage)
	return effect


func _ready() -> void:
	_label = Label3D.new()
	_label.font_size = 72
	_label.pixel_size = 0.008
	_label.modulate = PanicFlawStatus.COLOR.lightened(0.25)
	_label.outline_modulate = Color(0.05, 0.02, 0.10)
	_label.outline_size = 14
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = false
	_label.visible = _overlay_2d_count <= 0
	add_child(_label)
	if not play_sound:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = _crystal_sound()
	player.volume_db = -8.0
	player.max_distance = 40.0
	add_child(player)
	player.play()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_elapsed += delta
	position.y += delta * 0.7
	_label.modulate.a = clampf((0.75 - _elapsed) / 0.25, 0.0, 1.0)
	if _elapsed >= 0.75:
		queue_free()


static func _crystal_sound() -> AudioStreamWAV:
	if _sound != null:
		return _sound
	var bytes := PackedByteArray()
	var rate := 22050
	var count := int(rate * 0.14)
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var wave := (sin(TAU * 1940.0 * t) + 0.45 * sin(TAU * 3163.0 * t) \
			+ 0.25 * sin(TAU * 4871.0 * t)) * exp(-t * 43.0) * minf(t * 4000.0, 1.0)
		bytes.encode_s16(i * 2, int(wave * 11000.0))
	_sound = AudioStreamWAV.new()
	_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_sound.mix_rate = rate
	_sound.data = bytes
	return _sound
