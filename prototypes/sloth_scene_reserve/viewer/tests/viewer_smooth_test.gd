extends SceneTree
## Native checks for movement, render-frame camera following and teleport resets.
## Set process-local APPDATA to .runtime/AppData when running with local caches.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	var viewer := scene.get("viewer") as CharacterBody3D
	var camera := viewer.get("camera") as Camera3D
	_check(camera.top_level and camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "independent camera with automatic interpolation disabled")
	_check(bool(ProjectSettings.get_setting("physics/common/physics_interpolation")), "project interpolation enabled")
	for i in 60:
		await RenderingServer.frame_post_draw
	var spawn := viewer.global_position
	# A deliberately low test-only tick rate makes the difference between body
	# ticks and interpolated render frames clear, independent of monitor refresh.
	Engine.physics_ticks_per_second = 10
	viewer.call("snap_camera")
	_key(KEY_W, true)
	var body_changes := 0
	var camera_changes := 0
	var max_body_step := 0.0
	var max_camera_step := 0.0
	var old_body := viewer.global_position
	var old_camera := camera.global_position
	for i in 240:
		await RenderingServer.frame_post_draw
		var body_step := viewer.global_position.distance_to(old_body)
		var camera_step := camera.global_position.distance_to(old_camera)
		if body_step > 0.00001: body_changes += 1
		if camera_step > 0.00001: camera_changes += 1
		max_body_step = maxf(max_body_step, body_step)
		max_camera_step = maxf(max_camera_step, camera_step)
		old_body = viewer.global_position
		old_camera = camera.global_position
	_key(KEY_W, false)
	Engine.physics_ticks_per_second = 60
	_check(viewer.global_position.z < spawn.z - 0.1, "W advances along bridge")
	_check(camera_changes > body_changes + 10, "camera advances between physics ticks")
	_check(max_camera_step < max_body_step * 0.8, "render-frame camera steps smaller than physics body steps")
	print("SMOOTH_METRICS | frames=240 | physics_body_changes=", body_changes,
		" | camera_changes=", camera_changes, " | max_body_step=", max_body_step,
		" | max_camera_step=", max_camera_step)
	scene.call("set_view", 0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var yaw_before := viewer.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(70.0, -20.0)
	viewer.call("_unhandled_input", motion)
	await RenderingServer.frame_post_draw
	_check(absf(angle_difference(camera.global_rotation.y, yaw_before - 70.0 * 0.0022)) < 0.001, "mouse yaw reaches camera on next rendered frame")
	var yaw_before_arrows := viewer.rotation.y
	_key(KEY_RIGHT, true)
	for i in 3:
		await RenderingServer.frame_post_draw
	_key(KEY_RIGHT, false)
	_check(viewer.rotation.y < yaw_before_arrows, "direction-key look updates on render frames")
	viewer.call("_unhandled_input", _key_event(KEY_F, true))
	_check(bool(viewer.get("flying")), "F enters flight")
	var flight_y := viewer.position.y
	_key(KEY_E, true)
	for i in 5:
		await physics_frame
	_key(KEY_E, false)
	_check(viewer.position.y > flight_y + 0.1, "E ascends during flight")
	viewer.call("_unhandled_input", _key_event(KEY_F, true))
	_check(not bool(viewer.get("flying")), "F returns to walking")
	viewer.call("_unhandled_input", _key_event(KEY_ESCAPE, true))
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases pointer")
	viewer.call("set_input_enabled", false)
	for index in [3, 0, 2, 1, 0]:
		scene.call("set_view", index)
		_check(camera.global_position.distance_to(viewer.global_position + Vector3.UP * 1.7) < 0.0001, "preset camera snaps immediately")
		for i in 3:
			await RenderingServer.frame_post_draw
		_check(camera.global_position.distance_to(viewer.global_position + Vector3.UP * 1.7) < 0.0001, "preset camera remains at destination")
	viewer.call("teleport_to", Vector3(0.0, 0.1, 75.0), Vector3(0.0, 0.0, 65.0))
	_check(camera.global_position.distance_to(Vector3(0.0, 1.8, 75.0)) < 0.0001, "teleport synchronizes camera immediately")
	viewer.call("reset_view")
	_check(Vector2(viewer.position.x, viewer.position.z).distance_to(Vector2(spawn.x, spawn.z)) < 0.01, "reset returns to entry")
	_check(camera.global_position.distance_to(viewer.global_position + Vector3.UP * 1.7) < 0.0001, "reset has no camera travel from previous position")
	if failures.is_empty():
		print("VIEWER_SMOOTH_TEST_PASS | interpolation, input, flight, disabled input, presets and teleports")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _key(code: int, pressed: bool) -> void:
	Input.parse_input_event(_key_event(code, pressed))


func _key_event(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
