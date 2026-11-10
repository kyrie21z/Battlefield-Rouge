extends "res://tests/flawless_bench.gd"
var failures := 0

func _ready() -> void:
	GameSettings.settings_path = "user://climax_hud_proof_defaults.cfg"
	super._ready()
	for index in 1200:
		if encounter.phase == DoppelgangerSpawn.Phase.COMBAT:
			break
		await get_tree().physics_frame
	encounter.boss.phase = FlawlessDoppelganger.Phase.GUARD
	encounter.boss.phase_left = 100
	player.position = Vector3(0,0,5)
	player.aim_at(Vector3(0,1.4,0))
	for index in 4:
		await get_tree().physics_frame
	await capture("05-combat-hud.png")
	encounter.hud.pause_menu.try_open()
	await capture("06-pause.png")
	encounter.hud.pause_menu.close()
	encounter.hud.set_combat_visible(false)
	encounter.label.hide()
	encounter.boss.phase = FlawlessDoppelganger.Phase.RECOVER
	encounter.boss.phase_left = 100
	encounter.boss.visual.set_guard(false)
	player.hide()
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(1.0,2.5,2.6)
	camera.look_at(encounter.boss.visual.crown_anchor.global_position-Vector3.UP*0.08)
	camera.fov = 32
	camera.current = true
	await capture("07-head-fit.png")
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	GameSettings.settings_path = GameSettings.DEFAULT_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://climax_hud_proof_defaults.cfg"))
	print("CLIMAX HUD NATIVE: 3 captures, failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func capture(filename:String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/proof/issue-150/"+filename))
	failures += 0 if error == OK else 1
	print("CAPTURE %s error=%d" % [filename,error])
