extends Node3D
## 红晶体敌人的动画与碎裂预览场（不是游戏主场景）。
##
## 从 tools/crystal_enemy/anim_shatter.tscn 运行，三种用法：
##   godot --path . res://tools/crystal_enemy/anim_shatter.tscn
##       → 有窗口，← → 切 23 个剪辑，1 爆头，2 断左臂，3 断左腿，4 全身碎裂，R 复位
##   godot --headless --path . res://tools/crystal_enemy/anim_shatter.tscn -- --check
##       → 只读模型和碎片库，逐项打印实际结构，全部符合预期时退出码 0
##   godot --path . res://tools/crystal_enemy/anim_shatter.tscn -- --anim=walk --fx=head --shot=<绝对路径>.png
##       → 摆好姿势/碎好后截图再退出（截图要真窗口，headless 没有渲染器）
##
## 模型用 animated.glb（11 件蒙皮网格 + 24 骨 + 23 个剪辑），碎屑用 shards.glb（56 片，
## 按部位分组命名）。碎片是按 T-pose 模型空间导出的，贴到当前动画姿势要乘骨骼增量
## `bone_global_pose · bone_global_rest⁻¹`，见 _bone_delta()。

const MODEL: PackedScene = preload("res://assets/models/characters/red_crystal_enemy_animated.glb")
const SHARDS: PackedScene = preload("res://assets/models/characters/red_crystal_enemy_shards.glb")
const MAT_BODY: Material = preload("res://assets/materials/red_crystal_material_shader.tres")
const MAT_SHARD: Material = preload("res://assets/materials/red_crystal_material_shard.tres")

## 部位名（GEO_m_xxx / SHARD_m_xxx_0 里的 xxx）→ 该部位主骨
const PART_BONE := {
	"head": "Head",
	"torso": "Spine",
	"hips": "Hips",
	"upper_arm_L": "LeftArm",
	"upper_arm_R": "RightArm",
	"forearm_L": "LeftForeArm",
	"forearm_R": "RightForeArm",
	"thigh_L": "LeftUpLeg",
	"thigh_R": "RightUpLeg",
	"shin_L": "LeftLeg",
	"shin_R": "RightLeg",
}
## 爆头 / 断左臂 / 断左腿，对应游戏里的按部位碎裂
const FX_HEAD: Array[String] = ["head"]
const FX_ARM: Array[String] = ["upper_arm_L", "forearm_L"]
const FX_LEG: Array[String] = ["thigh_L", "shin_L"]

## --check 的期望值（来自导出时的实测规格）
const EXPECT_ANIMS := 23
const EXPECT_BONES := 24
const EXPECT_MESHES := 11
const EXPECT_VERTS := 5155
const EXPECT_SHARDS := 56
const EXPECT_GROUPS := 11

@export var cycle_seconds := 3.0
@export var shard_speed := 1.6

var _model: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _names: Array = []
var _idx := 0
var _timer := 0.0

var _part_node := {}      # 部位 -> 动画模型里的 MeshInstance3D
var _shard_groups := {}   # 部位 -> [{mesh, xf}]
var _bodies: Array[RigidBody3D] = []

var _cam: Camera3D
var _hud: Label
var _yaw := 3.58      # 面朝 −Z，相机放到模型正面一侧
var _pitch := -0.08
var _dist := 4.4

var _shot_path := ""
var _shot_frames := 90


func _ready() -> void:
	_build_environment()
	_build_floor()
	_spawn_model()
	_load_shard_library()
	_build_camera()
	_build_hud()
	_parse_args()


func _spawn_model() -> void:
	var inst: Node = MODEL.instantiate()
	inst.name = "RedCrystalEnemy"
	add_child(inst)
	_model = inst as Node3D
	_apply_material(inst, MAT_BODY)

	for n in inst.find_children("*", "Skeleton3D", true, false):
		_skel = n as Skeleton3D
		break
	for n in inst.find_children("*", "AnimationPlayer", true, false):
		_anim = n as AnimationPlayer
		break
	if _anim != null:
		_names = _anim.get_animation_list()
	if not _names.is_empty():
		_play(0)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var part := _part_key(String(n.name))
		if part != "":
			_part_node[part] = n
	print("[demo] 动画 %d 个，骨骼 %d 根，部位网格 %d 件" % [
		_names.size(), 0 if _skel == null else _skel.get_bone_count(), _part_node.size()])


func _load_shard_library() -> void:
	var lib: Node = SHARDS.instantiate()
	var total := 0
	for n in lib.find_children("*", "MeshInstance3D", true, false):
		var part := _part_key(String(n.name))
		if part == "":
			continue
		if not _shard_groups.has(part):
			_shard_groups[part] = []
		_shard_groups[part].append({"mesh": (n as MeshInstance3D).mesh, "xf": (n as Node3D).transform})
		total += 1
	lib.free()
	print("[demo] 碎片库 %d 部位 / %d 片" % [_shard_groups.size(), total])


## GEO_m_head → head；SHARD_m_upper_arm_L_3 → upper_arm_L
func _part_key(node_name: String) -> String:
	if node_name.begins_with("GEO_m_"):
		return node_name.substr(6)
	if node_name.begins_with("SHARD_m_"):
		var rest := node_name.substr(8)
		var cut := rest.rfind("_")
		return rest if cut < 0 else rest.substr(0, cut)
	return ""


func _bone_delta(part: String) -> Transform3D:
	if _skel == null or not PART_BONE.has(part):
		return Transform3D.IDENTITY
	var b := _skel.find_bone(PART_BONE[part])
	if b < 0:
		return Transform3D.IDENTITY
	return _skel.get_bone_global_pose(b) * _skel.get_bone_global_rest(b).affine_inverse()


func _bone_pose(part: String) -> Transform3D:
	if _skel == null or not PART_BONE.has(part):
		return Transform3D.IDENTITY
	var b := _skel.find_bone(PART_BONE[part])
	if b < 0:
		return Transform3D.IDENTITY
	return _skel.get_bone_global_pose(b)


## 把一个部位换成碎片刚体飞出去，其余部位继续动（对应游戏里的按部位碎裂）
func shatter_part(part: String) -> int:
	if not _shard_groups.has(part):
		push_warning("没有这个部位的碎片：%s" % part)
		return 0
	var delta := _bone_delta(part)
	var center := _bone_pose(part).origin
	var spawned := 0
	for s in _shard_groups[part]:
		_spawn_shard(s["mesh"], delta * (s["xf"] as Transform3D), center)
		spawned += 1
	if _part_node.has(part):
		(_part_node[part] as MeshInstance3D).visible = false
	return spawned


func shatter_parts(parts: Array) -> int:
	var spawned := 0
	for part in parts:
		spawned += shatter_part(String(part))
	return spawned


func shatter_all() -> int:
	return shatter_parts(_shard_groups.keys())


func reset_shards() -> void:
	for b in _bodies:
		if is_instance_valid(b):
			b.queue_free()
	_bodies.clear()
	for part in _part_node.keys():
		(_part_node[part] as MeshInstance3D).visible = true


func _spawn_shard(mesh: Mesh, xf: Transform3D, center: Vector3) -> void:
	var rb := RigidBody3D.new()
	rb.mass = 0.2
	rb.gravity_scale = 1.6
	rb.linear_damp = 1.2
	rb.angular_damp = 1.0

	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	cs.shape = shape
	rb.add_child(cs)

	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = MAT_SHARD
	rb.add_child(vis)

	var world: Transform3D = _model.global_transform * xf
	rb.global_transform = world
	add_child(rb)

	var dir := world.origin - (_model.global_transform * center)
	if dir.length() < 0.01:
		dir = Vector3.UP
	rb.linear_velocity = dir.normalized() * shard_speed * randf_range(0.6, 1.25) \
		+ Vector3.UP * randf_range(0.2, 0.9)
	rb.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 1.6
	_bodies.append(rb)


func _apply_fx(fx: String) -> int:
	match fx:
		"head":
			return shatter_parts(FX_HEAD)
		"arm":
			return shatter_parts(FX_ARM)
		"leg":
			return shatter_parts(FX_LEG)
		"all":
			return shatter_all()
	push_warning("不认识的 --fx=%s（可用 head / arm / leg / all）" % fx)
	return 0


func _parse_args() -> void:
	var check := false
	var want_anim := ""
	var want_fx := ""
	for a in OS.get_cmdline_user_args():
		if a == "--check":
			check = true
		elif a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--shotframes="):
			_shot_frames = int(a.substr(13))
		elif a.begins_with("--anim="):
			want_anim = a.substr(7)
		elif a.begins_with("--fx="):
			want_fx = a.substr(5)
		elif a.begins_with("--yaw="):
			_yaw = float(a.substr(6))
		elif a.begins_with("--pitch="):
			_pitch = float(a.substr(8))
		elif a.begins_with("--dist="):
			_dist = float(a.substr(7))
	_update_camera()
	if want_anim != "":
		var i := _names.find(want_anim)
		if i < 0:
			i = _names.find(want_anim.capitalize())
		if i < 0:
			push_warning("没有这个剪辑：%s" % want_anim)
		else:
			_play(i)
			_timer = -1.0e9
	if want_fx != "":
		_apply_fx(want_fx)
	if check:
		_run_check()


## --check：只读资源并打印实际结构，退出码非 0 表示和导出规格不符
func _run_check() -> void:
	var fails: Array[String] = []
	var anims: Array = [] if _anim == null else _anim.get_animation_list()
	if anims.size() != EXPECT_ANIMS:
		fails.append("动画 %d 个，期望 %d" % [anims.size(), EXPECT_ANIMS])
	for name in anims:
		var clip := _anim.get_animation(String(name))
		print("[check] anim %-16s %6.3fs tracks=%d" % [name, clip.length, clip.get_track_count()])

	var bones := 0 if _skel == null else _skel.get_bone_count()
	if bones != EXPECT_BONES:
		fails.append("骨骼 %d 根，期望 %d" % [bones, EXPECT_BONES])

	var meshes := 0
	var verts := 0
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		meshes += 1
		for s in mi.mesh.get_surface_count():
			verts += mi.mesh.surface_get_array_len(s)
	if meshes != EXPECT_MESHES:
		fails.append("部位网格 %d 件，期望 %d" % [meshes, EXPECT_MESHES])
	if verts != EXPECT_VERTS:
		fails.append("顶点 %d，期望 %d" % [verts, EXPECT_VERTS])

	var total := 0
	for part in _shard_groups.keys():
		var n: int = _shard_groups[part].size()
		total += n
		print("[check] shard %-14s %2d 片" % [part, n])
		if not PART_BONE.has(part):
			fails.append("碎片部位 %s 没有对应的骨" % part)
		if not _part_node.has(part):
			fails.append("碎片部位 %s 在模型里找不到同名网格" % part)
	if total != EXPECT_SHARDS:
		fails.append("碎片 %d 片，期望 %d" % [total, EXPECT_SHARDS])
	if _shard_groups.size() != EXPECT_GROUPS:
		fails.append("碎片分组 %d 组，期望 %d" % [_shard_groups.size(), EXPECT_GROUPS])

	var head := shatter_parts(FX_HEAD)
	if head != _shard_groups["head"].size() or _bodies.size() != _shard_groups["head"].size():
		fails.append("爆头生成 %d 片刚体，期望 %d" % [_bodies.size(), _shard_groups["head"].size()])
	reset_shards()
	var all_parts := shatter_all()
	if all_parts != EXPECT_SHARDS or _bodies.size() != EXPECT_SHARDS:
		fails.append("全身碎裂生成 %d 片刚体，期望 %d" % [_bodies.size(), EXPECT_SHARDS])
	reset_shards()

	if fails.is_empty():
		print("[check] OK 动画=%d 骨骼=%d 网格=%d 顶点=%d 碎片=%d 分组=%d" % [
			anims.size(), bones, meshes, verts, total, _shard_groups.size()])
		get_tree().quit(0)
	else:
		for f in fails:
			printerr("[check] FAIL ", f)
		get_tree().quit(1)


func _play(i: int) -> void:
	if _names.is_empty():
		return
	_idx = wrapi(i, 0, _names.size())
	_anim.play(String(_names[_idx]))
	_refresh_hud()


func _process(delta: float) -> void:
	_timer += delta
	if _shot_path == "" and _names.size() > 1 and _timer > cycle_seconds:
		_timer = 0.0
		_play(_idx + 1)
	if _shot_path != "":
		_shot_frames -= 1
		if _shot_frames <= 0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_path)
			print("[demo] shot saved: ", _shot_path)
			_shot_path = ""
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT:
				_timer = 0.0
				_play(_idx + 1)
			KEY_LEFT:
				_timer = 0.0
				_play(_idx - 1)
			KEY_1:
				shatter_parts(FX_HEAD)
			KEY_2:
				shatter_parts(FX_ARM)
			KEY_3:
				shatter_parts(FX_LEG)
			KEY_4:
				shatter_all()
			KEY_R:
				reset_shards()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_yaw -= event.relative.x * 0.01
		_pitch = clamp(_pitch - event.relative.y * 0.01, -1.2, 1.2)
		_update_camera()


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.fov = 45.0
	add_child(_cam)
	_update_camera()
	_cam.current = true


func _update_camera() -> void:
	if _cam == null:
		return
	var off := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch) + 0.35, cos(_yaw) * cos(_pitch)) * _dist
	_cam.position = Vector3(0, 0.95, 0) + off
	_cam.look_at(Vector3(0, 0.95, 0))


func _build_hud() -> void:
	_hud = Label.new()
	_hud.name = "Hud"
	_hud.position = Vector2(20, 14)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.add_theme_color_override("font_color", Color(1, 0.72, 0.68))
	add_child(_hud)
	_refresh_hud()


func _refresh_hud() -> void:
	if _hud == null:
		return
	var nm := "-" if _names.is_empty() else String(_names[_idx])
	_hud.text = "动画 %s (%d/%d)  ← → 切换 | 1 爆头 2 断臂 3 断腿 4 全碎 R 复位 | 左键拖动转视角" % [
		nm, _idx + 1, _names.size()]


func _apply_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		_apply_material(c, mat)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.038, 0.048)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.36, 0.42)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.28
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
	rim.light_energy = 0.9
	rim.light_color = Color(1, 0.45, 0.35)
	rim.rotation_degrees = Vector3(-25, 200, 0)
	add_child(rim)


func _build_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.12, 0.125, 0.14)
	fm.roughness = 0.85
	floor_mesh.material_override = fm
	floor_mesh.position = Vector3(0, -0.002, 0)
	add_child(floor_mesh)

	# 碎片要能落在地面上
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	cs.shape = box
	cs.position = Vector3(0, -0.1, 0)
	body.add_child(cs)
	add_child(body)
