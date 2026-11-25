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
	if "--free-mouse" in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	await verify_clockwork(scenery as SlothClockwork)
	await verify_worksite(room.geometry as SlothRealm, true)
	await verify_anchor_navigation(anchor)
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
	player.position = Vector3(10.2, 1.33, -3.8)
	player.aim_at(Vector3(0, 8.8, -30))
	await capture("sloth-belfry-side")
	await verify_worksite(room.geometry as SlothRealm, false)
	room.queue_free()
	await frames(4)
	load_room("res://maps/realms/sloth_boss.tscn")
	await frames(4)
	check("Boss keeps its solo encounter and receives the overhead clock",room.living_enemies() == 1 and room.boss is SlothColossus and room.geometry.has_node("SuspendedClockwork"))
	player.aim_at(Vector3(0,13,-29))
	await capture("sloth-colossus-clock")
	var boss_yard := room.geometry.get_node("ClockRepairYard") as SlothWorksite
	check("the Boss court retains its original collision layout beneath the clock",
		boss_yard.find_children("*","CollisionObject3D",true,false).is_empty())
	var clockwork := room.geometry.get_node("SuspendedClockwork") as SlothClockwork
	var angle := clockwork.minute_hand.rotation.z
	(room.geometry as SlothRealm).set_deprivation(true)
	await frames(22)
	check("deprivation sends the same physical-looking mechanism spinning", clockwork.minute_hand.rotation.z < angle - 0.42)
	room.queue_free()
	await frames(5)
	OS.delay_msec(250)
	print("SLOTH SANCTUM COMBAT: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func verify_clockwork(clockwork: SlothClockwork) -> void:
	check("the dial has the articulated hand, separate pendulum, and two meshing drive assemblies",
		is_instance_valid(clockwork.minute_hand) and is_instance_valid(clockwork.pendulum)
		and clockwork.rings.size() == 2 and clockwork.get_node("SuspendedMeridian").find_children("*","MultiMeshInstance3D",true,false).size() > 7)
	check("the distant belfries and cloud sea are carried by visual nodes",
		clockwork.get_node("BrokenBelfries").get_child_count() >= 6 and clockwork.has_node("SeaOfClouds")
		and clockwork.find_children("*","CollisionObject3D",true,false).is_empty())
	var resting_angle := clockwork.minute_hand.rotation.z
	var resting_pendulum := clockwork.pendulum.rotation.z
	await frames(103)
	var at_stop := clockwork.minute_hand.rotation.z
	check("its minute hand approaches the last notch but does not cross it",
		at_stop < resting_angle - 0.10 and at_stop >= SlothClockwork.STOP_HAND_ANGLE - 0.005)
	check("the pendulum swings through only a few degrees",
		not is_equal_approx(clockwork.pendulum.rotation.z, resting_pendulum) and absf(clockwork.pendulum.rotation.z) <= 0.044)
	get_tree().paused = true
	await frames(12)
	check("pausing holds the minute hand in place", is_equal_approx(clockwork.minute_hand.rotation.z, at_stop))
	get_tree().paused = false
	await frames(115)
	check("the hand slips back toward its original mark", absf(clockwork.minute_hand.rotation.z - resting_angle) < 0.045)


func verify_worksite(realm: SlothRealm, capture_details: bool) -> void:
	var yard := realm.get_node("ClockRepairYard") as SlothWorksite
	var physics := realm.get_world_3d().direct_space_state
	var front := yard.gear.to_global(Vector3(0.55, 1.81, 2.4))
	var back := yard.gear.to_global(Vector3(0.55, 1.81, -2.4))
	var impact := physics.intersect_ray(PhysicsRayQueryParameters3D.create(front, back, CollisionLayers.WORLD))
	check("the broken gear actually blocks gun-height WORLD rays", impact.get("collider") == yard.gear)
	var center := yard.beam.position.z
	var low_ray := PhysicsRayQueryParameters3D.create(Vector3(4.31, 0.67, center + 2.4),
		Vector3(4.31, 0.67, center - 2.1), CollisionLayers.WORLD)
	check("the lifting cradle is real waist-high cover",
		physics.intersect_ray(low_ray).get("collider") == yard.get_node("BeamRest"))
	var gate_ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1.58, 16), Vector3(0, 1.58, -20), CollisionLayers.WORLD)
	check("the middle lane still faces the exit without a WORLD blocker", physics.intersect_ray(gate_ray).is_empty())
	var nav := room._region.get_navigation_map()
	var path := NavigationServer3D.map_get_path(nav, Vector3(-8.0, 0, 2.1), Vector3(-8.0, 0, -5.5), true)
	check("enemy navigation reaches the far side of the gear", path.size() > 1 and path[-1].z < -5.0)
	var outside_ray := PhysicsRayQueryParameters3D.create(yard.broken_span.position + Vector3.UP * 4,
		yard.broken_span.position + Vector3.DOWN * 6, CollisionLayers.WORLD)
	check("the bridge ends at the existing court and the far remnant remains scenic",
		physics.intersect_ray(outside_ray).is_empty() and SlothWorksite.BRIDGE_END > -20.0)
	var guard_shape := CapsuleShape3D.new()
	guard_shape.radius = 0.50
	guard_shape.height = 1.85
	var guard_query := PhysicsShapeQueryParameters3D.new()
	guard_query.shape = guard_shape
	guard_query.collision_mask = CollisionLayers.WORLD
	var guards_clear := true
	for spawn in realm.wave_spawn_points():
		guard_query.transform = Transform3D(Basis.IDENTITY, spawn + Vector3.UP)
		for overlap in physics.intersect_shape(guard_query, 16):
			var body := overlap.collider as Node
			if yard.is_ancestor_of(body):
				guards_clear = false
	check("the actual fixtures leave all guard and reinforcement spawns clear", guards_clear)

	if capture_details:
		player.position = Vector3(0.3, 0.08, 8.55)
		player.aim_at(Vector3(0, 3.9, -12.8))
		await capture("sloth-repair-court")
		player.position = Vector3(-13.1, 1.33, yard.bridge_z + 0.48)
		player.aim_at(Vector3(-22.9, 2.18, yard.bridge_z))
		await capture("sloth-broken-bridge")
	player.set_physics_process(true)
	await _dash_past(Vector3(8.46, 0.08, center + 2.75), center - 1.7,
		"the real player dashes through the raised end of the stone beam")
	await _dash_past(Vector3(-8.31, 0.08, 0.93), -3.35,
		"the real player dashes around the outer side of the broken gear")
	player.recover_from_fall(Vector3(-14.33, 1.34, yard.bridge_z))
	player.aim_at(Vector3(-21.5, player.eye_position().y, yard.bridge_z))
	await frames(5)
	Input.action_press("move_forward")
	for tick in 106:
		await frames(1)
		if player.position.x < -18.58:
			break
	Input.action_release("move_forward")
	check("the accessible side steps connect smoothly to the terrace",
		player.position.x < -18.58 and player.position.y > 1.87)
	player.set_physics_process(false)
	player.recover_from_fall(realm.player_spawn() + Vector3.UP * 0.1)


func _dash_past(start: Vector3, target_z: float, label: String) -> void:
	player.recover_from_fall(start)
	await frames(6)
	player.aim_at(Vector3(start.x, player.eye_position().y, target_z - 3.0))
	var did_dash := player.dash.try_dash()
	await frames(15)
	check(label, did_dash and player.position.z < target_z and player.position.y >= -0.04)


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

func verify_anchor_navigation(anchor: SlothEnemy) -> void:
	var spawn := anchor.global_position
	check("the opening spawn starts outside the Anchor's casting range",
		spawn.distance_to(player.global_position) > anchor.engage_range)
	anchor.set_physics_process(true)
	for index in 240:
		await frames(1)
		if is_instance_valid(anchor.active_attack):
			break
	check("the Anchor walks into range and casts from its authored spawn",
		anchor.global_position.distance_to(spawn) > 1.0 and is_instance_valid(anchor.active_attack))
	anchor.set_physics_process(false)
	anchor._cancel_attack()

	player.position = Vector3(11.35,1.33,2.45)
	anchor.position = Vector3(17.45,0.08,2.45)
	anchor.velocity = Vector3.ZERO
	anchor.cooldown_left = 0.0
	anchor.begin_hunt()
	await frames(3)
	anchor._update_sight()
	check("the real east terrace plinth blocks the opening sight ray",not anchor._sees_target)
	var blocked := anchor.global_position
	anchor.set_physics_process(true)
	for index in 420:
		await frames(1)
		if is_instance_valid(anchor.active_attack):
			break
	check("the Anchor routes around the terrace cover and resumes its attack",
		anchor.global_position.distance_to(blocked) > 1.0 and is_instance_valid(anchor.active_attack))
	anchor.set_physics_process(false)
	anchor._cancel_attack()

func verify_anchor_and_recluse(anchor: SlothEnemy, recluse: SlothEnemy) -> void:
	anchor.position = Vector3(0,0.08,0)
	player.position = Vector3(0,0.08,5)
	await frames(2)
	check("Anchor casts a fixed 3.2m field",anchor.cast_attack())
	var field := anchor.active_attack
	var locked := field.field_center
	await frames(72)
	check("Anchor applies 25% walking slowdown and keeps its field fixed",is_equal_approx(player.stasis_multiplier(),0.75) and field.field_center == locked)
	var hud := room.hud
	check("the amber screen edge accompanies the actual movement slow",hud._stasis.visible and hud._stasis_strength > 0.0)
	player.aim_at(Vector3(0,0.36,1.0))
	await capture("sloth-stasis-feedback")
	player.position = Vector3(0,0.08,10.6)
	player.aim_at(Vector3(0,0.18,4.2))
	await frames(15)
	check("walking out of the field restores speed",is_equal_approx(player.stasis_multiplier(),1.0))
	check("the amber screen edge fades after leaving the field",not hud._stasis.visible)
	await capture("sloth-stasis-dial")
	anchor.begin_retreat(Vector3.ZERO,1.0)
	anchor.position = Vector3(17,0.08,4)
	recluse.position = Vector3(0,0.08,0)
	player.position = Vector3(0,0.08,4)
	await frames(2)
	check("Recluse opens its shell with a low-wave warning",recluse.cast_attack())
	var hp := player.health.health
	player.position.z = 6.5
	player.aim_at(Vector3(0,0.35,0.0))
	await frames(77)
	var wave := recluse.active_attack
	check("the active gold front uses the same radius and escape angle as the damage wave",
		is_instance_valid(wave) and is_equal_approx(wave._time_field._effect.get_shader_parameter("front"), wave._last_radius)
		and is_equal_approx(wave._time_field.safe_half_angle, SlothAttack.GAP_HALF_ANGLE))
	await capture("sloth-recluse-wave")
	await frames(39)
	check("the aimed 44 degree gap is safe for a standing player",is_equal_approx(player.health.health,hp))
	player.position = Vector3(0,0.08,4)
	recluse.warnings_enabled = false
	check("Recluse can make a second wave",recluse.cast_attack())
	await frames(20)
	check("losing Fear hides the charge warning",not recluse.active_attack._graphics.visible)
	player.position = Vector3(4,0.08,0)
	await frames(58)
	check("the active wave remains visible with the charge warning hidden",recluse.active_attack._graphics.visible)
	await frames(38)
	check("crossing the wave outside its gap delivers one 14 HP hit",is_equal_approx(player.health.health,hp-14.0))
	recluse.warnings_enabled = true
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
	var pool := mire._pool
	var original_spot := Vector3(0,0,5)
	check("late windup shows a harmless warning on the player's ground",
		is_instance_valid(pool) and not pool.landed and pool.global_position.distance_to(original_spot) < 0.15)
	var hp := player.health.health
	player.position = Vector3(0,0.08,9.7)
	await frames(62)
	mire.set_physics_process(false)
	check("sidestepping avoids the attack and the glue lands on the original spot",
		is_instance_valid(pool) and pool.landed and pool.global_position.distance_to(original_spot) < 0.15 and player.health.health == hp)
	if not is_instance_valid(pool) or not pool.landed:
		return
	player.aim_at(Vector3(0,0.2,4.2))
	await capture("sloth-resin-pool")
	player.position = Vector3(2.45,0.08,5)
	await frames(3)
	check("stepping in well away from the centre immediately slows walking by 35%",
		is_equal_approx(player.realm_effects.move_multiplier,0.65) and player.health.health == hp)
	var age := pool.age
	get_tree().paused = true
	await frames(8)
	check("pause freezes the pool and its damage",is_equal_approx(pool.age,age) and player.health.health == hp)
	get_tree().paused = false
	await frames(60)
	check("one full second in the glue deals 10 HP and the slow persists",
		is_equal_approx(player.health.health,hp - 10.0) and is_equal_approx(player.realm_effects.move_multiplier,0.65))
	player.position.x = 3.65
	await frames(20)
	check("leaving the pool clears the slow and stops damage",
		is_equal_approx(player.health.health,hp - 10.0) and is_equal_approx(player.realm_effects.move_multiplier,1.0))
	player.position = Vector3(0,0.9,5)
	await frames(20)
	check("jumping above the pool avoids damage and slow",
		is_equal_approx(player.health.health,hp - 10.0) and is_equal_approx(player.realm_effects.move_multiplier,1.0))
	player.position.y = 0.08
	await frames(18)
	check("stepping back in reapplies the slow and starts a new damage tick",
		is_equal_approx(player.health.health,hp - 12.5) and is_equal_approx(player.realm_effects.move_multiplier,0.65))
	await frames(130)
	check("expiry clears the pool and its slow while the player is still inside",
		not is_instance_valid(pool) and is_equal_approx(player.realm_effects.move_multiplier,1.0))

	hp = player.health.health
	var wall := SlothRealm.box(room,Vector3(0,1.7,2.65),Vector3(3.5,3.4,0.45),SlothRealm.material(Color.WHITE,0,1),true)
	await frames(2)
	mire.start_cast()
	mire._update_cast(0.85)
	var blocked := mire._pool
	mire._update_cast(1.3)
	await frames(50)
	check("solid cover stops the lob before the marked pool activates",
		not is_instance_valid(blocked) and is_equal_approx(player.health.health,hp) and is_equal_approx(player.realm_effects.move_multiplier,1.0))
	wall.queue_free()

	mire.start_cast()
	mire._update_cast(0.85)
	var interrupted := mire._pool
	mire.apply_impact(Vector3.RIGHT,3.0,0.3)
	await frames(2)
	check("a shove clears the warned footprint without releasing an extra projectile",
		not is_instance_valid(interrupted) and mire.cast_left == 0.0 and mire.shots_fired == 2)

	var shots: Array[Projectile] = []
	var record_shot := func(shot: Projectile) -> void:
		if shot.source == mire:
			shots.append(shot)
	Events.projectile_registered.connect(record_shot)
	mire.start_cast()
	mire._update_cast(0.85)
	var reflected_pool := mire._pool
	mire._update_cast(1.3)
	Events.projectile_registered.disconnect(record_shot)
	check("the throw registers one parryable projectile", shots.size() == 1)
	if shots.size() == 1:
		var shot := shots[0]
		var launch_y := shot.global_position.y
		await frames(6)
		check("the projectile rises along a lob before descending", shot.global_position.y > launch_y)
		shot.reflect(player, shot.global_position)
		await frames(2)
		check("reflecting the glob transfers ownership and removes the marked pool",
			shot.reflected and shot.source == player and not is_instance_valid(reflected_pool))
		shot.queue_free()

	# On the real east ramp, the wet surface follows the rising ground and
	# remains out of reach of feet on the floor level underneath.
	var slope_feet := ground_below(Vector3(12.4,2.0,6.0))
	var raised_feet := ground_below(Vector3(12.4,2.0,4.8))
	player.position = slope_feet
	mire.start_cast()
	mire._update_cast(0.85)
	var ramp_pool := mire._pool
	check("the footprint conforms to the ramp and does not affect the floor below",
		is_instance_valid(ramp_pool) and raised_feet.y - slope_feet.y > 0.25
			and ramp_pool._touches(raised_feet, 1.0)
			and not ramp_pool._touches(Vector3(raised_feet.x, 0.0, raised_feet.z), 1.0))
	mire.begin_retreat(Vector3.ZERO, 1.0)


func ground_below(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 3.0, CollisionLayers.WORLD)
	var hit := room.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else point
