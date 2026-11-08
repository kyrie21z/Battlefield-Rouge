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
	print("NAVY REVISION: %d checks, %d failed" % [checks, failures])
	get_tree().quit(0 if failures == 0 and finished else 1)


func _run() -> void:
	arena = Node3D.new()
	add_child(arena)
	player = load("res://actors/player/player.tscn").instantiate() as Player
	arena.add_child(player)
	player.position = Vector3(0,0,-5)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for part in ["head", "leg"]:
		var enemy := _enemy(0)
		enemy.health.health = 20.0
		await _frames(3)
		var color: Color = enemy.visual.crystal_material().get_shader_parameter("base_color")
		_check("body is navy and original material stays red", color.b > color.r * 2.0
			and (SlothVisual.CRYSTAL.get_shader_parameter("base_color") as Color).r > 0.5)
		var height := 1.78 if part == "head" else 0.5
		player.weapon._shoot_ray(Vector3(0,height,-3), Vector3.BACK)
		_check("real weapon kills at " + part, enemy.health.is_dead())
		var shatter := enemy.visual.shatter
		_check("exact final ray contact retained", absf(enemy.last_hit_point.y - height) < 0.001
			and enemy.last_hit_point.z < 0.0)
		_check("death immediately hides body and clothing", not enemy.visual.model.visible
			and not enemy.visual._outfit.visible)
		_check("death never plays a fall animation", enemy.visual.animation.current_animation != "death")
		_check("all 56 authored shards are retained", is_instance_valid(shatter) and shatter.fragments.size() == 56)
		_check("fracture starts at the contacted body part " + shatter.first_part,
			shatter.first_part == "head" if part == "head" else shatter.first_part in ["shin_L","shin_R","thigh_L","thigh_R"])
		var first_distance := INF
		var later_distance := 0.0
		for fragment in shatter.fragments:
			if fragment["released"]:
				first_distance = minf(first_distance, fragment["distance"])
			else:
				later_distance = maxf(later_distance, fragment["distance"])
		_check("contact fragments break before distant fragments", first_distance < later_distance)
		get_tree().paused = true
		var elapsed := shatter.elapsed
		await _frames(10)
		_check("shards pause with combat", shatter.elapsed == elapsed)
		get_tree().paused = false
		await _frames(125)
		_check("shards clean up without a corpse", not is_instance_valid(shatter))
		enemy.queue_free()
	var cloak := _enemy(0)
	cloak.setup(player, [])
	cloak.cast_attack()
	await _frames(88)
	_check("cloak opens during its delayed throw", cloak.visual._mantle_open > 0.25)
	_check("opening the cloak exposes its hourglass chest weak point", cloak.get_node("CoreHitbox").collision_layer == CollisionLayers.HITBOXES)
	_check("cloak cast uses four suspended shots with short tell marks", cloak.active_attack._orbs.size() == 4
		and cloak.active_attack._fins.size() == 8 and cloak.active_attack._graphics.get_child_count() == 12)
	cloak.apply_impact(Vector3.RIGHT, 1.0, 0.1)
	_check("melee breaks the cloak's windup", not is_instance_valid(cloak.active_attack))
	_check("interrupting the cloak grants a one-second weak-point window", cloak.cloak_recover_left == 1.0)
	cloak.queue_free()
	var anchor := _enemy(1)
	anchor.setup(player, [])
	anchor.cast_attack()
	var flat := true
	for child in anchor.active_attack._graphics.get_children():
		flat = flat and absf((child as Node3D).global_position.y - player.global_position.y) < 0.15
	_check("field markings lie on the floor, not a raised crown", flat)
	anchor.queue_free()
	await _frames(3)
	var sample := _enemy(2)
	seed(1329)
	var expected := randi()
	seed(1329)
	sample.visual.die(sample.global_position + Vector3.UP, Vector3.BACK)
	_check("shattering does not consume gameplay random numbers", randi() == expected)
	await _frames(125)
	finished = true


func _enemy(kind: int) -> SlothEnemy:
	var enemy := load("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
	enemy.kind = kind
	enemy.evade_chance = 0.0
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
