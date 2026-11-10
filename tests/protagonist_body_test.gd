extends Node
## Headless check of the player's shadow body: the grey-white crystal model in
## protagonist_body.tscn, with its material, skeleton, clips and size, the
## AnimationTree that splits legs and aim, and the gun carried in the right hand.
##   godot --headless --path . res://tests/protagonist_body_test.tscn

const PLAYER_SCENE := "res://actors/player/player.tscn"
const MATERIAL_NAME := "MI_ProtagonistCrystal"
const EXPECTED_HEIGHT_MIN := 1.6
const EXPECTED_HEIGHT_MAX := 1.9
## Bones the aim pose owns; Hips and the leg chain must stay on idle / run.
const UPPER_BONES := ["Spine", "Chest", "Neck", "Head", "LeftShoulder", "LeftArm",
	"LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]
const LOWER_BONES := ["Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToe",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToe"]

var _failures := 0


func _ready() -> void:
	await _run()
	print("PROTAGONIST BODY: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var shadow := player.get_node("ShadowBody") as Node3D
	shadow.set_process(false)
	await get_tree().process_frame

	var meshes := shadow.find_children("*", "MeshInstance3D", true, false)
	var body_meshes := []
	for node in meshes:
		if (node as MeshInstance3D).skin != null:
			body_meshes.append(node)
	_check("the model has 11 MeshInstance3D", body_meshes.size() == 11)
	var all_shadows_only := true
	var all_protagonist := true
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			all_shadows_only = false
		var material := mi.material_overlay as ShaderMaterial
		if material == null or material.resource_name != MATERIAL_NAME:
			all_protagonist = false
	_check("every mesh is SHADOWS_ONLY", all_shadows_only)
	_check("every mesh uses the grey-white %s" % MATERIAL_NAME, all_protagonist)

	var skeletons := shadow.find_children("*", "Skeleton3D", true, false)
	var skeleton := skeletons[0] as Skeleton3D
	_check("one Skeleton3D with 24 bones",
		skeletons.size() == 1 and skeleton.get_bone_count() == 24)

	var anim := shadow.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips_ok := anim != null and anim.has_animation("idle") and anim.has_animation("run")
	_check("idle and run clips exist", clips_ok)
	_check("both clips loop linearly", clips_ok
		and anim.get_animation("idle").loop_mode == Animation.LOOP_LINEAR
		and anim.get_animation("run").loop_mode == Animation.LOOP_LINEAR)

	var tree := shadow.find_child("AnimationTree", true, false) as AnimationTree
	_check("an active AnimationTree drives the body", tree != null and tree.active)
	_check("the legs start on idle", tree != null and tree.get("parameters/legs/blend_amount") == 0.0)
	player.velocity = Vector3(3.0, 0.0, 0.0)
	shadow._process(0.15)
	_check("moving at 3 m/s blends the legs onto run",
		tree != null and is_equal_approx(tree.get("parameters/legs/blend_amount"), 1.0))
	player.velocity = Vector3.ZERO
	shadow._process(0.15)
	_check("stopping blends the legs back to idle",
		tree != null and is_equal_approx(tree.get("parameters/legs/blend_amount"), 0.0))

	# The aim pose owns the upper body only; hips and legs stay on the legs blend.
	var upper := (tree.tree_root as AnimationNodeBlendTree).get_node("upper") as AnimationNodeBlend2
	var bone_prefix := String(tree.get_node(tree.root_node).get_path_to(skeleton))
	var upper_kept := true
	var lower_free := true
	for bone in UPPER_BONES:
		upper_kept = upper_kept and upper.is_path_filtered(NodePath(bone_prefix + ":" + bone))
	for bone in LOWER_BONES:
		lower_free = lower_free and not upper.is_path_filtered(NodePath(bone_prefix + ":" + bone))
	_check("the aim pose owns %d upper bones" % UPPER_BONES.size(), upper_kept)
	_check("the filter leaves hips and legs to idle / run", lower_free)

	# The gun: a BoneAttachment3D on the right hand with the rifle in it.
	var attachment := skeleton.find_child("GunAttachment", true, false) as BoneAttachment3D
	_check("a BoneAttachment3D hangs the gun off the right hand",
		attachment != null and attachment.bone_name == "RightHand" and attachment.get_child_count() == 1)
	var gun := attachment.get_child(0) as Node3D
	var gun_meshes := gun.find_children("*", "MeshInstance3D", true, false)
	_check("pistol is the right-hand shadow model", gun.scene_file_path.ends_with("obsidian_pistol.glb"))
	_check("pistol muzzle points forward", (gun.global_transform * Vector3(0, .066, -.1765)).z < gun.global_position.z - .15)
	# And the grip has to sit in the right hand, not float above it.
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))
	var gun_box := AABB()
	for node in gun_meshes:
		var mi := node as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		gun_box = box if gun_box.size == Vector3.ZERO else gun_box.merge(box)
	var nearest := hand.origin.clamp(gun_box.position, gun_box.end)
	_check("the gun touches the right hand (%.2f m)" % nearest.distance_to(hand.origin),
		nearest.distance_to(hand.origin) < 0.12)

	# Firing the weapon plays the short recoil over the aim pose.
	var weapon := player.get_node("Head/Camera3D/Weapon") as Weapon
	_check("no recoil before a shot", tree.get("parameters/fire/active") == false)
	weapon.fired.emit()
	await get_tree().process_frame
	_check("firing makes the shot one-shot active", tree.get("parameters/fire/active") == true)

	# A blade in the hands hides the gun, as it does for the first-person model.
	weapon.trigger_enabled = false
	shadow._process(0.0)
	_check("the gun hides while a blade is swung", not gun.visible)
	weapon.trigger_enabled = true
	shadow._process(0.0)
	_check("the gun is back once the blade is away", gun.visible)

	# One equipped pistol cannot be replaced by a wheel event.
	weapon._cycle_wheel(1)
	_check("wheel retains one pistol attachment", attachment.get_child_count() == 1 and attachment.get_child(0) == gun)

	var merged := _model_aabb(shadow, player)
	_check("the model is %.2f m tall (%.1f-%.1f m)" % [
		merged.size.y, EXPECTED_HEIGHT_MIN, EXPECTED_HEIGHT_MAX],
		merged.size.y >= EXPECTED_HEIGHT_MIN and merged.size.y <= EXPECTED_HEIGHT_MAX)
	_check("the feet sit at %.3f m (within 0.05 m of the floor)" % merged.position.y,
		absf(merged.position.y) <= 0.05)
	var leftover := []
	for node in shadow.find_children("*", "", true, false):
		if String(node.name).to_lower().contains("soldier"):
			leftover.append(node.name)
	_check("no soldier node left under ShadowBody", leftover.is_empty())

	player.queue_free()
	await get_tree().process_frame


## Merged AABB of the body's skinned rest meshes, in the player's space. The
## imported skin stores its binds by bone name, and vertices index those binds,
## so the rest pose has to be applied through the bind poses to get real metres.
## The gun is not skinned, so it is left out.
func _model_aabb(shadow: Node3D, player: Player) -> AABB:
	var skeleton := shadow.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var to_player := player.global_transform.affine_inverse()
	var merged := AABB()
	var first := true
	for node in shadow.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin == null:
			continue
		var skin := mi.skin
		var bone_for_bind: Array[int] = []
		for bind_index in skin.get_bind_count():
			bone_for_bind.append(skeleton.find_bone(skin.get_bind_name(bind_index)))
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for i in verts.size():
				var position := Vector3.ZERO
				for k in 4:
					var bind_index := bones[i * 4 + k]
					var weight := weights[i * 4 + k]
					if bind_index < 0 or weight == 0.0:
						continue
					var bone_xf := skeleton.global_transform \
						* skeleton.get_bone_global_rest(bone_for_bind[bind_index]) \
						* skin.get_bind_pose(bind_index)
					position += (bone_xf * verts[i]) * weight
				position = to_player * position
				if first:
					merged = AABB(position, Vector3.ZERO)
					first = false
				else:
					merged = merged.expand(position)
	return merged


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
