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
	get_tree().create_timer(90,true).timeout.connect(func():get_tree().quit(2))
	RunState.fixture = null
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.position.y = 2
	var inspector := preload("res://ui/codex/build_inspector.tscn").instantiate() as BuildInspector
	inspector.player = player
	add_child(inspector)
	check("Tab and View registered",InputMap.action_get_events("inspect_build").size()==2)
	get_tree().paused = true
	check("does not steal existing pause",not inspector.try_open())
	get_tree().paused = false
	Input.action_press("fire")
	Input.action_press("move_forward")
	check("opens and owns pause",inspector.try_open() and get_tree().paused)
	check("clears held gameplay actions",not Input.is_action_pressed("fire") and not Input.is_action_pressed("move_forward"))
	check("empty slots report truth",inspector.snapshot().slots == ["","","",""])
	var card := load("res://buffs/resources/sloth/sloth_blade_cleave.tres") as BoonData
	player.boons.equip(card)
	player.fragments.acquire(1)
	player.stats.set_modifier(&"test",{Stats.MAX_HEALTH:{"add":30.0}})
	await get_tree().process_frame
	check("live equipment updates while paused",inspector._snapshot.slots[1]==card.id)
	check("live fragment and stats updates",inspector._snapshot.shards.has(1) and inspector._snapshot.stats.max_health==130)
	var position_before := player.position
	await get_tree().create_timer(0.08,true).timeout
	check("simulation remains frozen",player.position==position_before)
	inspector.close()
	check("fade retains pause",get_tree().paused)
	await get_tree().create_timer(0.2,true).timeout
	check("close releases own pause",not inspector.opened and not get_tree().paused)
	inspector.can_open = func():return false
	check("cinematic gate respected",not inspector.try_open())
	inspector.can_open = Callable()
	check("reopen",inspector.try_open())
	var menu := PauseMenu.new()
	add_child(menu)
	PauseMenu.allow_headless = true
	menu.setup(GameSettings.new(),player,null)
	check("pause menu cannot steal inspection pause",not menu.try_open())
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().create_timer(0.2,true).timeout
	check("Escape releases inspector without opening pause menu",not inspector.opened and not menu.is_open() and not get_tree().paused)
	menu.queue_free()
	PauseMenu.allow_headless = false
	inspector.try_open()
	inspector.queue_free()
	await get_tree().process_frame
	check("scene exit releases pause",not get_tree().paused)
	player.queue_free()
	await get_tree().process_frame
	var departing := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(departing)
	var last_panel := BuildInspector.new()
	last_panel.player = departing
	add_child(last_panel)
	last_panel.try_open()
	departing.free()
	last_panel.free()
	check("player-first teardown cannot leave tree paused",not get_tree().paused)
	print("BUILD INSPECTOR: %d checks, %d failed" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
