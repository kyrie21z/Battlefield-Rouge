extends Node3D
var checks := 0
var failures := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
func frames(count: int) -> void:
	for i in count: await get_tree().process_frame
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var original_mute := AudioServer.is_bus_mute(0)
	var original_volume := AudioServer.get_bus_volume_db(0)
	var baseline_buses := AudioServer.bus_count
	var corridor := preload("res://levels/climax/threshold_corridor.tscn").instantiate()
	add_child(corridor)
	var player: Player = corridor.player
	player.set_physics_process(false)
	var crown := player.get_node("CrownVoiceSystem") as CrownVoiceSystem
	var dsp := crown.voice_dsp
	var index := AudioServer.get_bus_index(dsp.bus_name)
	check("real worn Crown routes through 300–3500 Hz chain", crown.audio.bus == dsp.bus_name and AudioServer.get_bus_effect(index,0).cutoff_hz == 300 and AudioServer.get_bus_effect(index,1).cutoff_hz == 3500)
	var wet := dsp.plate.wet
	var drive := dsp.harmonics.drive
	crown.set_fracture_level(4)
	check("actual radiance signal brightens plate and harmonics", dsp.plate.wet > wet and dsp.harmonics.drive > drive and dsp.presence.gain > 1)
	var copy_voice := AudioStreamPlayer3D.new()
	add_child(copy_voice)
	var copy_dsp := CrownVoiceDSP.new()
	copy_dsp.setup(copy_voice, 0.5)
	add_child(copy_dsp)
	check("3D Crown voice has an isolated low-radiance effect instance", copy_voice.bus != crown.audio.bus and copy_dsp.plate.wet < dsp.plate.wet)
	copy_dsp.free()
	check("3D source returns to original bus on component removal", copy_voice.bus == &"Master")
	copy_voice.free()
	var sequence: BodyReassembly = corridor.reassembly
	var sound: ClimaxAudio = sequence.soundscape
	AudioServer.set_bus_mute(0, false)
	AudioServer.set_bus_volume_db(0, -7.25)
	check("real body fracture begins its audio vacuum", sequence.begin() and sound.vacuum.active and AudioServer.is_bus_mute(0) and not sound.impact.playing)
	get_tree().paused = true
	await frames(4)
	check("pause releases Master mute without changing volume", not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_db(0), -7.25) and sound.vacuum.active)
	get_tree().paused = false
	await get_tree().create_timer(0.16).timeout
	check("100ms active vacuum releases before one stereo shatter", not sound.vacuum.active and not AudioServer.is_bus_mute(0) and sound.cue_counts.get(&"shatter",0) == 1 and sound.impact.stream.stereo)
	sequence.set_process(false)
	sequence._process(1.1)
	check("first real line is left and keeps original Chinese WAV", sound.played_lines == [0] and is_equal_approx(sound.panner.pan, ClimaxAudio.PANS[0]) and sound.voice.stream == load("res://assets/audio/climax/slumber.wav"))
	for i in range(1,5):
		sequence._process(20.0)
		check("line %d has authored pan and exact duration" % i, sound.played_lines.back() == i and is_equal_approx(sound.panner.pan, ClimaxAudio.PANS[i]) and is_equal_approx(sequence._line_left, sound.line_duration(i)))
	var position_before := sound.voice.get_playback_position()
	get_tree().paused = true
	await get_tree().create_timer(0.09,true).timeout
	check("pause also freezes cry playback", absf(sound.voice.get_playback_position()-position_before)<0.04)
	get_tree().paused = false
	sequence._process(20.0)
	check("real REBUILD starts golden liquid resonance", sequence.phase == BodyReassembly.Phase.REBUILD and sound.flow.playing and not sound.voice.playing)
	for i in 4: sound._process(0.8)
	check("reassembly plays four original warm piano single notes", sound.cue_counts.get(&"piano",0) == 4 and sound.piano.all(func(v): return v.stream is AudioStreamWAV))
	sequence._process(3.2)
	sequence._process(1.6)
	check("full sequence completes with ordered five voices", sequence.phase == BodyReassembly.Phase.COMPLETE and sound.played_lines == [0,1,2,3,4])
	corridor.free()
	await frames(2)
	check("scene exit removes all owned audio buses", AudioServer.bus_count == baseline_buses)
	# Destruction during the live vacuum, including an already-muted baseline.
	for start_muted in [false, true]:
		AudioServer.set_bus_mute(0, start_muted)
		var guard := AudioVacuum.new()
		add_child(guard)
		guard.begin(0.1)
		guard.free()
		check("early exit restores exact mute baseline %s" % start_muted, AudioServer.is_bus_mute(0) == start_muted and is_equal_approx(AudioServer.get_bus_volume_db(0), -7.25))
	AudioServer.set_bus_mute(0, false)
	var first := AudioVacuum.new()
	var second := AudioVacuum.new()
	add_child(first)
	add_child(second)
	first.begin()
	second.begin()
	first.free()
	check("overlapping vacuum keeps mute until last owner exits", AudioServer.is_bus_mute(0))
	second.free()
	check("last vacuum releases original state without mute leak", not AudioServer.is_bus_mute(0))
	var parent_bus := StringName("TemporaryParentAudio")
	AudioServer.add_bus()
	var parent_index := AudioServer.bus_count-1
	AudioServer.set_bus_name(parent_index,parent_bus)
	var orphan := AudioStreamPlayer.new()
	orphan.bus = parent_bus
	add_child(orphan)
	var orphan_dsp := CrownVoiceDSP.new()
	orphan_dsp.setup(orphan)
	add_child(orphan_dsp)
	AudioServer.remove_bus(parent_index)
	orphan_dsp.free()
	check("removed original bus safely falls back to Master", orphan.bus == &"Master")
	orphan.free()
	AudioServer.set_bus_mute(0, false)
	var abandoned := preload("res://levels/climax/threshold_corridor.tscn").instantiate()
	add_child(abandoned)
	abandoned.reassembly.begin()
	var vacuum_was_live := AudioServer.is_bus_mute(0)
	abandoned.free()
	check("early actual corridor exit cancels its live vacuum and buses", vacuum_was_live and not AudioServer.is_bus_mute(0) and AudioServer.bus_count == baseline_buses)
	AudioServer.set_bus_mute(0,false)
	var doomed := preload("res://levels/climax/threshold_corridor.tscn").instantiate()
	add_child(doomed)
	doomed.reassembly.begin()
	doomed.player.health.apply_damage(99999, Hitbox.BodyPart.BODY)
	check("death during actual sequence releases vacuum and stops voices", not AudioServer.is_bus_mute(0) and doomed.reassembly.soundscape.stopped and not doomed.reassembly.soundscape.vacuum.active)
	doomed.free()
	await frames(2)
	check("death and scene cleanup leave bus count unchanged", AudioServer.bus_count == baseline_buses)
	AudioServer.set_bus_mute(0,original_mute)
	AudioServer.set_bus_volume_db(0,original_volume)
	print("CROWN CLIMAX AUDIO: %d checks, %d failed" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
