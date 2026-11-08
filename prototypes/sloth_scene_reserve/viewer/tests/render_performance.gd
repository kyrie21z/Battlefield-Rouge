extends SceneTree
## Native rendering benchmark. Scene assets and game code are never modified.
## For a workspace-local cache, set APPDATA in the launching PowerShell process
## to this preview's .runtime/AppData folder. No system setting is changed.

const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 180


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proof"))
	print("INITIAL_VIEWPORT | root_size=", root.size, " | window_size=", DisplayServer.window_get_size(),
		" | render_texture_size=", root.get_texture().get_size())
	root.size = Vector2i(1440, 810)
	var packed := load("res://main.tscn") as PackedScene
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	var viewer := scene.get("viewer") as CharacterBody3D
	viewer.call("set_input_enabled", false)
	var hud := scene.get("hud") as CanvasLayer
	hud.call("set_proof_mode", true)
	var viewport_rid := root.get_viewport_rid()
	var after_run := "--after" in OS.get_cmdline_user_args()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	print("SCENE_LOADED | scene and shaders loaded; beginning native warmup | ", RenderingServer.get_current_rendering_method())
	for index in [0, 3]:
		scene.call("set_view", index)
		for i in WARMUP_FRAMES:
			await RenderingServer.frame_post_draw
		print("VIEWPORT_METADATA | view=", index + 1, " | root_size=", root.size,
			" | window_size=", DisplayServer.window_get_size(), " | render_texture_size=", root.get_texture().get_size(),
			" | objects=", RenderingServer.viewport_get_render_info(viewport_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
			" | draw_calls=", RenderingServer.viewport_get_render_info(viewport_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			" | primitives=", RenderingServer.viewport_get_render_info(viewport_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		if index == 0:
			var picture := root.get_texture().get_image()
			var path := ProjectSettings.globalize_path("res://proof/perf-after-view0.png" if after_run else "res://proof/perf-view0.png")
			print("PERF_SCREENSHOT | ", picture.get_size(), " | saved=", picture.save_png(path), " | ", path)
		var gpu_samples: Array[float] = []
		var cpu_samples: Array[float] = []
		var wall_samples: Array[float] = []
		var last_tick := Time.get_ticks_usec()
		for i in SAMPLE_FRAMES:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			wall_samples.append(float(now - last_tick) / 1000.0)
			last_tick = now
			var gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
			if gpu > 0.0:
				gpu_samples.append(gpu)
			cpu_samples.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu())
		print("PERFORMANCE | view=", index + 1, " | samples=", SAMPLE_FRAMES,
			" | GPU_ms=", _stats(gpu_samples), " | CPU_render_ms=", _stats(cpu_samples),
			" | wall_frame_ms=", _stats(wall_samples))
	if after_run:
		await _measure_movement(scene, viewer, viewport_rid)
	print("PERFORMANCE_COMPLETE | native Forward+ | warmed ", WARMUP_FRAMES, " frames/view")
	quit(0)


func _measure_movement(scene: Node3D, viewer: CharacterBody3D, viewport_rid: RID) -> void:
	scene.call("set_view", 0)
	viewer.position = Vector3(0.0, 0.1, 94.0)
	viewer.rotation = Vector3.ZERO
	var head := viewer.get("head") as Node3D
	head.rotation.x = deg_to_rad(-18.0)
	viewer.call("snap_camera")
	for i in 60:
		await RenderingServer.frame_post_draw
	var pilot := BenchmarkWalk.new()
	pilot.target = viewer
	scene.add_child(pilot)
	var gpu_samples: Array[float] = []
	var wall_samples: Array[float] = []
	var begin := Time.get_ticks_usec()
	var last_tick := begin
	var elapsed := 0.0
	var next_sample := 0.0
	var duration := 54.0 / 8.0
	# Follow an 8 m/s path, sampling frame costs across the full walk. Waiting
	# between selected samples does not contaminate the per-frame wall interval.
	while elapsed < duration or wall_samples.size() < SAMPLE_FRAMES:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - last_tick) / 1000.0
		last_tick = now
		elapsed = float(now - begin) / 1000000.0
		if elapsed >= next_sample and wall_samples.size() < SAMPLE_FRAMES:
			wall_samples.append(frame_ms)
			var gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
			if gpu > 0.0:
				gpu_samples.append(gpu)
			next_sample += duration / float(SAMPLE_FRAMES)
	print("PERFORMANCE_MOVING | path=z94_to_z40 | speed=8m/s | samples=", wall_samples.size(),
		" | GPU_ms=", _stats(gpu_samples), " | wall_frame_ms=", _stats(wall_samples))
	pilot.queue_free()
	for i in 2:
		await physics_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://proof/ground.png")
	print("GROUND_SCREENSHOT | ", image.get_size(), " | saved=", image.save_png(path), " | ", path)


func _stats(samples: Array[float]) -> String:
	if samples.is_empty():
		return "unavailable"
	samples.sort()
	var median := samples[samples.size() / 2]
	var p95 := samples[mini(int(ceil(samples.size() * 0.95)) - 1, samples.size() - 1)]
	return "median:%.3f,p95:%.3f,n:%d" % [median, p95, samples.size()]


class BenchmarkWalk extends Node:
	var target: CharacterBody3D

	func _physics_process(delta: float) -> void:
		if is_instance_valid(target):
			target.position.z = maxf(40.0, target.position.z - delta * 8.0)
