class_name ClimaxAudio
extends Node
## Reads actual BodyReassembly phase/line signals; never advances the narrative.
const PANS := [-0.8, 0.65, -0.35, 0.85, 0.0]
const PITCHES := [0.88, 1.08, 0.94, 0.91, 1.0]
const NOTES := [293.6648, 440.0, 659.2551, 587.3295]
var sequence: Node
var player: Player
var voice: AudioStreamPlayer
var impact: AudioStreamPlayer
var flow: AudioStreamPlayer
var piano: Array[AudioStreamPlayer] = []
var vacuum: AudioVacuum
var panner: AudioEffectPanner
var bus_name: StringName
var played_lines: Array[int] = []
var cue_counts: Dictionary = {}
var stopped := false
var _cry_reverb: AudioEffectReverb
var _rebuilding := false
var _rebuild_time := 0.0
var _note_index := 0

func setup(value: Node, owner_player: Player) -> void:
	sequence = value
	player = owner_player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	bus_name = StringName("ClimaxCries_%d" % get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	panner = AudioEffectPanner.new()
	AudioServer.add_bus_effect(index, panner)
	var room := AudioEffectReverb.new()
	room.wet = 0.17
	room.room_size = 0.7
	AudioServer.add_bus_effect(index, room)
	_cry_reverb = room
	voice = _voice(-5.0)
	voice.bus = bus_name
	impact = _voice(-4.0)
	flow = _voice(-13.0)
	for i in 4: piano.append(_voice(-10.0))
	# Prewarm before the 100 ms beat; synthesis cannot stall its release frame.
	ClimaxSoundBank.get_sound(&"shatter")
	ClimaxSoundBank.get_sound(&"gold_flow")
	for note in NOTES: ClimaxSoundBank.get_sound(&"piano", note)
	vacuum = AudioVacuum.new()
	add_child(vacuum)
	vacuum.finished.connect(_shatter)
	sequence.phase_changed.connect(_phase_changed)
	sequence.line_started.connect(_line_started)
	player.health.died.connect(func(_source): stop_all())

func _voice(volume: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.volume_db = volume
	add_child(sound)
	return sound

func _phase_changed(value: int) -> void:
	if stopped: return
	match value:
		BodyReassembly.Phase.SHATTER: vacuum.begin(0.1)
		BodyReassembly.Phase.REBUILD:
			voice.stop()
			_rebuilding = true
			_rebuild_time = 0
			_note_index = 0
			flow.stream = ClimaxSoundBank.get_sound(&"gold_flow")
			flow.play()
			cue_counts[&"gold_flow"] = 1
		BodyReassembly.Phase.COMPLETE: _rebuilding = false

func _shatter() -> void:
	if stopped: return
	impact.stream = ClimaxSoundBank.get_sound(&"shatter")
	impact.play()
	cue_counts[&"shatter"] = int(cue_counts.get(&"shatter", 0)) + 1

func _line_started(index: int, _text: String) -> void:
	if stopped or index < 0 or index >= BodyReassembly.CLIPS.size(): return
	voice.stop()
	panner.pan = PANS[index]
	voice.stream = load("res://assets/audio/climax/%s.wav" % BodyReassembly.CLIPS[index]) as AudioStream
	voice.pitch_scale = PITCHES[index]
	voice.play()
	played_lines.append(index)

func _process(delta: float) -> void:
	if stopped or not _rebuilding: return
	_rebuild_time += delta
	if _note_index < NOTES.size() and _rebuild_time >= _note_index*0.8:
		var sound := piano[_note_index]
		sound.stream = ClimaxSoundBank.get_sound(&"piano", NOTES[_note_index])
		sound.play()
		_note_index += 1
		cue_counts[&"piano"] = _note_index

func line_duration(index: int) -> float:
	var clip := load("res://assets/audio/climax/%s.wav" % BodyReassembly.CLIPS[index]) as AudioStream
	return clip.get_length()/PITCHES[index]+0.4

func _clear_cry_tail() -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0 or _cry_reverb == null: return
	AudioServer.remove_bus_effect(index, 1)
	AudioServer.add_bus_effect(index, _cry_reverb, 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED: _clear_cry_tail()

func stop_all() -> void:
	_clear_cry_tail()
	stopped = true
	_rebuilding = false
	if is_instance_valid(vacuum): vacuum.cancel()
	for sound in [voice, impact, flow] + piano:
		if is_instance_valid(sound): sound.stop()

func _exit_tree() -> void:
	stop_all()
	var index := AudioServer.get_bus_index(bus_name)
	if index > 0: AudioServer.remove_bus(index)
