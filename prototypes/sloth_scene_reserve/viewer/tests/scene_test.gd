extends SceneTree
## Independent environment checks. Movement probes use the real capsule and physics world.

var checks := 0
var failures: Array[String] = []
var world: Node3D
var viewer: CharacterBody3D

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS | ", description)
	else:
		failures.append(description)
		push_error("FAIL | " + description)

func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	_check(scene != null, "Independent main scene loads")
	if scene == null:
		_finish()
		return
	world = scene.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await physics_frame
	await physics_frame
	viewer = world.get_node_or_null("Viewer") as CharacterBody3D
	_check(viewer != null, "Scene creates the walkthrough capsule")
	if viewer == null:
		_finish()
		return
	viewer.set_physics_process(false)
	for landmark in ["CloudSea", "ArrivalBridge", "Sanctuary", "GreatHalo", "QuietCourt", "FloatingPrecincts"]:
		_check(world.get_node_or_null(landmark) != null, "Landmark present: " + landmark)
	_check(viewer.camera.current and viewer.camera.far >= 1000.0, "Active camera includes the distant floating architecture")
	_check(world.environment.fog_enabled, "Atmospheric depth is enabled by default")
	_check(not world.motion_enabled, "Stillness is the default environment state")
	var targets := [Vector3(0,32,-48), Vector3(-2,30,-48), Vector3(-45,2.8,3), Vector3(-5,5,-28)]
	var labels := ["静滞长桥", "环形圣殿", "静息侧庭", "云海"]
	for index in range(4):
		world.set_view(index)
		_check(viewer.camera.global_position.distance_to(viewer.global_position+Vector3.UP*1.7)<0.0001,
			"Viewpoint %d snaps camera immediately to the destination eye position" % (index + 1))
		var toward: Vector3 = (targets[index] - viewer.camera.global_position).normalized()
		_check((-viewer.camera.global_basis.z).dot(toward) > 0.999,
			"Viewpoint %d aims at its intended landmark" % (index + 1))
		_check(_all_labels(world.hud).contains(labels[index]),
			"Viewpoint %d updates the Chinese location label" % (index + 1))
		_check(viewer.flying == (index == 3),
			"Viewpoint %d selects safe walking or aerial mode" % (index + 1))
	_check(_all_labels(world.hud).contains("WASD") and _all_labels(world.hud).contains("云上静滞圣殿"),
		"HUD displays title and walkthrough controls")
	await _shortcut(KEY_1)
	_check(viewer.position.distance_to(Vector3(0,0.1,94))<0.01 and not viewer.flying,
		"Keyboard 1 selects the walking entrance view")
	await _shortcut(KEY_4)
	_check(viewer.position.distance_to(Vector3(93,49,128))<0.01 and viewer.flying,
		"Keyboard 4 selects the aerial panorama")
	await _shortcut(KEY_F)
	_check(not viewer.flying, "Keyboard F switches the aerial viewer back to walking")
	await _shortcut(KEY_R)
	_check(viewer.position.distance_to(Vector3(0,0.1,94))<0.01,
		"Keyboard R restores the entrance view")
	# Floors are queried against static architecture only, excluding the test player.
	var bridge_supported := true
	for z in range(105, -1, -3):
		var hit := _ray(Vector3(0,2,z), Vector3(0,-3,z))
		bridge_supported = bridge_supported and not hit.is_empty()
	_check(bridge_supported, "Bridge-to-sanctuary route has continuous physical ground")
	var court_supported := true
	for x in range(-20, -52, -2):
		var hit := _ray(Vector3(x,2,5), Vector3(x,-3,5))
		court_supported = court_supported and not hit.is_empty()
	_check(court_supported, "Left court route has continuous physical ground")
	_check(not _ray(Vector3(0,1.2,85),Vector3(8,1.2,85)).is_empty(),
		"Bridge barrier blocks the capsule above the visible parapet")
	_check(not _ray(Vector3(0,0.35,-30),Vector3(0,0.35,-49)).is_empty(),
		"Outer sanctuary has a physical perimeter")
	# Exposed upward faces must have a single depth at every sampled walkable point.
	# This tests visible geometry across group boundaries, including the bridge joint.
	var floor_surfaces := _ground_surfaces(world)
	var bridge_samples: Array[Vector2] = []
	for x in [-5.0,0.0,5.0]:
		for z in [42.2,43.5,44.7,45.5,46.2,65.3,78.3,94.1,105.1]:
			bridge_samples.append(Vector2(x,z))
	_check(_unique_ground_depth(floor_surfaces,bridge_samples),
		"Bridge and sanctuary joint contain no exposed coplanar floor faces")
	var sanctuary_samples: Array[Vector2] = []
	for x in [-30.0,-20.0,-10.0,0.0,10.0,20.0,30.0]:
		for z in [-30.0,-20.0,-10.0,0.0,10.0,20.0,30.0]:
			sanctuary_samples.append(Vector2(x,z))
	_check(_unique_ground_depth(floor_surfaces,sanctuary_samples),
		"Main sanctuary ground contains no exposed coplanar floor faces")
	var patio_samples: Array[Vector2] = []
	for side in [-1.0,1.0]:
		for x in [29.04,29.2,35.2,40.2,45.2,50.2,55.2]:
			for z in [-6.94,-6.8,-5.2,5.2,15.2,16.8,16.94]:
				patio_samples.append(Vector2(side*x,z))
	_check(_unique_ground_depth(floor_surfaces,patio_samples),
		"Side courts and their exposed borders contain no coplanar floor faces")
	_check(_visible_floor_matches_collision(floor_surfaces,[Vector2(2.1,78.3),Vector2(-3.1,50.3),Vector2(0.4,44.7)]),
		"Bridge floor and its joint remain within 6 cm of the supporting collision")
	_check(_visible_floor_matches_collision(floor_surfaces,[Vector2(19.1,28.1),Vector2(-20.1,-18.1),Vector2(6.1,0.1)]),
		"Sanctuary and dais stay within 6 cm of the supporting collision")
	_check(_visible_floor_matches_collision(floor_surfaces,[Vector2(-42.1,12.1),Vector2(42.1,12.1),Vector2(-29.04,5.1)]),
		"Side court floors remain within 6 cm of the supporting collision")
	var joint_is_level := true
	for x in [-3.0,0.0,3.0]:
		for z in [41.5,43.5,45.5,47.5,50.5]:
			var hit := _ray(Vector3(x,1,z),Vector3(x,-1,z))
			joint_is_level = joint_is_level and not hit.is_empty()
			if not hit.is_empty(): joint_is_level = joint_is_level and absf(hit.position.y)<0.002
	_check(joint_is_level, "Bridge-to-sanctuary collision stays on one level across the visual joint")
	# Real move_and_slide traversal checks detect invisible walls and step-height problems.
	var bridge_end: Vector3 = await _walk(Vector3(0,0.05,103),Vector3(0,0,30))
	_check(absf(bridge_end.x)<0.5 and bridge_end.z<31.0 and bridge_end.y>-0.2,
		"Capsule walks from entry bridge onto sanctuary without falling or obstruction")
	var reverse_bridge_end: Vector3 = await _walk(Vector3(0,0.05,30),Vector3(0,0,103))
	_check(absf(reverse_bridge_end.x)<0.5 and reverse_bridge_end.z>102.0 and absf(reverse_bridge_end.y)<0.01,
		"Capsule walks back from sanctuary onto the bridge without a collision step")
	var dais_end: Vector3 = await _walk(Vector3(0,0.05,20),Vector3(0,0,0))
	_check(dais_end.z<1.0 and dais_end.y>0.30,
		"Capsule walks onto the central dais without a required jump")
	var court_end: Vector3 = await _walk(Vector3(-25,0.05,5),Vector3(-49,0,5))
	_check(court_end.x < -48.0 and court_end.y>-0.2,
		"Capsule walks through the sanctuary perimeter into the quiet court")
	world.set_view(0)
	viewer.flying = true
	viewer.reset_view()
	_check(not viewer.flying and viewer.position.distance_to(Vector3(0,0.1,94))<0.01,
		"Reset returns flying viewer to the safe bridge entrance")
	_check(viewer.camera.global_position.distance_to(viewer.global_position+Vector3.UP*1.7)<0.0001,
		"Reset synchronizes the camera eye immediately without the old viewpoint")
	var was_fog: bool = world.environment.fog_enabled
	world.toggle_atmosphere()
	_check(world.environment.fog_enabled != was_fog, "Atmosphere switch changes the fog state")
	world.toggle_atmosphere()
	world.set_process(false)
	world.toggle_motion()
	world._process(2.0)
	_check(world.halo.rotation.z != 0.0, "Optional motion preview animates the great halo")
	world.toggle_motion()
	var frozen: Transform3D = world.halo.transform
	world._process(2.0)
	_check(world.halo.transform.is_equal_approx(frozen), "Disabling motion freezes the environment again")
	var ui: Control = world.hud.get("_root")
	world.hud.toggle_visibility()
	_check(not ui.visible, "Clean-view command hides the HUD")
	world.hud.toggle_visibility()
	_check(ui.visible, "HUD can be restored")
	world.hud.set_proof_mode(true)
	_check(not ui.visible, "Screenshot mode removes the HUD")
	world.hud.set_proof_mode(false)
	_check(_local_resource_references(), "Scene source references stay inside this standalone project")
	world.queue_free()
	await process_frame
	_finish()

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	query.exclude = [viewer.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _walk(start: Vector3, target: Vector3) -> Vector3:
	viewer.flying = false
	viewer.global_position = start
	viewer.velocity = Vector3.ZERO
	viewer.snap_camera()
	await physics_frame
	var distance := Vector2(target.x-start.x,target.z-start.z).length()
	var frames := ceili((distance+3.0)/8.0*60.0)
	for frame in range(frames):
		await physics_frame
		var difference := Vector3(target.x-viewer.position.x,0,target.z-viewer.position.z)
		if difference.length()<0.25:
			break
		var direction := difference.normalized()
		viewer.velocity.x = direction.x*8.0
		viewer.velocity.z = direction.z*8.0
		if not viewer.is_on_floor():
			viewer.velocity.y -= 9.8/60.0
		viewer.move_and_slide()
	print("TRAVERSE | ",start," -> ",target," | reached ",viewer.position)
	return viewer.position

func _all_labels(parent: Node) -> String:
	var text := ""
	if parent is Label: text += parent.text+"\n"
	for child in parent.get_children(): text += _all_labels(child)
	return text

func _ground_surfaces(parent: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if parent is MeshInstance3D and parent.mesh != null and parent.is_visible_in_tree():
		var instance := parent as MeshInstance3D
		# Tilted decorative fragments are not walkable horizontal floor faces.
		if instance.global_basis.y.normalized().dot(Vector3.UP)>0.9999:
			var local_top: Array[Vector3] = []
			if instance.mesh is BoxMesh:
				var dimensions: Vector3 = instance.mesh.size*0.5
				for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
					local_top.append(Vector3(corner.x*dimensions.x,dimensions.y,corner.y*dimensions.z))
			elif instance.mesh is CylinderMesh:
				var cylinder := instance.mesh as CylinderMesh
				if cylinder.cap_top:
					for index in range(cylinder.radial_segments):
						var angle := TAU*index/cylinder.radial_segments
						local_top.append(Vector3(sin(angle)*cylinder.top_radius,cylinder.height*0.5,cos(angle)*cylinder.top_radius))
			var footprint := PackedVector2Array()
			var height := -INF
			for point in local_top:
				var position := instance.global_transform*point
				footprint.append(Vector2(position.x,position.z))
				height = position.y
			# Broad surfaces near foot level; fine inlays and raised furniture are excluded.
			if height>=-0.8 and height<=0.7 and _polygon_area(footprint)>=16.0:
				result.append({"footprint":footprint,"height":height,"name":str(instance.get_path())})
	for child in parent.get_children():
		result.append_array(_ground_surfaces(child))
	return result

func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(points.size()):
		area += points[index].cross(points[(index+1)%points.size()])
	return absf(area)*0.5

func _tops_at(surfaces: Array[Dictionary], point: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for surface in surfaces:
		if Geometry2D.is_point_in_polygon(point,surface.footprint):
			result.append(surface)
	return result

func _unique_ground_depth(surfaces: Array[Dictionary], samples: Array[Vector2]) -> bool:
	var valid := true
	var reported := 0
	for point in samples:
		var tops := _tops_at(surfaces,point)
		if tops.is_empty(): continue
		var highest := -INF
		for top in tops: highest = maxf(highest,top.height)
		var at_highest: Array[String] = []
		for top in tops:
			if absf(top.height-highest)<0.002:
				at_highest.append(top.name)
		if at_highest.size()>1:
			valid = false
			if reported<3:
				print("COPLANAR_FLOOR | ",point," | height ",highest," | ",at_highest)
				reported += 1
	return valid

func _visible_floor_matches_collision(surfaces: Array[Dictionary], samples: Array[Vector2]) -> bool:
	for point in samples:
		var tops := _tops_at(surfaces,point)
		if tops.is_empty(): return false
		var highest := -INF
		for top in tops: highest = maxf(highest,top.height)
		var hit := _ray(Vector3(point.x,1.0,point.y),Vector3(point.x,-1.0,point.y))
		if hit.is_empty(): return false
		if absf(highest-hit.position.y)>0.06:
			print("FLOOR_COLLISION_GAP | ",point," | render ",highest," | collision ",hit.position.y)
			return false
	return true

func _shortcut(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame

func _local_resource_references() -> bool:
	for path in ["res://project.godot","res://main.tscn","res://sanctum.gd","res://viewer.gd","res://viewer_hud.gd","res://cloud_sea.gdshader","res://sanctum_sky.gdshader","res://stone.gdshader","res://floor.gdshader"]:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("D:\\") or text.contains("../") or text.contains("res://../"): return false
		var pattern := RegEx.new()
		pattern.compile("res://[A-Za-z0-9_./-]+")
		for found in pattern.search_all(text):
			if not FileAccess.file_exists(found.get_string()): return false
	return true

func _finish() -> void:
	print("SCENE_TEST_SUMMARY | ",checks," checks | ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
