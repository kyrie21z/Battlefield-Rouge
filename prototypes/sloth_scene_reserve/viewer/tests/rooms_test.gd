extends SceneTree
## Two-room reserve verification; real capsule probes and world collision queries.
## Run headless with --fixed-fps 60. Keep APPDATA/log-file inside the reserve folder.

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
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == "res://main.tscn",
		"Boss reserve remains the project default entry")
	var scene := load("res://rooms_preview.tscn") as PackedScene
	_check(scene != null, "Independent rooms preview scene loads")
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
	_check(viewer != null, "Two-room preview creates the real walkthrough capsule")
	if viewer == null:
		_finish()
		return
	viewer.set_physics_process(false)
	_check(world.get_node_or_null("CloudSea") != null and world.get_node_or_null("HorizonPrecincts") != null,
		"Rooms share the cloud sea and restrained floating horizon")
	_check(world.get_node_or_null("GreatHalo") == null, "Full giant ring remains reserved for the Boss scene")
	for index in range(2):
		world.set_room(index)
		await process_frame
		await physics_frame
		await physics_frame
		await _check_room(index)
	# Exercise both bindings through the Viewport's actual input dispatch.
	await _shortcut(KEY_F1)
	_check(world.room_index == 0, "F1 input loads the first room")
	await _shortcut(KEY_F2)
	_check(world.room_index == 1, "F2 input loads the second room")
	var buttons: Array = world.hud.room_buttons
	_check(buttons.size() == 2 and buttons[0] is Button and buttons[1] is Button,
		"HUD exposes two real room-selection buttons")
	if buttons.size() == 2:
		buttons[0].pressed.emit()
		await process_frame
		_check(world.room_index == 0 and _all_text(world.hud).contains("停滞前庭"),
			"First HUD button loads the first room and its Chinese title")
		buttons[1].pressed.emit()
		await process_frame
		_check(world.room_index == 1 and _all_text(world.hud).contains("锚定回廊"),
			"Second HUD button loads the second room and its Chinese title")
	for repeat in range(4):
		world.set_room(repeat % 2)
		# Group queries must immediately exclude the detached old geometry, even
		# before its queued resources have been released at the end of this frame.
		_check(_active_group("CoverPieces").size() == 20 + repeat % 2
			and _active_group("EncounterSlots").size() == world.encounter_slots.get_child_count(),
			"Repeated template switch %d keeps only current cover and planning slots" % (repeat + 1))
		await process_frame
	_check(_active_room_geometry_count() == 1, "Only one room geometry subtree remains after repeated switches")
	_check(_all_text(world.hud).contains("F1") and _all_text(world.hud).contains("F2")
		and _all_text(world.hud).contains("WASD"), "Chinese HUD retains room shortcuts and movement controls")
	_check(_local_resources_only(), "Room preview resource dependencies remain inside the reserve project")
	world.queue_free()
	await process_frame
	_finish()

func _check_room(index: int) -> void:
	var prefix := "Room %d: " % (index + 1)
	_check(world.room_index == index, prefix + "room selection state matches the loaded template")
	var shell: Node = world.room_geometry.get_node_or_null("WalkableShell")
	_check(shell != null and shell.get_node_or_null("SunkenCourt") != null
		and shell.get_node_or_null("EntryFloor") != null and shell.get_node_or_null("ExitFloor") != null,
		prefix + "sunken courtyard and both connecting floors are present")
	if shell == null: return
	var surfaces := _ground_surfaces(world.room_geometry)
	var levels: Array[float] = []
	var x_min := INF
	var x_max := -INF
	var z_min := INF
	var z_max := -INF
	for surface in surfaces:
		if surface.normal.y>0.999:
			var level := snappedf(surface.origin.y,0.01)
			if not levels.has(level): levels.append(level)
		if surface.name.ends_with("EntryFloor") or surface.name.ends_with("ExitFloor"): continue
		for point in surface.footprint:
			x_min = minf(x_min,point.x)
			x_max = maxf(x_max,point.x)
			z_min = minf(z_min,point.y)
			z_max = maxf(z_max,point.y)
	levels.sort()
	_check(x_max-x_min>=95.9 and z_max-z_min>=127.9,
		prefix + "combat terrain spans the enlarged 96 by 128 metre footprint")
	_check(levels.size()>=4 and levels.front() < -2.0 and levels.back()>4.0,
		prefix + "flat combat spaces include lowered, ground and two elevated levels")
	_check(_active_group("TerrainRamps").size()>=9,
		prefix + "ramps and an inclined cross-court bridge connect the vertical levels")
	var covers := _active_group("CoverPieces")
	var partial := 0
	var full := 0
	var central := 0
	var all_block_low := true
	var full_block_eye := true
	var partial_clear_eye := true
	for piece in covers:
		if piece.name == "CentralDetour":
			central += 1
		elif piece.get_meta("cover_role", "") == "partial":
			partial += 1
		else:
			full += 1
		var dimensions: Vector3 = piece.mesh.size
		var center: Vector3 = piece.global_position
		var ground := center.y-dimensions.y*0.5
		# Probe one nearby face rather than starting on a neighbouring column.
		var a := Vector3(center.x + dimensions.x*0.5 + 0.18,ground+0.8,center.z)
		var b := Vector3(center.x,ground+0.8,center.z)
		var low_hit := _ray(a,b)
		if not _hit_piece(low_hit,piece):
			print("COVER_PROBE | ",piece.get_path()," | expected ",piece.get_instance_id()," | hit ",str(low_hit))
		all_block_low = all_block_low and _hit_piece(low_hit,piece)
		a.y = ground+1.7
		b.y = ground+1.7
		if piece.get_meta("cover_role", "") == "partial":
			partial_clear_eye = partial_clear_eye and not _hit_piece(_ray(a,b),piece)
		else:
			full_block_eye = full_block_eye and _hit_piece(_ray(a,b),piece)
	_check(partial == 12 and full == 8 and central == index,
		prefix + "twelve partial and eight full covers are distinct from the optional central barrier")
	_check(all_block_low, prefix + "every authored cover piece blocks a low world ray")
	_check(full_block_eye, prefix + "full cover and central barrier reliably stop standing-eye-height rays")
	_check(partial_clear_eye, prefix + "low cover is honestly partial at standing-eye height")
	var slots := _active_group("EncounterSlots")
	var planning_only: bool = slots.size() >= 3 and slots.size() == world.encounter_slots.get_child_count()
	for slot in slots:
		planning_only = planning_only and slot is Marker3D and slot.get_meta("planning_only",false)
		planning_only = planning_only and slot.get_child_count() == 0
	_check(planning_only, prefix + "authored encounter slots remain planning markers without enemy behaviour")
	_check(_all_text(world.hud).contains(["停滞前庭","锚定回廊"][index]), prefix + "Chinese title matches the selected room")
	for view_index in range(4):
		world.set_view(view_index)
		_check(viewer.camera.current and viewer.camera.global_position.distance_to(viewer.global_position+Vector3.UP*1.7)<0.0001,
			prefix + "view %d immediately synchronizes the camera eye" % (view_index + 1))
		var target: Vector3 = world.room_targets[view_index]
		_check((-viewer.camera.global_basis.z).dot((target-viewer.camera.global_position).normalized())>0.999
			and viewer.flying == (view_index == 3),
			prefix + "view %d aims correctly and uses the appropriate movement mode" % (view_index + 1))
	# Compare actual mesh plane equations with actual physics support. This checks
	# flat galleries and tilted ramps without accepting metadata as proof.
	_check(_floor_collision_matches_surfaces(surfaces),
		prefix + "all sampled flat floors and ramps match their physical top surfaces")
	var seams_level := true
	for x in [-3.0,0.0,3.0]:
		for z in [-80.0,-66.0,-64.02,-63.98,63.98,64.02,66.0,80.0]:
			var hit := _ray(Vector3(x,0.2,z),Vector3(x,-0.5,z))
			seams_level = seams_level and not hit.is_empty()
			if not hit.is_empty(): seams_level = seams_level and absf(hit.position.y)<0.002
	_check(seams_level, prefix + "entry and exit bridge joints are physically continuous and level")
	_check(_unique_ground_depth(surfaces,_geometry_samples(surfaces)),
		prefix + "no sampled exposed floor or slope has competing coplanar top faces")
	var center_hit := _ray(Vector3(0,-0.8,12),Vector3(0,-0.8,0))
	_check((not center_hit.is_empty()) == (index == 1), prefix + "central line is open in room one and blocked only by room two's detour wall")
	if index == 0:
		_check(await _walk_path([Vector3(0,0.05,80),Vector3(0,0,34),Vector3(0,-2.5,14),
			Vector3(0,-2.5,-14),Vector3(0,0,-34),Vector3(0,0,-80)]),
			prefix + "real capsule descends through the court and climbs back to the exit without jumping")
	else:
		for side in [-1.0,1.0]:
			_check(await _walk_path([Vector3(0,0.05,80),Vector3(0,0,34),Vector3(0,-2.5,14),
				Vector3(side*8,-2.5,12),Vector3(side*8,-2.5,0),Vector3(0,-2.5,-14),Vector3(0,0,-34),Vector3(0,0,-80)]),
				prefix + "real capsule bypasses the central wall on its %s side and reaches the exit" % ("left" if side<0 else "right"))
	for side in [-1.0,1.0]:
		_check(await _walk_path([Vector3(0,0.05,80),Vector3(0,0,54.5),Vector3(side*29,0,54.5),
			Vector3(side*29,0,-55.25),Vector3(0,0,-55.25),Vector3(0,0,-80)]),
			prefix + "real capsule traverses the %s alternative route without jumping or falling" % ("left" if side<0 else "right"))
	_check(await _walk_path([Vector3(0,0.05,80),Vector3(0,0,54.5),Vector3(-39,0,54.5),
		Vector3(-39,3,20),Vector3(-36,3,20),Vector3(-36,3,-9),Vector3(36,5,-9),
		Vector3(39,5,-15),Vector3(39,0,-55.25),Vector3(0,0,-55.25),Vector3(0,0,-80)]),
		prefix + "real capsule climbs the left gallery, crosses the high bridge and descends the right gallery")
	for side in [-1.0,1.0]:
		_check(await _walk_path([Vector3(side*39,0.05,26),Vector3(side*39,0,-20)]),
			prefix + "real capsule passes beneath the %s gallery with head clearance" % ("left" if side<0 else "right"))
		_check(await _walk_path([Vector3(0,-2.45,0),Vector3(side*29,0,0)]),
			prefix + "real capsule uses the %s side ramp from the lowered court to ground level" % ("left" if side<0 else "right"))
	world.set_view(0)
	viewer.flying = true
	viewer.reset_view()
	_check(not viewer.flying and viewer.position.z>40.0
		and viewer.camera.global_position.distance_to(viewer.global_position+Vector3.UP*1.7)<0.0001,
		prefix + "reset returns to a safe walking entrance and snaps the camera")

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	query.exclude = [viewer.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _hit_piece(hit: Dictionary, piece: Node) -> bool:
	return not hit.is_empty() and hit.collider.get_parent() == piece

func _walk_path(points: Array[Vector3]) -> bool:
	var lowest := INF
	for point in points: lowest = minf(lowest,point.y)
	viewer.flying = false
	viewer.global_position = points[0]
	viewer.velocity = Vector3.ZERO
	viewer.snap_camera()
	await physics_frame
	for index in range(1,points.size()):
		var target := points[index]
		var distance := Vector2(target.x-viewer.position.x,target.z-viewer.position.z).length()
		var budget := ceili((distance+4.0)/8.0*60.0)
		for frame in range(budget):
			await physics_frame
			var difference := Vector3(target.x-viewer.position.x,0,target.z-viewer.position.z)
			if difference.length()<0.25: break
			var direction := difference.normalized()
			viewer.velocity.x = direction.x*8.0
			viewer.velocity.z = direction.z*8.0
			if not viewer.is_on_floor(): viewer.velocity.y -= 9.8/60.0
			viewer.move_and_slide()
			if viewer.position.y < lowest-0.3:
				print("ROUTE_FALL | at ",viewer.position)
				return false
		if Vector2(target.x-viewer.position.x,target.z-viewer.position.z).length()>0.4:
			print("ROUTE_BLOCKED | wanted ",target," reached ",viewer.position)
			return false
		if absf(viewer.position.y-target.y)>0.12:
			print("ROUTE_WRONG_LEVEL | wanted ",target," reached ",viewer.position)
			return false
	print("ROUTE_PASS | room ",world.room_index+1," | ",points[0]," -> ",points[points.size()-1]," | ",viewer.position)
	return absf(viewer.position.y-points[points.size()-1].y)<0.06

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
	await physics_frame

func _active_group(title: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_nodes_in_group(title):
		if node.is_inside_tree() and world.is_ancestor_of(node): result.append(node)
	return result

func _active_room_geometry_count() -> int:
	var count := 0
	for child in world.get_children():
		if child.get_meta("room_index",-1)>=0: count += 1
	return count

func _all_text(parent: Node) -> String:
	var result := ""
	if parent is Label or parent is Button: result += parent.text+"\n"
	for child in parent.get_children(): result += _all_text(child)
	return result

func _ground_surfaces(parent: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if parent is MeshInstance3D and parent.mesh is BoxMesh and parent.is_visible_in_tree() and parent.is_in_group("WalkableFloors"):
		var mi := parent as MeshInstance3D
		var normal := (mi.global_basis.inverse().transposed()*Vector3.UP).normalized()
		if normal.y>0.5:
			var half: Vector3 = mi.mesh.size*0.5
			var footprint := PackedVector2Array()
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point: Vector3 = mi.global_transform*Vector3(corner.x*half.x,half.y,corner.y*half.z)
				footprint.append(Vector2(point.x,point.z))
			var origin := mi.global_transform*Vector3(0,half.y,0)
			result.append({"origin":origin,"normal":normal,"footprint":footprint,"name":str(mi.get_path()),
				"half_x":mi.global_basis.x*half.x,"half_z":mi.global_basis.z*half.z})
	for child in parent.get_children(): result.append_array(_ground_surfaces(child))
	return result

func _surface_y_at(surface: Dictionary, point: Vector2) -> float:
	return (surface.normal.dot(surface.origin)-surface.normal.x*point.x-surface.normal.z*point.y)/surface.normal.y

func _geometry_samples(surfaces: Array[Dictionary]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for surface in surfaces:
		for u in [-0.96,-0.5,0.0,0.5,0.96]:
			for v in [-0.96,-0.5,0.0,0.5,0.96]:
				var point: Vector3 = surface.origin+surface.half_x*u+surface.half_z*v
				result.append(Vector2(point.x,point.z))
	return result

func _floor_collision_matches_surfaces(surfaces: Array[Dictionary]) -> bool:
	for surface in surfaces:
		for u in [-0.9,0.0,0.9]:
			for v in [-0.9,0.0,0.9]:
				var point: Vector3 = surface.origin+surface.half_x*u+surface.half_z*v
				var hit := _ray(point+Vector3.UP*0.15,point-Vector3.UP*0.5)
				if hit.is_empty() or absf(hit.position.y-point.y)>0.04:
					print("FLOOR_COLLISION_GAP | ",surface.name," | expected ",point," | hit ",hit)
					return false
	return not surfaces.is_empty()

func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(points.size()): area += points[index].cross(points[(index+1)%points.size()])
	return absf(area)*0.5

func _unique_ground_depth(surfaces: Array[Dictionary], samples: Array[Vector2]) -> bool:
	for point in samples:
		var highest := -INF
		var count := 0
		for surface in surfaces:
			if not Geometry2D.is_point_in_polygon(point,surface.footprint): continue
			var height := _surface_y_at(surface,point)
			if height>highest+0.002:
				highest = height
				count = 1
			elif absf(height-highest)<0.002: count += 1
		if count!=1:
			print("FLOOR_DEPTH_CONFLICT | at ",point," | visible top count ",count)
			return false
	return true

func _local_resources_only() -> bool:
	var pattern := RegEx.new()
	pattern.compile("res://[A-Za-z0-9_./-]+")
	for path in ["res://rooms_preview.tscn","res://rooms.gd","res://rooms_hud.gd","res://viewer.gd"]:
		var source := FileAccess.get_file_as_string(path)
		if source.contains("D:\\") or source.contains("../") or source.contains("RunState") or source.contains("res://actors/"): return false
		for found in pattern.search_all(source):
			if not FileAccess.file_exists(found.get_string()): return false
	return true

func _finish() -> void:
	print("ROOMS_TEST_SUMMARY | ",checks," checks | ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
