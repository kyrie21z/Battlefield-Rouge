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

var _checks := 0
var _failures := 0
var _finished := false
var _zone_cleared := 0
var _run_won := 0


func _ready() -> void:
	Events.zone_cleared.connect(func(_zone: int): _zone_cleared += 1)
	Events.run_won.connect(func(): _run_won += 1)
	await _run()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	var ok := _failures == 0 and _finished
	print("%s (%d checks, %d failed%s)" % ["ALL PASSED" if ok else "FAIL", _checks,
		_failures, "" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	print("== run order")
	_check("there are three zones", RunState.ZONE_SCENES.size() == 3)
	_check("the boss zone is the last one", RunState.ZONE_SCENES.back() == BOSS_SCENE)

	print("== the wave: one big enemy with two escorts, nine small ones in all")
	var scene := await _load_boss()
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	var boss := scene.get_node("Boss") as Enemy
	var enemies := get_tree().get_nodes_in_group("enemy")
	var small: Array = enemies.filter(func(e: Node): return e != boss)
	_check("ten enemies in all", enemies.size() == 10)
	_check("nine of them are small", small.size() == 9)
	var sample := small[0] as Enemy
	_check("the boss has far more health (%d vs %d)" % [boss.health.max_health, sample.health.max_health],
		boss.health.max_health >= sample.health.max_health * 4.0)
	var boss_height := (boss.get_node("CollisionShape3D") as CollisionShape3D).shape.height as float
	var small_height := (sample.get_node("CollisionShape3D") as CollisionShape3D).shape.height as float
	_check("the boss is taller (%.1f m vs %.1f m)" % [boss_height, small_height], boss_height > small_height * 1.3)
	_check("the boss shoots from higher up", boss.eye_height > sample.eye_height)
	_check("the boss wears the Hazmat model", boss.find_child("Character_Hazmat", true, false) != null
		and boss.find_child("Character_Enemy", true, false) == null)
	_check("the small enemies use the Sloth crystal variants", sample is SlothEnemy
		and sample.find_child("GEO_m_head", true, false) != null)
	var boss_head := boss.find_child("HeadHitbox", true, false) as Hitbox
	_check("the boss head hitbox moved onto the new skeleton",
		boss_head != null and boss_head.get_parent().get_parent() == boss.get_node("Model/CharacterArmature/Skeleton3D"))
	_check("a bigger head pays less per headshot (%.2f vs %.2f)" % [boss.health.headshot_multiplier, sample.health.headshot_multiplier],
		boss.health.headshot_multiplier < sample.health.headshot_multiplier)
	var escorts: Array[Enemy] = []
	var others: Array[Enemy] = []
	for enemy: Enemy in small:
		var gap := Vector2(enemy.global_position.x - boss.global_position.x,
			enemy.global_position.z - boss.global_position.z).length()
		if gap > 2.0 and gap < 6.0:
			escorts.append(enemy)
		else:
			others.append(enemy)
	_check("two small enemies escort the boss at 2-6 m", escorts.size() == 2)
	_check("the other seven hold the front and middle, nearer the player",
		others.size() == 7 and others.all(func(e: Enemy) -> bool:
			return e.global_position.distance_to(player.global_position) < boss.global_position.distance_to(player.global_position)))
	_check("the enemies are in front of the core, not past it", boss.global_position.z > point.global_position.z)
	for enemy: Enemy in enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

	print("== the boss has a health bar")
	var bar := scene.get_node("HUD/BossHealth") as BossHealth
	_check("the director reports the boss", director.boss == boss)
	_check("only the boss is flagged as one", enemies.filter(func(e: Node): return (e as Enemy).is_boss).size() == 1)
	_check("the bar is shown", bar.visible and not bar.fallen)
	_check("it starts full (%d / %d)" % [bar.displayed_health, bar.max_health],
		bar.max_health == boss.health.max_health and bar.max_health == 900.0
		and bar.displayed_health == 900.0 and bar.delayed_health == 900.0)
	_check("the label gives the numbers", bar.health_text == "900 / 900")
	boss.health.apply_damage(42.0, Hitbox.BodyPart.BODY)
	_check("a hit immediately lowers the bar to %d" % boss.health.health,
		bar.displayed_health == boss.health.health and bar.displayed_health == 858.0)
	_check("the label immediately follows", bar.health_text == "858 / 900")
	small[0].health.apply_damage(30.0, Hitbox.BodyPart.BODY)
	_check("hitting a small enemy does not move it", bar.displayed_health == 858.0)

	print("== the core stays shut while the boss stands")
	var objective := scene.get_node("HUD/Top/Objective") as Label
	var shared := load(CONFIG_PATH) as CaptureConfig
	_check("the zone is the boss zone", director.is_boss_zone)
	_check("it starts with the boss still to fell", director.phase == ZoneDirector.Phase.BOSS_STANDING)
	_check("the core is locked", point.locked)
	_check("the objective says to fell the boss", director.objective == "打倒 Boss" and objective.text == "击倒 Boss" and objective.visible)
	_check("one blade strike would finish the core", is_equal_approx(point.config.progress_per_swing, 1.0))
	_check("small zones still use the 10% rhythm", shared.resource_path == CONFIG_PATH and is_zero_approx(shared.progress_per_swing) and is_equal_approx(shared.normal_progress(), 0.10))
	_check("ten enemies are alive and the core stays shut", director.enemies_total == 10 and not boss.health.is_dead())
	player.global_position = point.global_position + Vector3(3.6, 0.0, 0.0)
	for i in 6:
		await get_tree().physics_frame
	_check("walking up to the core puts the player in reach", point.player_in_reach)
	point.resolve_swing(2.0)
	point.resolve_swing(2.5)
	_check("striking a locked core adds nothing", point.progress == 0.0 and point.locked)
	_check("the hint is still on screen", objective.text == "击倒 Boss")

	print("== the nine small enemies do not open the core")
	for i in small.size():
		(small[i] as Enemy).health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	_check("nine small enemies dead, core still shut", director.phase == ZoneDirector.Phase.BOSS_STANDING and point.locked and point.progress == 0.0)
	_check("killing them never counted as clearing the zone", _zone_cleared == 0)

	print("== the boss's death opens the core, and one blade strike shatters it")
	# Reload a fresh wave so the small enemies are still alive for this check.
	get_tree().paused = false
	scene.free()
	_zone_cleared = 0
	scene = await _load_boss()
	director = scene.get_node("ZoneDirector") as ZoneDirector
	point = scene.get_node("CapturePoint") as CapturePoint
	player = scene.get_node("Player") as Player
	boss = scene.get_node("Boss") as Enemy
	bar = scene.get_node("HUD/BossHealth") as BossHealth
	objective = scene.get_node("HUD/Top/Objective") as Label
	enemies = get_tree().get_nodes_in_group("enemy")
	small = enemies.filter(func(e: Node): return e != boss)
	for enemy: Enemy in enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = point.global_position + Vector3(3.6, 0.0, 0.0)
	for i in 6:
		await get_tree().physics_frame
	boss.health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	_check("the boss is dead and the small enemies are not", boss.health.is_dead() and small.all(func(e: Enemy): return not e.health.is_dead()))
	_check("the core opens", director.phase == ZoneDirector.Phase.CLOCK_POINT and not point.locked)
	_check("the objective names the blade", director.objective == "砸碎城市核心，按 V" and objective.text == "挥刃敲钟")
	_check("the bar is empty once the boss is dead", bar.displayed_health == 0.0)
	_check("the label says it has fallen", bar.health_text == "已倒下" and bar.fallen
		and bar.fill_color == CapturePoint.COLOR_LOCKED)
	point.resolve_swing(2.5)
	_check("one ordinary blade reaches 100%", point.is_captured() and is_equal_approx(point.progress, 1.0))
	_check("that one blade strike collapses every block", point.fracture_stage == 4 and point.intact_block_count() == 0)
	_check("the director is in FLAG_PLANTED", director.phase == ZoneDirector.Phase.FLAG_PLANTED)
	_check("the short objective confirms the core capture", objective.text == "城市核心已夺取")
	_check("a flag was planted on the core", point.get_node_or_null("Flag") != null)
	_check("killing the wave never counted as clearing the zone", _zone_cleared == 0)

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
	point.resolve_swing(2.5)
	_check("a swing before the boss falls adds nothing", point.progress == 0.0 and point.locked)
	(scene.get_node("Boss") as Enemy).health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	_check("the core is open and still empty", not point.locked and point.progress == 0.0)
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
	_check("zone 1 shows no boss bar", not (scene.get_node("HUD/BossHealth") as BossHealth).visible)
	var boss_marker := scene.get_node("HUD/WorldMarkers/Boss") as WorldMarker
	boss_marker.refresh()
	_check("zone 1 shows no boss marker", not boss_marker.visible and boss_marker.target == null)
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
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
