extends Node
## Headless check of the faster enemy bullets:
##   godot --headless --path . res://tests/enemy_bullet_test.tscn
## Speed, the speed-scaled tracer, and the ray sweep that still stops a fast
## bullet at a thin wall.

var _failures := 0


func _ready() -> void:
	await _run()
	print("ENEMY BULLETS: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var enemy := load("res://actors/enemy/enemy.tscn").instantiate() as Enemy
	_check("enemy bullets default to 22 m/s", is_equal_approx(enemy.projectile_speed, 22.0))
	enemy.free()
	var idle := Projectile.new()
	_check("the projectile class default stays 30 m/s (enemies pass their own)", is_equal_approx(idle.speed, 30.0))
	idle.free()

	var arena := Node3D.new()
	add_child(arena)
	var fast := Projectile.spawn(arena, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, null, 10.0, 30.0, [])
	var slow := Projectile.spawn(arena, Vector3(10.0, 1.0, 0.0), Vector3.FORWARD, null, 10.0, 10.0, [])
	_check("a 30 m/s tracer is %.2f m long" % fast.tracer_length(),
		is_equal_approx(fast.tracer_length(), 30.0 * Projectile.TRACER_SECONDS))
	_check("a slow projectile keeps the %.1f m minimum" % Projectile.TRACER_MIN_LENGTH,
		is_equal_approx(slow.tracer_length(), Projectile.TRACER_MIN_LENGTH))
	_check("the tracer grows with speed", fast.tracer_length() > slow.tracer_length())
	fast.free()
	slow.free()

	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	wall.position = Vector3(0.0, 1.0, -2.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.2)
	shape.shape = box
	wall.add_child(shape)
	arena.add_child(wall)
	await get_tree().physics_frame
	var bullet := Projectile.spawn(arena, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, null, 10.0, 30.0, [])
	for i in 12:
		await get_tree().physics_frame
		if not is_instance_valid(bullet):
			break
	_check("30 m/s does not tunnel through a 0.2 m wall", not is_instance_valid(bullet))
	arena.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
