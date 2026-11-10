class_name BodyFracture
extends Node
## Fractures the original rig and its 56 authored shards. Derived render meshes
## only add facet-edge attributes; original GLB geometry/resources stay untouched.

const SHARDS := preload("res://assets/models/characters/red_crystal_enemy_shards.glb")
const CRYSTAL := preload("res://assets/materials/protagonist_crystal_material.tres")
const FRACTURE_SHADER := preload("res://actors/player/body_fracture.gdshader")
const SEAMS := preload("res://actors/player/crystal_seams.gd")
const PART_BONE := {"head": "Head", "torso": "Spine", "hips": "Hips",
	"upper_arm_L": "LeftArm", "upper_arm_R": "RightArm", "forearm_L": "LeftForeArm",
	"forearm_R": "RightForeArm", "thigh_L": "LeftUpLeg", "thigh_R": "RightUpLeg",
	"shin_L": "LeftLeg", "shin_R": "RightLeg"}
const MATERIAL_PARAMETERS := ["base_color", "emission_color", "emission_strength",
	"rim_color", "rim_strength", "rim_power", "spec_color", "specular_amount",
	"roughness_value", "inner_glow"]

@export_range(0, 4) var fracture_level := 0
@export var enable_debug_keys := false
var fracture_materials: Array[ShaderMaterial] = []
var fragments: Array[Dictionary] = []
var source_meshes: Dictionary = {}
var _model: Node3D
var _skeleton: Skeleton3D
var _age := 0.0
var _wrist_rest := Vector3.ZERO


func _ready() -> void:
	Events.sin_defeated.connect(set_fracture_level)


func _exit_tree() -> void:
	if is_instance_valid(_skeleton) and _skeleton.skeleton_updated.is_connected(_update_pose):
		_skeleton.skeleton_updated.disconnect(_update_pose)
	if Events.sin_defeated.is_connected(set_fracture_level):
		Events.sin_defeated.disconnect(set_fracture_level)


func setup(model: Node3D, skeleton: Skeleton3D) -> void:
	assert(_model == null, "BodyFracture.setup must be called once")
	_model = model
	_skeleton = skeleton
	_wrist_rest = skeleton.get_bone_global_rest(skeleton.find_bone("LeftHand")).origin
	for node in model.find_children("GEO_m_*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var part := String(mesh.name).trim_prefix("GEO_m_")
		if not PART_BONE.has(part):
			continue
		var material := _make_material(part)
		source_meshes[part] = {"node": mesh, "material": material,
			"bone": skeleton.find_bone(PART_BONE[part]), "visible": mesh.visible,
			"original_mesh": mesh.mesh, "seam_mesh": SEAMS.with_seam_attributes(mesh.mesh),
			"original_material": mesh.material_override, "original_overlay": mesh.material_overlay}
	_build_fragments()
	_skeleton.skeleton_updated.connect(_update_pose)
	set_fracture_level(fracture_level)


func set_fracture_level(level: int) -> void:
	fracture_level = clampi(level, 0, 4)
	for material in fracture_materials:
		material.set_shader_parameter("fracture_level", fracture_level)
	for part: String in source_meshes:
		var entry: Dictionary = source_meshes[part]
		var mesh := entry.node as MeshInstance3D
		if not is_instance_valid(mesh) or not mesh.is_inside_tree():
			continue
		mesh.visible = entry.visible and not _uses_fragments(part)
		mesh.mesh = entry.original_mesh if fracture_level == 0 else entry.seam_mesh
		mesh.material_override = entry.original_material if fracture_level == 0 else entry.material
		mesh.material_overlay = entry.original_overlay if fracture_level == 0 else null
	_update_pose()


func _unhandled_key_input(event: InputEvent) -> void:
	if not enable_debug_keys or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code >= KEY_0 and code <= KEY_4:
		set_fracture_level(code - KEY_0)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_age += delta
	_update_pose()


func _uses_fragments(part: String) -> bool:
	# Keep the rigged torso (the library has only one torso piece) and head.
	# Head must remain shadow-only even at the final fracture state.
	if part == "torso" or part == "head":
		return false
	return fracture_level >= (3 if "arm" in part else 4)


func _update_pose() -> void:
	# The imported model can leave the tree before this sibling component when
	# a zone is replaced. Bone callbacks must stop before reading world poses.
	if not is_inside_tree() or not is_instance_valid(_skeleton) or not _skeleton.is_inside_tree():
		return
	if not is_instance_valid(_model) or not _model.is_inside_tree():
		return
	var skeleton_from_world := _skeleton.global_transform.affine_inverse()
	for part: String in source_meshes:
		var entry: Dictionary = source_meshes[part]
		if not is_instance_valid(entry.node) or not entry.node.is_inside_tree():
			continue
		var rest := _skeleton.get_bone_global_rest(entry.bone)
		var pose := _skeleton.get_bone_global_pose(entry.bone)
		(entry.material as ShaderMaterial).set_shader_parameter("rest_from_world",
			rest * pose.affine_inverse() * skeleton_from_world)
	for fragment in fragments:
		var piece := fragment.node as MeshInstance3D
		if not is_instance_valid(piece) or not piece.is_inside_tree():
			continue
		var entry: Dictionary = source_meshes[fragment.part]
		piece.visible = entry.visible and _uses_fragments(fragment.part)
		if not piece.visible:
			continue
		var bone: int = fragment.bone
		var delta := _skeleton.get_bone_global_pose(bone) * _skeleton.get_bone_global_rest(bone).affine_inverse()
		var rest: Transform3D = fragment.rest
		var posed := _skeleton.global_transform * delta * rest
		var index: int = fragment.index
		var loose := index % 3 == 1 if fracture_level == 3 else index % 2 == 0
		if loose:
			var separation := 0.0025 if fracture_level == 3 else 0.0045
			var direction := Vector3(signf(rest.origin.x) * 0.65, 0.18, -0.74).normalized()
			posed.origin += (_skeleton.global_basis * delta.basis * direction).normalized() * separation * (1.0 + 0.10 * sin(_age * 1.7 + index))
		piece.global_transform = posed
		(piece.material_override as ShaderMaterial).set_shader_parameter("rest_from_world",
			rest * posed.affine_inverse())


func _make_material(part: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FRACTURE_SHADER
	for parameter in MATERIAL_PARAMETERS:
		material.set_shader_parameter(parameter, CRYSTAL.get_shader_parameter(parameter))
	var kind := 1 if part == "forearm_L" else (2 if part == "torso" else (3 if "arm" in part else 0))
	material.set_shader_parameter("body_part", kind)
	material.set_shader_parameter("wrist_position", _wrist_rest)
	fracture_materials.append(material)
	return material


func _build_fragments() -> void:
	var library := SHARDS.instantiate() as Node3D
	for node in library.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		var key := String(source.name).trim_prefix("SHARD_m_")
		var part := key.substr(0, key.rfind("_"))
		if not source_meshes.has(part):
			continue
		var piece := MeshInstance3D.new()
		piece.name = source.name
		piece.mesh = SEAMS.with_seam_attributes(source.mesh)
		piece.material_override = _make_material(part)
		piece.cast_shadow = (source_meshes[part].node as MeshInstance3D).cast_shadow
		piece.visible = false
		_model.add_child(piece)
		var bone: int = source_meshes[part].bone
		if part == "forearm_L" or part == "forearm_R":
			var hand := _skeleton.find_bone("LeftHand" if part == "forearm_L" else "RightHand")
			var wrist := _skeleton.get_bone_global_rest(hand).origin
			# The original distal palm shard follows Hand, whose orientation is
			# independently solved around the pistol grip. Forearm-only attachment
			# would leave the hand pointing past the grip at late fracture levels.
			if absf(source.position.x) > absf(wrist.x):
				bone = hand
		fragments.append({"node": piece, "part": part, "rest": source.transform,
			"original_mesh": source.mesh,
			"bone": bone,
			"index": int(key.get_slice("_", key.get_slice_count("_") - 1))})
	library.free()
