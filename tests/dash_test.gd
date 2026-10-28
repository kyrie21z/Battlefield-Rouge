extends Node
## Headless check of the Shift dash:
##   godot --headless --path . res://tests/dash_test.tscn
## Prints one line per check and exits 1 if anything failed.
##
## The dash is measured on a flat test floor inside the same 30 m boundary as
## the real maps, through the real input actions. Distances come from where the
## body actually ended up, not from reading the exported numbers back; pitched
## dashes are measured in 3D.

const DISTANCE_TOLERANCE := 0.3
const FLOOR_SIZE := 80.0
const BOUNDARY := 30.0

var _failures := 0
var _finished := false
var _player: Player
var _vitals: Vitals


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	await _build_world()
	print("== the input action")
	_check("Shift is bound to `dash`", InputMap.has_action("dash")
		and not InputMap.has_action("sprint"))
	_check("the hold-to-sprint speed is gone", _player.get("sprint_speed") == null)
	_check("two charges, full at the start", _player.dash_charges() == 2
		and _player.dash_max_charges() == 2)

	_vitals = Vitals.new()
	_vitals.size = Vector2(340.0, 88.0)
	add_child(_vitals)
	_vitals.set_process(false)
	_vitals.setup(_player)
	_vitals.advance(0.0)
	_check("HUD starts with both pips full", _vitals.dash_charges == 2
		and _vitals.dash_max_charges == 2 and is_zero_approx(_vitals.dash_recharge_fraction))
	var dash_rect := Rect2(Vitals.DASH_ORIGIN,
		Vector2(Vitals.DASH_CELL.x * 2.0 + Vitals.DASH_GAP, Vitals.DASH_CELL.y))
	var shield_rect := Rect2(Vitals.BAR_RECT.position.x, Vitals.BAR_RECT.position.y - 16.0,
		Vitals.BAR_RECT.size.x, 6.0)
	_check("the dash pips clear the shield strip", not dash_rect.intersects(shield_rect))

	print("== forward dash, no direction held")
	var forward := await _dash_from([])
	_check("covers 5 m (%.2f m)" % forward.length(),
		absf(forward.length() - 5.0) <= DISTANCE_TOLERANCE)
	_check("goes straight ahead (%s)" % forward, forward.z < -4.0 and absf(forward.x) < 0.3)
	_check("one charge spent", _player.dash_charges() == 1)
	_vitals.advance(0.0)
	_check("HUD drops to one pip and starts refilling", _vitals.dash_charges == 1
		and _vitals.dash_recharge_fraction > 0.0)

	print("== dash follows the movement input")
	var right := await _dash_from(["move_right"])
	_check("covers 5 m to the right (%.2f m)" % right.length(),
		absf(right.length() - 5.0) <= DISTANCE_TOLERANCE)
	_check("moves +X when D is held (%s)" % right, right.x > 4.0 and absf(right.z) < 0.3)
	_check("both charges spent", _player.dash_charges() == 0)
	_vitals.advance(0.0)
	_check("HUD shows no ready pips", _vitals.dash_charges == 0
		and _vitals.dash_recharge_fraction > 0.0)

	print("== a third dash does nothing")
	var before := _player.global_position
	await _tap("dash")
	for i in 4:
		await get_tree().physics_frame
	_check("no dash starts without a charge", not _player.dash.is_dashing()
		and _player.dash_charges() == 0)
	_check("the body does not move", _player.global_position.distance_to(before) < 0.05)

	print("== one charge comes back after 1.5 s, one at a time")
	await _wait_for_charges(2, 300)
	_check("both charges are back", _player.dash_charges() == 2)
	await _start_dash([])
	_check("spending one leaves one", _player.dash_charges() == 1)
	for i in 72:
		await get_tree().physics_frame
	_check("still one at 1.2 s", _player.dash_charges() == 1)
	for i in 21:
		await get_tree().physics_frame
	_check("the second charge is back by 1.55 s", _player.dash_charges() == 2)

	print("== one air dash per leave from the ground")
	await _settle(6)
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 3:
		await get_tree().physics_frame
	_check("the jump left the floor", not _player.is_on_floor())
	await _start_dash([])
	_check("an air dash is allowed", _player.dash.is_dashing() and _player.dash_charges() == 1)
	await _tap("dash")
	_check("a second air dash is refused", _player.dash_charges() == 1)
	await _wait_until_floor(120)
	_check("landing restores the air dash", _player.is_on_floor())
	await _start_dash([])
	_check("the ground dash works again", _player.dash.is_dashing()
		and _player.dash_charges() == 0)
	await _wait_dash_end()

	print("== holding Shift no longer runs")
	_check("no charges left, so Shift cannot dash again", _player.dash_charges() == 0)
	Input.action_press("dash")
	Input.action_press("move_forward")
	await _settle(24)
	var walk := Vector2(_player.velocity.x, _player.velocity.z).length()
	_check("holding Shift + W walks at %.2f m/s" % walk,
		absf(walk - _player.jog_speed) <= 0.3)
	Input.action_release("dash")
	Input.action_release("move_forward")
	await _settle(4)

	print("== dash breaks ADS, keeps reloading, and grants immunity")
	await _wait_for_charges(2, 300)
	_player.stats.base[Stats.SKILL_UNLOCKED] = 1.0
	_check("the shield activates for the overlap test", _player.shield.try_activate()
		and _player.health.invulnerable)
	Input.action_press("aim")
	await _settle(3)
	_check("aiming is on before the dash", _player.weapon.aiming)
	await _start_dash([])
	_check("the dash is running", _player.dash.is_dashing())
	_check("ADS is dropped", not _player.weapon.aiming)
	_check("both immunity sources are on", _player.health.invulnerable
		and _player.health.dash_invulnerable)
	var full := _player.health.health
	var dealt := _player.health.apply_damage(20.0, Hitbox.BodyPart.BODY)
	_check("a hit during the dash deals nothing", is_zero_approx(dealt)
		and is_equal_approx(_player.health.health, full))
	await _wait_dash_end()
	_check("the shield still owns its immunity after the dash",
		_player.health.invulnerable and not _player.health.dash_invulnerable)
	dealt = _player.health.apply_damage(20.0, Hitbox.BodyPart.BODY)
	_check("the shield alone still blocks", is_zero_approx(dealt))
	_player.shield.cancel()
	await _settle(2)
	dealt = _player.health.apply_damage(20.0, Hitbox.BodyPart.BODY)
	_check("the dash immunity did not leak past its window", dealt > 0.0
		and _player.health.health < full)
	Input.action_release("aim")
	await _settle(2)

	_player.weapon.ammo = 5
	_player.weapon.reserve = 30
	_player.weapon.try_reload()
	_check("a reload starts", _player.weapon.is_reloading())
	await _start_dash([])
	_check("the dash does not cancel the reload", _player.weapon.is_reloading())
	await _wait_dash_end()
	_check("the reload is still running when the dash ends", _player.weapon.is_reloading())
	_player.weapon.select(0)

	_vitals.advance(0.0)
	_check("HUD follows the live charge count", _vitals.dash_charges == _player.dash_charges()
		and _vitals.dash_max_charges == _player.dash_max_charges())

	print("== the dash follows the camera pitch")
	await _wait_for_charges(2, 300)
	await _place(Vector3(0.0, 0.05, 0.0))
	var before_up := _player.global_position
	_aim(Vector3(0.0, 10.0, -10.0))
	await _start_dash([])
	await _wait_dash_end()
	var end_vy := _player.velocity.y
	var up := _player.global_position - before_up
	_check("a 45° pitch lifts the dash (%.2f m up)" % up.y, up.y > 2.0)
	_check("its 3D length is still 5 m (%.2f m)" % up.length(),
		absf(up.length() - 5.0) <= DISTANCE_TOLERANCE)
	_check("the hand-back zeroes velocity.y (%.2f m/s)" % end_vy, is_zero_approx(end_vy))

	print("== a level dash stays level")
	await _wait_for_charges(2, 300)
	await _place(Vector3(0.0, 0.05, 0.0))
	var level := await _dash_aimed(Vector3(0.0, 0.0, -10.0))
	_check("no vertical drift (%.2f m)" % level.y, absf(level.y) < 0.1)
	_check("it still covers 5 m (%.2f m)" % level.length(),
		absf(level.length() - 5.0) <= DISTANCE_TOLERANCE)

	print("== a downward dash slides along the floor")
	await _wait_for_charges(2, 300)
	await _place(Vector3(0.0, 0.05, 0.0))
	var down := await _dash_aimed(Vector3(0.0, -10.0, -10.0))
	var slide := Vector2(down.x, down.z).length()
	_check("a 45° down dash still covers ground (%.2f m)" % slide, slide > 2.0)
	_check("it does not sink through the floor (%.2f m)" % down.y, down.y >= -0.1)

	print("== the boundary stops a pitched dash")
	await _wait_for_charges(2, 300)
	await _place(Vector3(28.0, 0.05, 28.0))
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 3:
		await get_tree().physics_frame
	_check("the jump left the floor", not _player.is_on_floor())
	_aim(Vector3(10.0, 10.0, 10.0))
	await _start_dash([])
	await _wait_dash_end()
	var at_wall := _player.global_position
	_check("jump + upward dash stays inside x ±30 (%.2f)" % at_wall.x,
		at_wall.x <= BOUNDARY)
	_check("jump + upward dash stays inside z ±30 (%.2f)" % at_wall.z,
		at_wall.z <= BOUNDARY)

	_finished = true


func _build_world() -> void:
	var floor := StaticBody3D.new()
	floor.collision_layer = CollisionLayers.WORLD
	floor.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE)
	shape.shape = box
	shape.position.y = -0.5
	floor.add_child(shape)
	add_child(floor)

	_add_wall(Vector3(60.0, 36.0, 1.0), Vector3(0.0, 18.0, -BOUNDARY))
	_add_wall(Vector3(60.0, 36.0, 1.0), Vector3(0.0, 18.0, BOUNDARY))
	_add_wall(Vector3(1.0, 36.0, 60.0), Vector3(BOUNDARY, 18.0, 0.0))
	_add_wall(Vector3(1.0, 36.0, 60.0), Vector3(-BOUNDARY, 18.0, 0.0))

	_player = load("res://actors/player/player.tscn").instantiate() as Player
	_player.position = Vector3(0.0, 0.05, 0.0)
	add_child(_player)
	await _settle(12)


func _add_wall(size: Vector3, position: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.BOUNDARY
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	wall.add_child(shape)
	add_child(wall)


## Puts the body on the floor at `position` with the camera level.
func _place(position: Vector3) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = position
	_player.global_rotation = Vector3.ZERO
	_aim(Vector3(0.0, 0.0, -10.0))
	await _wait_until_floor(180)
	await _settle(2)


## Points the camera so its forward axis is `direction`, in camera space: -Z
## ahead, +Y up.
func _aim(direction: Vector3) -> void:
	_player.aim_at(_camera_pos() + direction)


func _camera_pos() -> Vector3:
	return (_player.get_node("Head/Camera3D") as Camera3D).global_position


## One dash with the camera tilted along `aim`, measured in 3D after the
## hand-back.
func _dash_aimed(aim: Vector3) -> Vector3:
	_aim(aim)
	var before := _player.global_position
	await _start_dash([])
	await _wait_dash_end()
	return _player.global_position - before


## Dashes from a settled standstill and returns the horizontal displacement,
## measured after the dash has handed movement back to the walk code.
func _dash_from(actions: Array[String]) -> Vector3:
	await _settle(6)
	_player.global_rotation = Vector3.ZERO
	_aim(Vector3(0.0, 0.0, -10.0))
	_player.velocity = Vector3.ZERO
	await _settle(2)
	var before := _player.global_position
	await _start_dash(actions)
	await _wait_dash_end()
	var delta := _player.global_position - before
	delta.y = 0.0
	return delta


## Presses Shift with `actions` held until the dash actually starts. The
## physics_frame signal fires before nodes run, so checking is_dashing() right
## after one wait would race ahead of the dash and measure nothing.
func _start_dash(actions: Array[String]) -> void:
	for action in actions:
		Input.action_press(action)
	Input.action_press("dash")
	for i in 12:
		await get_tree().physics_frame
		if _player.dash.is_dashing():
			break
	Input.action_release("dash")
	for action in actions:
		Input.action_release(action)


func _wait_dash_end() -> void:
	var frames := 0
	while _player.dash.is_dashing() and frames < 60:
		await get_tree().physics_frame
		frames += 1


func _wait_for_charges(target: int, limit: int) -> void:
	var frames := 0
	while _player.dash_charges() < target and frames < limit:
		await get_tree().physics_frame
		frames += 1


func _wait_until_floor(limit: int) -> void:
	var frames := 0
	while not _player.is_on_floor() and frames < limit:
		await get_tree().physics_frame
		frames += 1


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
