extends Node3D
## Native inspection of the actual enemy silhouette, physical purple facets,
## and destructible dash decoy. Does not change production stage state.


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Fear visual proof requires native rendering")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.055, 0.06, 0.08)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.84, 0.95)
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.1
	add_child(light)
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.position = Vector3(0.4, 1.65, -6.7)
	add_child(camera)
	camera.look_at(Vector3(0.4, 1.0, 0))
	for i in 2:
		var enemy := preload("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as Node3D
		enemy.position = Vector3(-1.7 + i * 1.7, 0, 0)
		add_child(enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.rotation.y = 0.0 if i == 0 else PI
		var panic := PanicFlawStatus.new()
		panic.actor = enemy
		panic.health = enemy.get_node("Health")
		enemy.add_child(panic)
		panic.apply(4.0, true)
		if i == 1:
			panic.break_facet(0, true)
		_label("FRONT FLAW" if i == 0 else "RELOCATED TO BACK", enemy.position + Vector3(0, 2.4, 0))
	# Freeze the same pose used by the live first-person body, including its
	# complete head and hands. The hidden source never participates in combat.
	var source := preload("res://actors/player/player.tscn").instantiate() as Player
	source.position = Vector3(100, 0, 100)
	source.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(source)
	source.visible = false
	var body := source.get_node("ShadowBody") as ProtagonistBody
	body._tree.active = false
	body.pose_arms()
	body._skeleton.force_update_all_bone_transforms()
	var decoy := FearDecoy.new()
	decoy.pose_source = body
	decoy.position = Vector3(1.9, 0, 0)
	add_child(decoy)
	decoy.set_process(false)
	camera.make_current()
	_label("DESTRUCTIBLE DECOY / 2s", Vector3(1.9, 2.4, 0))
	var output := "user://proof/fear-core.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output)
	print("FEAR VISUAL PROOF: %s (%d)" % [output, error])
	get_tree().quit(0 if error == OK else 1)


func _label(text: String, point: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 30
	label.pixel_size = 0.0035
	label.modulate = Color(0.78, 0.69, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = point
	add_child(label)
