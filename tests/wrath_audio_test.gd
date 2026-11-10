extends Node3D
## Real phase transitions, swept motion, SpiteStatus contacts and spawned spikes.
var checks := 0
var failures := 0
var stage: RealmStage
var director: WrathAudioDirector
var slams: Array[Dictionary] = []

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
	stage.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("WRATH AUDIO: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func run_checks() -> void:
	stage = preload("res://maps/realms/wrath_1.tscn").instantiate() as RealmStage
	add_child(stage)
	director = stage.get_node("RealmAudio") as WrathAudioDirector
	director.set_process(false)
	stage.player.set_physics_process(false)
	stage.player.dash.set_physics_process(false)
	stage.player.health.invulnerable = true
	for actor in stage.enemies:
		actor.set_physics_process(false)
	await frames()
	var geometry := stage.geometry as WrathRealm
	check("production room takes explicit ownership of kiln ambience", geometry.audio_managed and not geometry.ambience.playing and director.ambient.playing)
	geometry.set_deprivation(false)
	check("legacy environment cannot restart managed ambience", not geometry.ambience.playing)
	var piercer := stage.enemies[0] as WrathRealmEnemy
	piercer.position = Vector3(0, 0.04, -8)
	stage.player.position = Vector3(0, 0.04, -15)
	piercer.start_attack()
	piercer._physics_process(0.2)
	director._process(0.016)
	var voice := director.actor_voices.voice_for(piercer)
	check("real piercer windup starts positional pressure sound", voice != null and voice.playing and voice.stream == WrathSoundBank.get_sound(&"wrath_charge", true))
	var early_pitch := voice.pitch_scale if voice != null else 0.0
	piercer._physics_process(0.3)
	director._process(0.016)
	check("charge pitch increases with real remaining windup", voice != null and voice.pitch_scale > early_pitch)
	piercer.warnings_enabled = false
	director._process(0.016)
	check("deprived warning hides pressure cue without altering windup", director.actor_voices.voice_for(piercer) == null and piercer.attack_phase == WrathRealmEnemy.Attack.WINDUP)
	piercer._physics_process(0.3)
	piercer._physics_process(0.016)
	director._process(0.016)
	voice = director.actor_voices.voice_for(piercer)
	check("actual 23 m/s rush replaces warning with physical air sound", piercer.velocity.length() >= 23.0 and voice != null and voice.stream == WrathSoundBank.get_sound(&"wrath_rush", true))
	var aggressor := stage.enemies[2] as WrathRealmEnemy
	aggressor.position = Vector3(5, 0.04, -8)
	aggressor.start_attack()
	aggressor._physics_process(0.42)
	aggressor._physics_process(0.016)
	director._process(0.016)
	var saw := director.actor_voices.voice_for(aggressor)
	check("real aggressor rush drives saw rotation sound", saw != null and saw.stream == WrathSoundBank.get_sound(&"wrath_saw", true) and saw.pitch_scale > 1.0)
	aggressor.boon_stunned = true
	director._process(0.016)
	check("stunned powered blade has no residual saw sound", director.actor_voices.voice_for(aggressor) == null and not saw.playing)
	aggressor.boon_stunned = false
	aggressor.begin_retreat(Vector3(10, 0, 10), 5.0)
	director._process(0.016)
	check("retreat removes attack sound sources", director.actor_voices.voice_for(aggressor) == null)
	# A dedicated nearby physical wall makes actual Jolt contact deterministic.
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.4)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 2, -6)
	stage.add_child(wall)
	piercer.position = Vector3(0, 0.04, -3)
	piercer.velocity = Vector3.ZERO
	piercer.attack_phase = WrathRealmEnemy.Attack.RECOVER
	piercer.attack_left = 100
	piercer.health.max_health = 1000
	piercer.health.health = 1000
	stage.player.position = Vector3(0, 0.04, 4)
	stage.player.boons.request_equip(load("res://buffs/resources/wrath/wrath_gun_cannon.tres"))
	stage.player.boons.request_equip(load("res://buffs/resources/wrath/wrath_shrapnel.tres"))
	var effect := stage.player.boons.effect_for(preload("res://buffs/effects/wrath_effect.gd")) as WrathBoons
	stage.player.boons.event_dispatched.connect(func(event: StringName, ctx: Dictionary):
		if event == &"wall_slam":
			slams.append(ctx.duplicate()))
	await frames()
	effect.knock(piercer, Vector3.FORWARD, 3.0)
	piercer.set_physics_process(true)
	await frames(25)
	piercer.set_physics_process(false)
	check("real high-speed WORLD contact emits exactly one heavy slam", slams.size() == 1 and slams[0].wall_impact and director.cue_counts.get(&"wrath_wall_slam", 0) == 1)
	check("actual five emitted lava spikes each have a bounded whoosh", director.cue_counts.get(&"wrath_spike", 0) == 5)
	var orphan_slam := false
	for child in stage.get_children():
		if child is AudioStreamPlayer3D:
			orphan_slam = true
	check("old unpooled clock-break sound is removed", not orphan_slam)
	# A floor-only impulse cannot fabricate a collision cue.
	piercer.boon_stunned = false
	piercer.boon_time_scale = 1.0
	piercer.position = Vector3(10, 0.04, 5)
	piercer.velocity = Vector3.ZERO
	piercer.attack_phase = WrathRealmEnemy.Attack.RECOVER
	piercer.attack_left = 100
	await frames()
	effect.knock(piercer, Vector3.FORWARD, 2.5)
	piercer.set_physics_process(true)
	await frames(20)
	piercer.set_physics_process(false)
	check("floor-only travel produces no additional slam", slams.size() == 1 and director.cue_counts.get(&"wrath_wall_slam", 0) == 1)
	stage.player.boons.remove(WrathTraits.SHRAPNEL)
	stage.player.boons.remove(WrathBoons.GUN)
	var impacts_before := int(director.cue_counts.get(&"wrath_wall_slam", 0))
	# Use a fresh production piercer so no boon stun from the previous scenario leaks in.
	var detonator := preload("res://actors/enemy/wrath/wrath_realm_enemy.tscn").instantiate() as WrathRealmEnemy
	detonator.variant = WrathRealmEnemy.Variant.PIERCER
	detonator.position = Vector3(0, 0.04, -4.3)
	stage.add_child(detonator)
	stage._register_actor(detonator)
	detonator.set_physics_process(false)
	stage.player.position = Vector3(0, 0.04, -8)
	await frames()
	detonator.start_attack()
	detonator._physics_process(0.76)
	for i in 12:
		detonator._physics_process(0.016)
		await frames(1)
	director._process(0.016)
	check("piercer real wall self-detonation adds exactly one impact", detonator.wall_detonations == 1 and detonator.emitted_shards == 8 and director.cue_counts.get(&"wrath_wall_slam", 0) == impacts_before + 1)
	director._process(8.0)
	check("distant thermal metal has deterministic simulation-time cadence", director.cue_counts.get(&"wrath_metal", 0) == 1)
	get_tree().paused = true
	var counts := director.cue_counts.duplicate()
	var elapsed_before := director.elapsed
	director._process(12.0)
	director.play_cue(&"wrath_wall_slam", Vector3.ZERO)
	check("pause freezes metal cadence and rejects new transients", director.elapsed == elapsed_before and counts == director.cue_counts)
	get_tree().paused = false
	for i in 100:
		director.play_cue(&"wrath_wall_slam", Vector3.ZERO)
	check("impact storms cannot allocate unbounded players", director.voices.size() == 16 and director.actor_voices.voices.size() == 8)
	seed(178)
	var expected := randf()
	seed(178)
	var stream := WrathSoundBank.get_sound(&"wrath_wall_slam", true)
	check("sound synthesis leaves gameplay RNG untouched", expected == randf())
	check("impact loop is cached bounded PCM with zero seam", stream == WrathSoundBank.get_sound(&"wrath_wall_slam", true) and stream.data.decode_s16(0) == 0 and absi(stream.data.decode_s16(stream.data.size() - 2)) < 100)
	if "--audio-proof" in OS.get_cmdline_user_args():
		WrathSoundBank.get_sound(&"wrath_kiln", true).save_to_wav("res://docs/proof/issue-178/kiln.wav")
		WrathSoundBank.get_sound(&"wrath_wall_slam").save_to_wav("res://docs/proof/issue-178/wall-slam.wav")
	stage.player.health.invulnerable = false
	stage.player.health.apply_damage(99999, Hitbox.BodyPart.BODY)
	check("real death stops every managed sound", director.stopped and director.voices.all(func(v): return not v.playing) and director.actor_voices.bindings.is_empty())
	var boss_stage := preload("res://maps/realms/wrath_boss.tscn").instantiate() as RealmStage
	add_child(boss_stage)
	boss_stage.player.set_physics_process(false)
	for actor in boss_stage.enemies:
		actor.set_physics_process(false)
	var boss_audio := boss_stage.get_node("RealmAudio") as WrathAudioDirector
	var boss_geometry := boss_stage.geometry as WrathRealm
	boss_stage.boss.health.apply_damage(999999, Hitbox.BodyPart.BODY, boss_stage.player)
	await frames()
	boss_geometry.set_deprivation(false)
	check("real boss defeat silences managed kiln without legacy restart", boss_stage.boss_defeated and boss_audio.deprived and not boss_audio.ambient.playing and not boss_geometry.ambience.playing)
	boss_stage.queue_free()
	await frames()
