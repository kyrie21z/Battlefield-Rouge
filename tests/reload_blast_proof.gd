extends Node
## Native evidence of a completed empty reload, physical C release and distant hit.
## Real map/HUD/player/enemies; a fixture floor outside the map keeps the 20m lane clear.

var _out := "res://docs/proof/active-buffs"
var _checks := 0
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
	print("ACTIVE MAGAZINE VISUAL: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	RunState.start_new_run()
	BuffPool.reset(40408)
	var scene: Node = load(RunState.zone_scene()).instantiate()
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	(director.selection.get_node("Center/Box/Choices").get_child(0) as Button).pressed.emit()
	await get_tree().process_frame
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3(60, 0, 0)
	_add_lane(scene)
	var guards := get_tree().get_nodes_in_group("enemy")
	for index in guards.size():
		var enemy := guards[index] as Enemy
		enemy.set_physics_process(false)
		enemy.global_position = Vector3(60 + float(index) * 1.2 - 1.8, 0, -23.0)
		enemy.health.max_health = 1000.0
		enemy.health.health = 1000.0
	for frame in 4:
		await get_tree().physics_frame
	var thrown: Array[Node3D] = []
	player.combat_traits.reload_charge_thrown.connect(func(value: Node3D): thrown.append(value))
	player.weapon.ammo = 0
	player.weapon.try_reload()
	_check("starting empty reload creates no projectile", thrown.is_empty() and not player.combat_traits.has_reload_charge())
	await get_tree().create_timer(player.weapon._reload_left + 0.08).timeout
	player.weapon.set_process(false)
	_check("completed empty reload leaves one held magazine", player.combat_traits.has_reload_charge() and thrown.is_empty())
	await get_tree().create_timer(ReloadCharge.FUSE_TIME + 0.1).timeout
	_check("waiting in hand does not start the fuse", player.combat_traits.has_reload_charge() and thrown.is_empty())
	await _shot("magazine-01-held-C-ready")
	var launch := player.global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Inject before the process callbacks, not at the preceding frame's draw
	# completion where just-pressed state can expire before actors sample it.
	await get_tree().process_frame
	var event := InputEventKey.new()
	event.physical_keycode = KEY_C
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in 2:
		await get_tree().process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_C
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	_check("physical C launches one held magazine", thrown.size() == 1 and not player.combat_traits.has_reload_charge())
	if thrown.is_empty():
		scene.queue_free()
		return
	var charge := thrown[0] as ReloadCharge
	var state := {"effect": null, "hits": 0, "point": launch}
	charge.exploded.connect(func(point: Vector3, effect: Node3D):
		state["effect"] = effect
		state["hits"] = effect.get_meta("targets_hit")
		state["point"] = point
	)
	await get_tree().create_timer(0.55).timeout
	_check("charge is visibly travelling down the distant lane", is_instance_valid(charge) and charge.global_position.z < -12.0)
	await _shot("magazine-02-distant-flight")
	if is_instance_valid(charge) and not charge.exploded_once:
		await charge.exploded
	await get_tree().create_timer(0.05).timeout
	await _shot("magazine-03-distant-impact")
	var distance := launch.distance_to(state["point"] as Vector3)
	_check("real explosion damages enemies at least 18m away", int(state["hits"]) > 0 and distance >= 18.0)
	_check("the stronger explosion deals at least 60 damage to a distant enemy", guards.any(func(enemy: Enemy): return enemy.health.health <= 940.0))
	print("VISUAL THROW: %.2f m; actual targets=%d" % [distance, state["hits"]])
	await get_tree().create_timer(0.9).timeout
	await _shot("magazine-04-clear-view")
	_check("explosion automatically recycles", not is_instance_valid(state["effect"]))
	get_tree().paused = false
	scene.queue_free()
	await get_tree().create_timer(0.3).timeout


func _add_lane(parent: Node) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(60, -0.5, -15)
	floor_body.collision_layer = CollisionLayers.WORLD
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 70)
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
	for metres in [10, 20]:
		var marker := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(12, 0.02, 0.08)
		marker.mesh = strip
		marker.position = Vector3(60, 0.015, -float(metres))
		var stripe_material := StandardMaterial3D.new()
		stripe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stripe_material.albedo_color = Color("DAA754")
		marker.material_override = stripe_material
		parent.add_child(marker)
		var label := Label3D.new()
		label.text = "%d m" % metres
		label.position = Vector3(56.5, 1.5, -float(metres))
		label.font_size = 80
		label.pixel_size = 0.01
		label.no_depth_test = true
		parent.add_child(label)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(file_name + ".png")
	_check("saved " + file_name, get_viewport().get_texture().get_image().save_png(path) == OK)
	print("SCREENSHOT " + path)


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s" % ["ok" if ok else "FAIL", label])
