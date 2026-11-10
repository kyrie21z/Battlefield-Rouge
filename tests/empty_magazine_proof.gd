extends Node
## Native evidence of final-shot storage, C throwing before reload completes,
## and the real 6m explosion at a distant enemy. No player-centred blast exists.
## AI and movement are staged; the real map, HUD and player/enemy models render.
## The old magazine perk is injected by a legacy fixture, not by boon selection.

var _out := "res://docs/proof/empty-magazine"
var _checks := 0
var _failures := 0
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
	print("EMPTY MAGAZINE VISUAL: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var fixture := RunFixture.by_id("FX-001").duplicate() as RunFixture
	fixture.id = "LEGACY-MAGAZINE-PROOF"
	fixture.run_seed = 40408
	fixture.buffs.assign([BuffPool.ALL[0]])
	RunState.start_fixture(fixture)
	var scene: Node = load(RunState.zone_scene()).instantiate()
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	(director.selection.get_node("Center/Box/Choices").get_child(0) as Button).pressed.emit()
	await get_tree().process_frame
	player.boons.clear() # Isolate the historical magazine from new family shots.
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	player.weapon.set_process(false)
	player.global_position = Vector3(60, 0, 0)
	player.aim_at(Vector3(60, 1.6, -23))
	_add_stage(scene)
	var hud := scene.get_node("HUD") as CanvasLayer
	var magazine_slot := hud.get_node("AbilityBar/Magazine") as AbilitySlot
	var guards := get_tree().get_nodes_in_group("enemy")
	for index in guards.size():
		var enemy := guards[index] as Enemy
		enemy.set_physics_process(false)
		enemy.global_position = Vector3(60 + [-2.5, 0.0, 2.5, 4.5][index % 4], 0, -23)
		enemy.health.max_health = 1000.0
		enemy.health.health = 1000.0
	for frame in 4:
		await get_tree().physics_frame
	player.weapon.ammo = 1
	player.weapon.reserve = 100
	player.weapon.ammo_changed.emit(player.weapon.ammo, player.weapon.reserve)
	await _frames(5)
	_check("explicit legacy fixture enables the dangerous-magazine perk", player.stats.get_value(Stats.RELOAD_BLAST_DAMAGE) > 0.0)
	_check("C is unlocked and empty before the final shot", not magazine_slot.locked and not magazine_slot.slot_ready and magazine_slot.count_text == "0/1")
	await _shot("01-ready-last-round")
	var thrown: Array[Node3D] = []
	var before_reload := [false]
	player.combat_traits.reload_charge_stored.connect(func():
		before_reload[0] = not player.weapon.is_reloading() and player.weapon.ammo == 0)
	player.combat_traits.reload_charge_thrown.connect(func(charge: Node3D): thrown.append(charge))
	_check("last real pistol shot is accepted", player.weapon.try_fire())
	_check("one charge is stored synchronously before reload begins", before_reload[0] and player.combat_traits.has_reload_charge())
	_check("automatic reload starts while the charge is already available", player.weapon.is_reloading() and player.weapon.ammo == 0)
	_check("emptying the gun does not automatically throw or explode", thrown.is_empty() and not scene.has_node("BlastPulse"))
	# Freeze the accepted reload timer deliberately. The C proof below must
	# succeed while ammo is still zero, without ever finishing that reload.
	var pending_reload := player.weapon._reload_left
	player.weapon._flash.visible = false
	await _frames(3)
	_check("C lights up immediately at 1/1 with zero gun ammo", magazine_slot.slot_ready and magazine_slot.count_text == "1/1" and player.weapon.ammo == 0)
	await _shot("02-C-ready-before-reload")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.aim_at(Vector3(60, 1.6, -23))
	await _key(KEY_C)
	_check("physical C releases one charge before the frozen reload completes", thrown.size() == 1 and not player.combat_traits.has_reload_charge()
		and player.weapon.ammo == 0 and is_equal_approx(player.weapon._reload_left, pending_reload))
	_check("C slot returns to 0/1 immediately after release", not magazine_slot.slot_ready and magazine_slot.count_text == "0/1")
	if thrown.is_empty():
		scene.queue_free()
		return
	var charge := thrown[0] as ReloadCharge
	_check("thrown charge uses the requested 6m explosion radius", is_equal_approx(charge.radius, 6.0))
	var result := {"effect": null, "point": Vector3.ZERO, "count": 0}
	charge.exploded.connect(func(point: Vector3, effect: Node3D):
		result["effect"] = effect
		result["point"] = point
		result["count"] += 1)
	# A timeout makes an unexpected collision regression fail instead of hang.
	for frame in 120:
		if int(result["count"]) > 0:
			break
		await get_tree().physics_frame
	_check("flight explodes exactly once after reaching distant enemies", int(result["count"]) == 1 and player.global_position.distance_to(result["point"]) > 18.0)
	if result["effect"] == null:
		scene.queue_free()
		return
	var effect := result["effect"] as Node3D
	var point := result["point"] as Vector3
	_check("distant explosion applies real damage to multiple enemies", int(effect.get_meta("targets_hit")) >= 2)
	_check("distant 6m explosion leaves the thrower unharmed", player.health.health == player.health.max_health)
	await get_tree().create_timer(0.22).timeout
	await _shot("03-distant-impact")
	print("DISTANT IMPACT: %.2f m; targets=%d; radius=%.1f m" % [player.global_position.distance_to(point), effect.get_meta("targets_hit"), effect.get_meta("blast_radius")])
	var observer := Camera3D.new()
	observer.fov = 70.0
	scene.add_child(observer)
	observer.global_position = point + Vector3(9, 8, 12)
	observer.look_at(point)
	observer.make_current()
	_add_range_marker(scene, point)
	await get_tree().create_timer(0.18).timeout
	# Keep the screenshot on the actual full-radius wave, including under pause.
	get_tree().paused = true
	var front := effect.get_node("BlastWaveFront") as MeshInstance3D
	var paused_scale := front.scale
	await get_tree().create_timer(0.10).timeout
	_check("world effect freezes during pause", front.scale.is_equal_approx(paused_scale))
	_check("orange world wave reaches the advertised 6m radius", is_equal_approx(front.scale.x, 6.0))
	await _shot("04-six-metre-pressure-wave")
	get_tree().paused = false
	await get_tree().create_timer(0.65).timeout
	_check("world explosion recycles after its short presentation", not is_instance_valid(effect))
	_check("proof throws and detonates without finishing the original reload", player.weapon.ammo == 0 and player.weapon.is_reloading())
	scene.queue_free()
	await get_tree().create_timer(0.3).timeout


func _add_stage(parent: Node) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(60, -0.5, -15)
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


func _add_range_marker(parent: Node, point: Vector3) -> void:
	for metres in [6]:
		var marker := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = float(metres) - 0.025
		torus.outer_radius = float(metres)
		torus.rings = 96
		torus.ring_segments = 6
		marker.mesh = torus
		marker.position = Vector3(point.x, 0.02, point.z)
		var stripe_material := StandardMaterial3D.new()
		stripe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stripe_material.albedo_color = Color("728594")
		marker.material_override = stripe_material
		parent.add_child(marker)
		var label := Label3D.new()
		label.text = "%d m" % metres
		label.position = Vector3(point.x + float(metres), 0.18, point.z)
		label.font_size = 64
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		parent.add_child(label)


func _shot(file_name: String) -> Image:
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
	_check("saved " + file_name + " as JPEG under 300 KB", result == OK and byte_count > 0 and byte_count <= MAX_JPEG_BYTES)
	print("SCREENSHOT %s (%s, %d bytes)" % [path, frame.get_size(), byte_count])
	return frame


func _key(keycode: Key) -> void:
	await get_tree().process_frame
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in 2:
		await get_tree().process_frame
	event = InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _frames(count: int) -> void:
	for frame in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s" % ["ok" if ok else "FAIL", label])
