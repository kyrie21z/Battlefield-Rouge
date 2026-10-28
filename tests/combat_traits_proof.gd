extends Node
## Staged visual proof of the three core actions, using actual game components.
## This fixture grants all cores for demonstration; normal choice timing is
## independently verified by buff_run_test. Enemy AI is held still for framing.

var _out := "res://docs/proof/ac-04-ac-08"
var _failures := 0


func _ready() -> void:
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
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	RunState.start_new_run()
	BuffPool.reset(40408)
	var scene := load(RunState.zone_scene()).instantiate() as Node
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	(director.selection.get_node("Center/Box/Choices").get_child(0) as Button).pressed.emit()
	await get_tree().process_frame
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.global_position = Vector3.ZERO
	var guards := get_tree().get_nodes_in_group("enemy")
	for index in guards.size():
		var enemy := guards[index] as Enemy
		enemy.set_physics_process(false)
		enemy.global_position = Vector3(float(index) * 1.5 - 1.5, 0.0, -5.0 - float(index % 2))
	var source := guards[0] as Enemy
	for frame_index in 4:
		await get_tree().physics_frame
	player.weapon.ammo = 0
	player.weapon.try_reload()
	player.weapon._finish_reload()
	_check("completed reload holds a magazine", player.combat_traits.has_reload_charge())
	_check("manual release launches the held magazine", player.combat_traits.try_throw_reload_charge())
	await get_tree().create_timer(0.10).timeout
	await _shot("action_01_ejected_magazine")
	await get_tree().create_timer(0.65).timeout
	await _shot("action_02_magazine_blast")
	_grant(player, BuffPool.ALL[3])
	player.weapon._finish_reload()
	await get_tree().process_frame
	Input.action_press("melee")
	await get_tree().process_frame
	Input.action_release("melee")
	Projectile.spawn(scene, Vector3(0, 1.0, -0.9), Vector3.BACK, source, 10.0, 9.0, [])
	await get_tree().create_timer(0.10).timeout
	_check("parry collected one bullet", player.combat_traits.stored_rounds == 1)
	await _shot("action_03_collected_bullet")
	# The camera looks along -Z. A real shot releases the stored projectile.
	player.weapon.set_process(true)
	player.weapon.try_fire()
	_check("shot released stored bullet", player.combat_traits.stored_rounds == 0)
	await get_tree().create_timer(0.04).timeout
	await _shot("action_04_returned_bullet")
	_grant(player, BuffPool.ALL[6])
	await get_tree().create_timer(0.3).timeout
	source.global_position = Vector3(-1.5, 0.0, -2.4)
	await get_tree().process_frame
	Input.action_press("shield")
	await get_tree().process_frame
	Input.action_release("shield")
	_check("G activated the shield", player.shield.is_active())
	Projectile.spawn(scene, Vector3(0, 1.0, -0.9), Vector3.BACK, source, 10.0, 9.0, [])
	await get_tree().create_timer(0.15).timeout
	_check("shield absorbed the incoming projectile", player.combat_traits.feedback.contains("蓄能"))
	await _shot("action_05_shield_charged")
	await get_tree().create_timer(player.shield.active_remaining + 0.08).timeout
	_check("shield counterattack fired", player.combat_traits.feedback.contains("护盾反击"))
	await _shot("action_06_shield_counter")
	print("VISUAL TRAITS: stored_after_release=%d, feedback=%s" % [player.combat_traits.stored_rounds, player.combat_traits.feedback])
	get_tree().paused = false
	scene.queue_free()
	await get_tree().create_timer(0.65).timeout


func _grant(player: Player, buff: Buff) -> void:
	Events.buff_chosen.emit(buff)
	player.stats.apply_buff(buff)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(file_name + ".png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT %s: %s" % [path, "ok" if result == OK else "FAIL"])
	_check("saved " + file_name, result == OK)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["ok" if ok else "FAIL", label])
