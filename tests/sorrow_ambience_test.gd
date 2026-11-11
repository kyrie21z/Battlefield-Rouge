extends Node
var checks := 0
var failures := 0
var gunshots := 0
var output := ""
var finished := false

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for index in count: await get_tree().physics_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	await _run()
	check("production ambience scenario finishes",finished)
	OS.delay_msec(250)
	print("SORROW AMBIENCE: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _gunshot(_point: Vector3) -> void:
	gunshots += 1

func _run() -> void:
	var rain := SorrowSoundBank.get_sound(&"rain",true)
	check("rain keeps four seconds of mono PCM16 and its full loop",rain.mix_rate == 22050 and rain.format == AudioStreamWAV.FORMAT_16_BITS and not rain.stereo and rain.data.size() == 176400 and rain.loop_end == 88200 and rain.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	SorrowSoundBank._cache.erase("rain_loop")
	check("fresh rain synthesis is byte deterministic",rain.data == SorrowSoundBank.get_sound(&"rain",true).data)
	seed(177)
	var expected := randi()
	seed(177)
	SorrowSoundBank._cache.erase("rain_loop")
	SorrowSoundBank.get_sound(&"rain",true)
	check("rain synthesis leaves gameplay randomness untouched",randi() == expected)
	var count := rain.data.size()/2
	var peak := 0.0
	var energy := 0.0
	for index in count:
		var value := float(rain.data.decode_s16(index*2))/32768
		peak = maxf(peak,absf(value))
		energy += value*value
	var rms := sqrt(energy/count)
	var seam := absf(float(rain.data.decode_s16(0)-rain.data.decode_s16((count-1)*2))/32768)
	check("rain is audible continuous noise with no clipping",rms > 0.01 and rms < 0.05 and peak < 0.3)
	check("loop wrap has no isolated sharp discontinuity",seam < 0.03)
	print("RAIN_PCM rms=%.6f peak=%.6f wrap_delta=%.6f" % [rms,peak,seam])
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		check("actual production rain preview saves",rain.save_to_wav(output.path_join("rain.wav")) == OK)
		var hashes := {}
		for kind in SorrowSoundBank.KINDS:
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(SorrowSoundBank.get_sound(kind).data)
			hashes[kind] = hash.finish().hex_encode()
		var file := FileAccess.open(output.path_join("cue-hashes.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(hashes,"  "))
	var room := preload("res://maps/realms/sorrow_1.tscn").instantiate() as RealmStage
	add_child(room)
	var player := room.player
	player.set_physics_process(false)
	player.dash.set_physics_process(false)
	for actor in room.enemies: actor.set_physics_process(false)
	var director := room.get_node("RealmAudio") as SorrowAudioDirector
	var enemy_gun := ProceduralAudio.generate("enemy_shot").data
	var idle_gun_voice := false
	var audio_nodes := room.find_children("*","AudioStreamPlayer",true,false)+room.find_children("*","AudioStreamPlayer3D",true,false)
	Events.gunshot.connect(_gunshot)
	for tick in 520:
		await get_tree().physics_frame
		for voice in audio_nodes:
			if voice.playing and voice.stream is AudioStreamWAV:
				idle_gun_voice = idle_gun_voice or voice.stream == player.weapon._gunshot or voice.stream.data == enemy_gun
	check("idle across two loops emits no gameplay gunshot events",gunshots == 0)
	check("no idle voice plays the real player or stock enemy gunshot",not idle_gun_voice)
	check("idle room plays only the managed rain bed in its environment pool",director.ambient.playing and director.ambient.stream == SorrowSoundBank.get_sound(&"rain",true) and not director.ambient_tail.playing and director.voices.all(func(voice):return not voice.playing) and not room.geometry.splash.playing)
	check("idle movement does not generate water-step or slide shots",director.cue_counts.get(&"water_step",0) == 0 and director.cue_counts.get(&"water_slide",0) == 0)
	player.aim_at(Vector3(0,3,-20))
	check("real player gunshot remains audible and emits its own event",player.weapon.try_fire() and gunshots == 1 and player.weapon._shot_voices.any(func(voice):return voice.playing))
	var time := director.elapsed
	get_tree().paused = true
	await frames(4)
	check("pause freezes the environment clock",director.elapsed == time)
	get_tree().paused = false
	director.set_deprived(true)
	check("deprivation stops both environmental voices",not director.ambient.playing and not director.ambient_tail.playing)
	room.queue_free()
	await frames(3)
	Events.gunshot.disconnect(_gunshot)
	finished = true
