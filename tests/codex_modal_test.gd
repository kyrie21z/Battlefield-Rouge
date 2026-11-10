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
	var card := load("res://buffs/resources/sloth/sloth_gun_pulse.tres") as BoonData
	player.boons.equip(card)
	Events.boon_chosen.emit(card)
	check("real boon selection signal persists discovery",MetaProgression.discovered_boons.has(card.id))
	check("production host opens",panel.try_open())
	panel.show_page(1)
	await get_tree().process_frame
	check("codex is a live visible page",panel._codex != null and panel._codex.is_visible_in_tree())
	check("codex receives current manager and persisted discovery",panel._codex.get("_manager")==player.boons and panel._codex.get("_discovered").has(card.id))
	check("page switch keeps world paused",get_tree().paused and not panel._build_scroll.visible)
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_LEFT_SHOULDER
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	check("actual shoulder event wraps codex pages",panel._codex.get("_page")==4)
	panel.show_page(0)
	check("return to matrix preserves equipment",panel._snapshot.slots[0]==card.id and panel._build_scroll.visible)
	panel.close(true)
	check("close restores game",not get_tree().paused)
	panel.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("CODEX MODAL: %d checks, %d failed" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
