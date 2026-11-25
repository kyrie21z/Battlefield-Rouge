extends Node
var checks := 0
var failures := 0
var sections := 0
var output := ""
var stage: RealmStage
var reaper: FearReaper
var player: Player

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for index in count: await get_tree().physics_frame

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	var paused := get_tree().paused
	get_tree().paused = true
	await get_tree().create_timer(0.2,true,false,true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check("native capture "+label,get_viewport().get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
	get_tree().paused = paused

func find_reaper(room: RealmStage) -> FearReaper:
	for actor in room.enemies:
		if actor is FearReaper: return actor
	return null

func stop_wisps() -> void:
	for wisp in reaper.living_wisps(): wisp.set_physics_process(false)

func _ready() -> void:
	# the realm intro panel is a UI concern; these tests only care about the flow
	MetaProgression.introduced_realms.assign([0,1,2,3])
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	await _combat()
	await _second_room()
	check("both production room scenarios finish",sections == 2)
	get_tree().paused = false
	await frames(3)
	OS.delay_msec(250)
	print("FEAR REAPER: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _combat() -> void:
	stage = load("res://maps/realms/fear_1.tscn").instantiate() as RealmStage
	add_child(stage)
	for actor in stage.enemies: actor.set_physics_process(false)
	player = stage.player
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	reaper = find_reaper(stage)
	check("first room adds one reaper alongside all three existing enemies",stage.enemies.size() == 4 and reaper != null)
	if reaper == null: return
	check("authored torn hood and held curved scythe are real meshes",reaper.visual.scythe.find_child("CurvedScytheBlade",true,false) is MeshInstance3D and reaper.visual._outfit.find_child("HollowHood",true,false) != null)
	reaper.position = Vector3(0,0.03,9)
	player.aim_at(reaper.position+Vector3.UP*1.5)
	reaper.attack_cooldown = 0
	reaper.set_physics_process(true)
	await frames(20)
	check("real AI begins a visible summon windup without immediate ghosts",reaper.attack_elapsed > 0 and reaper.living_wisps().is_empty())
	await capture("reaper-casting")
	var progress := reaper.attack_elapsed
	get_tree().paused = true
	await frames(12)
	check("pause freezes the master cast",reaper.attack_elapsed == progress)
	get_tree().paused = false
	for tick in 100:
		await frames(1)
		if reaper.living_wisps().size() == 3: break
	reaper.set_physics_process(false)
	stop_wisps()
	check("completed cast creates three live purple flying summons",reaper.living_wisps().size() == 3)
	check("summons join boon targeting but never the room kill count",player.boons.enemies().has(reaper.living_wisps()[0]) and stage.living_enemies() == 4)
	await capture("three-wisps")
	var wisps := reaper.living_wisps()
	var shot := wisps[0]
	shot.position = Vector3(0,1.4,12)
	await frames(3)
	player.weapon.data = player.weapon.data.duplicate()
	player.weapon.data.hip_spread = 0
	player.weapon.data.ads_spread = 0
	player.aim_at(shot.position)
	var died := [0]
	shot.health.died.connect(func(_source):died[0] += 1)
	check("real pistol fires into the spirit hitbox",player.weapon.try_fire())
	check("one normal pistol shot destroys a small spirit",died[0] == 1)
	await frames(3)
	check("destroyed spirit frees itself without a room reward or blocker",not is_instance_valid(shot) and stage.living_enemies() == 4)
	var flying := reaper.living_wisps()[0]
	flying.position = Vector3(12,1.4,0)
	flying.set_physics_process(true)
	var before := flying.position
	await frames(25)
	flying.set_physics_process(false)
	check("spirit flies across the abyss at faster than player jogging speed",flying.position.distance_to(before) > 2.0 and flying.SPEED > player.jog_speed)
	# Start this close-range fixture on the entry deck, independent of campaign spawn.
	player.position = Vector3(0, 0.10, 16)
	flying.position = Vector3(0,1.4,14.4)
	flying.attack_elapsed = -1
	flying.set_physics_process(true)
	var hp := player.health.health
	await frames(18)
	check("nearby spirit stops and warns before it can hurt",flying.attack_elapsed >= 0 and flying.attack_elapsed < flying.WINDUP and player.health.health == hp)
	await capture("wisp-warning")
	progress = flying.attack_elapsed
	get_tree().paused = true
	await frames(10)
	check("pause freezes spirit windup and health",flying.attack_elapsed == progress and player.health.health == hp)
	get_tree().paused = false
	await frames(40)
	check("warned lunge deals exactly eight HP then consumes the spirit",is_equal_approx(player.health.health,hp-8) and not is_instance_valid(flying))
	await frames(25)
	check("one spirit cannot repeat contact hits",is_equal_approx(player.health.health,hp-8))
	var blocked := reaper.living_wisps()[0]
	blocked.position = Vector3(0,1.4,14.5)
	blocked.attack_elapsed = 0
	blocked.locked_direction = Vector3.BACK
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3,4,0.2)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(0,2,15.3)
	stage.add_child(wall)
	await frames(2)
	blocked.set_physics_process(true)
	hp = player.health.health
	await frames(60)
	check("WORLD cover blocks a spirit lunge and all damage",player.health.health == hp and not is_instance_valid(blocked))
	wall.queue_free()
	await frames(2)
	reaper._summon()
	stop_wisps()
	var dodged := reaper.living_wisps()[0]
	dodged.position = Vector3(0,1.4,14.4)
	dodged.set_physics_process(true)
	await frames(3)
	player.rotation.y = 0
	player._pitch = 0
	player._visual_kick = Vector2.ZERO
	player._apply_look()
	player.set_physics_process(true)
	Input.action_press("move_right")
	await frames(55)
	Input.action_release("move_right")
	player.set_physics_process(false)
	check("actual sideways walking dodges the locked short lunge",player.position.x > 2 and player.health.health == hp and not is_instance_valid(dodged))
	reaper._summon()
	stop_wisps()
	check("repeated summoning never exceeds three live spirits",reaper.living_wisps().size() == 3)
	var expired := reaper.living_wisps()[0]
	expired.elapsed = expired.LIFETIME-0.02
	expired.set_physics_process(true)
	await frames(4)
	check("unspent spirit expires instead of persisting forever",not is_instance_valid(expired))
	reaper._dismiss_wisps()
	await frames(2)
	player.position = Vector3(0,0.1,16)
	reaper.position = Vector3(0,0.02,13.7)
	reaper.velocity = Vector3.ZERO
	hp = player.health.health
	check("nearby master starts its scythe attack",reaper.start_attack() and reaper.melee)
	reaper.set_physics_process(true)
	await frames(25)
	check("scythe also leaves a readable windup",player.health.health == hp)
	await frames(35)
	reaper.set_physics_process(false)
	check("scythe delivers one actual close hit",reaper.scythe_hits == 1 and is_equal_approx(player.health.health,hp-16))
	reaper._summon()
	stop_wisps()
	var remaining := reaper.living_wisps()
	reaper.health.apply_damage(9999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	await frames(3)
	check("master death immediately clears every remaining summon",remaining.all(func(wisp):return not is_instance_valid(wisp)))
	for actor in stage.enemies:
		if not actor.health.is_dead(): actor.health.apply_damage(9999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	await frames(3)
	if stage.orb_pending():
		stage.claim_talent()
		await get_tree().process_frame
		await get_tree().process_frame
	check("normal clear still opens reward without chasing orphan summons",stage.cleared and is_instance_valid(stage.selection) and stage.living_enemies() == 0)
	get_tree().paused = false
	stage.queue_free()
	await frames(3)
	sections += 1

func _second_room() -> void:
	var room := load("res://maps/realms/fear_2.tscn").instantiate() as RealmStage
	room.difficulty_multiplier = 1.5
	room.configure_run(2,[1],[],100,[])
	add_child(room)
	for actor in room.enemies: actor.set_physics_process(false)
	var master := find_reaper(room)
	check("second room includes one reaper on the raised side route",room.enemies.size() == 5 and master != null and master.position.y > 1)
	if master != null:
		master._summon()
		check("master and summons inherit depth scaling and warning deprivation",master.health.max_health == 210 and master.living_wisps().all(func(wisp):return wisp.health.max_health == 27 and wisp.realm_damage_scale == 1.5 and not wisp.warnings_enabled))
		var owned := master.living_wisps()
		room.queue_free()
		await frames(3)
		check("leaving the room frees every owned spirit",owned.all(func(wisp):return not is_instance_valid(wisp)))
	else: room.queue_free()
	await frames(3)
	sections += 1
