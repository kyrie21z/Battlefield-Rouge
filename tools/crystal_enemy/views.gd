extends Node3D
## 给三个 GLB 各拍前 / 侧 / 头三视角，用来出 docs/proof/crystal-enemy 里的对照图。
## 要真实窗口（headless 没有渲染器）：
##   godot --path . --resolution 760x950 res://tools/crystal_enemy/views.tscn -- --out=<输出目录>
## 图落在 <输出目录>/<版本>_<视角>.png，三版本拍完自己退出。

const MODELS := {
	"static": "res://assets/models/characters/red_crystal_enemy_static.glb",
	"rigged": "res://assets/models/characters/red_crystal_enemy_rigged.glb",
	"parts": "res://assets/models/characters/red_crystal_enemy_parts.glb",
}
const SHOTS := [
	{"name": "front", "from": Vector3(0.0, 1.00, 4.40), "look": Vector3(0.0, 0.97, 0.0)},
	{"name": "side", "from": Vector3(4.40, 1.00, 0.0), "look": Vector3(0.0, 0.97, 0.0)},
	{"name": "head", "from": Vector3(0.00, 1.78, 1.30), "look": Vector3(0.0, 1.75, 0.0)},
]

var _out_dir := ""
var _order: Array[String] = ["static", "rigged", "parts"]
var _mi := 0
var _si := 0
var _wait := -1
var _cam: Camera3D
var _holder: Node3D
var _mat: Material


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out_dir = a.substr(6)
	_build_environment()
	_build_floor()
	_mat = load("res://assets/materials/red_crystal_material_shader.tres")
	_holder = Node3D.new()
	add_child(_holder)
	_cam = Camera3D.new()
	_cam.fov = 35.0
	add_child(_cam)
	_cam.current = true
	_spawn()
	_aim()


func _spawn() -> void:
	for c in _holder.get_children():
		c.queue_free()
	var inst: Node = load(MODELS[_order[_mi]]).instantiate()
	_holder.add_child(inst)
	_override(inst, _mat)
	print("[views] %s -> %s" % [_order[_mi], _describe(inst)])


func _aim() -> void:
	var s: Dictionary = SHOTS[_si]
	_cam.position = s["from"]
	_cam.look_at(s["look"])
	_wait = 8


func _process(_delta: float) -> void:
	if _wait < 0:
		return
	_wait -= 1
	if _wait > 0:
		return
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [_out_dir, _order[_mi], SHOTS[_si]["name"]]
	img.save_png(path)
	print("[views] saved ", path)
	_si += 1
	if _si < SHOTS.size():
		_aim()
		return
	_si = 0
	_mi += 1
	if _mi < _order.size():
		_spawn()
		_aim()
		return
	get_tree().quit()


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.038, 0.048)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.36, 0.42)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.35
	key.light_color = Color(1, 0.96, 0.94)
	key.rotation_degrees = Vector3(-42, 38, 0)
	key.shadow_enabled = true
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.8
	rim.light_color = Color(1, 0.45, 0.35)
	rim.rotation_degrees = Vector3(-25, 200, 0)
	add_child(rim)


func _build_floor() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(18, 18)
	mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.12, 0.125, 0.14)
	fm.roughness = 0.85
	mi.material_override = fm
	mi.position = Vector3(0, -0.001, 0)
	add_child(mi)


func _override(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for c in node.get_children():
		_override(c, mat)


func _describe(node: Node) -> String:
	var meshes := 0
	var bones := 0
	var verts := 0
	var stack: Array[Node] = [node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes += 1
			if n.mesh != null:
				for s in n.mesh.get_surface_count():
					verts += n.mesh.surface_get_array_len(s)
		elif n is Skeleton3D:
			bones += n.get_bone_count()
		stack.append_array(n.get_children())
	return "meshes=%d verts=%d bones=%d" % [meshes, verts, bones]
