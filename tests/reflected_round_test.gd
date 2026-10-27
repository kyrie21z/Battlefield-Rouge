extends Node
## Collected rounds obey cover even when their visible launch offset crosses it.

var _failures := 0


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("REFLECTED ROUND: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var arena := Node3D.new()
	add_child(arena)
	var player: Player = load("res://actors/player/player.tscn").instantiate()
	arena.add_child(player)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	player.shield.set_process(false)
	player.stats.apply_buff(load("res://buffs/blade_damage.tres"))
	# Isolate the additional projectile from the ordinary hitscan damage.
	player.weapon.data = player.weapon.data.duplicate() as WeaponData
	player.weapon.data.max_range = 0.05
	var target := Node3D.new()
	target.position = Vector3(0, 1.6, -1.5)
	var health := Health.new()
	health.max_health = 1000.0
	target.add_child(health)
	var hitbox := Hitbox.new()
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	collision.shape = sphere
	hitbox.add_child(collision)
	target.add_child(hitbox)
	arena.add_child(target)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	# The player capsule can stand against this near face at z=-0.35.
	# A fixed 0.4 m launch offset would put the projectile behind the wall.
	wall.position = Vector3(0, 1.6, -0.37)
	var wall_collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.04)
	wall_collision.shape = box
	wall.add_child(wall_collision)
	arena.add_child(wall)
	for index in 3:
		await get_tree().physics_frame
	var released := [0]
	player.combat_traits.rounds_released.connect(func(count: int): released[0] += count)
	player.combat_traits.stored_rounds = 1
	_check("shot with stored round is accepted", player.weapon.try_fire())
	for index in 6:
		await get_tree().physics_frame
	_check("blocked shot consumes and releases its stored round",
		released[0] == 1 and player.combat_traits.stored_rounds == 0)
	_check("nearby thin wall blocks the collected round", is_equal_approx(health.health, 1000.0))
	wall.queue_free()
	for index in 3:
		await get_tree().physics_frame
	player.weapon._cooldown = 0.0
	player.combat_traits.stored_rounds = 1
	_check("unobstructed shot is accepted", player.weapon.try_fire())
	for index in 6:
		await get_tree().physics_frame
	var expected := CombatTraits.COLLECTED_ROUND_DAMAGE * player.stats.get_value(Stats.MELEE_DAMAGE)
	_check("unobstructed collected round keeps its damage",
		is_equal_approx(1000.0 - health.health, expected) and released[0] == 2)
	_check("collected rounds do not damage their owner", is_equal_approx(player.health.health, 100.0))
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
