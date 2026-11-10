extends "res://tests/combat_bench.gd"
## Native-render proof frames, never used as a substitute for a human feel review.
func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	set_physics_process(false)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	for level in 5:
		Events.sin_defeated.emit(level)
		await _shot("fracture_%d" % level)
	player.weapon.aiming = true
	for frame in 30:
		player.weapon._process(1.0 / 60.0)
		await get_tree().process_frame
	await _shot("ads")
	player.weapon.aiming = false
	player.weapon.ammo = 0
	player.weapon.try_reload()
	player.weapon._process(0.40)
	await _shot("bloom")
	player.weapon._process(0.45)
	player.melee.swing_now()
	player.melee._process(0.13)
	await _shot("blade")
	get_tree().quit()

func _shot(title: String) -> void:
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://docs/proof/epic1"
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder + "/" + title + ".png")
