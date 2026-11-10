extends Node3D
const BENCH := preload("res://tests/sloth_realm_bench.tscn")
var bench: Node3D

func _ready() -> void:
	bench = BENCH.instantiate()
	add_child(bench)
	bench.player.set_physics_process(false)
	bench.player.hide()
	bench.player.health.invulnerable = true
	for i in 3:
		bench.enemies[i].set_physics_process(false)
		bench.enemies[i].position = Vector3((i-1)*3.5,0,-2)
		bench.enemies[i].rotation.y = PI
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(19,12,23)
	camera.look_at(Vector3(0,3,-5))
	camera.fov = 62
	camera.current = true
	await get_tree().create_timer(1.0).timeout
	await capture("realm-overview")
	camera.position = Vector3(7,3.5,8)
	camera.look_at(Vector3(0,1.2,-2))
	camera.fov = 47
	await get_tree().create_timer(0.6).timeout
	await capture("amber-variants")
	bench.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit()

func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-138/"+name_value+".png")
	print("SLOTH NATIVE: "+name_value)
