extends Node3D
var checks := 0
var failed := 0
var player: Player
const ENEMY := preload("res://actors/enemy/wrath/wrath_realm_enemy.tscn")

func _ready() -> void:
	await _run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("WRATH REALM: %d checks, %d failed" % [checks, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _run() -> void:
	var ground := _wall(Vector3(0, -0.5, 0), Vector3(50, 1, 50))
	player = preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	player.position = Vector3(0, 0, -6)
	player.health.max_health = 10000
	player.health.health = 10000
	player.set_process_input(false)
	await _frames(4)
	var shield := _enemy(1, Vector3.ZERO)
	shield.rotation.y = 0
	await _frames(2)
	_check("actual shared crystalline body has 24 bones", shield.visual.skeleton.get_bone_count() == 24)
	var original := shield.health.health
	player.weapon._shoot_ray(Vector3(0, 1.1, -6), Vector3.BACK)
	_check("real frontal gun ray is blocked", is_equal_approx(shield.health.health, original) and shield.blocked_shots == 1)
	_check("blocked gun pressure is actual requested damage", shield.pressure > 30.0 and shield.pressure < 40.0)
	player.weapon._shoot_ray(Vector3(6, 1.1, 0), Vector3.LEFT)
	_check("real side gun ray penetrates shield", shield.health.health < original)
	var after_side := shield.health.health
	player.weapon._shoot_ray(Vector3(0, 1.1, 6), Vector3.FORWARD)
	_check("real rear gun ray penetrates shield", shield.health.health < after_side)
	var before_blade := shield.health.health
	(shield.get_node("TorsoHitbox") as Hitbox).apply_hit_at(10, player, Vector3(0, 1, -0.3), Vector3.BACK, false, {"kind": &"blade", "direction": Vector3.BACK})
	_check("front melee bypasses bullet-only barrier", shield.health.health < before_blade)
	for i in 3:
		player.weapon._shoot_ray(Vector3(0, 1.1, -6), Vector3.BACK)
	_check("pressure caps at 100", is_equal_approx(shield.pressure, 100.0))
	shield.setup(player, [])
	await _frames(70)
	_check("full pressure starts and releases actual wave", shield.wave_releases == 1 and is_equal_approx(shield.pressure, 0.0))
	var wave: WrathShockwave
	for child in get_children():
		if child is WrathShockwave:
			wave = child
	_check("released wave exists and advances", wave != null and wave.radius > 0)
	shield.queue_free()
	await _frames(3)
	_check("caster death/removal clears pending wave", not is_instance_valid(wave))

	var aggressor := _enemy(2, Vector3(7, 0, 0))
	await _frames(2)
	aggressor.apply_impact(Vector3.RIGHT, 50, 2)
	_check("aggressor rejects ordinary knockback and stagger", aggressor._impact_left == 0 and aggressor._impact_velocity == Vector3.ZERO)
	var previous := aggressor.health.health
	aggressor.health.apply_damage(8, Hitbox.BodyPart.BODY, player)
	_check("armor does not make aggressor immune to HP damage", aggressor.health.health == previous - 8)
	aggressor.setup(player, [])
	aggressor.boon_time_scale = 0.0
	var frozen_pos := aggressor.position
	await _frames(8)
	_check("local Sloth freeze stops Wrath actor movement", aggressor.position.is_equal_approx(frozen_pos))
	aggressor.boon_time_scale = 1.0
	aggressor.queue_free()
	await _frames(2)
	await _test_reader()

	var wall := _wall(Vector3(0, 2, -5), Vector3(12, 4, 0.4))
	player.position = Vector3(0, 0, -3)
	var piercer := _enemy(0, Vector3(0, 0, 3))
	piercer.setup(player, [])
	await _frames(2)
	_check("piercer commits to visible target with windup", piercer.attack_phase == WrathRealmEnemy.Attack.WINDUP)
	player.position = Vector3(7, 0, -2)
	await _frames(80)
	_check("real WORLD wall contact detonates once", piercer.wall_detonations == 1 and piercer.health.is_dead())
	_check("wall detonation launches eight actual ricochets", piercer.emitted_shards == 8)
	_check("swept piercer body never crosses wall", piercer.global_position.z > -4.9)
	_check("death emits all 56 original rigid crystal fragments", piercer.visual.shatter.fragments.size() == 56 and (piercer.visual.shatter.fragments[0].node is RigidBody3D))
	var fragment_material := ((piercer.visual.shatter.fragments[0].node as RigidBody3D).get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	_check("fragments retain crimson instance material", (fragment_material.get_shader_parameter("base_color") as Color).r > 0.3)
	await _frames(125)
	_check("all rigid fragments are reclaimed", not is_instance_valid(piercer.visual.shatter))

	var bullet := WrathRicochet.launch(self, Vector3(0, 1.5, -2), Vector3.FORWARD, player, 4.0, 18.0)
	await _frames(12)
	_check("crystal projectile actually reflects from WORLD", is_instance_valid(bullet) and bullet.bounce_count == 1 and (-bullet.global_basis.z).z > 0.99)
	if is_instance_valid(bullet):
		bullet.queue_free()
	player.position = Vector3(0, 0, -4.0)
	await _frames(2)
	var before_fast_bullet := player.health.health
	WrathRicochet.launch(self, Vector3(0, 1.1, -2), Vector3.FORWARD, piercer, 4.0, 240.0)
	await _frames(2)
	_check("nearer player hitbox wins over wall in same high-speed sweep", player.health.health < before_fast_bullet)
	wall.queue_free()
	piercer.queue_free()
	await _frames(2)

	var caster := _enemy(1, Vector3(0, 0, 0))
	player.position = Vector3(0, 0, 5)
	var before_wave := player.health.health
	var actual_wave := WrathShockwave.new()
	actual_wave.source = caster
	actual_wave.target = player
	add_child(actual_wave)
	await _frames(25)
	_check("expanding wave damages actual player HP", player.health.health < before_wave and actual_wave.hit_player)
	_check("wave pushes the real CharacterBody through shared impulse", player.global_position.z > 5.05)
	var once := player.health.health
	await _frames(20)
	_check("one ring cannot damage twice", player.health.health == once)
	actual_wave.queue_free()
	caster.queue_free()
	await _frames(2)
	var realm := WrathRealm.new()
	add_child(realm)
	await _frames(2)
	_check("white kiln creates ten tilted WORLD walls and eight fissures", realm.walls.size() == 12 and realm.lava.size() == 8)
	_check("eight steam vents and synthesized industrial ambience are active", realm.steam.size() == 8 and realm.ambience.playing)
	realm.set_deprivation(true)
	_check("local loss extinguishes furnace and steam", realm.deprived and realm.steam.all(func(p: CPUParticles3D): return not p.emitting) and not realm.ambience.playing)
	ground.queue_free()

func _test_reader() -> void:
	var reader := _enemy(WrathRealmEnemy.Variant.READER, Vector3.ZERO)
	player.position = Vector3(0, 0.04, -2.9)
	player.velocity = Vector3.ZERO
	reader.setup(player, [])
	await _frames(56)
	_check("an undisturbed reader keeps the paper and does not attack a nearby player",
		not reader.paper_torn and reader.attack_phase == WrathRealmEnemy.Attack.APPROACH
		and reader.position.z > -0.2 and is_equal_approx(reader.run_speed, 3.0))
	reader.health.apply_damage(0, Hitbox.BodyPart.BODY, player)
	_check("a zero-damage hit cannot tear the paper", not reader.paper_torn)
	var old_hp := reader.health.health
	player.weapon._shoot_ray(Vector3(0, 1.1, -2.7), Vector3.BACK)
	_check("the first real bullet tears the paper exactly once and doubles enraged chase speed",
		reader.paper_torn and reader.attack_phase == WrathRealmEnemy.Attack.APPROACH
		and reader.health.health == old_hp and is_equal_approx(reader.run_speed, 9.2))
	reader.health.apply_damage(5, Hitbox.BodyPart.BODY, player, {"kind": &"blade"})
	_check("even during the tear animation the next melee hit damages the reader", reader.health.health == old_hp - 5)
	var health_before := player.health.health
	reader.boon_time_scale = 0.0
	await _frames(8)
	_check("local time stop prevents the enraged reader from starting a lunge",
		reader.attack_phase == WrathRealmEnemy.Attack.APPROACH and player.health.health == health_before)
	reader.boon_time_scale = 1.0
	await _frames(2)
	_check("a visible nearby target triggers a 20 m/s lunge immediately without windup",
		reader.attack_phase == WrathRealmEnemy.Attack.RUSH
		and is_equal_approx(Vector2(reader.velocity.x, reader.velocity.z).length(), 20.0))
	var locked_aim := reader.locked_direction
	player.position.x += 2.6
	await _frames(16)
	_check("sidestepping the locked rush avoids damage and opens recovery",
		reader.locked_direction.is_equal_approx(locked_aim) and reader.attack_phase == WrathRealmEnemy.Attack.RECOVER
		and player.health.health == health_before)
	player.position = reader.position + Vector3.BACK * 2.2
	var wall := _wall(reader.position + Vector3(0, 1.0, 1.15), Vector3(4, 2.2, 0.28))
	await _frames(5)
	reader.attack_phase = WrathRealmEnemy.Attack.APPROACH
	await _frames(15)
	_check("the reader cannot start a lunge through WORLD cover", reader.attack_phase == WrathRealmEnemy.Attack.APPROACH)
	var barrier_center := wall.position
	reader.position = Vector3(barrier_center.x, 0.04, barrier_center.z - 0.49)
	player.position = Vector3(barrier_center.x, 0.04, barrier_center.z + 0.48)
	reader.attack_phase = WrathRealmEnemy.Attack.RUSH
	reader.locked_direction = Vector3.BACK
	reader.attack_left = 0.25
	await _frames(18)
	_check("an already committed punch cannot deal contact damage through a thin wall",
		reader.attack_phase == WrathRealmEnemy.Attack.RECOVER and player.health.health == health_before)
	wall.queue_free()
	await _frames(4)
	player.position = reader.position + Vector3.BACK * 2.2
	reader.realm_damage_scale = 1.5
	for i in 160:
		if player.health.health < health_before:
			break
		await _frames(1)
	_check("one lunge deals ten base melee damage with the room difficulty multiplier",
		is_equal_approx(health_before - player.health.health, 15.0))
	var hit_hp := player.health.health
	await _frames(45)
	_check("the reader cannot hit twice or repeat during its punish window",
		reader.attack_phase == WrathRealmEnemy.Attack.RECOVER and player.health.health == hit_hp)
	reader.queue_free()
	var other := _enemy(WrathRealmEnemy.Variant.READER, Vector3(8, 0, 0))
	other.health.apply_damage(22, Hitbox.BodyPart.HEAD, player, {"kind": &"blade"})
	_check("a first melee hit can also break an intact paper", other.paper_torn and other.health.health == other.health.max_health)
	other.queue_free()
	var exposed := _enemy(WrathRealmEnemy.Variant.READER, Vector3(-8, 0, 0))
	exposed.health.apply_damage(12, Hitbox.BodyPart.BODY, player, {"true_damage": true})
	_check("true damage tears the paper and retains its existing defense bypass",
		exposed.paper_torn and is_equal_approx(exposed.health.health, exposed.health.max_health - 12.0))
	exposed.queue_free()
	await _frames(3)

func _enemy(kind: int, pos: Vector3) -> WrathRealmEnemy:
	var actor := ENEMY.instantiate() as WrathRealmEnemy
	actor.variant = kind
	actor.position = pos
	add_child(actor)
	return actor

func _wall(pos: Vector3, size_value: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size_value
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.position = pos
	return body

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failed += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
