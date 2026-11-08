extends SceneTree
## Native, static-view performance sampling for the expanded reserve rooms.
## Launch with process-local APPDATA=.runtime/AppData and an explicit local log.
## No CUA, game-state changes, combat simulation, or fixed battle-FPS promise.
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 180
const TARGET_SIZE := Vector2i(1440,810)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proof"))
	Engine.max_fps = 0
	DisplayServer.window_set_title("场景性能检查，自动退出")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(TARGET_SIZE)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = TARGET_SIZE
	var renderer := RenderingServer.get_current_rendering_method()
	print("ROOMS_PERFORMANCE_BEGIN | renderer=",renderer," | target=",TARGET_SIZE,
		" | vsync=",DisplayServer.window_get_vsync_mode()," | max_fps=",Engine.max_fps,
		" | warmup_frames=",WARMUP_FRAMES," | sample_frames=",SAMPLE_FRAMES)
	if renderer != "forward_plus":
		push_error("This native room benchmark requires Forward+.")
		quit(1)
		return
	var packed := load("res://rooms_preview.tscn") as PackedScene
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	scene.viewer.set_input_enabled(false)
	scene.hud.set_proof_mode(true)
	var viewport_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
	var failures := 0
	for room_index in [0,1]:
		scene.set_room(room_index)
		for view_index in [0,3]:
			scene.set_view(view_index)
			for frame in WARMUP_FRAMES:
				await RenderingServer.frame_post_draw
			print("ROOMS_VIEW_METADATA | room=",room_index+1," | view=",view_index+1,
				" | viewport=",root.size," | window=",DisplayServer.window_get_size(),
				" | texture_size=",root.get_texture().get_size(),
				" | actual_image_size=",root.get_texture().get_image().get_size(),
				" | objects=",RenderingServer.viewport_get_render_info(viewport_rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
				" | draw_calls=",RenderingServer.viewport_get_render_info(viewport_rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
				" | primitives=",RenderingServer.viewport_get_render_info(viewport_rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
			var gpu_samples: Array[float] = []
			var cpu_samples: Array[float] = []
			var wall_samples: Array[float] = []
			var last_tick := Time.get_ticks_usec()
			for frame in SAMPLE_FRAMES:
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				wall_samples.append(float(now-last_tick)/1000.0)
				last_tick = now
				var gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
				if gpu>0.0: gpu_samples.append(gpu)
				cpu_samples.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)+RenderingServer.get_frame_setup_time_cpu())
			print("ROOMS_PERFORMANCE | room=",room_index+1," | view=",view_index+1,
				" | GPU_ms=",_stats(gpu_samples)," | CPU_render_ms=",_stats(cpu_samples),
				" | wall_frame_ms=",_stats(wall_samples))
			if gpu_samples.size()!=SAMPLE_FRAMES or root.size!=TARGET_SIZE:
				failures += 1
	RenderingServer.viewport_set_measure_render_time(viewport_rid,false)
	scene.queue_free()
	await process_frame
	print("ROOMS_PERFORMANCE_COMPLETE | 4 static room views | failures=",failures,
		" | local measurements only; no combat or cross-machine FPS guarantee")
	quit(0 if failures==0 else 1)

func _stats(samples: Array[float]) -> String:
	if samples.is_empty(): return "unavailable"
	samples.sort()
	var median := samples[samples.size()/2]
	var p95 := samples[mini(int(ceil(samples.size()*0.95))-1,samples.size()-1)]
	return "median:%.3f,p95:%.3f,n:%d" % [median,p95,samples.size()]
