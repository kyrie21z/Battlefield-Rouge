extends Node
## Production body, eye, gait and two-handed grip contract. Visual occlusion is also
## checked by protagonist_body_proof through the actual rendering camera.
const PLAYER := preload("res://actors/player/player.tscn")
const ORIGINAL := preload("res://assets/models/characters/red_crystal_enemy_animated.glb")
var _failures := 0

func _ready() -> void:
	var player := PLAYER.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	var body := player.get_node("ShadowBody")
	var skeleton := body._skeleton as Skeleton3D
	await get_tree().process_frame
	_check("one original 24-bone skeleton", body.find_children("*", "Skeleton3D", true, false).size() == 1 and skeleton.get_bone_count() == 24)
	_check("independent fake hand removed", not player.has_node("Head/Camera3D/LeftHand") and not ResourceLoader.exists("res://actors/player/left_hand_view.gd"))
	var original := ORIGINAL.instantiate()
	var count := 0
	for node in body.find_children("GEO_m_*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var source := original.find_child(mesh.name, true, false) as MeshInstance3D
		if String(mesh.name).begins_with("GEO_m_forearm_"):
			_check("%s has authored grip geometry bound to the original rig" % mesh.name,
				source != null and mesh.mesh != source.mesh and mesh.skeleton == source.skeleton)
		else:
			_check("%s shares original mesh and skin" % mesh.name, source != null and mesh.mesh == source.mesh and mesh.skin == source.skin)
		var expected := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if mesh.name == "GEO_m_head" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_check("%s visible body / head shadow policy" % mesh.name, mesh.visible and mesh.cast_shadow == expected)
		count += 1
	_check("all eleven authored body parts retained", count == 11)
	original.free()
	_check("single gameplay pistol, no separate shadow gun", body.find_child("GunAttachment", true, false) == null)
	_check("authored idle and run animation retained", body._anim.has_animation("idle") and body._anim.has_animation("run"))
	player.velocity = Vector3(0, 0, -3)
	body._process(0.2)
	_check("movement drives original run animation", is_equal_approx(body._tree.get("parameters/legs/blend_amount"), 1.0))
	var leg := skeleton.find_bone("LeftLeg")
	body._tree.advance(0.1)
	var before := skeleton.get_bone_pose_rotation(leg)
	body._tree.advance(0.2)
	_check("run changes original leg pose", not before.is_equal_approx(skeleton.get_bone_pose_rotation(leg)))
	player.velocity = Vector3.ZERO
	body._process(0.2)
	_check("stopping blends back to idle", is_zero_approx(body._tree.get("parameters/legs/blend_amount")))
	for pitch in [0.0, -65.0, -82.0, 55.0, 85.0]:
		player._pitch = deg_to_rad(pitch)
		player._apply_look()
		body.pose_arms()
		var grip := player.weapon.grip_transform()
		var wrist := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("RightHand")).origin)
		var target := grip * ProtagonistBody.RIGHT_PISTOL_WRIST
		_check("pitch %.0f right wrist reaches actual pistol (error %.3fm)" % [pitch, wrist.distance_to(target)], wrist.distance_to(target) < 0.065)
		_check_left_pistol_grip(player, body, "hip pitch %.0f" % pitch)
		if pitch == 0.0:
			_check_hand_meshes_at_grip(player, body, "hip")
		_check("pitch %.0f logical ray and rendered eye coincide" % pitch, player.eye_position().is_equal_approx(player.view_camera.global_position))
		var eye := player.eye_position()
		body._tree.advance(0.15)
		body.pose_arms()
		_check("pitch %.0f animation cannot move logical eye" % pitch, eye.distance_to(player.eye_position()) < 0.0001)
	player.weapon.aiming = true
	player.weapon._process(1.0)
	for pitch in [0.0, -82.0, 85.0]:
		player._pitch = deg_to_rad(pitch)
		player._apply_look()
		body.pose_arms()
		_check_left_pistol_grip(player, body, "ADS pitch %.0f" % pitch)
		if pitch == 0.0:
			_check_hand_meshes_at_grip(player, body, "ADS")
	player._pitch = 0.0
	player._apply_look()
	player.weapon.aiming = false
	player.weapon._process(1.0)
	var before_shot := player.weapon.grip_transform()
	_check("the actual pistol fires", player.weapon.try_fire())
	player.weapon._process(1.0 / 60.0)
	body.pose_arms()
	_check("recoil moves the pistol grip", not before_shot.is_equal_approx(player.weapon.grip_transform()))
	_check_left_pistol_grip(player, body, "recoil")
	player.weapon.try_reload()
	for i in 26:
		player.weapon._process(1.0 / 60.0)
	body.pose_arms()
	_check("the pistol is reassembling", player.weapon.is_reloading())
	_check_left_pistol_grip(player, body, "reassembly")
	player.weapon.complete_reload()
	var left_arm := body.find_child("GEO_m_forearm_L", true, false) as MeshInstance3D
	_check("the pristine and fractured left hand use the authored grip shape", left_arm.find_blend_shape_by_name(&"BladeGrip") >= 0)
	body.set_fracture_level(4)
	player.melee.swing_now()
	for delta in [0.03, 0.05, 0.06, 0.06]:
		player.melee._process(delta)
		body.pose_arms()
		var grip := player.melee.grip_transform()
		_check("swinging left hand follows actual blade grip", _left_wrist(skeleton).distance_to(grip * ProtagonistBody.LEFT_BLADE_WRIST) < 0.065)
	var left_shard := body.fracture._left_hand_shard as MeshInstance3D
	_check("blade grip is active at final fracture level", left_shard.visible and is_equal_approx(_blade_weight(left_shard), 1.0))
	body.set_fracture_level(1)
	_check("the blade shape survives the fracture mesh replacement", left_arm.visible and is_equal_approx(_blade_weight(left_arm), 1.0))
	var release_wrist := _left_wrist(skeleton)
	for i in 30:
		player.melee._process(1.0 / 60.0)
		if not player.melee.is_swinging():
			break
		body.pose_arms()
		release_wrist = _left_wrist(skeleton)
	_check("the real blade recovery completes", not player.melee.is_swinging())
	body.pose_arms()
	_check("the blade hand starts its return from its last visible pose", _left_wrist(skeleton).distance_to(release_wrist) < 0.001)
	body._process(ProtagonistBody.REGRIP_TIME * 0.5)
	body.pose_arms()
	var pistol_target := player.weapon.grip_transform() * ProtagonistBody.LEFT_PISTOL_WRIST
	var mid_return := _left_wrist(skeleton)
	_check("the left hand moves partway back to the pistol", mid_return.distance_to(release_wrist) > 0.03
		and mid_return.distance_to(pistol_target) > 0.03
		and mid_return.distance_to(pistol_target) < release_wrist.distance_to(pistol_target))
	_check("left fingers blend back during the wrist return", is_equal_approx(_blade_weight(left_arm), 0.5))
	body._process(ProtagonistBody.REGRIP_TIME * 0.5)
	body.pose_arms()
	_check_left_pistol_grip(player, body, "after the blade recovery")
	_check("the pistol grip shape returns after blade recovery", is_zero_approx(_blade_weight(left_arm)))
	player.queue_free()
	await get_tree().process_frame
	# The audio thread drains its stopped swing playback before engine exit.
	await get_tree().create_timer(0.1, true, false, true).timeout
	print("PROTAGONIST BODY: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _left_wrist(skeleton: Skeleton3D) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin)

func _blade_weight(hand: MeshInstance3D) -> float:
	var shape := hand.find_blend_shape_by_name(&"BladeGrip")
	return hand.get_blend_shape_value(shape) if shape >= 0 else -1.0

func _check_left_pistol_grip(player: Player, body: ProtagonistBody, state: String) -> void:
	var target := player.weapon.grip_transform() * ProtagonistBody.LEFT_PISTOL_WRIST
	var error := _left_wrist(body._skeleton).distance_to(target)
	_check("%s left wrist reaches actual pistol (error %.3fm)" % [state, error], error < 0.02)

func _check_hand_meshes_at_grip(player: Player, body: ProtagonistBody, state: String) -> void:
	var pistol_from_world := player.weapon.grip_transform().affine_inverse()
	var grip_mesh := player.weapon._view.find_child("grip_block", true, false) as MeshInstance3D
	var planes := _grip_planes(grip_mesh, pistol_from_world * grip_mesh.global_transform)
	_check("%s has supporting planes from the physical grip" % state, planes.size() >= 6)
	var skeleton := body._skeleton
	var pistol_from_skeleton := pistol_from_world * skeleton.global_transform
	for side in ["Right", "Left"]:
		var part := body.find_child("GEO_m_forearm_" + side.left(1), true, false) as MeshInstance3D
		var hand := skeleton.find_bone(side + "Hand")
		var samples := _skinned_hand_points(part, skeleton, hand, pistol_from_skeleton)
		var nearest := INF
		var deepest := 0.0
		var wraps_front := false
		var supports_back := false
		for point in samples:
			var distance := -INF
			for plane in planes:
				distance = maxf(distance, plane.distance_to(point))
			nearest = minf(nearest, absf(distance))
			deepest = maxf(deepest, -distance)
			# Within the contact band, the right palm is behind the grip and its
			# fingertips reach across the front to the side opposite the wrist.
			if absf(point.y) < 0.027 and absf(distance) < 0.013:
				var depth := point.z + 0.47 * point.y
				wraps_front = wraps_front or (point.x < -0.008 and depth < -0.025)
				supports_back = supports_back or (absf(point.x) < 0.023 and depth > 0.025)
		_check("%s %s hand mesh meets the grip (gap %.1f mm, depth %.1f mm)" % [state, side, nearest * 1000, deepest * 1000],
			nearest < 0.006 and deepest < 0.006)
		if side == "Right":
			_check("%s right fingertips wrap the front of the grip opposite the palm" % state, wraps_front and supports_back)

func _grip_planes(grip_mesh: MeshInstance3D, pistol_from_grip: Transform3D) -> Array[Plane]:
	var points := grip_mesh.mesh.get_faces()
	for i in points.size():
		points[i] = pistol_from_grip * points[i]
	var planes: Array[Plane] = []
	for i in range(0, points.size(), 3):
		var plane := Plane(points[i], points[i + 1], points[i + 2])
		if plane.normal.is_zero_approx():
			continue
		if plane.distance_to(Vector3.ZERO) > 0.0:
			plane = -plane
		# Ignore the gold inlay and interior facets that do not bound the grip.
		var bounds_grip := true
		for point in points:
			if plane.distance_to(point) > 0.001:
				bounds_grip = false
				break
		if bounds_grip:
			planes.append(plane)
	return planes

func _skinned_hand_points(part: MeshInstance3D, skeleton: Skeleton3D, hand: int, pistol_from_skeleton: Transform3D) -> PackedVector3Array:
	var arrays := part.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var stride := int(float(joints.size()) / vertices.size())
	var posed := PackedVector3Array()
	var hand_weights := PackedFloat32Array()
	for i in vertices.size():
		var position := Vector3.ZERO
		var hand_weight := 0.0
		for j in stride:
			var weight := weights[i * stride + j]
			if weight <= 0.0:
				continue
			var bind := joints[i * stride + j]
			var name := part.skin.get_bind_name(bind)
			var bone := skeleton.find_bone(name) if not name.is_empty() else part.skin.get_bind_bone(bind)
			position += weight * (skeleton.get_bone_global_pose(bone) * part.skin.get_bind_pose(bind) * vertices[i])
			if bone == hand:
				hand_weight += weight
		posed.append(pistol_from_skeleton * position)
		hand_weights.append(hand_weight)
	var samples := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		if maxf(hand_weights[a], maxf(hand_weights[b], hand_weights[c])) > 0.5:
			samples.append_array([posed[a], posed[b], posed[c], (posed[a] + posed[b] + posed[c]) / 3.0])
	return samples

func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
