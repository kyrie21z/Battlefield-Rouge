extends Node
## Native captures and traversals of the campaign scenes, using the real player camera.

const ROOMS := [preload("res://maps/realms/sorrow_1.tscn"), preload("res://maps/realms/sorrow_2.tscn")]
const BOSS := preload("res://maps/realms/sorrow_boss.tscn")

var _output := ""
var _baseline := false
var _checks := 0
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_output = ProjectSettings.globalize_path(arg.trim_prefix("--out="))
		elif arg == "--baseline":
			_baseline = true
	if not _output.is_empty():
		DirAccess.make_dir_recursive_absolute(_output)
	for index in ROOMS.size():
		await _room(ROOMS[index], index)
	if not _baseline:
		var boss := BOSS.instantiate() as RealmStage
		add_child(boss)
		_check("the Monolith room still owns its original basin and boss",
			boss.geometry is SorrowRealm and boss.geometry.boss_arena
			and not boss.geometry.has_node("FloodedCourt") and boss.living_enemies() == 1
			and not boss.player.realm_effects.ground_current.is_valid())
		boss.queue_free()
		await _frames(4)
	print("SORROW COURT: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures else 0)


func _room(scene: PackedScene, index: int) -> void:
	var stage := scene.instantiate() as RealmStage
	if _baseline:
		(stage.get_node("Geometry") as SorrowRealm).chamber_style = 0
	add_child(stage)
	var realm := stage.geometry as SorrowRealm
	var player := stage.player
	player.health.invulnerable = true
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	for actor in stage.enemies:
		actor.set_physics_process(false)
	await _frames(10)
	player.aim_at(Vector3(0, 3.8, -24))
	await _capture("room-%d-entry" % (index + 1))
	if not _baseline:
		await _frames(36)
		var swirl: Vector4 = realm._whirlpools[0]
		player.position = Vector3(swirl.x + 0.4, 0.38, swirl.y + 3.35)
		player.aim_at(Vector3(swirl.x, realm.water_level - 0.34, swirl.y))
		await _capture("room-%d-whirlpool" % (index + 1))
	if index == 1:
		player.position = Vector3(4, 0.10, 8)
		player.aim_at(Vector3(18, 5.0, -12))
		await _capture("room-2-spillway")
		if not _baseline and not _output.is_empty() and DisplayServer.get_name() != "headless":
			await _capture_cry(stage)
	if not _baseline:
		await _verify(stage, realm, index)
	stage.queue_free()
	await _frames(5)


func _capture_cry(stage: RealmStage) -> void:
	var mourner := stage.enemies[2] as SorrowRealmEnemy
	var previous := mourner.position
	mourner.position = Vector3(0, 0.08, -1.5)
	stage.player.position = Vector3(0, 0.10, 8.8)
	stage.player.aim_at(Vector3(0, 0.1, -1.5))
	mourner.release_cry()
	var pulse := stage.get_children().filter(func(node: Node) -> bool: return node is SorrowCry).front() as SorrowCry
	await _frames(9)
	await _capture("room-2-blue-cry")
	pulse.queue_free()
	mourner.position = previous


func _verify(stage: RealmStage, realm: SorrowRealm, index: int) -> void:
	var room := "Sorrow %d: " % (index + 1)
	var court := realm.get_node_or_null("FloodedCourt") as Node3D
	_check(room + "formal basin has the new court and original encounter size",
		is_instance_valid(court) and stage.living_enemies() == (3 if index == 0 else 5))
	if court == null:
		return
	_check(room + "scenery is separate from navigation and world collisions",
		court.find_children("*", "CollisionObject3D", true, false).is_empty()
		and realm.platforms.size() == 4 and stage._region.navigation_mesh.get_polygon_count() > 0)
	var ruins := realm.find_children("BasinRuin*", "StaticBody3D", false, false)
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-8, 1.4, 0.7), Vector3(-2.4, 1.4, 0.7), CollisionLayers.WORLD)
	var hit := stage.get_world_3d().direct_space_state.intersect_ray(ray)
	_check(room + "six ruins add navigable cover and block actual world rays",
		ruins.size() == 6 and hit.get("collider") == realm.get_node_or_null("BasinRuin1")
		and ruins.all(func(ruin: Node) -> bool: return ruin.is_in_group("navigation_geometry")))
	_check(room + "water stays at ankle height with its reflection environment",
		is_equal_approx(realm.water_level, 0.14) and realm.mirror_environment.ssr_enabled
		and stage.player.view_camera.environment == realm.mirror_environment)
	var spillways := court.get_node("Spillways") as Node3D
	_check(room + "rain and the three spillways start active", realm.rain.emitting and spillways.visible
		and spillways.get_child_count() == 4)
	await _verify_whirlpools(stage, realm, room)
	var current_time := realm.clock
	realm.set_deprivation(true)
	await _frames(4)
	_check(room + "deprivation dries the court as well as the basin",
		not spillways.visible and not realm.rain.emitting and not realm.water.visible
		and is_equal_approx(realm.clock, current_time)
		and is_zero_approx(realm._basin_floor_visual.position.y))
	realm.set_deprivation(false)
	await _frames(4)
	_check(room + "restoring sorrow resumes spillways and rain",
		spillways.visible and realm.rain.emitting and realm.water.visible)
	var player := stage.player
	player.set_physics_process(true)
	var spawn := realm.player_spawn() + Vector3.UP * 0.06
	player.position = spawn
	player.velocity = Vector3.ZERO
	var walked := await _walk(player, [Vector3(1.7,0,7), Vector3(1.7,0,-14), Vector3(0,0,-18.5)])
	_check(room + "player traverses the central approach, dashing out of any trap", walked)
	player.position = spawn
	player.velocity = Vector3.ZERO
	walked = await _walk(player, [Vector3(4,0,10.4), Vector3(14.6,0,9.8), Vector3(15.5,0,-16.6), Vector3(2.6,0,-18.2)])
	_check(room + "player can bypass the platforms on the side route", walked)
	_check(room + "real movement adds ripples on the wet floor", realm.movement_ripple_count > 4)
	player.set_physics_process(false)
	await _clear_and_exit(stage, room)


func _verify_whirlpools(stage: RealmStage, realm: SorrowRealm, room: String) -> void:
	var first: Vector4 = realm._whirlpools[0]
	realm.start_whirlpools(stage.run_seed, stage.room_index)
	_check(room + "the opening center is reproducible from the run seed and room",
		is_equal_approx(first.z, 2.6) and Vector2(first.x, first.y).is_equal_approx(
			Vector2(realm._whirlpools[0].x, realm._whirlpools[0].y)))
	var starts := {}
	for trial in 12:
		realm.start_whirlpools(stage.run_seed + trial, stage.room_index)
		var sample: Vector4 = realm._whirlpools[0]
		starts[Vector2(sample.x, sample.y).round()] = true
	_check(room + "different run seeds pick different open water sites", starts.size() > 4)
	realm.start_whirlpools(stage.run_seed, stage.room_index)
	first = realm._whirlpools[0]
	var clearance := CylinderShape3D.new()
	clearance.radius = SorrowRealm.WHIRLPOOL_RADIUS + SorrowRealm.WHIRLPOOL_JITTER * sqrt(2.0)
	clearance.height = 0.34
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = clearance
	query.collision_mask = CollisionLayers.WORLD
	var clear_sites := true
	for site: Vector2 in SorrowRealm.WHIRLPOOL_SITES:
		query.transform = Transform3D(Basis.IDENTITY, Vector3(site.x, 0.31, site.y))
		clear_sites = clear_sites and realm.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	_check(room + "all full-size funnels and their site jitter are clear of ruins", clear_sites)
	_check(room + "the submerged surface has vertices for a deep funnel without moving the walking floor",
		(realm.water.mesh as PlaneMesh).subdivide_width > 80
		and is_equal_approx(realm.water_material.get_shader_parameter("whirlpool_depth"), 0.60)
		and is_equal_approx(realm._basin_floor_visual.position.y, -0.60)
		and is_zero_approx((realm.get_node("BasinFloor") as StaticBody3D).position.y + 0.5))

	var player := stage.player
	var center := Vector3(first.x, 0.08, first.y)
	await _until(realm, first.w + 0.60)
	var pull := realm._ground_current(center + Vector3.RIGHT * 1.4)
	_check(room + "the active inward flow is more than twice the base walking speed",
		pull.x < -2.0 * player.jog_speed and is_zero_approx(pull.w))
	_check(room + "the current only exists in shallow water inside the rim",
		realm._ground_current(Vector3(first.x + 0.8, 1.2, first.y)).is_zero_approx()
		and realm._ground_current(Vector3(first.x + 2.65, 0.0, first.y)).is_zero_approx())

	player.recover_from_fall(center + Vector3.RIGHT * 1.4)
	player.aim_at(center + Vector3.RIGHT * 8 + Vector3.UP * 1.6)
	var standing_eye := player.eye_position().y - player.global_position.y
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await _frames(22)
	_check(room + "walking outward still gets the player caught by the current",
		player.current_trapped and absf(player.position.x - center.x) < SorrowRealm.WHIRLPOOL_CORE_RADIUS)
	var first_eye := player.eye_position().y - player.global_position.y
	var hp := player.health.health
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(55)
	Input.action_release("move_forward")
	var sunk_eye := player.eye_position().y - player.global_position.y
	_check(room + "the camera keeps sinking without moving the body below the floor or taking health",
		first_eye - sunk_eye > 0.25 and standing_eye - sunk_eye > 0.40
		and player.position.y > -0.03 and is_equal_approx(player.health.health, hp))
	_check(room + "walking and jumping cannot free a captured player",
		player.current_trapped and absf(player.position.x - center.x) < 0.15 and player.is_on_floor())
	_check(room + "the HUD shows the remappable dash key while trapped",
		stage.hud._exit_hint.visible and stage.hud._exit_hint.text.contains("冲刺脱离漩涡"))
	if room.begins_with("Sorrow 2:"):
		await _capture("room-2-whirlpool-trapped")
	player.aim_at(player.eye_position() + Vector3(0.10, -8.0, 0.0))
	var charges := player.dash.charges()
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	await _frames(12)
	_check(room + "one actual Shift input escapes even when looking down",
		player.dash.charges() == charges - 1 and not player.current_trapped
		and Vector2(player.position.x - center.x, player.position.z - center.z).length() > SorrowRealm.WHIRLPOOL_RADIUS)
	await _frames(40)
	_check(room + "the eye returns to normal height once outside",
		absf((player.eye_position().y - player.global_position.y) - standing_eye) < 0.11
		and (not stage.hud._exit_hint.visible or not stage.hud._exit_hint.text.contains("冲刺脱离漩涡")))
	player.set_physics_process(false)

	await _until(realm, first.w + 4.90)
	_check(room + "the first funnel stands alone before five seconds", realm._whirlpools.size() == 1)
	await _until(realm, first.w + 5.06)
	_check(room + "five seconds later both funnels coexist at different centers",
		realm._whirlpools.size() == 2 and realm._whirlpools[0] == first
		and Vector2(realm._whirlpools[1].x - first.x, realm._whirlpools[1].y - first.y).length() > 5.2)
	await _until(realm, first.w + 10.06)
	_check(room + "ten seconds after opening there are three distinct active funnels", realm._whirlpools.size() == 3)
	await _until(realm, first.w + 14.67)
	player.recover_from_fall(center)
	player.set_physics_process(true)
	await _frames(8)
	_check(room + "the core still holds the player shortly before expiry", player.current_trapped)
	await _until(realm, first.w + 14.94)
	_check(room + "the opening funnel lasts until the fifteen second boundary",
		realm._whirlpools.size() == 3 and realm._whirlpools[0] == first)
	await _until(realm, first.w + 15.06)
	_check(room + "at fifteen seconds the first expires and its replacement keeps the active count at three",
		realm._whirlpools.size() == 3 and not realm._whirlpools.has(first)
		and is_equal_approx(realm._whirlpools.back().w, first.w + 15.0))
	_check(room + "an expired whirlpool releases the player even without Shift", not player.current_trapped)
	player.set_physics_process(false)


func _until(realm: SorrowRealm, target_time: float) -> void:
	while realm.clock < target_time:
		await get_tree().physics_frame


func _clear_and_exit(stage: RealmStage, room: String) -> void:
	var player := stage.player
	var exit_signals := [0]
	stage.exit_requested.connect(func(_stage: RealmStage) -> void: exit_signals[0] += 1)
	for actor in stage.enemies:
		actor.health.apply_damage(actor.health.health + 1.0, Hitbox.BodyPart.BODY, null, {"true_damage": true})
	await _frames(12)
	_check(room + "clearing the real encounter opens a talent orb", stage.cleared and stage.orb_pending())
	if not stage.orb_pending():
		return
	player.position = stage.talent_orb.position + Vector3.BACK * 0.6
	player.position.y = 0.06
	player.aim_at(stage.talent_orb.position)
	await _frames(3)
	await _press_f()
	_check(room + "pressing F opens the actual reward picker", is_instance_valid(stage.selection))
	if not is_instance_valid(stage.selection):
		return
	stage.selection._choose(stage.selection._offered[0])
	await _frames(4)
	player.position = stage.gate.position + Vector3.BACK * 1.4
	player.aim_at(stage.gate.position + Vector3.UP)
	await _press_f()
	_check(room + "pressing F at the open gate requests one transition", stage.exit_ready and exit_signals[0] == 1)


func _walk(player: Player, targets: Array[Vector3]) -> bool:
	for goal in targets:
		for tick in 400:
			if Vector2(player.position.x - goal.x, player.position.z - goal.z).length() < 0.60:
				break
			player.aim_at(Vector3(goal.x, player.eye_position().y, goal.z))
			Input.action_press("move_forward")
			if player.current_trapped and player.dash.charges() > 0:
				Input.action_press("dash")
				await _frames(2)
				Input.action_release("dash")
			await get_tree().physics_frame
		Input.action_release("move_forward")
		if Vector2(player.position.x - goal.x, player.position.z - goal.z).length() >= 0.60:
			print("Route stopped at %s before %s" % [player.position, goal])
			return false
	return true


func _press_f() -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F
		key.pressed = pressed
		Input.parse_input_event(key)
		await get_tree().process_frame


func _capture(name_value: String) -> void:
	if _output.is_empty() or DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_jpg(_output.path_join(name_value + ".jpg"), 0.90)
	_check("native capture " + name_value, error == OK)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
