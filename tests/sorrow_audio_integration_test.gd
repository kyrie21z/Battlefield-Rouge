extends Node3D
var checks := 0
var failures := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
func freeze_room(room: RealmStage) -> void:
	room.player.set_physics_process(false)
	for enemy in room.enemies: enemy.set_physics_process(false)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var other := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	other.configure_run(1,[3],[],100,[])
	add_child(other)
	freeze_room(other)
	for i in 3: await get_tree().physics_frame
	var audio := other.get_node("RealmAudio") as RealmAudioDirector
	var tears := audio.get_node("SorrowBoonAudio") as SorrowBoonAudio
	check("actual Sloth room automatically owns one cross-realm tear observer",tears != null and tears.realm == 0 and audio.find_children("SorrowBoonAudio","Node",false,false).size()==1)
	other.player.boons.equip(load("res://buffs/resources/sorrow/sorrow_gun_needles.tres"))
	var effect := other.player.boons.effect_for(load("res://buffs/effects/sorrow_effect.gd")) as SorrowEffect
	effect.spawn_tear(other.player.global_position)
	effect._pickup(effect.tears.back())
	check("real tear pickup is audible outside Sorrow",tears.cue_counts.get(&"tear_return",0)==1)
	other.player.boons.dispatch(&"clock_struck",{"position":other.player.global_position})
	check("Sloth clock does not acquire a water-bell layer",tears.cue_counts.get(&"water_bell",0)==0)
	var hits := other.player.fragments.brittle_hits
	other.player.health.apply_damage(1,Hitbox.BodyPart.BODY)
	check("inherited Sorrow loss keeps one glass hit source across rooms",other.player.fragments.brittle_hits==hits+1 and other.player.fragments._glass.stream==SorrowSoundBank.get_sound(&"glass"))
	other.queue_free()
	await get_tree().process_frame
	for realm_path in ["res://maps/realms/fear_1.tscn","res://maps/realms/wrath_1.tscn"]:
		var cross_room := (load(realm_path) as PackedScene).instantiate() as RealmStage
		add_child(cross_room)
		freeze_room(cross_room)
		var cross_feedback := cross_room.get_node("RealmAudio/SorrowBoonAudio") as SorrowBoonAudio
		cross_room.player.boons.dispatch(&"sorrow_tear_collected",{"position":cross_room.player.global_position})
		check("%s installs shared tear feedback even without a specialised director" % realm_path,cross_feedback.realm == cross_room.realm and cross_feedback.cue_counts.get(&"tear_return",0)==1)
		cross_room.queue_free()
		await get_tree().process_frame
	var room := preload("res://maps/realms/sorrow_boss.tscn").instantiate() as RealmStage
	add_child(room)
	freeze_room(room)
	for i in 3: await get_tree().physics_frame
	var sound := room.get_node("RealmAudio") as SorrowAudioDirector
	check("actual Sorrow boss room has only managed rain and no legacy splash",sound.ambient.playing and room.geometry.audio_managed and not room.geometry.splash.playing)
	var monolith := room.boss as SorrowMonolith
	monolith.begin_move(SorrowMonolith.Move.TIDE)
	sound._physics_process(0.016)
	check("real tidal windup does not ring the water bell",sound.cue_counts.get(&"water_bell",0)==0 and monolith.tides_released == 0)
	monolith._physics_process(monolith.action_left+0.001)
	sound._physics_process(0.016)
	var waves := room.get_children().filter(func(c):return c is SorrowTide)
	check("real radial tide release rings one positional water bell",monolith.tides_released == 1 and waves.size() == 1 and sound.cue_counts.get(&"water_bell",0)==1)
	sound._physics_process(0.016)
	check("observing the same released tide cannot replay the bell",sound.cue_counts.get(&"water_bell",0)==1)
	monolith.begin_move(SorrowMonolith.Move.TIDE)
	room.boss.health.apply_damage(999999,Hitbox.BodyPart.BODY,room.player)
	for i in 3: await get_tree().process_frame
	check("actual boss defeat evaporates environmental rain",room.boss_defeated and sound.deprived and not sound.ambient.playing and not sound.ambient_tail.playing)
	sound._physics_process(2.0)
	check("boss death cancels pending tidal bell with no tail or catch-up",monolith.tides_released==1 and sound.cue_counts.get(&"water_bell",0)==1 and sound.voices.all(func(v):return not v.playing))
	room.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("SORROW AUDIO INTEGRATION: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
