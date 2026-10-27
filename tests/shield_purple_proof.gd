extends Node
## Native rendering of the real skill choice, G shield and damaging counter.
## Guards are held still only to frame the visual evidence.

var _out := "res://docs/proof/ac-04-ac-08"
var _failures := 0
var _checks := 0


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
	await _run()
	print("PURPLE SHIELD VISUAL: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	RunState.start_new_run()
	BuffPool.reset(40408)
	var icon_path := _out.path_join("black-panther-icon.png")
	_check("saved actual imported Black Panther icon", BuffPool.ALL[6].icon.get_image().save_png(icon_path) == OK)
	var scene := (load(RunState.zone_scene()) as PackedScene).instantiate()
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	for frame in 3:
		await get_tree().process_frame
	await _shot("shield-01-purple-cards")
	var skill_card := director.selection.get_node("Center/Box/Choices").get_child(2) as Button
	skill_card.pressed.emit()
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.global_position = Vector3.ZERO
	(player.get_node("Head/Camera3D") as Camera3D).rotation.x = deg_to_rad(-8.0)
	var guards := get_tree().get_nodes_in_group("enemy")
	for index in guards.size():
		var enemy := guards[index] as Enemy
		enemy.set_physics_process(false)
		enemy.global_position = Vector3(float(index) * 1.5 - 2.25, 0, -2.4)
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
	Projectile.spawn(scene, Vector3(0, 1.0, -0.9), Vector3.BACK, source, 10.0, 9.0, [])
	await get_tree().create_timer(0.15).timeout
	_check("real incoming projectile is absorbed", player.health.health == health_before
		and player.combat_traits.feedback.contains("蓄能"))
	await _shot("shield-02-purple-active")
	if player.shield.is_active():
		await player.shield.expired
	await get_tree().create_timer(0.12).timeout
	_check("shield counters once for unchanged 25 body damage", pulses[0] == 1
		and is_equal_approx(target_before - source.health.health, 25.0))
	await _shot("shield-03-purple-pulse")
	# An additional observation camera makes the outward pulse colour visible;
	# it exists only in this fixture and never changes the gameplay camera.
	var observer := Camera3D.new()
	observer.fov = 70.0
	scene.add_child(observer)
	observer.global_position = Vector3(3.7, 3.0, 4.5)
	observer.look_at(Vector3(0, 1, -0.4))
	observer.make_current()
	await _shot("shield-04-purple-pulse-wide")
	await get_tree().create_timer(0.65).timeout
	_check("shield overlay ends and normal cooldown remains", not player.shield.is_active()
		and not player.health.invulnerable and player.shield.cooldown_duration() == 8.0)
	get_tree().paused = false
	scene.queue_free()
	await get_tree().create_timer(0.3).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(file_name + ".png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	_check("saved " + file_name, result == OK)
	print("SCREENSHOT " + path)


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s" % ["ok" if ok else "FAIL", label])
