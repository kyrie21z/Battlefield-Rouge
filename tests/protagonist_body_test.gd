extends Node
## Production body/eye/gait/one-handed grip contract. Visual occlusion is also
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
		var target := grip * Vector3(0.014, -0.018, 0.055)
		_check("pitch %.0f right wrist reaches actual pistol (error %.3fm)" % [pitch, wrist.distance_to(target)], wrist.distance_to(target) < 0.065)
		var left := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin)
		_check("pitch %.0f left hand stays free of pistol" % pitch, left.distance_to(grip.origin) > 0.18)
		_check("pitch %.0f logical ray and rendered eye coincide" % pitch, player.eye_position().is_equal_approx(player.view_camera.global_position))
		var eye := player.eye_position()
		body._tree.advance(0.15)
		body.pose_arms()
		_check("pitch %.0f animation cannot move logical eye" % pitch, eye.distance_to(player.eye_position()) < 0.0001)
	player._pitch = 0.0
	player._apply_look()
	player.melee.swing_now()
	for delta in [0.03, 0.05, 0.06, 0.06]:
		player.melee._process(delta)
		body.pose_arms()
		var grip := player.melee.grip_transform()
		var wrist := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin)
		_check("swinging left hand follows actual blade grip", wrist.distance_to(grip * Vector3(0.0, -0.015, 0.045)) < 0.065)
	player.melee.cancel()
	player.queue_free()
	await get_tree().process_frame
	# The audio thread drains its stopped swing playback before engine exit.
	await get_tree().create_timer(0.1, true, false, true).timeout
	print("PROTAGONIST BODY: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
