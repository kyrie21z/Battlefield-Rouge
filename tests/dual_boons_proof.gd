extends Node3D
## Native proof stages production actors, then invokes real shots/dashes.
## Status meshes and pools are exclusively created by equipped boon effects.

var _player: Player
var _manager: BoonManager
var _camera: Camera3D
var _cards: Dictionary = {}
var _failed := 0
var _status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		push_error("Dual proof requires native Forward+ rendering")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var mode := "tearful"
	var output := "user://proof/issue-123"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	_stage()
	for card in BoonCatalog.all():
		_cards[card.id] = card
	_player = preload("res://actors/player/player.tscn").instantiate() as Player
	_player.position = Vector3(0, 0.05, -7)
	add_child(_player)
	_player.visible = false
	_player.set_physics_process(false)
	_player.weapon.set_process(false)
	_player.melee.set_process(false)
	_player.dash.set_physics_process(false)
	_manager = _player.boons
	_manager.set_physics_process(false)
	_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in 12:
		await get_tree().process_frame
	if mode == "mire":
		await _mire()
	else:
		await _tearful()
	# Freeze only after the real hit/movement and status assertions completed.
	# This holds their brief presentation long enough for native frame capture.
	get_tree().paused = true
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var path := output.path_join("02-suffocating-mire.png" if mode == "mire" else "01-tearful-panic.png")
	_check("native screenshot saved", get_viewport().get_texture().get_image().save_png(path) == OK)
	print("DUAL NATIVE PROOF: %s | %d failed" % [path, _failed])
	get_tree().paused = false
	_manager.clear()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(150)
	await get_tree().process_frame
	get_tree().quit(0 if _failed == 0 else 1)


func _tearful() -> void:
	for id in ["fear_gaze_pierce", "sorrow_blade_tide", "dual_tearful_panic"]:
		_equip(id)
	var victim := _enemy(Vector3.ZERO)
	var left := _enemy(Vector3(-3, 0, -0.7))
	var right := _enemy(Vector3(3, 0, 0.7))
	var fear := DualBoonManager.family(_manager, "fear") as FearEffect
	var sorrow := DualBoonManager.family(_manager, "sorrow") as SorrowEffect
	fear.apply_panic(victim)
	var before := right.global_position
	var facet := fear.status_for(victim)
	var point := facet.facet_position(0)
	_player.weapon.camera.global_position = point + Vector3.FORWARD * 4.0
	_player.weapon.camera.look_at(point)
	await _frames(3, false)
	var ray := PhysicsRayQueryParameters3D.create(_player.weapon.camera.global_position, _player.weapon.camera.global_position + Vector3.BACK * 10, CollisionLayers.HITBOXES)
	var contact := get_world_3d().direct_space_state.intersect_ray(ray)
	print("PROOF CONTACT ", contact.get("collider"), " point=", contact.get("position"), " facet=", point)
	_player.weapon._shoot_ray(_player.weapon.camera.global_position, Vector3.BACK)
	_check("real pistol ray breaks the physical front flaw", victim.health.health < 5000.0 and facet.facets[0] == null)
	_check("dual event gives all three production enemies five erosion layers", sorrow.erosion_layers(victim) == 5 and sorrow.erosion_layers(left) == 5 and sorrow.erosion_layers(right) == 5)
	await _frames(7, false)
	_check("real CharacterBody pull moves the outer enemy inward", right.global_position.distance_to(victim.global_position) < before.distance_to(victim.global_position) - .2)
	var dual := _manager.effect_for(preload("res://buffs/dual/dual_boon_manager.gd")) as DualBoonManager
	_check("the visible pool belongs to the active dual effect", not dual._pools.is_empty())
	_label("惊惧泪海  /  TEARFUL PANIC", "实体破绽被手枪射线击碎 → 深潭聚拢 → 三名敌人均为 5 层溶蚀")
	_status.text = "真实状态  ·  溶蚀 %d / %d / %d 层  ·  外侧敌人已向中心移动 %.2f m" % [sorrow.erosion_layers(left), sorrow.erosion_layers(victim), sorrow.erosion_layers(right), before.distance_to(right.global_position)]


func _mire() -> void:
	for id in ["sloth_gun_pulse", "sorrow_blade_tide", "sloth_dash_ripple", "dual_suffocating_mire"]:
		_equip(id)
	await _dash_from(Vector3(-3, .05, 2.5))
	_manager.equip(_cards["sorrow_dash_ribbon"])
	await _dash_from(Vector3(2, .05, 2.5))
	_player.set_physics_process(false)
	_player.dash.set_physics_process(false)
	_player.global_position = Vector3(0, 0, -8)
	_player.velocity = Vector3.ZERO
	var aura_enemy := _enemy(Vector3(-3, 0, -2.2))
	var water_enemy := _enemy(Vector3(2, 0, 0))
	var outside := _enemy(Vector3(5.8, 0, 0))
	await _frames(2)
	var projectile := Projectile.spawn(self, Vector3(2, 1.0, -1.0), Vector3.BACK, water_enemy, 5.0, 20.0, [])
	projectile.set_physics_process(false)
	_manager._physics_process(.01)
	var start := projectile.global_position
	projectile._physics_process(.1)
	_check("real Sloth aura and Sorrow ribbon both apply half attack speed", is_equal_approx(aura_enemy.boon_attack_scale, .5) and is_equal_approx(water_enemy.boon_attack_scale, .5) and is_equal_approx(outside.boon_attack_scale, 1.0))
	_check("hostile projectile advances at five percent speed inside the real mire", is_equal_approx(projectile.boon_time_scale, .05) and is_equal_approx(projectile.global_position.distance_to(start), .1))
	var dual := _manager.effect_for(preload("res://buffs/dual/dual_boon_manager.gd")) as DualBoonManager
	_check("visible mire meshes are backed by real water and aura regions", dual._regions().size() >= 3 and dual._mire_nodes.size() == dual._regions().size())
	_label("沉溺泥沼  /  SUFFOCATING MIRE", "真实冲刺留下怠惰光环与苍蓝水带 → 双重效果将两类区域变成泥沼")
	_status.text = "真实状态  ·  光环内攻速 %.0f%%  ·  水带内攻速 %.0f%%  ·  区外 %.0f%%  ·  敌弹速度 %.0f%%" % [aura_enemy.boon_attack_scale * 100, water_enemy.boon_attack_scale * 100, outside.boon_attack_scale * 100, projectile.boon_time_scale * 100]


func _dash_from(point: Vector3) -> void:
	_player.global_position = point
	_player.rotation = Vector3.ZERO
	_player.weapon.camera.rotation = Vector3.ZERO
	_player.velocity = Vector3.DOWN
	_player.move_and_slide()
	_player.set_physics_process(true)
	_player.dash.set_physics_process(true)
	await _frames(2)
	_check("production dash entry accepts a grounded charge", _player.dash.try_dash())
	await _frames(13)
	_player.set_physics_process(false)
	_player.dash.set_physics_process(false)
	_check("production dash physically travels through the world", _player.global_position.distance_to(point) > 3.0)


func _equip(id: String) -> void:
	_check("equip " + id, _manager.request_equip(_cards[id]))


func _enemy(point: Vector3) -> Enemy:
	var enemy := preload("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as Enemy
	enemy.position = point
	(enemy.get_node("Health") as Health).max_health = 5000.0
	add_child(enemy)
	enemy.health.max_health = 5000.0
	enemy.health.health = 5000.0
	(enemy as SlothEnemy).evade_chance = 0.0 # Stage a deterministic visible hit.
	return enemy


func _frames(count: int, step_manager := true) -> void:
	for frame in count:
		await get_tree().physics_frame
		if step_manager:
			_manager._physics_process(1.0 / 60.0)


func _stage() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("eef0f3")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = .85
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)
	var floor := StaticBody3D.new()
	floor.collision_layer = CollisionLayers.WORLD
	floor.collision_mask = 0
	floor.position.y = -.1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(50, .2, 50)
	collider.shape = shape
	floor.add_child(collider)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f4f4f3")
	material.roughness = .88
	mesh.material_override = material
	floor.add_child(mesh)
	add_child(floor)
	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.position = Vector3(9, 8, -12)
	add_child(_camera)
	_camera.look_at(Vector3(.5, .5, 0))


func _label(title: String, subtitle: String) -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var heading := Label.new()
	heading.position = Vector2(40, 26)
	heading.add_theme_font_size_override("font_size", 44)
	heading.add_theme_color_override("font_color", Color("2a203e"))
	heading.text = title
	canvas.add_child(heading)
	var detail := Label.new()
	detail.position = Vector2(42, 88)
	detail.add_theme_font_size_override("font_size", 27)
	detail.add_theme_color_override("font_color", Color("414453"))
	detail.text = subtitle
	canvas.add_child(detail)
	_status = Label.new()
	_status.position = Vector2(42, get_viewport().get_visible_rect().size.y - 70)
	_status.add_theme_font_size_override("font_size", 26)
	_status.add_theme_color_override("font_color", Color("303344"))
	canvas.add_child(_status)


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", label])
	if not condition:
		_failed += 1
