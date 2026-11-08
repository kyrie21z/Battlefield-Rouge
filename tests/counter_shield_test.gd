extends Node
## Finite absorption, manual/automatic release and independent immunity checks.

class Source extends Node3D:
	var team := 1

var checks := 0
var failures := 0

func _ready() -> void:
	await _run()
	print("COUNTER SHIELD: %d checks, %d failed" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func _run() -> void:
	var arena := Node3D.new()
	arena.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	var player := load("res://actors/player/player.tscn").instantiate() as Player
	arena.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	player.combat_traits.set_process(false)
	var shield := player.shield
	shield.set_process(false)
	var source := Source.new()
	arena.add_child(source)
	var ally := Source.new()
	ally.team=0
	arena.add_child(ally)
	var target := _target(arena,Vector3(6,1,0))
	var hidden := _target(arena,Vector3(0,1,-4))
	var wall := StaticBody3D.new()
	wall.collision_layer=CollisionLayers.WORLD
	wall.position=Vector3(0,1,-2)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(3,3,0.2)
	collision.shape=box
	wall.add_child(collision)
	arena.add_child(wall)
	for frame in 3:await get_tree().physics_frame
	var pulses := [0]
	player.combat_traits.shield_pulsed.connect(func():pulses[0]+=1)
	_check("shield starts locked",not shield.try_activate())
	player.stats.apply_buff(BuffPool.ALL[7])
	_check("duration card preserves the ordinary timed shield",shield.try_activate()
		and not shield.is_counter_mode() and is_equal_approx(shield.active_remaining,2.5)
		and player.health.invulnerable)
	shield._process(2.51)
	_check("ordinary protection still expires into cooldown",not shield.is_active()
		and not player.health.invulnerable and not shield.try_activate())
	shield.cancel()
	player.stats.clear_buffs()
	player.stats.apply_buff(BuffPool.ALL[6])
	_check("counter card chooses finite absorption mode",shield.is_counter_mode()
		and shield.capacity()==100.0 and shield.try_activate() and not player.health.invulnerable)
	shield._process(300.0)
	_check("unused counter shield remains visible after five minutes",shield.is_active()
		and shield._overlay.visible and shield.cooldown_remaining==0.0 and pulses[0]==0)
	var hp := player.health.health
	player.health.apply_damage(30,Hitbox.BodyPart.BODY,ally)
	_check("friendly hits do not charge the shield",shield.absorbed_damage()==0.0)
	player.health.parrying=true
	player.health.apply_damage(30,Hitbox.BodyPart.BODY,source)
	player.health.parrying=false
	_check("parried hits do not charge the shield",shield.absorbed_damage()==0.0)
	player.health.dash_invulnerable=true
	player.health.apply_damage(30,Hitbox.BodyPart.BODY,source)
	player.health.dash_invulnerable=false
	_check("dash immunity cannot create stored shield damage",shield.absorbed_damage()==0.0)
	player.health.invulnerable=true
	player.health.apply_damage(30,Hitbox.BodyPart.BODY,source)
	shield._process(0.1)
	_check("independent invulnerability is preserved and cannot charge",player.health.invulnerable
		and shield.absorbed_damage()==0.0)
	player.health.invulnerable=false
	player.health.apply_damage(35,Hitbox.BodyPart.BODY,source)
	_check("partial damage is absorbed without losing HP",player.health.health==hp
		and shield.absorbed_damage()==35.0 and is_equal_approx(shield.charge_fraction(),0.35))
	shield._process(30.0)
	_check("charged rim persists after the impact flash and old timeout",shield.is_active()
		and shield._overlay.visible and shield._overlay.charged and shield._overlay.impact_remaining==0)
	get_tree().paused=true
	_check("paused input cannot release the shield",not shield.try_release() and shield.is_active())
	get_tree().paused=false
	var before := target.health
	_check("the same activate action manually releases a partial shield",shield.try_activate()
		and not shield.is_active() and not shield.last_release_automatic)
	_check("manual wave returns only the thirty-five absorbed damage",pulses[0]==1
		and is_equal_approx(before-target.health,35) and hidden.health==1000.0)
	_check("release consumes the charge and starts eight-second cooldown",shield.absorbed_damage()==0
		and shield.cooldown_remaining==8.0 and not shield.try_activate() and not shield.try_release())
	shield._process(8.01)
	shield.try_activate()
	player.health.apply_damage(40,Hitbox.BodyPart.BODY,source)
	_check("below threshold remains raised",shield.is_active() and shield.absorbed_damage()==40)
	before=target.health
	player.health.apply_damage(60,Hitbox.BodyPart.BODY,source)
	_check("reaching threshold automatically ends shield and returns one hundred",not shield.is_active()
		and shield.last_release_automatic and pulses[0]==2 and before-target.health==100.0
		and player.health.health==hp and shield.last_released_damage==100.0)
	shield._process(30.0)
	_check("later feedback updates cannot fire the automatic pulse twice",pulses[0]==2)
	shield.try_activate()
	before=target.health
	player.health.apply_damage(130,Hitbox.BodyPart.BODY,source)
	_check("a breaking hit absorbs capacity and applies only the overflow",player.health.health==hp-30
		and before-target.health==100.0 and pulses[0]==3)
	shield._process(8.01)
	shield.try_activate()
	player.health.apply_damage(10,Hitbox.BodyPart.HEAD,source)
	player.health.apply_damage(10,Hitbox.BodyPart.LIMB,source)
	_check("absorption uses real body-part-scaled damage",shield.absorbed_damage()==31.0)
	shield.cancel()
	player.stats.apply_buff(BuffPool.ALL[6])
	player.stats.apply_buff(BuffPool.ALL[7])
	_check("stacking raises return multiplier and duration card adds capacity",shield.capacity()==125.0
		and player.stats.get_value(Stats.SHIELD_REFLECT_MULTIPLIER)==2.0)
	shield.try_activate()
	before=target.health
	player.health.apply_damage(20,Hitbox.BodyPart.BODY,source)
	shield.try_release()
	_check("two counter layers return actual absorption times two",before-target.health==40)
	shield._process(8.01)
	shield.try_activate()
	var release_count: int = pulses[0]
	shield.try_release()
	_check("empty manual closure never creates a free wave",pulses[0]==release_count
		and not shield.is_active() and shield.cooldown_remaining==8.0)
	shield._process(8.01)
	shield.try_activate()
	player.health.apply_damage(10,Hitbox.BodyPart.BODY,source)
	shield.cancel()
	_check("cancellation clears shield and stored damage without countering",pulses[0]==release_count
		and not shield.is_active() and shield.absorbed_damage()==0 and not shield._overlay.visible)
	shield.try_activate()
	# At capacity callbacks cannot manually duplicate or reopen the same shield.
	var recursive_releases := [0]
	var on_absorb := func(_amount:float):
		if not shield.is_active() and shield.try_release():recursive_releases[0]+=1
	shield.absorbed_hit.connect(on_absorb)
	player.health.apply_damage(125,Hitbox.BodyPart.BODY,source)
	shield.absorbed_hit.disconnect(on_absorb)
	_check("full-hit signal reentrancy cannot release twice",recursive_releases[0]==0
		and pulses[0]==release_count+1)
	shield._process(8.01)
	shield.try_activate()
	var health_before_nested := player.health.health
	release_count=pulses[0]
	var nested_hit := func(_amount:float):player.health.apply_damage(1,Hitbox.BodyPart.BODY,source)
	shield.absorbed_hit.connect(nested_hit)
	player.health.apply_damage(125,Hitbox.BodyPart.BODY,source)
	shield.absorbed_hit.disconnect(nested_hit)
	_check("a nonlethal nested hit resolves before exactly one automatic return",player.health.health==health_before_nested-1
		and pulses[0]==release_count+1 and not shield.is_active())
	shield._process(8.01)
	shield.try_activate()
	player.health.health=5.0
	release_count=pulses[0]
	player.health.apply_damage(140,Hitbox.BodyPart.BODY,source)
	_check("lethal overflow cancels pending reflection rather than firing after death",player.health.is_dead()
		and not shield.is_active() and pulses[0]==release_count and not shield._overlay.visible)
	# Reproduce a full shield's feedback applying another hit before the first
	# hook returns: the inner completion must not release the outer 100 charge
	# before the outer ten-point overflow kills a five-HP player.
	var nested_player := load("res://actors/player/player.tscn").instantiate() as Player
	arena.add_child(nested_player)
	nested_player.set_physics_process(false)
	nested_player.set_process(false)
	nested_player.weapon.set_process(false)
	nested_player.melee.set_process(false)
	nested_player.combat_traits.set_process(false)
	nested_player.shield.set_process(false)
	nested_player.stats.apply_buff(BuffPool.ALL[6])
	var nested_pulses := [0]
	nested_player.combat_traits.shield_pulsed.connect(func():nested_pulses[0]+=1)
	nested_player.shield.try_activate()
	nested_player.health.health=5
	nested_player.shield.absorbed_hit.connect(func(_amount:float):nested_player.health.apply_damage(1,Hitbox.BodyPart.BODY,source))
	nested_player.health.apply_damage(110,Hitbox.BodyPart.BODY,source)
	_check("110 damage with five HP and a nested hit cannot preempt lethal overflow",nested_player.health.is_dead()
		and nested_pulses[0]==0 and not nested_player.shield.is_active() and not nested_player.shield._overlay.visible)
	arena.queue_free()
	await get_tree().process_frame
	OS.delay_msec(150)
	await get_tree().process_frame

func _target(parent:Node3D,at:Vector3) -> Health:
	var actor := Node3D.new()
	actor.position=at
	var health := Health.new()
	health.max_health=1000
	actor.add_child(health)
	for index in 2:
		var hitbox := Hitbox.new()
		hitbox.body_part=Hitbox.BodyPart.BODY if index==0 else Hitbox.BodyPart.HEAD
		hitbox.position.y=float(index)*0.6
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius=0.25
		collision.shape=sphere
		hitbox.add_child(collision)
		actor.add_child(hitbox)
	parent.add_child(actor)
	return health

func _check(label:String,ok:bool) -> void:
	checks+=1
	if not ok:failures+=1
	print("  [%s] %s" % ["ok" if ok else "FAIL",label])
