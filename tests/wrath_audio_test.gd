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
	# the realm intro panel is a UI concern; these tests only care about the flow
	MetaProgression.introduced_realms.assign([0,1,2,3])
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
	check("managed slam is acknowledged and never starts legacy fallback", not orphan_slam and bool(slams[0].get("wrath_wall_audio_managed", false)))
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
	await legacy_fallback_checks()
	await last_piercer_reward_checks()

func legacy_fallback_checks() -> void:
	for mode in ["normal", "paused", "dead", "removed"]:
		# Old combat benches instantiate Player and SlothEnemy without RealmStage/director.
		var arena := Node3D.new()
		add_child(arena)
		for layout in [[Vector3(0, -0.5, 0), Vector3(20, 1, 20)], [Vector3(0, 2, -6), Vector3(10, 4, 0.4)]]:
			var wall := StaticBody3D.new()
			wall.collision_layer = CollisionLayers.WORLD
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = layout[1]
			collision.shape = shape
			wall.add_child(collision)
			wall.position = layout[0]
			arena.add_child(wall)
		var legacy_player := preload("res://actors/player/player.tscn").instantiate() as Player
		arena.add_child(legacy_player)
		legacy_player.set_physics_process(false)
		legacy_player.dash.set_physics_process(false)
		legacy_player.boons.request_equip(load("res://buffs/resources/wrath/wrath_gun_cannon.tres"))
		var effect := legacy_player.boons.effect_for(preload("res://buffs/effects/wrath_effect.gd")) as WrathBoons
		var enemy := preload("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
		enemy.kind = SlothEnemy.Kind.RECLUSE
		enemy.position = Vector3(0, 0.04, -3)
		arena.add_child(enemy)
		enemy.health.max_health = 1000
		enemy.health.health = 1000
		var actual_slams: Array[Dictionary] = []
		legacy_player.boons.event_dispatched.connect(func(event: StringName, ctx: Dictionary):
			if event != &"wall_slam":
				return
			actual_slams.append(ctx)
			if mode == "paused":
				get_tree().paused = true
			elif mode == "dead":
				legacy_player.health.apply_damage(99999, Hitbox.BodyPart.BODY)
			elif mode == "removed":
				legacy_player.boons.remove(WrathBoons.GUN))
		await frames(3)
		effect.knock(enemy, Vector3.FORWARD, 3.0)
		for i in 60:
			await frames(1)
			if not actual_slams.is_empty():
				break
		enemy.set_physics_process(false)
		await frames(1) # Drain the deferred ownership check after event consumers.
		check("legacy %s uses actual WORLD contact without an audio director" % mode, actual_slams.size() == 1 and actual_slams[0].wall_impact and arena.find_children("*", "RealmAudioDirector", true, false).is_empty())
		var fallback := arena.get_node_or_null("WrathWallFallback") as AudioStreamPlayer3D
		if mode == "normal":
			check("unmanaged legacy slam retains exactly one original clock-break voice", fallback != null and fallback.playing and (fallback.stream as AudioStreamWAV).data == ProceduralAudio.generate("clock_break").data and fallback.global_position.is_equal_approx(actual_slams[0].position))
			var audio_ref: WeakRef = weakref(fallback)
			legacy_player.boons.remove(WrathBoons.GUN)
			await frames(1)
			check("removing the legacy effect stops and frees its fallback voice", audio_ref.get_ref() == null)
		else:
			check("legacy %s cannot start a deferred sound" % mode, fallback == null)
		get_tree().paused = false
		await frames(1)
		check("legacy %s never schedules a late replay" % mode, arena.get_node_or_null("WrathWallFallback") == null)
		arena.queue_free()
		await frames(1)


func _timing_snapshot(room: RealmStage, audio: WrathAudioDirector, actor: WrathRealmEnemy, label: String) -> Dictionary:
	var row := {"event":label,"ticks_ms":Time.get_ticks_msec(),"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"paused":get_tree().paused,"wall_detonations":actor.wall_detonations,"cue_count":int(audio.cue_counts.get(&"wrath_wall_slam",0)),"living_enemies":room.living_enemies(),"enemy_dead":actor.health.is_dead(),"stage_cleared":room.cleared,"picker_exists":is_instance_valid(room.selection)}
	print("LAST PIERCER TIMING " + JSON.stringify(row))
	return row


func last_piercer_reward_checks() -> void:
	var room := preload("res://maps/realms/wrath_1.tscn").instantiate() as RealmStage
	add_child(room)
	var audio := room.get_node("RealmAudio") as WrathAudioDirector
	room.player.set_physics_process(false)
	room.player.dash.set_physics_process(false)
	room.player.health.invulnerable = true
	room.player.weapon.trigger_enabled = false
	var actor := room.enemies[0] as WrathRealmEnemy
	for enemy in room.enemies: enemy.set_physics_process(false)
	var death_rows: Array[Dictionary] = []
	var clear_rows: Array[Dictionary] = []
	room.enemy_defeated.connect(func(_room: RealmStage, defeated: Enemy):
		if defeated == actor: death_rows.append(_timing_snapshot(room,audio,actor,"real_enemy_defeated")))
	room.stage_cleared.connect(func(_room: RealmStage):
		clear_rows.append(_timing_snapshot(room,audio,actor,"real_stage_cleared")))
	for enemy in room.enemies:
		if enemy != actor: enemy.health.apply_damage(99999,Hitbox.BodyPart.BODY,room.player)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10,4,0.4)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0,2,-6)
	room.add_child(wall)
	actor.position = Vector3(0,0.04,-4.3)
	actor.velocity = Vector3.ZERO
	room.player.position = Vector3(0,0.04,-8)
	await frames(3)
	check("last-piercer fixture has one live actor and no synthetic wall count", room.living_enemies()==1 and actor.wall_detonations==0 and not get_tree().paused)
	actor.start_attack()
	actor.set_physics_process(true)
	var deadline := Time.get_ticks_msec()+15000
	# the last piercer must die before the room clears, which is when the talent
	# orb appears in front of the gate - claim it so the picker opens
	var claimed_orb := false
	while not is_instance_valid(room.selection) and Time.get_ticks_msec()<deadline:
		if not claimed_orb and room.orb_pending():
			claimed_orb = true
			room.claim_talent()
		await get_tree().process_frame
	var real_path := is_instance_valid(room.selection) and actor.wall_detonations==1 and actor.health.is_dead() and room.cleared and get_tree().paused
	check("last piercer really self-detonates and opens the paused reward picker",real_path)
	if not real_path:
		room.queue_free()
		await frames(1)
		return
	var pause_row := _timing_snapshot(room,audio,actor,"picker_paused")
	check("one heavy impact is dispatched synchronously at real death before reward pause",death_rows.size()==1 and death_rows[0].cue_count==1 and not death_rows[0].paused and clear_rows.size()==1 and clear_rows[0].cue_count==1 and not clear_rows[0].paused and pause_row.cue_count==1)
	await get_tree().process_frame
	await get_tree().process_frame
	var held := _timing_snapshot(room,audio,actor,"picker_pause_held")
	check("reward pause retains the consumed impact without another voice",held.paused and held.cue_count==1)
	var picker := room.selection
	check("real reward exposes a selectable card",not picker._buttons.is_empty())
	if picker._buttons.is_empty():
		room.queue_free()
		await frames(1)
		return
	picker._buttons[0].pressed.emit()
	_timing_snapshot(room,audio,actor,"real_card_button_closed_picker")
	for i in 4: await get_tree().process_frame
	var resumed := _timing_snapshot(room,audio,actor,"four_process_frames_after_choice")
	check("real card choice resumes gameplay without replaying the collision",not resumed.paused and not resumed.picker_exists and room.exit_ready and resumed.cue_count==1)
	room.queue_free()
	await frames(1)
