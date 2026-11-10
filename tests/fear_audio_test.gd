extends Node3D
## Production room, real gaze/blink/facet paths; no fake audio event emission.
var checks := 0
var failures := 0
var stage: RealmStage
var director: FearAudioDirector

func check(label: String, value: bool) -> void:
	checks += 1
	if not value:
		failures += 1
	print("%s %s" % ["PASS" if value else "FAIL", label])

func frames(count := 2) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await run_checks()
	get_tree().paused = false
	var voice_ref: WeakRef = weakref(director.actor_voices.voices[0])
	stage.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	check("room exit frees actor audio voices", voice_ref.get_ref() == null)
	print("FEAR AUDIO: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func run_checks() -> void:
	stage = preload("res://maps/realms/fear_1.tscn").instantiate() as RealmStage
	add_child(stage)
	director = stage.get_node("RealmAudio") as FearAudioDirector
	director.set_process(false)
	stage.player.set_physics_process(false)
	stage.player.dash.set_physics_process(false)
	for actor in stage.enemies:
		actor.set_physics_process(false)
	await frames()
	check("production Fear room injects player and plays abyss PCM", director.player == stage.player and director.ambient.playing and director.ambient.stream == FearSoundBank.get_sound(&"fear_abyss", true))
	var watcher := stage.enemies[0] as FearRealmEnemy
	var camera := stage.player.get_node("Head/Camera3D") as Camera3D
	camera.look_at(watcher.global_position + Vector3.UP * watcher.eye_height)
	camera.rotate_y(PI)
	watcher.start_attack()
	watcher.advance_attack(0.2)
	director._process(0.016)
	var voice := director.actor_voices.voice_for(watcher)
	check("actual watcher windup starts a positional sustained lock", voice != null and voice.playing and voice.global_position.is_equal_approx(watcher.global_position + Vector3.UP))
	var early_pitch := voice.pitch_scale if voice != null else 0.0
	watcher.advance_attack(0.6)
	director._process(0.016)
	check("pitch follows actual lock progress, not player gaze timer", voice != null and voice.pitch_scale > early_pitch and is_equal_approx(voice.pitch_scale, 1.15) and watcher.gaze_progress == 0)
	camera.look_at(watcher.global_position + Vector3.UP * watcher.eye_height)
	watcher.advance_attack(0.16)
	director._process(0.016)
	check("real sustained eye contact cancels lock without residual cue", watcher.gaze_interrupts == 1 and director.actor_voices.voice_for(watcher) == null and not voice.playing)
	camera.rotate_y(PI)
	watcher.start_attack()
	watcher.advance_attack(0.2)
	watcher.warnings_enabled = false
	director._process(0.016)
	check("actor warning deprivation suppresses sound without cancelling attack", watcher.attack_elapsed > 0 and director.actor_voices.voice_for(watcher) == null)
	watcher.warnings_enabled = true
	director._process(0.016)
	director.set_deprived(true)
	check("realm deprivation immediately stops an existing lock", director.actor_voices.bindings.is_empty())
	director._process(0.016)
	check("deprived realm cannot reintroduce warning", director.actor_voices.bindings.is_empty())
	director.set_deprived(false)
	watcher._finish_attack(10)
	var trembler := stage.enemies[1] as FearRealmEnemy
	stage.player.position = Vector3(7, 0.05, -7)
	await frames()
	var before := trembler.global_position
	check("real collision-tested blink succeeds", trembler.try_blink() and trembler.global_position.distance_to(before) > 3.9)
	director._process(0.016)
	director._process(0.016)
	check("one real blink plays one phase cue", director.cue_counts.get(&"fear_phase", 0) == 1)
	stage.player.position = trembler.position + Vector3.RIGHT
	check("invalid close blink does not advance counter", not trembler.try_blink())
	director._process(0.016)
	check("failed blink cannot manufacture another phase cue", director.cue_counts.get(&"fear_phase", 0) == 1)
	var phase := FearSoundBank.get_sound(&"fear_phase")
	var stereo_diff := 0
	for i in range(100, 1500):
		stereo_diff += absi(phase.data.decode_s16(i * 4) - phase.data.decode_s16(i * 4 + 2))
	check("phase distortion contains different left/right waveforms", phase.stereo and stereo_diff > 100000)
	watcher.health.max_health = 2000
	watcher.health.health = 2000
	var card := load("res://buffs/resources/fear/gaze_pierce.tres") as BoonData
	if not stage.player.boons.has(card.id):
		stage.player.boons.request_equip(card)
	var effect := stage.player.boons.effect_for(preload("res://buffs/effects/fear_effect.gd")) as FearEffect
	effect.apply_panic(watcher)
	var status := effect.status_for(watcher)
	stage.player.position = watcher.position + Vector3(0, 0, -4)
	await frames()
	var point := status.facet_position(0) + Vector3(0, 0, -0.075)
	stage.player.boons.apply_damage(watcher, 35.0, {"kind": &"gun", "proc_depth": 0, "position": point, "direction": Vector3.BACK, "hitbox": status.facets[0], "body_part": Hitbox.BodyPart.BODY, "source": stage.player})
	check("real facet damage dispatches exactly one shatter", director.cue_counts.get(&"fear_flaw_shatter", 0) == 1)
	var muted_critical := false
	for child in stage.get_children():
		if child is FearCriticalFeedback:
			muted_critical = not child.play_sound and child.find_children("*", "AudioStreamPlayer3D", false, false).is_empty()
	check("facet keeps critical text but suppresses duplicate old audio", muted_critical)
	var ordinary := FearCriticalFeedback.spawn(stage, watcher.global_position, 70.0)
	check("ordinary non-facet critical retains existing sound", ordinary.play_sound and ordinary.get_child_count() == 2)
	camera.look_at(watcher.global_position + Vector3.UP * watcher.eye_height)
	camera.rotate_y(PI)
	watcher.start_attack()
	watcher.advance_attack(0.2)
	director._process(0.016)
	voice = director.actor_voices.voice_for(watcher)
	await get_tree().create_timer(0.05, true).timeout
	var playback_before := voice.get_playback_position() if voice != null else -1.0
	get_tree().paused = true
	var counts := director.cue_counts.duplicate()
	var elapsed_before := director.elapsed
	director._process(5.0)
	director.play_cue(&"fear_phase", Vector3.ZERO)
	await get_tree().create_timer(0.08, true).timeout
	check("pause freezes director and rejects new cues", director.elapsed == elapsed_before and counts == director.cue_counts and voice != null and absf(voice.get_playback_position() - playback_before) < 0.025)
	get_tree().paused = false
	watcher.health.apply_damage(99999, Hitbox.BodyPart.BODY, stage.player)
	director._process(0.016)
	check("dead watcher loses sustained source", director.actor_voices.voice_for(watcher) == null)
	for i in 100:
		director.play_cue(&"fear_phase", Vector3.ZERO)
	check("transients and sustained sources have fixed bounds", director.voices.size() == 16 and director.actor_voices.voices.size() == 8)
	seed(177)
	var expected := randf()
	seed(177)
	var stream := FearSoundBank.get_sound(&"fear_flaw_shatter", true)
	check("sound generation does not consume gameplay RNG", expected == randf())
	check("cached loop has zero endpoints and 16-bit stereo PCM", stream == FearSoundBank.get_sound(&"fear_flaw_shatter", true) and stream.data.decode_s16(0) == 0 and absi(stream.data.decode_s16(stream.data.size() - 2)) < 100)
	if "--audio-proof" in OS.get_cmdline_user_args():
		FearSoundBank.get_sound(&"fear_abyss", true).save_to_wav("res://docs/proof/issue-177/abyss.wav")
		phase.save_to_wav("res://docs/proof/issue-177/phase.wav")
		FearSoundBank.get_sound(&"fear_flaw_shatter").save_to_wav("res://docs/proof/issue-177/flaw-shatter.wav")
	stage.player.health.apply_damage(99999, Hitbox.BodyPart.BODY)
	check("real player death stops ambient, transients and locks", director.stopped and not director.ambient.playing and director.voices.all(func(v): return not v.playing) and director.actor_voices.bindings.is_empty())
	await cross_realm_check()

func cross_realm_check() -> void:
	var other := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(other)
	other.player.set_physics_process(false)
	other.player.dash.set_physics_process(false)
	for actor in other.enemies:
		actor.set_physics_process(false)
	var target := other.enemies[0]
	target.health.max_health = 2000
	target.health.health = 2000
	target.rotation = Vector3.ZERO
	other.player.boons.request_equip(load("res://buffs/resources/fear/gaze_pierce.tres"))
	var effect := other.player.boons.effect_for(preload("res://buffs/effects/fear_effect.gd")) as FearEffect
	effect.apply_panic(target)
	var status := effect.status_for(target)
	other.player.position = target.position + Vector3(0, 0, -4)
	await frames()
	other.player.boons.apply_damage(target, 35.0, {"kind": &"gun", "proc_depth": 0, "position": status.facet_position(0) + Vector3(0, 0, -0.075), "direction": Vector3.BACK, "hitbox": status.facets[0], "body_part": Hitbox.BodyPart.BODY, "source": other.player})
	var other_audio := other.get_node("RealmAudio") as RealmAudioDirector
	check("Fear boon in production Sloth room still plays one facet shatter", other_audio.cue_counts.get(&"fear_flaw_shatter", 0) == 1 and other_audio.get_sound(&"fear_flaw_shatter") == FearSoundBank.get_sound(&"fear_flaw_shatter"))
	# Legacy/standalone compositions still own their old critical audio source.
	other_audio.free()
	other.player.position = target.position + Vector3(0, 0, 4)
	var old_facet := status.facets[1]
	other.player.boons.apply_damage(target, 35.0, {"kind": &"gun", "proc_depth": 0, "position": status.facet_position(1) + Vector3(0, 0, 0.075), "direction": Vector3.FORWARD, "hitbox": status.facets[1], "body_part": Hitbox.BodyPart.BODY, "source": other.player})
	var fallback_count := 0
	for child in other.get_children():
		if child is FearCriticalFeedback and child.play_sound: fallback_count += 1
	check("real facet without a managed director retains exactly one legacy voice",fallback_count == 1 and status.facets[1] != old_facet)
	other.queue_free()
	await frames()
