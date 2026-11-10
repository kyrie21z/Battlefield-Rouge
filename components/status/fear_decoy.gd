class_name FearDecoy
extends CharacterBody3D
## A real enemy target with a destructible torso. Its one-shot expiration is
## reported to the owning boon effect, which owns the panic/visibility rules.

signal burst(point: Vector3)

const BODY := preload("res://actors/player/protagonist_body.tscn")

var team := 0
var lifetime := 2.0
var health: Health
## Inject the production ShadowBody. Snapshot poses, never run its player code.
var pose_source: Node3D
var skeleton: Skeleton3D
var crystal_material: StandardMaterial3D
var copied_bones := 0
var _elapsed := 0.0
var _finished := false
var _visual: Node3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	health = Health.new()
	health.name = "Health"
	health.max_health = 1.0
	health.team = team
	add_child(health)
	health.died.connect(_on_died)
	var hitbox := Hitbox.new()
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.7
	collider.shape = shape
	hitbox.position.y = 0.9
	hitbox.add_child(collider)
	add_child(hitbox)
	_visual = BODY.instantiate() as Node3D
	_visual.name = "CrystalBody"
	add_child(_visual)
	skeleton = _visual.find_child("Skeleton3D", true, false) as Skeleton3D
	_snapshot_pose()
	crystal_material = StandardMaterial3D.new()
	crystal_material.resource_local_to_scene = true
	crystal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	crystal_material.albedo_color = Color(0.31, 0.14, 0.59, 0.52)
	crystal_material.metallic = 0.55
	crystal_material.roughness = 0.23
	crystal_material.rim_enabled = true
	crystal_material.rim = 0.55
	crystal_material.rim_tint = 0.2
	crystal_material.emission_enabled = true
	crystal_material.emission = PanicFlawStatus.COLOR
	crystal_material.emission_energy_multiplier = 0.18
	for node in _visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = crystal_material
		mesh.material_overlay = null
		mesh.visible = true
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _snapshot_pose() -> void:
	var animation := _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null:
		if animation.has_animation("idle"):
			animation.play("idle")
			animation.seek(0.0, true)
		animation.pause()
		animation.active = false
	var source_skeleton := pose_source.find_child("Skeleton3D", true, false) as Skeleton3D if is_instance_valid(pose_source) else null
	if source_skeleton != null and skeleton != null:
		global_basis = pose_source.global_basis
		for index in skeleton.get_bone_count():
			var source_index := source_skeleton.find_bone(skeleton.get_bone_name(index))
			if source_index < 0:
				continue
			skeleton.set_bone_pose_position(index, source_skeleton.get_bone_pose_position(source_index))
			skeleton.set_bone_pose_rotation(index, source_skeleton.get_bone_pose_rotation(source_index))
			skeleton.set_bone_pose_scale(index, source_skeleton.get_bone_pose_scale(source_index))
			copied_bones += 1
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()


func _process(delta: float) -> void:
	if get_tree().paused or _finished:
		return
	_elapsed += delta
	_visual.position.x = sin(_elapsed * 117.0) * 0.045
	_visual.position.z = sin(_elapsed * 93.0) * 0.025
	if _elapsed >= lifetime:
		explode()


func explode() -> void:
	if _finished:
		return
	_finished = true
	burst.emit(global_position)
	queue_free()


func cancel() -> void:
	_finished = true
	queue_free()


func _on_died(_source: Node) -> void:
	explode()
