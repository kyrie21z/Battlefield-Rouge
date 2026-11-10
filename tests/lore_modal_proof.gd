extends Node
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name()=="headless" or not MetaProgression.isolated_profile:
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280,720))
	MetaProgression.record_archive(0)
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	stage.hud.inspector.try_open()
	stage.hud.inspector.show_page(2)
	await capture("production-diary")
	stage.hud.inspector.close(true)
	stage.queue_free()
	await get_tree().process_frame
	for realm in 4:
		MetaProgression.record_archive(realm,true)
	MetaProgression.record_archive(-1,false,true)
	var ending := preload("res://ui/ending_menu.tscn").instantiate()
	add_child(ending)
	ending.call("_open_archive")
	var diary: Control = ending.get("_archive_reader").get("diary")
	diary.set("_selected",4)
	diary.call("refresh")
	await capture("ending-diary")
	ending.call("_close_archive")
	ending.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func capture(stem: String) -> void:
	for frame in 25: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(ProjectSettings.globalize_path("res://docs/proof/issue-175/%s.png" % stem))
	print("LORE PRODUCTION PNG %s: %s, status %d" % [stem,image.get_size(),result])
	if result != OK:
		get_tree().quit(1)
