class_name SlothAudioDirector
extends RealmAudioDirector
const CALM_BPM := 60.0
const FRANTIC_BPM := 148.0
var bpm := CALM_BPM
var beat_left := 0.0

func _ready() -> void:
	if stage.geometry is SlothRealm: stage.geometry.set_audio_managed(true)
	for kind in [&"warm_pad",&"gears"]: RealmSoundBank.get_sound(kind,true)
	for kind in [&"second_tick",&"pendulum",&"heartbeat",&"delayed_burst"]: RealmSoundBank.get_sound(kind)
	super._ready()

func set_deprived(value: bool) -> void:
	super.set_deprived(value)
	bpm = FRANTIC_BPM if value else CALM_BPM
	beat_left = 0.0
	set_ambience(&"gears" if value else &"warm_pad")

func _process(delta: float) -> void:
	super._process(delta)
	if stopped: return
	beat_left -= delta
	if beat_left <= 0:
		beat_left += 60.0/bpm
		play_cue(&"second_tick" if deprived else &"pendulum",player.global_position)
		if not deprived: play_cue(&"heartbeat",player.global_position,1.0,-21.0)
