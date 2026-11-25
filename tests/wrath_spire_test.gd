extends Node3D
var checks := 0
var failed := 0
var defeats := 0
var player: Player
var boss: WrathSpire
var realm: WrathRealm

func _ready() -> void:
	await _run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("WRATH SPIRE: %d checks, %d failed" % [checks, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _run() -> void:
	realm = WrathRealm.new()
	realm.boss_arena = true
	add_child(realm)
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0, 0, 12)
	add_child(player)
	player.health.max_health = 10000
	player.health.health = 10000
	boss = preload("res://actors/boss/wrath_spire/wrath_spire.tscn").instantiate()
	boss.position = Vector3(0, 0, 0)
	boss.arena = realm
	add_child(boss)
	boss.setup(player, [])
	boss.realm_defeated.connect(func(id: int): defeats += 1 if id == 2 else 100)
	await _frames(3)
	_check("boss exposes production Enemy and Health contract", boss.is_boss and boss.health.max_health == WrathSpire.BASE_HEALTH and boss.health.max_health == 1450.0 and boss.health.team == 1)
	var visual := boss.visual as WrathSpireVisual
	_check("storm has three rotating layers of original humanoid parts", visual.storm_rings.size() == 3 and visual.storm_rings[0].get_child_count() == 8)
	var rotation_before := visual.storm_rings[0].rotation.y
	await get_tree().process_frame
	await get_tree().process_frame
	_check("crystal limbs actually rotate", visual.storm_rings[0].rotation.y != rotation_before)
	boss.attack_phase = WrathRealmEnemy.Attack.APPROACH
	boss.attack_left = 6.0
	var gap_before := boss.global_position.distance_to(player.global_position)
	await _frames(30)
	_check("approach relentlessly closes the gap instead of standing still", boss.attack_phase == WrathRealmEnemy.Attack.APPROACH and boss.global_position.distance_to(player.global_position) < gap_before - 1.0)
	boss.global_position = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	boss.attack_phase = WrathRealmEnemy.Attack.APPROACH
	boss.attack_left = 10.0
	boss.rage = 0.0
	await _frames(2)
	var wave_start := boss.spawned_waves
	boss.begin_move(WrathSpire.Move.FISSURE)
	await _frames(30)
	_check("fissure stays in telegraph before release", boss.attack_phase == WrathRealmEnemy.Attack.WINDUP and boss.spawned_waves == wave_start)
	var before_pause := boss.attack_left
	get_tree().paused = true
	for i in 4:
		await get_tree().process_frame
	_check("pause preserves attack deadline", is_equal_approx(boss.attack_left, before_pause))
	get_tree().paused = false
	var hp_before := player.health.health
	await _frames(75)
	_check("fissure releases three actual directed wave fans", boss.spawned_waves - wave_start == 3)
	_check("locked ground fan damages a grounded player", player.health.health < hp_before)
	boss.begin_move(WrathSpire.Move.SHRAPNEL)
	var start_count := boss.spawned_bullets
	await _frames(95)
	_check("two shrapnel bursts launch 24 real projectiles", boss.spawned_bullets - start_count == 24)
	var live_bullets := 0
	for node in get_children():
		if node is WrathRicochet:
			live_bullets += 1
	_check("launched ricochets remain actual moving objects", live_bullets > 0)
	boss._clear_bullets()
	await _frames(3)
	boss.global_position = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	boss.attack_phase = WrathRealmEnemy.Attack.APPROACH
	boss.attack_left = 10.0
	boss.rage = 0.0
	player.position = Vector3(0, 0, 12)
	player.health.health = player.health.max_health
	await _frames(2)
	boss.health.apply_damage(100.0, Hitbox.BodyPart.BODY, player)
	await _frames(1)
	_check("absorbing real player damage banks rage", boss.rage > 40.0 and boss.rage < 50.0)
	_check("rage and missing life spin the storm and heat its glow", visual.speed_factor > 1.5 and visual.molten > 0.2)
	var burst_start := boss.rage_bursts
	var burst_waves := boss.spawned_waves
	var burst_bullets := boss.spawned_bullets
	boss.health.apply_damage(100.0, Hitbox.BodyPart.BODY, player)
	boss.health.apply_damage(100.0, Hitbox.BodyPart.BODY, player)
	await _frames(1)
	_check("full rage primes telegraphed windup before releasing shockwave", boss.rage_bursts == burst_start and boss.rage == 0.0 and boss.attack_phase == WrathRealmEnemy.Attack.WINDUP and boss.move_kind == WrathSpire.Move.VORTEX)
	await _frames(45)
	var rage_wave: WrathShockwave
	for node in get_children():
		if node is WrathShockwave and is_equal_approx((node as WrathShockwave).max_radius, WrathSpire.RAGE_WAVE_RADIUS):
			rage_wave = node
	_check("full rage unleashes one 360-degree rage shockwave after telegraph", boss.rage_bursts == burst_start + 1 and rage_wave != null and rage_wave.half_angle >= PI)
	_check("rage shockwave uses jumpable radius and speed", rage_wave != null and is_equal_approx(rage_wave.speed, 18.0) and is_equal_approx(rage_wave.damage, 14.0 * boss.realm_damage_scale))
	_check("rage burst fires eight radial ricochets", boss.spawned_bullets - burst_bullets == 8 and boss.spawned_waves - burst_waves == 1)
	_check("rage burst launches straight into a vortex dash", boss.attack_phase == WrathRealmEnemy.Attack.RUSH and boss.move_kind == WrathSpire.Move.VORTEX)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.5)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 2, 10)
	add_child(wall)
	boss._clear_bullets()
	boss.global_position = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	boss.attack_phase = WrathRealmEnemy.Attack.APPROACH
	boss.attack_left = 10.0
	boss.rage = 0.0
	boss.wall_slams = 0
	player.position = Vector3(0, 0, 14)
	await _frames(2)
	var dash_bullets := boss.spawned_bullets
	boss.begin_move(WrathSpire.Move.VORTEX)
	_check("vortex initiates from inside its longer charge range", boss.move_kind == WrathSpire.Move.VORTEX and boss.attack_phase == WrathRealmEnemy.Attack.WINDUP)
	var dash_wait := 0
	while boss.attack_phase != WrathRealmEnemy.Attack.RUSH and dash_wait < 90:
		await get_tree().physics_frame
		dash_wait += 1
	var dash_start := boss.global_position
	await _frames(10)
	_check("vortex dash closes the gap at charge speed", boss.global_position.distance_to(dash_start) > 1.5)
	boss.boon_time_scale = 0
	var freeze_pos := boss.global_position
	var freeze_clock := boss.attack_left
	await _frames(10)
	_check("local time stop freezes boss attacks and physics", boss.global_position.is_equal_approx(freeze_pos) and boss.attack_left == freeze_clock)
	boss.boon_time_scale = 1
	var slam_wait := 0
	while boss.wall_slams == 0 and slam_wait < 90:
		await get_tree().physics_frame
		slam_wait += 1
	_check("vortex slam into a WORLD wall bursts six ricochets once", boss.wall_slams == 1 and boss.spawned_bullets - dash_bullets == 6 and boss.global_position.z > 6.0)
	wall.queue_free()
	boss._clear_bullets()
	await _frames(3)
	boss.attack_phase = WrathRealmEnemy.Attack.RECOVER
	boss.attack_left = 5.0
	boss.velocity = Vector3.ZERO
	var before_shot := boss.health.health
	var from := boss.global_position + Vector3(0, 2.0, 8)
	player.weapon._shoot_ray(from, Vector3.FORWARD)
	_check("real gun ray damages boss in punish window", boss.health.health < before_shot)
	boss.begin_move(WrathSpire.Move.SHRAPNEL)
	await _frames(70)
	boss.attack_phase = WrathRealmEnemy.Attack.APPROACH
	boss.attack_left = 10.0
	boss.rage = 0.0
	await _frames(2)
	boss.health.apply_damage(100.0, Hitbox.BodyPart.BODY, player)
	boss.health.apply_damage(100.0, Hitbox.BodyPart.BODY, player)
	boss.health.apply_damage(100.0, Hitbox.BodyPart.BODY, player)
	await _frames(45)
	_check("a live rage wave and its shrapnel exist before death", boss._owned_bullets.size() >= 8 and get_children().any(func(node: Node): return node is WrathShockwave))
	boss.health.apply_damage(5000, Hitbox.BodyPart.BODY, player, {"true_damage": true})
	_check("actual boss death emits one Wrath clear event", defeats == 1)
	_check("boss death extinguishes local furnace and ambience", realm.deprived and not realm.ambience.playing)
	_check("boss death scatters original 56 rigid crystal parts", boss.visual.shatter.fragments.size() == 56)
	await _frames(2)
	_check("boss death cancels bullets, waves and pending eruptions", boss._owned_bullets.is_empty() and not get_children().any(func(node: Node): return node is WrathRicochet or node is WrathShockwave or node is SpireEruption))
	var shot_count := boss.spawned_bullets
	var wave_count := boss.spawned_waves
	await _frames(130)
	_check("dead boss never starts later attacks", boss.spawned_bullets == shot_count and boss.spawned_waves == wave_count)
	_check("boss rigid fragments clean up after two seconds", not is_instance_valid(boss.visual.shatter))
	boss.health.apply_damage(5000, Hitbox.BodyPart.BODY, player)
	_check("duplicate damage cannot duplicate clear event", defeats == 1)
	player.fragments.configure_deprivation([2])
	var guard := preload("res://actors/enemy/wrath/wrath_realm_enemy.tscn").instantiate() as WrathRealmEnemy
	guard.variant = 2
	guard.position = Vector3(3,0,8)
	add_child(guard)
	guard.setup(player,[])
	player.boons.register_enemy(guard)
	guard.boon_time_scale = 0
	guard.apply_impact(Vector3.BACK,20,1)
	_check("post-boss ordinary force remains disabled", not guard.ordinary_impacts_enabled and guard._impact_left == 0)
	var shard := preload("res://zone/psyche_shard_pickup.tscn").instantiate() as PsycheShardPickup
	shard.realm = 2
	shard.position = player.position
	shard.setup(player)
	add_child(shard)
	await _frames(2)
	_check("physical Spite pickup activates independent shard",player.fragments.has_shard(2) and not is_instance_valid(shard))
	player.position = Vector3(5,0,8)
	player.health.apply_damage(2,Hitbox.BodyPart.BODY,guard)
	_check("Spite can move armored Wrath actor independently",guard._impact_left > 0 and not guard.ordinary_impacts_enabled)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _check(label: String, ok: bool) -> void:
	checks += 1
	failed += 0 if ok else 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
