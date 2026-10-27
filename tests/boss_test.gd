extends Node
## Headless check of the boss zone (Cut-001b AC-02). Run from the project root
## (it is a scene, not a --script, so the autoloads exist):
##   godot --headless --path . res://tests/boss_test.tscn
## Prints one line per check. Exits 1 if a check failed or if the run stopped
## before the last check (a script error inside it), so it cannot pass by accident.
## The enemies' AI is switched off so the scripted player is not shot; how they
## fight is not under test here, only the wave and how the zone ends.

const BOSS_SCENE := "res://maps/boss.tscn"
const CONFIG_PATH := "res://zone/capture_config.tres"

var _failures := 0
var _finished := false
var _zone_cleared := 0
var _run_won := 0


func _ready() -> void:
	Events.zone_cleared.connect(func(_zone: int): _zone_cleared += 1)
	Events.run_won.connect(func(): _run_won += 1)
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures, "" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	print("== run order")
	_check("there are three zones", RunState.ZONE_SCENES.size() == 3)
	_check("the boss zone is the last one", RunState.ZONE_SCENES.back() == BOSS_SCENE)

	print("== the wave: one big enemy, six small ones around it")
	var scene := await _load_boss()
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	var boss := scene.get_node("Boss") as Enemy
	var enemies := get_tree().get_nodes_in_group("enemy")
	var small: Array = enemies.filter(func(e: Node): return e != boss)
	_check("seven enemies in all", enemies.size() == 7)
	_check("six of them are small", small.size() == 6)
	var sample := small[0] as Enemy
	_check("the boss has far more health (%d vs %d)" % [boss.health.max_health, sample.health.max_health],
		boss.health.max_health >= sample.health.max_health * 4.0)
	var boss_height := (boss.get_node("CollisionShape3D") as CollisionShape3D).shape.height as float
	var small_height := (sample.get_node("CollisionShape3D") as CollisionShape3D).shape.height as float
	_check("the boss is taller (%.1f m vs %.1f m)" % [boss_height, small_height], boss_height > small_height * 1.3)
	_check("the boss shoots from higher up", boss.eye_height > sample.eye_height)
	var ring_ok := true
	for enemy: Enemy in small:
		var gap := Vector2(enemy.global_position.x - boss.global_position.x,
			enemy.global_position.z - boss.global_position.z).length()
		ring_ok = ring_ok and gap > 2.0 and gap < 6.0
	_check("the six small enemies stand 2-6 m around the boss", ring_ok)
	_check("the enemies are in front of the core, not past it", boss.global_position.z > point.global_position.z)
	for enemy: Enemy in enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

	print("== the boss has a health bar")
	var bar := scene.get_node("HUD/Top/BossBar") as ProgressBar
	var bar_label := scene.get_node("HUD/Top/BossLabel") as Label
	_check("the director reports the boss", director.boss == boss)
	_check("only the boss is flagged as one", enemies.filter(func(e: Node): return (e as Enemy).is_boss).size() == 1)
	_check("the bar is shown", bar.visible and bar_label.visible)
	_check("it starts full (%d / %d)" % [bar.value, bar.max_value],
		bar.max_value == boss.health.max_health and bar.value == bar.max_value)
	_check("the label gives the numbers", "600 / 600" in bar_label.text)
	boss.health.apply_damage(42.0, Hitbox.BodyPart.BODY)
	_check("a hit lowers the bar to %d" % boss.health.health, bar.value == boss.health.health and bar.value == 558.0)
	_check("the label follows", "558 / 600" in bar_label.text)
	small[0].health.apply_damage(30.0, Hitbox.BodyPart.BODY)
	_check("hitting a small enemy does not move it", bar.value == 558.0)

	print("== the core is open from the start (no clear-first)")
	_check("the zone is set to open at once", director.open_at_start)
	_check("it starts in HAMMER_POINT", director.phase == ZoneDirector.Phase.HAMMER_POINT)
	_check("the core is not locked", not point.locked)
	_check("the core uses the same config as the small zones", point.config.resource_path == CONFIG_PATH)
	_check("seven enemies are alive and the core is open anyway", director.enemies_total == 7)
	player.global_position = point.global_position + Vector3(3.6, 0.0, 0.0)
	for i in 6:
		await get_tree().physics_frame
	_check("walking up to the core puts the player in reach", point.player_in_reach)
	point.resolve_swing(2.0)
	_check("a perfect strike adds 12% with enemies alive", is_equal_approx(point.progress, 0.12))
	point.resolve_swing(2.5)
	_check("an ordinary strike adds 8% with enemies alive", is_equal_approx(point.progress, 0.20))

	print("== killing the wave does not gate or reset the core")
	for i in small.size():
		(small[i] as Enemy).health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	_check("six small enemies dead, still HAMMER_POINT", director.phase == ZoneDirector.Phase.HAMMER_POINT)
	_check("progress is untouched by the kills", is_equal_approx(point.progress, 0.20))
	var swings := 0
	while not point.is_captured() and swings < 40:
		point.resolve_swing(10.0 + swings)
		swings += 1
	_check("the core reaches 100%", point.is_captured())
	_check("the director is in FLAG_PLANTED", director.phase == ZoneDirector.Phase.FLAG_PLANTED)
	_check("a flag was planted on the core", point.get_node_or_null("Flag") != null)
	boss.health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	_check("killing the boss during the flag raise does not move the phase back",
		director.phase == ZoneDirector.Phase.FLAG_PLANTED)
	_check("killing the wave never counted as clearing the zone", _zone_cleared == 0)
	_check("the bar is empty once the boss is dead", bar.value == 0.0)
	_check("the label says it has fallen", "已倒下" in bar_label.text)

	print("== victory")
	_check("no win yet while the flag is rising", _run_won == 0)
	await get_tree().create_timer(ZoneDirector.FLAG_RAISE_TIME + 0.3).timeout
	var end := _end_screen(director)
	_check("the end screen appears", end != null)
	_check("it says victory", end != null and _title(end) == "胜利")
	_check("it names the city core", end != null and "城市核心" in _subtitle(end))
	_check("the run is won once", _run_won == 1)
	_check("no buff is offered after the boss", not director.get_children().any(func(c: Node): return c.has_signal("chosen")))
	get_tree().paused = false
	scene.queue_free()
	await get_tree().process_frame

	print("== defeat")
	_run_won = 0
	RunState.zone_index = RunState.ZONE_SCENES.size() - 1
	scene = await _load_boss()
	director = scene.get_node("ZoneDirector") as ZoneDirector
	point = scene.get_node("CapturePoint") as CapturePoint
	player = scene.get_node("Player") as Player
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = point.global_position + Vector3(3.6, 0.0, 0.0)
	for i in 6:
		await get_tree().physics_frame
	point.resolve_swing(2.0)
	_check("some progress was made", point.progress > 0.0 and not point.is_captured())
	player.health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	_check("the player is dead", player.health.is_dead())
	end = _end_screen(director)
	_check("the end screen appears", end != null)
	_check("it says defeat", end != null and _title(end) == "阵亡")
	_check("the run is reset to the first zone", RunState.zone_index == 0)
	_check("the core was not captured", not point.is_captured())
	_check("no victory was reported", _run_won == 0)
	point.add_capture_progress(1.0)
	await get_tree().create_timer(ZoneDirector.FLAG_RAISE_TIME + 0.3).timeout
	_check("a late capture after death does not turn it into a win", _run_won == 0 and _title(end) == "阵亡")
	get_tree().paused = false
	scene.queue_free()
	await get_tree().process_frame

	print("== a small zone has no boss bar")
	RunState.start_new_run()
	scene = await _load_scene(RunState.zone_scene())
	director = scene.get_node("ZoneDirector") as ZoneDirector
	_check("zone 1 has no boss", director.boss == null)
	_check("zone 1 shows no boss bar", not (scene.get_node("HUD/Top/BossBar") as ProgressBar).visible)
	scene.queue_free()
	await get_tree().process_frame
	_finished = true


func _load_boss() -> Node:
	RunState.zone_index = RunState.ZONE_SCENES.size() - 1
	return await _load_scene(BOSS_SCENE)


func _load_scene(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	if is_instance_valid(director.selection):
		(director.selection.get_node("Center/Box/Choices/Choice1") as Button).pressed.emit()
	return scene


func _end_screen(director: ZoneDirector) -> Node:
	for child in director.get_children():
		if child.has_signal("restart_pressed"):
			return child
	return null


func _title(end: Node) -> String:
	return (end.get_node("Center/Box/Title") as Label).text


func _subtitle(end: Node) -> String:
	return (end.get_node("Center/Box/Subtitle") as Label).text


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
