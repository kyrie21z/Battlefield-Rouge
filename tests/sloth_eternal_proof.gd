extends Node3D
## Native evidence from the production kill trigger and real frozen projectiles.
var _player: Player
var _manager: BoonManager
var _actors: Array[SlothEnemy] = []
var _shots: Array[Projectile] = []
var _failed := false

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_stage()
	_player = preload("res://actors/player/player.tscn").instantiate() as Player
	_player.position = Vector3(0, 0, 15)
	add_child(_player)
	_player.visible = false
	_player.set_physics_process(false)
	_manager = _player.get_node("BoonManager") as BoonManager
	for id in ["sloth_gun_pulse", "sloth_inertia", "sloth_resonance", "sloth_eternal"]:
		var card := load("res://buffs/resources/sloth/%s.tres" % id) as BoonData
		_check("legal equip " + id, _manager.can_equip(card) and _manager.equip(card))
	var effect := _manager.effect_for(load("res://buffs/effects/sloth_effect.gd")) as SlothEffect
	for index in 3:
		var actor := _enemy(Vector3((index - 1) * 2.2, 0, -1.0))
		actor.apply_impact(Vector3.RIGHT, 8.0, 4.0)
		_actors.append(actor)
		_shots.append(Projectile.spawn(self, actor.position + Vector3(0, 1.3, 1.4), Vector3.BACK, actor, 4.0, 12.0, [], LatencyStatus.AMBER))
		effect.apply_latency(actor)
	for index in 3:
		var victim := _enemy(Vector3(60 + index * 3, 0, 0))
		_manager.apply_damage(victim, 10000.0, {"tag": &"sloth_burst", "proc_depth": 1})
	var origins: Array[Vector3] = []
	var bullet_origins: Array[Vector3] = []
	for actor in _actors:
		origins.append(actor.global_position)
	for shot in _shots:
		bullet_origins.append(shot.global_position)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(7.5, 5.0, 9.0)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.fov = 48.0
	camera.make_current()
	await get_tree().create_timer(0.4).timeout
	for index in 3:
		_check("actual enemy and bullet remain frozen %d" % index, _actors[index].boon_time_scale == 0.0 and _shots[index].boon_time_scale == 0.0 and _actors[index].global_position.is_equal_approx(origins[index]) and _shots[index].global_position.is_equal_approx(bullet_origins[index]))
	_title("永恒停滞 · 真实三杀触发", "敌人与飞弹冻结 2 秒 · 玩家时钟持续运行")
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-116/eternal-stasis.png")
	_check("native screenshot saved", error == OK)
	await get_tree().create_timer(1.9).timeout
	_check("enemy clock restores without Engine time-scale deadlock", _actors[0].boon_time_scale == 1.0 and Engine.time_scale == 1.0 and not _actors[0].global_position.is_equal_approx(origins[0]))
	_manager.clear()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	print("ETERNAL NATIVE: ", "FAIL" if _failed else "ALL PASSED")
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
	settings.background_color = Color(0.72, 0.76, 0.8)
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
	material.albedo_color = Color(0.91, 0.93, 0.95)
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
	label.add_theme_color_override("font_color", Color(0.12, 0.16, 0.22))
	layer.add_child(label)
