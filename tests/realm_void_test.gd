extends Node
## 四个领域都要有同一套坠落边界：
## 玩家掉出去扣固定的 30 点生命并回到稳定地面，敌人掉出去直接死亡。

var checks := 0
var failures := 0


class Target extends CharacterBody3D:
	var hits := 0

	func apply_impact(_direction: Vector3, _force: float, _stagger: float) -> void:
		hits += 1


func _ready() -> void:
	for realm_name in ["sloth", "fear", "wrath", "sorrow"]:
		await _check_realm(realm_name)
	print("REALM VOID: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _check_realm(realm_name: String) -> void:
	var realm: Node3D = load("res://environments/%s/realm.gd" % realm_name).new()
	add_child(realm)
	await _frames(3)
	_check(realm.get("void_fall") != null, realm_name + ": the room installs a fall boundary")

	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	player.position = Vector3(0, 1.2, 16)
	add_child(player)
	await _frames(2)
	player.set_physics_process(false)
	realm.call("set_player", player)
	await _frames(2)

	# 敌人掉进虚空：直接死亡，不走护盾也不留残血。
	var target := Target.new()
	var enemy_health := Health.new()
	enemy_health.name = "Health"
	enemy_health.max_health = 100.0
	target.add_child(enemy_health)
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	body_shape.shape = capsule
	target.add_child(body_shape)
	target.collision_layer = CollisionLayers.ENEMIES
	target.collision_mask = 0
	add_child(target)
	target.global_position = Vector3(5, -15, 5)
	await _frames(4)
	_check(enemy_health.is_dead(), realm_name + ": an enemy falling into the void dies outright")

	# 玩家掉进虚空：扣 30 点，回到稳定地面，不死。
	var before := player.health.health
	player.global_position = Vector3(0, -13, 0)
	await _frames(5)
	_check(is_equal_approx(player.health.health, before - 30.0),
		realm_name + ": the player loses exactly 30 HP")
	_check(not player.health.is_dead(), realm_name + ": 30 damage does not kill a full-health player")
	_check(player.global_position.y > -1.0, realm_name + ": the player is returned to solid ground")

	# 第二次坠落继续扣 30，说明它可重复触发而不是一次性。
	# 先等过 0.3 秒的防连触发冷却。
	await _frames(24)
	player.global_position = Vector3(0, -13, 0)
	await _frames(5)
	_check(is_equal_approx(player.health.health, before - 60.0),
		realm_name + ": a second fall costs another 30 HP")

	player.queue_free()
	target.queue_free()
	realm.queue_free()
	await _frames(3)


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(("[ok] " if passed else "[FAIL] ") + label)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
