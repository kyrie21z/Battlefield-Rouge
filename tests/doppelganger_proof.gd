extends "res://tests/flawless_bench.gd"
var failures := 0
func _ready() -> void:
	build_arena()
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0,0,12)
	add_child(player)
	player.hide()
	player.fragments.configure_deprivation([0,1,2,3])
	for realm in 4:
		player.fragments.acquire(realm)
	encounter = DoppelgangerSpawn.new()
	encounter.setup(player)
	add_child(encounter)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(3.5,2.5,7)
	camera.look_at(Vector3(0,1.4,0))
	camera.fov = 48
	camera.current = true
	await until_phase(DoppelgangerSpawn.Phase.PRINT)
	await frames(70)
	await capture("01-print.png")
	await until_phase(DoppelgangerSpawn.Phase.COMBAT)
	encounter.boss.phase = FlawlessDoppelganger.Phase.GUARD
	encounter.boss.phase_left = 100
	await frames(4)
	await capture("02-white-double.png")
	encounter.boss.phase = FlawlessDoppelganger.Phase.RECOVER
	encounter.boss.health.apply_damage(99999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	await frames(40)
	await capture("03-annihilation.png")
	await until_phase(DoppelgangerSpawn.Phase.COMPLETE)
	await frames(15)
	await capture("04-crown-aftermath.png")
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	print("DOPPELGANGER NATIVE: 4 captures, failures=%d" % failures)
	get_tree().quit(0 if failures==0 else 1)
func until_phase(value:int) -> void:
	for i in 900:
		if encounter.phase==value:
			return
		await get_tree().physics_frame
	failures+=1
func frames(count:int) -> void:
	for i in count:
		await get_tree().physics_frame
func capture(filename:String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://docs/proof/issue-150/"+filename)
	var error := get_viewport().get_texture().get_image().save_png(output)
	failures+=0 if error==OK else 1
	print("CAPTURE %s phase=%d error=%d" % [filename,encounter.phase,error])
