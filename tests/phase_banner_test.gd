extends Node
## Headless check of the centre-screen phase banners:
##   godot --headless --path . res://tests/phase_banner_test.tscn
## Each phase shows the right headline, the reinforcement warning is once per
## zone and queues behind "据点开放", and the banner hides for the scope and
## the buff selection.

var _failures := 0
var _finished := false
var _player: Player
var _banner: PhaseBanner
var _director: ZoneDirector


func _ready() -> void:
	await _run()
	for voice in find_children("*", "AudioStreamPlayer", true, false):
		voice.stop()
		voice.stream = null
	for child in get_children():
		child.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var scene := await _open_zone("res://maps/zone_1.tscn", 0, 13579)
	_player = scene.get_node("Player") as Player
	_director = scene.get_node("ZoneDirector") as ZoneDirector
	_banner = scene.get_node("HUD/PhaseBanner") as PhaseBanner
	_player.health.max_health = 100000.0
	_player.health.health = 100000.0
	# This observes banner transitions, independently of the live opening attack.
	_player.health.invulnerable = true

	_check("no banner under the entry buff selection", not _banner.is_showing() and not _banner.visible)
	_choose_entry(scene)
	await _frames(3)
	_check("zone start says 战斗开始", _banner.title_text() == "战斗开始" and _banner.is_showing())
	_check("with the objective hint", "据点才会开放" in _banner.subtitle_text())
	var panel := (scene.get_node("HUD/Top/Objective") as Label).text
	_check("not a duplicate of the objective panel", _banner.title_text() != panel
		and _banner.subtitle_text() != panel)
	await _seconds(3.1)
	_check("the banner fades out after its duration", not _banner.is_showing() and not _banner.visible)

	for enemy in _enemies(scene):
		enemy.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	await _frames(3)
	_check("the open point says 据点开放", _banner.title_text() == "据点开放" and _banner.is_showing())
	_check("the reinforcement warning waits behind it", _banner.queued_title() == "增援来袭")
	await _seconds(3.1)
	_check("then the warning appears", _banner.title_text() == "增援来袭")
	_check("red title", _banner.title_color().r > 0.9 and _banner.title_color().g < 0.5)
	var warn := _banner.title_text()
	_director.reinforcement_spawned.emit(Vector3.ZERO)
	await _frames(2)
	_check("the reinforcement warning is once per zone", _banner.title_text() == warn
		and _banner.queued_title().is_empty())

	await _test_ads_visible()
	await _test_replace()
	await _test_flag(scene)
	await _close(scene)
	await _test_boss()
	_finished = true


func _test_ads_visible() -> void:
	print("== hiding the banner")
	_director.phase_changed.emit(ZoneDirector.Phase.CLEAR_GUARDS)
	await _frames(2)
	Input.action_press("aim")
	await _seconds(0.7)
	_check("pistol aims", _player.weapon.aiming)
	_check("ADS keeps the current phase banner visible", _banner.visible and _banner.is_showing())
	Input.action_release("aim")
	await _seconds(0.3)
	_check("banner remains after ADS", _banner.visible)


func _test_replace() -> void:
	print("== a new phase replaces the banner")
	_director.phase_changed.emit(ZoneDirector.Phase.CLEAR_GUARDS)
	await _frames(2)
	_director.phase_changed.emit(ZoneDirector.Phase.BOSS_STANDING)
	await _frames(2)
	_check("the new prompt replaces the old one at once", _banner.title_text() == "Boss 现身")
	_check("and it has its own subtitle", _banner.subtitle_text().contains("城市核心"))


func _test_flag(scene: Node) -> void:
	print("== flag and objective text")
	_director.phase_changed.emit(ZoneDirector.Phase.HAMMER_POINT)
	await _frames(2)
	var point := scene.get_node("CapturePoint") as CapturePoint
	point.player_in_reach = true
	point.add_capture_progress(1.0)
	await _frames(3)
	_check("capture says 据点已占领", _banner.title_text() == "据点已占领" and _banner.is_showing())
	_check("and points at the pedestal action", "按 F" in _banner.subtitle_text())
	var panel := (scene.get_node("HUD/Top/Objective") as Label).text
	_check("without copying the objective line", _banner.subtitle_text() != panel
		and _banner.title_text() != panel)


func _test_boss() -> void:
	print("== the boss zone")
	RunState.zone_index = 2
	var scene: Node = load("res://maps/boss.tscn").instantiate()
	add_child(scene)
	await _frames(3)
	_player = scene.get_node("Player") as Player
	_director = scene.get_node("ZoneDirector") as ZoneDirector
	_banner = scene.get_node("HUD/PhaseBanner") as PhaseBanner
	_check("boss zone starts with Boss 现身", _banner.title_text() == "Boss 现身" and _banner.is_showing())
	_check("and its subtitle matches the core objective", "核心" in _banner.subtitle_text())
	var panel := (scene.get_node("HUD/Top/Objective") as Label).text
	_check("not the objective line", _banner.title_text() != panel and _banner.subtitle_text() != panel)
	(_director.boss as Enemy).health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	await _frames(3)
	_check("the open core says 砸碎城市核心", _banner.title_text() == "砸碎城市核心" and _banner.is_showing())
	_check("with the hammer action", "按 E" in _banner.subtitle_text())
	_director.capture_point.add_capture_progress(1.0)
	await _frames(3)
	_check("captured core replaces the hammer instruction immediately",
		_banner.title_text() == "核心已击碎" and _banner.subtitle_text().is_empty()
		and _banner.title_color() == PhaseBanner.TITLE_GREEN)
	# Let the real delayed victory callback finish before releasing its owner.
	await _seconds(1.5)
	await _close(scene)


func _open_zone(path: String, zone_index: int, run_seed: int) -> Node:
	get_tree().paused = false
	RunState.clear_fixture()
	RunState.zone_index = zone_index
	RunState.buffs.clear()
	RunState.selection_history.clear()
	RunState.run_seed = run_seed
	BuffPool.reset(run_seed)
	var scene := (load(path) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	return scene


func _close(scene: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(scene):
		scene.free()
	await get_tree().process_frame


func _choose_entry(scene: Node) -> void:
	if is_instance_valid(_director.selection):
		(_director.selection.get_node("Center/Box/Choices/Choice1") as Button).pressed.emit()


func _enemies(scene: Node) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if scene.is_ancestor_of(node):
			found.append(node as Enemy)
	return found


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
