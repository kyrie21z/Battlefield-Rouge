extends Node
## Native-window captures only. MetaProgression isolates all tests at autoload init.
var diary: LoreDiary
var folder := "res://docs/proof/issue-175/"

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not MetaProgression.isolated_profile:
		push_error("Native display and isolated test profile required")
		get_tree().quit(1)
		return
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(2))
	diary = preload("res://ui/codex/lore_diary.tscn").instantiate()
	add_child(diary)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.content_scale_size = dimensions
		DisplayServer.window_set_size(dimensions)
		await frames()
		var suffix := "-%dx%d" % [dimensions.x, dimensions.y]
		diary.setup({})
		diary._change_section(false)
		diary._select(0)
		await capture("01-locked" + suffix)
		diary.setup({"visited_realms": [0], "defeated_realms": [], "reconciled": false})
		await capture("02-visited-diary" + suffix)
		diary._change_section(true)
		await capture("03-crown-only" + suffix)
		diary.setup({"visited_realms": [0, 1, 2, 3], "defeated_realms": [0, 1, 2, 3], "reconciled": false})
		diary._select(2)
		await capture("04-dual-dossier" + suffix)
		diary._reader.scroll_vertical = int(diary._reader.get_v_scroll_bar().max_value)
		await capture("04b-dual-dossier-end" + suffix)
		diary.setup({"visited_realms": [0, 1, 2, 3], "defeated_realms": [0, 1, 2, 3], "reconciled": true})
		diary._change_section(false)
		diary._select(4)
		diary._reader.grab_focus()
		await capture("05-reconciled" + suffix)
		diary._reader.scroll_vertical = int(diary._reader.get_v_scroll_bar().max_value)
		await capture("06-final-line" + suffix)
	diary.free()
	await frames()
	get_tree().quit()

func frames() -> void:
	for index in 6:
		await get_tree().process_frame

func capture(file_name: String) -> void:
	if not file_name.begins_with("05-") and not file_name.begins_with("06-"):
		diary._buttons[diary._selected].grab_focus()
	await frames()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(folder + file_name + ".png")
	print("LORE NATIVE: %s %s code=%d" % [file_name, image.get_size(), result])
	if result != OK:
		get_tree().quit(1)
