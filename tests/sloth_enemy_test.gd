extends Node
## Exercises the real Sloth actors, target Health, collision queries and physics
## phases. Run with --headless --fixed-fps 60. Enemy steering is disabled so
## each test can isolate a readable attack without navigation or AI noise.

const ENEMY_SCENE := preload("res://actors/enemy/sloth/sloth_enemy.tscn")
const PLAYER_SCENE := preload("res://actors/player/player.tscn")

## Sample completed movement, after Player (priority 0) and Dash (-10).
## SceneTree.physics_frame itself fires before those nodes update.
signal step_finished(delta: float)

var _arena: Node3D
var _player: Player
var _checks := 0
var _failures := 0
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	await _run()
	get_tree().paused = false
	if is_instance_valid(_arena):
		_stop_audio(_arena)
		_arena.queue_free()
	await _frames(4)
	# Fast headless steps can finish before the audio worker releases stopped WAVs.
	OS.delay_msec(100)
	await get_tree().process_frame
	var ok := _finished and _failures == 0
	print("SLOTH ENEMIES: %s (%d checks, %d failed%s)" % [
		"ALL PASSED" if ok else "FAIL", _checks, _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _physics_process(delta: float) -> void:
	step_finished.emit(delta)


func _run() -> void:
	print("== delayed volley: warning, fixed aim and real hits")
	await _world(Vector3(0, 0, -10))
	var lingerer := _enemy(0, Vector3.ZERO)
	_check("a lingerer can start one attack", lingerer.cast_attack())
	_check("an active cast cannot be duplicated", not lingerer.cast_attack())
	var formation := lingerer.active_attack
	_check("all four suspended tells sit ahead of the chest for readability", formation._volley.all(
		func(point: Vector3) -> bool: return (point - formation._origin).dot(formation.locked_direction) > 0.44))
	var original_aim := Vector3.ZERO
	var initial_health := _player.health.health
	await _frames(42)
	_check("the warning phase cannot hurt the player", is_equal_approx(_player.health.health, initial_health))
	_check("no projectiles are launched during the warning", _projectiles().is_empty())
	_player.global_position.x = 1.0
	await _frames(56)
	original_aim = _player.global_position + Vector3.UP * Enemy.AIM_HEIGHT
	_check("the final warning locks aim after slow formation", lingerer.active_attack.aim_locked)
	_player.global_position.x = 5.0
	var fixed_directions: Array[Vector3] = []
	for origin in lingerer.active_attack._volley:
		fixed_directions.append((original_aim - origin).normalized())
	await _frames(20)
	_check("the full two-second formation completes before any shot", _projectiles().is_empty())
	await _frames(4)
	_check("only the first shot releases at the start of the burst", _projectiles().size() == 1)
	await _frames(11)
	_check("the second shot is staggered after the first", _projectiles().size() == 2)
	await _frames(11)
	_check("the third shot is staggered after the second", _projectiles().size() == 3)
	_check("the caster stays in its attack until the fourth shot", is_instance_valid(lingerer.active_attack))
	await _frames(11)
	var bullets := _projectiles()
	_check("four visible fast projectiles are released, each with nine damage", bullets.size() == 4
		and bullets.all(func(p: Projectile) -> bool: return is_equal_approx(p.speed, 40.0) and is_equal_approx(p.damage, 9.0)))
	var kept_aim := bullets.size() == 4
	for i in bullets.size():
		kept_aim = kept_aim and (-bullets[i].global_basis.z).dot(fixed_directions[i]) > 0.9999
	_check("all four shots keep their locked direction after lateral movement", kept_aim)
	await _frames(9)
	_check("a completed burst opens a recovery window", not is_instance_valid(lingerer.active_attack)
		and lingerer.cloak_recover_left > 0.0)
	_check("the next cast cannot skip the recovery window", not lingerer.cast_attack())
	await _frames(50)
	_check("a lateral dodge avoids the locked four-shot volley", is_equal_approx(_player.health.health, initial_health))
	await _world(Vector3(0, 0, -8))
	_wall(Vector3(0, 1.42, -0.22), Vector3(4.0, 2.0, 0.1))
	await _frames(2)
	lingerer = _enemy(0, Vector3.ZERO)
	lingerer.cast_attack()
	formation = lingerer.active_attack
	_check("nearby WORLD cover keeps suspended tells from appearing beyond a thin wall", formation._volley.all(
		func(point: Vector3) -> bool: return point.is_equal_approx(formation._origin)))
	await _world(Vector3(0, 0, -8))
	lingerer = _enemy(0, Vector3.ZERO)
	initial_health = _player.health.health
	lingerer.cast_attack()
	await _frames(150)
	_check("standing on the announced trajectory actually receives damage",
		_player.health.health < initial_health)

	print("== four-shot burst pause and cancellation after release")
	await _world(Vector3(5, 0, -30))
	lingerer = _enemy(0, Vector3.ZERO)
	var launched: Array[int] = []
	_arena.child_entered_tree.connect(func(node: Node) -> void:
		if node is Projectile: launched.append(node.get_instance_id()))
	lingerer.cast_attack()
	await _frames(134)
	var paused_volley := lingerer.active_attack
	_check("two projectiles are emitted before the mid-burst pause", launched.size() == 2)
	var pause_time := paused_volley.elapsed
	var pause_position := _projectiles()[0].global_position
	get_tree().paused = true
	await _frames(25)
	_check("pausing freezes the remaining shot schedule", launched.size() == 2 and paused_volley.elapsed == pause_time)
	_check("pausing also freezes already released projectiles", _projectiles()[0].global_position == pause_position)
	get_tree().paused = false
	_player.global_position.x = 12.0
	await _frames(30)
	_check("resuming releases exactly the two remaining shots", launched.size() == 4)
	for interrupted_by in ["death", "retreat"]:
		await _world(Vector3(5, 0, -30))
		lingerer = _enemy(0, Vector3.ZERO)
		var emitted: Array[int] = []
		_arena.child_entered_tree.connect(func(node: Node) -> void:
			if node is Projectile: emitted.append(node.get_instance_id()))
		lingerer.cast_attack()
		await _frames(134)
		_check("two shots precede " + interrupted_by, emitted.size() == 2)
		if interrupted_by == "death":
			lingerer.health.apply_damage(9999.0, Hitbox.BodyPart.BODY, _player)
		else:
			lingerer.begin_retreat(Vector3(30, 0, 0), 5.0)
		_player.global_position.x = 12.0
		await _frames(80)
		_check(interrupted_by + " cancels the unreleased third and fourth shots", emitted.size() == 2
			and not is_instance_valid(lingerer.active_attack))

	print("== interrupted casts and retreat")
	await _world(Vector3(0, 0, -8))
	lingerer = _enemy(0, Vector3.ZERO)
	lingerer.cast_attack()
	await _frames(25)
	lingerer.health.apply_damage(9999.0, Hitbox.BodyPart.BODY, _player)
	await _frames(140)
	_check("killing the caster cancels an unreleased volley", _projectiles().is_empty())
	lingerer = _enemy(0, Vector3(3, 0, 0))
	lingerer.cast_attack()
	await _frames(15)
	lingerer.begin_retreat(Vector3(20, 0, 0), 5.0)
	await _frames(140)
	_check("retreat cancels pending attacks without releasing bullets", _projectiles().is_empty())
	var recluse := _enemy(2, Vector3.ZERO)
	recluse.cast_attack()
	await _frames(20)
	recluse.apply_impact(Vector3.RIGHT, 2.0, 0.2)
	_check("a melee shove interrupts a winding-up recluse", not is_instance_valid(recluse.active_attack))
	initial_health = _player.health.health
	await _frames(110)
	_check("an interrupted wave causes no later damage", is_equal_approx(_player.health.health, initial_health))

	print("== anchored field: telegraph, overlap, escape and death cleanup")
	await _world(Vector3(0, 0, -8))
	var anchor := _enemy(1, Vector3.ZERO)
	anchor.cast_attack()
	var field := anchor.active_attack
	var fixed_center := field.field_center
	await _frames(38)
	_check("a field does not slow during its warning", is_equal_approx(_player.stasis_multiplier(), 1.0))
	_player.global_position.x = 6.0
	await _frames(25)
	_check("the field's announced position never follows the player", field.field_center.is_equal_approx(fixed_center))
	_check("leaving the announced zone before activation avoids the slow", is_equal_approx(_player.stasis_multiplier(), 1.0))
	_player.global_position = Vector3(fixed_center.x, 0, fixed_center.z)
	await _frames(3)
	_check("entering the active field applies a bounded 25 percent slow", is_equal_approx(_player.stasis_multiplier(), 0.75))
	var second_anchor := _enemy(1, Vector3(4, 0, 0))
	second_anchor.cast_attack()
	await _frames(61)
	_check("overlapping fields do not stack the movement penalty", is_equal_approx(_player.stasis_multiplier(), 0.75))
	anchor.health.apply_damage(9999.0, Hitbox.BodyPart.BODY, _player)
	_check("destroying one source preserves the remaining field", is_equal_approx(_player.stasis_multiplier(), 0.75))
	second_anchor.health.apply_damage(9999.0, Hitbox.BodyPart.BODY, _player)
	_check("destroying the final anchor removes the slow immediately", is_equal_approx(_player.stasis_multiplier(), 1.0))
	anchor = _enemy(1, Vector3.ZERO)
	anchor.cast_attack()
	await _frames(61)
	_check("a new field can apply after prior sources were destroyed", is_equal_approx(_player.stasis_multiplier(), 0.75))
	_player.global_position.x += 5.0
	await _frames(3)
	_check("walking out clears the slow on the next physics update", is_equal_approx(_player.stasis_multiplier(), 1.0))
	_player.global_position.x -= 5.0
	await _frames(3)
	await _frames(165)
	_check("a field expires rather than slowing indefinitely", is_equal_approx(_player.stasis_multiplier(), 1.0))

	print("== the slowing field respects solid cover")
	await _world(Vector3(0, 0, -8))
	anchor = _enemy(1, Vector3.ZERO)
	anchor.cast_attack()
	_player.global_position.x = 2.0
	_wall(Vector3(1.0, 0.9, -8.0), Vector3(0.2, 1.8, 3.0))
	await _frames(65)
	_check("a solid wall blocks the field between its center and the player", is_equal_approx(_player.stasis_multiplier(), 1.0))

	print("== field tells follow a slope and remain on their storey")
	await _world(Vector3(0, 1.0 + 0.2 / cos(0.2), -8))
	var slope := StaticBody3D.new()
	slope.collision_layer = CollisionLayers.WORLD
	slope.collision_mask = 0
	slope.position = Vector3(0, 1, -8)
	slope.rotation.z = 0.2
	var slope_shape := CollisionShape3D.new()
	var slope_box := BoxShape3D.new()
	slope_box.size = Vector3(8, 0.4, 8)
	slope_shape.shape = slope_box
	slope.add_child(slope_shape)
	_arena.add_child(slope)
	await _frames(2)
	anchor = _enemy(1, Vector3.ZERO)
	anchor.cast_attack()
	var slope_field := anchor.active_attack
	var outline := slope_field._graphics.get_child(0) as MeshInstance3D
	var vertices: PackedVector3Array = outline.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var follows_slope := true
	for vertex in vertices:
		var point := outline.global_transform * vertex
		var expected_y := 1.0 + 0.2 / cos(0.2) + tan(0.2) * point.x + 0.065
		follows_slope = follows_slope and absf(point.y - expected_y) < 0.015
	_check("a slowing field outline follows the actual sloped WORLD surface", follows_slope)
	var cached_points := slope_field._ground_heights.size()
	await _frames(70)
	_check("telegraph projection is sampled once instead of recasting every frame",
		cached_points > 0 and slope_field._ground_heights.size() == cached_points)
	await _world(Vector3(0, 5, -8))
	anchor = _enemy(1, Vector3.ZERO)
	anchor.cast_attack()
	var upper_field := anchor.active_attack
	outline = upper_field._graphics.get_child(0) as MeshInstance3D
	vertices = outline.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var stays_above := true
	for vertex in vertices:
		stays_above = stays_above and absf((outline.global_transform * vertex).y - 5.065) < 0.01
	_check("an upper-level tell does not snap to another storey five metres below", stays_above)
	_player.position.y = 0.0
	await _frames(65)
	_check("a fixed upper-level field does not slow the player on the lower storey",
		is_equal_approx(_player.stasis_multiplier(), 1.0))

	print("== active slowing fields block Shift without spending its charges")
	await _world(Vector3(0, 0, -8))
	_player.set_physics_process(true)
	await _after_steps(8)
	var baseline_dash := await _measure_dash()
	_check("the unmodified dash control starts normally", baseline_dash.started)
	_check("the unmodified dash control travels five meters (%.3f)" % baseline_dash.distance,
		absf(baseline_dash.distance - 5.0) < 0.3)
	await _world(Vector3(0, 0, -8))
	_player.set_physics_process(true)
	await _after_steps(8)
	anchor = _enemy(1, Vector3.ZERO)
	anchor.cast_attack()
	await _frames(61)
	_check("the real player is slowed before the dash", is_equal_approx(_player.stasis_multiplier(), 0.75))
	var charges := _player.dash.charges()
	Input.action_press("dash")
	await _after_steps(2)
	Input.action_release("dash")
	_check("Shift is blocked inside the active field without spending a charge",
		not _player.dash.is_dashing() and _player.dash.charges() == charges)
	anchor.boon_time_scale = 0.0
	_player.position.x += SlothAttack.FIELD_RADIUS + 0.45
	await _after_steps(2)
	_check("leaving a frozen field clears the slowdown on the next tick",
		is_equal_approx(_player.stasis_multiplier(), 1.0))
	var escaped_dash := await _measure_dash()
	_check("outside the field dash works again at its original distance",
		escaped_dash.started and absf(escaped_dash.distance - baseline_dash.distance) < 0.05)
	_player.set_physics_process(false)

	print("== recluse wave: safe opening, one hit, cover and jump")
	await _world(Vector3(0, 0, -4))
	recluse = _enemy(2, Vector3.ZERO)
	recluse.cast_attack()
	initial_health = _player.health.health
	await _frames(125)
	_check("remaining inside the announced open wedge is safe", is_equal_approx(_player.health.health, initial_health))
	await _world(Vector3(0, 0, -4))
	recluse = _enemy(2, Vector3.ZERO)
	recluse.cast_attack()
	initial_health = _player.health.health
	await _frames(30)
	_player.global_position = Vector3(4, 0, 0)
	await _frames(22)
	_check("a wave's warning deals no damage even outside its opening", is_equal_approx(_player.health.health, initial_health))
	await _frames(85)
	_check("crossing the wave receives exactly one 14-damage hit", is_equal_approx(initial_health - _player.health.health, 14.0))
	await _world(Vector3(0, 0, -4))
	recluse = _enemy(2, Vector3.ZERO)
	recluse.cast_attack()
	_player.global_position = Vector3(4, 0, 0)
	_wall(Vector3(2, 0.9, 0), Vector3(0.2, 1.8, 3))
	initial_health = _player.health.health
	await _frames(125)
	_check("solid cover blocks the wave's damage", is_equal_approx(_player.health.health, initial_health))
	await _world(Vector3(0, 0, -4))
	recluse = _enemy(2, Vector3.ZERO)
	recluse.cast_attack()
	var jump_wave := recluse.active_attack
	_player.set_physics_process(true)
	_player.global_position = Vector3(4, 0, 0)
	initial_health = _player.health.health
	await _frames(62)
	# Inject the physical binding between render frames so just_pressed survives
	# until Player's next physics update in both native and headless runs.
	await get_tree().process_frame
	_space_key(true)
	var peak_height := 0.0
	var wave_height := INF
	var wave_health := initial_health
	var wave_samples := 0
	for i in 78:
		await step_finished
		peak_height = maxf(peak_height, _player.global_position.y)
		if is_instance_valid(jump_wave):
			var wave_radius := (jump_wave.elapsed - jump_wave.warning_time()) * 9.0
			if wave_radius >= 3.55 and wave_radius <= 4.45:
				wave_samples += 1
				wave_height = minf(wave_height, _player.global_position.y)
				wave_health = minf(wave_health, _player.health.health)
		if i == 8:
			_space_key(false)
	_check("ordinary SPACE input lifts the real player over the arriving wave (peak %.3f, crossing %.3f)" % [
		peak_height, wave_height], peak_height > 0.3 and wave_samples > 0 and wave_height > 0.345)
	_check("an ordinary jump avoids the incoming wave", is_equal_approx(_player.health.health, initial_health)
		and is_equal_approx(wave_health, initial_health))
	print("  jump samples: peak=%.3f, wave crossing samples=%d, crossing health=%.1f" % [
		peak_height, wave_samples, wave_health])
	_player.set_physics_process(false)

	print("== a closed shell remains damageable; its opening rewards aimed fire")
	await _world(Vector3(0, 0, -4))
	recluse = _enemy(2, Vector3.ZERO)
	await _frames(2)
	var closed_hit := _chest_ray()
	_check("the closed shell exposes a normal body hitbox", closed_hit.get("collider") == recluse.get_node("TorsoHitbox"))
	var enemy_health := recluse.health.health
	if closed_hit.get("collider") is Hitbox:
		(closed_hit.collider as Hitbox).apply_hit(10.0, _player)
	_check("the closed shell is damageable without a special weapon", is_equal_approx(enemy_health - recluse.health.health, 10.0))
	recluse.set_physics_process(true)
	recluse.cast_attack()
	await _frames(47)
	var exposed_hit := _chest_ray()
	_check("opening the shell makes the chest core hittable", exposed_hit.get("collider") == recluse.get_node("CoreHitbox"))
	enemy_health = recluse.health.health
	if exposed_hit.get("collider") is Hitbox:
		(exposed_hit.collider as Hitbox).apply_hit(10.0, _player)
	_check("an aimed core hit rewards the player with double damage", is_equal_approx(enemy_health - recluse.health.health, 20.0))
	await _frames(175)
	_check("the exposed core closes again after the recovery window", recluse.get_node("CoreHitbox").collision_layer == 0)

	print("== pause freezes attack phases")
	await _world(Vector3(0, 0, -8))
	anchor = _enemy(1, Vector3.ZERO)
	anchor.cast_attack()
	field = anchor.active_attack
	await _frames(25)
	var before := field.elapsed
	get_tree().paused = true
	await _frames(75)
	_check("attack time remains frozen during a pause", is_equal_approx(field.elapsed, before))
	_check("a warning cannot turn into a slow while paused", is_equal_approx(_player.stasis_multiplier(), 1.0))
	get_tree().paused = false
	await _frames(40)
	_check("resuming advances the same attack into its active field", is_equal_approx(_player.stasis_multiplier(), 0.75))
	_finished = true


func _world(player_position: Vector3) -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
		await get_tree().process_frame
	_arena = Node3D.new()
	_arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_arena)
	_wall(Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = player_position
	_arena.add_child(_player)
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player.aim_at(_player.eye_position() + Vector3.FORWARD * 10.0)
	_player.health.max_health = 1000.0
	_player.health.health = 1000.0
	await _frames(2)


func _enemy(kind: int, position_value: Vector3) -> SlothEnemy:
	var actor := ENEMY_SCENE.instantiate() as SlothEnemy
	actor.kind = kind
	actor.evade_chance = 0.0
	actor.position = position_value
	_arena.add_child(actor)
	actor.set_physics_process(false)
	actor.setup(_player, [])
	return actor


func _wall(position_value: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.position = position_value
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_arena.add_child(body)


func _projectiles() -> Array[Projectile]:
	var found: Array[Projectile] = []
	for child in _arena.get_children():
		if child is Projectile and not child.is_queued_for_deletion():
			found.append(child as Projectile)
	return found


func _chest_ray() -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.33, -2),
		Vector3(0, 1.33, 0.1), CollisionLayers.HITBOXES)
	return _arena.get_world_3d().direct_space_state.intersect_ray(query)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _after_steps(count: int) -> void:
	for i in count:
		await step_finished


func _measure_dash() -> Dictionary:
	await step_finished
	var start := _player.global_position
	var started := _player.dash.try_dash()
	await _after_steps(15)
	var travelled := _player.global_position - start
	return {"started": started, "distance": Vector2(travelled.x, travelled.z).length()}


func _space_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = pressed
	Input.parse_input_event(event)


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		node.stop()
		node.stream = null


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
