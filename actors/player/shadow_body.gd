class_name ProtagonistBody
extends Node3D
## One authored crystal body is both the first-person body and the world shadow.
## The stable eye reference comes from its head bone; animation moves the legs,
## while a two-bone arm solve holds the actual gameplay pistol at every pitch.

const RUN_SPEED := 0.5
const IDLE_ANIM := "idle"
const RUN_ANIM := "run"
const AIM_ANIM := "Aiming_1"
const SHOT_ANIM := "Shooting_1_1"
const BLEND_TIME := 0.15
const SHOT_FADE_IN := 0.04
const SHOT_FADE_OUT := 0.12
# Gun-local wrist poses fitted to the opening between the original palm and
# fingers. The left hand supports the lower grip and exposes its cracked back.
const RIGHT_PISTOL_WRIST := Vector3(0.025, -0.014, 0.080)
const RIGHT_PISTOL_EULER := Vector3(9.0, -23.0, -31.0) * PI / 180.0
const LEFT_PISTOL_WRIST := Vector3(-0.034, -0.030, 0.095)
const LEFT_PISTOL_EULER := Vector3(-15.0, 20.0, -10.0) * PI / 180.0
const LEFT_BLADE_WRIST := Vector3(0.0, -0.015, 0.045)
const REGRIP_TIME := 0.14
const MATERIAL := preload("res://assets/materials/protagonist_crystal_material.tres")
const POSE_MODIFIER := preload("res://actors/player/body_pose_modifier.gd")
const UPPER_BONES: Array[StringName] = [
	&"Spine", &"Chest", &"Neck", &"Head",
	&"RightShoulder", &"RightArm", &"RightForeArm", &"RightHand",
	&"LeftShoulder", &"LeftArm", &"LeftForeArm", &"LeftHand",
]

@export_range(0, 4) var fracture_level := 0
@export var enable_debug_keys := false
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _run_blend := 0.0
var _blade_wrist_in_camera := Transform3D.IDENTITY
var _blade_grip_weight := 0.0
var _weapon: Weapon
var _melee: MeleeWeapon
var _head: Node3D
var _hand_basis := {}
var _right_pistol_basis := Basis.from_euler(RIGHT_PISTOL_EULER)
var _left_pistol_basis := Basis.from_euler(LEFT_PISTOL_EULER)
var _eye_reference := Vector3.ZERO
var fracture: Node

func _ready() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	_dress_meshes()
	var clips := _anim.get_animation_library("").duplicate(true) as AnimationLibrary
	_anim.remove_animation_library("")
	_anim.add_animation_library("", clips)
	for clip in [IDLE_ANIM, RUN_ANIM]:
		# Imported animations are shared resources. Loop flags belong to this instance.
		var local := _anim.get_animation(clip).duplicate() as Animation
		local.loop_mode = Animation.LOOP_LINEAR
		_anim.get_animation_library("").add_animation(clip, local)
	_sample_pose()
	_build_tree()
	var player := get_parent()
	_weapon = player.get_node_or_null("Head/Camera3D/Weapon") as Weapon
	_head = player.get_node_or_null("Head") as Node3D
	_melee = player.get_node_or_null("Head/Camera3D/Melee") as MeleeWeapon
	if _head != null:
		_head.position = player.to_local(_skeleton.to_global(_eye_reference))
	if _weapon != null:
		_weapon.fired.connect(_on_weapon_fired)
	var modifier := SkeletonModifier3D.new()
	modifier.set_script(POSE_MODIFIER)
	modifier.name = "BodyPose"
	modifier.body = self
	_skeleton.add_child(modifier)
	Events.sin_defeated.connect(set_fracture_level)
	fracture = preload("res://actors/player/body_fracture.gd").new()
	fracture.name = "BodyFracture"
	add_child(fracture)
	fracture.setup(_anim.get_parent(), _skeleton)
	set_fracture_level(fracture_level)

func _process(delta: float) -> void:
	_blade_grip_weight = move_toward(_blade_grip_weight, 0.0, delta / REGRIP_TIME)
	var player := get_parent() as CharacterBody3D
	var speed := Vector2(player.velocity.x, player.velocity.z).length() if player != null else 0.0
	_run_blend = move_toward(_run_blend, 1.0 if speed > RUN_SPEED else 0.0, delta / BLEND_TIME)
	_tree.set("parameters/legs/blend_amount", _run_blend)

func _dress_meshes() -> void:
	var opaque := StandardMaterial3D.new()
	opaque.albedo_color = Color(0.8, 0.81, 0.83)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if mesh.name == "GEO_m_head" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh.material_override = opaque
		mesh.material_overlay = MATERIAL.duplicate()

func _sample_pose() -> void:
	_anim.play(AIM_ANIM)
	_anim.seek(0.0, true)
	_anim.pause()
	_skeleton.force_update_all_bone_transforms()
	for side in ["Right", "Left"]:
		_hand_basis[side] = _skeleton.get_bone_global_pose(_skeleton.find_bone(side + "Hand")).basis
	# Head origin is near the skull centre. Eyes lie above and toward -Z.
	_eye_reference = _skeleton.get_bone_global_rest(_skeleton.find_bone("Head")).origin + Vector3(0.0, 0.045, -0.160)
	_eye_reference.x = 0.0

func _build_tree() -> void:
	var model := _anim.get_parent()
	var skeleton_path := String(model.get_path_to(_skeleton))
	var aim := AnimationNodeAnimation.new()
	aim.animation = AIM_ANIM
	var idle := AnimationNodeAnimation.new()
	idle.animation = IDLE_ANIM
	var run := AnimationNodeAnimation.new()
	run.animation = RUN_ANIM
	var shot := AnimationNodeAnimation.new()
	shot.animation = SHOT_ANIM
	var legs := AnimationNodeBlend2.new()
	var fire := AnimationNodeOneShot.new()
	fire.fadein_time = SHOT_FADE_IN
	fire.fadeout_time = SHOT_FADE_OUT
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	for bone in UPPER_BONES:
		upper.set_filter_path(NodePath(skeleton_path + ":" + bone), true)
	var root := AnimationNodeBlendTree.new()
	root.add_node("idle", idle)
	root.add_node("run", run)
	root.add_node("legs", legs)
	root.add_node("aim", aim)
	root.add_node("shot", shot)
	root.add_node("fire", fire)
	root.add_node("upper", upper)
	root.connect_node("legs", 0, "idle")
	root.connect_node("legs", 1, "run")
	root.connect_node("fire", 0, "aim")
	root.connect_node("fire", 1, "shot")
	root.connect_node("upper", 0, "legs")
	root.connect_node("upper", 1, "fire")
	root.connect_node("output", 0, "upper")
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim)
	_tree.tree_root = root
	_tree.set("parameters/legs/blend_amount", 0.0)
	_tree.set("parameters/upper/blend_amount", 1.0)
	_tree.active = true
	_anim.active = false

func pose_arms() -> void:
	if not is_inside_tree():
		return
	for node in [_skeleton, _weapon, _head]:
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
	if not is_instance_valid(_weapon.camera) or not _weapon.camera.is_inside_tree():
		return
	# Keep the authored upright torso and stable skull position. Running owns
	# leg rotations, not the logical eye/ray origin or a hunched third-person aim.
	for bone_name in ["Hips", "Spine", "Chest", "Neck", "Head"]:
		var bone := _skeleton.find_bone(bone_name)
		_skeleton.set_bone_pose_position(bone, _skeleton.get_bone_rest(bone).origin)
		_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	var lean := clampf(-_head.rotation.x / deg_to_rad(80.0), 0.0, 1.0)
	for bone_name in ["Spine", "Chest"]:
		var bone := _skeleton.find_bone(bone_name)
		var angle := -0.16 if bone_name == "Spine" else -0.38
		var rest := _skeleton.get_bone_rest(bone).basis
		_skeleton.set_bone_pose_rotation(bone, (rest * Basis(Vector3.RIGHT, angle * lean)).get_rotation_quaternion())
	var head_point := _skeleton.get_bone_global_pose(_skeleton.find_bone("Head")).origin + Vector3(0.0, 0.045, -0.160)
	head_point.x = 0.0
	_head.position = get_parent().to_local(_skeleton.to_global(head_point))
	# Raise the real pistol toward the shoulder when aiming overhead; rays stay
	# at the shared camera eye, while the original arm remains within reach.
	var upward := clampf(_head.rotation.x / (PI * 0.5), 0.0, 1.0)
	_weapon.position.z = 0.035 + 0.20 * upward
	# The clavicles rise naturally when aiming overhead, without stretching the
	# original humerus or forearm or moving the stable head reference.
	for side in ["Right", "Left"]:
		var clavicle := _skeleton.find_bone(side + "Shoulder")
		_skeleton.set_bone_pose_rotation(clavicle, _skeleton.get_bone_rest(clavicle).basis.get_rotation_quaternion())
		if upward > 0.0:
			var arm := _skeleton.find_bone(side + "Arm")
			var origin := _skeleton.get_bone_global_pose(clavicle).origin
			var arm_direction := _skeleton.get_bone_global_pose(arm).origin - origin
			_rotate_bone(clavicle, arm_direction, arm_direction + Vector3(0.0, upward * 0.18, 0.0))
	var grip := _weapon.grip_transform()
	var inverse := _skeleton.global_transform.affine_inverse()
	var aim_basis := _skeleton.global_basis.orthonormalized().inverse() * grip.basis.orthonormalized()
	_solve_arm("Right", inverse * (grip * RIGHT_PISTOL_WRIST),
		aim_basis * _right_pistol_basis * (_hand_basis["Right"] as Basis), Vector3(0.35, -0.6, 0.15))
	_pose_left_arm(grip, inverse)

func _pose_left_arm(grip: Transform3D, skeleton_from_world: Transform3D) -> void:
	var camera := _weapon.camera
	var wrist := Transform3D(grip.basis.orthonormalized() * _left_pistol_basis,
		grip * LEFT_PISTOL_WRIST)
	if _melee != null and _melee.is_swinging():
		var blade_grip := _melee.grip_transform()
		wrist = Transform3D(blade_grip.basis.orthonormalized(), blade_grip * LEFT_BLADE_WRIST)
		# The blade resets to its hidden rest pose when recovery ends.
		_blade_wrist_in_camera = camera.global_transform.affine_inverse() * wrist
		_blade_grip_weight = 1.0
	elif _blade_grip_weight > 0.0:
		var last_blade_wrist := camera.global_transform * _blade_wrist_in_camera
		wrist = wrist.interpolate_with(last_blade_wrist, smoothstep(0.0, 1.0, _blade_grip_weight))
	wrist = (skeleton_from_world * wrist).orthonormalized()
	_solve_arm("Left", wrist.origin, wrist.basis * (_hand_basis["Left"] as Basis),
		Vector3(-0.45, -0.5, 0.05))

func _solve_arm(side: String, target: Vector3, hand_basis: Basis, pole: Vector3) -> void:
	var upper := _skeleton.find_bone(side + "Arm")
	var forearm := _skeleton.find_bone(side + "ForeArm")
	var hand := _skeleton.find_bone(side + "Hand")
	var shoulder := _skeleton.get_bone_global_pose(upper).origin
	var elbow := _skeleton.get_bone_global_pose(forearm).origin
	var wrist := _skeleton.get_bone_global_pose(hand).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var direction := (target - shoulder).normalized()
	var distance := clampf(shoulder.distance_to(target), absf(a - b) + 0.001, a + b - 0.001)
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(a * a - along * along, 0.0))
	var bend := (pole - direction * pole.dot(direction)).normalized()
	var desired_elbow := shoulder + direction * along + bend * height
	_rotate_bone(upper, elbow - shoulder, desired_elbow - shoulder)
	elbow = _skeleton.get_bone_global_pose(forearm).origin
	wrist = _skeleton.get_bone_global_pose(hand).origin
	_rotate_bone(forearm, wrist - elbow, shoulder + direction * distance - elbow)
	_set_global_basis(hand, hand_basis)

func _rotate_bone(index: int, from: Vector3, to: Vector3) -> void:
	var rotation := Basis(Quaternion(from.normalized(), to.normalized()))
	_set_global_basis(index, rotation * _skeleton.get_bone_global_pose(index).basis)

func _set_global_basis(index: int, basis: Basis) -> void:
	var parent := _skeleton.get_bone_parent(index)
	var parent_basis := _skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	_skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * basis).orthonormalized().get_rotation_quaternion())

func set_fracture_level(level: int) -> void:
	fracture_level = clampi(level, 0, 4)
	if fracture != null:
		fracture.set_fracture_level(fracture_level)

func _unhandled_key_input(event: InputEvent) -> void:
	if not enable_debug_keys or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key >= KEY_0 and key <= KEY_4:
		set_fracture_level(key - KEY_0)
		get_viewport().set_input_as_handled()

func _on_weapon_fired() -> void:
	_tree.set("parameters/fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
