extends SceneTree
## Check the corrected ordinary crown, including every physical mesh corner.
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
	check("physical crown fits authored human head dimensions",bounds.size.x>0.20 and bounds.size.x<0.24 and bounds.size.y<0.15 and bounds.size.z>0.24 and bounds.size.z<0.28)
	check("ordinary crown contains only band, rims and six points",meshes.size()==42)
	check("crown has no face or appendage nodes",crown.get("face")==null and crown.get("gloves")==null and crown.get("pupils")==null)
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
	check("worn crown retains the same simple silhouette",crown.worn and meshes.all(func(mesh):return mesh.visible))
	world.queue_free()
	await process_frame
	print("CROWN BOUNDS: %s (%d checks)" % ["ALL PASSED" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
