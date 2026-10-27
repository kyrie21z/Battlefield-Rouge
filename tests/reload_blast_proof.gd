extends Node
## Real map/player/enemy components. Guards are held still only for framing.

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
	var scene := (load(RunState.zone_scene()) as PackedScene).instantiate()
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	(director.selection.get_node("Center/Box/Choices").get_child(0) as Button).pressed.emit()
	await get_tree().process_frame
	player.set_physics_process(false)
	player.set_process(false)
	player.weapon.set_process(false)
	player.global_position = Vector3.ZERO
	var guards := get_tree().get_nodes_in_group("enemy")
	for index in guards.size():
		var enemy := guards[index] as Enemy
		enemy.set_physics_process(false)
		enemy.global_position = Vector3(float(index) * 1.7 - 1.7, 0, -5 - float(index % 2))
	for frame_index in 4:
		await get_tree().physics_frame
	var thrown: Array[Node3D] = []
	player.combat_traits.reload_charge_thrown.connect(func(value: Node3D): thrown.append(value))
	player.weapon.ammo = 0
	player.weapon.try_reload()
	_check("actual empty reload ejected one magazine", thrown.size() == 1)
	var charge := thrown[0] as ReloadCharge
	var state := {"effect": null, "hits": 0}
	charge.exploded.connect(func(_point: Vector3, effect: Node3D):
		state["effect"] = effect
		state["hits"] = effect.get_meta("targets_hit")
	)
	await get_tree().create_timer(0.16).timeout
	await _shot("reload-01-ejected")
	if is_instance_valid(charge) and not charge.exploded_once:
		await charge.exploded
	await get_tree().create_timer(0.065).timeout
	await _shot("reload-02-flash")
	_check("real explosion damaged an enemy", int(state["hits"]) > 0)
	await get_tree().create_timer(0.15).timeout
	await _shot("reload-03-pressure-smoke")
	await get_tree().create_timer(0.9).timeout
	await _shot("reload-04-clear-view")
	_check("explosion automatically recycled", not is_instance_valid(state["effect"]))
	print("RELOAD BLAST VISUAL: %d failed; actual targets=%d" % [_failures, state["hits"]])
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
	if not ok:
		_failures += 1
	print("[%s] %s" % ["ok" if ok else "FAIL", label])
