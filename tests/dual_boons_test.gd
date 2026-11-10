extends Node3D
## Cross-family integration: real production Player/Enemy/Hitbox/Projectile,
## explicit simulation stepping, and no manufactured combat-event dispatches.

const ENEMY_SCENE := preload("res://actors/enemy/enemy.tscn")
const PLAYER_SCENE := preload("res://actors/player/player.tscn")
const GUNS := ["sloth_gun_pulse", "fear_gaze_pierce", "wrath_gun_cannon", "sorrow_gun_needles"]
const BLADES := ["sloth_blade_cleave", "fear_flash_backstab", "wrath_blade_sweep", "sorrow_blade_tide"]

var _failed := 0
var _finished := false
var _player: Player
var _manager: BoonManager
var _cards: Dictionary = {}
var _actors: Array[Node] = []
var _walls: Array[Node] = []
var _events: Array[Dictionary] = []


func _ready() -> void:
	await _run()
	var ok := _failed == 0 and _finished
	print("%s (%d failed, finished=%s)" % ["ALL PASSED" if ok else "FAIL", _failed, _finished])
	if is_instance_valid(_manager):
		_manager.clear()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var catalog := BoonCatalog.all()
	_check("complete catalog contains 48 family cards and six dual cards", catalog.size() == 54)
	for card in catalog:
		_check("stable card ID is unique: " + card.id, not _cards.has(card.id))
		_cards[card.id] = card
	if catalog.size() != 54:
		return
	_floor()
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	_player.set_physics_process(false)
	_player.weapon.set_process(false)
	_player.melee.set_process(false)
	_player.dash.set_physics_process(false)
	_player.weapon.data = _player.weapon.data.duplicate() as WeaponData
	_player.weapon.data.damage = 10.0
	_player.weapon.data.hip_spread = 0.0
	_player.weapon.data.ads_spread = 0.0
	_player.stats.base[Stats.MAX_HEALTH] = 5000.0
	_player.stats.changed.emit()
	_manager = _player.boons
	_manager.set_physics_process(false)
	_manager.event_dispatched.connect(_record)
	await _frames(3, false)
	await _test_eligibility()
	await _test_privileged_without_dual()
	await _test_slumber_magma()
	await _test_tearful_panic()
	await _test_spiteful_deluge()
	await _test_frozen_paranoia()
	await _test_suffocating_mire()
	await _test_hysterical_rampage()
	_finished = true


func _test_eligibility() -> void:
	for id: String in DualBoonManager.PAIRS:
		await _reset()
		var pair: Array = DualBoonManager.PAIRS[id]
		var card: BoonData = _cards[id]
		_check(id + " is excluded without its cores", not _eligible(id))
		_equip(GUNS[pair[0]])
		_check(id + " is excluded with only its first core", not _eligible(id))
		var found_trait := false
		for candidate: BoonData in _cards.values():
			if candidate.sin == pair[1] and not candidate.core and candidate.rarity in [BoonData.Rarity.COMMON, BoonData.Rarity.RARE]:
				_manager.equip(candidate)
				found_trait = true
				break
		_check(id + " cannot substitute a trait for its missing core", found_trait and not _eligible(id))
		_manager.clear()
		_equip(GUNS[pair[0]])
		_equip(GUNS[pair[1]])
		_check(id + " cannot retain a replaced core in the same slot", not _eligible(id))
		_manager.clear()
		_equip(GUNS[pair[0]])
		_equip(BLADES[pair[1]])
		_check(id + " enters the real eligible pool with two different core slots", _eligible(id))
		_check(id + " equips through prerequisite validation", _manager.request_equip(card))
		var dual := _dual()
		_check(id + " becomes active after equip", dual != null and dual._active(id))
		if id == "dual_slumber_magma":
			_check("slumber attack-speed cost is applied to real Stats", is_equal_approx(_player.stats.get_value(Stats.FIRE_RATE), .8))
		_equip(BLADES[pair[0]])
		_check(id + " immediately loses synergy after a prerequisite core is replaced", not dual._active(id))
		if id == "dual_slumber_magma":
			_check("slumber penalty is removed with the missing core", is_equal_approx(_player.stats.get_value(Stats.FIRE_RATE), 1.0))


func _test_privileged_without_dual() -> void:
	await _reset(["sloth_gun_pulse", "fear_flash_backstab"])
	var enemy := _enemy(Vector3(5, 0, 0))
	var sloth = _family("sloth")
	var fear = _family("fear")
	sloth.apply_latency(enemy)
	fear.apply_panic(enemy)
	var before := enemy.health.health
	var amount := _manager.apply_damage(enemy, 10.0, {"kind": &"proc", "proc_depth": 1, "tag": &"privilege_probe"})
	_check("two independent statuses give 10-to-14 damage even without a dual card", is_equal_approx(amount, 14.0) and is_equal_approx(before - enemy.health.health, 14.0) and _dual() == null)
	await _frames(2, false)
	before = enemy.health.health
	var blast := ReloadCharge.blast(self, enemy.global_position + Vector3.UP, _player, 10.0, 2.0)
	_actors.append(blast)
	_check("legacy physical blast receives the same dual-status bonus through Health", is_equal_approx(before - enemy.health.health, 14.0) and blast.get_meta("targets_hit") == 1)
	before = enemy.health.health
	enemy.health.apply_damage(10.0, Hitbox.BodyPart.BODY)
	_check("environmental damage cannot inherit the player's status bonus", is_equal_approx(before - enemy.health.health, 10.0))
	fear.status_for(enemy).clear()
	amount = _manager.apply_damage(enemy, 10.0, {"kind": &"proc", "proc_depth": 1, "tag": &"privilege_probe"})
	_check("one remaining status removes the global forty-percent bonus", is_equal_approx(amount, 10.0))


func _test_slumber_magma() -> void:
	await _reset(["sloth_gun_pulse", "wrath_blade_sweep", "dual_slumber_magma"])
	_wall(Vector3(0, 1.5, -2.2), Vector3(12, 3, .3))
	var first := _enemy(Vector3(-2, 0, 0))
	var second := _enemy(Vector3(2, 0, 0))
	await _frames(3, false)
	var sloth = _family("sloth")
	sloth.apply_latency(first)
	sloth.apply_latency(second)
	var initial_a := first.global_position
	var initial_b := second.global_position
	(sloth.clocks[first.get_instance_id()] as LatencyStatus).detonate()
	await _frames(36)
	var walls := _events_for(&"wall_slam").filter(func(entry: Dictionary) -> bool: return entry.context.get("wall_impact", false))
	var hit_ids: Dictionary = {}
	for event in walls:
		hit_ids[event.context.target.get_instance_id()] = true
	_check("sloth detonation physically launches both latent enemies into a real wall", hit_ids.has(first.get_instance_id()) and hit_ids.has(second.get_instance_id()) and first.global_position.distance_to(initial_a) > 1.0 and second.global_position.distance_to(initial_b) > 1.0)
	_check("real wall contacts cause damage, stun, and spawned magma spikes", first.health.health < 4900 and second.health.health < 4900 and first.boon_stunned and second.boon_stunned and not _dual()._pools.is_empty())


func _test_tearful_panic() -> void:
	await _reset(["fear_gaze_pierce", "sorrow_blade_tide", "dual_tearful_panic"])
	var victim := _enemy(Vector3.ZERO)
	var nearby := _enemy(Vector3(3, 0, 0))
	var outside := _enemy(Vector3(8, 0, 0))
	var fear = _family("fear")
	var sorrow = _family("sorrow")
	fear.apply_panic(victim)
	var start := nearby.global_position
	await _shoot_facet(victim)
	_check("a real pistol ray hitting a physical flaw creates the tearful pool", not _events_for(&"fear_flaw_broken").is_empty() and not _dual()._pools.is_empty())
	_check("tearful pool rests on the physical ground below the chest facet", not _dual()._pools.is_empty() and absf(_dual()._pools[0].node.global_position.y - 0.03) < 0.01)
	_check("tearful pool gives five actual erosion layers inside its radius only", sorrow.erosion_layers(victim) == 5 and sorrow.erosion_layers(nearby) == 5 and sorrow.erosion_layers(outside) == 0)
	await _frames(8, false)
	_check("tearful pull moves the enemy through CharacterBody physics toward the break", nearby.global_position.distance_to(victim.global_position) < start.distance_to(victim.global_position) - .2)


func _test_spiteful_deluge() -> void:
	await _reset(["wrath_gun_cannon", "sorrow_blade_tide", "sorrow_buffer", "dual_spiteful_deluge"])
	var attacker := _enemy(Vector3(2, 0, 0))
	var before := attacker.health.health
	_player.health.apply_damage(60.0, Hitbox.BodyPart.BODY, attacker)
	_check("real sorrow buffer defers half an incoming hit", is_equal_approx(_player.health.health, 4970.0))
	_manager._physics_process(.5)
	_check("settled five-point debt sends ten damage back to the enemy with player ownership", is_equal_approx(before - attacker.health.health, 10.0) and is_equal_approx(_player.health.health, 4965.0))
	var returned := _events_for(&"hit_after").filter(func(entry: Dictionary) -> bool: return entry.context.get("tag") == &"dual")
	_check("retaliation records the player as source and a fresh proc context", not returned.is_empty() and returned.back().context.source == _player and returned.back().context.kind == &"proc")
	# The victim stands behind the blade cone but inside the tear's blast, so
	# the 90-point explosion cannot be mistaken for melee or water-shot damage.
	attacker.global_position = Vector3(2, 0, 1)
	var sorrow = _family("sorrow")
	sorrow.spawn_tear(Vector3(0, 0, -2))
	var tear: TearCrystal = sorrow.tears.back()
	_player.weapon.camera.look_at(tear.global_position)
	await _frames(3, false)
	before = attacker.health.health
	_player.melee.swing_now()
	_player.melee._process(.081)
	_player.melee._process(.12)
	_check("real blade active window breaks the physical tear and adds exactly ninety radial damage", tear.consumed and is_equal_approx(before - attacker.health.health, 90.0) and not _events_for(&"sorrow_tear_broken").is_empty())


func _test_frozen_paranoia() -> void:
	await _reset(["fear_gaze_pierce", "sloth_blade_cleave", "dual_frozen_paranoia"])
	var enemy := _enemy(Vector3(0, 0, -8))
	var fear = _family("fear")
	var status: PanicFlawStatus = fear.apply_panic(enemy)
	_player.weapon.camera.look_at(enemy.global_position + Vector3.UP)
	_manager._physics_process(.01)
	_check("standing still and aiming at an enemy applies eighty-percent slow and triple physical area", is_equal_approx(enemy.boon_movement_scale, .2) and is_equal_approx(status.area_multiplier, 3.0))
	_player.velocity = Vector3(4, 0, 0)
	_manager._physics_process(.01)
	_check("moving without ADS restores both gaze modifiers immediately", is_equal_approx(enemy.boon_movement_scale, 1.0) and is_equal_approx(status.area_multiplier, 1.0))
	_player.weapon.aiming = true
	_manager._physics_process(.01)
	_check("real weapon ADS retains gaze while moving", is_equal_approx(enemy.boon_movement_scale, .2) and is_equal_approx(status.area_multiplier, 3.0))
	_player.weapon.camera.look_at(Vector3(8, 1, 0))
	_manager._physics_process(.01)
	_check("turning away restores the same enemy's area and speed", is_equal_approx(enemy.boon_movement_scale, 1.0) and is_equal_approx(status.area_multiplier, 1.0))


func _test_suffocating_mire() -> void:
	await _reset(["sloth_gun_pulse", "sorrow_blade_tide", "sloth_dash_ripple", "dual_suffocating_mire"])
	var sorrow = _family("sorrow")
	# Leave a real Sloth aura, then replace only the dash core. Sloth gun keeps
	# the committed aura alive while a real Sorrow dash creates the ribbon.
	_check("Sloth dash starts through the production action entry", _player.dash.try_dash())
	_player.dash._physics_process(.2)
	await get_tree().process_frame
	_equip("sorrow_dash_ribbon")
	_player.global_position = Vector3(8, 0, 0)
	_player.velocity = Vector3(0, -1, 0)
	_player.move_and_slide()
	_player.dash._physics_process(.01)
	_check("Sorrow dash starts after landing and replacing the dash slot", _player.dash.try_dash())
	_player.dash._physics_process(.2)
	await get_tree().process_frame
	_player.global_position = Vector3(8, 0, 3)
	_player.velocity = Vector3.ZERO
	var aura_enemy := _enemy(Vector3(1, 0, 0))
	var water_enemy := _enemy(Vector3(8, 0, 0))
	var outsider := _enemy(Vector3(16, 0, 0))
	var projectile := Projectile.spawn(self, Vector3(8, 1, .5), Vector3.FORWARD, water_enemy, 5.0, 20.0, [])
	_manager._physics_process(.01)
	_check("mire uses the union of real water regions and the dash aura", _dual()._regions().size() >= 2 and is_equal_approx(aura_enemy.boon_attack_scale, .5) and is_equal_approx(water_enemy.boon_attack_scale, .5) and is_equal_approx(outsider.boon_attack_scale, 1.0))
	_check("mire halves attack timing without applying an extra movement or time slow", is_equal_approx(water_enemy.boon_movement_scale, .6) and is_equal_approx(water_enemy.boon_time_scale, 1.0))
	_player.global_position = Vector3(8, 0, 10)
	water_enemy.target = _player
	water_enemy._sees_target = true
	water_enemy._react_left = 1.0
	water_enemy._strafe_left = 1.0
	water_enemy._strafe_dir = 1.0
	water_enemy._process_engage(.2)
	_check("mire halves the production reaction timer while retaining normal strafe velocity", is_equal_approx(water_enemy._react_left, .9) and is_equal_approx(Vector2(water_enemy.velocity.x, water_enemy.velocity.z).length(), water_enemy.strafe_speed))
	water_enemy.target = null
	water_enemy.velocity = Vector3.ZERO
	var bullet_start := projectile.global_position
	projectile._physics_process(.1)
	_check("hostile projectile advances only ten centimetres in a tenth-second at five percent speed", is_equal_approx(projectile.boon_time_scale, .05) and is_equal_approx(projectile.global_position.distance_to(bullet_start), .1))
	sorrow.add_erosion(water_enemy, 1)
	var prior_tears: int = sorrow.tears.size()
	_manager.apply_damage(water_enemy, 10000.0, {"tag": &"mire_death_probe", "proc_depth": 1})
	_check("an eroded enemy dying inside mire emits two real tears", sorrow.tears.size() - prior_tears == 2)
	projectile.queue_free()


func _test_hysterical_rampage() -> void:
	await _reset(["fear_gaze_pierce", "wrath_blade_sweep", "dual_hysterical_rampage"])
	_wall(Vector3(0, 1.5, 2.2), Vector3(12, 3, .3))
	var victim := _enemy(Vector3.ZERO)
	var remote := _enemy(Vector3(12, 0, 0))
	var fear = _family("fear")
	fear.apply_panic(victim)
	fear.apply_panic(remote)
	var before := remote.health.health
	await _shoot_facet(victim)
	await _frames(28)
	_check("physical flaw break launches target into a real WORLD contact", _events_for(&"wall_slam").any(func(event: Dictionary) -> bool: return event.context.get("wall_impact", false) and event.context.target == victim))
	_check("real wall contact detonates the distant remaining physical flaw", remote.health.health < before and fear.status_for(remote).facet_count() == 0)
	var detonations := _events_for(&"fear_flaw_broken").size()
	await _frames(30)
	_check("wall-to-flaw chain cannot recursively generate another cascade", _events_for(&"fear_flaw_broken").size() == detonations)
	await _reset(["fear_gaze_pierce", "wrath_blade_sweep", "dual_hysterical_rampage"])
	victim = _enemy(Vector3.ZERO)
	remote = _enemy(Vector3(12, 0, 0))
	fear = _family("fear")
	fear.apply_panic(victim)
	fear.apply_panic(remote)
	before = remote.health.health
	await _shoot_facet(victim)
	await _frames(40)
	_check("open-air motion without a wall cannot detonate distant flaws", is_equal_approx(remote.health.health, before) and fear.status_for(remote).facet_count() == 1)
	await _reset(["fear_gaze_pierce", "wrath_blade_sweep", "dual_hysterical_rampage"])
	victim = _enemy(Vector3.ZERO)
	var blocker := _enemy(Vector3(0, 0, 1.2))
	remote = _enemy(Vector3(12, 0, 0))
	fear = _family("fear")
	fear.apply_panic(victim)
	fear.apply_panic(remote)
	before = remote.health.health
	await _shoot_facet(victim)
	await _frames(30)
	_check("enemy-body contact is not promoted to a WORLD wall cascade", _events_for(&"wall_slam").any(func(event: Dictionary) -> bool: return event.context.get("collider") == blocker and not event.context.get("wall_impact", true)) and is_equal_approx(remote.health.health, before) and fear.status_for(remote).facet_count() == 1)


func _reset(ids: Array = []) -> void:
	_manager.clear()
	for actor in _actors:
		if is_instance_valid(actor):
			actor.queue_free()
	for wall in _walls:
		if is_instance_valid(wall):
			wall.queue_free()
	for projectile in _manager.projectiles():
		projectile.queue_free()
	_actors.clear()
	_walls.clear()
	_events.clear()
	_player.global_position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_player.weapon.aiming = false
	_player.weapon.camera.rotation = Vector3.ZERO
	_player.health.health = 5000.0
	_player.dash.cancel()
	_player.melee.cancel()
	_player.weapon.ammo = 8
	await _frames(2, false)
	for id: String in ids:
		_equip(id)


func _equip(id: String) -> void:
	assert(_cards.has(id), "missing authored card: " + id)
	_manager.equip(_cards[id])


func _eligible(id: String) -> bool:
	return BoonCatalog.eligible(_manager).any(func(card: BoonData) -> bool: return card.id == id)


func _family(name: String) -> Variant:
	return DualBoonManager.family(_manager, name)


func _dual() -> DualBoonManager:
	return _manager.effect_for(preload("res://buffs/dual/dual_boon_manager.gd")) as DualBoonManager


func _record(event: StringName, context: Dictionary) -> void:
	_events.append({"event": event, "context": context.duplicate()})


func _events_for(event: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _events:
		if entry.event == event:
			result.append(entry)
	return result


func _enemy(point: Vector3) -> Enemy:
	var actor := ENEMY_SCENE.instantiate() as Enemy
	(actor.get_node("Health") as Health).max_health = 5000.0
	actor.position = point
	add_child(actor)
	_actors.append(actor)
	return actor


func _shoot_facet(enemy: Enemy) -> void:
	var status: PanicFlawStatus = _family("fear").status_for(enemy)
	var index := 0 if is_instance_valid(status.facets[0]) else 1
	var point := status.facet_position(index)
	var normal := -status.facets[index].global_basis.z.normalized()
	_player.global_position = enemy.global_position + normal * 4.0
	var camera := _player.weapon.camera
	camera.global_position = point + normal * 4.0
	camera.look_at(point)
	await _frames(2, false)
	_player.weapon._shoot_ray(camera.global_position, (point - camera.global_position).normalized())


func _frames(count: int, step_manager := true) -> void:
	for frame in count:
		await get_tree().physics_frame
		if step_manager:
			_manager._physics_process(1.0 / 60.0)


func _floor() -> void:
	var floor := _box(Vector3(0, -.1, 0), Vector3(80, .2, 80))
	add_child(floor)


func _wall(point: Vector3, size: Vector3) -> void:
	var wall := _box(point, size)
	add_child(wall)
	_walls.append(wall)


func _box(point: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.position = point
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", label])
	if not condition:
		_failed += 1
