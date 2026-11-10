class_name FlawlessVisual
extends SlothVisual
var guard_shell: MeshInstance3D
var blade: Node3D
var gun: Node3D
var crown_anchor: Node3D
var print_progress := 0.0
var shader_origin := 0.0
var printing := true
var _crown_offset := Vector3(0,0.10,0)
var crown_fit := Vector3.ONE
var head_bounds := AABB()
var head_mesh: MeshInstance3D
func _build() -> void:
	if _built:
		return
	_built = true
	_crystal = ShaderMaterial.new()
	_crystal.shader = preload("res://actors/boss/flawless_doppelganger/flawless.gdshader")
	model = BODY.instantiate() as Node3D
	add_child(model)
	model.scale = Vector3.ONE*1.18
	for child in model.find_children("*","MeshInstance3D",true,false):
		(child as MeshInstance3D).material_override = _crystal
		if String(child.name).to_lower().ends_with("_head"):
			head_mesh = child as MeshInstance3D
			head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in model.find_children("*","Skeleton3D",true,false):
		skeleton = child as Skeleton3D
		break
	_fit_crown_to_head()
	for child in model.find_children("*","AnimationPlayer",true,false):
		animation = child as AnimationPlayer
		break
	var library := animation.get_animation_library("").duplicate(true) as AnimationLibrary
	animation.remove_animation_library("")
	animation.add_animation_library("",library)
	for clip in ["idle","run","Aim"]:
		if animation.has_animation(clip):
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_outfit = Node3D.new()
	add_child(_outfit)
	_outfit.scale = model.scale
	gun = _equipment("RightHand","MirrorPistol",preload("res://assets/models/weapons/obsidian_pistol.glb"))
	blade = _equipment("LeftHand","AuroraBlade",preload("res://assets/models/weapons/mind_blade.glb"))
	blade.scale = Vector3.ONE*1.7
	guard_shell = MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = 1.35
	shell.height = 2.7
	shell.radial_segments = 20
	shell.rings = 10
	guard_shell.mesh = shell
	var shield_mat := StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.85,0.94,1.0,0.16)
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	guard_shell.material_override = shield_mat
	guard_shell.position.y = 1.15
	guard_shell.visible = false
	add_child(guard_shell)
	crown_anchor = Node3D.new()
	add_child(crown_anchor)
	play_motion("idle")
	animation.advance(0)
	_update_bones()
	_update_crown_anchor()
	set_print_progress(0)
func _equipment(bone: String,label: String,scene: PackedScene) -> Node3D:
	var follow := _follow(bone,label)
	var equipment := scene.instantiate() as Node3D
	follow.add_child(equipment)
	equipment.position = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin
	for child in equipment.find_children("*","MeshInstance3D",true,false):
		(child as MeshInstance3D).material_override = _crystal
	return equipment
func set_print_progress(value: float) -> void:
	print_progress = clampf(value,0,1)
	printing = print_progress < 1
	_crystal.set_shader_parameter("print_cutoff",shader_origin+lerpf(2.5,-0.2,print_progress) if printing else -100.0)
func set_guard(value: bool) -> void:
	guard_shell.visible = value and not _dead
	_crystal.set_shader_parameter("guard",1.0 if value else 0.0)
func play_motion(motion: String) -> void:
	if animation != null and not _dead and animation.has_animation(motion) and animation.current_animation != motion:
		animation.play(motion,0.08)
func _process(delta: float) -> void:
	if _dead:
		return
	var actor := get_parent() as Enemy
	if actor != null:
		animation.speed_scale = actor.boon_time_scale
		if actor.has_method("tempo_multiplier"):
			animation.speed_scale *= actor.call("tempo_multiplier")
		if actor.boon_stunned:
			animation.speed_scale = 0
	_time += delta
	_update_bones()
	_update_crown_anchor()
func _update_crown_anchor() -> void:
	var head := skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Head"))
	# Follow the real head pose without scaling the shared, true-size crown.
	var axes := head.basis.orthonormalized()
	crown_anchor.global_transform = Transform3D(axes,head.origin+axes*_crown_offset)
func _fit_crown_to_head() -> void:
	# Imported mesh axes differ from head-bone axes. Evaluate the actual skin
	# bindings once so height/depth cannot be accidentally exchanged.
	var inverse := skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse()
	var points: Array[Vector3] = []
	for surface in head_mesh.mesh.get_surface_count():
		var arrays := head_mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences := bones.size()/vertices.size()
		for vertex in vertices.size():
			var point := Vector3.ZERO
			for slot in influences:
				var index := vertex*influences+slot
				if weights[index] <= 0:
					continue
				var bind := bones[index]
				var bone := skeleton.find_bone(head_mesh.skin.get_bind_name(bind))
				var transform_value := inverse*skeleton.get_bone_global_rest(bone)*head_mesh.skin.get_bind_pose(bind)
				point += (transform_value*vertices[vertex])*weights[index]
			points.append(point*model.scale)
	head_bounds = AABB(points[0],Vector3.ZERO)
	for point in points:
		head_bounds = head_bounds.expand(point)
	var top := head_bounds.end.y
	var upper: Array[Vector3] = []
	for point in points:
		if point.y >= top-head_bounds.size.y*0.4:
			upper.append(point)
	var band := AABB(upper[0],Vector3.ZERO)
	for point in upper:
		band = band.expand(point)
	crown_fit = Vector3(band.size.x*1.04/CrownModel.INNER_WIDTH,1,band.size.z*1.04/CrownModel.INNER_DEPTH)
	_crown_offset = Vector3(band.get_center().x,top-0.025,band.get_center().z)
func die(point := Vector3.INF,direction := Vector3.FORWARD) -> void:
	if _dead:
		return
	_dead = true
	animation.stop()
	guard_shell.hide()
	shatter = WrathShatter.new()
	get_parent().get_parent().add_child(shatter)
	shatter.build(self,global_position+Vector3.UP if point == Vector3.INF else point,direction)
	model.hide()
	_outfit.hide()
