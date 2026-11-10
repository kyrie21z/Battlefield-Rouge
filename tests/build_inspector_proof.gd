extends Node
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name()=="headless":
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280,720))
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	for path in ["sloth/sloth_gun_pulse","fear/flash_backstab","wrath/wrath_dash_ram","sorrow/sorrow_buffer","sloth/sloth_inertia","fear/sixth_sense"]:
		stage.player.boons.equip(load("res://buffs/resources/%s.tres" % path))
	stage.player.fragments.acquire(0)
	stage.player.fragments.acquire(1)
	stage.hud.inspector.try_open()
	for frame in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/proof/issue-173/build-inspector.png"
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE "+path)
	stage.hud.inspector.close(true)
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit()
