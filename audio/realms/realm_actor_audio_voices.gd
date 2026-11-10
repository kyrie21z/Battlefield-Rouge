class_name RealmActorAudioVoices
extends Node
## Fixed pool for sustained actor sounds; the director supplies real state each frame.
const LIMIT := 8
var voices: Array[AudioStreamPlayer3D] = []
var bindings: Dictionary = {}
var _used: Array[int] = []

func _ready() -> void:
	for i in LIMIT:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "ActorVoice%d" % i
		voice.unit_size = 5.0
		voice.max_distance = 40.0
		add_child(voice)
		voices.append(voice)

func begin_frame() -> void:
	_used.clear()

func sync_actor(actor: Node3D, stream: AudioStreamWAV, pitch: float, volume: float) -> AudioStreamPlayer3D:
	var id := actor.get_instance_id()
	var index := int(bindings.get(id, -1))
	if index < 0:
		for i in voices.size():
			if not bindings.values().has(i):
				index = i
				bindings[id] = i
				break
	if index < 0:
		return null
	_used.append(id)
	var voice := voices[index]
	voice.global_position = actor.global_position + Vector3.UP
	voice.pitch_scale = pitch
	voice.volume_db = volume
	if voice.stream != stream or not voice.playing:
		voice.stop()
		voice.stream = stream
		voice.play()
	return voice

func end_frame() -> void:
	for id in bindings.keys():
		if not _used.has(id):
			voices[bindings[id]].stop()
			bindings.erase(id)

func voice_for(actor: Node) -> AudioStreamPlayer3D:
	var id := actor.get_instance_id()
	return voices[bindings[id]] if bindings.has(id) else null

func stop_all() -> void:
	for voice in voices:
		voice.stop()
	bindings.clear()
