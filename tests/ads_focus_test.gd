extends Node3D
var checks := 0
var failures := 0
func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])
func _ready() -> void:
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var focus := player.get_node("ADSFocus") as ADSFocus
	focus.set_process(false)
	check("render camera owns private attributes; logical aim untouched",player.view_camera.attributes==focus.attributes and player._camera.attributes==null)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8,8,1)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0,0,-10)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var expected_distance := (player._camera.global_position.z+9.5)/player._camera.global_basis.z.z
	print("ACTUAL EYE ",player._camera.global_position," WALL DISTANCE ",focus.measure_distance()," EXPECTED ",expected_distance)
	check("physics ray focuses actual world wall",is_equal_approx(focus.measure_distance(),expected_distance))
	player.weapon.aiming = true
	for i in 30: focus._process(1.0/60)
	check("ADS keeps the sight picture sharp (no depth of field)",focus.amount==0 and not focus.attributes.dof_blur_near_enabled and not focus.attributes.dof_blur_far_enabled)
	check("focus converges on true target depth",absf(focus.focus_distance-expected_distance)<0.03)
	check("rays are rate limited",focus.ray_count<=12)
	check("target stays between unblurred focus distances",focus.attributes.dof_blur_near_distance<9.5 and focus.attributes.dof_blur_far_distance>9.5)
	player.weapon.aiming = false
	for i in 15: focus._process(1.0/60)
	check("hipfire completely disables DOF",focus.amount==0 and not focus.attributes.dof_blur_far_enabled)
	player.weapon.aiming = true
	focus._process(0.2)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	check("cinematic lock clears retained blur",focus.amount==0 and not focus.attributes.dof_blur_near_enabled)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	focus._process(0.2)
	player.health.apply_damage(10000,Hitbox.BodyPart.BODY)
	check("death clears DOF immediately",focus.amount==0 and not focus.attributes.dof_blur_far_enabled)
	var resource := preload("res://environments/default_env.tres")
	check("white-space profile includes SSAO and SSIL",resource.ssao_enabled and resource.ssil_enabled)
	var copy := resource.duplicate() as Environment
	copy.ssao_intensity = 0.1
	check("realm copies cannot mutate shared profile",resource.ssao_intensity>1.0)
	for child in get_children(): child.queue_free()
	await get_tree().process_frame
	print("ADS FOCUS: %d checks, %d failures"%[checks,failures])
	get_tree().quit(1 if failures else 0)
