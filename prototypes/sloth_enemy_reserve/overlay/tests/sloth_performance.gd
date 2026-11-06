extends Node
## Native Windows reserve benchmark. Wall time is measured only in this tool;
## gameplay keeps its seeded, simulation-driven clock. No fixed-FPS override.
const SIZE := Vector2i(1440, 810)
var scene: Node3D
var player: Player
var actors: Array[SlothEnemy] = []
var failures := 0
var results: Array[Dictionary] = []
var output := ""
var image_path := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--shot="): image_path = arg.trim_prefix("--shot=")
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(SIZE)
	get_viewport().size = SIZE
	var metadata := {"os":OS.get_name(), "cpu":OS.get_processor_name(),
		"gpu":RenderingServer.get_video_adapter_name(), "engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_current_rendering_method(), "resolution":[SIZE.x,SIZE.y],
		"vsync":DisplayServer.window_get_vsync_mode(), "max_fps":Engine.max_fps}
	print("SLOTH_PERFORMANCE_METADATA ", JSON.stringify(metadata))
	RunState.zone_index = 1
	RunState.run_seed = 24601
	scene = load("res://maps/zone_2.tscn").instantiate() as Node3D
	add_child(scene)
	player = scene.get_node("Player") as Player
	# Shield updates its invulnerability flag. Use a large health pool so combat
	# and HUD effects keep running instead of death pausing the benchmark.
	player.health.max_health = 100000.0
	player.health.health = 100000.0
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0,19,26)
	camera.look_at(Vector3(0,1,0))
	camera.fov = 65
	camera.make_current()
	for child in scene.get_children():
		if child is SlothEnemy: actors.append(child)
	_check("real second zone contains six guards", actors.size() == 6)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	await get_tree().create_timer(3.0).timeout
	_sync_cast()
	await _sample("six_real_guards",5.0,16.67)
	var spawn_start := Time.get_ticks_usec()
	for i in 6:
		var actor := load("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
		actor.kind = i % 3
		scene.add_child(actor)
		actor.position = Vector3(-6.0+float(i%3)*6.0,0,7.0-float(i/3)*6.0)
		actor.setup(player,[])
		actors.append(actor)
	results.append({"phase":"six_additional_spawns","cpu_ms":float(Time.get_ticks_usec()-spawn_start)/1000.0})
	await get_tree().create_timer(2.5).timeout
	_sync_cast()
	await _sample("twelve_active_actors",5.0,16.67)
	if not image_path.is_empty():
		get_viewport().get_texture().get_image().save_png(image_path)
	var start := Time.get_ticks_usec()
	for actor in actors:
		actor.health.apply_damage(9999,Hitbox.BodyPart.BODY,player)
	var kill_ms := float(Time.get_ticks_usec()-start)/1000.0
	var bursts := _bursts()
	_check("twelve deaths retain all 672 authored shards", bursts.size()==12
		and bursts.all(func(b:SlothShatter)->bool:return b.fragments.size()==56))
	results.append({"phase":"synchronous_death_build", "actors":12, "shards":672, "cpu_ms":kill_ms})
	print("SLOTH_PERFORMANCE_DEATH_BUILD ",kill_ms,"ms")
	_check("twelve kills including guard-triggered reinforcement spawn stay below 100ms",kill_ms<100.0)
	await _sample("twelve_simultaneous_shatters",2.0,33.33)
	await get_tree().create_timer(0.1).timeout
	_check("all bursts and their fragments are reclaimed", _bursts().is_empty())
	_check("all pending skills are cancelled", actors.all(func(a:SlothEnemy)->bool:return not is_instance_valid(a.active_attack)))
	_check("stasis sources release after caster deaths", player._stasis_sources.is_empty())
	_check("native viewport really renders requested size", get_viewport().get_texture().get_image().get_size()==SIZE)
	var report := {"metadata":metadata,"results":results,"failures":failures,"finished":true}
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file == null:
			failures += 1
		else:
			file.store_string(JSON.stringify(report,"\t")+"\n")
	scene.queue_free()
	await get_tree().process_frame
	print("SLOTH_PERFORMANCE_COMPLETE failures=",failures)
	get_tree().quit(0 if failures==0 else 1)


func _sync_cast() -> void:
	# Force a shared peak while leaving real AI, navigation and physics running.
	for actor in actors:
		actor._cancel_attack()
		actor.cast_attack()


func _sample(label: String, seconds: float, budget: float) -> void:
	var wall: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var calls: Array[float] = []
	var physics: Array[float] = []
	var viewport := get_viewport().get_viewport_rid()
	var begin := Time.get_ticks_usec()
	var previous := begin
	while float(Time.get_ticks_usec()-begin)/1000000.0 < seconds:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		wall.append(float(now-previous)/1000.0)
		previous = now
		var measured_gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		if measured_gpu>0.0: gpu.append(measured_gpu)
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport)+RenderingServer.get_frame_setup_time_cpu())
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		calls.append(RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	var result := {"phase":label,"wall_ms":_stats(wall),"gpu_ms":_stats(gpu),
		"cpu_render_ms":_stats(cpu),"physics_ms":_stats(physics),"draw_calls":_stats(calls),"wall_p95_budget_ms":budget}
	results.append(result)
	print("SLOTH_PERFORMANCE_PHASE ",JSON.stringify(result))
	_check(label+" keeps combat alive and unpaused", not player.health.is_dead() and not get_tree().paused)
	_check(label+" completes real samples within its p95 budget", wall.size()>=60 and float(result.wall_ms.p95)<=budget)


func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"n":0}
	values.sort()
	return {"n":values.size(),"median":values[values.size()/2],
		"p95":values[mini(int(ceil(values.size()*0.95))-1,values.size()-1)],"max":values[-1]}


func _bursts() -> Array[Node]:
	return scene.find_children("*","SlothShatter",true,false)


func _check(label: String, ok: bool) -> void:
	if not ok: failures += 1
	print("  [", "ok" if ok else "FAIL", "] ",label)
