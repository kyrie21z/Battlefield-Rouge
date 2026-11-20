extends Node
## Matched first-person views of the shipped room and variant.

const ROOM := preload("res://maps/realms/wrath_2.tscn")
const FIRST_ROOM := preload("res://maps/realms/wrath_1.tscn")
const BOSS_ROOM := preload("res://maps/realms/wrath_boss.tscn")
const SPILLWAY := preload("res://environments/wrath/kiln_spillway.gd")
const DISPLAY_ACTOR := Vector3(-1.8, 0.06, -2.0)
var room: RealmStage
var player: Player
var output := ""
var verify := false
var failures := 0
var checks := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = ProjectSettings.globalize_path(arg.trim_prefix("--out="))
		elif arg == "--verify":
			verify = true
	await run()
	print("WRATH KILN: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func run() -> void:
	room = ROOM.instantiate() as RealmStage
	# The harness owns pause control. Gameplay children must remain pausable.
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(room)
	player = room.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var accumulator: WrathRealmEnemy
	for actor in room.enemies:
		actor.set_physics_process(false)
		if actor is WrathRealmEnemy and actor.variant == WrathRealmEnemy.Variant.ACCUMULATOR:
			accumulator = actor
	await frames(12)
	check("production room has its Accumulator", is_instance_valid(accumulator))
	if not is_instance_valid(accumulator):
		return
	player.aim_at(Vector3(0.0, 2.0, -20.0))
	await capture("entrance")
	pose_camera(Vector3(13.0, 0.04, 8.9), Vector3(0.0, 1.8, -12.0))
	await capture("side-route")
	pose_camera(Vector3(-5.0, 0.04, -10.0), Vector3(-12.2, 6.6, -26.0))
	await capture("furnace")
	pose_camera(Vector3(12.5, 0.04, -4.4), Vector3(18.4, 3.1, -10.6))
	await capture("spillway")
	pose_camera(Vector3(16.15, 0.04, -13.05), Vector3(17.85, 3.83, -10.50))
	await capture("spillway-profile")
	pose_camera(Vector3(-10.4, 0.04, 3.1), Vector3(-20.05, 8.2, -2.0))
	await capture("west-tower")
	pose_camera(Vector3(13.6, 0.04, 1.3), Vector3(20.05, 8.9, -2.0))
	await capture("east-tower")
	for guard_kind in [WrathRealmEnemy.Variant.PIERCER, WrathRealmEnemy.Variant.AGGRESSOR]:
		for actor in room.enemies:
			if actor is WrathRealmEnemy and actor.variant == guard_kind:
				var saved := actor.transform
				actor.position = DISPLAY_ACTOR
				actor.rotation = Vector3.ZERO
				pose_camera(DISPLAY_ACTOR + Vector3(-2.35, 0.0, -3.35), DISPLAY_ACTOR + Vector3(0, 1.12, -0.22))
				await capture("piercer" if guard_kind == WrathRealmEnemy.Variant.PIERCER else "aggressor")
				actor.transform = saved
				break
	for actor in room.enemies:
		if actor is WrathRealmEnemy and actor.variant == WrathRealmEnemy.Variant.READER:
			var saved := actor.transform
			actor.position = DISPLAY_ACTOR
			actor.rotation = Vector3.ZERO
			pose_camera(DISPLAY_ACTOR + Vector3(-0.9, 0, -3.3), DISPLAY_ACTOR + Vector3.UP * 1.25)
			await frames(3)
			await capture("reader-calm")
			player.weapon._shoot_ray(DISPLAY_ACTOR + Vector3(0, 1.10, -4.1), Vector3.BACK)
			await capture("reader-tear")
			await frames(42)
			await capture("reader-enraged")
			check("the production reader loses the newspaper to the first player shot", actor.paper_torn
				and is_equal_approx(actor.health.health, actor.health.max_health))
			actor.set_physics_process(true)
			for i in 150:
				if actor.attack_phase == WrathRealmEnemy.Attack.RUSH:
					break
				await frames(1)
			check("the room reader reaches its live lunge", actor.attack_phase == WrathRealmEnemy.Attack.RUSH)
			await capture("reader-rush", 0.08)
			actor.set_physics_process(false)
			actor.velocity = Vector3.ZERO
			actor.transform = saved
			break
	var original_pose := accumulator.transform
	accumulator.position = DISPLAY_ACTOR
	accumulator.rotation = Vector3.ZERO
	pose_camera(Vector3(-1.8, 0.04, -6.1), DISPLAY_ACTOR + Vector3.UP * 1.05)
	await frames(3)
	var hp := accumulator.health.health
	for round_index in 2:
		player.weapon._shoot_ray(DISPLAY_ACTOR + Vector3(0, 1.10, -4.1), Vector3.BACK)
	await capture("accumulator-front")
	pose_camera(DISPLAY_ACTOR + Vector3(3.55, 0, -1.26), DISPLAY_ACTOR + Vector3.UP * 1.05)
	await capture("accumulator-side")
	if verify:
		await frames(2)
		check("real front shots fill pressure without reducing HP",
			accumulator.blocked_shots == 2 and accumulator.pressure > 0.0 and is_equal_approx(accumulator.health.health, hp))
		var seams := accumulator.visual._shield_seams
		check("two pressure tiers glow while the last seam stays cool",
			seams.size() == 3 and seams[0].emission_energy_multiplier > 2.0
			and seams[1].emission_energy_multiplier > 2.0 and seams[2].emission_energy_multiplier < 0.3)
		player.weapon._shoot_ray(DISPLAY_ACTOR + Vector3(3.6, 1.1, 0), Vector3.LEFT)
		check("a real flank shot hits the exposed torso", accumulator.health.health < hp and accumulator.blocked_shots == 2)
		var head := (accumulator.get_node("HeadHitbox") as Hitbox).global_position
		var after_body := accumulator.health.health
		player.weapon._shoot_ray(head + Vector3.FORWARD * 4.0, Vector3.BACK)
		check("the front guard cone also protects the visible head", accumulator.blocked_shots == 3
			and is_equal_approx(accumulator.health.health, after_body))
		player.weapon._shoot_ray(head + Vector3.RIGHT * 3.6, Vector3.LEFT)
		check("an exposed side headshot reaches the head hitbox", accumulator.health.health < after_body
			and accumulator.health.last_damage_context.get("body_part") == Hitbox.BodyPart.HEAD)
		accumulator.transform = original_pose
		await verify_routes()
		await verify_escape()
	room.queue_free()
	await frames(3)
	if verify:
		await verify_other_rooms()


func verify_routes() -> void:
	var nav := room._region.get_navigation_map()
	var stage_start := Vector3(0, 0.08, 16)
	var floor_shape := room.geometry.get_node("WalkableKiln").get_child(0) as CollisionShape3D
	var shell := room.geometry.get_node("CrackedKilnScenery")
	var spillway := shell.get_node("Spillway") as SPILLWAY
	check("the kiln supplies the only world environment and directional light",
		room.find_children("*", "WorldEnvironment", true, false).size() == 1
		and room.find_children("*", "DirectionalLight3D", true, false).size() == 1)
	var lights := spillway.find_children("*", "OmniLight3D", true, false)
	var flows := 0
	var closed := true
	for node: MeshInstance3D in spillway.find_children("*", "MeshInstance3D", true, false):
		if node.material_override != spillway._melt:
			continue
		flows += 1
		var geometry := MeshDataTool.new()
		geometry.create_from_surface(node.mesh, 0)
		for edge in geometry.get_edge_count():
			if geometry.get_edge_faces(edge).size() != 2:
				closed = false
				break
	check("every molten body has a closed mesh including its banks, underside and ends", flows == 5 and closed)
	var towers := shell.get_node("HideTowers")
	var west := towers.get_node("West3") as MeshInstance3D
	var east := towers.get_node("East3") as MeshInstance3D
	check("paired towers are upright on both banks and share their stone and pelt geometry",
		towers.get_child_count() == 10 and west.mesh == east.mesh and west.mesh.get_surface_count() == 2
		and west.global_basis.y.is_equal_approx(Vector3.UP) and east.global_basis.y.is_equal_approx(Vector3.UP)
		and west.global_position.x < -19.0 and east.global_position.x > 19.0)
	room.geometry.set_deprivation(true)
	var frozen := spillway._flow_time
	await get_tree().process_frame
	await get_tree().process_frame
	check("deprivation cools both cascades, stops the flow and extinguishes their local light",
		lights.size() == 2 and lights.all(func(light: Node3D) -> bool: return not light.visible)
		and is_zero_approx(spillway._melt.get_shader_parameter("heat")) and frozen == spillway._flow_time)
	room.geometry.set_deprivation(false)
	await get_tree().process_frame
	await get_tree().process_frame
	check("restoring wrath restarts the molten flow and its furnace lighting",
		lights.all(func(light: Node3D) -> bool: return light.visible)
		and is_equal_approx(spillway._melt.get_shader_parameter("heat"), 1.0) and spillway._flow_time > frozen)
	check("suspended and distant scenery is free of collision bodies",
		shell.find_children("*", "CollisionObject3D", true, false).is_empty())
	check("the combat slab is still 40 by 48 metres and the gate is 36 metres from spawn",
		(floor_shape.shape as BoxShape3D).size.is_equal_approx(Vector3(40, 1.2, 48))
		and is_equal_approx(stage_start.z - room.gate.position.z, 36.0))
	for actor in room.enemies:
		var foot := NavigationServer3D.map_get_closest_point(nav, actor.global_position)
		check("guard spawn is attached to walkable ground: " + str(actor.variant), foot.distance_to(actor.global_position) < 0.9)
	check("central fire lane sees the exit", clear_ray(Vector3(0, 1.4, 16), Vector3(0, 1.4, -20)))
	var flank := Vector3(14.7, 1.4, -4)
	var guard_eye := Vector3(8, 1.4, -4)
	check("near side cover denies sight and the outer flank opens it",
		not clear_ray(Vector3(8, 1.4, 10.3), guard_eye) and clear_ray(flank, guard_eye))

	player.position = stage_start
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	# Stay in the central lane while walking just beside the authored guard at x=0.
	var central := await walk_route([Vector3(-1.7, 0, 7), Vector3(-1.7, 0, -14.6), Vector3(0, 0, -17)])
	check("the Player walks the direct central route", central)
	player.position = stage_start
	player.velocity = Vector3.ZERO
	var side := await walk_route([Vector3(8, 0, 10.7), Vector3(14.7, 0, 9.8)])
	player.aim_at(Vector3(player.position.x, player.eye_position().y, -15.0))
	var before_dash := player.position.z
	Input.action_press("dash")
	await frames(2)
	Input.action_release("dash")
	await frames(20)
	check("the real dash clears the outer lane along the first cover", before_dash - player.position.z > 3.5)
	var around := await walk_route([Vector3(14.7,0,-4), Vector3(14.7,0,-14.8), Vector3(0,0,-17)])
	check("the Player walks the full flanking route and rejoins at the gate", side and around)
	player.set_physics_process(false)

	# Place the active production Aggressor on the far side of an existing
	# WORLD collider. Its navigation should take an actual detour.
	var hunter := room.enemies[2] as WrathRealmEnemy
	var hunt_start := Vector3(8, 0.08, 0.6)
	hunter.position = hunt_start
	player.position = Vector3(8, 0.08, 12.2)
	await frames(3)
	var hidden := not clear_ray(hunt_start + Vector3.UP * 1.4, player.position + Vector3.UP * 1.4)
	hunter.set_physics_process(true)
	var found_route := false
	for index in 320:
		await frames(1)
		if hunter.position.z > 8.8 and absf(hunter.position.x - hunt_start.x) > 1.3:
			found_route = true
			break
	hunter.set_physics_process(false)
	check("production AI follows a detour around the side cover", hidden and found_route)


func walk_route(waypoints: Array[Vector3]) -> bool:
	for destination in waypoints:
		for index in 600:
			if Vector2(player.position.x - destination.x, player.position.z - destination.z).length() < 0.58:
				break
			player.aim_at(Vector3(destination.x, player.eye_position().y, destination.z))
			Input.action_press("move_forward")
			await frames(1)
		Input.action_release("move_forward")
		if Vector2(player.position.x - destination.x, player.position.z - destination.z).length() >= 0.58:
			return false
	return true


func clear_ray(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD)
	return room.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func press_f() -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F
		key.pressed = pressed
		Input.parse_input_event(key)
		await get_tree().process_frame


func verify_escape() -> void:
	player.position = Vector3(0, 0.04, -17.7)
	var exits := [0]
	room.exit_requested.connect(func(_stage: RealmStage) -> void: exits[0] += 1)
	for actor in room.enemies:
		actor.health.apply_damage(actor.health.health + 1.0, Hitbox.BodyPart.BODY, null, {"true_damage": true})
	for index in 250:
		if room.orb_pending():
			break
		await frames(1)
	check("clear opens the room's real talent orb", room.cleared and is_instance_valid(room.talent_orb))
	if not is_instance_valid(room.talent_orb):
		return
	player.position = Vector3(room.talent_orb.position.x, 0.04, room.talent_orb.position.z + 0.3)
	player.aim_at(room.talent_orb.position)
	await frames(2)
	await press_f()
	check("F at the orb opens the real reward picker", is_instance_valid(room.selection))
	if not is_instance_valid(room.selection):
		return
	room.selection._choose(room.selection._offered[0])
	await frames(3)
	player.position = Vector3(0, 0.04, -18.4)
	player.aim_at(room.gate.position + Vector3.UP)
	await press_f()
	check("after a card choice F opens the exit once", room.exit_ready and exits[0] == 1)


func verify_other_rooms() -> void:
	room = FIRST_ROOM.instantiate() as RealmStage
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(room)
	player = room.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	for actor in room.enemies:
		actor.set_physics_process(false)
	await frames(12)
	var has_kiln: bool = room.geometry.chamber_style == 1 and room.geometry.has_node("CrackedKilnScenery")
	check("wrath_1 has the formal kiln and its three opening guards", has_kiln and room.living_enemies() == 3)
	if has_kiln and room.living_enemies() == 3:
		player.aim_at(Vector3(0.0, 2.0, -20.0))
		await capture("first-room-entrance")
		await verify_routes()
		await verify_escape()
	room.queue_free()
	await frames(4)

	var boss := BOSS_ROOM.instantiate() as RealmStage
	add_child(boss)
	check("wrath_boss loads its arena and boss roster",
		boss.geometry.chamber_style == 0 and not boss.geometry.has_node("CrackedKilnScenery")
		and boss.living_enemies() == 1)
	boss.queue_free()
	await frames(4)


func pose_camera(feet: Vector3, focus: Vector3) -> void:
	player.position = feet
	player.aim_at(focus)


func capture(label: String, settle_seconds := 0.18) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(settle_seconds).timeout
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	var result := get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png"))
	get_tree().paused = false
	check("captured " + label, result == OK)


func frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
