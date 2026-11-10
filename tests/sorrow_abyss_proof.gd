extends Node3D
## Real kill-spawned fountains and moving, homing, piercing water blades.
var _player: Player
var _manager: BoonManager
var _failed := false
var _blade_hits := 0

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_stage()
	_player = preload("res://actors/player/player.tscn").instantiate() as Player
	_player.position = Vector3(0, 0, 15)
	add_child(_player)
	_player.visible = false
	_player.set_physics_process(false)
	_manager = _player.get_node("BoonManager") as BoonManager
	_manager.event_dispatched.connect(func(event: StringName, ctx: Dictionary):
		if event == &"enemy_damage" and ctx.get("tag") == &"sorrow_water_blade" and float(ctx.get("dealt", 0.0)) > 0.0:
			_blade_hits += 1)
	for id in ["sorrow_gun_needles", "sorrow_echo", "sorrow_buffer", "sorrow_abyss"]:
		var card := load("res://buffs/resources/sorrow/%s.tres" % id) as BoonData
		_check("legal equip " + id, _manager.can_equip(card) and _manager.equip(card))
	var effect := _manager.effect_for(load("res://buffs/effects/sorrow_effect.gd")) as SorrowEffect
	var targets: Array[SlothEnemy] = []
	for index in 3:
		var actor := _enemy(Vector3((index - 1) * 2.8, 0, -3.5))
		targets.append(actor)
		effect.add_erosion(actor, 2)
	for index in 2:
		var victim := _enemy(Vector3((index * 2 - 1) * 3.0, 0, 2.0))
		_manager.apply_damage(victim, 10000.0, {"tag": &"native_proof_kill", "proc_depth": 1})
	effect.spawn_tear(Vector3(0, 0, 2.6), 3)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(7.5, 6.0, 10.0)
	camera.look_at(Vector3(0, 0.7, -0.8))
	camera.fov = 48.0
	camera.make_current()
	for frame in 7:
		await get_tree().physics_frame
	_check("actual player kills create two fountains", effect._traits.fountains.size() == 2)
	_check("existing tear drops become live homing water blades", effect._traits.blades.size() >= 5 and effect.tears.is_empty())
	await RenderingServer.frame_post_draw
	_check("tear conversion screenshot saved", get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-122/abyss-tear-conversion.png") == OK)
	for frame in 107:
		await get_tree().physics_frame
	_title("无尽悲渊 · 击杀涌泉与追踪水刃", "真实泪晶升华 · 穿透不同目标 · WORLD 遮挡终止")
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-122/abyss-fountains.png")
	_check("native screenshot saved", error == OK)
	await get_tree().create_timer(0.8).timeout
	_check("live water blades damage production enemy Health", _blade_hits > 0)
	_manager.clear()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	print("ABYSS NATIVE: ", "FAIL" if _failed else "ALL PASSED")
	get_tree().quit(1 if _failed else 0)

func _enemy(point: Vector3) -> SlothEnemy:
	var actor := preload("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
	actor.position = point
	add_child(actor)
	actor.health.max_health = 1000.0
	actor.health.health = 1000.0
	_manager.register_enemy(actor)
	return actor

func _check(label: String, value: bool) -> void:
	_failed = _failed or not value
	print("[%s] %s" % ["ok" if value else "FAIL", label])

func _stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.32, 0.38, 0.46)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CollisionLayers.WORLD
	floor_body.position.y = -0.2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(180, 0.4, 40)
	shape.shape = box
	floor_body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.42, 0.49)
	material.roughness = 0.85
	visual.material_override = material
	floor_body.add_child(visual)
	add_child(floor_body)

func _title(title: String, subtitle: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	var label := Label.new()
	label.text = title + "\n" + subtitle
	label.position = Vector2(42, 30)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	layer.add_child(label)
