extends Node
const BENCH := preload("res://tests/sloth_realm_bench.tscn")
var checks := 0
var failures := 0
var bench: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bench = BENCH.instantiate()
	add_child(bench)
	await frames(4)
	var player: Player = bench.player
	player.set_physics_process(false)
	for e in bench.enemies:
		e.set_physics_process(false)
	var laggard: SlothRealmEnemy = bench.enemies[0]
	var anchor: SlothRealmEnemy = bench.enemies[1]
	var retreater: SlothRealmEnemy = bench.enemies[2]
	check("all three actors reuse the 24-bone crystal humanoid",laggard.visual.skeleton.get_bone_count()==24 and anchor.visual.skeleton.get_bone_count()==24 and retreater.visual.skeleton.get_bone_count()==24)
	check("Laggard moves at specified 2.2m/s",is_equal_approx(laggard.run_speed,2.2))
	check("Anchor has no locomotion and an eight metre radius",is_zero_approx(anchor.run_speed) and anchor.ANCHOR_RADIUS==8)
	check("two warm Rest Zones and two suspended drive rings",bench.geometry.rest_zones.size()==2 and bench.geometry.rings.size()==2 and bench.geometry.rest_enabled)
	laggard.position = Vector3.ZERO
	player.position = Vector3(0,0,-8)
	anchor.position = Vector3(14,0,14)
	retreater.position = Vector3(-14,0,14)
	await frames(2)
	check("first delayed volley starts",laggard.start_volley())
	check("casting cannot duplicate another volley",not laggard.start_volley())
	check("formation does not damage the player",player.health.health==100)
	laggard._release_volley()
	laggard.cast_left = 0
	await frames(25)
	check("four projectiles wait visibly before any hit",projectiles().size()==4 and player.health.health==100)
	var before: Vector3 = projectiles()[0].global_position
	await frames(10)
	check("hovering projectiles retain their launch position",projectiles()[0].global_position.is_equal_approx(before))
	await frames(100)
	check("released crystals hit real player Health",player.health.health<100)
	check("each launched crystal passes through normal Projectile pipe",laggard.shots_fired==4)
	# Real cloak-free hit causes a retreat; the source is the actual Player.
	player.position = Vector3(0,0,8)
	retreater.position = Vector3.ZERO
	retreater.health.apply_damage(1,Hitbox.BodyPart.BODY,player)
	check("Retreater starts retreating after a real hit",retreater.retreat_left>1.7)
	retreater.cooldown_left = 0
	var oldpos := retreater.global_position
	retreater.set_physics_process(true)
	await frames(16)
	check("retreat is CharacterBody movement away from the player",retreater.global_position.distance_to(player.global_position)>oldpos.distance_to(player.global_position))
	check("retreat fires a homing backshot",retreater.shots_fired>0 and projectiles().any(func(p):return p.homing_target==player))
	retreater.set_physics_process(false)
	anchor.position = Vector3.ZERO
	player.position = Vector3(0,0,7.7)
	anchor.cooldown_left = 0
	await frames(2)
	anchor._update_anchor()
	check("Anchor activates inside eight metres with line of sight",anchor.anchor_active)
	if player.has_method("set_realm_effect"):
		check("real player cannot dash while anchored",not player.dash.try_dash())
	player.position = Vector3(0,0,8.3)
	anchor._update_anchor()
	check("leaving the eight metre boundary clears the field",not anchor.anchor_active)
	if player.has_method("set_realm_effect"):
		check("leaving the field restores real dash access",player.dash.try_dash())
		player.dash.cancel()
	player.position = Vector3(0,0,7.7)
	var wall := SlothRealm.box(bench,Vector3(0,1,4),Vector3(4,2,0.4),SlothRealm.material(Color.WHITE,0,1),true)
	await frames(3)
	anchor._update_anchor()
	check("solid WORLD cover blocks the gravity field",not anchor.anchor_active)
	wall.queue_free()
	await frames(3)
	anchor._update_anchor()
	check("field resumes when cover is removed",anchor.anchor_active)
	anchor.boon_time_scale = 0
	anchor.set_physics_process(true)
	await frames(2)
	check("absolute stasis releases the caster field",not anchor.anchor_active)
	anchor.boon_time_scale = 1
	anchor.set_physics_process(false)
	anchor._update_anchor()
	anchor.health.apply_damage(500,Hitbox.BodyPart.BODY,player)
	check("death cancels the gravity source immediately",not anchor.anchor_active)
	check("death produces 56 actual WORLD-colliding rigid crystals",anchor.visual.realm_shatter.pieces.size()==56 and anchor.visual.realm_shatter.pieces.all(func(p):return p is RigidBody3D and p.collision_mask==CollisionLayers.WORLD))
	var burst := anchor.visual.realm_shatter
	var elapsed := burst.elapsed
	get_tree().paused = true
	await frames(5)
	check("scene pause freezes physical shard lifetime",is_equal_approx(burst.elapsed,elapsed))
	get_tree().paused = false
	await frames(160)
	check("all crystal rigid bodies are reclaimed",not is_instance_valid(burst))
	bench.queue_free()
	await frames(5)
	OS.delay_msec(250)
	await get_tree().process_frame
	print("SLOTH REALM: %s (%d checks, %d failed)" % ["ALL PASSED" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func projectiles() -> Array[SlothRealmProjectile]:
	var list: Array[SlothRealmProjectile] = []
	for child in bench.get_children():
		if child is SlothRealmProjectile and not child.is_queued_for_deletion():
			list.append(child)
	return list

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func check(label: String,pass_value: bool) -> void:
	checks += 1
	if not pass_value:
		failures += 1
	print("%s %s" % ["PASS" if pass_value else "FAIL",label])
