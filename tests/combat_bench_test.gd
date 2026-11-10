extends Node
## Exercise the real interactive bench with production Player/Weapon/Clock.
var _failed := 0
var _bench: Node3D
var _player: Player


func _ready() -> void:
	_bench = load("res://tests/combat_bench.tscn").instantiate()
	add_child(_bench)
	_player = _bench.player
	# Manual projectile probes below avoid waiting for the periodic emitter.
	_bench.set_physics_process(false)
	await _frames(4)
	await _test_pistol()
	await _test_blade()
	await _test_clock()
	await _test_clock_geometry()
	await _test_parry()
	var hand := _player.get_node("ShadowBody")
	for level in 5:
		Events.sin_defeated.emit(level)
		_check("bench body follows level %d" % level, hand.fracture_level == level)
	_player.health.apply_damage(20000, Hitbox.BodyPart.BODY)
	_check("death cancels both weapons", not _player.melee.is_swinging()
		and not _player.weapon.trigger_enabled and not _player.weapon.is_reloading()
		and not _player.melee.swing_now())
	_bench.free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	print("%s (%d failed)" % ["ALL PASSED" if _failed == 0 else "FAIL", _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _test_pistol() -> void:
	var target: CombatBenchTarget = _bench.moving_target
	var start := target.position
	await get_tree().create_timer(0.15).timeout
	_check("target rail actually moves", target.position.distance_to(start) > 0.01)
	target.set_physics_process(false)
	_player.global_position = target.global_position + Vector3(0, 0.05, 4)
	_player.velocity = Vector3.ZERO
	_player.aim_at(target.global_position + Vector3.UP)
	await _frames(3)
	var before := target.health.health
	_check("pistol fires in the production player", _player.weapon.try_fire())
	_check("bench target receives 35 hitscan damage", is_equal_approx(before - target.health.health, 35.0))
	_check("pistol consumes exactly one round", _player.weapon.ammo == 7)
	Input.action_press("aim")
	await get_tree().create_timer(0.3).timeout
	_check("player ADS converges to 58 degrees", _player.weapon.aiming
		and absf(_player.melee.camera.fov - 58.0) < 1.0)
	Input.action_release("aim")
	_player.weapon.try_reload()
	_check("manual recharge starts on partial magazine", _player.weapon.is_reloading())
	await get_tree().create_timer(0.9).timeout
	_check("reassembly refills the production magazine", _player.weapon.ammo == 8 and not _player.weapon.is_reloading())


func _test_blade() -> void:
	var target: CombatBenchTarget = _bench.melee_target
	_player.global_position = target.global_position + Vector3(0, 0.05, 4)
	_player.velocity = Vector3.ZERO
	_player.aim_at(target.global_position + Vector3.UP)
	await _frames(4)
	var start := _player.global_position
	var before := target.health.health
	_check("production blade can start while pistol held", _player.melee.swing_now())
	_check("pistol remains visible through the slash", _player.weapon._view.visible)
	await get_tree().create_timer(0.38).timeout
	var travelled := Vector2(start.x, start.z).distance_to(Vector2(_player.global_position.x, _player.global_position.z))
	_check("production lunge travels exactly 0.45m without leftover slide", absf(travelled - 0.45) < 0.02)
	_check("bench dummy receives exactly 55 blade damage", is_equal_approx(before - target.health.health, 55.0))
	_check("pistol recovers after quick slash", _player.weapon._view.visible and not _player.melee.is_swinging())


func _test_clock() -> void:
	var point: CapturePoint = _bench.clock_point
	_player.global_position = point.global_position + Vector3(0, 0.05, 3)
	_player.velocity = Vector3.ZERO
	_player.aim_at(point.global_position + Vector3.UP)
	await _frames(4)
	_check("bench clock detects real player in reach", point.player_in_reach)
	var before := point.progress
	Input.action_press("melee")
	await get_tree().process_frame
	Input.action_release("melee")
	await get_tree().create_timer(0.25).timeout
	_check("V reaches clock through blade signal", point.progress > before)
	# Force the remaining progress; capture must remove physical geometry.
	point.add_capture_progress(1.0)
	await _frames(2)
	var shape := point.get_node_or_null("Objective/Shape") as CollisionShape3D
	_check("captured clock releases its collider", shape != null and shape.disabled)
	await get_tree().create_timer(3.1).timeout
	_check("bench rebuilds a usable clock", is_instance_valid(_bench.clock_point)
		and _bench.clock_point.progress == 0.0 and not _bench.clock_point.locked)


func _test_clock_geometry() -> void:
	var point: CapturePoint = _bench.clock_point
	# Exercise the production contact resolver against Boss-sized geometry.
	# Body/Area queries still run; only the test's practice clock is resized.
	var objective := point.get_node("Objective") as StaticBody3D
	objective.position.y = 1.75
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.4, 3.5, 4.4)
	point._building.mesh = mesh
	var core_shape := BoxShape3D.new()
	core_shape.size = mesh.size
	(point.get_node("Objective/Shape") as CollisionShape3D).shape = core_shape
	var reach_shape: CylinderShape3D
	for child in point.get_children():
		if child is CollisionShape3D:
			reach_shape = child.shape as CylinderShape3D
			reach_shape.radius = 4.2
	_player.set_physics_process(false)
	_player.global_position = point.global_position + Vector3(0, 0.05, 4.35)
	_player.aim_at(point._building.global_position)
	await _frames(3)
	_check("large core Area detects player beyond centre reach", point.player_in_reach
		and _player.eye_position().distance_to(point._building.global_position) > _player.melee.strike_reach())
	point._on_swung(_player)
	_check("large core reachable face accepts blade", point.progress > 0.0)
	var before := point.progress
	_player.aim_at(_player.eye_position() + Vector3.BACK * 10.0)
	point._on_swung(_player)
	_check("back-facing blade cannot strike core", point.progress == before)
	_player.aim_at(point._building.global_position)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.2)
	collider.shape = box
	wall.add_child(collider)
	wall.position = point.global_position + Vector3(0, 1.5, 3.2)
	_bench.add_child(wall)
	await _frames(3)
	point._on_swung(_player)
	_check("solid wall blocks blade-to-clock contact", point.progress == before)
	wall.free()
	# Make the interaction area deliberately generous to isolate the blade's
	# own distance guard from the Area's independent membership guard.
	reach_shape.radius = 8.0
	_player.global_position = point.global_position + Vector3(0, 0.05, 7.0)
	_player.aim_at(point._building.global_position)
	await _frames(3)
	point._on_swung(_player)
	_check("beyond-reach surface is rejected inside an Area", point.player_in_reach and point.progress == before)
	_player.set_physics_process(true)


func _test_parry() -> void:
	var emitter: CombatBenchTarget = _bench.emitter
	_player.global_position = emitter.global_position + Vector3(0, 0.05, 6)
	_player.velocity = Vector3.ZERO
	_player.aim_at(emitter.global_position + Vector3.UP * 1.4)
	await _frames(4)
	_player.melee.set_process(false)
	_player.melee.swing_now()
	_player.melee._process(0.08)
	_bench._shot_left = 0.0
	_bench._physics_process(0.01)
	var bullet: Projectile
	for child in _bench.get_children():
		if child is Projectile:
			bullet = child
	_check("bench periodic emitter creates a slow round", bullet != null and bullet.speed == 6.0)
	if bullet == null:
		return
	bullet.set_physics_process(false)
	bullet._physics_process(0.8)
	_check("production blade reflects emitter round", bullet.reflected and bullet.source == _player)
	_check("bench records parry and asks for 50ms hitstop", _bench._parries == 1 and is_equal_approx(HitStop.last_requested, 0.05))
	var before := emitter.health.health
	bullet._physics_process(0.15)
	_check("returned round hits real bench emitter", emitter.health.health < before)
	_player.melee.cancel()
	_player.melee.set_process(true)
	await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, passed: bool) -> void:
	print("[%s] %s" % ["ok" if passed else "FAIL", label])
	if not passed:
		_failed += 1
