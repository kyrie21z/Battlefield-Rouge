class_name CrownModel
extends Node3D
## Simple hollow six-point ivory crown with a restrained gold rim.
## The crown has no face, hands or character gestures.
const GEOMETRY_SCALE := Vector3(0.25, 0.23, 0.30)
const WEAR_OFFSET := Vector3(0, 0.10, 0.16) # Relative to the authored eye position.
const INNER_WIDTH := 0.17125
const INNER_DEPTH := 0.2055
var emission_strength := 0.5
var worn := false
var gold: StandardMaterial3D
var ivory: StandardMaterial3D

func _ready() -> void:
	gold = material(Color(0.68, 0.51, 0.25), 0.55, 0.34)
	gold.emission_enabled = true
	gold.emission = Color(0.75, 0.44, 0.12)
	ivory = material(Color(0.88, 0.85, 0.73), 0.15, 0.3)
	# Twelve beveled panels describe a hollow band, not a closed cylinder.
	for index in 12:
		var angle := TAU * index / 12
		var pivot := Node3D.new()
		pivot.rotation.y = angle
		# Apply physical dimensions before yaw so the complete band remains oval.
		add_child(pivot)
		var panel := slab(Vector3(0.23, 0.23, 0.075), ivory)
		panel.position = Vector3(0, 0, 0.38)
		pivot.add_child(panel)
		for y in [-0.12, 0.12]:
			var trim := slab(Vector3(0.245, 0.035, 0.09), gold)
			trim.position = Vector3(0, y, 0.38)
			pivot.add_child(trim)
		if index % 2 == 0:
			var tip := MeshInstance3D.new()
			var spike := PrismMesh.new()
			spike.size = Vector3(0.23, 0.36, 0.09)
			tip.mesh = spike
			tip.material_override = ivory
			tip.position = Vector3(0, 0.27, 0.39)
			pivot.add_child(tip)
	for part in get_children():
		part.transform = Transform3D(Basis.from_scale(GEOMETRY_SCALE),Vector3.ZERO) * part.transform
	set_emission_strength(emission_strength)
	set_worn(worn)

func set_worn(value: bool) -> void:
	worn = value
	for part in find_children("*", "MeshInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if worn \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

static func worn_transform(eye: Node3D) -> Transform3D:
	# The body sets the eye position from the animated skull. Camera pitch and
	# recoil rotate the eye node, so use the character's axes for the crown.
	var body_basis := eye.get_parent_node_3d().global_basis
	return Transform3D(body_basis, eye.global_position + body_basis * WEAR_OFFSET)

func set_emission_strength(value: float) -> void:
	emission_strength = maxf(value, 0.0)
	if is_instance_valid(gold):
		gold.emission_energy_multiplier = emission_strength

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
