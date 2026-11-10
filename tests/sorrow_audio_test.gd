extends Node3D
var checks := 0
var failures := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var room := preload("res://maps/realms/sorrow_1.tscn").instantiate() as RealmStage
	add_child(room)
	for enemy in room.enemies: enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var player := room.player
	player.position = Vector3(0, 0.1, 10)
	var director := room.get_node("RealmAudio") as SorrowAudioDirector
	var feedback := director.get_node("SorrowBoonAudio") as SorrowBoonAudio
	check("production stage installs exactly one director and one feedback pool", room.find_children("RealmAudio", "", false, false).size() == 1 and director.find_children("SorrowBoonAudio", "", false, false).size() == 1)
	player.boons.dispatch(&"sloth_burst", {"position": player.position})
	check("cross-realm Sloth burst retains parent audio mapping", director.cue_counts.get(&"delayed_burst",0) == 1 and director.get_sound(&"delayed_burst") == RealmSoundBank.get_sound(&"delayed_burst"))
	await frames(8)
	check("wet room owns rain loop and silences legacy splash", director.ambient.playing and director.ambient.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and room.geometry.audio_managed and not room.geometry.splash.playing)
	check("standing does not splash", director.cue_counts.get(&"water_step", 0) == 0)
	player.apply_external_impulse(Vector3.RIGHT, 4.0, 0.7)
	await frames(40)
	check("actual grounded wet movement splashes", director.cue_counts.get(&"water_step", 0) > 0)
	var count: int = director.cue_counts.get(&"water_step", 0)
	player.position = Vector3(7, 0.8, -5)
	await frames(12)
	player.apply_external_impulse(Vector3.RIGHT, 2, 0.25)
	await frames(12)
	check("high dry platform travel does not splash", director.cue_counts.get(&"water_step", 0) == count)
	player.position = Vector3(0, 0.1, 10)
	await frames(8)
	player.dash.try_dash()
	await frames(16)
	check("real dash across water produces sliding cue", director.cue_counts.get(&"water_slide", 0) > 0)
	player.set_physics_process(false)
	player.dash.set_physics_process(false)
	player.boons.set_physics_process(false)
	player.boons.equip(load("res://buffs/resources/sorrow/sorrow_blade_tide.tres"))
	var effect := player.boons.effect_for(load("res://buffs/effects/sorrow_effect.gd")) as SorrowEffect
	effect.spawn_tear(player.position + Vector3(0, 0, -3))
	var tear := effect.tears.back() as TearCrystal
	effect._pickup(tear)
	effect._pickup(tear)
	check("successful consume emits exactly one pickup cue", feedback.cue_counts.get(&"tear_return", 0) == 1)
	feedback.realm = 0
	effect.spawn_tear(player.position + Vector3(0, 0, -3))
	tear = effect.tears.back()
	effect._strike_tear(tear, {"kind": &"blade", "direction": Vector3.FORWARD})
	check("real blade tears emit spray even outside Sorrow", feedback.cue_counts.get(&"tear_spray", 0) == 1)
	player.boons.dispatch(&"clock_struck", {"position": player.position})
	check("other realm clock stays dry", feedback.cue_counts.get(&"water_bell", 0) == 0)
	feedback.realm = 3
	player.boons.dispatch(&"clock_struck", {"position": player.position})
	check("real Sorrow clock event rings water bell", feedback.cue_counts.get(&"water_bell", 0) == 1)
	var elapsed := director.elapsed
	get_tree().paused = true
	await get_tree().create_timer(0.08, true).timeout
	player.boons.dispatch(&"sorrow_tear_collected", {"position": player.position})
	check("pause freezes elapsed and rejects new cues", director.elapsed == elapsed and feedback.cue_counts.get(&"tear_return", 0) == 1)
	get_tree().paused = false
	room.geometry.set_deprivation(true)
	director.set_deprived(true)
	check("deprivation evaporates all environmental water voices", not director.ambient.playing and not director.ambient_tail.playing and director.voices.all(func(v): return not v.playing))
	player.fragments.configure_deprivation([3])
	player.health.dash_invulnerable = false
	var hits := player.fragments.brittle_hits
	for context in [{}, {"true_damage": true}, {"tag": &"melee"}]:
		player.health.apply_damage(1, Hitbox.BodyPart.BODY, null, context)
	check("every actual unbuffered HP hit uses existing single glass source", player.fragments.brittle_hits == hits + 3 and player.fragments._glass.stream == SorrowSoundBank.get_sound(&"glass"))
	for i in 30: player.boons.dispatch(&"sorrow_tear_broken", {"position": player.position})
	check("rapid tear spray is bounded", feedback.voices.size() == 8 and director.voices.size() == 16)
	player.health.apply_damage(99999, Hitbox.BodyPart.BODY)
	check("death stops all environmental and tear voices", director.stopped and feedback.stopped and feedback.voices.all(func(v): return not v.playing))
	room.free()
	await frames(3)
	print("SORROW AUDIO: %d checks, %d failed" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
