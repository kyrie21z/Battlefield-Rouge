class_name SorrowBoonAudio
extends Node
## Installed in EVERY realm by the room audio composition root, including revisits.
const MAX_VOICES := 8
var player: Player
var realm := -1
var voices: Array[AudioStreamPlayer3D] = []
var cue_counts: Dictionary = {}
var stopped := false

func setup(value: Player, realm_index := -1) -> void:
	player = value
	realm = realm_index

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for i in MAX_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 5
		voice.max_distance = 40
		add_child(voice)
		voices.append(voice)
	player.fragments.set_brittle_audio(SorrowSoundBank.get_sound(&"glass"))
	player.boons.event_dispatched.connect(_on_event)
	player.health.died.connect(func(_source): stop_all())

func _on_event(event: StringName, context: Dictionary) -> void:
	var kind: StringName
	match event:
		&"sorrow_tear_collected": kind = &"tear_return"
		&"sorrow_tear_broken": kind = &"tear_spray"
		&"clock_struck":
			if realm != 3 or player.health.unbuffered: return
			kind = &"water_bell"
		_: return
	play_cue(kind, context.get("position", player.global_position))

func play_cue(kind: StringName, point: Vector3) -> void:
	if stopped or get_tree().paused or player.health.is_dead(): return
	cue_counts[kind] = int(cue_counts.get(kind, 0)) + 1
	var voice := voices[0]
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	voice.stop()
	voice.stream = SorrowSoundBank.get_sound(kind)
	voice.global_position = point
	voice.volume_db = -12 if kind == &"water_bell" else -9
	voice.play()

func stop_all() -> void:
	stopped = true
	for voice in voices: voice.stop()

func _exit_tree() -> void:
	for voice in voices:
		if is_instance_valid(voice): voice.stop()
