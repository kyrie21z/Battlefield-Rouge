extends Node3D
## The player's body, drawn only into shadows: the camera sits inside its head,
## so it is never seen directly, but the ground shows a running figure. The
## model is the grey-white crystal humanoid from protagonist_body.tscn. Purely
## visual; it holds no hitbox and draws no random numbers.
##
## The figure carries the gun the player has out: a `BoneAttachment3D` on the
## right hand holds that gun's own model, and an `AnimationTree` splits the body
## into legs (idle / run, 0.15 s blend) and a held two-handed aim pose on top
## (Spine and up). Firing the weapon fires a short recoil one-shot over the aim
## pose. With no weapon in the parent (tests that instance the body alone) it
## keeps aiming with the rifle.

## Horizontal speed above which the legs run instead of standing.
const RUN_SPEED := 0.5
const IDLE_ANIM := "idle"
const RUN_ANIM := "run"
## The held aim pose: a single keyed frame (0.033 s) of both hands forward.
const AIM_ANIM := "Aiming_1"
## Recoil over the aim pose. It opens and closes on the same pose, so the hold
## comes back cleanly. `Shoot` is not used: its arms are out to the sides and
## would snap out of the aim pose.
const SHOT_ANIM := "Shooting_1_1"
const BLEND_TIME := 0.15
const SHOT_FADE_IN := 0.04
const SHOT_FADE_OUT := 0.12
## Bone the gun hangs from.
const GUN_BONE := "RightHand"
## How far past the wrist the grip sits, along the hand bone's own axis.
const PALM_OFFSET := 0.05
const MATERIAL: Material = preload("res://assets/materials/protagonist_crystal_material.tres")

## Bones the aim pose owns. Hips and the leg chain stay on idle / run.
const UPPER_BONES: Array[StringName] = [
	&"Spine", &"Chest", &"Neck", &"Head",
	&"LeftShoulder", &"LeftArm", &"LeftForeArm", &"LeftHand",
	&"RightShoulder", &"RightArm", &"RightForeArm", &"RightHand",
]

## The gun model shown for each `WeaponData`, keyed by its resource path (the
## order in `Weapon.data_set` is not fixed). `grip` is the pistol grip of the
## model in its own space (the point the right hand wraps); `yaw`/`pitch`/`roll`
## are degrees, `scale` shrinks the mesh to a real gun. After the rotation the
## barrel points at -Z, the player's forward, and `grip` is put exactly on the
## right hand. The ak is authored muzzle along -X (its viewmodel yaw is +90), so
## it needs -90 here; the shotgun and sniper are exported grip-at-origin, muzzle -Z.
const GUNS := {
	"res://weapons/obsidian_pistol/obsidian_pistol.tres": {
		"scene": preload("res://assets/models/weapons/obsidian_pistol.glb"),
		"grip": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0,
		"roll": 0.0, "scale": 1.0,
	},
	"res://weapons/rifle.tres": {
		"scene": preload("res://assets/models/weapons/ak.gltf"),
		"grip": Vector3(0.032, -0.078, 0.0), "yaw": -90.0, "pitch": 0.0,
		"roll": 0.0, "scale": 0.55,
	},
	"res://weapons/shotgun.tres": {
		"scene": preload("res://assets/models/weapons/shotgun.glb"),
		"grip": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0,
		"roll": 0.0, "scale": 0.95,
	},
	"res://weapons/sniper.tres": {
		"scene": preload("res://assets/models/weapons/sniper.glb"),
		"grip": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0,
		"roll": 0.0, "scale": 0.9,
	},
}
## Gun shown when the parent has no Weapon (body instanced alone).
const DEFAULT_GUN := "res://weapons/obsidian_pistol/obsidian_pistol.tres"

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _attachment: BoneAttachment3D
var _gun: Node3D
## Right-hand bone in the aim pose, skeleton space. The gun's local transform is
## derived from it once, so the gun follows the hand through the recoil.
var _hand_xf := Transform3D.IDENTITY
## Where the gun's grip goes: just past the wrist, inside the fist.
var _grip_target := Vector3.ZERO
var _run_blend := 0.0
var _weapon: Weapon
## Which entry of `GUNS` is on screen, so a repeated `selected` swaps nothing.
var _gun_shown := ""


func _ready() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	_dress_meshes(self)
	for clip in [IDLE_ANIM, RUN_ANIM]:
		_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_sample_aim_hand()
	_build_tree()
	_build_gun()
	_bind_weapon()


func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var speed := Vector2(body.velocity.x, body.velocity.z).length() if body != null else 0.0
	_run_blend = move_toward(_run_blend, 1.0 if speed > RUN_SPEED else 0.0, delta / BLEND_TIME)
	_tree.set("parameters/legs/blend_amount", _run_blend)
	# A blade in the player's hands takes the gun off screen; hide it here too.
	if _gun != null and _weapon != null:
		_gun.visible = _weapon.trigger_enabled


## Every mesh of the body casts shadows only; the opaque grey base takes the
## shadow pass (the crystal shader writes ALPHA, and blended materials do not
## cast) while the crystal material is drawn over it.
func _dress_meshes(root: Node) -> void:
	var shadow_caster := StandardMaterial3D.new()
	shadow_caster.albedo_color = Color(0.80, 0.81, 0.83)
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		mi.material_override = shadow_caster
		mi.material_overlay = MATERIAL


## Reads the hand once in the aim pose, so `_gun_transform()` can turn the gun
## to face the player's forward no matter how the bone is oriented at rest. The
## grip target is a little past the wrist along the bone's own Y (wrist to
## fingers), inside the fist rather than at the wrist joint.
func _sample_aim_hand() -> void:
	_anim.play(AIM_ANIM)
	_anim.seek(0.0, true)
	_anim.pause()
	_skeleton.force_update_all_bone_transforms()
	_hand_xf = _skeleton.get_bone_global_pose(_skeleton.find_bone(GUN_BONE))
	_grip_target = _hand_xf.origin + _hand_xf.basis.y.normalized() * PALM_OFFSET


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

	# Legs: idle and run, blended by speed.
	var legs := AnimationNodeBlend2.new()
	# Upper body: the aim pose with the recoil played over it.
	var fire := AnimationNodeOneShot.new()
	fire.fadein_time = SHOT_FADE_IN
	fire.fadeout_time = SHOT_FADE_OUT
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	for bone in UPPER_BONES:
		upper.set_filter_path(NodePath(skeleton_path + ":" + bone), true)

	var root := AnimationNodeBlendTree.new()
	root.add_node("idle", idle, Vector2(-400.0, 0.0))
	root.add_node("run", run, Vector2(-400.0, 120.0))
	root.add_node("legs", legs, Vector2(-200.0, 60.0))
	root.add_node("aim", aim, Vector2(-400.0, 260.0))
	root.add_node("shot", shot, Vector2(-400.0, 380.0))
	root.add_node("fire", fire, Vector2(-200.0, 300.0))
	root.add_node("upper", upper, Vector2(0.0, 160.0))
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
	# The tree drives the skeleton now; the AnimationPlayer must stay quiet.
	_anim.active = false


func _build_gun() -> void:
	_attachment = BoneAttachment3D.new()
	_attachment.name = "GunAttachment"
	_skeleton.add_child(_attachment)
	_attachment.bone_name = GUN_BONE


func _bind_weapon() -> void:
	var body := get_parent()
	_weapon = body.get_node_or_null("Head/Camera3D/Weapon") as Weapon if body != null else null
	if _weapon == null:
		_show_gun(DEFAULT_GUN)
		return
	_weapon.selected.connect(_on_weapon_selected)
	_weapon.fired.connect(_on_weapon_fired)
	_show_gun(_gun_key(_weapon.data))


func _gun_key(data: WeaponData) -> String:
	if data != null and GUNS.has(data.resource_path):
		return data.resource_path
	return DEFAULT_GUN


## Puts `key`'s model in the right hand. The gun only ever moves with the hand;
## it never touches the player or the camera.
func _show_gun(key: String) -> void:
	if key == _gun_shown and _gun != null:
		return
	var entry: Dictionary = GUNS.get(key, GUNS[DEFAULT_GUN])
	var scene: PackedScene = entry["scene"]
	if _gun != null:
		_attachment.remove_child(_gun)
		_gun.queue_free()
	_gun_shown = key
	_gun = scene.instantiate()
	_gun.transform = _gun_transform(entry)
	_attachment.add_child(_gun)
	_gun.name = "Gun"
	_dress_meshes(_gun)


## Where the gun model sits in the hand: turned so the barrel runs along -Z,
## then placed so the model's pistol grip lands on the right hand.
func _gun_transform(entry: Dictionary) -> Transform3D:
	var turn := Basis.from_euler(Vector3(
		deg_to_rad(entry["pitch"]), deg_to_rad(entry["yaw"]), deg_to_rad(entry["roll"])))
	var scale := float(entry["scale"])
	var turned := turn.scaled(Vector3.ONE * scale)
	var grip: Vector3 = entry["grip"]
	var desired := Transform3D(turned, _grip_target - turned * grip)
	return _hand_xf.affine_inverse() * desired


func _on_weapon_selected(_index: int, data: WeaponData) -> void:
	_show_gun(_gun_key(data))


func _on_weapon_fired() -> void:
	_tree.set("parameters/fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
