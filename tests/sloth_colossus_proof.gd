extends Node3D
const BENCH := preload("res://tests/sloth_colossus_bench.tscn")
var bench: Node3D

func _ready() -> void:
	bench = BENCH.instantiate()
	add_child(bench)
	bench.player.set_physics_process(false)
	bench.player.health.invulnerable = true
	bench.player.hide()
	bench.colossus.set_physics_process(false)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(10,5,-18)
	camera.look_at(Vector3(0,2.6,-8))
	camera.fov = 55
	camera.current = true
	await get_tree().create_timer(1.0).timeout
	bench.colossus.start_attack(2)
	await get_tree().create_timer(0.5).timeout
	await capture("colossus-pendulum")
	bench.colossus.health.apply_damage(5000,Hitbox.BodyPart.BODY,bench.player)
	camera.position = Vector3(19,10,24)
	camera.look_at(Vector3(0,4,-5))
	await get_tree().create_timer(0.8).timeout
	await capture("rest-extinguished")
	bench.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit()

func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-139/"+name_value+".png")
	print("COLOSSUS NATIVE: "+name_value)
