extends Node
var checks := 0
var failures := 0
func check(title: String,value: bool) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+title)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.fixture = null
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	var panel := preload("res://ui/codex/build_inspector.tscn").instantiate() as BuildInspector
	panel.player = player
	add_child(panel)
	MetaProgression.record_archive(0)
	panel.try_open()
	panel.show_page(2)
	await get_tree().process_frame
	check("production diary page is visible",is_instance_valid(panel.get("_diary")) and panel.get("_diary").is_visible_in_tree())
	var diary: Control = panel.get("_diary")
	check("entry snapshot reveals only visited diary",diary.get("_pages")[0].unlocked and not diary.get("_pages")[1].unlocked and not diary.get("_pages")[4].unlocked)
	MetaProgression.record_archive(-1,false,true)
	await get_tree().process_frame
	check("progress updates reproject diary while open",diary.get("_pages")[4].unlocked)
	check("diary does not release modal pause",get_tree().paused)
	panel.close(true)
	var count_before := RunDirector.run_count
	var wallet_before := MetaProgression.will_shards
	var ending := preload("res://ui/ending_menu.tscn").instantiate()
	add_child(ending)
	ending.call("_open_archive")
	var reader: Control = ending.get("_archive_reader")
	ending.call("_open_archive")
	check("ending menu opens a single independent reader",reader==ending.get("_archive_reader"))
	check("reader hides menu actions from controller focus",not ending.get("_menu_box").is_visible_in_tree())
	check("final diary accessible without starting new challenge",reader.get("diary").get("_pages")[4].unlocked and RunDirector.run_count==count_before and MetaProgression.will_shards==wallet_before)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	check("Escape returns to safe ending menu",ending.get("_archive_reader")==null and ending.get("_menu_box").is_visible_in_tree() and not get_tree().paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	ending.queue_free()
	panel.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("LORE MODAL: %d checks, %d failed" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
