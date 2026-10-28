extends Node
## Behavior checks for held magazines, real projectile travel and the wider shield.

class Source extends Node3D:
	var team := 1

var _checks := 0
var _failures := 0
var _finished := false
var _elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	_finished = true
	print("ACTIVE MAGAZINE: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 20.0 and not _finished:
		push_error("Active magazine fixture timed out")
		get_tree().quit(1)


func _run() -> void:
	var arena := Node3D.new()
	add_child(arena)
	var player: Player = load("res://actors/player/player.tscn").instantiate()
	arena.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	player.shield.set_process(false)
	var traits := player.combat_traits
	var weapon := player.weapon
	var thrown: Array[Node3D] = []
	traits.reload_charge_thrown.connect(func(charge: Node3D): thrown.append(charge))
	_check("no charge can be thrown before the buff", not traits.try_throw_reload_charge())
	weapon.ammo = 0
	weapon.try_reload()
	_finish_reload(weapon)
	_check("an ordinary completed empty reload cannot grant a charge", not traits.has_reload_charge())
	player.stats.apply_buff(BuffPool.ALL[0])
	_check("first stack has 120 explosive damage", player.stats.get_value(Stats.RELOAD_BLAST_DAMAGE) == 120.0)
	weapon.ammo = 1
	weapon.try_reload()
	_finish_reload(weapon)
	_check("completed tactical reload does not store a charge", not traits.has_reload_charge())
	weapon.ammo = 0
	weapon.try_reload()
	weapon.try_reload()
	_check("starting and repeating R does not grant an unfinished charge", not traits.has_reload_charge() and thrown.is_empty())
	weapon.select_next()
	weapon._finish_reload()
	_check("switching guns cancels an unfinished reload candidate", not traits.has_reload_charge())
	weapon.ammo = 0
	weapon.reserve = 100
	weapon.try_reload()
	_finish_reload(weapon)
	_check("completed empty reload stores exactly one charge without launching", traits.has_reload_charge() and thrown.is_empty())
	var held := player.get_node("Head/Camera3D/HeldReloadCharge") as Node3D
	_check("the stored magazine is visible in hand", held.visible)
	# There is no live projectile or fuse while the magazine is in the hand.
	await get_tree().create_timer(ReloadCharge.FUSE_TIME + 0.2).timeout
	_check("holding past the fuse duration neither throws nor explodes", traits.has_reload_charge() and thrown.is_empty())
	weapon.select_next()
	_check("switching guns preserves an existing held magazine", traits.has_reload_charge())
	weapon.aiming = true
	traits._process(0.0)
	_check("a scope hides the held model without spending inventory", not held.visible and traits.has_reload_charge())
	weapon.aiming = false
	traits._process(0.0)
	_check("leaving the scope restores the held model", held.visible)
	weapon.ammo = 0
	weapon.reserve = 100
	weapon.try_reload()
	_finish_reload(weapon)
	_check("another completed empty reload cannot duplicate the inventory", traits.has_reload_charge() and thrown.is_empty())
	get_tree().paused = true
	_check("the public throw path cannot consume inventory while paused", not traits.try_throw_reload_charge() and traits.has_reload_charge())
	get_tree().paused = false
	player.stats.apply_buff(BuffPool.ALL[0])
	# A further reload can run while the already-held magazine is thrown.
	weapon.ammo = 0
	weapon.try_reload()
	_check("held magazine can be thrown during another reload", weapon.is_reloading() and traits.try_throw_reload_charge())
	_check("one launch consumes the sole inventory and repeated throws fail", thrown.size() == 1 and not traits.has_reload_charge() and not traits.try_throw_reload_charge())
	if not thrown.is_empty():
		var charge := thrown.back() as ReloadCharge
		_check("the throw reads current stacked damage", charge.damage == 240.0)
		_check("fuse starts at release", is_equal_approx(charge.fuse_remaining, ReloadCharge.FUSE_TIME))
		charge.queue_free()
	_finish_reload(weapon)
	traits.clear()
	weapon.ammo = 0
	weapon.reserve = 0
	weapon.try_reload()
	_check("no-reserve reload cannot create a magazine", not weapon.is_reloading() and not traits.has_reload_charge())
	weapon.reserve = 100
	weapon.try_reload()
	traits.clear()
	_finish_reload(weapon)
	_check("clearing cancels an unfinished reload candidate", not traits.has_reload_charge())
	weapon.ammo = 0
	weapon.try_reload()
	_finish_reload(weapon)
	_check("a fresh completed reload can store another charge", traits.has_reload_charge())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _key(KEY_C)
		_check("C outside captured gameplay does not throw", traits.has_reload_charge() and thrown.size() == 1)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await _key(KEY_C)
		_check("physical C input throws exactly one held magazine", not traits.has_reload_charge() and thrown.size() == 2)
		for charge in thrown:
			if is_instance_valid(charge):
				charge.queue_free()
		weapon.ammo = 0
		weapon.try_reload()
		_finish_reload(weapon)
	player.health.health = 0.0
	player.health.died.emit(null)
	_check("death discards the held magazine and denies throwing", not traits.has_reload_charge() and not traits.try_throw_reload_charge() and not held.visible)
	player.queue_free()
	await get_tree().process_frame
	await _flight_checks(arena)
	await _shield_checks(arena)
	arena.queue_free()
	await get_tree().create_timer(0.25).timeout


func _finish_reload(weapon: Weapon) -> void:
	_check("fixture is finishing a real accepted reload", weapon.is_reloading())
	weapon._process(weapon._reload_left + 0.001)


func _flight_checks(arena: Node3D) -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = CollisionLayers.WORLD
	ground.position = Vector3(50, -0.5, -20)
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 70)
	ground_shape.shape = box
	ground.add_child(ground_shape)
	arena.add_child(ground)
	await _sync()
	var launch := Vector3(50, 1.6, 0)
	var charge := ReloadCharge.spawn(arena, launch, Vector3.FORWARD, null, 120.0) as ReloadCharge
	var result := {"count": 0, "point": launch}
	charge.exploded.connect(func(point: Vector3, _effect: Node3D):
		result["count"] += 1
		result["point"] = point
	)
	await get_tree().create_timer(0.8).timeout
	_check("horizontal throw remains live after travelling at least 18 metres", is_instance_valid(charge) and charge.global_position.z <= -18.0 and result["count"] == 0)
	await get_tree().create_timer(0.6).timeout
	var distance := launch.distance_to(result["point"] as Vector3)
	_check("flat-ground throw impacts once more than 20 metres away", result["count"] == 1 and distance > 20.0)
	print("THROW DISTANCE %.2f m" % distance)


func _shield_checks(arena: Node3D) -> void:
	var player: Player = load("res://actors/player/player.tscn").instantiate()
	arena.add_child(player)
	player.position = Vector3(100, 0, 0)
	player.set_process(false)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	player.shield.set_process(false)
	var source := Source.new()
	arena.add_child(source)
	var inside := _target(arena, Vector3(106, 1, 0))
	var edge := _target(arena, Vector3(107, 1, 0))
	var outside := _target(arena, Vector3(107.2, 1, 0))
	var hidden := _target(arena, Vector3(100, 1, -6))
	var wall := StaticBody3D.new()
	wall.position = Vector3(100, 1, -3)
	wall.collision_layer = CollisionLayers.WORLD
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.2)
	collision.shape = box
	wall.add_child(collision)
	arena.add_child(wall)
	await _sync()
	player.stats.apply_buff(BuffPool.ALL[6])
	var pulses := [0]
	player.combat_traits.shield_pulsed.connect(func(): pulses[0] += 1)
	player.shield.try_activate()
	player.shield._process(player.shield.active_remaining + 0.01)
	_check("no absorbed attack still means no free counterattack", pulses[0] == 0 and inside.health == 1000.0)
	player.shield._process(player.shield.cooldown_remaining + 0.01)
	player.shield.try_activate()
	player.health.apply_damage(20.0, Hitbox.BodyPart.BODY, source)
	player.health.apply_damage(20.0, Hitbox.BodyPart.BODY, source)
	player.shield._process(player.shield.active_remaining + 0.01)
	player.shield._process(0.1)
	_check("counter reaches a multi-hitbox enemy at 6m once for 25 BODY damage", inside.health == 975.0 and pulses[0] == 1)
	_check("7m boundary receives unchanged uniform damage", edge.health == 975.0)
	_check("hitbox overlap past 7m receives no damage", outside.health == 1000.0)
	_check("a wall still blocks the larger pulse", hidden.health == 1000.0)
	player.queue_free()
	await get_tree().process_frame


func _target(parent: Node3D, point: Vector3) -> Health:
	var actor := Node3D.new()
	actor.position = point
	var health := Health.new()
	health.max_health = 1000.0
	actor.add_child(health)
	for index in 2:
		var hitbox := Hitbox.new()
		hitbox.body_part = Hitbox.BodyPart.BODY if index == 0 else Hitbox.BodyPart.HEAD
		hitbox.position.y = float(index) * 0.6
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.25
		collision.shape = sphere
		hitbox.add_child(collision)
		actor.add_child(hitbox)
	parent.add_child(actor)
	return health


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in 2:
		await get_tree().process_frame
	event = InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _sync() -> void:
	for frame in 3:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
