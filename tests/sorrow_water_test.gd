extends Node
var checks := 0
var failures := 0
var stage: RealmStage
var realm: SorrowRealm
var player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	get_tree().paused = false
	stage.queue_free()
	await frames(3)
	# Let the audio mixer release stopped playback references before quitting.
	OS.delay_msec(250)
	await get_tree().process_frame
	print("SORROW WATER: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _run() -> void:
	stage = preload("res://maps/realms/sorrow_1.tscn").instantiate() as RealmStage
	add_child(stage)
	realm = stage.geometry as SorrowRealm
	player = stage.player
	var audio := stage.get_node("RealmAudio") as SorrowAudioDirector
	var tear_audio := audio.get_node("SorrowBoonAudio") as SorrowBoonAudio
	player.health.invulnerable = true
	for actor in stage.enemies:
		actor.set_physics_process(false)
	await frames(8)
	check("tests use isolated autoload profile",MetaProgression.save_path().begins_with("user://meta_test_"))
	check("production map uses new opaque mirror shader",realm.water_material.shader.resource_path.ends_with("water_mirror.gdshader"))
	check("production rain is 750 GPU white threads",realm.rain is GPUParticles3D and realm.rain.amount == 750 and realm.rain.emitting)
	var env: Environment
	for child in realm.get_children():
		if child is WorldEnvironment: env = child.environment
	check("production realm enables SSR with 128 steps",env.ssr_enabled and env.ssr_max_steps == 128 and player.view_camera.environment == env)
	var collision_count := realm.find_children("*","CollisionShape3D",true,false).size()
	var nav := stage._region.navigation_mesh.get_vertices()
	var idle := realm.ripple_count
	await frames(15)
	check("idle feet emit no artificial actor rings",realm.ripple_count == idle)
	player.apply_external_impulse(Vector3.RIGHT,4.0,0.45)
	await frames(32)
	check("real wet movement keeps visual packets and one managed splash layer",realm.movement_ripple_count > 0 and realm.footstep_count > 0 and audio.cue_counts.get(&"water_step",0) > 0 and realm.audio_managed and not realm.splash.playing)
	var moving := realm.movement_ripple_count
	player.aim_at(player.global_position+Vector3.FORWARD*10+Vector3.UP*1.5)
	var dash_from := player.position
	check("real dash starts",player.dash.try_dash())
	var dash_distance := 0.0
	for tick in 15:
		var dashing := player.dash.is_dashing()
		await frames(1)
		if dashing:
			dash_distance = player.position.distance_to(dash_from)
	check("dash draws denser wakes with managed slide audio and unchanged distance",
		realm.movement_ripple_count > moving+3 and audio.cue_counts.get(&"water_slide",0)>0
		and not realm.splash.playing and absf(dash_distance - 5.0) < 0.1)
	check("walking can pick up the current after the dash", not player.dash.is_dashing()
		and not realm._ground_current(player.global_position).is_zero_approx())
	var actor := stage.enemies[1] as SorrowRealmEnemy
	actor.position = Vector3(0,0,-6)
	actor.set_physics_process(true)
	moving = realm.movement_ripple_count
	var origin := actor.position
	await frames(65)
	check("real enemy AI movement drives foot ripples",actor.position.distance_to(origin)>0.6 and realm.movement_ripple_count>moving)
	actor.set_physics_process(false)
	moving = realm.movement_ripple_count
	actor.health.health = 0
	await frames(5)
	check("dead and idle actors stop emitting",realm.movement_ripple_count == moving)
	actor.health.health = actor.health.max_health
	var shots := realm.shot_ripple_count
	player.aim_at(player.global_position+Vector3.FORWARD*10+Vector3.UP)
	check("real successful pistol shot",player.weapon.try_fire())
	check("successful shot displaces wet shooter water",realm.shot_ripple_count == shots+1)
	var ripples := realm.ripple_count
	check("cooldown rejects extra trigger",not player.weapon.try_fire())
	check("rejected trigger emits no extra water event",realm.ripple_count == ripples)
	# Equip production sorrow pipeline, then spawn, blade-launch and pick up
	# actual Tears; no direct add_ripple call stands in for combat integration.
	player.boons.equip(load("res://buffs/resources/sorrow/sorrow_gun_needles.tres"))
	player.boons.equip(load("res://buffs/resources/sorrow/sorrow_blade_tide.tres"))
	var effect := player.boons.effect_for(load("res://buffs/effects/sorrow_effect.gd")) as SorrowEffect
	var tears := realm.tear_ripple_count
	effect.spawn_tear(player.global_position+Vector3.FORWARD*2.0)
	await frames(3)
	check("real tear placement creates a landing ring",realm.tear_ripple_count == tears+1)
	player.aim_at(effect.tears.back().global_position)
	var sprays := int(tear_audio.cue_counts.get(&"tear_spray",0))
	var launched := [0]
	var on_shot := func(shot: Node3D):
		if shot is Projectile and shot.source == player: launched[0] += 1
	Events.projectile_registered.connect(on_shot)
	check("real blade starts",player.melee.swing_now())
	await frames(22)
	check("real blade creates owned projectiles, a water ring and one spray cue",realm.tear_ripple_count>=tears+2 and effect.tears.is_empty() and launched[0] == 3 and tear_audio.cue_counts.get(&"tear_spray",0)==sprays+1)
	Events.projectile_registered.disconnect(on_shot)
	tears = realm.tear_ripple_count
	var returns := int(tear_audio.cue_counts.get(&"tear_return",0))
	effect.spawn_tear(player.global_position)
	await frames(20)
	check("real pickup creates exactly two rings and one return cue",effect.tears.is_empty() and realm.tear_ripple_count == tears+2 and tear_audio.cue_counts.get(&"tear_return",0)==returns+1)
	player.boons.equip(load("res://buffs/resources/sorrow/sorrow_shards.tres"))
	tears = realm.tear_ripple_count
	effect.spawn_tear(player.global_position+Vector3.FORWARD*2)
	await frames(3)
	player.aim_at(effect.tears.back().global_position)
	check("real gun can fire at a tear",player.weapon.try_fire())
	await frames(5)
	check("actual gun ray consumes tear and creates its water ring",effect.tears.is_empty() and realm.tear_ripple_count == tears+2)
	# A consumed tear can be freed before the realm's next physics tick.
	tears = realm.tear_ripple_count
	effect.spawn_tear(player.global_position+Vector3.FORWARD*3)
	effect.tears.back().consume()
	await frames(2)
	check("same-frame tear consumption is observed once",realm.tear_ripple_count == tears+1)
	# Platform / airborne / remote / teleport suppression.
	player.position = Vector3(-7,0.61,6)
	await frames(5)
	ripples = realm.ripple_count
	player.apply_external_impulse(Vector3.RIGHT,2.0,0.3)
	await frames(16)
	check("dry platform motion emits no false rings",realm.ripple_count == ripples)
	player.position = Vector3(0,4,6)
	player.apply_external_impulse(Vector3.RIGHT,4,0.3)
	ripples = realm.ripple_count
	await frames(10)
	check("airborne motion emits no water rings",realm.ripple_count == ripples)
	player.position = Vector3(0,0,16)
	await frames(3)
	ripples = realm.ripple_count
	player.position = Vector3(0,0,-16)
	await frames(2)
	check("teleport does not paint a room-long wake",realm.ripple_count == ripples)
	# Pause freezes uniforms too; neither rain nor ring shaders use TIME.
	var clock := realm.clock
	get_tree().paused = true
	await frames(5)
	realm.add_ripple(Vector3.ZERO)
	check("pause freezes water and GPU rain clocks",realm.clock == clock and realm._rain_motion.get_shader_parameter("clock") == clock and realm.ripple_count == ripples)
	get_tree().paused = false
	seed(169)
	var expected := randf()
	seed(169)
	for i in 100: realm.add_ripple(Vector3(float(i%10),0,0))
	check("presentation never consumes seeded gameplay RNG",randf() == expected)
	check("event flood remains a bounded 32-entry uniform pool",realm._ripples.size() == 32 and (realm.water_material.get_shader_parameter("ripples") as PackedVector4Array).size() == 32)
	realm.set_water_level(0.9)
	check("flood updates rain impact height and water together",is_equal_approx(float(realm._rain_motion.get_shader_parameter("water_level")),0.9) and is_equal_approx(realm.water.position.y,realm.water_level))
	check("visual changes preserve collision and baked navigation",realm.find_children("*","CollisionShape3D",true,false).size() == collision_count and stage._region.navigation_mesh.get_vertices() == nav)
	realm.set_deprivation(true)
	ripples = realm.ripple_count
	realm.add_ripple(Vector3.ZERO)
	check("deprivation suppresses water, rain and new rings",not realm.water.visible and not realm.rain.visible and not realm.rain.emitting and realm.ripple_count == ripples)
	realm.set_deprivation(false)
	check("restoring water cannot resurrect old wave packets",realm._ripples[0].z < 0 and realm.rain.visible and realm.rain.emitting)
	var callbacks := Events.gunshot.get_connections().size()
	stage.remove_child(realm)
	var removed_cleanly := Events.gunshot.get_connections().size() == callbacks-1 and realm._walkers.is_empty() and realm._tears.is_empty() and audio.stopped and not audio.ambient.playing and not audio.ambient_tail.playing and audio.voices.all(func(voice):return not voice.playing)
	realm.free()
	var cues_after_removal := audio.cue_counts.duplicate()
	await frames(3)
	check("realm removal stops audio immediately and stays silent after geometry free",removed_cleanly and audio.stopped and audio.cue_counts == cues_after_removal and not audio.ambient.playing and not audio.ambient_tail.playing and audio.voices.all(func(voice):return not voice.playing))

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
