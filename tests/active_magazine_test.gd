extends Node
## Immediate last-shot storage, active throwing, projectile travel and shield range.

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
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	var stored: Array[Dictionary] = []
	traits.reload_charge_thrown.connect(func(charge: Node3D): thrown.append(charge))
	traits.reload_charge_stored.connect(func():
		stored.append({"frame": Engine.get_process_frames(), "ammo": weapon.ammo,
			"reloading": weapon.is_reloading()})
	)
	_check("no charge can be thrown before the buff", not traits.try_throw_reload_charge())
	weapon.ammo = 1
	weapon.reserve = 0
	_check("ordinary last shot fires without the perk", weapon.try_fire())
	_check("last shot without perk cannot store a charge", not traits.has_reload_charge() and stored.is_empty())
	weapon.reserve = 100
	weapon.try_reload()
	_finish_reload(weapon)
	_check("ordinary empty reload cannot grant a charge", not traits.has_reload_charge())
	player.stats.apply_buff(BuffPool.ALL[0])
	_check("first stack has 120 explosive damage", player.stats.get_value(Stats.RELOAD_BLAST_DAMAGE) == 120.0)
	weapon.ammo = 1
	weapon.try_reload()
	_finish_reload(weapon)
	_check("completed tactical reload cannot store a charge", not traits.has_reload_charge())
	weapon.ammo = 0
	weapon.try_reload()
	weapon.try_reload()
	_check("starting and repeating R on empty cannot grant a charge", not traits.has_reload_charge())
	weapon.select_next()
	weapon._finish_reload()
	_check("cancelled or completed empty reload cannot grant a charge", not traits.has_reload_charge())
	weapon.select(0)
	weapon.ammo = 2
	weapon.reserve = 100
	weapon._cooldown = 0.0
	_check("penultimate shot fires", weapon.try_fire())
	_check("penultimate shot does not grant a charge", not traits.has_reload_charge())
	weapon._cooldown = 0.0
	var final_shot_frame := Engine.get_process_frames()
	_check("final shot fires", weapon.try_fire())
	var snapshot: Dictionary = stored.back() if not stored.is_empty() else {}
	_check("last round stores one charge in the same frame", traits.has_reload_charge()
		and stored.size() == 1 and snapshot.get("frame", -1) == final_shot_frame)
	_check("storage precedes automatic reload", snapshot.get("ammo", -1) == 0
		and not snapshot.get("reloading", true) and weapon.is_reloading())
	_check("storage does not automatically throw or explode", thrown.is_empty())
	var held := player.get_node("Head/Camera3D/HeldReloadCharge") as Node3D
	_check("stored magazine is immediately visible", held.visible)
	_check("can throw immediately while the original reload runs", traits.try_throw_reload_charge()
		and weapon.is_reloading() and thrown.size() == 1)
	if not thrown.is_empty():
		var first_charge := thrown[0] as ReloadCharge
		_check("throw uses 6m radius", first_charge.radius == 6.0)
		_check("fuse starts at release", is_equal_approx(first_charge.fuse_remaining, ReloadCharge.FUSE_TIME))
		first_charge.queue_free()
	_finish_reload(weapon)
	_check("finishing the original reload cannot refill spent charge", not traits.has_reload_charge() and stored.size() == 1)
	weapon.ammo = 1
	weapon._cooldown = 0.0
	weapon.try_fire()
	_check("a later final shot stores a fresh charge", traits.has_reload_charge() and stored.size() == 2)
	weapon.select(2)
	_check("switching guns and cancelling reload preserve inventory", traits.has_reload_charge())
	weapon.aiming = true
	traits._process(0.0)
	_check("scope hides held model without spending inventory", not held.visible and traits.has_reload_charge())
	weapon.aiming = false
	traits._process(0.0)
	_check("leaving scope restores held model", held.visible)
	await get_tree().create_timer(ReloadCharge.FUSE_TIME + 0.2).timeout
	_check("holding past fuse time neither throws nor explodes", traits.has_reload_charge() and thrown.size() == 1)
	weapon.ammo = 1
	weapon.reserve = 100
	weapon.try_fire()
	_check("another final shot does not duplicate or replace held inventory", traits.has_reload_charge() and stored.size() == 2)
	_finish_reload(weapon)
	_check("another completed reload cannot duplicate inventory", traits.has_reload_charge() and stored.size() == 2)
	get_tree().paused = true
	_check("public throw path cannot spend inventory while paused", not traits.try_throw_reload_charge() and traits.has_reload_charge())
	get_tree().paused = false
	traits.clear()
	# Each gun must store once on its real final shot even with no reserve.
	# Shotgun pellets share one fired signal and cannot produce extra inventory.
	for slot in weapon.data_set.size():
		weapon.select(slot)
		weapon.ammo = 1
		weapon.reserve = 0
		var stores_before := stored.size()
		_check("gun %d final shot fires without reserve" % slot, weapon.try_fire())
		_check("gun %d immediately stores exactly one charge" % slot,
			traits.has_reload_charge() and stored.size() == stores_before + 1 and not weapon.is_reloading())
		weapon._cooldown = 0.0
		_check("gun %d dry fire cannot grant another charge" % slot,
			not weapon.try_fire() and stored.size() == stores_before + 1)
		traits.clear()
		weapon.try_reload()
		_check("gun %d empty reload without reserve grants nothing" % slot,
			not weapon.is_reloading() and not traits.has_reload_charge())
		weapon.select(slot)
		player.stats.changed.emit()
		_check("gun %d empty selection and Stats refresh grant nothing" % slot, not traits.has_reload_charge())
	weapon.select(0)
	weapon.ammo = 1
	weapon.reserve = 100
	weapon.try_fire()
	player.stats.apply_buff(BuffPool.ALL[0])
	_check("held charge can be thrown while another reload runs", weapon.is_reloading() and traits.try_throw_reload_charge())
	_check("one launch consumes the sole inventory", thrown.size() == 2 and not traits.has_reload_charge() and not traits.try_throw_reload_charge())
	if thrown.size() == 2:
		var charge := thrown.back() as ReloadCharge
		_check("throw samples current stacked damage", charge.damage == 240.0)
		charge.queue_free()
	_finish_reload(weapon)
	_check("reload completion after throwing grants nothing", not traits.has_reload_charge())
	get_tree().paused = true
	weapon.ammo = 1
	weapon._cooldown = 0.0
	weapon.try_fire()
	_check("paused final-shot calls cannot grant inventory", not traits.has_reload_charge())
	get_tree().paused = false
	weapon.select(0)
	weapon.ammo = 1
	weapon.try_fire()
	_check("fresh last shot restores an inventory for input checks", traits.has_reload_charge())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _key(KEY_C)
		_check("C outside captured gameplay cannot throw", traits.has_reload_charge() and thrown.size() == 2)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await _key(KEY_C)
		_check("physical C throws exactly one stored magazine", not traits.has_reload_charge() and thrown.size() == 3)
		if thrown.size() == 3:
			thrown.back().queue_free()
		weapon.select(0)
		weapon.ammo = 1
		weapon.try_fire()
	player.health.health = 0.0
	player.health.died.emit(null)
	_check("death discards held magazine and denies throwing", not traits.has_reload_charge() and not traits.try_throw_reload_charge() and not held.visible)
	weapon._reload_left = 0.0
	weapon._cooldown = 0.0
	weapon.ammo = 1
	weapon.try_fire()
	_check("dead final-shot calls cannot restore inventory", not traits.has_reload_charge())
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
	player.shield._process(3.0)
	_check("no absorbed attack still means no free counterattack", pulses[0] == 0 and inside.health == 1000.0)
	player.shield.try_release()
	player.shield._process(player.shield.cooldown_remaining + 0.01)
	player.shield.try_activate()
	player.health.apply_damage(20.0, Hitbox.BodyPart.BODY, source)
	player.health.apply_damage(20.0, Hitbox.BodyPart.BODY, source)
	player.shield.try_release()
	player.shield._process(0.1)
	_check("counter reaches a multi-hitbox enemy at 6m once for forty absorbed BODY damage", inside.health == 960.0 and pulses[0] == 1)
	_check("7m boundary receives unchanged uniform damage", edge.health == 960.0)
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
