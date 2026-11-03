extends Node
## Headless check of the capture point's hammer feedback:
##   godot --headless --path . res://tests/hammer_feel_test.tscn
## Presentation only: progress, beats, fracture stages and collision stay as
## they were; the camera shake, block squash, chips, brass payoff and floating
## text are what this checks.

var _failures := 0
var _finished := false
var _player: Player
var _hud
var _point: CapturePoint
var _aim: Camera3D


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
	get_tree().paused = false
	_player = scene.get_node("Player") as Player
	_hud = scene.get_node("HUD")
	_point = scene.get_node("CapturePoint") as CapturePoint
	_aim = _player.get_node("Head/Camera3D") as Camera3D
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)
	var shape := _point.get_node("Objective/Shape") as CollisionShape3D
	var shape_before := shape.global_transform
	_point.open()
	_point.player_in_reach = true
	_player.global_position = _point.global_position + Vector3(0.0, 0.0, 3.0)
	await _frames(3)

	await _test_normal_strike()
	await _test_perfect_strike()
	await _test_fractures()
	await _test_capture()
	_check("the collision shape never moved", shape.global_transform.is_equal_approx(shape_before))
	_finished = true


func _test_normal_strike() -> void:
	print("== an ordinary strike")
	var want := "+%d%%" % roundi(_point.config.normal_progress() * 100.0)
	var aim_before := _aim.global_transform
	_hud.last_strike_shake = 0.0
	_point.resolve_swing(2.3)
	_check("the view shakes", _player.view_is_shaking())
	_check("an ordinary strike kicks 0.45 deg (%.2f)" % _hud.last_strike_shake,
		is_equal_approx(_hud.last_strike_shake, 0.45))
	_check("the floating text says %s" % want, _hud._strike_text.text == want)
	_check("it starts white and fully opaque", _hud._strike_text.modulate.a > 0.9
		and _hud._strike_text.get_theme_color("font_color").g > 0.9)
	_check("an ordinary strike throws %d chips" % _point.last_chip_count, _point.last_chip_count == 14)
	_check("the aim camera does not move", _aim.global_transform.is_equal_approx(aim_before))
	await _seconds(0.5)
	_check("the blocks settle exactly back on their rests", _blocks_at_rest())
	await _seconds(0.25)
	_check("the text has faded", _hud._strike_text.modulate.a <= 0.01)
	var risen: float = _hud._strike_text.offset_top
	_check("the text started rising (%.0f)" % risen, risen < _hud.STRIKE_TEXT_TOP)


func _test_perfect_strike() -> void:
	print("== a perfect strike")
	var want := "+%d%%" % roundi(_point.config.perfect_progress() * 100.0)
	_hud.last_strike_shake = 0.0
	HitStop.last_requested = 0.0
	_point.resolve_swing(3.0)
	_check("a perfect strike kicks harder (%.2f > 0.45)" % _hud.last_strike_shake,
		is_equal_approx(_hud.last_strike_shake, 0.9) and _hud.last_strike_shake > 0.45)
	_check("the floating text says %s" % want, _hud._strike_text.text == want)
	_check("it is gold", _hud._strike_text.get_theme_color("font_color").g > 0.7
		and _hud._strike_text.get_theme_color("font_color").b < 0.4)
	_check("a perfect strike throws %d chips" % _point.last_chip_count, _point.last_chip_count == 30)
	_check("it asks for a 0.035 s hitstop (%.3f)" % HitStop.last_requested,
		is_equal_approx(HitStop.last_requested, 0.035))
	await _seconds(0.5)
	_check("the blocks settle exactly back on their rests", _blocks_at_rest())


func _test_fractures() -> void:
	print("== quarter breaks")
	_point.progress = 0.0
	var stages: Array[int] = []
	_point.fractured.connect(func(stage: int) -> void: stages.append(stage))
	_hud.last_strike_shake = 0.0
	_point.add_capture_progress(0.25)
	_check("25% emits fractured(1)", stages == [1])
	_check("a quarter break kicks 0.7 deg (%.2f)" % _hud.last_strike_shake,
		is_equal_approx(_hud.last_strike_shake, 0.7))
	_point.add_capture_progress(0.25)
	_point.add_capture_progress(0.25)
	_check("one fractured per quarter, no duplicates", stages == [1, 2, 3])
	_check("six blocks have come off, two are left", _point.fracture_stage == 3
		and _point.intact_block_count() == 2)


func _test_capture() -> void:
	print("== the stopped clock breaks open")
	var captured := [0]
	_point.captured.connect(func() -> void: captured[0] += 1)
	_hud.last_strike_shake = 0.0
	_point.add_capture_progress(0.25)
	_check("capture fires once", captured[0] == 1 and _point.is_captured())
	_check("the payoff kicks 1.6 deg (%.2f)" % _hud.last_strike_shake,
		is_equal_approx(_hud.last_strike_shake, 1.6))
	var gears := _point.gear_piece_count()
	_check("brass clock parts burst out (%d)" % gears, gears >= 24 and gears <= 40)
	var specs := _point._gear_specs()
	_check("the gear specs are deterministic", _same_specs(specs, _point._gear_specs()))
	_check("the spawned gears use those specs", _gears_match_specs(specs))
	var airborne := true
	for i in _point._gears.size():
		var node: Node3D = _point._gears[i].node
		if node.position.y <= CapturePoint.GEAR_SETTLE_Y:
			airborne = false
	_check("the pieces are still in the air", airborne)
	await _seconds(0.35)
	_check("and they fall", _gears_moved(specs))


func _blocks_at_rest() -> bool:
	for block in _point._blocks:
		if block in _point._broken:
			continue
		var rest: Transform3D = _point._block_rest[block]
		if not block.transform.is_equal_approx(rest):
			return false
	return true


func _same_specs(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if int(a[i].kind) != int(b[i].kind):
			return false
		for key in ["radius", "height", "size"]:
			if not is_equal_approx(float(a[i][key]), float(b[i][key])):
				return false
		for key in ["offset", "velocity", "spin", "tilt"]:
			var va: Vector3 = a[i][key]
			var vb: Vector3 = b[i][key]
			if not va.is_equal_approx(vb):
				return false
	return true


func _gears_match_specs(specs: Array[Dictionary]) -> bool:
	if _point._gears.size() != specs.size():
		return false
	for i in specs.size():
		var offset: Vector3 = specs[i].offset
		var node: Node3D = _point._gears[i].node
		if not node.position.is_equal_approx(_point._gear_origin + offset):
			return false
	return true


## True once at least one piece has moved away from where it spawned.
func _gears_moved(specs: Array[Dictionary]) -> bool:
	for i in _point._gears.size():
		var offset: Vector3 = specs[i].offset
		var node: Node3D = _point._gears[i].node
		if node.position.distance_to(_point._gear_origin + offset) > 0.05:
			return true
	return false


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
