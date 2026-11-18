class_name SlothShatter
extends Node3D
## Reuses all 56 authored crystal shards at the CURRENT skeleton pose.
## The impact point orders the fracture; visual physics never consumes gameplay RNG.
const SHARDS := preload("res://assets/models/characters/red_crystal_enemy_shards.glb")
const RESERVE_KEY := &"sloth_prepared_shatter"
static var _templates: Array[Dictionary] = []
const PART_BONE := {"head":"Head", "torso":"Spine", "hips":"Hips",
	"upper_arm_L":"LeftArm", "upper_arm_R":"RightArm", "forearm_L":"LeftForeArm",
	"forearm_R":"RightForeArm", "thigh_L":"LeftUpLeg", "thigh_R":"RightUpLeg",
	"shin_L":"LeftLeg", "shin_R":"RightLeg"}
var impact_point := Vector3.ZERO
var impact_direction := Vector3.FORWARD
var first_part := ""
var fragments: Array[Dictionary] = []
var elapsed := 0.0
var started := false
var _material: ShaderMaterial


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


static func prepare_for(visual: Node3D, source: ShaderMaterial) -> SlothShatter:
	var existing := visual.get_meta(RESERVE_KEY) as SlothShatter if visual.has_meta(RESERVE_KEY) else null
	if is_instance_valid(existing):
		return existing
	var burst := SlothShatter.new()
	burst.prepare(source)
	visual.set_meta(RESERVE_KEY, burst)
	visual.tree_exiting.connect(burst._discard_unused, CONNECT_ONE_SHOT)
	return burst


static func take(visual: Node3D, source: ShaderMaterial) -> SlothShatter:
	var burst := prepare_for(visual, source)
	visual.remove_meta(RESERVE_KEY)
	return burst


func _discard_unused() -> void:
	if not started:
		queue_free()


static func prepare_templates() -> void:
	if not _templates.is_empty():
		return
	var library := SHARDS.instantiate()
	for child in library.find_children("*","MeshInstance3D",true,false):
		var source := child as MeshInstance3D
		var key := String(source.name).trim_prefix("SHARD_m_")
		_templates.append({"mesh":source.mesh,"transform":source.transform,
			"part":key.substr(0,key.rfind("_"))})
	library.free()


func prepare(source: ShaderMaterial) -> void:
	if not fragments.is_empty():
		return
	prepare_templates()
	_material = source.duplicate() as ShaderMaterial
	for template in _templates:
		var piece := MeshInstance3D.new()
		piece.mesh = template.mesh
		piece.material_override = _material
		piece.visible = false
		add_child(piece)
		fragments.append({"node":piece, "part":template.part, "distance":0.0,
			"delay":0.0, "released":false, "velocity":Vector3.ZERO, "spin":Vector3.ZERO})
	hide()
	set_physics_process(false)


func build(visual: SlothVisual, point: Vector3, direction: Vector3) -> void:
	impact_point = point
	impact_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	prepare(visual.crystal_material())
	var source := visual.crystal_material()
	for parameter in ["base_color", "rim_color", "emission_color", "emission_strength", "rim_strength", "inner_glow", "spec_color", "roughness_value"]:
		var val: Variant = source.get_shader_parameter(parameter)
		if val != null:
			_material.set_shader_parameter(parameter, val)
	_material.set_shader_parameter("rim_strength", 0.22)
	var poses := {}
	var nearest := INF
	for index in _templates.size():
		var template: Dictionary = _templates[index]
		var part: String = template.part
		var bone := visual.skeleton.find_bone(PART_BONE.get(part, "Spine"))
		if not poses.has(bone):
			poses[bone] = visual.skeleton.get_bone_global_pose(bone) * visual.skeleton.get_bone_global_rest(bone).affine_inverse() if bone >= 0 else Transform3D.IDENTITY
		var xf: Transform3D = visual.model.global_transform * poses[bone] * (template.transform as Transform3D)
		var fragment := fragments[index]
		var piece := fragment["node"] as MeshInstance3D
		piece.global_transform = xf
		piece.visible = true
		var distance := xf.origin.distance_to(point)
		if distance < nearest:
			nearest = distance
			first_part = part
		var scatter := Vector3(sin(index * 2.4), 0.6 + cos(index * 1.3) * 0.2, cos(index * 2.4))
		var away := (xf.origin - point).normalized()
		fragment["part"] = part
		fragment["distance"] = distance
		fragment["delay"] = 0.0
		fragment["released"] = false
		fragment["velocity"] = away * 1.3 + impact_direction * 1.6 + scatter * 0.6
		fragment["spin"] = Vector3(cos(index), sin(index * 2.2), 0.7) * 2.0
	for fragment in fragments:
		fragment["delay"] = minf(0.12, maxf(0.0, fragment["distance"] - nearest) * 0.065)
	# Contact shards begin immediately; the rest follow within 120 ms.
	for fragment in fragments:
		if fragment["delay"] < 0.001:
			fragment["released"] = true
	started = true
	show()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	elapsed += delta
	for fragment in fragments:
		var piece := fragment["node"] as MeshInstance3D
		if elapsed < fragment["delay"]:
			continue
		fragment["released"] = true
		var velocity: Vector3 = fragment["velocity"]
		velocity.y -= 6.5 * delta
		var from := piece.global_position
		var to := from + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			to = hit.position + hit.normal * 0.015
			velocity = velocity.bounce(hit.normal) * 0.22
		piece.global_position = to
		piece.rotate_x(fragment["spin"].x * delta)
		piece.rotate_y(fragment["spin"].y * delta)
		fragment["velocity"] = velocity * exp(-0.7 * delta)
		piece.scale = Vector3.ONE * (1.0 - smoothstep(1.25, 1.8, elapsed))
	if elapsed >= 1.8:
		queue_free()
