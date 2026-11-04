extends Node
## Headless check of the player's shadow body: the grey-white crystal model in
## protagonist_body.tscn, with its material, skeleton, clips and size.
##   godot --headless --path . res://tests/protagonist_body_test.tscn

const PLAYER_SCENE := "res://actors/player/player.tscn"
const MATERIAL_NAME := "MI_ProtagonistCrystal"
const EXPECTED_HEIGHT_MIN := 1.6
const EXPECTED_HEIGHT_MAX := 1.9

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
	await get_tree().process_frame

	var meshes := shadow.find_children("*", "MeshInstance3D", true, false)
	_check("the model has 11 MeshInstance3D", meshes.size() == 11)
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
	_check("one Skeleton3D with 24 bones",
		skeletons.size() == 1 and (skeletons[0] as Skeleton3D).get_bone_count() == 24)

	var anim := shadow.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips_ok := anim != null and anim.has_animation("idle") and anim.has_animation("run")
	_check("idle and run clips exist", clips_ok)
	_check("both clips loop linearly", clips_ok
		and anim.get_animation("idle").loop_mode == Animation.LOOP_LINEAR
		and anim.get_animation("run").loop_mode == Animation.LOOP_LINEAR)
	_check("idle is playing at rest", clips_ok and anim.current_animation == "idle" and anim.is_playing())

	player.velocity = Vector3(3.0, 0.0, 0.0)
	shadow._process(0.0)
	_check("moving at 3 m/s plays run after one step", clips_ok and anim.current_animation == "run")
	player.velocity = Vector3.ZERO
	shadow._process(0.0)
	_check("stopping plays idle again", clips_ok and anim.current_animation == "idle")

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
func _model_aabb(shadow: Node3D, player: Player) -> AABB:
	var skeleton := shadow.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var to_player := player.global_transform.affine_inverse()
	var merged := AABB()
	var first := true
	for node in shadow.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
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
