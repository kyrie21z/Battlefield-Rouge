extends Node3D
## Real Player actions + real Health/Hitbox, with independent expected results.
class Dummy extends CharacterBody3D:
	var team := 1
	var boon_time_scale := 1.0
	var boon_movement_scale := 1.0
	var boon_stunned := false
	var boon_windup_scale := 1.0

const PROBE = preload("res://tests/boon_probe_effect.gd")
var failed := 0
var checks := 0
var finished := false
var actor: Player
var manager: BoonManager
var target: Dummy
var target_health: Health
var saved_changes := 0

func _ready() -> void:
	await _run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(100)
	if not finished:
		failed += 1
	print("BOON PIPELINE: %d checks, %d failed, completed=%s" % [checks, failed, finished])
	get_tree().quit(0 if failed == 0 else 1)

func _run() -> void:
	actor = preload("res://actors/player/player.tscn").instantiate() as Player
	actor.gravity = 0.0
	add_child(actor)
	actor.set_physics_process(false)
	actor.weapon.set_process(false)
	actor.melee.set_process(false)
	actor.dash.set_physics_process(false)
	manager = actor.boons
	manager.set_physics_process(false)
	target = Dummy.new()
	target.position = Vector3(0, 1.6, -3)
	target_health = Health.new()
	target_health.name = "Health"
	target_health.max_health = 1000.0
	target.add_child(target_health)
	var box := Hitbox.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 0.5)
	collision.shape = shape
	box.add_child(collision)
	target.add_child(box)
	add_child(target)
	manager.register_enemy(target)
	for i in 3:
		await get_tree().physics_frame
	var legacy := Buff.new()
	legacy.stat = Stats.DAMAGE
	legacy.mul = 1.2
	actor.stats.apply_buff(legacy)
	var gun := _card("probe_gun", BoonData.Slot.GUN)
	gun.stat_modifiers = {Stats.DAMAGE: {"mul": 1.5}}
	_check("equip vacant gun directly", manager.request_equip(gun))
	var probe := manager.effect_for(PROBE)
	_check("legacy and boon modifiers combine", is_equal_approx(actor.stats.get_value(Stats.DAMAGE), 1.8))
	var knife := _card("probe_blade", BoonData.Slot.BLADE)
	manager.equip(knife)
	_check("same hook Script gets one state instance", manager.effect_for(PROBE) == probe and manager._effects.size() == 1)
	var gun2 := _card("replacement", BoonData.Slot.GUN)
	gun2.stat_modifiers = {Stats.DAMAGE: {"mul": 2.0}}
	_check("occupied slot needs explicit confirmation", not manager.request_equip(gun2) and manager.has(gun.id))
	manager.confirm_replace(false)
	_check("cancel keeps original numerical modifier", is_equal_approx(actor.stats.get_value(Stats.DAMAGE), 1.8))
	manager.request_equip(gun2)
	_check("confirm swaps one core", manager.confirm_replace(true) and not manager.has(gun.id) and manager.has(gun2.id))
	_check("replacement removes old source, retains legacy buff", is_equal_approx(actor.stats.get_value(Stats.DAMAGE), 2.4))
	seed(7521)
	var expected_random := randf()
	seed(7521)
	manager.dispatch(&"blade_started", {})
	_check("pipeline consumes no global gameplay RNG", randf() == expected_random)
	actor.weapon.data = actor.weapon.data.duplicate()
	actor.weapon.data.hip_spread = 0.0
	actor.weapon.data.ads_spread = 0.0
	actor.weapon.data.spread_per_shot = 0.0
	actor.weapon.camera.global_position = Vector3(0, 1.6, 0)
	_check("real pistol fires through pipeline", actor.weapon.try_fire())
	_check("gun hit has actual modified damage (35*2.4+7)", is_equal_approx(target_health.health, 909.0))
	_check("successful shot has one shoot and hit event", probe.counts.get(&"shoot_fired", 0) == 1 and probe.counts.get(&"hit_after", 0) == 1)
	actor.weapon.try_fire()
	_check("cooldown rejected fire adds no hook", probe.counts.get(&"shoot_fired", 0) == 1)
	_check("real blade starts", actor.melee.swing_now())
	actor.melee._process(0.08)
	actor.melee._process(0.12)
	actor.melee._process(0.15)
	_check("real blade damage uses pipeline once", is_equal_approx(target_health.health, 777.0))
	_check("blade active and end hooks fire once", probe.counts.get(&"blade_struck", 0) == 1 and probe.counts.get(&"blade_finished", 0) == 1)
	_check("real dash starts", actor.dash.try_dash())
	actor.dash._physics_process(0.18)
	await get_tree().process_frame
	_check("dash lifecycle hooks", probe.counts.get(&"dash_started", 0) == 1 and probe.counts.get(&"dash_finished", 0) == 1)
	actor.dash.cancel()
	actor.weapon.try_reload()
	actor.weapon._process(1.0)
	_check("real reload hooks", probe.counts.get(&"reload_started", 0) == 1 and probe.counts.get(&"reload_finished", 0) == 1)
	var hurt_events := [0]
	var count_hurt := func(_amount, _part, _source): hurt_events[0] += 1
	actor.health.damaged.connect(count_hurt)
	probe.prevent_damage = true
	actor.health.apply_damage(1000.0, Hitbox.BodyPart.BODY, target)
	_check("pre-HP hook prevents lethal damage", actor.health.health == 100.0 and not actor.health.is_dead())
	_check("cancelled damage never emits a false damaged event", hurt_events[0] == 0)
	actor.health.damaged.disconnect(count_hurt)
	probe.prevent_damage = false
	actor.health.damage_absorber = func(amount: float): return maxf(amount - 10.0, 0.0)
	manager.grant_shield(15.0)
	var dealt := actor.health.apply_damage(30.0, Hitbox.BodyPart.BODY, target)
	_check("legacy shield and new barrier compose", dealt == 5.0 and actor.health.health == 95.0 and manager.shield_amount == 0.0)
	actor.health.damage_absorber = Callable()
	var prior := target_health.health
	manager.apply_damage(target, 9.0, {"damage": 999.0, "proc_depth": 1})
	_check("raw proc overrides copied damage and scales exactly once", is_equal_approx(prior - target_health.health, 21.6))
	prior = target_health.health
	manager.apply_damage(target, 9.0, {"damage_scaled": true, "proc_depth": 1})
	_check("already settled proc is not multiplied again", is_equal_approx(prior - target_health.health, 9.0))
	prior = target_health.health
	target_health.apply_damage(5.0, Hitbox.BodyPart.BODY, actor)
	_check("direct outgoing Health damage uses the same multiplier once", is_equal_approx(prior - target_health.health, 12.0))
	prior = target_health.health
	target_health.apply_damage(5.0, Hitbox.BodyPart.BODY)
	_check("environmental damage does not inherit player offense", is_equal_approx(prior - target_health.health, 5.0))
	_check("proc recursion depth capped", manager.apply_damage(target, 99.0, {"proc_depth": 5}) == 0.0)
	manager.set_modifier(&"timed", {Stats.MOVE_SPEED: {"mul": 2.0}}, 0.2)
	manager.set_status(target, &"slow", 0.2, 0.6)
	var projectile := Projectile.spawn(self, Vector3(10, 2, 0), Vector3.FORWARD, target, 1.0, 10.0, [])
	projectile.set_physics_process(false)
	manager.freeze_world(0.15)
	_check("world freeze stops enemy and hostile projectile locally", target.boon_time_scale == 0.0 and projectile.boon_time_scale == 0.0 and Engine.time_scale == 1.0)
	var before := projectile.position
	projectile._physics_process(0.1)
	_check("frozen projectile cannot advance", projectile.position == before)
	get_tree().paused = true
	manager.set_physics_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	manager.set_physics_process(false)
	_check("paused tree does not expire timed effects", actor.stats.get_value(Stats.MOVE_SPEED) == 2.0 and target.boon_time_scale == 0.0)
	get_tree().paused = false
	manager._physics_process(0.16)
	_check("freeze expires while player clock runs, other slow remains", target.boon_time_scale == 1.0 and target.boon_movement_scale == 0.6 and projectile.boon_time_scale == 1.0)
	manager._physics_process(0.05)
	_check("timed source expires and restores speed", actor.stats.get_value(Stats.MOVE_SPEED) == 1.0 and target.boon_movement_scale == 1.0)
	await _extended_contracts()
	manager.loadout_changed.connect(func(_cards): saved_changes += 1)
	var save_before := saved_changes
	actor.remove_child(manager)
	_check("scene teardown never persists empty loadout", saved_changes == save_before)
	_check("teardown removes reversible modifiers but retains legacy buff", is_equal_approx(actor.stats.get_value(Stats.DAMAGE), 1.2))
	manager.free()
	actor.free()
	actor = preload("res://actors/player/player.tscn").instantiate() as Player
	actor.gravity = 0.0
	add_child(actor)
	manager = actor.boons
	manager.register_enemy(target)
	manager.equip(_card("death_probe", BoonData.Slot.GUN))
	manager.freeze_world(5.0)
	manager.set_modifier(&"death_timed", {Stats.MOVE_SPEED: {"mul": 1.5}}, 5.0)
	actor.health.apply_damage(9999.0, Hitbox.BodyPart.BODY, target)
	_check("real death removes cards, timed stats and local freeze", actor.health.is_dead()
		and manager.all_equipped().is_empty() and target.boon_time_scale == 1.0
		and actor.stats.get_value(Stats.MOVE_SPEED) == 1.0)
	finished = true

func _extended_contracts() -> void:
	var victim := Node3D.new()
	var victim_health := Health.new()
	victim_health.name = "Health"
	victim_health.max_health = 10.0
	victim.add_child(victim_health)
	add_child(victim)
	_check("Health overkill return equals actual ten HP loss", victim_health.apply_damage(100.0, Hitbox.BodyPart.BODY, actor) == 10.0 and victim_health.last_damage_context.dealt == 10.0)
	victim.queue_free()
	target_health.max_shield = 50.0
	target_health.shield_regeneration_rate = 10.0
	target_health.shield_regeneration_delay = 0.0
	target_health.set_physics_process(false)
	target_health.grant_shield(30.0)
	var hp_before := target_health.health
	target_health.apply_damage(40.0, Hitbox.BodyPart.BODY, actor, {"damage_scaled": true})
	_check("intrinsic Health shield absorbs before HP", is_equal_approx(hp_before - target_health.health, 10.0) and target_health.shield_points == 0.0)
	_check("resolved damage reports real absorption plus HP", target_health.last_damage_context.absorbed == 30.0 and target_health.last_damage_context.resolved_damage == 40.0)
	target_health.grant_shield(50.0)
	hp_before = target_health.health
	manager.apply_damage(target, 7.0, {"true_damage": true, "tag": &"test_true"})
	_check("raw true damage scales offense but bypasses intrinsic shield", is_equal_approx(hp_before - target_health.health, 16.8) and target_health.shield_points == 50.0)
	_check("break_shield removes full actual capacity", target_health.break_shield() == 50.0 and target_health.shield_points == 0.0)
	target_health.set_shield_regeneration_blocked(&"external", true)
	manager.set_status(target, &"regen_block", 0.0, 1.0, 1.0, false, 1.0, true)
	target_health._physics_process(1.0)
	_check("shield recovery is really blocked", target_health.shield_points == 0.0)
	manager.clear_status(target, &"regen_block")
	target_health._physics_process(1.0)
	_check("removing one blocker preserves another source", target_health.shield_points == 0.0 and target_health.shield_regeneration_blocked)
	target_health.set_shield_regeneration_blocked(&"external", false)
	target_health._physics_process(1.0)
	_check("natural regeneration resumes after all blockers clear", target_health.shield_points == 10.0)
	manager.set_modifier(&"debt_test", {Stats.DAMAGE_TAKEN: {"mul": 0.5}})
	hp_before = actor.health.health
	actor.health.apply_damage(4.0, Hitbox.BodyPart.BODY, target, {"skip_damage_multiplier": true})
	_check("fixed deferred damage is not mitigated twice", is_equal_approx(hp_before - actor.health.health, 4.0))
	manager.remove_modifier(&"debt_test")
	for slot_index in [BoonData.Slot.BLADE, BoonData.Slot.DASH, BoonData.Slot.OTHER]:
		var first := _card("slot_%d" % slot_index, slot_index)
		manager.equip(first)
		var next := _card("next_%d" % slot_index, slot_index)
		_check("slot %d request cannot silently overwrite" % slot_index, not manager.request_equip(next) and manager.has(first.id))
		_check("slot %d confirms exactly one replacement" % slot_index, manager.confirm_replace(true) and not manager.has(first.id))
	var conditional := _card("condition", BoonData.Slot.OTHER)
	conditional.core = false
	conditional.prerequisite_any.assign(["missing", "replacement"])
	_check("OR prerequisite accepts owned alternative", manager.can_equip(conditional))
	conditional.required_trait_sin = BoonData.Sin.SLOTH
	conditional.required_trait_count = 1
	var dual := _card("dual_count", BoonData.Slot.OTHER)
	dual.core = false
	dual.rarity = BoonData.Rarity.DUAL
	manager.equip(dual)
	_check("dual cards do not count as family secondary traits", not manager.can_equip(conditional))
	var ordinary := _card("ordinary_trait", BoonData.Slot.OTHER)
	ordinary.core = false
	manager.equip(ordinary)
	_check("ordinary family trait satisfies count prerequisite", manager.can_equip(conditional))
	actor.weapon.ammo = 0
	actor.weapon.try_reload()
	actor.weapon._process(0.2)
	manager.set_modifier(&"dynamic_reload", {Stats.RELOAD_SPEED: {"mul": 2.0}})
	actor.weapon._process(0.33)
	_check("mid-reload speed boost advances existing reassembly", not actor.weapon.is_reloading() and actor.weapon.ammo == 8)
	manager.remove_modifier(&"dynamic_reload")
	var sloth := preload("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
	sloth.position = Vector3(0, 0, -12)
	add_child(sloth)
	sloth.set_physics_process(false)
	sloth.target = actor
	_check("production Sloth starts real attack", sloth.cast_attack())
	var attack := sloth.active_attack
	attack.set_physics_process(false)
	manager.set_status(sloth, &"windup", 0.0, 1.0, 1.0, false, 1.3)
	_check("windup status changes actual Sloth warning 2s to 2.6s", is_equal_approx(attack.warning_time(), 2.6))
	manager.freeze_world(0.2, &"production_freeze")
	attack._physics_process(0.1)
	_check("local freeze pauses derived Sloth attack and animation", attack.elapsed == 0.0 and sloth.visual.animation.speed_scale == 0.0)
	var newborn := Projectile.spawn(self, Vector3(15, 1, 0), Vector3.FORWARD, sloth, 1.0, 10.0, [])
	newborn.set_physics_process(false)
	_check("new enemy projectile inherits ongoing freeze", newborn.boon_time_scale == 0.0)
	manager.clear_world_freeze(&"production_freeze")
	attack._physics_process(0.1)
	_check("explicit freeze cleanup resumes real attack", is_equal_approx(attack.elapsed, 0.1) and newborn.boon_time_scale == 1.0)
	manager.set_status(sloth, &"attack_speed", 0.0, 1.0, 1.0, false, 1.0, false, 0.5)
	attack._physics_process(0.2)
	_check("attack speed halves real attack clock without movement slow", is_equal_approx(attack.elapsed, 0.2) and sloth.boon_movement_scale == 1.0 and sloth.boon_time_scale == 1.0)
	manager.clear_status(sloth, &"attack_speed")
	_check("attack speed source restores independently", sloth.boon_attack_scale == 1.0)
	manager.clear_status(sloth, &"windup")
	_check("windup cleanup restores original warning", is_equal_approx(attack.warning_time(), 2.0))
	sloth.free()
	newborn.queue_free()
	var point := CapturePoint.new()
	var objective := Node3D.new()
	objective.name = "Objective"
	var building := MeshInstance3D.new()
	building.name = "Mesh"
	building.mesh = BoxMesh.new()
	objective.add_child(building)
	point.add_child(objective)
	add_child(point)
	point.open()
	point.player_in_reach = true
	point.resolve_swing(0.2, 2.0, 1.5, 2)
	_check("clock widened window applies perfect verdict and progress multiplier", is_equal_approx(point.progress, 0.4))
	_check("clock theme drives actual flash and light", point._material.emission == BoonPalette.COLORS[1]
		and point._light.light_color == BoonPalette.COLORS[1])
	var bar := StrikeBar.new()
	for child_name in ["Hint", "Result"]:
		var label := Label.new()
		label.name = child_name
		bar.add_child(label)
	var flash := ColorRect.new()
	flash.name = "Flash"
	bar.add_child(flash)
	add_child(bar)
	actor.stats.set_modifier(&"clock_test", {Stats.CLOCK_THEME: {"add": 2.0}, Stats.CLOCK_WINDOW: {"mul": 1.5}})
	bar.setup(point, actor.stats)
	_check("timing bar reads same themed stats as clock", bar._theme_color() == BoonPalette.COLORS[1] and bar._stats == actor.stats)
	actor.stats.remove_modifier(&"clock_test")
	point.free()
	bar.free()
	await get_tree().process_frame

func _card(id: String, slot: BoonData.Slot) -> BoonData:
	var result := BoonData.new()
	result.id = id
	result.name = id
	result.slot = slot
	result.script_hook = PROBE
	return result

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failed += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
