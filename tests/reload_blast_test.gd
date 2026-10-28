extends Node
## Exercises the real physics query, projectile travel and reload event path.

var _failures := 0
var _checks := 0


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("RELOAD BLAST: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var arena := Node3D.new()
	add_child(arena)
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	arena.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	player.shield.set_process(false)
	var near := _target(arena, Vector3(0.5, 1, 0), 1)
	var middle := _target(arena, Vector3(2.25, 1, 0), 1)
	var edge := _target(arena, Vector3(3.5, 1, 0), 1)
	var outside := _target(arena, Vector3(3.65, 1, 0), 1)
	var ally := _target(arena, Vector3(-1, 1, 0), 0)
	var hidden := _target(arena, Vector3(0, 1, -3), 1)
	_wall(arena, Vector3(0, 1, -1.5), Vector3(1.5, 3, 0.2))
	await _sync()
	var effect := ReloadCharge.blast(arena, Vector3(0, 1, 0), player, 120, 3.5, ReloadCharge.ACCENT, true)
	_check("inner 1m deals exactly 120 once across two hitboxes", is_equal_approx(near.health, 880))
	_check("2.25m deals 90", is_equal_approx(middle.health, 910))
	_check("3.5m edge deals 60", is_equal_approx(edge.health, 940))
	_check("overlapping shape with centre beyond 3.5m is unharmed", outside.health == 1000)
	_check("solid wall blocks both enemy hitboxes", hidden.health == 1000)
	_check("ally and player are unharmed", ally.health == 1000 and player.health.health == 100)
	_check("three unique enemies were damaged", effect.get_meta("targets_hit") == 3)
	_check("explosion has hot core and pressure ring", effect.has_node("FireFlash") and effect.has_node("PressureRing"))
	_check("explosion has smoke sparks and a brief light", effect.has_node("Smoke2") and effect.has_node("Spark11") and effect.has_node("FlashLight"))
	var first_near := near.health
	var first_middle := middle.health
	var first_edge := edge.health
	ReloadCharge.blast(arena, Vector3(0, 1, 0), player, 240, 3.5, ReloadCharge.ACCENT, true)
	_check("second layer doubles inner damage", is_equal_approx(first_near - near.health, 240))
	_check("second layer doubles middle damage", is_equal_approx(first_middle - middle.health, 180))
	_check("second layer doubles edge damage", is_equal_approx(first_edge - edge.health, 120))
	first_middle = middle.health
	first_edge = edge.health
	var pulse := ReloadCharge.blast(arena, Vector3(0, 1, 0), player, 25, 3.5, Color("30d4ee"))
	_check("shield pulse retains uniform 25 damage", is_equal_approx(first_middle - middle.health, 25) and is_equal_approx(first_edge - edge.health, 25))
	_check("shield pulse keeps its own visual", not pulse.has_node("FireFlash"))
	await get_tree().create_timer(0.9).timeout
	_check("explosion and pulse recycle themselves", not is_instance_valid(effect) and not is_instance_valid(pulse))
	# At this angle a short head-only wall hides the closer head, but the
	# exposed torso still receives damage. Head/body order cannot suppress it.
	var partial := _target(arena, Vector3(10, 1, -2), 1)
	_wall(arena, Vector3(10, 1.3, -1), Vector3(1, 0.18, 0.15))
	await _sync()
	var sight := PhysicsRayQueryParameters3D.create(Vector3(10, 1, 0), Vector3(10, 1.6, -2), CollisionLayers.WORLD)
	_check("partial-cover fixture really blocks the head ray", not arena.get_world_3d().direct_space_state.intersect_ray(sight).is_empty())
	ReloadCharge.blast(arena, Vector3(10, 1, 0), player, 60, 3.5, ReloadCharge.ACCENT, true)
	_check("covered head does not suppress visible torso", is_equal_approx(partial.health, 952))
	# At the faster launch speed the arc crosses this target near y=1.3.
	var collision_target := _target(arena, Vector3(20, 1.3, -2.5), 1)
	await _sync()
	var charge := ReloadCharge.spawn(arena, Vector3(20, 1, 0), Vector3.FORWARD, player, 60) as ReloadCharge
	var detonation := {"count": 0, "position": Vector3.ZERO}
	charge.exploded.connect(func(point: Vector3, _effect: Node3D):
		detonation["count"] += 1
		detonation["position"] = point
	)
	await get_tree().create_timer(0.36).timeout
	_check("flying magazine detonates on enemy before fuse expires", detonation["count"] == 1 and (detonation["position"] as Vector3).z > -2.6)
	_check("enemy collision deals full core damage", is_equal_approx(collision_target.health, 940))
	var behind_wall := _target(arena, Vector3(30, 1, -2.0), 1)
	_wall(arena, Vector3(30, 1, -1.2), Vector3(3, 3, 0.2))
	await _sync()
	var wall_charge := ReloadCharge.spawn(arena, Vector3(30, 1, 0), Vector3.FORWARD, player, 60) as ReloadCharge
	var wall_explosions := [0]
	wall_charge.exploded.connect(func(_point: Vector3, _effect: Node3D): wall_explosions[0] += 1)
	await get_tree().create_timer(0.25).timeout
	_check("flying magazine explodes once on world geometry", wall_explosions[0] == 1)
	_check("wall impact cannot damage enemy behind that wall", behind_wall.health == 1000)
	player.position = Vector3(40, 0, 0)
	_wall(arena, Vector3(40, 1.5, -0.2), Vector3(3, 3, 0.1))
	player.stats.apply_buff(BuffPool.ALL[0])
	var thrown: Array[Node3D] = []
	player.combat_traits.reload_charge_thrown.connect(func(value: Node3D): thrown.append(value))
	await _sync()
	player.weapon.ammo = 0
	player.weapon.try_reload()
	player.weapon.try_reload()
	_check("empty reload creates no flight before completion", thrown.is_empty())
	player.weapon._finish_reload()
	_check("completed reload stores one charge", player.combat_traits.has_reload_charge() and thrown.is_empty())
	_check("active input launches one charge", player.combat_traits.try_throw_reload_charge() and thrown.size() == 1)
	if not thrown.is_empty():
		var close_charge := thrown[0] as ReloadCharge
		_check("close wall keeps magazine on player's side", close_charge.global_position.z > -0.15)
		var exploded_effect := close_charge.detonate()
		_check("manual detonation cannot repeat", close_charge.detonate() == null and exploded_effect != null)
	player.weapon._reload_left = 0
	player.weapon.ammo = 1
	player.weapon.try_reload()
	_check("tactical reload produces no extra charge", thrown.size() == 1)
	player.position = Vector3(50, 0, 0)
	await _sync()
	var free_charge := ReloadCharge.spawn(arena, Vector3(50, 1.6, -0.05), Vector3.FORWARD, player, 60) as ReloadCharge
	var fuse_explosions := [0]
	free_charge.exploded.connect(func(_point: Vector3, _effect: Node3D): fuse_explosions[0] += 1)
	await get_tree().create_timer(0.12).timeout
	_check("magazine exits shooter hitbox without detonating on self", is_instance_valid(free_charge) and fuse_explosions[0] == 0)
	await get_tree().create_timer(ReloadCharge.FUSE_TIME).timeout
	_check("unobstructed flight detonates once on fuse", fuse_explosions[0] == 1)
	await get_tree().create_timer(0.95).timeout
	arena.queue_free()
	await get_tree().create_timer(0.2).timeout


func _target(parent: Node3D, point: Vector3, team: int) -> Health:
	var actor := Node3D.new()
	actor.position = point
	var health := Health.new()
	health.max_health = 1000
	health.team = team
	actor.add_child(health)
	for index in 2:
		var hitbox := Hitbox.new()
		hitbox.body_part = Hitbox.BodyPart.BODY if index == 0 else Hitbox.BodyPart.HEAD
		hitbox.position.y = index * 0.6
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.2
		collision.shape = sphere
		hitbox.add_child(collision)
		actor.add_child(hitbox)
	parent.add_child(actor)
	return health


func _wall(parent: Node3D, point: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	wall.position = point
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	wall.add_child(collision)
	parent.add_child(wall)


func _sync() -> void:
	for frame_index in 3:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
