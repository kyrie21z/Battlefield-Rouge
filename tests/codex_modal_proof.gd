extends Node
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name()=="headless":
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280,720))
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	for path in ["sloth/sloth_gun_pulse","wrath/wrath_blade_sweep"]:
		var card := load("res://buffs/resources/%s.tres" % path) as BoonData
		stage.player.boons.equip(card)
		Events.boon_chosen.emit(card)
	var panel := stage.hud.inspector
	panel.try_open()
	panel.show_page(1)
	for frame in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/proof/issue-174/production-modal.png"))
	panel.close(true)
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit()
