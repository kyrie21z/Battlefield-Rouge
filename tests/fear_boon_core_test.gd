extends Node3D
## Behavioral checks use the real manager, Health, facets and swept Projectile.

class Actor extends CharacterBody3D:
	var team := 1
	var target: CharacterBody3D
	var boon_movement_scale := 1.0
	var boon_time_scale := 1.0
	var boon_stunned := false

var _failed := 0
var _finished := false
var _manager: BoonManager
var _source: Actor
var _effect: FearEffect


func _ready() -> void:
	await _run()
	var ok := _failed == 0 and _finished
	print("%s (%d failed, finished=%s)" % ["ALL PASSED" if ok else "FAIL", _failed, _finished])
	_manager.clear()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_source = _actor(Vector3.ZERO, 0)
	var stats := Stats.new()
	_source.add_child(stats)
	_manager = BoonManager.new()
	_manager.player = _source
	_manager.stats = stats
	_manager.health = _source.get_node("Health")
	_source.add_child(_manager)
	_manager.equip(load("res://buffs/resources/fear/gaze_pierce.tres"))
	_manager.equip(load("res://buffs/resources/fear/flash_backstab.tres"))
	_manager.equip(load("res://buffs/resources/fear/tremor_decoy.tres"))
	_effect = _manager.effect_for(preload("res://buffs/effects/fear_effect.gd")) as FearEffect
	var enemy := _actor(Vector3(0, 0, -5))
	_manager.register_enemy(enemy)
	enemy.target = _source
	var body := enemy.get_node("Body") as Hitbox
	var first := _hit(enemy, 35.0, &"gun", enemy.global_position + Vector3(0.25, 1.0, 0.3), Vector3.FORWARD, body)
	_check("first ordinary bullet damages 35 before applying panic", is_equal_approx(first, 35.0))
	var status := _effect.status_for(enemy)
	_check("first bullet exposes one physical front facet for four seconds", status != null and status.facet_count() == 1 and is_equal_approx(status.remaining, 4.0))
	# Actor faces -Z, so front-facing shooter stands at negative Z.
	_source.position.z = -8.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var point := status.facet_position(0) + Vector3(0, 0, -0.075)
	var direct := _hit(enemy, 35.0, &"gun", point, Vector3.BACK, status.facets[0])
	_check("real front facet hit deals exactly 260 percent", is_equal_approx(direct, 91.0))
	_check("gun fracture rotates the facet to enemy back", status.facet_count() == 1 and status.facets[0] == null and is_instance_valid(status.facets[1]))
	_check("surface test rejects the opposite face and remote body contact", status.contact_index(status.facet_position(1), Vector3.BACK) == -1 and status.contact_index(enemy.global_position + Vector3.UP * 0.3, Vector3.FORWARD) == -1)
	var head := _hit(enemy, 35.0, &"gun", enemy.global_position + Vector3.UP * 1.8, Vector3.BACK, body, Hitbox.BodyPart.HEAD)
	_check("panic headshot is 200 percent without stacking native head multiplier", is_equal_approx(head, 70.0))
	_source.position.z = 0.0
	var blade := _hit(enemy, 55.0, &"blade", enemy.global_position + Vector3(0.25, 1.0, 0.3), Vector3.FORWARD, body)
	_check("blade backstab is guaranteed 200 percent", is_equal_approx(blade, 110.0))
	_check("blade speed modifier is reversible Stats multiplier", is_equal_approx(stats.get_value(Stats.MELEE_SPEED), 1.3))
	var remaining := status.remaining
	get_tree().paused = true
	status._process(1.0)
	_check("pause freezes panic lifetime", is_equal_approx(status.remaining, remaining))
	get_tree().paused = false
	status._process(4.01)
	_check("expired panic removes physical facets", not status.is_active() and status.facet_count() == 0)
	_effect.apply_panic(enemy)
	_manager.dispatch(&"dash_started", {"position": _source.global_position})
	var decoy := _effect._decoys[0]
	_check("dash leaves a real two-second target and attracts enemy", enemy.target == decoy and decoy.health.health == 1.0)
	decoy._process(1.99)
	_check("decoy stays alive until timeout", not decoy.is_queued_for_deletion())
	decoy._process(0.02)
	_check("timeout restores original aggro and applies radius panic", enemy.target == _source and status.is_active() and _effect._decoys.is_empty())
	_manager.dispatch(&"dash_started", {"position": _source.global_position})
	decoy = _effect._decoys[0]
	decoy.health.apply_damage(5.0, Hitbox.BodyPart.BODY, enemy)
	_check("enemy damage destroys the physical decoy exactly once", decoy.is_queued_for_deletion() and _effect._decoys.is_empty() and enemy.target == _source)
	await get_tree().process_frame
	await _test_reflection(enemy)
	_manager.dispatch(&"dash_started", {"position": _source.global_position})
	_manager.clear()
	_check("cleanup restores aggro, removes panic and reverses blade speed", enemy.target == _source and not status.is_active() and is_equal_approx(stats.get_value(Stats.MELEE_SPEED), 1.0))
	_finished = true


func _test_reflection(enemy: Actor) -> void:
	var other := _actor(Vector3(3, 0, -5))
	_manager.register_enemy(other)
	_effect.apply_panic(enemy)
	_effect.apply_panic(other)
	var start_hp := (other.get_node("Health") as Health).health
	var projectile := Projectile.spawn(self, Vector3(0, 1.22, -9), Vector3.BACK, enemy, 10.0, 20.0, [])
	projectile.reflect(_source, projectile.global_position)
	projectile.boon_hook = _manager.dispatch
	_manager.dispatch(&"parry", {"projectile": projectile, "position": projectile.global_position})
	_check("successful parry retains original reflected projectile and attaches homing", projectile.reflected and projectile.source == _source and projectile.get_child_count() > 3)
	for i in 25:
		await get_tree().physics_frame
	_check("swept reflected projectile reaches a flaw and detonates another enemy", not is_instance_valid(projectile) and (other.get_node("Health") as Health).health < start_hp)
	_check("detonation consumes every exposed remote facet", _effect.status_for(other).facet_count() == 0)


func _hit(target: Actor, damage: float, kind: StringName, point: Vector3, direction: Vector3, hitbox: Hitbox, part := Hitbox.BodyPart.BODY) -> float:
	return _manager.apply_damage(target, damage, {"kind": kind, "proc_depth": 0,
		"position": point, "direction": direction, "hitbox": hitbox, "body_part": part, "source": _source})


func _actor(point: Vector3, team := 1) -> Actor:
	var actor := Actor.new()
	actor.team = team
	actor.position = point
	var health := Health.new()
	health.name = "Health"
	health.max_health = 2000.0
	health.team = team
	actor.add_child(health)
	var hitbox := Hitbox.new()
	hitbox.name = "Body"
	hitbox.position.y = 1.1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 1.2, 0.5)
	collision.shape = shape
	hitbox.add_child(collision)
	actor.add_child(hitbox)
	add_child(actor)
	return actor


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", label])
	if not condition:
		_failed += 1
