extends Node
var checks := 0
var failed := 0

func check(label: String, value: bool) -> void:
	checks += 1
	if not value:
		failed += 1
	print("%s %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var hud := Node.new()
	add_child(hud)
	BoonHitstop.attach(hud, player)
	RunState.clear_fixture()
	for event in BoonHitstop.IMPACTS:
		HitStop.last_requested = 0.0
		player.boons.event_dispatched.emit(event, {})
		check("semantic impact requests feedback: %s" % event, is_equal_approx(HitStop.last_requested, 0.04))
	HitStop.last_requested = 0.0
	player.boons.event_dispatched.emit(&"gun_fired", {})
	check("ordinary actions do not add a stop", HitStop.last_requested == 0.0)
	get_tree().paused = true
	player.boons.event_dispatched.emit(&"wall_slam", {})
	check("pause rejects feedback", HitStop.last_requested == 0.0)
	get_tree().paused = false
	RunState.fixture = RunFixture.new()
	player.boons.event_dispatched.emit(&"wall_slam", {})
	check("fixtures never request a stop", HitStop.last_requested == 0.0)
	RunState.clear_fixture()
	HitStop.allow_headless = true
	player.boons.event_dispatched.emit(&"sloth_burst", {})
	check("native path slows time", HitStop.is_active() and Engine.time_scale < 1.0)
	hud.queue_free()
	await get_tree().create_timer(0.08, true, false, true).timeout
	check("HUD teardown cannot strand time scale", not HitStop.is_active() and is_equal_approx(Engine.time_scale, 1.0))
	HitStop.last_requested = 0.0
	player.boons.event_dispatched.emit(&"wall_slam", {})
	check("freed HUD disconnects from action bus", HitStop.last_requested == 0.0)
	BoonHitstop.attach(self, player)
	player.health.apply_damage(999999.0, Hitbox.BodyPart.BODY)
	player.boons.event_dispatched.emit(&"wall_slam", {})
	check("death rejects feedback", HitStop.last_requested == 0.0)
	HitStop.allow_headless = false
	player.queue_free()
	await get_tree().process_frame
	print("BOON HITSTOP: %d checks, %d failures" % [checks, failed])
	get_tree().quit(1 if failed else 0)
