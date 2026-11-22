extends Node3D
var checks := 0
var failures := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
func frames(count := 3) -> void:
	for i in count: await get_tree().physics_frame
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var initial_buses := AudioServer.bus_count
	var opening := preload("res://ui/cinematics/opening_sequence.tscn").instantiate() as OpeningSequence
	add_child(opening)
	opening.set_process(false)
	opening.start()
	check("reality interviewer keeps its original opening bus",opening.crown_voice_dsp == null and String(opening.audio.bus).begins_with("OpeningVoice_"))
	opening._enter(OpeningSequence.Phase.ENCOUNTER)
	check("actual opening Crown speech uses one radio DSP",opening.audio.bus == opening.crown_voice_dsp.bus_name and opening.audio.stream == opening.clips["wake"] and opening.audio.playing)
	var opening_bus := opening.crown_voice_dsp.bus_name
	opening.skip()
	check("skip stops processed Crown speech",not opening.audio.playing and opening.phase == OpeningSequence.Phase.PLAYABLE)
	opening.queue_free()
	await frames()
	check("opening removes owned radio and downstream buses",AudioServer.get_bus_index(opening_bus) == -1 and AudioServer.bus_count == initial_buses)
	var early_skip := preload("res://ui/cinematics/opening_sequence.tscn").instantiate() as OpeningSequence
	add_child(early_skip)
	early_skip.set_process(false)
	early_skip.start()
	early_skip.skip()
	check("skip from reality creates no Crown processing or residual interview",early_skip.crown_voice_dsp == null and not early_skip.audio.playing and not early_skip.stress_audio.playing)
	early_skip.queue_free()
	await frames()
	var floor := StaticBody3D.new()
	floor.collision_layer = CollisionLayers.WORLD
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40,0.5,40)
	collision.shape = shape
	floor.position.y = -0.25
	floor.add_child(collision)
	add_child(floor)
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector3(0,0,12)
	var encounter := DoppelgangerSpawn.new()
	encounter.setup(player)
	add_child(encounter)
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	check("production final encounter routes dry 3D Crown clip",encounter.voice_dsp == null and encounter.voice.bus == &"Master" and encounter.voice.stream.resource_path.ends_with("crown_breakdown.wav"))
	encounter.crown.call("set_emission_strength",16.5888)
	encounter._physics_process(0.0)
	check("final encounter updates actual Crown emission while keeping dry voice",encounter.voice_dsp == null and is_equal_approx((encounter.crown as CrownModel).gold.emission_energy_multiplier,16.5888))
	var audio := encounter.get_node("CombatAudio") as RealmAudioDirector
	check("final boss owns player-only combat audio with no realm ambience",audio.player == player and audio.stage == null and not audio.ambient.playing and audio.get_node_or_null("SorrowBoonAudio") != null)
	encounter.boss.set_combat_active(true)
	encounter.boss.phase = FlawlessDoppelganger.Phase.RECOVER
	encounter._unlock_player()
	player.set_physics_process(false)
	player.boons.request_equip(load("res://buffs/resources/fear/gaze_pierce.tres"))
	var effect := player.boons.effect_for(preload("res://buffs/effects/fear_effect.gd")) as FearEffect
	effect.apply_panic(encounter.boss)
	var status := effect.status_for(encounter.boss)
	var facet_normal := -status.facets[0].global_basis.z.normalized()
	player.position = encounter.boss.global_position + facet_normal*4.0
	await frames()
	var old_facet := status.facets[0]
	var hp_before := encounter.boss.health.health
	player.weapon._shoot_ray(status.facet_position(0)+facet_normal*2.0,-facet_normal)
	var legacy := 0
	for child in get_children():
		if child is FearCriticalFeedback and child.play_sound: legacy += 1
	check("real final-boss facet plays exactly one managed shatter",audio.cue_counts.get(&"fear_flaw_shatter",0)==1 and legacy==0 and encounter.boss.health.health < hp_before and encounter.boss.critical_weak_hits == 1 and status.facets[0] != old_facet)
	player.boons.equip(load("res://buffs/resources/sorrow/sorrow_gun_needles.tres"))
	var sorrow := player.boons.effect_for(preload("res://buffs/effects/sorrow_effect.gd")) as SorrowEffect
	sorrow.spawn_tear(player.global_position)
	sorrow._pickup(sorrow.tears.back())
	var tears := audio.get_node("SorrowBoonAudio") as SorrowBoonAudio
	check("final-boss real tear pickup uses cross-realm voice",tears.cue_counts.get(&"tear_return",0)==1 and tears.realm == -1)
	encounter.voice.play()
	player.health.apply_damage(99999,Hitbox.BodyPart.BODY)
	check("death stops final cinematic speech and all combat pools",not encounter.voice.playing and audio.stopped and tears.stopped and audio.voices.all(func(v):return not v.playing))
	encounter.phase = DoppelgangerSpawn.Phase.DROP
	encounter.carrier.position = Vector3(0,0.12,0)
	await frames(12)
	encounter._physics_process(0.0)
	check("real floor contact after death cannot restart Crown rant",encounter.phase == DoppelgangerSpawn.Phase.RANT and not encounter.voice.playing)
	encounter.queue_free()
	player.queue_free()
	await frames()
	await get_tree().create_timer(0.15).timeout
	check("final encounter leaves audio bus count unchanged",AudioServer.bus_count==initial_buses)
	print("CROWN AUDIO INTEGRATION: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
