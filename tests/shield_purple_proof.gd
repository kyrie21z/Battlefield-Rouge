extends Node
## Native rendering of the real skill choice, G shield and damaging counter.
## Guards are held still only to frame the visual evidence.

var _out := "res://docs/proof/active-buffs"
var _failures := 0
var _checks := 0
const MAX_JPEG_BYTES := 300000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("Visual proof requires a native display")
		get_tree().quit(1)
		return
	_out = ProjectSettings.globalize_path(_out)
	if DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("Cannot create visual proof output directory")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _run()
	print("PURPLE SHIELD VISUAL: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	RunState.start_new_run()
	BuffPool.reset(40408)
	var scene := (load(RunState.zone_scene()) as PackedScene).instantiate()
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	for frame in 3:
		await get_tree().process_frame
	var skill_card := director.selection.get_node("Center/Box/Choices").get_child(2) as Button
	skill_card.pressed.emit()
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.global_position = Vector3(60, 0, 0)
	_add_floor(scene)
	(player.get_node("Head/Camera3D") as Camera3D).rotation.x = deg_to_rad(-8.0)
	var guards := get_tree().get_nodes_in_group("enemy")
	for index in guards.size():
		var enemy := guards[index] as Enemy
		enemy.set_physics_process(false)
		enemy.global_position = Vector3(60 + float(index) * 1.5 - 2.25, 0, -6.0)
	for frame in 4:
		await get_tree().physics_frame
	_check("actual skill choice unlocks the same G shield", player.shield.is_unlocked())
	_check("first skill card retains 115 maximum health", player.health.max_health == 115.0)
	var source := guards[1] as Enemy
	var health_before := player.health.health
	var target_before := source.health.health
	var pulses := [0]
	player.combat_traits.shield_pulsed.connect(func(): pulses[0] += 1)
	Input.action_press("shield")
	# process_frame resumes before nodes' _process; allow the real shield
	# input consumer to execute before asserting its state.
	for frame in 2:
		await get_tree().process_frame
	Input.action_release("shield")
	_check("G input activates the shield", player.shield.is_active())
	Projectile.spawn(scene, Vector3(60, 1.0, -0.9), Vector3.BACK, source, 10.0, 9.0, [])
	await get_tree().create_timer(0.15).timeout
	_check("real incoming projectile is absorbed", player.health.health == health_before
		and player.combat_traits.feedback.contains("蓄能"))
	if player.shield.is_active():
		await player.shield.expired
	await get_tree().create_timer(0.12).timeout
	_check("7m shield reaches a real enemy beyond the old 3.5m range once for 25 body damage", pulses[0] == 1
		and is_equal_approx(target_before - source.health.health, 25.0))
	await _shot("shield-01-purple-pulse")
	# An additional observation camera makes the outward pulse colour visible;
	# it exists only in this fixture and never changes the gameplay camera.
	var observer := Camera3D.new()
	observer.fov = 70.0
	scene.add_child(observer)
	observer.global_position = Vector3(69.5, 7.0, 10.0)
	observer.look_at(Vector3(60, 1, -1.0))
	observer.make_current()
	# The outside view records the same wave near its full seven-metre extent.
	await get_tree().create_timer(0.18).timeout
	await _shot("shield-02-purple-pulse-wide")
	await get_tree().create_timer(0.65).timeout
	_check("shield overlay ends and normal cooldown remains", not player.shield.is_active()
		and not player.health.invulnerable and player.shield.cooldown_duration() == 8.0)
	get_tree().paused = false
	scene.queue_free()
	await get_tree().create_timer(0.3).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var path := _out.path_join(file_name + ".jpg")
	var quality := 0.82
	var result := frame.save_jpg(path, quality)
	var byte_count := FileAccess.get_file_as_bytes(path).size() if result == OK else 0
	while result == OK and byte_count > MAX_JPEG_BYTES and quality > 0.56:
		quality -= 0.05
		result = frame.save_jpg(path, quality)
		byte_count = FileAccess.get_file_as_bytes(path).size() if result == OK else 0
	_check("saved " + file_name + " as JPEG under 300 KB", result == OK
		and byte_count > 0 and byte_count <= MAX_JPEG_BYTES)
	print("SCREENSHOT %s (%s, %d bytes, quality %.2f)" % [path, frame.get_size(), byte_count, quality])


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s" % ["ok" if ok else "FAIL", label])


func _add_floor(parent: Node) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(60, -0.5, -12)
	floor_body.collision_layer = CollisionLayers.WORLD
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 70)
	collision.shape = box
	floor_body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var visual := BoxMesh.new()
	visual.size = box.size
	mesh.mesh = visual
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("35404A")
	mesh.material_override = material
	floor_body.add_child(mesh)
	parent.add_child(floor_body)
