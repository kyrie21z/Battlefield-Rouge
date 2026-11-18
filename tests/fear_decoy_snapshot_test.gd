extends Node3D
## Exercise the production protagonist pose and real destructible decoy.

var _failed := 0
var _finished := false


func _ready() -> void:
	await _run()
	var ok := _finished and _failed == 0
	print("%s (%d failed, finished=%s)" % ["ALL PASSED" if ok else "FAIL", _failed, _finished])
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	var source := player.get_node("ShadowBody") as ProtagonistBody
	source._tree.active = false
	for modifier in source._skeleton.find_children("*", "SkeletonModifier3D", true, false):
		(modifier as SkeletonModifier3D).active = false
	source.rotation.y = 0.73
	source.pose_arms()
	var arm := source._skeleton.find_bone("RightArm")
	source._skeleton.set_bone_pose_rotation(arm, Quaternion(Vector3.RIGHT, 0.28))
	source._skeleton.force_update_all_bone_transforms()
	var original := source.find_child("GEO_m_head", true, false) as MeshInstance3D
	var original_material := original.material_override
	var original_overlay := original.material_overlay
	source.fracture.set_blade_grip(0.72)
	var first := FearDecoy.new()
	first.pose_source = source
	add_child(first)
	first.set_process(false)
	_check("production pose copies all 24 crystal body bones", first.skeleton.get_bone_count() == 24 and first.copied_bones == 24)
	var poses_equal := true
	for index in first.skeleton.get_bone_count():
		var source_index := source._skeleton.find_bone(first.skeleton.get_bone_name(index))
		poses_equal = poses_equal and source_index >= 0
		poses_equal = poses_equal and first.skeleton.get_bone_pose_position(index).is_equal_approx(source._skeleton.get_bone_pose_position(source_index))
		poses_equal = poses_equal and first.skeleton.get_bone_pose_rotation(index).is_equal_approx(source._skeleton.get_bone_pose_rotation(source_index))
		poses_equal = poses_equal and first.skeleton.get_bone_pose_scale(index).is_equal_approx(source._skeleton.get_bone_pose_scale(source_index))
	_check("all local bone positions rotations and scales match snapshot", poses_equal)
	_check("snapshot retains current protagonist facing", first.global_basis.is_equal_approx(source.global_basis))
	var left_arm := first.find_child("GEO_m_forearm_L", true, false) as MeshInstance3D
	var grip_shape := left_arm.find_blend_shape_by_name(&"BladeGrip")
	source.fracture.set_blade_grip(0.0)
	_check("snapshot freezes the hand shape independently of later player motion",
		grip_shape >= 0 and is_equal_approx(left_arm.get_blend_shape_value(grip_shape), 0.72))
	var full_body := true
	for part in ["head", "torso", "hips", "upper_arm_L", "upper_arm_R", "forearm_L", "forearm_R", "thigh_L", "thigh_R", "shin_L", "shin_R"]:
		var mesh := first.find_child("GEO_m_" + part, true, false) as MeshInstance3D
		full_body = full_body and mesh != null and mesh.visible and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_check("complete head torso arms hands and legs render in ghost", full_body and first.skeleton.find_bone("LeftHand") >= 0 and first.skeleton.find_bone("RightHand") >= 0)
	_check("ghost uses pure scene without player script or animation tree", first.get_node("CrystalBody").get_script() == null and first.find_children("*", "AnimationTree", true, false).is_empty())
	var animation := first.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("snapshot animation is frozen", not animation.active and not animation.is_playing())
	var snapshot_rotation := first.skeleton.get_bone_pose_rotation(arm)
	source._skeleton.set_bone_pose_rotation(arm, Quaternion(Vector3.UP, 1.1))
	await get_tree().process_frame
	_check("later player animation cannot alter captured pose", first.skeleton.get_bone_pose_rotation(arm).is_equal_approx(snapshot_rotation))
	var second := FearDecoy.new()
	add_child(second)
	second.set_process(false)
	var fallback_animation := second.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("missing source falls back to frozen authored idle pose", second.skeleton.get_bone_count() == 24 and second.copied_bones == 0 and fallback_animation.assigned_animation == "idle" and not fallback_animation.active)
	_check("each decoy owns a separate translucent reflective material", first.crystal_material != second.crystal_material and first.crystal_material.albedo_color.a < 1.0 and first.crystal_material.metallic > 0.0 and first.crystal_material.roughness < 0.3)
	var second_color := second.crystal_material.albedo_color
	first.crystal_material.albedo_color = Color.WHITE
	_check("editing one ghost material leaves others and protagonist unchanged", second.crystal_material.albedo_color == second_color and original.material_override == original_material and original.material_overlay == original_overlay and original.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	first._process(0.01)
	_check("frozen pose retains spatial tremor", absf(first._visual.position.x) > 0.001 and absf(first._visual.position.z) > 0.001)
	var elapsed := first._elapsed
	get_tree().paused = true
	first._process(0.5)
	get_tree().paused = false
	_check("pause freezes jitter and two second expiration", is_equal_approx(first._elapsed, elapsed) and first.lifetime == 2.0)
	var hitboxes: Array[Hitbox] = []
	for child in first.get_children():
		if child is Hitbox:
			hitboxes.append(child)
	_check("ghost keeps one hit point and real capsule hitbox", first.health.health == 1.0 and hitboxes.size() == 1 and (hitboxes[0].get_child(0) as CollisionShape3D).shape is CapsuleShape3D)
	var bursts := [0]
	first.burst.connect(func(_point: Vector3) -> void: bursts[0] += 1)
	hitboxes[0].apply_hit(2.0)
	first.explode()
	_check("destruction still emits one burst and removes ghost", first.is_queued_for_deletion() and bursts[0] == 1)
	second._process(2.01)
	_check("fallback ghost still expires at two seconds", second.is_queued_for_deletion())
	_finished = true


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", label])
	if not condition:
		_failed += 1
