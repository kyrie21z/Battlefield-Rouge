extends Node3D
var checks := 0
var failed := 0
var player: Player
var realm: SorrowRealm
const ENEMY := preload("res://actors/enemy/sorrow/sorrow_realm_enemy.tscn")
func _ready() -> void:
	await _run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("SORROW REALM: %d checks, %d failed" % [checks,failed])
	get_tree().quit(0 if failed == 0 else 1)
func _run() -> void:
	realm = SorrowRealm.new()
	add_child(realm)
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0,0,8)
	add_child(player)
	player.health.max_health = 10000
	player.health.health = 10000
	realm.set_player(player)
	await _frames(5)
	_check("mirror water shader, eight melted pillars and four low platforms exist",realm.water.material_override is ShaderMaterial and realm.columns.size() == 8 and realm.platforms.size() == 4)
	_check("silent white rain falls over ankle water",realm.rain.emitting and is_equal_approx(realm.water_level,0.14))
	player.apply_external_impulse(Vector3.RIGHT,4.0,0.4)
	await _frames(30)
	_check("actual player movement emits water ripple and splash",realm.ripple_count > 0 and realm.footstep_count > 0)
	var sunken := _enemy(1,Vector3(0,0,5))
	await _frames(3)
	_check("Sorrow body retains original 24 bones",sunken.visual.skeleton.get_bone_count() == 24)
	_check("live gravity aura changes player jump and dash reach",player.realm_effects.jump_multiplier < 0.3 and player.realm_effects.dash_distance_multiplier < 0.4)
	player.position = Vector3(12,0,8)
	await _frames(2)
	_check("leaving gravity range restores movement",player.realm_effects.jump_multiplier == 1 and player.realm_effects.dash_distance_multiplier == 1)
	player.position = Vector3(0,0,8)
	await _frames(2)
	sunken.health.apply_damage(5000,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("source death clears its gravity constraint immediately",player.realm_effects.jump_multiplier == 1)
	_check("cyan death creates 56 actual rigid crystal droplets",sunken.visual.shatter.fragments.size() == 56 and sunken.visual.shatter.fragments[0].node is RigidBody3D)
	var mat := ((sunken.visual.shatter.fragments[0].node as Node).get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	_check("shards preserve source cyan material",(mat.get_shader_parameter("base_color") as Color).b > 0.2)
	var corroder := _enemy(0,Vector3(0,0,0))
	corroder.start_dive()
	_check("diving removes hittable body while leaving water silhouette",corroder.visual.submerged and (corroder.get_node("TorsoHitbox") as Hitbox).collision_layer == 0)
	await _frames(72)
	_check("Corroder resurfaces behind player with restored hitboxes",corroder.dives == 1 and corroder.global_position.z > player.global_position.z and (corroder.get_node("TorsoHitbox") as Hitbox).collision_layer == CollisionLayers.HITBOXES)
	player.position = Vector3(0,0,22)
	corroder.start_dive()
	corroder.resurface()
	_check("behind-player emergence stays inside real WORLD boundary",corroder.position.z > 22 and corroder.position.z < 23.6)
	corroder.set_physics_process(false)
	corroder.position = Vector3(0,0,3)
	player.position = Vector3(0,0,8)
	await _frames(2)
	var before := player.health.health
	corroder.spit()
	await _frames(34)
	_check("actual slime projectile damages and slows player",player.health.health < before and player.realm_effects.move_multiplier < 0.5)
	corroder.health.apply_damage(5000,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("slime source death clears slow and flying globs",player.realm_effects.move_multiplier == 1 and corroder._owned.is_empty())
	var mourner := _enemy(2,Vector3(0,0,2))
	mourner.set_physics_process(false)
	mourner.release_cry()
	await _frames(35)
	_check("actual expanding cry makes screen monochrome",player.realm_effects.monochrome == 1)
	_check("cry changes real reload speed and skill cooldown stats",player.stats.get_value(Stats.RELOAD_SPEED) < 0.5 and player.stats.get_value(Stats.SHIELD_COOLDOWN) >= 2.0)
	var left: float = player.realm_effects.effects[mourner.effect_key].duration
	get_tree().paused = true
	for i in 4:
		await get_tree().process_frame
	_check("pause does not consume source effect duration",is_equal_approx(player.realm_effects.effects[mourner.effect_key].duration,left))
	get_tree().paused = false
	mourner.queue_free()
	await _frames(2)
	_check("caster removal clears cry monochrome and reload debuff",player.realm_effects.monochrome == 0 and player.stats.get_value(Stats.RELOAD_SPEED) == 1)
	await _frames(130)
	_check("all cyan rigid droplets expire",not is_instance_valid(sunken.visual.shatter) and not is_instance_valid(corroder.visual.shatter))
	realm.set_water_level(0.9)
	_check("water visibly floods lower platforms",realm.water.position.y > realm.platforms[0].position.y*2)
	realm.set_deprivation(true)
	_check("deprivation fully evaporates water and stops rain",not realm.water.visible and not realm.rain.emitting)
	var ripples := realm.ripple_count
	realm.add_ripple(player.position)
	_check("dry world creates no phantom water ripples",realm.ripple_count == ripples)
func _enemy(kind: int,pos: Vector3) -> SorrowRealmEnemy:
	var actor := ENEMY.instantiate() as SorrowRealmEnemy
	actor.variant = kind
	actor.position = pos
	actor.arena = realm
	add_child(actor)
	actor.setup(player,[])
	return actor
func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
func _check(label: String,ok: bool) -> void:
	checks += 1
	failed += 0 if ok else 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
