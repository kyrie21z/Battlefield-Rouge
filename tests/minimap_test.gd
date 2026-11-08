extends Node
## Headless check of the HUD minimap:
##   godot --headless --path . res://tests/minimap_test.tscn
## Presentation only: geometry, the world-to-map transform, marker visibility,
## rim clamping, reinforcement pulses and the scope hiding rule.

var _failures := 0
var _finished := false
var _player: Player
var _director: ZoneDirector
var _map: Minimap


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	_choose_entry(scene)
	await _frames(3)
	_player = scene.get_node("Player") as Player
	_director = scene.get_node("ZoneDirector") as ZoneDirector
	_map = scene.get_node("HUD/Minimap") as Minimap
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)
	_player.global_position = Vector3.ZERO
	_player.global_rotation = Vector3.ZERO
	await _frames(3)

	await _test_scope_hide()
	_test_geometry()
	await _test_transform()
	await _test_enemies()
	_test_capture_clamp()
	await _test_reinforcement_pulse()
	await _test_boss()
	_finished = true


func _test_scope_hide() -> void:
	print("== the scope takes the minimap away")
	_player.weapon.select(2)
	Input.action_press("aim")
	await _seconds(0.7)
	_check("sniping is scoped", _player.weapon.is_scoped())
	await _frames(2)
	_check("the minimap hides behind the scope", not _map.visible)
	Input.action_release("aim")
	await _seconds(0.7)
	await _frames(2)
	_check("and comes back when the scope goes down", _map.visible)


func _test_geometry() -> void:
	print("== level geometry")
	_check("geometry polygons were read (%d)" % _map.geometry_count(), _map.geometry_count() > 0)
	var covers_centre := false
	for poly in _map._geometry:
		if Geometry2D.is_point_in_polygon(Vector2.ZERO, poly):
			covers_centre = true
	_check("the floor is excluded", not covers_centre)


func _test_transform() -> void:
	print("== world to map")
	var centre := _map.size * 0.5
	_player.global_position = Vector3.ZERO
	_player.global_rotation = Vector3.ZERO
	await _frames(1)
	var ahead := _map.to_map(Vector3(0.0, 0.0, -10.0))
	_check("10 m ahead maps above the centre", ahead.y < centre.y - 10.0 and absf(ahead.x - centre.x) < 0.5)
	var right := _map.to_map(Vector3(10.0, 0.0, 0.0))
	_check("10 m right maps to the right", right.x > centre.x + 10.0 and absf(right.y - centre.y) < 0.5)
	_check("both directions use the same scale",
		is_equal_approx(centre.y - ahead.y, right.x - centre.x))
	_player.global_rotation = Vector3(0.0, PI * 0.5, 0.0)
	await _frames(1)
	var turned := _map.to_map(Vector3(0.0, 0.0, -10.0))
	_check("after a 90 deg turn the same point is to the right",
		turned.x > centre.x + 10.0 and absf(turned.y - centre.y) < 0.5)
	_check("turning does not change the distance",
		is_equal_approx(ahead.distance_to(centre), turned.distance_to(centre)))
	_player.global_rotation = Vector3.ZERO
	await _frames(1)


func _test_enemies() -> void:
	print("== enemy markers")
	_check("the guards are living", _director.living_enemies().size() >= 2)
	var victim: Enemy = _director.living_enemies()[0]
	# Guard placement spans the larger courtyard. Establish visibility before
	# checking the range transition instead of assuming the first guard is near.
	victim.global_position = _player.global_position + Vector3(5.0, 0.0, 0.0)
	await _frames(1)
	var before := _map.visible_enemy_count()
	_check("a nearby guard is drawn", before > 0)
	victim.global_position = _player.global_position + Vector3(Minimap.RANGE_METERS + 10.0, 0.0, 0.0)
	await _frames(1)
	_check("an enemy beyond range is not drawn", _map.visible_enemy_count() == before - 1)
	victim.global_position = _player.global_position + Vector3(5.0, 0.0, 0.0)
	await _frames(1)
	var living := _director.living_enemies()
	victim.health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	await _frames(2)
	_check("a dead enemy leaves living_enemies", _director.living_enemies().size() == living.size() - 1
		and not _director.living_enemies().has(victim))


func _test_capture_clamp() -> void:
	print("== out-of-range objectives")
	_player.set_physics_process(false)
	_player.global_position = Vector3(100.0, 0.0, 0.0)
	var centre := _map.size * 0.5
	var limit := minf(_map.size.x, _map.size.y) * 0.5 - Minimap.RIM_WIDTH - Minimap.MARKER_RADIUS - 2.0
	var rim := _map.rim_position(_director.capture_point.global_position)
	_check("the capture point clamps to the rim", absf(rim.distance_to(centre) - limit) < 0.5)
	var wanted := (_map.to_map(_director.capture_point.global_position) - centre).normalized()
	_check("and keeps its direction", (rim - centre).normalized().dot(wanted) > 0.99)


func _test_reinforcement_pulse() -> void:
	print("== reinforcement warning")
	var emitted: Array[Vector3] = []
	_director.reinforcement_spawned.connect(func(position: Vector3) -> void: emitted.append(position))
	_director._spawn_one()
	_check("spawning a reinforcement signals its position", emitted.size() == 1)
	_check("the minimap starts a pulse", _map.pulse_count() == 1)
	await _seconds(1.35)
	_check("the pulse expires", _map.pulse_count() == 0)


func _test_boss() -> void:
	print("== the boss on the boss map")
	_player.get_parent().queue_free()
	await _frames(2)
	RunState.zone_index = 2
	var boss_scene: Node = load("res://maps/boss.tscn").instantiate()
	add_child(boss_scene)
	await _frames(3)
	var boss_director := boss_scene.get_node("ZoneDirector") as ZoneDirector
	_check("the boss is alive", boss_director.boss != null and not boss_director.boss.health.is_dead())
	_check("living_enemies includes the boss",
		boss_director.boss != null and boss_director.living_enemies().has(boss_director.boss))
	_check("the boss map minimap was set up",
		(boss_scene.get_node("HUD/Minimap") as Minimap).geometry_count() > 0)


func _choose_entry(scene: Node) -> void:
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	if is_instance_valid(director.selection):
		(director.selection.get_node("Center/Box/Choices/Choice1") as Button).pressed.emit()


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
