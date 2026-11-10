extends Node3D
var elapsed := 0.0
var captured := false
var frame := 0
var previous_usec := 0
var samples: Array[float] = []
var warm_samples: Array[float] = []
var capture_requested := false
var spawn_ms := 0.0
var first_burst_frame_ms := 0.0
func _ready() -> void:
	capture_requested = "--capture" in OS.get_cmdline_user_args()
	CrystalBurst.prepare(self)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("19222c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	environment.environment.glow_enabled = true
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-20,0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(0,6,13)
	add_child(camera)
	camera.look_at(Vector3(0,1,0))
	camera.current = true
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24,15)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	for index in 4:
		var label := Label3D.new()
		label.text = ["SLOTH","FEAR","WRATH","SORROW"][index]
		label.position = Vector3(-6+index*4,0.3,2.2)
		label.font_size = 72
		label.modulate = CrystalBurst.COLORS[index]
		add_child(label)
func _process(delta: float) -> void:
	elapsed += delta
	frame += 1
	var now := Time.get_ticks_usec()
	if frame >= 60 and frame <= 180 and previous_usec>0:
		samples.append(float(now-previous_usec)/1000.0)
	if frame>1 and frame<60:
		warm_samples.append(float(now-previous_usec)/1000.0)
	previous_usec = now
	if frame == 61:
		first_burst_frame_ms = samples.back()
	if frame == 60:
		var spawn_start := Time.get_ticks_usec()
		for index in 12:
			CrystalBurst.spawn(self,Vector3(-6+(index%4)*4,1.2,-float(index/4)*2),index%4,&"death",Vector3.DOWN)
		spawn_ms = float(Time.get_ticks_usec()-spawn_start)/1000.0
	if frame == 75 and capture_requested and not captured:
		captured = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-168/four-crystal-bursts.png")
	if frame == 181:
		var raw_samples := samples.duplicate()
		samples.sort()
		warm_samples.sort()
		print("LOAD_WARMUP: %d frames, p95=%.3f ms max=%.3f ms"%[warm_samples.size(),warm_samples[int(warm_samples.size()*0.95)],warm_samples.back()])
		print("CAPTURE_MODE=%s SPAWN_CPU=%.3f ms FIRST_BURST_FRAME=%.3f ms"%[capture_requested,spawn_ms,first_burst_frame_ms])
		print("GPU BURST STORM: 12 emitters / 528 GPU shards; %d frames, p50=%.3f ms p95=%.3f ms max=%.3f ms"%[samples.size(),samples[samples.size()/2],samples[int(samples.size()*0.95)],samples.back()])
		if not capture_requested:
			var file := FileAccess.open("res://docs/proof/issue-168/performance.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"capture_during_sampling":false,"emitters":12,"gpu_shards":528,"frame_ms":raw_samples,"spawn_cpu_ms":spawn_ms,"first_burst_frame_ms":first_burst_frame_ms,"loading_warmup_max_ms":warm_samples.back()},"\t"))
		get_tree().quit()
