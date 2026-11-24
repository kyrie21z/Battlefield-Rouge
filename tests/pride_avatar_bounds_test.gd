extends SceneTree
## Check the A3 crown in the camera and in the worn, shadow-only state.
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var crown := CrownModel.new()
	world.add_child(crown)
	crown.set_process(false)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.12, 2.8)
	world.add_child(camera)
	camera.make_current()
	await process_frame
	var meshes:=crown.find_children("*", "MeshInstance3D", true, false)
	var bounds:=AABB(Vector3.ZERO,Vector3.ZERO)
	for mesh in meshes:
		for corner in 8:bounds=bounds.expand(mesh.global_transform*mesh.get_aabb().get_endpoint(corner))
	print("PHYSICAL CROWN AABB: %.4f x %.4f x %.4f m; inner %.5f x %.4f m" % [bounds.size.x,bounds.size.y,bounds.size.z,CrownModel.INNER_WIDTH,CrownModel.INNER_DEPTH])
	check("physical crown fits authored human head dimensions",
		bounds.size.x > 0.13 and bounds.size.x < 0.18 and bounds.size.y < 0.12
		and bounds.size.z > 0.16 and bounds.size.z < 0.21)
	check("A3 crown is one crystal mesh", meshes.size() == 1)
	check("crown has no face or appendage nodes",
		crown.find_children("*Face*", "", true, false).is_empty()
		and crown.find_children("*Glove*", "", true, false).is_empty()
		and crown.find_children("*Pupil*", "", true, false).is_empty())
	for state in 20:
		crown.rotation.y = state * TAU / 20.0
		var fits := true
		for mesh in meshes:
			for corner in 8:
				var point: Vector3 = mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
				var projected := camera.unproject_position(point)
				fits = fits and root.get_visible_rect().grow(-8).has_point(projected)
		check("complete simple crown fits camera at angle %d" % state, fits)
	crown.set_worn(true)
	check("worn crown retains the same silhouette in its shadow",crown.worn and meshes.all(func(mesh):
		return mesh.visible and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY))
	crown.set_worn(false)
	check("the crown renders before it is worn",meshes.all(func(mesh):
		return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
	var second_crown := CrownModel.new()
	second_crown.set_emission_strength(3.0)
	world.add_child(second_crown)
	crown.set_emission_strength(-1.0)
	check("each crown keeps its own nonnegative emission on the visible mesh",
		meshes.size() == 1 and meshes[0].material_override == crown.crystal_material
		and is_zero_approx(float(crown.crystal_material.get_shader_parameter("emission_strength")))
		and is_equal_approx(float(second_crown.crystal_material.get_shader_parameter("emission_strength")), 3.0))
	world.queue_free()
	await process_frame
	print("CROWN BOUNDS: %s (%d checks)" % ["ALL PASSED" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
