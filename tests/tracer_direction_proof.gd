extends Node
## Real pistol shots from different headings, hip and ADS, with frozen tracer snapshots.
## --baseline re-applies only the old transform formula to the same real mesh;
## the shot, seed, camera, geometry and tracer travel are identical in both runs.

const MAX_JPEG_BYTES := 150000
const CASES := [
	[0, 60.0, 12.0, false, "pistol"],
	[1, -65.0, -15.0, false, "pistol-left"],
	[2, 105.0, 25.0, false, "pistol-up"],
	[3, -75.0, -10.0, true, "pistol-ads"],
]

var _out := "res://docs/proof/tracer-direction"
var _baseline := false
var _checks := 0
var _failures := 0
var _spawned: Array[Tracer] = []
var _scene: Node
var _player: Player


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--baseline":
			_baseline = true
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("Tracer direction proof requires a native display")
		get_tree().quit(1)
		return
	_out = ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame
	await _run()
	print("TRACER DIRECTION %s: %d checks, %d failed" % ["BASELINE" if _baseline else "FIXED", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	RunState.start_fixture(RunFixture.by_id("FX-001"))
	BuffPool.reset(40408)
	_scene = load("res://maps/zone_1.tscn").instantiate()
	_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_scene)
	_player = _scene.get_node("Player") as Player
	var director := _scene.get_node("ZoneDirector") as ZoneDirector
	(director.selection.get_node("Center/Box/Choices").get_child(0) as Button).pressed.emit()
	get_tree().paused = false
	_player.set_process(false)
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.weapon.set_process(false)
	_player.global_position = Vector3(60, 0, 0)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		enemy.set_physics_process(false)
		enemy.global_position += Vector3(1000, 0, 0)
	var banner := _scene.get_node("HUD/PhaseBanner") as Control
	banner.set_process(false)
	banner.hide()
	_add_floor()
	var direction := _direction(60.0, 12.0)
	_add_board(_player.eye_position() + direction * 30.0, direction)
	for frame in 4:
		await get_tree().physics_frame
	get_tree().node_added.connect(_on_node_added)
	# Both modes use exactly the same spread/recoil random sequence.
	seed(20261104)
	for values: Array in CASES:
		await _fire_case(values)
	get_tree().node_added.disconnect(_on_node_added)
	_scene.queue_free()
	await get_tree().process_frame


func _fire_case(values: Array) -> void:
	var weapon := _player.weapon

	weapon.aiming = bool(values[3])
	weapon._view_base = weapon.data.ads_position if weapon.aiming else weapon.data.hip_position
	weapon._apply_view_pose(0.0)
	weapon._cooldown = 0.0
	weapon._spread = 0.0
	_player._visual_kick = Vector2.ZERO
	var forward := _direction(float(values[1]), float(values[2]))
	_player.aim_at(_player.eye_position() + forward * 30.0)
	_player.view_camera.fov = weapon.fov_for(_player.base_fov)
	_spawned.clear()
	_check("%s real shot accepted" % values[4], weapon.try_fire())
	var expected_count := mini(maxi(weapon.data.pellets, 1), weapon.data.max_tracers)
	_check("%s spawns the configured number of tracers" % values[4], _spawned.size() == expected_count)
	if bool(values[3]):
		_check("ADS retains the pistol in view", weapon.aiming and weapon._view.visible
			and is_equal_approx(_player.view_camera.fov, weapon.fov_for(_player.base_fov)))
	for tracer in _spawned:
		tracer.set_process(false)
		_validate_stages(tracer, str(values[4]))
	if int(values[0]) == 0 and not _spawned.is_empty():
		var tracer := _spawned[0]
		tracer._travelled = 2.0
		_place_snapshot(tracer)
		weapon._flash.visible = false
		var guide := _add_guide(tracer)
		await _shot(("before" if _baseline else "after") + "-01-first-person")
		var observer := Camera3D.new()
		_scene.add_child(observer)
		var center := tracer._from + tracer._direction
		var side := tracer._direction.cross(Vector3.UP).normalized()
		observer.global_position = center + side * 2.8 + Vector3.UP * 1.3
		observer.look_at(center)
		observer.fov = 65.0
		observer.make_current()
		await _shot(("before" if _baseline else "after") + "-02-observer")
		_player.view_camera.make_current()
		observer.queue_free()
		guide.queue_free()
	for tracer in _spawned:
		tracer.queue_free()
	await get_tree().process_frame


func _validate_stages(tracer: Tracer, label: String) -> void:
	var original_from := tracer._from
	var original_direction := tracer._direction
	var original_distance := tracer._distance
	for travelled in [0.4, 2.0, 7.0, tracer._distance + 3.0]:
		tracer._travelled = travelled
		_place_snapshot(tracer)
		var head := minf(travelled, tracer._distance)
		var tail := maxf(travelled - Tracer.LENGTH, 0.0)
		var world_tail := tracer.to_global(Vector3(0, 0, 0.5))
		var world_head := tracer.to_global(Vector3(0, 0, -0.5))
		var expected_tail := tracer._from + tracer._direction * tail
		var expected_head := tracer._from + tracer._direction * head
		var alignment := (world_head - world_tail).normalized().dot(tracer._direction)
		var width_x := tracer.global_basis.x.length() * Tracer.THICKNESS
		var width_y := tracer.global_basis.y.length() * Tracer.THICKNESS
		var endpoints_match := world_tail.distance_to(expected_tail) < 0.0001 and world_head.distance_to(expected_head) < 0.0001
		var width_matches := is_equal_approx(width_x, Tracer.THICKNESS) and is_equal_approx(width_y, Tracer.THICKNESS)
		var stage := "%s t=%.2f" % [label, travelled]
		if _baseline:
			_check(stage + " reproduces the old mesh/shot direction mismatch", not endpoints_match and alignment < 0.9999)
		else:
			_check(stage + " actual mesh endpoints stay on the original shot line", endpoints_match and alignment > 0.99999)
			_check(stage + " actual width stays 0.014m on both local axes", width_matches)
		_check(stage + " leaves the shot origin/direction/path unchanged", tracer._from == original_from
			and tracer._direction == original_direction and tracer._distance == original_distance)
		print("GEOMETRY %s: alignment=%.6f, width=(%.6f,%.6f), tail_error=%.6f, head_error=%.6f" % [stage,
			alignment, width_x, width_y, world_tail.distance_to(expected_tail), world_head.distance_to(expected_head)])


func _place_snapshot(tracer: Tracer) -> void:
	tracer._place()
	if not _baseline:
		return
	# Reproduce the old runtime formula only here. Do not touch the real shot
	# parameters, travelled distance, mesh, material, camera or backdrop.
	var head := minf(tracer._travelled, tracer._distance)
	var tail := maxf(tracer._travelled - Tracer.LENGTH, 0.0)
	var length := maxf(head - tail, 0.01)
	var up := Vector3.UP if absf(tracer._direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(tracer._direction, up).scaled(Vector3(1.0, 1.0, length))
	tracer.global_transform = Transform3D(basis, tracer._from + tracer._direction * (head + tail) * 0.5)


func _on_node_added(node: Node) -> void:
	if node is Tracer:
		_spawned.append(node as Tracer)


func _direction(yaw_degrees: float, pitch_degrees: float) -> Vector3:
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(pitch_degrees)
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func _add_floor() -> void:
	var floor_visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(120, 1, 120)
	floor_visual.mesh = box
	floor_visual.position = Vector3(60, -0.5, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("29343F")
	floor_visual.material_override = material
	_scene.add_child(floor_visual)


func _add_board(point: Vector3, direction: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	_scene.add_child(body)
	body.global_position = point
	body.look_at(point - direction)
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(20, 12, 0.15)
	collision.shape = box_shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_shape.size
	visual.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("182631")
	visual.material_override = material
	body.add_child(visual)


func _add_guide(tracer: Tracer) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.15, 0.75, 1.0)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	mesh.surface_add_vertex(tracer._from - tracer._direction * 0.3)
	mesh.surface_add_vertex(tracer._from + tracer._direction * 2.3)
	mesh.surface_end()
	visual.mesh = mesh
	_scene.add_child(visual)
	return visual


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var path := _out.path_join(file_name + ".jpg")
	var quality := 0.82
	var result := frame.save_jpg(path, quality)
	var byte_count := FileAccess.get_file_as_bytes(path).size() if result == OK else 0
	while result == OK and byte_count > MAX_JPEG_BYTES and quality > 0.5:
		quality -= 0.05
		result = frame.save_jpg(path, quality)
		byte_count = FileAccess.get_file_as_bytes(path).size() if result == OK else 0
	_check("saved " + file_name + " as JPEG under 150KB", result == OK and byte_count > 0 and byte_count <= MAX_JPEG_BYTES)
	print("SCREENSHOT %s.jpg (%s, %d bytes)" % [file_name, frame.get_size(), byte_count])


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s" % ["ok" if ok else "FAIL", label])
