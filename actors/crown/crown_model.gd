class_name CrownModel
extends Node3D
## Hollow six-point gold crystal crown shared by portraits, actors, and cinematics.
const MODEL: PackedScene = preload("res://assets/models/crown/pride_crown.glb")
const CRYSTAL: ShaderMaterial = preload("res://assets/materials/crown_crystal_material.tres")
const WEAR_OFFSET := Vector3(0, 0.10, 0.16) # Relative to the authored eye position.
const INNER_WIDTH := 0.134
const INNER_DEPTH := 0.160
var emission_strength := 0.5
var worn := false
var show_when_worn := false
var crystal_material: ShaderMaterial

func _ready() -> void:
	crystal_material = CRYSTAL.duplicate() as ShaderMaterial
	add_child(MODEL.instantiate())
	for mesh in find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = crystal_material
	set_emission_strength(emission_strength)
	set_worn(worn)

func set_worn(value: bool) -> void:
	worn = value
	for part in find_children("*", "MeshInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if worn and not show_when_worn \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

static func worn_transform(eye: Node3D) -> Transform3D:
	# The body sets the eye position from the animated skull. Camera pitch and
	# recoil rotate the eye node, so use the character's axes for the crown.
	var body_basis := eye.get_parent_node_3d().global_basis
	return Transform3D(body_basis, eye.global_position + body_basis * WEAR_OFFSET)

func set_emission_strength(value: float) -> void:
	emission_strength = maxf(value, 0.0)
	if crystal_material != null:
		crystal_material.set_shader_parameter("emission_strength", emission_strength)

static func material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result

static func slab(size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	return node
