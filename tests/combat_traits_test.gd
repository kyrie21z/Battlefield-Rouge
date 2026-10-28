extends Node
## Behavioral checks for the three MVP cores inspired by the supplied ideas.

class Source extends Node3D:
	var team := 1

var _failures := 0
var _finished := false


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	var ok := _failures == 0 and _finished
	print("COMBAT TRAITS: %s (%d failed)" % ["ALL PASSED" if ok else "FAIL", _failures])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var arena := Node3D.new()
	add_child(arena)
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	arena.add_child(player)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	player.shield.set_process(false)
	var traits := player.combat_traits
	var enemy_source := Source.new()
	arena.add_child(enemy_source)
	var ally := Source.new()
	ally.team = 0
	arena.add_child(ally)
	var target := _target(arena, Vector3(0, 1.0, -1.7), 1)
	var friend := _target(arena, Vector3(1.0, 1.0, -1.4), 0)
	var hidden := _target(arena, Vector3(0, 1.0, -3.2), 1)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	wall.position = Vector3(0, 1.0, -2.6)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.2)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	arena.add_child(wall)
	for frame_index in 3:
		await get_tree().physics_frame
	print("== explosion filtering")
	var effect := ReloadCharge.blast(arena, Vector3(0, 1, 0), player, 30.0, 3.5)
	_check("one blast damages a multi-hitbox enemy once", is_equal_approx(target.health, 970.0) and effect.get_meta("targets_hit") == 1)
	_check("blast ignores allies and player", friend.health == 1000.0 and player.health.health == 100.0)
	_check("blast does not pass through walls", hidden.health == 1000.0)
	print("== empty reload core")
	var thrown: Array[Node3D] = []
	traits.reload_charge_thrown.connect(func(charge: Node3D): thrown.append(charge))
	player.stats.apply_buff(BuffPool.ALL[0])
	player.weapon.ammo = 1
	player.weapon.try_reload()
	_check("tactical reload does not throw a charge", thrown.is_empty())
	player.weapon._reload_left = 0.0
	player.weapon.ammo = 0
	player.weapon.try_reload()
	player.weapon.try_reload()
	_check("empty reload does not throw before completion", thrown.is_empty() and not traits.has_reload_charge())
	player.weapon._finish_reload()
	_check("completed reload stores the magazine without throwing", traits.has_reload_charge() and thrown.is_empty())
	_check("active throw consumes one stored magazine", traits.try_throw_reload_charge() and thrown.size() == 1)
	var charge := thrown[0] as ReloadCharge
	var explosions := [0]
	charge.exploded.connect(func(_origin: Vector3, _effect: Node3D): explosions[0] += 1)
	charge.detonate()
	charge.detonate()
	_check("magazine detonates only once", explosions[0] == 1 and charge.exploded_once)
	player.stats.apply_buff(BuffPool.ALL[0])
	_check("repeated gun core raises blast damage", player.stats.get_value(Stats.RELOAD_BLAST_DAMAGE) == 240.0)
	print("== blade parry and gun release")
	player.stats.apply_buff(BuffPool.ALL[3])
	_check("blade core grants one storage slot", traits.capacity() == 1)
	player.melee.swing_now()
	player.health.apply_damage(10.0, Hitbox.BodyPart.BODY, ally)
	_check("friendly fire cannot create stored bullets", traits.stored_rounds == 0)
	var health_before := player.health.health
	Projectile.spawn(arena, Vector3(0, 0.9, -0.8), Vector3.BACK, enemy_source, 12.0, 8.0, [])
	for frame_index in 8:
		await get_tree().physics_frame
	_check("timed V swing catches an actual enemy projectile", traits.stored_rounds == 1 and player.health.health == health_before)
	player.health.apply_damage(12.0, Hitbox.BodyPart.BODY, enemy_source)
	_check("parry storage respects capacity", traits.stored_rounds == 1)
	traits._process(CombatTraits.PARRY_WINDOW + 0.01)
	player.health.apply_damage(10.0, Hitbox.BodyPart.BODY, enemy_source)
	_check("damage resumes outside the parry window", player.health.health == health_before - 10.0)
	var released := [0]
	traits.rounds_released.connect(func(count: int): released[0] += count)
	player.weapon._reload_left = 0.0
	player.weapon._cooldown = 0.0
	player.weapon.ammo = 10
	player.weapon.data = player.weapon.data.duplicate() as WeaponData
	player.weapon.data.hip_spread = 0.0
	player.weapon._spread = 0.0
	var target_before := target.health
	player.weapon.try_fire()
	_check("next shot releases and consumes the collected bullet", released[0] == 1 and traits.stored_rounds == 0)
	for frame_index in 6:
		await get_tree().physics_frame
	_check("returned bullet adds real damage to gunfire", target_before - target.health > player.weapon.data.damage * player.stats.get_value(Stats.DAMAGE))
	player.stats.apply_buff(BuffPool.ALL[3])
	_check("repeated blade core raises storage capacity", traits.capacity() == 2)
	print("== shield counterattack")
	player.stats.apply_buff(BuffPool.ALL[6])
	var pulses := [0]
	traits.shield_pulsed.connect(func(): pulses[0] += 1)
	player.shield.try_activate()
	player.shield._process(player.shield.active_remaining + 0.01)
	_check("unused shield cannot produce a free pulse", pulses[0] == 0)
	player.shield._process(player.shield.cooldown_remaining + 0.01)
	player.shield.try_activate()
	health_before = player.health.health
	player.health.apply_damage(30.0, Hitbox.BodyPart.BODY, enemy_source)
	player.health.apply_damage(30.0, Hitbox.BodyPart.BODY, enemy_source)
	_check("shield absorbs attacks before countering", player.health.health == health_before and pulses[0] == 0)
	target_before = target.health
	player.shield._process(player.shield.active_remaining + 0.01)
	player.shield._process(0.1)
	_check("shield ends in exactly one damaging pulse", pulses[0] == 1 and is_equal_approx(target_before - target.health, 25.0))
	print("== death clears primed combat state")
	# The parry swing above is still in its windup because this test does not
	# advance MeleeWeapon. Clear it so the death swing can start and show a blade.
	player.melee.cancel()
	player.melee.swing_now()
	player.health.apply_damage(10.0, Hitbox.BodyPart.BODY, enemy_source)
	traits._process(0.0)
	_check("death fixture has a visible stored bullet and active parry", traits.stored_rounds == 1 and player.health.parrying and traits._orbs.any(func(orb: MeshInstance3D): return orb.visible))
	traits._process(CombatTraits.PARRY_WINDOW + 0.01)
	player.shield._process(player.shield.cooldown_remaining + 0.01)
	player.shield.try_activate()
	player.health.apply_damage(10.0, Hitbox.BodyPart.BODY, enemy_source)
	player.melee.swing_now()
	var pulses_before_death: int = pulses[0]
	# Deliver the real Health death signal with all three temporary effects
	# primed; active invulnerability otherwise prevents a damage-based death.
	player.health.health = 0.0
	player.health.died.emit(enemy_source)
	_check("death cancels shield overlay and invulnerability", not player.shield.is_active() and not player.shield._overlay.visible and not player.health.invulnerable)
	_check("death clears parry storage and orbiting bullets", traits.stored_rounds == 0 and traits.parry_remaining == 0.0 and not player.health.parrying and traits._orbs.all(func(orb: MeshInstance3D): return not orb.visible))
	_check("death cancels blade and does not trigger shield counter", not player.melee.view_visible() and pulses[0] == pulses_before_death)
	arena.queue_free()
	await get_tree().process_frame
	# Let the audio server consume the players' queued stop commands before
	# engine shutdown. A frame alone can be shorter than its next audio mix.
	await get_tree().create_timer(0.15).timeout
	_finished = true


func _target(parent: Node, position: Vector3, team: int) -> Health:
	var node := Node3D.new()
	node.position = position
	var health := Health.new()
	health.max_health = 1000.0
	health.team = team
	node.add_child(health)
	for index in 2:
		var hitbox := Hitbox.new()
		hitbox.body_part = Hitbox.BodyPart.BODY if index == 0 else Hitbox.BodyPart.HEAD
		var shape := SphereShape3D.new()
		shape.radius = 0.4
		var collision := CollisionShape3D.new()
		collision.shape = shape
		hitbox.add_child(collision)
		hitbox.position.y = index * 0.6
		node.add_child(hitbox)
	parent.add_child(node)
	return health


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
