extends Node
var checks := 0
var failures := 0
var finished := false
var arena: Node3D
var player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	get_tree().paused = false
	arena.queue_free()
	await get_tree().process_frame
	print("CLOAK DEFENSE: %d checks, %d failed, finished=%s" % [checks, failures, finished])
	get_tree().quit(0 if failures == 0 and finished else 1)


func _run() -> void:
	arena = Node3D.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	var ground := StaticBody3D.new()
	ground.collision_layer = CollisionLayers.WORLD
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60,1,60)
	collider.shape = shape
	ground.position.y = -0.5
	ground.add_child(collider)
	arena.add_child(ground)
	player = load("res://actors/player/player.tscn").instantiate() as Player
	arena.add_child(player)
	player.position = Vector3(0,0,-6)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var enemy := _enemy(0)
	enemy.evade_chance = 1.0
	enemy.health.health = 20.0
	await _frames(3)
	var confirmed: Array[bool] = []
	player.weapon.hit_landed.connect(func(_head: bool, _kill: bool): confirmed.append(true))
	player.weapon._shoot_ray(Vector3(0,1.78,-3), Vector3.BACK)
	_check("a closed cloak can evade a real lethal headshot", enemy.health.health == 20.0 and enemy.evade_count == 1)
	_check("evading does not falsely confirm damage or overwrite the final hit", confirmed.is_empty() and enemy.last_hit_point == Vector3.INF)
	_check("evasion has visible feedback and no death burst", enemy.visual._evade_left > 0.0 and enemy.visual.shatter == null)
	player.weapon._shoot_ray(Vector3(0,1.78,-3), Vector3.BACK)
	_check("the next bullet during cooldown lands and kills", enemy.health.is_dead() and confirmed.size() == 1)
	_check("the real lethal contact still drives shattering", is_instance_valid(enemy.visual.shatter)
		and enemy.visual.shatter.first_part == "head" and absf(enemy.last_hit_point.y - 1.78) < 0.001)
	enemy.queue_free()
	await _frames(2)
	enemy = _enemy(0)
	enemy.evade_chance = 1.0
	var health := enemy.health.health
	enemy.set_core_exposed(true)
	_check("opening the cloak disables its dodge", _contact(enemy, 10.0) == 10.0 and enemy.evade_count == 0)
	enemy.set_core_exposed(false)
	enemy.cloak_recover_left = 1.0
	_check("the recovery window also guarantees normal damage", _contact(enemy, 10.0) == 10.0)
	enemy.cloak_recover_left = 0.0
	var torso := enemy.get_node("TorsoHitbox") as Hitbox
	_check("melee contact cannot be dodged", torso.apply_hit_at(10.0, player, torso.global_position, Vector3.BACK) == 10.0)
	_check("area damage cannot be dodged", enemy.health.apply_damage(10.0, Hitbox.BodyPart.BODY, player) == 10.0)
	_check("all four bypass hits actually reduced health", enemy.health.health == health - 40.0)
	var ally := _enemy(1)
	ally.position.x = 15.0
	seed(781)
	var expected := randf()
	seed(781)
	_check("friendly fire is ignored without consuming the passive", torso.apply_hit_at(10.0, ally, torso.global_position, Vector3.BACK, true) == 0.0
		and enemy.evade_count == 0 and randf() == expected)
	enemy.health.invulnerable = true
	_check("existing immunity does not consume dodge cooldown", _contact(enemy, 10.0) == 0.0 and enemy.evade_count == 0)
	enemy.health.invulnerable = false
	_check("a real dodge starts cooldown", _contact(enemy, 1.0) == 0.0 and enemy.evade_cooldown_left > 2.4)
	for i in 8:
		_contact(enemy, 1.0)
	_check("a shotgun-like burst loses only one pellet", enemy.evade_count == 1 and enemy.health.health == health - 48.0)
	enemy.set_physics_process(true)
	await _frames(60)
	var before := enemy.evade_cooldown_left
	get_tree().paused = true
	await _frames(40)
	_check("cooldown freezes during pause", enemy.evade_cooldown_left == before)
	get_tree().paused = false
	await _frames(100)
	enemy.set_physics_process(false)
	_check("cooldown returns after simulation time", enemy.evade_cooldown_left == 0.0 and _contact(enemy, 1.0) == 0.0 and enemy.evade_count == 2)
	enemy.evade_cooldown_left = 0.0
	enemy.evade_chance = 0.0
	_check("zero probability always allows the bullet", _contact(enemy, 1.0) == 1.0)
	for kind in [1,2]:
		var other := _enemy(kind)
		other.evade_chance = 1.0
		_check("other enemy types do not inherit evasion (%d)" % kind, _contact(other, 1.0) == 1.0 and other.evade_count == 0)
		other.queue_free()
	enemy.evade_chance = 0.30
	enemy.health.health = 10000.0
	seed(581)
	var dodged := 0
	for i in 1000:
		enemy.evade_cooldown_left = 0.0
		if _contact(enemy, 1.0) == 0.0:
			dodged += 1
	print("  independent eligible contacts: %d/1000 evaded" % dodged)
	_check("the default probability produces both hits and dodges", dodged > 230 and dodged < 370)
	var first := _sequence(enemy, 875)
	_check("the same gameplay seed repeats the dodge sequence", first == _sequence(enemy, 875))
	await _frames(125)
	finished = true


func _sequence(enemy: SlothEnemy, seed_value: int) -> String:
	seed(seed_value)
	var result := ""
	for i in 64:
		enemy.evade_cooldown_left = 0.0
		result += "D" if _contact(enemy, 1.0) == 0.0 else "H"
	return result


func _contact(enemy: SlothEnemy, amount: float) -> float:
	var hitbox := enemy.get_node("TorsoHitbox") as Hitbox
	return hitbox.apply_hit_at(amount, player, hitbox.global_position, Vector3.BACK, true)


func _enemy(kind: int) -> SlothEnemy:
	var enemy := load("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
	enemy.kind = kind
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
