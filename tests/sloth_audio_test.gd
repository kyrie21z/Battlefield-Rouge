extends Node
var failures := 0
var checks := 0
func check(label: String, value: bool) -> void:
	checks += 1
	if not value: failures += 1
	print("%s %s" % ["PASS" if value else "FAIL",label])
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stage := preload("res://maps/realms/sloth_boss.tscn").instantiate() as RealmStage
	add_child(stage)
	for i in 3: await get_tree().physics_frame
	stage.player.set_physics_process(false)
	for actor in stage.enemies: actor.set_physics_process(false)
	var director := stage.get_node("RealmAudio") as SlothAudioDirector
	check("production room owns injected ambience",director.player == stage.player and director.ambient.playing)
	check("pre-boss pendulum is 60 bpm",director.bpm == 60.0)
	director.set_process(false)
	director._process(1.0)
	check("clock and heartbeat layers both played",director.cue_counts.has(&"pendulum") and director.cue_counts.has(&"heartbeat"))
	for card in BoonCatalog.all():
		if card.id == "sloth_gun_pulse": stage.player.boons.request_equip(card)
	var effect := stage.player.boons.effect_for(preload("res://buffs/effects/sloth_effect.gd")) as SlothEffect
	if effect != null:
		var clock := effect.apply_latency(stage.boss,SlothEffect.GUN)
		clock.detonate()
	print("LATENCY AUDIO count=",director.cue_counts.get(&"delayed_burst",0)," effect_exists=",effect != null," has_card=",stage.player.boons.has("sloth_gun_pulse"))
	check("real latency detonation triggers delay bass",director.cue_counts.get(&"delayed_burst",0)==1)
	stage.boss.health.apply_damage(999999,Hitbox.BodyPart.BODY,stage.player)
	await get_tree().process_frame
	await get_tree().process_frame
	check("real boss death switches to 148 bpm",stage.boss_defeated and director.deprived and director.bpm==148)
	check("overclock replaces warm pad",director.ambient.stream == RealmSoundBank.get_sound(&"gears",true))
	director._process(0.35)
	check("old ambience fades out without a dangling loop",not director.ambient_tail.playing and is_equal_approx(director.ambient.volume_db,-18.0))
	stage.hud.settings.music_volume = 0.0
	stage.hud.settings.changed.emit()
	check("room music respects zero-volume setting",AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")))
	stage.hud.settings.music_volume = 0.7
	stage.hud.settings.changed.emit()
	get_tree().paused = true
	var frozen_time := director.elapsed
	for i in 3: await get_tree().process_frame
	check("paused tree freezes the audio timeline",director.elapsed == frozen_time and not director.can_process())
	var count := director.cue_counts.duplicate()
	director.play_cue(&"pendulum",Vector3.ZERO)
	check("paused presentation rejects new cue",count == director.cue_counts)
	get_tree().paused = false
	for i in 100: director.play_cue(&"delayed_burst",Vector3.ZERO)
	check("polyphony bounded at sixteen voices",director.voices.size()==16)
	var stream := RealmSoundBank.get_sound(&"warm_pad",true)
	check("loop is cached stereo PCM with finite seamless window",stream==RealmSoundBank.get_sound(&"warm_pad",true) and stream.stereo and stream.data.size()==352800 and stream.data.decode_s16(0)==0)
	stage.player.health.apply_damage(999999,Hitbox.BodyPart.BODY)
	check("real player death stops all room audio",director.stopped and not director.ambient.playing and director.voices.all(func(v):return not v.playing))
	director.set_deprived(false)
	check("late state refresh cannot restart dead-room ambience",not director.ambient.playing and not director.ambient_tail.playing)
	stage.queue_free()
	await get_tree().process_frame
	for i in 3: await get_tree().process_frame
	check("room exit frees the whole voice pool",not is_instance_valid(director))
	print("SLOTH AUDIO: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
