extends "res://tests/flawless_bench.gd"
var failures := 0
var perf_only := OS.get_cmdline_user_args().has("--climax-perf")
var review_camera: Camera3D
func _ready() -> void:
	GameSettings.settings_path = "user://epic172_proof_settings.cfg"
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),perf_only)
	build_arena()
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0,0,7)
	add_child(player)
	player.set_physics_process(false)
	var crown := player.get_node("CrownVoiceSystem") as CrownVoiceSystem
	crown.set_fracture_level(0)
	await frames(12)
	await profile("crown_level0")
	await capture("01-crown-level0.png")
	crown.set_fracture_level(4)
	await frames(6)
	await profile("crown_level4")
	await capture("02-crown-level4.png")
	crown.set_cinematic_hidden(true)
	player.position = Vector3.ZERO
	var body := player.get_node("ShadowBody") as ProtagonistBody
	for entry:Dictionary in body.fracture.source_meshes.values():
		(entry.node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	review_camera = Camera3D.new()
	add_child(review_camera)
	review_camera.position = Vector3(1.9,1.6,2.9)
	review_camera.look_at(Vector3(0,0.95,0))
	review_camera.fov = 42
	review_camera.current = true
	await frames(10)
	await profile("original_body")
	BodyReassembly.apply_kintsugi(player)
	await frames(10)
	await profile("kintsugi_body")
	await profile("kintsugi_body_repeat")
	await capture("03-kintsugi-body.png")
	review_camera.position = Vector3(0.7,1.35,1.2)
	review_camera.look_at(Vector3(0,1.10,0))
	await frames(30)
	await capture("04-kintsugi-seams.png")
	player.position = Vector3(0,0,12)
	player.hide()
	encounter = DoppelgangerSpawn.new()
	encounter.setup(player)
	add_child(encounter)
	review_camera.position = Vector3(3.5,2.5,7)
	review_camera.look_at(Vector3(0,1.4,0))
	review_camera.fov = 48
	for i in 900:
		if encounter.phase == DoppelgangerSpawn.Phase.PRINT: break
		await get_tree().physics_frame
	await frames(65)
	await capture("05-projected-crown-glare.png")
	for child in get_children(): child.queue_free()
	await get_tree().process_frame
	GameSettings.settings_path = GameSettings.DEFAULT_PATH
	OS.delay_msec(250)
	print("CLIMAX SHADERS %s: failures=%d" % ["PERF (no screenshots)" if perf_only else "NATIVE (five captures)",failures])
	get_tree().quit(0 if failures==0 else 1)
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func capture(filename: String) -> void:
	if perf_only: return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/proof/issue-172/"+filename))
	if error != OK: failures += 1
	print("CAPTURE %s error=%d" % [filename,error])

func profile(label: String) -> void:
	if not perf_only: return
	# Give asynchronous pipelines time to settle before measuring cached frames.
	await get_tree().create_timer(1.0).timeout
	for i in 32: await RenderingServer.frame_post_draw
	var values: Array[float] = []
	for i in 60:
		await RenderingServer.frame_post_draw
		values.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	values.sort()
	var total := 0.0
	for value in values: total += value
	print("GPU SAMPLE %s frames=60 mean_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [label,total/60,values[56],values[59]])
