extends Node3D
## 红晶体敌人素材的预览场（不是游戏主场景）
## 从 tools/crystal_enemy/gallery.tscn 运行：static / rigged / parts 三个版本并排，镜头自动环绕。
## 出图用 `-- --shot=绝对路径.png`，脚本等 90 帧后截图退出。
## 要在游戏里用：把 assets/models/characters/red_crystal_enemy_*.glb 拖进场景，材质用
## assets/materials/red_crystal_material.tres 或 red_crystal_material_shader.tres 覆盖。

const MODELS: Array[String] = [
	"res://assets/models/characters/red_crystal_enemy_static.glb",
	"res://assets/models/characters/red_crystal_enemy_rigged.glb",
	"res://assets/models/characters/red_crystal_enemy_parts.glb",
]
const LABELS: Array[String] = ["static (单网格)", "rigged (24 骨)", "parts (11 部件)"]

@export var spacing := 1.55
@export var spin_speed := 0.35
@export var cam_distance := 6.3
@export var cam_height := 1.6
@export var use_shader_material := true

var _pivot: Node3D
var _spawned: Array[Node] = []
var _shot_path := ""
var _shot_frames := 90


func _ready() -> void:
	_build_environment()
	_build_floor()
	_pivot = Node3D.new()
	_pivot.name = "Turntable"
	add_child(_pivot)

	var mat := _load_material()
	for i in MODELS.size():
		var ps: PackedScene = load(MODELS[i])
		if ps == null:
			push_warning("加载失败：%s" % MODELS[i])
			continue
		var inst: Node = ps.instantiate()
		inst.name = "Enemy_%d" % i
		inst.position = Vector3((i - (MODELS.size() - 1) * 0.5) * spacing, 0.0, 0.0)
		_pivot.add_child(inst)
		_spawned.append(inst)
		if mat != null:
			_override_material(inst, mat)
		_make_label(LABELS[i], inst.position)
		print("[demo] %s -> %s" % [MODELS[i], _describe(inst)])

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 42.0
	add_child(cam)
	cam.position = Vector3(0, cam_height, cam_distance)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotate_y(spin_speed * delta)
	if _shot_path != "":
		_shot_frames -= 1
		if _shot_frames <= 0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_path)
			print("[demo] shot saved: ", _shot_path)
			_shot_path = ""
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
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.0
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_energy = 1.35
	key.light_color = Color(1, 0.96, 0.94)
	key.rotation_degrees = Vector3(-42, 38, 0)
	key.shadow_enabled = true
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.light_energy = 0.8
	rim.light_color = Color(1, 0.45, 0.35)
	rim.rotation_degrees = Vector3(-25, 200, 0)
	add_child(rim)


func _build_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(18, 18)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.12, 0.125, 0.14)
	fm.roughness = 0.85
	floor_mesh.material_override = fm
	floor_mesh.position = Vector3(0, -0.001, 0)
	add_child(floor_mesh)


func _load_material() -> Material:
	var path := "res://assets/materials/red_crystal_material_shader.tres" if use_shader_material \
		else "res://assets/materials/red_crystal_material.tres"
	var m: Material = load(path)
	if m == null:
		push_warning("材质加载失败：%s" % path)
	return m


func _override_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for c in node.get_children():
		_override_material(c, mat)


func _make_label(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.0042
	l.modulate = Color(1, 0.55, 0.5)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.position = at + Vector3(0, 2.32, 0)
	add_child(l)


func _describe(node: Node) -> String:
	var meshes := 0
	var skeleton := 0
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
			skeleton += 1
			bones += n.get_bone_count()
		stack.append_array(n.get_children())
	return "meshes=%d verts=%d skeleton=%d bones=%d" % [meshes, verts, skeleton, bones]
