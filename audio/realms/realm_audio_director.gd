class_name RealmAudioDirector
extends Node
## The composition root injects the room. Audio never reads campaign singletons.
const MAX_VOICES := 16
var stage: RealmStage
var player: Player
var deprived := false
var stopped := false
var ambient: AudioStreamPlayer
var ambient_tail: AudioStreamPlayer
var _fade_left := 0.0
var voices: Array[AudioStreamPlayer3D] = []
var cue_counts: Dictionary = {}
var elapsed := 0.0

func setup(room: RealmStage) -> void:
	stage = room
	player = room.player
	deprived = room.deprivations.has(room.realm)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	ambient = AudioStreamPlayer.new()
	ambient.name = "RealmAmbience"
	ambient.bus = &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"
	ambient.volume_db = -18
	add_child(ambient)
	ambient_tail = AudioStreamPlayer.new()
	ambient_tail.bus = ambient.bus
	add_child(ambient_tail)
	for index in MAX_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.max_distance = 45
		voice.unit_size = 6
		voice.volume_db = -12
		add_child(voice)
		voices.append(voice)
	player.boons.event_dispatched.connect(_on_boon_event)
	stage.realm_defeated.connect(_on_realm_defeated)
	stage.player_fallen.connect(_on_fallen)
	set_deprived(deprived)
	if is_instance_valid(stage.hud):
		stage.hud.settings.changed.connect(_apply_audio_settings)
		_apply_audio_settings()

func _apply_audio_settings() -> void:
	var index := AudioServer.get_bus_index(&"Music")
	if index >= 0:
		AudioServer.set_bus_mute(index,stage.hud.settings.music_volume <= 0.001)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(stage.hud.settings.music_volume,0.001)))

func get_sound(kind: StringName, loop := false) -> AudioStreamWAV:
	return RealmSoundBank.get_sound(kind,loop)

func set_ambience(kind: StringName) -> void:
	if ambient.playing:
		ambient_tail.stream = ambient.stream
		ambient_tail.volume_db = ambient.volume_db
		ambient_tail.play(ambient.get_playback_position())
		_fade_left = 0.35
	ambient.stream = get_sound(kind,true)
	ambient.volume_db = -60 if _fade_left > 0 else -18
	ambient.play()

func set_deprived(value: bool) -> void:
	deprived = value

func play_cue(kind: StringName, point: Vector3, pitch := 1.0, volume := -12.0) -> void:
	if stopped or get_tree().paused: return
	cue_counts[kind] = int(cue_counts.get(kind,0))+1
	var voice := voices[0]
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	voice.stop()
	voice.stream = get_sound(kind)
	voice.global_position = point
	voice.pitch_scale = pitch
	voice.volume_db = volume
	voice.play()

func _on_boon_event(event: StringName, context: Dictionary) -> void:
	if event == &"sloth_burst":
		play_cue(&"delayed_burst",context.get("position",player.global_position),1.0,-7.0)

func _on_realm_defeated(_room: RealmStage) -> void:
	set_deprived(true)

func _on_fallen(_room: RealmStage, _cause: StringName) -> void:
	stop_all()

func stop_all() -> void:
	stopped = true
	ambient.stop()
	ambient_tail.stop()
	for voice in voices: voice.stop()

func _process(delta: float) -> void:
	if stopped: return
	elapsed += delta
	if _fade_left > 0:
		_fade_left = maxf(0,_fade_left-delta)
		var progress := 1.0-_fade_left/0.35
		ambient.volume_db = -18 + linear_to_db(maxf(progress,0.001))
		ambient_tail.volume_db = -18 + linear_to_db(maxf(1.0-progress,0.001))
		if _fade_left <= 0: ambient_tail.stop()

func _exit_tree() -> void:
	if is_instance_valid(ambient): ambient.stop()
	if is_instance_valid(ambient_tail): ambient_tail.stop()
	for voice in voices:
		if is_instance_valid(voice): voice.stop()
