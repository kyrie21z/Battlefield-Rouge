extends Node
## Behavioral coverage of the one-blade contract, including swept parries.

class Dummy extends CharacterBody3D:
	var team := 1
	var impact_count := 0
	var last_force := 0.0
	func apply_impact(_direction: Vector3, force: float, _stagger: float) -> void:
		impact_count += 1
		last_force = force

var _failed := 0
var _world: Node3D
var _shooter: Dummy
var _blade: MeleeWeapon
var _lunges: Array[float] = []
var _strikes := 0


func _ready() -> void:
	_world = Node3D.new()
	add_child(_world)
	_shooter = _dummy(Vector3.ZERO, 0)
	var camera := Camera3D.new()
	_shooter.add_child(camera)
	camera.current = true
	_blade = MeleeWeapon.new()
	_blade.blade_data = preload("res://weapons/mind_blade/mind_blade.tres")
	_blade.camera = camera
	_blade.shooter = _shooter
	camera.add_child(_blade)
	_blade.set_process(false)
	_blade.lunge.connect(func(_d: Vector3, speed: float, duration: float): _lunges.append(speed * duration))
	_blade.struck.connect(func(): _strikes += 1)
	await _settle()
	await _test_slash()
	await _test_parry()
	await _test_obstruction_and_pause()
	_test_grip_trajectory()
	await _test_player_integration()
	_blade.cancel()
	_check("cancel returns idle and hides view", not _blade.is_swinging() and not _blade.view_visible())
	_blade.deactivate()
	_check("deactivated blade rejects public swing", not _blade.swing_now())
	_world.free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	print("%s (%d failed)" % ["ALL PASSED" if _failed == 0 else "FAIL", _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _test_player_integration() -> void:
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	player.position = Vector3(20, 3, 0)
	player.gravity = 0.0
	_world.add_child(player)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	var enemy := _dummy(player.position + Vector3(0, 1.6, -4), 1)
	await _settle()
	_check("real Player equips only MindBlade", player.melee.weapons.size() == 1
		and player.melee.current().resource_path.ends_with("mind_blade.tres"))
	_check("Q no longer switches the blade", not InputMap.has_action("switch_melee"))
	var inputs := InputMap.action_get_events("melee")
	_check("V and side mouse button both bind melee", inputs.size() == 2
		and (inputs[0] as InputEventKey).physical_keycode == KEY_V
		and (inputs[1] as InputEventMouseButton).button_index == MOUSE_BUTTON_XBUTTON1)
	var start := player.global_position
	player.melee.swing_now()
	_check("pistol stays visible during blade wind-up", player.weapon._view.visible)
	for i in 12:
		await get_tree().physics_frame
	var step := Vector2(player.position.x - start.x, player.position.z - start.z).length()
	_check("real Player lunge stops at exactly 0.45m", absf(step - 0.45) < 0.002
		and Vector2(player.velocity.x, player.velocity.z).length() < 0.001)
	player.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	_check("player death cancels and disables the blade", not player.melee.is_swinging()
		and not player.melee.swing_now() and not player.melee.view_visible())
	player.free()
	enemy.free()


func _test_slash() -> void:
	var target := _dummy(Vector3(0, 0, -4), 1)
	await _settle()
	_check("V starts the single blade", _blade.swing_now())
	_check("one 0.45m lunge for a target at four metres", _lunges.size() == 1 and is_equal_approx(_lunges[0], 0.45))
	_check("wind-up cannot damage yet", _health(target).health == 100.0)
	_check("input cannot restart a committed swing", not _blade.swing_now())
	_blade._process(0.08)
	_check("wind-up ends at 80ms", _blade._phase == MeleeWeapon.Phase.ACTIVE)
	_blade._process(0.10)
	_check("active slash lands exactly 55 damage", is_equal_approx(_health(target).health, 45.0))
	_check("slash supplies knockback and stagger", target.impact_count == 1 and target.last_force > 0.0)
	_blade._process(0.021)
	_check("end sample never double-damages", is_equal_approx(_health(target).health, 45.0))
	_check("one clock strike per slash", _strikes == 1)
	_blade._process(0.15)
	_check("recovery returns to idle", not _blade.is_swinging() and not _blade.view_visible())
	target.free()
	var outside := _dummy(Vector3(5, 0, -1), 1)
	await _settle()
	_blade.swing_now()
	_check("outside the front cone cannot pull player", _lunges.size() == 1)
	_blade._process(0.08)
	_blade._process(0.12)
	_check("outside arc is unharmed", _health(outside).health == 100.0)
	_blade.cancel()
	outside.free()
	_blade.swing_now()
	_blade._process(0.35)
	_check("one slow frame preserves 350ms cycle", not _blade.is_swinging())
	var view := _blade.get_node("Pivot").get_child(0) as Node3D
	var triangles := 0
	var bounds := AABB()
	var first := true
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		triangles += part.mesh.get_faces().size() / 3
		var transform: Transform3D = view.global_transform.affine_inverse() * part.global_transform
		var local_bounds: AABB = transform * part.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/epic1_models/manifest.json"))
	var model: Dictionary = manifest.models[1]
	_check("actual blade triangles match Blender receipt (%d)" % triangles, triangles > 0 and triangles == int(model.glb_triangles))
	_check("blade source records only flat triangles/quads", model.objects.values().all(
		func(part: Dictionary) -> bool: return part.flat_faces and part.triangles_authored + part.quads_authored == part.polygons))
	_check("blade receipt hash matches actual GLB", FileAccess.get_sha256("res://assets/models/weapons/mind_blade.glb") == model.sha256)
	_check("blade is exactly 40mm wide and 15mm thick", absf(bounds.size.y - .040) < .0001 and absf(bounds.size.x - .015) < .0001)
	_check("imported blade uses flat face normals", _flat_normals(view))
	_check("blade overall length is 40cm", absf(bounds.size.z - 0.4) < 0.001)
	_check("swing tip matches imported blade geometry", absf(-bounds.position.z - _blade.blade_length()) < 0.001)


func _test_parry() -> void:
	var enemy := _dummy(Vector3(0, 0, -5), 1)
	await _settle()
	_blade.swing_now()
	_blade._process(0.08)
	var bullet := Projectile.spawn(_world, Vector3(0, 0, -3), Vector3.BACK, enemy, 10.0, 30.0, [enemy.get_rid()])
	bullet.set_physics_process(false)
	bullet._physics_process(0.1)
	_check("sweep catches bullet crossing whole parry sphere", bullet.reflected)
	_check("reflection changes ownership and clears enemy exclusions", bullet.source == _shooter
		and not bullet.exclude.has(enemy.get_rid()) and bullet.exclude.has(_shooter.get_rid()))
	_check("reflected bullet flies back faster", bullet.speed >= 60.0 and (-bullet.global_basis.z).z < -0.99)
	bullet._physics_process(0.1)
	_check("returned projectile damages its original enemy", _health(enemy).health < 100.0)
	await get_tree().process_frame
	_blade.cancel()
	var late := Projectile.spawn(_world, Vector3(0, 0, -3), Vector3.BACK, enemy, 10.0, 30.0, [])
	late.set_physics_process(false)
	late._physics_process(0.1)
	_check("idle blade does not parry", not late.reflected)
	_check("idle bullet reaches the player", _health(_shooter).health == 90.0)
	await get_tree().process_frame
	_blade.swing_now()
	_blade._process(0.08)
	var rear := Projectile.spawn(_world, Vector3(0, 0, 3), Vector3.FORWARD, enemy, 10.0, 30.0, [])
	rear.set_physics_process(false)
	rear._physics_process(0.1)
	_check("active blade cannot parry behind player", not rear.reflected)
	await get_tree().process_frame
	enemy.free()


func _test_obstruction_and_pause() -> void:
	_blade.cancel()
	var enemy := _dummy(Vector3(0, 0, -4), 1)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 0.15)
	shape.shape = box
	wall.add_child(shape)
	wall.position.z = -1.2
	_world.add_child(wall)
	await _settle()
	var lunge_count := _lunges.size()
	_blade.swing_now()
	_check("wall prevents magnet acquisition", _lunges.size() == lunge_count)
	_blade._process(0.08)
	var health_before := _health(_shooter).health
	var bullet := Projectile.spawn(_world, Vector3(0, 0, -3), Vector3.BACK, enemy, 10.0, 30.0, [])
	bullet.set_physics_process(false)
	bullet._physics_process(0.1)
	_check("wall prevents parry through cover", not bullet.reflected)
	_blade._process(0.12)
	_check("wall also blocks slash", _health(enemy).health == 100.0)
	_check("wall still stops the unreflected bullet", _health(_shooter).health == health_before)
	await get_tree().process_frame
	wall.free()
	_blade.cancel()
	await _settle()
	_blade.swing_now()
	_blade._process(0.08)
	bullet = Projectile.spawn(_world, Vector3(0, 0, -3), Vector3.BACK, enemy, 10.0, 30.0, [])
	_blade.set_process(true)
	var phase_left := _blade._phase_left
	var bullet_position := bullet.position
	get_tree().paused = true
	_check("paused blade rejects public swing", not _blade.swing_now())
	await get_tree().create_timer(0.05, true).timeout
	_check("pause freezes blade window and projectile", _blade._phase_left == phase_left and bullet.position == bullet_position)
	_blade.set_process(false)
	bullet.set_physics_process(false)
	get_tree().paused = false
	_blade.cancel()
	bullet._physics_process(0.1)
	_check("death/cancel immediately removes parry window", not bullet.reflected)
	await get_tree().process_frame
	enemy.free()


func _test_grip_trajectory() -> void:
	# Exercise the public grip in a transformed player frame, so an accidental
	# local transform would fail even if the blade looks right at world origin.
	_shooter.position = Vector3(2.0, 1.0, -3.0)
	_shooter.rotation.y = 0.65
	var camera := _blade.camera
	var original_fov := camera.fov
	var view := _blade.get_node("Pivot").get_child(0) as Node3D
	var left_shoulder := Vector3(-0.17, -0.24, 0.14)
	for fov in [75.0, 58.0]:
		camera.fov = fov
		_blade.cancel()
		_blade.swing_now()
		var max_reach := 0.0
		var matches_view := true
		var min_depth := INF
		for sample in range(71):
			var grip := _blade.grip_transform()
			matches_view = matches_view and grip.is_equal_approx(view.global_transform)
			# The wrist sits four centimetres behind the imported grip origin.
			var wrist := camera.global_transform.affine_inverse() * (grip * Vector3(0, 0, 0.04))
			max_reach = maxf(max_reach, wrist.distance_to(left_shoulder))
			min_depth = minf(min_depth, _blade.tip_depth())
			if sample < 70:
				_blade._process(0.005)
		_check("%.0f FOV public grip follows rendered blade through all phases" % fov, matches_view)
		_check("%.0f FOV wrist path fits 44cm arm (%.3fm)" % [fov, max_reach], max_reach <= 0.44)
		_check("%.0f FOV blade tip remains in front of near plane" % fov, min_depth > camera.near)
	camera.fov = original_fov
	_shooter.transform = Transform3D.IDENTITY


func _dummy(at: Vector3, team: int) -> Dummy:
	var body := Dummy.new()
	body.team = team
	body.collision_layer = 0
	body.collision_mask = 0
	body.position = at
	var health := Health.new()
	health.name = "Health"
	health.team = team
	body.add_child(health)
	var hitbox := Hitbox.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	shape.shape = sphere
	hitbox.add_child(shape)
	body.add_child(hitbox)
	_world.add_child(body)
	return body


func _health(body: Dummy) -> Health:
	return body.get_node("Health") as Health


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _check(label: String, passed: bool) -> void:
	print("[%s] %s" % ["ok" if passed else "FAIL", label])
	if not passed:
		_failed += 1


func _flat_normals(model: Node3D) -> bool:
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (found as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				if normals[indices[i]].distance_to(normals[indices[i + 1]]) > .002 or normals[indices[i]].distance_to(normals[indices[i + 2]]) > .002:
					return false
	return true
