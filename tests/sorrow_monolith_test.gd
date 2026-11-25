extends Node3D
var checks := 0
var failed := 0
var defeats := 0
var player: Player
var realm: SorrowRealm
var boss: SorrowMonolith
func _ready() -> void:
	await _run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("SORROW MONOLITH: %d checks, %d failed" % [checks,failed])
	get_tree().quit(0 if failed == 0 else 1)
func _run() -> void:
	realm = SorrowRealm.new()
	realm.boss_arena = true
	add_child(realm)
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0,0,10)
	add_child(player)
	player.health.max_health = 10000
	player.health.health = 10000
	realm.set_player(player)
	boss = preload("res://actors/boss/sorrow_monolith/sorrow_monolith.tscn").instantiate()
	boss.arena = realm
	add_child(boss)
	boss.setup(player,[])
	player.boons.register_enemy(boss)
	boss.realm_defeated.connect(func(id:int): defeats += 1 if id == 3 else 100)
	await _frames(4)
	_check("giant keeps real Enemy/Health and original crystal skeleton",boss.is_boss and is_equal_approx(boss.health.health,SorrowMonolith.BASE_HEALTH) and boss.visual.skeleton.get_bone_count() == 24)
	boss.begin_move(SorrowMonolith.Move.TIDE)
	await _frames(35)
	_check("wave remains telegraphed before release",boss.tides_released == 0 and boss.action == 1)
	_check("undertow drags wading movement to 0.72x while the tide gathers",is_equal_approx(player.realm_effects.move_multiplier,0.72))
	var before := player.health.health
	await _frames(85)
	_check("real full-room tide hits grounded player",boss.tides_released == 1 and player.health.health < before)
	_check("tide pushes actual player with collision motion",player.position.z > 10.2)
	player.position = Vector3(0,0,10)
	boss.begin_move(SorrowMonolith.Move.RAIN)
	before = player.health.health
	await _frames(70)
	var bolts := get_children().filter(func(n:Node):return n is SorrowGlob)
	var closing: float = bolts[0].global_position.distance_to(player.global_position) if bolts.size() > 0 else 99.0
	await _frames(3)
	_check("rain fires two aimed slowing bolts at the player",bolts.size() == 2 and boss.globs_fired == 2 and bolts[0].global_position.distance_to(player.global_position) < closing)
	await _frames(42)
	_check("locked rain launches 25 actual downward projectiles",boss.tears_released == 25)
	_check("center tear damages actual player hitbox",player.health.health < before)
	boss.begin_move(SorrowMonolith.Move.SLAP)
	var locked := boss.locked_point
	player.position += Vector3.RIGHT*4
	before = player.health.health
	await _frames(70)
	_check("slap aim remains locked and can be dodged",boss.locked_point.is_equal_approx(locked) and player.health.health == before)
	boss.begin_move(SorrowMonolith.Move.SLAP)
	before = player.health.health
	await _frames(70)
	_check("slap punishes staying in marked area",player.health.health < before and boss.slaps == 2)
	boss.action = 2
	boss.action_left = 0.001
	await _frames(1)
	_check("phase 1 recovery tightens to 0.9s",boss.action == 3 and is_equal_approx(boss.action_left,0.9))
	boss.boon_time_scale = 0
	var water_before := realm.water_level
	var timer_before := boss.action_left
	await _frames(10)
	_check("local time stop freezes rising water and boss deadline",realm.water_level == water_before and boss.action_left == timer_before)
	boss.boon_time_scale = 1
	var hp_before := boss.health.health
	player.weapon._shoot_ray(boss.position+Vector3(0,2,8),Vector3.FORWARD)
	_check("actual gun ray damages giant",boss.health.health < hp_before)
	var cries_before := boss.cries
	boss.begin_move(SorrowMonolith.Move.CRY)
	await _frames(125)
	_check("weeping cry expands and lands on the open player",boss.cries == cries_before+1 and boss.action != 1 and player.realm_effects.monochrome > 0.9)
	var choke: Dictionary = player.realm_effects.effects.get(boss.effect_key,{})
	_check("cry chokes reload to 0.55x and stretches cooldowns 1.6x for 2.2s",is_equal_approx(float(choke.get("reload_multiplier",1.0)),0.55) and is_equal_approx(float(choke.get("cooldown_multiplier",1.0)),1.6) and float(choke.get("duration",0.0)) > 1.0 and float(choke.get("duration",0.0)) <= 2.2)
	player.position = Vector3(0,0,10)
	boss.begin_move(SorrowMonolith.Move.RAIN)
	player.position = Vector3(2.5,0,10)
	var drift := player.global_position.distance_to(boss.locked_point)
	await _frames(80)
	_check("rain release drags the wading player back toward the mark",player.global_position.distance_to(boss.locked_point) < drift-0.2)
	boss.health.apply_damage(boss.health.health-boss.health.max_health*0.5,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	await _frames(2)
	_check("half health opens phase 2 with a 15 percent non-regenerating shield",boss.boss_phase == 2 and is_equal_approx(boss.health.max_shield,roundf(SorrowMonolith.BASE_HEALTH*0.15)) and boss.health.shield_regeneration_rate == 0.0)
	_check("battle progression raises actual shader water plane",realm.water_level > 0.8 and is_equal_approx(realm.water.position.y,realm.water_level))
	_check("low platform is actually submerged while high platform remains usable",realm.water_level > 0.6 and realm.water_level < 1.2)
	boss.start_submerge()
	await _frames(6)
	_check("submerge leaves the mirror with no hitbox to shoot",boss.submerged and boss.visual.submerged and (boss.get_node("TorsoHitbox") as Hitbox).collision_layer == CollisionLayers.NONE)
	var surfacing := player.global_position
	await _frames(60)
	var flat := Vector2(boss.global_position.x-surfacing.x,boss.global_position.z-surfacing.z).length()
	_check("hidden monolith resurfaces 5.5-7.5m from the player",not boss.submerged and flat >= SorrowMonolith.AMBUSH_NEAR-0.05 and flat <= SorrowMonolith.AMBUSH_FAR+0.05)
	_check("resurfaced monolith restores hitboxes and strikes at once",(boss.get_node("TorsoHitbox") as Hitbox).collision_layer == CollisionLayers.HITBOXES and not boss.visual.submerged and boss.action == 1 and (boss.move_kind == SorrowMonolith.Move.SLAP or boss.move_kind == SorrowMonolith.Move.CRY))
	boss.begin_move(SorrowMonolith.Move.RAIN)
	await _frames(70)
	boss.health.apply_damage(5000,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("real giant death emits one Sorrow realm event",defeats == 1)
	_check("defeat dries mirror water and shuts off rain",realm.deprived and not realm.water.visible and not realm.rain.emitting)
	await _frames(2)
	_check("death clears tell, waves, wails and unlanded rain projectiles",boss.tell == null and boss._owned.is_empty() and not get_children().any(func(n:Node):return n is Projectile or n is SorrowTide or n is SorrowCry))
	_check("death releases the choking and undertow effects on the player",not player.realm_effects.effects.has(boss.effect_key) and not player.realm_effects.effects.has(StringName("%s_undertow" % boss.effect_key)))
	_check("giant fractures into 56 physical cyan pieces",boss.visual.shatter.fragments.size() == 56)
	player.fragments.configure_deprivation([3])
	_check("post-boss ordinary buffering stays deprived",player.health.unbuffered and not player.fragments.has_shard(3))
	var shard := preload("res://zone/psyche_shard_pickup.tscn").instantiate() as PsycheShardPickup
	shard.realm = 3
	shard.position = player.position
	shard.setup(player)
	add_child(shard)
	await _frames(2)
	_check("physical Tenderness pickup enables independent 40 barrier",player.fragments.has_shard(3) and is_equal_approx(player.fragments.barrier,PsycheFragments.TENDERNESS_CAPACITY) and not is_instance_valid(shard))
	player.health.health = player.health.max_health
	before = player.health.health
	player.health.apply_damage(PsycheFragments.TENDERNESS_CAPACITY+20.0,Hitbox.BodyPart.BODY,null)
	_check("independent barrier absorbs 40 and actual overflow shatters HP",is_equal_approx(player.health.health,before-20) and player.fragments.barrier == 0)
	_check("pickup never restores ordinary buffering and real HP loss sounds brittle",player.health.unbuffered and player.fragments.brittle_hits > 0)
	await _frames(130)
	_check("giant physical shards fully clean up",not is_instance_valid(boss.visual.shatter))
	boss.health.apply_damage(5000,Hitbox.BodyPart.BODY,player)
	_check("duplicate damage cannot duplicate Sorrow completion",defeats == 1)
func _frames(count:int) -> void:
	for i in count:
		await get_tree().physics_frame
func _check(label:String,ok:bool) -> void:
	checks += 1
	failed += 0 if ok else 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
