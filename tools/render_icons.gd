extends Node
## Renders the HUD weapon silhouettes from the models already in this repo.
## Needs a display (no --headless). Run from the project root:
##   godot --path . res://tools/render_icons.tscn
##
## Every icon is the same side view: camera on +X looking at the model, which
## makes the muzzle / blade point right. The models are drawn unshaded white on a
## transparent background, so the HUD can tint them with its own colours.

const ICON_SIZE := Vector2i(256, 128)
const OUTPUT_DIR := "res://assets/ui/weapons"
const MODELS := [
	["pistol", "res://weapons/obsidian_pistol/obsidian_pistol_view.tscn"],
	["mind_blade", "res://weapons/mind_blade/mind_blade_view.tscn"],
]

var _viewport: SubViewport
var _world: Node3D
var _failures := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Icon rendering requires a native display")
		get_tree().quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)) != OK:
		push_error("Cannot create icon output directory")
		get_tree().quit(1)
		return
	_viewport = SubViewport.new()
	_viewport.size = ICON_SIZE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_world = Node3D.new()
	_world.name = "IconWorld"
	_viewport.add_child(_world)

	for entry in MODELS:
		await _render(entry[0], entry[1])
	print("Rendered %d icons to %s (%d failed)" % [MODELS.size() - _failures, OUTPUT_DIR, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _render(icon_name: String, scene_path: String) -> void:
	var view: Node3D = load(scene_path).instantiate()
	_world.add_child(view)
	await get_tree().process_frame

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bounds := AABB()
	var has_bounds := false
	for found in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if not mesh.visible:
			continue
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if not has_bounds else bounds.merge(box)
		has_bounds = true
	if not has_bounds:
		_failures += 1
		push_error("%s has no mesh" % scene_path)
		view.queue_free()
		return

	# The viewport is 2:1, so the vertical extent also has to fit the length.
	var ortho := maxf(bounds.size.y, bounds.size.z * 0.5) * 1.3
	var center := bounds.get_center()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ortho
	camera.near = 0.01
	camera.far = 20.0
	_world.add_child(camera)
	camera.position = center + Vector3(4.0, 0.0, 0.0)
	camera.look_at(center, Vector3.UP)
	camera.current = true

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var path := "%s/%s.png" % [OUTPUT_DIR, icon_name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_failures += 1
	print("== %s -> %s (%s)" % [icon_name, path, "ok" if error == OK else "error %d" % error])

	camera.queue_free()
	view.queue_free()
	await get_tree().process_frame
