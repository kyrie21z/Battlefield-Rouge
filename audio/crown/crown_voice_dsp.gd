class_name CrownVoiceDSP
extends Node
## Supports both worn 2D voice and the independent 3D cinematic Crown source.
const PROFILE := preload("res://audio/crown/crown_audio_filter.tres")
var voice: Node
var bus_name: StringName
var original_bus: StringName
var plate: AudioEffectReverb
var harmonics: AudioEffectDistortion
var presence: AudioEffectHighShelfFilter
var _strength := 0.5

func setup(source: Node, emission_strength := 0.5) -> void:
	assert(source is AudioStreamPlayer or source is AudioStreamPlayer3D)
	voice = source
	_strength = emission_strength

func _ready() -> void:
	original_bus = voice.bus
	bus_name = StringName("CrownRadio_%d" % get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, original_bus if AudioServer.get_bus_index(original_bus) >= 0 else &"Master")
	# Radio band first, then a little saturation and bright metallic plate tail.
	for effect in [PROFILE.high_pass, PROFILE.low_pass, PROFILE.harmonics, PROFILE.presence, PROFILE.plate]:
		AudioServer.add_bus_effect(index, effect.duplicate())
	harmonics = AudioServer.get_bus_effect(index, 2) as AudioEffectDistortion
	presence = AudioServer.get_bus_effect(index, 3) as AudioEffectHighShelfFilter
	plate = AudioServer.get_bus_effect(index, 4) as AudioEffectReverb
	voice.bus = bus_name
	set_radiance(0, _strength)

func set_radiance(_level: int, strength: float) -> void:
	_strength = strength
	if plate == null: return
	var amount := clampf((strength - 0.5) / (16.5888 - 0.5), 0.0, 1.0)
	plate.wet = lerpf(0.12, 0.43, amount)
	plate.room_size = lerpf(0.58, 0.78, amount)
	plate.damping = lerpf(0.25, 0.08, amount)
	harmonics.drive = lerpf(0.04, 0.22, amount)
	presence.gain = lerpf(1.0, 2.2, amount)

## Clear effect delay lines when a line is cancelled/replaced. This also keeps
## hidden/dead/paused Crown reverberation from bleeding over the next scene.
func flush_tail() -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0 or plate == null: return
	AudioServer.remove_bus_effect(index, 4)
	AudioServer.add_bus_effect(index, plate, 4)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_DISABLED:
		flush_tail()

func _exit_tree() -> void:
	if is_instance_valid(voice) and voice.bus == bus_name:
		voice.bus = original_bus if AudioServer.get_bus_index(original_bus) >= 0 else &"Master"
	var index := AudioServer.get_bus_index(bus_name)
	if index > 0: AudioServer.remove_bus(index)
