class_name BladeSlashTrail
extends MeshInstance3D
## Glowing crystal ribbon left by the blade through one cut.
##
## The trail is pure presentation. While the swing is active the weapon feeds
## it the blade root and tip in world space; it keeps the last few samples and
## rebuilds a short triangle strip, then fades the strip out on its own clock.
## Nothing here reads simulation state or the global RNG, and a paused tree
## freezes the fade because the node is pausable like its weapon.

## Seconds the ribbon takes to fade after the cut ends.
const FADE_TIME := 0.14
## Samples kept. An active window at 240 Hz is about 29 frames; the cap only
## stops a pathologically slow frame from growing the mesh without bound.
const MAX_SAMPLES := 48
## The ribbon is a gradient: the edge is the bright crystal highlight and the
## tail dissolves into the swing.
const ROOT_COLOR := Color(0.36, 0.78, 1.0)
const TIP_COLOR := Color(0.90, 0.99, 1.0)
const TAIL_ALPHA := 0.05

var _mesh: ArrayMesh
var _roots := PackedVector3Array()
var _tips := PackedVector3Array()
var _fade_left := 0.0


func _ready() -> void:
	# Vertices are sampled in world space, so the ribbon does not inherit the
	# weapon's sway. Living under the weapon keeps it in the same pause scope
	# and frees it with the swing.
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 1.0
	_mesh = ArrayMesh.new()
	mesh = _mesh
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.vertex_color_use_as_albedo = true
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.disable_receive_shadows = true
	material_override = glow
	visible = false
	set_process(false)


## A new cut starts: drop whatever the last one left behind.
func begin() -> void:
	_fade_left = 0.0
	_roots.clear()
	_tips.clear()
	visible = false
	set_process(false)
	if _mesh != null:
		_mesh.clear_surfaces()


## Adds one frame of the arc. `root` is the grip, `tip` the point of the blade.
func sample(root: Vector3, tip: Vector3) -> void:
	if _mesh == null:
		return
	if _roots.size() >= MAX_SAMPLES:
		_roots.remove_at(0)
		_tips.remove_at(0)
	_roots.append(root)
	_tips.append(tip)
	_fade_left = 0.0
	if _roots.size() >= 2:
		_rebuild(1.0)


## The cut is over: hold the ribbon where it is and let it fade.
func end() -> void:
	if _roots.size() < 2:
		clear()
		return
	_fade_left = FADE_TIME
	set_process(true)


## Whether the ribbon currently draws anything. Read by proofs and tests.
func is_trailing() -> bool:
	return visible and _mesh != null and _mesh.get_surface_count() > 0


## Drops the ribbon and stops its clock. Used on cancel, death and scene exit.
func clear() -> void:
	_roots.clear()
	_tips.clear()
	_fade_left = 0.0
	visible = false
	set_process(false)
	if _mesh != null:
		_mesh.clear_surfaces()


func _process(delta: float) -> void:
	if get_tree().paused or _fade_left <= 0.0:
		return
	_fade_left = maxf(_fade_left - delta, 0.0)
	if _fade_left <= 0.0:
		clear()
		return
	_rebuild(_fade_left / FADE_TIME)


func _rebuild(alpha: float) -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	if _roots.size() < 2 or alpha <= 0.0:
		visible = false
		return
	var count := _roots.size()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(count * 2)
	colors.resize(count * 2)
	for i in count:
		# Newest sample is brightest; the tail fades toward the grip.
		var tail := float(i + 1) / float(count)
		var a := (TAIL_ALPHA + (1.0 - TAIL_ALPHA) * pow(tail, 1.7)) * alpha
		vertices[i * 2] = _roots[i]
		vertices[i * 2 + 1] = _tips[i]
		colors[i * 2] = Color(ROOT_COLOR.r, ROOT_COLOR.g, ROOT_COLOR.b, a * 0.72)
		colors[i * 2 + 1] = Color(TIP_COLOR.r, TIP_COLOR.g, TIP_COLOR.b, a)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	visible = true
