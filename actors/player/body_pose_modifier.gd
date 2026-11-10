extends SkeletonModifier3D
## Runs after AnimationTree so authored leg motion and the two arm chains agree.
var body: Node3D

func _process_modification() -> void:
	if is_inside_tree() and is_instance_valid(body) and body.is_inside_tree():
		body.pose_arms()
