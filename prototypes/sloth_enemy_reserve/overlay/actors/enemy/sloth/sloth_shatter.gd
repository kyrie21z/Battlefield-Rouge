class_name SlothShatter
extends Node3D
## Reuses all 56 authored crystal shards at the CURRENT skeleton pose.
## The impact point orders the fracture; visual physics never consumes gameplay RNG.
const SHARDS := preload("res://assets/models/characters/red_crystal_enemy_shards.glb")
const PART_BONE := {"head":"Head", "torso":"Spine", "hips":"Hips",
	"upper_arm_L":"LeftArm", "upper_arm_R":"RightArm", "forearm_L":"LeftForeArm",
	"forearm_R":"RightForeArm", "thigh_L":"LeftUpLeg", "thigh_R":"RightUpLeg",
	"shin_L":"LeftLeg", "shin_R":"RightLeg"}
var impact_point := Vector3.ZERO
var impact_direction := Vector3.FORWARD
var first_part := ""
var fragments: Array[Dictionary] = []
var elapsed := 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func build(visual: SlothVisual, point: Vector3, direction: Vector3) -> void:
	impact_point = point
	impact_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	var library := SHARDS.instantiate()
	var nearest := INF
	var mat := visual.crystal_material().duplicate() as ShaderMaterial
	mat.set_shader_parameter("rim_strength", 0.22)
	for child in library.find_children("*", "MeshInstance3D", true, false):
		var source := child as MeshInstance3D
		var key := String(source.name).trim_prefix("SHARD_m_")
		var part := key.substr(0, key.rfind("_"))
		var delta := Transform3D.IDENTITY
		var bone := visual.skeleton.find_bone(PART_BONE.get(part, "Spine"))
		if bone >= 0:
			delta = visual.skeleton.get_bone_global_pose(bone) * visual.skeleton.get_bone_global_rest(bone).affine_inverse()
		var xf: Transform3D = visual.model.global_transform * delta * source.transform
		var piece := MeshInstance3D.new()
		piece.mesh = source.mesh
		piece.material_override = mat
		add_child(piece)
		piece.global_transform = xf
		var distance := xf.origin.distance_to(point)
		if distance < nearest:
			nearest = distance
			first_part = part
		var index := fragments.size()
		var scatter := Vector3(sin(index * 2.4), 0.6 + cos(index * 1.3) * 0.2, cos(index * 2.4))
		var away := (xf.origin - point).normalized()
		fragments.append({"node":piece, "part":part, "distance":distance,
			"delay":0.0, "released":false, "velocity":away * 1.3 + impact_direction * 1.6 + scatter * 0.6,
			"spin":Vector3(cos(index), sin(index * 2.2), 0.7) * 2.0})
	library.free()
	for fragment in fragments:
		fragment["delay"] = minf(0.12, maxf(0.0, fragment["distance"] - nearest) * 0.065)
		(fragment["node"] as MeshInstance3D).visible = true
	# Contact shards begin immediately; the rest follow within 120 ms.
	for fragment in fragments:
		if fragment["delay"] < 0.001:
			fragment["released"] = true


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
