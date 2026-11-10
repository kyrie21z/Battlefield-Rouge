extends Node3D
## Native material inspection on the unmodified imported rig in its rest pose.
## For first-person body-awareness evidence, use protagonist_body_proof instead.

const FRACTURE = preload("res://actors/player/body_fracture.gd")
const BODY = preload("res://assets/models/characters/red_crystal_enemy_animated.glb")
const MATERIAL = preload("res://assets/materials/protagonist_crystal_material.tres")


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Body fracture proof requires native rendering")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var model := BODY.instantiate() as Node3D
	add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = MATERIAL
	var fracture = FRACTURE.new()
	add_child(fracture)
	fracture.setup(model, skeleton)
	var camera := Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.10, 0.12, 0.15)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_energy = 0.7
	add_child(light)
	var output_path := "res://docs/proof/issue-105/body-fracture"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=")
	var output := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(output)
	for region in ["wrist", "chest", "full"]:
		var focus := Vector3(-0.69, 1.57, 0.05) if region == "wrist" else Vector3(0, 1.5, 0)
		camera.position = focus + (Vector3(0.0, 0.30, -0.48) if region == "wrist" else Vector3(0.0, 0.10, -1.1))
		if region == "full":
			focus = Vector3(0, 1.0, 0)
			camera.position = Vector3(0, 1.0, -3.8)
		camera.look_at(focus)
		var levels := [1] if region == "wrist" else ([2] if region == "chest" else [4])
		for level in levels:
			fracture.set_fracture_level(level)
			for frame in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png(output.path_join("%s_%d.png" % [region, level]))
			assert(error == OK)
	print("BODY FRACTURE MATERIAL PROOF: complete")
	get_tree().quit()
