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
	_check("giant keeps real Enemy/Health and original crystal skeleton",boss.is_boss and boss.health.health == 1300 and boss.visual.skeleton.get_bone_count() == 24)
	boss.begin_move(SorrowMonolith.Move.TIDE)
	await _frames(35)
	_check("wave remains telegraphed before release",boss.tides_released == 0 and boss.action == 1)
	var before := player.health.health
	await _frames(85)
	_check("real full-room tide hits grounded player",boss.tides_released == 1 and player.health.health < before)
	_check("tide pushes actual player with collision motion",player.position.z > 10.2)
	player.position = Vector3(0,0,10)
	boss.begin_move(SorrowMonolith.Move.RAIN)
	before = player.health.health
	await _frames(115)
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
	boss.boon_time_scale = 0
	var water_before := realm.water_level
	var timer_before := boss.action_left
	await _frames(10)
	_check("local time stop freezes rising water and boss deadline",realm.water_level == water_before and boss.action_left == timer_before)
	boss.boon_time_scale = 1
	var hp_before := boss.health.health
	player.weapon._shoot_ray(boss.position+Vector3(0,2,8),Vector3.FORWARD)
	_check("actual gun ray damages giant",boss.health.health < hp_before)
	boss.health.apply_damage(650,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	await _frames(2)
	_check("battle progression raises actual shader water plane",realm.water_level > 0.85 and is_equal_approx(realm.water.position.y,realm.water_level))
	_check("low platform is actually submerged while high platform remains usable",realm.water_level > 0.6 and realm.water_level < 1.2)
	boss.begin_move(SorrowMonolith.Move.RAIN)
	await _frames(70)
	boss.health.apply_damage(5000,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("real giant death emits one Sorrow realm event",defeats == 1)
	_check("defeat dries mirror water and shuts off rain",realm.deprived and not realm.water.visible and not realm.rain.emitting)
	await _frames(2)
	_check("death clears tell, waves and unlanded rain projectiles",boss.tell == null and boss._owned.is_empty() and not get_children().any(func(n:Node):return n is Projectile or n is SorrowTide))
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
