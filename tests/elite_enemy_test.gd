extends Node3D
## Ticket 01 (#266): idempotent shielded elite promotion, orthogonal bonus
## tempo layers and the overhead shield-bar reveal.
## godot --headless --path . res://tests/elite_enemy_test.tscn

const ENEMY := preload("res://actors/enemy/enemy.tscn")
const PLAYER := preload("res://actors/player/player.tscn")
const CAMERA_ORIGIN := Vector3(0, 60, 0)
const HP_SCALE := 1.85
const TEMPO := 1.18
const ELITE_TEMPO := 1.10
const BOSS_TEMPO := 1.20

var checks := 0
var failures := 0
var player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	get_tree().paused = false
	print("ELITE ENEMY: %s (%d checks, %d failed)" % [
		"ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _run() -> void:
	_build_floor()
	player = PLAYER.instantiate() as Player
	add_child(player)
	player.position = Vector3(0, 0.05, -12)
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	player.health.max_health = 100000
	player.health.health = 100000
	await _frames(3)
	await _idempotent_promotion()
	await _shield_absorb_and_regen()
	await _orthogonal_tempo()
	await _halo_lifecycle()
	await _shield_bar_reveal()


func _spawn(order: String) -> Enemy:
	var enemy := ENEMY.instantiate() as Enemy
	if order == "pre_ready":
		enemy.apply_elite()
	enemy.position = Vector3(0, 0.05, -6)
	add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.set_physics_process(false)
	if order == "elite_first":
		enemy.apply_elite()
		enemy.apply_realm_scaling(HP_SCALE, 1.32, TEMPO)
	elif order == "scaling_first":
		enemy.apply_realm_scaling(HP_SCALE, 1.32, TEMPO)
		enemy.apply_elite()
	else:
		enemy.apply_realm_scaling(HP_SCALE, 1.32, TEMPO)
	return enemy


func _idempotent_promotion() -> void:
	var expected_max := 100.0 * 1.25 * HP_SCALE
	var expected_shield := roundf(expected_max * 0.65)
	for order in ["elite_first", "scaling_first", "pre_ready"]:
		var enemy := _spawn(order)
		_check(order + " folds the hp bonus into the realm-scaled maximum",
			is_equal_approx(enemy.health.max_health, expected_max)
			and is_equal_approx(enemy.health.max_health, enemy._base_max_health * enemy.realm_hp_scale)
			and is_equal_approx(enemy.health.health, expected_max))
		_check(order + " shield tracks the scaled maximum with the 5.5 s / 10% regen",
			is_equal_approx(enemy.health.max_shield, expected_shield)
			and is_equal_approx(enemy.health.shield_points, expected_shield)
			and is_equal_approx(enemy.health.shield_regeneration_delay, 5.5)
			and is_equal_approx(enemy.health.shield_regeneration_rate, expected_shield * 0.10))
		_check(order + " elite tempo joins attack and windup exactly once",
			is_equal_approx(enemy.elite_tempo_scale, ELITE_TEMPO)
			and is_equal_approx(enemy.effective_attack_scale(), TEMPO * ELITE_TEMPO)
			and is_equal_approx(enemy.effective_windup_scale(), 1.0 / (TEMPO * ELITE_TEMPO)))
		enemy.apply_elite()
		enemy.apply_elite()
		enemy.apply_realm_scaling(HP_SCALE, 1.32, TEMPO)
		_check(order + " repeated promotion and scaling never double-apply",
			is_equal_approx(enemy.health.max_health, expected_max)
			and is_equal_approx(enemy.health.max_shield, expected_shield)
			and is_equal_approx(enemy.health.shield_points, expected_shield)
			and is_equal_approx(enemy.effective_attack_scale(), TEMPO * ELITE_TEMPO))
		enemy.apply_realm_scaling(2.45, 1.50, 1.28)
		var deep_max := 125.0 * 2.45
		_check(order + " a deeper rescale keeps the elite shield proportional",
			is_equal_approx(enemy.health.max_health, deep_max)
			and is_equal_approx(enemy.health.max_shield, roundf(deep_max * 0.65))
			and is_equal_approx(enemy.health.shield_points, enemy.health.max_shield)
			and is_equal_approx(enemy.effective_attack_scale(), 1.28 * ELITE_TEMPO))
		enemy.queue_free()
		await _frames(2)


func _shield_absorb_and_regen() -> void:
	var enemy := _spawn("scaling_first")
	var health := enemy.health
	var full_hp := health.health
	health.apply_damage(100.0, Hitbox.BodyPart.BODY, player)
	_check("the crystal shield absorbs a hit without touching HP",
		is_equal_approx(health.shield_points, 50.0) and is_equal_approx(health.health, full_hp))
	health.apply_damage(80.0, Hitbox.BodyPart.BODY, player)
	_check("overflow past the broken shield removes HP",
		is_zero_approx(health.shield_points) and is_equal_approx(health.health, full_hp - 30.0))
	await _frames(320)
	_check("the shield stays empty through the 5.5 s recovery delay",
		is_zero_approx(health.shield_points))
	await _frames(30)
	_check("recovery starts at 10% of capacity per second",
		health.shield_points > 3.0 and health.shield_points < 8.0)
	await _frames(60)
	_check("one more second adds another 10% of capacity",
		health.shield_points > 18.0 and health.shield_points < 22.0)
	health.set_shield_regeneration_blocked(&"elite_test", true)
	var blocked_value := health.shield_points
	await _frames(60)
	_check("a shield-regen blocker freezes recovery",
		is_equal_approx(health.shield_points, blocked_value))
	health.set_shield_regeneration_blocked(&"elite_test", false)
	await _frames(60)
	_check("unblocking resumes recovery", health.shield_points > blocked_value + 10.0)
	var paused_value := health.shield_points
	get_tree().paused = true
	await _frames(60)
	_check("pause freezes the shield recovery clock",
		is_equal_approx(health.shield_points, paused_value))
	get_tree().paused = false
	enemy.queue_free()
	await _frames(2)


func _orthogonal_tempo() -> void:
	var enemy := _spawn("scaling_first")
	player.boons.register_enemy(enemy)
	var patrol_speed := enemy.run_speed
	_check("elite patrol speed follows realm and elite tempo at half strength",
		is_equal_approx(patrol_speed, 3.6 * (1.0 + (TEMPO * ELITE_TEMPO - 1.0) * 0.5)))
	enemy.boss_phase_tempo_scale = BOSS_TEMPO
	var combined := TEMPO * ELITE_TEMPO * BOSS_TEMPO
	_check("boss phase tempo multiplies attack and divides windup",
		is_equal_approx(enemy.effective_attack_scale(), combined)
		and is_equal_approx(enemy.effective_windup_scale(), 1.0 / combined))
	_check("the boss phase clock never touches patrol speed",
		is_equal_approx(enemy.run_speed, patrol_speed))
	player.boons.set_status(enemy, &"elite_slow", 60.0, 1.0, 1.0, false, 1.3, false, 0.6)
	_check("a boon slow composes without wiping the elite or boss layers",
		is_equal_approx(enemy.elite_tempo_scale, ELITE_TEMPO)
		and is_equal_approx(enemy.boss_phase_tempo_scale, BOSS_TEMPO)
		and is_equal_approx(enemy.effective_attack_scale(), 0.6 * combined)
		and is_equal_approx(enemy.effective_windup_scale(), 1.3 / combined))
	player.boons.clear_status(enemy, &"elite_slow")
	_check("clearing the boon restores the full bonus cadence",
		is_equal_approx(enemy.effective_attack_scale(), combined)
		and is_equal_approx(enemy.effective_windup_scale(), 1.0 / combined))
	player.boons.set_status(enemy, &"elite_block", 60.0, 1.0, 1.0, false, 1.0, true)
	_check("the boon shield-regen block reaches the elite shield",
		enemy.health.shield_regeneration_blocked)
	player.boons.clear_status(enemy, &"elite_block")
	_check("clearing the block releases the elite shield regen",
		not enemy.health.shield_regeneration_blocked)
	enemy.set_realm_tempo(1.28)
	_check("a realm tempo refresh keeps both bonus layers",
		is_equal_approx(enemy.elite_tempo_scale, ELITE_TEMPO)
		and is_equal_approx(enemy.boss_phase_tempo_scale, BOSS_TEMPO)
		and is_equal_approx(enemy.effective_attack_scale(), 1.28 * ELITE_TEMPO * BOSS_TEMPO)
		and is_equal_approx(enemy.run_speed, 3.6 * (1.0 + (1.28 * ELITE_TEMPO - 1.0) * 0.5)))
	enemy.queue_free()
	await _frames(2)


func _halo_lifecycle() -> void:
	var plain := ENEMY.instantiate() as Enemy
	plain.position = Vector3(2, 0.05, -6)
	add_child(plain)
	plain.process_mode = Node.PROCESS_MODE_PAUSABLE
	plain.set_physics_process(false)
	var collisions_before := plain.find_children("*", "CollisionObject3D", true, false).size()
	_check("a plain enemy carries no halo", plain.get_node_or_null("EliteHalo") == null)
	plain.apply_elite()
	var halo := plain.get_node_or_null("EliteHalo") as MeshInstance3D
	_check("promotion mounts a procedural crystal ring above the model",
		halo != null and halo.mesh != null and halo.position.y > plain.eye_height)
	_check("the halo adds no collision body or hitbox",
		plain.find_children("*", "CollisionObject3D", true, false).size() == collisions_before
		and halo.get_child_count() == 0
		and plain.collision_layer == CollisionLayers.ENEMIES
		and plain.collision_mask == (CollisionLayers.WORLD | CollisionLayers.ACTORS))
	var hitboxes_ok := true
	for child in plain.find_children("*", "Hitbox", true, false):
		hitboxes_ok = hitboxes_ok and (child as Hitbox).collision_layer == CollisionLayers.HITBOXES
	_check("every existing hitbox keeps its layer", hitboxes_ok)
	var start := halo.rotation.y
	await _frames(10)
	_check("the halo spins with the game clock", not is_equal_approx(halo.rotation.y, start))
	get_tree().paused = true
	var paused_rotation := halo.rotation.y
	await _frames(10)
	_check("pause freezes the halo", is_equal_approx(halo.rotation.y, paused_rotation))
	get_tree().paused = false
	plain.boon_time_scale = 0.0
	var frozen_rotation := halo.rotation.y
	await _frames(10)
	_check("a boon time stop freezes the halo", is_equal_approx(halo.rotation.y, frozen_rotation))
	plain.boon_time_scale = 1.0
	plain.health.apply_damage(plain.health.max_health * 10.0, Hitbox.BodyPart.BODY, player,
		{"true_damage": true})
	await _frames(2)
	_check("death clears the halo",
		not is_instance_valid(halo) and plain.get_node_or_null("EliteHalo") == null)
	plain.queue_free()
	var exiting := _spawn("scaling_first")
	var exiting_halo := exiting.get_node_or_null("EliteHalo") as MeshInstance3D
	exiting.queue_free()
	await _frames(2)
	_check("leaving the tree frees the halo", not is_instance_valid(exiting_halo))


func _shield_bar_reveal() -> void:
	player.global_position = CAMERA_ORIGIN - Vector3.UP * 1.5
	player.view_camera.global_transform = Transform3D(Basis.IDENTITY, CAMERA_ORIGIN)
	player.view_camera.make_current()
	var bars := EnemyHealthBars.new()
	add_child(bars)
	var elite := ENEMY.instantiate() as Enemy
	elite.position = CAMERA_ORIGIN + Vector3(4, -1.5, -24)
	add_child(elite)
	elite.process_mode = Node.PROCESS_MODE_PAUSABLE
	elite.set_physics_process(false)
	elite.apply_elite()
	var plain := ENEMY.instantiate() as Enemy
	plain.position = CAMERA_ORIGIN + Vector3(-4, -1.5, -24)
	add_child(plain)
	plain.process_mode = Node.PROCESS_MODE_PAUSABLE
	plain.set_physics_process(false)
	var tracked: Array[Enemy] = [elite, plain]
	bars.setup(player, self, tracked)
	await _settle()
	_check("full-health distant enemies stay hidden outside the aim cone",
		_bar(bars, elite).is_empty() and _bar(bars, plain).is_empty())
	elite.health.apply_damage(20.0, Hitbox.BodyPart.BODY, player)
	await _settle()
	var bar := _bar(bars, elite)
	_check("a shield-only hit reveals the elite bar at full HP",
		not bar.is_empty() and is_equal_approx(bar.health, elite.health.max_health)
		and bar.shield < bar.max_shield and is_equal_approx(bar.alpha, 1.0))
	_check("the revealed elite entry carries the elite marker flag", bar.get("elite", false))
	_check("the untouched neighbor stays hidden", _bar(bars, plain).is_empty())
	elite.health.apply_damage(30.0, Hitbox.BodyPart.BODY, player)
	bar = _bar(bars, elite)
	_check("the visible shield strip updates in the same hit callback",
		is_equal_approx(bar.shield, elite.health.shield_points)
		and is_equal_approx(bar.max_shield, elite.health.max_shield))
	plain.health.apply_damage(20.0, Hitbox.BodyPart.BODY, player)
	await _settle()
	var plain_bar := _bar(bars, plain)
	_check("a shield-only hit reveals a plain enemy without the elite flag",
		not plain_bar.is_empty() and not plain_bar.get("elite", false))
	elite.health.apply_damage(elite.health.max_health * 10.0, Hitbox.BodyPart.BODY, player,
		{"true_damage": true})
	_check("elite death removes its bar synchronously", _bar(bars, elite).is_empty())
	bars.queue_free()
	elite.queue_free()
	plain.queue_free()
	await _frames(2)


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = CollisionLayers.NONE
	body.position = Vector3(0, -0.5, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _bar(bars: EnemyHealthBars, enemy: Enemy) -> Dictionary:
	return bars.visible_entries().get(enemy.get_instance_id(), {})


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func _check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])