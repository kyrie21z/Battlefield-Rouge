extends Node3D
var checks := 0
var failures := 0
var realm: FearRealm
var player: Player
var enemies: Array[FearRealmEnemy] = []

func _ready() -> void:
	await run_checks()
	get_tree().paused = false
	for child in get_children():
		_stop_audio(child)
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("FEAR REALM: %s (%d checks, %d failures)" % ["ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func run_checks() -> void:
	realm = FearRealm.new()
	add_child(realm)
	player = preload("res://actors/player/player.tscn").instantiate() as Player
	player.position = Vector3(0, 0.05, 12)
	add_child(player)
	player.set_physics_process(false)
	player.dash.set_physics_process(false)
	await frames(3)
	check("three real trap slabs and eight connected encounter platforms", realm.tiles.size() == 3 and realm.spawn_points().size() == 8)
	check("the four legacy island spawn points stay first",
		realm.spawn_points().slice(0,4) == [Vector3(-7,0,8),Vector3(7,0,8),Vector3(-7,0,-8),Vector3(7,0,-8)])
	var connected := true
	for z in range(-20, 19):
		connected = connected and ground_at(Vector3(0.7, 0, z))
	for x in range(-7, 8):
		connected = connected and ground_at(Vector3(x, 0, 8)) and ground_at(Vector3(x, 0, -8))
	check("sampled main and side routes have continuous physical support", connected)
	check("void outside narrow bridges has no invisible floor", not ground_at(Vector3(15, 0, 0)))
	var watcher := spawn_enemy(0, Vector3(0, 0.04, 4))
	var camera := player.get_node("Head/Camera3D") as Camera3D
	camera.look_at(watcher.global_position + Vector3.UP * watcher.eye_height)
	await frames(2)
	check("actual camera facing watcher counts as gaze", watcher.is_being_watched())
	check("watcher starts one cast", watcher.start_attack() and not watcher.start_attack())
	watcher.advance_attack(0.16)
	check("sustained gaze cancels charged shot before damage", watcher.gaze_interrupts == 1 and watcher.shots_fired == 0 and watcher.attack_elapsed < 0)
	camera.rotation.y = PI
	check("looking away is not eye contact", not watcher.is_being_watched())
	watcher.start_attack()
	watcher.apply_impact(Vector3.RIGHT, 0.0, 0.1)
	check("ordinary stagger cannot substitute for gaze cancellation", watcher.attack_elapsed >= 0)
	get_tree().paused = true
	watcher.advance_attack(5.0)
	check("pause freezes charged attack", is_zero_approx(watcher.attack_elapsed))
	get_tree().paused = false
	var hp_before := player.health.health
	watcher.advance_attack(1.7)
	await frames(16)
	check("uninterrupted watcher launches physical projectile that damages real player", watcher.shots_fired == 1 and player.health.health < hp_before)
	var wall := block(Vector3(0, 1.6, 8), Vector3(3, 4, 0.4))
	camera.look_at(watcher.global_position + Vector3.UP * watcher.eye_height)
	await frames(2)
	check("WORLD occlusion rejects apparent on-screen eye contact", not watcher.is_being_watched() and not watcher.has_line_of_sight())
	wall.queue_free()
	await frames(2)
	watcher.warnings_enabled = false
	camera.rotation.y = PI
	watcher.start_attack()
	watcher.advance_attack(0.2)
	check("injected warning suppression hides lock line without canceling attack", not watcher._line.visible and watcher.attack_elapsed >= 0)
	watcher._finish_attack(9)
	var trembler := spawn_enemy(1, Vector3(7, 0.02, 8))
	player.position = Vector3(7, 0.02, -7)
	await frames(2)
	var before := trembler.position
	check("blink finds solid destination and moves toward player", trembler.try_blink() and trembler.position.distance_to(before) > 3.9)
	check("blink creates frozen crystalline afterimage", trembler.visual.ghost_count == 1)
	var ghost_count := trembler.visual.ghost_count
	trembler.health.apply_damage(1, Hitbox.BodyPart.BODY, player)
	check("actual hit splits a new afterimage", trembler.visual.ghost_count == ghost_count + 1)
	wall = block(Vector3(7, 1.0, 2.2), Vector3(4, 3, 0.4))
	await frames(2)
	check("blink refuses wall crossing", not trembler.try_blink())
	wall.queue_free()
	trembler.position = Vector3(7, 0.02, 8)
	player.position = Vector3(17, 0.02, 8)
	await frames(2)
	check("blink refuses destination without ground support", not trembler.try_blink())
	var faller := spawn_enemy(2, Vector3(0, 0.02, 1.5))
	player.position = Vector3(0, 0.02, 0)
	await frames(2)
	var grounded_limbs := true
	for bone_name in ["LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
		var joint := faller.visual.skeleton.get_bone_global_pose(faller.visual.skeleton.find_bone(bone_name)).origin
		grounded_limbs = grounded_limbs and joint.y >= 0.0 and joint.y < 0.2
	check("crawler has four anatomical contact limbs beneath its horizontal torso", grounded_limbs)
	check("faller starts warned pounce", faller.start_attack())
	hp_before = player.health.health
	faller.advance_attack(0.9)
	check("pounce has real forward velocity and a single claw hit", faller.velocity.length() > 10 and player.health.health < hp_before and faller.pounce_hits == 1)
	faller.advance_attack(0.35)
	check("landing schedules nearest physical bridge trap", realm.tiles[1].elapsed >= 0)
	var tile := realm.tiles[1]
	check("trap warning leaves supporting collider intact", ground_at(Vector3(1, 0, 0)))
	await frames(70)
	check("slab physically rotates to vertical and exposes a real gap", absf(tile.rotation.z - PI * 0.5) < 0.02 and not ground_at(Vector3(1, 0, 0)))
	realm.set_deprivation(true)
	check("deprivation removes trap alarm but does not remove lethal mechanism", not tile.warnings_enabled and not tile.warning.visible and is_instance_valid(realm.abyss))
	await frames(170)
	check("bridge restores after bounded trap cycle", tile.elapsed < 0 and ground_at(Vector3(1, 0, 0)))
	watcher.health.apply_damage(9999, Hitbox.BodyPart.BODY, player)
	var burst: FearShatter
	for child in get_children():
		if child is FearShatter:
			burst = child as FearShatter
	check("death reuses exactly 56 colliding rigid crystal shards", burst != null and burst.pieces.size() == 56 and burst.pieces[0].get_child(1) is CollisionShape3D)
	check("dead caster loses every damaging hitbox and lock line", watcher.state == Enemy.State.DEAD and not watcher._line.visible and watcher.get_node("HeadHitbox").collision_layer == 0)
	realm.set_player(player)
	player.health.health = 100
	player.position = Vector3(-7,0.05,8)
	player.set_physics_process(true)
	await frames(15)
	player.set_physics_process(false)
	var fatal_hp := player.health.health
	player.health.invulnerable = true
	player.health.dash_invulnerable = true
	player.health.grant_shield(500)
	player.position = Vector3(130, -14, 0)
	await frames(3)
	check("abyss costs thirty HP and returns player despite dash, immunity and shield", fatal_hp > 30 and is_equal_approx(player.health.health,fatal_hp-30) and player.position.y > -1 and player.health.last_damage_context.get("environmental_penalty",false))
	check("fall recovery returns to the last visited stable side platform",Vector2(player.position.x+7,player.position.z-8).length() < 0.5)
	await frames(30)
	wall = block(Vector3(-7,1,8),Vector3(2,2,2))
	await frames(2)
	player.position = Vector3(130,-14,0)
	await frames(3)
	check("an obstructed old landing safely falls back to the entry platform",Vector2(player.position.x,player.position.z-16).length() < 0.5 and is_equal_approx(player.health.health,fatal_hp-60))
	wall.queue_free()
	await frames(30)
	player.health.health = 20
	player.position = Vector3(0,-14,0)
	await frames(3)
	check("a fall is lethal only when remaining HP cannot cover its cost",player.health.is_dead())
	await frames(150)
	check("all rigid shards are reclaimed after their lifetime", not is_instance_valid(burst))

func spawn_enemy(kind: int, point: Vector3) -> FearRealmEnemy:
	var enemy := preload("res://actors/enemy/fear/fear_realm_enemy.tscn").instantiate() as FearRealmEnemy
	enemy.variant = kind
	enemy.position = point
	enemy.arena = realm
	add_child(enemy)
	enemy.setup(player, [])
	enemy.set_physics_process(false)
	enemies.append(enemy)
	player.boons.register_enemy(enemy)
	return enemy

func ground_at(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.0, point - Vector3.UP * 0.7, CollisionLayers.WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func block(point: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = point
	body.collision_layer = CollisionLayers.WORLD
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
