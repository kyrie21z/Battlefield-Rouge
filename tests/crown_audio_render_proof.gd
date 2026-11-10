extends Node
## Native mixer render, for reviewable audio artifacts, not human approval.
var failures := 0
const OUTPUT := "res://docs/proof/issue-180/audio/"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var voice := AudioStreamPlayer.new()
	voice.volume_db = -8
	add_child(voice)
	var dsp := CrownVoiceDSP.new()
	dsp.setup(voice)
	add_child(dsp)
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index(dsp.bus_name),record)
	voice.stream = preload("res://assets/audio/crown/dynamic/first.wav")
	for strength in [0.5, 16.5888]:
		dsp.set_radiance(0,strength)
		dsp.flush_tail()
		# flush_tail replaces the final plate effect (index 4), leaving recorder 5.
		record.set_recording_active(true)
		voice.play()
		await get_tree().create_timer(3.0).timeout
		voice.stop()
		await get_tree().create_timer(0.55).timeout
		record.set_recording_active(false)
		var clip := record.get_recording()
		var path := OUTPUT + ("crown_soft.wav" if strength < 1 else "crown_blazing.wav")
		var error := clip.save_to_wav(path)
		if error != OK or clip.data.is_empty(): failures += 1
		print("RENDER %s frames=%d error=%d" % [path,clip.data.size()/4,error])
	dsp.free()
	voice.free()
	for kind in [&"shatter", &"gold_flow", &"piano"]:
		var sound := ClimaxSoundBank.get_sound(kind)
		if sound.save_to_wav(OUTPUT + String(kind) + ".wav") != OK: failures += 1
		print("SYNTH %s stereo=%s duration=%.3f" % [kind,sound.stereo,sound.get_length()])
	print("CROWN AUDIO RENDER: %d failed" % failures)
	get_tree().quit(0 if failures == 0 else 1)
