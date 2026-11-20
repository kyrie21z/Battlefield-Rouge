extends SkeletonModifier3D
## Place both wrists at model-space grips after walking/idle animation.
var anchor := "Chest"
var left := Vector3(-0.355, 1.35, -0.18)
var right := Vector3(0.355, 1.35, -0.18)


func _process_modification() -> void:
	var rig := get_skeleton()
	if rig == null:
		return
	var index := rig.find_bone(anchor)
	var delta := rig.get_bone_global_pose(index) * rig.get_bone_global_rest(index).affine_inverse()
	_reach(rig, "Left", delta * left, Vector3(-0.65, -1, 0.1))
	_reach(rig, "Right", delta * right, Vector3(0.65, -1, 0.1))


func _reach(rig: Skeleton3D, prefix: String, goal: Vector3, pole: Vector3) -> void:
	var arm := rig.find_bone(prefix + "Arm")
	var forearm := rig.find_bone(prefix + "ForeArm")
	var hand := rig.find_bone(prefix + "Hand")
	var shoulder := rig.get_bone_global_pose(arm).origin
	var elbow := rig.get_bone_global_pose(forearm).origin
	var wrist := rig.get_bone_global_pose(hand).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var aim := shoulder.direction_to(goal)
	var reach := clampf(shoulder.distance_to(goal), absf(a - b) + 0.001, a + b - 0.001)
	var along := (a*a - b*b + reach*reach) / (2.0 * reach)
	var bend := pole.slide(aim).normalized() * sqrt(maxf(0.0, a*a - along*along))
	_turn(rig, arm, elbow - shoulder, aim * along + bend)
	elbow = rig.get_bone_global_pose(forearm).origin
	wrist = rig.get_bone_global_pose(hand).origin
	_turn(rig, forearm, wrist - elbow, shoulder + aim * reach - elbow)


func _turn(rig: Skeleton3D, index: int, from: Vector3, to: Vector3) -> void:
	var pose := rig.get_bone_global_pose(index)
	pose.basis = Basis(Quaternion(from.normalized(), to.normalized())) * pose.basis
	rig.set_bone_global_pose(index, pose)
