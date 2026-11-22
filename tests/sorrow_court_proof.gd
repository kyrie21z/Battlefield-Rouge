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
			and not boss.geometry.has_node("FloodedCourt") and boss.living_enemies() == 1)
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
	for actor in stage.enemies:
		actor.set_physics_process(false)
	await _frames(10)
	player.aim_at(Vector3(0, 3.8, -24))
	await _capture("room-%d-entry" % (index + 1))
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
	_check(room + "water stays at ankle height with its reflection environment",
		is_equal_approx(realm.water_level, 0.14) and realm.mirror_environment.ssr_enabled
		and stage.player.view_camera.environment == realm.mirror_environment)
	var spillways := court.get_node("Spillways") as Node3D
	_check(room + "rain and the three spillways start active", realm.rain.emitting and spillways.visible
		and spillways.get_child_count() == 4)
	realm.set_deprivation(true)
	await _frames(4)
	_check(room + "deprivation dries the court as well as the basin",
		not spillways.visible and not realm.rain.emitting and not realm.water.visible)
	realm.set_deprivation(false)
	await _frames(4)
	_check(room + "restoring sorrow resumes spillways and rain",
		spillways.visible and realm.rain.emitting and realm.water.visible)
	var player := stage.player
	player.set_physics_process(true)
	var spawn := realm.player_spawn() + Vector3.UP * 0.06
	player.position = spawn
	player.velocity = Vector3.ZERO
	var walked := await _walk(player, [Vector3(1.7,0,9), Vector3(1.7,0,-15), Vector3(0,0,-17.6)])
	_check(room + "player walks the central approach", walked)
	player.position = spawn
	player.velocity = Vector3.ZERO
	walked = await _walk(player, [Vector3(4,0,10.4), Vector3(14.2,0,8.1), Vector3(14.2,0,-15), Vector3(2.6,0,-18.2)])
	_check(room + "player can bypass the platforms on the side route", walked)
	_check(room + "real movement adds ripples on the wet floor", realm.movement_ripple_count > 4)
	player.set_physics_process(false)
	await _clear_and_exit(stage, room)


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
			await get_tree().physics_frame
		Input.action_release("move_forward")
		if Vector2(player.position.x - goal.x, player.position.z - goal.z).length() >= 0.60:
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
