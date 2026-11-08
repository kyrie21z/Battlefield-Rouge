extends Node
## Native Forward+ samples of a real map guard's unmodified SlothAttack.
## Only staging, the observer camera and screenshot pauses belong to this test.
##   godot --rendering-method forward_plus --path . res://tests/sloth_burst_proof.tscn
## Optional user argument: --out=res://artifacts/sloth-burst-proof

signal sampled

var _out := "res://artifacts/sloth-burst-proof"
var _map: Node3D
var _actor: SlothEnemy
var _attack: SlothAttack
var _camera: Camera3D
var _caption: Label
var _launches: Array[Dictionary] = []
var _checks := 0
var _failures := 0
var _screenshots: Array[String] = []
var _wall_time := 0.0
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	_out = ProjectSettings.globalize_path(_out)
	if DisplayServer.get_name() == "headless":
		push_error("Sloth burst proof requires a native Forward+ display")
		get_tree().quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_title("Sloth 四连发验证（自动结束）")
	_check("Forward+ renderer", RenderingServer.get_current_rendering_method() == "forward_plus")
	_check("proof output directory", DirAccess.make_dir_recursive_absolute(_out) == OK)
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	sampled.emit()


func _process(delta: float) -> void:
	_wall_time += delta
	if not _finished and _wall_time > 45.0:
		push_error("Sloth native burst proof timed out")
		get_tree().quit(1)


func _run() -> void:
	RunState.start_new_run()
	_map = load("res://maps/zone_1.tscn").instantiate() as Node3D
	add_child(_map)
	# Accept the actual opening offer, then stage the existing guard and Player.
	# Decisions of the other guards are irrelevant to the one observed volley.
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)
	var director := _map.get_node("ZoneDirector") as ZoneDirector
	_check("actual entry card exists", director.selection != null)
	(director.selection.get_node("Center/Box/Choices/Choice1") as Button).pressed.emit()
	var player := _map.get_node("Player") as Player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.health.invulnerable = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_map.get_node("HUD") as CanvasLayer).hide()
	_actor = _map.get_node("Enemy1") as SlothEnemy
	_check("observed actor is the authored Lingerer", _actor.kind == SlothEnemy.Kind.LINGERER
		and _actor.target == player and _actor.scene_file_path == "res://actors/enemy/sloth/sloth_enemy.tscn")
	player.global_position = _actor.global_position + Vector3(34.0, 0.1, 0.0)
	_actor.look_at(Vector3(player.global_position.x, _actor.global_position.y, player.global_position.z))
	_actor.state = Enemy.State.ENGAGE
	_actor.cooldown_left = 99.0
	_camera = Camera3D.new()
	_camera.far = 18000.0
	add_child(_camera)
	_close_camera()
	_camera.make_current()
	_build_caption()
	# Warm the native shaders and retain the actual scene's lighting/geometry.
	for i in 45:
		await get_tree().process_frame
	_map.child_entered_tree.connect(_record_launch)
	_check("real SlothAttack begins", _actor.cast_attack())
	_attack = _actor.active_attack
	_actor.set_physics_process(true)
	await _at(1.1)
	_check("four suspended orbs form before any projectile", _attack._orbs.size() == 4 and _launches.is_empty())
	await _shot("01-formation", "迟滞者 · 四连发\n凝聚 %.2f 秒  |  4 颗悬浮弹 · 尚未发射" % _attack.elapsed)
	await _at(1.65)
	_check("aim locks during the last 0.45 seconds", _attack.aim_locked and _launches.is_empty())
	var locked_directions := _attack._volley_directions.duplicate()
	await _shot("02-aim-locked", "迟滞者 · 四连发\n锁向 %.2f 秒  |  4 颗悬浮弹 · 最后预警" % _attack.elapsed)
	# A sideways move after the tell must not redirect any of the four shots.
	player.global_position.z -= 8.0
	_wide_camera()
	await _at(2.04)
	_check("first actual projectile waits for the full two seconds", _launches.size() == 1)
	await _shot("03-first-release", "迟滞者 · 四连发\n释放 %.2f 秒  |  第 1 / 4 发 · 已锁定方向" % _attack.elapsed)
	await _at(2.56)
	var bullets := _live_projectiles()
	_check("four actual Projectile nodes coexist after the fourth release", _launches.size() == 4 and bullets.size() == 4)
	var fixed_aim := bullets.size() == 4
	for i in bullets.size():
		fixed_aim = fixed_aim and (-bullets[i].global_basis.z).dot(locked_directions[i]) > 0.9999
	_check("all four keep their aim after the target moves", fixed_aim)
	await _shot("04-four-released", "迟滞者 · 四连发\n释放 %.2f 秒  |  4 / 4 发 · 间隔 0.18 秒" % _attack.elapsed)
	_check_launches()
	await _at(2.7)
	_check("the real burst ends in an exposed recovery", not is_instance_valid(_actor.active_attack)
		and _actor.cloak_recover_left > 0.0 and _actor.get_node("CoreHitbox").collision_layer != 0)
	_close_camera()
	await _shot("05-recovery", "迟滞者 · 四连发\n攻击结束  |  披风展开 · 1 秒破绽")
	_finished = true
	_write_report()
	print("SLOTH_BURST_NATIVE_COMPLETE checks=%d failures=%d output=%s" % [_checks, _failures, _out])
	get_tree().paused = false
	get_tree().quit(0 if _failures == 0 else 1)


func _record_launch(node: Node) -> void:
	if node is Projectile and node.source == _actor:
		_launches.append({"node_id": node.get_instance_id(), "elapsed": _attack.elapsed,
			"speed": node.speed, "damage": node.damage})
		print("ACTUAL_PROJECTILE | ", JSON.stringify(_launches.back()))


func _live_projectiles() -> Array[Projectile]:
	var result: Array[Projectile] = []
	for node in _map.get_children():
		if node is Projectile and node.source == _actor and not node.is_queued_for_deletion():
			result.append(node)
	return result


func _check_launches() -> void:
	_check("exactly four emissions, not decorative orbs", _launches.size() == 4)
	for i in _launches.size():
		var expected := 2.0 + float(i) * 0.18
		_check("projectile %d releases at %.2f seconds" % [i + 1, expected],
			absf(float(_launches[i].elapsed) - expected) <= 0.035)
		_check("projectile %d uses 40 m/s and 9 damage" % (i + 1),
			is_equal_approx(_launches[i].speed, 40.0) and is_equal_approx(_launches[i].damage, 9.0))


func _at(time: float) -> void:
	while is_instance_valid(_actor.active_attack) and _actor.active_attack.elapsed < time:
		await sampled


func _close_camera() -> void:
	_camera.global_position = _actor.global_position + Vector3(8.8, 2.0, 1.8)
	_camera.fov = 38.0
	_camera.look_at(_actor.global_position + Vector3.UP * 1.25)


func _wide_camera() -> void:
	_camera.global_position = _actor.global_position + Vector3(14.0, 6.5, -23.0)
	_camera.fov = 61.0
	_camera.look_at(_actor.global_position + Vector3(11.5, 1.1, 0.0))


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(44, 38)
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_color_override("font_color", Color("e7f7ff"))
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_caption)


func _shot(stem: String, text: String) -> void:
	# Pause only to save the sampled real phase without a screenshot stall
	# advancing the scheduled volley. No elapsed/phase/Projectile data is assigned.
	get_tree().paused = true
	_caption.text = text
	await RenderingServer.frame_post_draw
	var path := _out.path_join(stem + ".png")
	_check("native frame saved: " + stem, get_viewport().get_texture().get_image().save_png(path) == OK)
	_screenshots.append(path)
	get_tree().paused = false


func _write_report() -> void:
	var report := {"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "map": _map.scene_file_path,
		"actor": _actor.get_path(), "launches": _launches, "screenshots": _screenshots,
		"checks": _checks, "failures": _failures,
		"staging": "Actual map guard and Player; other AI frozen; target moved after aim lock. Screenshot pauses freeze the real attack, without assigning its elapsed time or projectiles."}
	var file := FileAccess.open(_out.path_join("burst-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("  [%s] %s" % ["ok" if passed else "FAIL", label])
