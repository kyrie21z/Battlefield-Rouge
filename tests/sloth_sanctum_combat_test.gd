extends Node
## Exercises the production rooms and actual hit/physics paths of the new encounter.
var checks := 0
var failures := 0
var output := ""
var room: RealmStage
var player: Player

func check(label: String, result: bool) -> void:
	checks += 1
	if not result:
		failures += 1
	print("%s %s" % ["PASS" if result else "FAIL",label])

func frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	var paused := get_tree().paused
	get_tree().paused = true
	await get_tree().create_timer(0.17,true,false,true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	var result := get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png"))
	check(label + " image captured",result == OK)
	get_tree().paused = paused

func load_room(path: String) -> void:
	room = load(path).instantiate() as RealmStage
	add_child(room)
	player = room.player
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	for enemy in room.enemies:
		enemy.set_physics_process(false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	load_room("res://maps/realms/sloth_1.tscn")
	await frames(40)
	var lingerer := room.enemies[0] as SlothEnemy
	var anchor := room.enemies[1] as SlothEnemy
	var recluse := room.enemies[2] as SlothEnemy
	var mire := room.enemies[-1] as SlothMire
	check("first room contains two staff bearers, one Anchor, one Recluse and one Resin Husk",
		room.enemies.size() == 5 and lingerer.kind == SlothEnemy.Kind.LINGERER and anchor.kind == SlothEnemy.Kind.ANCHOR
		and recluse.kind == SlothEnemy.Kind.RECLUSE and room.enemies[3] is SlothEnemy and mire != null)
	check("all four variants are real counted guardians",room.living_enemies() == 5)
	check("staff has an authored physical tip attached to the hand",lingerer.visual.staff_tip != null and lingerer.visual._outfit.find_child("LingererStaff",true,false) != null)
	var scenery := room.geometry.get_node("SuspendedClockwork")
	check("overhead scenery adds no physical obstacles",scenery.find_children("*","PhysicsBody3D",true,false).is_empty())
	check("the entry-to-gate distance is still 36 metres",is_equal_approx(player.position.z - room.gate.position.z,36.0))
	player.aim_at(Vector3(0,12,-26))
	await capture("sloth-clockwork")
	await verify_ramp()
	for index in room.enemies.size():
		room.enemies[index].position = Vector3(17.1,0.1,7 - index * 2.4)
	await frames(3)
	await verify_staff(lingerer)
	await verify_anchor_and_recluse(anchor,recluse)
	await verify_resin(mire)
	room.queue_free()
	await frames(4)
	load_room("res://maps/realms/sloth_2.tscn")
	await frames(5)
	check("second room has three staff bearers and seven total opponents",
		room.living_enemies() == 7 and room.enemies.filter(func(enemy: Enemy) -> bool: return enemy is SlothEnemy and enemy.kind == SlothEnemy.Kind.LINGERER).size() == 3)
	check("second room shifts both terraces",room.geometry.get_node("EastTerrace").position.z == -5.0 and room.geometry.get_node("WestTerrace").position.z == 3.0)
	room.queue_free()
	await frames(4)
	load_room("res://maps/realms/sloth_boss.tscn")
	await frames(4)
	check("Boss keeps its solo encounter and receives the overhead clock",room.living_enemies() == 1 and room.boss is SlothColossus and room.geometry.has_node("SuspendedClockwork"))
	player.aim_at(Vector3(0,13,-29))
	await capture("sloth-colossus-clock")
	room.queue_free()
	await frames(5)
	OS.delay_msec(250)
	print("SLOTH SANCTUM COMBAT: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func verify_ramp() -> void:
	player.position = Vector3(12.4,0.08,9.4)
	player.aim_at(Vector3(12.4,1.7,0))
	player.set_physics_process(true)
	await frames(3)
	Input.action_press("move_forward")
	for index in 105:
		await frames(1)
		if player.position.z < 2.5:
			break
	Input.action_release("move_forward")
	player.set_physics_process(false)
	check("real Player climbs the shallow ramp onto the 1.25m terrace",player.position.y > 1.17 and player.position.z < 3.8)
	var nav := room._region.get_navigation_map()
	var path := NavigationServer3D.map_get_path(nav,Vector3(12.4,0,9.4),Vector3(12.4,1.25,0),true)
	check("baked navigation reaches the raised terrace",path.size() >= 2 and path[-1].y > 1.1 and absf(path[-1].z) < 1.0)

func verify_staff(lingerer: SlothEnemy) -> void:
	player.position = Vector3(0,0.08,6)
	lingerer.position = Vector3(0,0.08,1)
	lingerer.look_at(Vector3(0,0.08,7))
	player.aim_at(lingerer.position + Vector3.UP*1.5)
	await frames(2)
	lingerer.cooldown_left = 0.0
	lingerer.set_physics_process(true)
	await frames(3)
	lingerer.set_physics_process(false)
	var attack := lingerer.active_attack
	check("the production Lingerer starts casting with real AI",is_instance_valid(attack))
	if not is_instance_valid(attack):
		return
	check("formation contains four crystals beside the actual staff tip",attack._orbs.size() == 4 and attack._origin.distance_to(lingerer.visual.staff_tip.global_position) < 0.2)
	var bursts := [0]
	var count_shot := func(shot: Projectile) -> void:
		if shot.source == lingerer:
			bursts[0] += 1
	Events.projectile_registered.connect(count_shot)
	await frames(64)
	await capture("sloth-staff-volley")
	await frames(33)
	check("last portion of staff windup locks the aim",attack.aim_locked and attack._released == 0)
	var heading := attack._volley_directions.duplicate()
	var hp := player.health.health
	player.position.x += 3.5
	await frames(12)
	check("side-stepping after lock does not change the four shot paths",attack._volley_directions == heading)
	await frames(52)
	Events.projectile_registered.disconnect(count_shot)
	check("one cast releases four real projectiles and dodged shots do no damage",bursts[0] == 4 and is_equal_approx(player.health.health,hp))
	lingerer.position = Vector3(17,0.08,5)

func verify_anchor_and_recluse(anchor: SlothEnemy, recluse: SlothEnemy) -> void:
	anchor.position = Vector3(0,0.08,0)
	player.position = Vector3(0,0.08,5)
	await frames(2)
	check("Anchor casts a fixed 3.2m field",anchor.cast_attack())
	var field := anchor.active_attack
	var locked := field.field_center
	await frames(62)
	check("Anchor applies 25% walking slowdown and keeps its field fixed",is_equal_approx(player.stasis_multiplier(),0.75) and field.field_center == locked)
	player.position.x = 3.7
	await frames(2)
	check("walking out of the field restores speed",is_equal_approx(player.stasis_multiplier(),1.0))
	anchor.begin_retreat(Vector3.ZERO,1.0)
	anchor.position = Vector3(17,0.08,4)
	recluse.position = Vector3(0,0.08,0)
	player.position = Vector3(0,0.08,4)
	await frames(2)
	check("Recluse opens its shell with a low-wave warning",recluse.cast_attack())
	var hp := player.health.health
	await frames(116)
	check("the aimed 44 degree gap is safe for a standing player",is_equal_approx(player.health.health,hp))
	player.position = Vector3(0,0.08,4)
	check("Recluse can make a second wave",recluse.cast_attack())
	await frames(20)
	player.position = Vector3(4,0.08,0)
	await frames(96)
	check("crossing the wave outside its gap delivers one 14 HP hit",is_equal_approx(player.health.health,hp-14.0))
	recluse.position = Vector3(17,0.08,3)

func verify_resin(mire: SlothMire) -> void:
	player.position = Vector3(0,0.08,5)
	mire.position = Vector3(0,0.08,0)
	mire.look_at(Vector3(0,0.08,6))
	player.aim_at(mire.position+Vector3.UP*1.4)
	await frames(2)
	mire.cooldown_left = 0.0
	mire.set_physics_process(true)
	await frames(3)
	check("the crooked Husk starts charging with real AI",mire.cast_left > 0.0)
	await frames(47)
	check("resin glob grows visibly during windup without inflicting damage",mire.shots_fired == 0 and mire._charging.visible)
	await capture("sloth-resin-windup")
	var hp := player.health.health
	for index in 67:
		await frames(1)
		if player.realm_effects.move_multiplier < 1.0:
			break
	check("a swept resin hit slows walking by 35% before the first tick",is_equal_approx(player.realm_effects.move_multiplier,0.65) and player.health.health == hp)
	var coating := player.get_node_or_null(SlothMire.COATING_NAME)
	var clock: float = coating.clock if coating != null else -1.0
	get_tree().paused = true
	await frames(8)
	check("pausing freezes the coating",is_instance_valid(coating) and is_equal_approx(coating.clock,clock) and player.health.health == hp)
	get_tree().paused = false
	await frames(64)
	check("four timed hits total 10 HP and remove the coating",is_equal_approx(player.health.health,hp-10.0) and is_equal_approx(player.realm_effects.move_multiplier,1.0))
	mire.set_physics_process(false)
	var wall := SlothRealm.box(room,Vector3(0,1.2,2.65),Vector3(3.5,2.4,0.45),SlothRealm.material(Color.WHITE,0,1),true)
	await frames(2)
	mire.start_cast()
	mire._update_cast(1.3)
	await frames(52)
	check("solid cover stops the glob and prevents slow and damage",is_equal_approx(player.health.health,hp-10.0) and is_equal_approx(player.realm_effects.move_multiplier,1.0))
	wall.queue_free()
	mire.start_cast()
	mire.apply_impact(Vector3.RIGHT,3.0,0.3)
	check("a shove interrupts the windup without releasing an extra projectile",mire.cast_left == 0.0 and mire.shots_fired == 2)
