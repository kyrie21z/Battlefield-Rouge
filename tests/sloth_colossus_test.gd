extends Node
const BENCH := preload("res://tests/sloth_colossus_bench.tscn")
var bench: Node3D
var checks := 0
var failures := 0
var death_events := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bench = BENCH.instantiate()
	add_child(bench)
	await frames(4)
	var boss: SlothColossus = bench.colossus
	var player: Player = bench.player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	boss.position = Vector3.ZERO
	player.position = Vector3(0,0,8)
	boss.realm_defeated.connect(func(_realm: int):death_events+=1)
	check("colossus has boss Health and real crystal skeleton",boss.is_boss and boss.health.max_health==SlothColossus.BASE_HEALTH and boss.health.max_health==1750.0 and boss.visual.skeleton.get_bone_count()==24)
	check("five solid-looking amber dorsal plates frame its curled silhouette",boss.visual.armor.size()==5 and boss.visual.boss_form)
	check("slam begins with its own visible windup",boss.start_attack(0))
	var slam := boss.active_attack
	await frames(50)
	check("slam warning cannot deal damage early",player.health.health==100 and slam.phase==0)
	var paused_elapsed := slam.elapsed
	get_tree().paused = true
	await frames(5)
	check("pause freezes boss attack clocks",slam.elapsed==paused_elapsed)
	get_tree().paused = false
	await frames(100)
	check("expanding slam hits the player's actual Health",player.health.health==78 and slam.hit_count==1)
	await frames(80)
	check("slam ends and gives a recovery window",not is_instance_valid(boss.active_attack) and boss.recovery_left>0)
	check("phase 1 recovery and cooldown tighten to 0.95/0.85",is_equal_approx(boss.recovery_left,0.95) and is_equal_approx(boss.cooldown_left,0.85))
	player.health.health = 100
	player.position = Vector3(0,1.3,8)
	boss.start_attack(0)
	await frames(220)
	check("jumping above the low shock wave avoids damage",player.health.health==100)
	player.position = Vector3(0,0,8)
	boss.start_attack(1)
	await frames(103)
	var crystals := projectiles()
	check("armour barrage releases seven suspended physical shots",crystals.size()==7 and crystals.all(func(p):return not p.released))
	await frames(50)
	check("armour shards release after their independent delays",projectiles().any(func(p):return p.released))
	for p in projectiles():
		p.queue_free()
	await frames(4)
	clear_attack(boss)
	player.health.health = 100
	player.position = Vector3(0,0,10)
	var wall := SlothRealm.box(bench,Vector3(0,2.5,5),Vector3(8,5,0.5),SlothRealm.material(Color.WHITE,0,1),true)
	boss.start_attack(2)
	await frames(240)
	check("WORLD cover blocks the rotating gravity ray",player.health.health==100)
	wall.queue_free()
	await frames(4)
	clear_attack(boss)
	boss.start_attack(2)
	await frames(112)
	check("pendulum ray activates after a long telegraph",is_instance_valid(boss.active_attack) and boss.active_attack.phase==1)
	# Move the real player onto the current beam, then let its swept ray resolve.
	var ray := boss.active_attack
	var heading := ray._aim.rotated(Vector3.UP,sin((ray.elapsed-ray.warning_time())*2.2)*0.80)
	var at := boss._eye()+heading*8
	player.position = Vector3(at.x,at.y-1.0,at.z)
	await frames(3)
	check("uncovered gravity ray can hit real player Health",player.health.health<100)
	check("the ray's stasis is stronger than a slow walk",is_equal_approx(player.realm_effects.move_multiplier,0.45) and player.realm_effects.dash_blocked==false and is_equal_approx(player.realm_effects.dash_distance_multiplier,0.65))
	clear_attack(boss)
	# Resin mortar: real hazard footprints on the ground the player occupies.
	player.health.health = 100
	player.position = Vector3(0,0,8)
	boss.start_attack(3)
	await frames(200)
	var pools := resin_pools()
	check("resin mortar marks the player's ground plus one flank",pools.size()==2 and pools.all(func(p):return p.landed))
	await frames(40)
	check("standing in landed resin actually costs Health",player.health.health<100)
	for pool in pools:
		pool.queue_free()
	await frames(4)
	# Amber hibernation: shell mitigation, shield regen, then both interrupts.
	player.health.health = 100
	player.position = Vector3(0,0,8)
	boss.health.shield_points = 0
	boss.start_attack(4)
	await frames(45)
	check("amber hibernation pulls in and projects a 9m stasis dial",boss.hibernating and is_instance_valid(boss.active_attack) and is_equal_approx(boss.active_attack._field.reach,9.0))
	check("the dial blocks dash and drags movement to 65%",player.realm_effects.dash_blocked and is_equal_approx(player.realm_effects.move_multiplier,0.65))
	await frames(60)
	check("the shell trickles a 45/s shield back",boss.health.shield_points>20.0 and boss.health.shield_points<=boss.hibernation_shield_cap())
	boss.health.shield_points = 0
	var before_shell := boss.health.health
	boss.health.apply_damage(100,Hitbox.BodyPart.BODY,player)
	check("ordinary damage is cut to 45% while the shell holds",is_equal_approx(before_shell-boss.health.health,45))
	var before_crack := boss.health.health
	boss.health.apply_damage(100,Hitbox.BodyPart.BODY,player)
	check("180 points of fire crack the shell into a 1.2s stagger",not boss.hibernating and is_equal_approx(boss.stagger_left,SlothColossus.STAGGER_TIME) and not is_instance_valid(boss.active_attack) and is_equal_approx(before_crack-boss.health.health,45))
	check("a cracked shell drops the gravity dial immediately",not player.realm_effects.dash_blocked and is_equal_approx(player.realm_effects.move_multiplier,1.0))
	boss.start_attack(4)
	await frames(45)
	boss.health.shield_points = 0
	var before_blade := boss.health.health
	boss.health.apply_damage(55,Hitbox.BodyPart.BODY,player,{"kind":&"blade","tag":&"blade"})
	check("one blade hit cracks the amber outright and lands full damage",not boss.hibernating and boss.stagger_left>0 and is_equal_approx(before_blade-boss.health.health,55))
	# Phase 2 follows the real half-health crossing, not a flag set by the test.
	boss.health.apply_damage(boss.health.max_health*0.5,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	check("half health still opens phase 2 with the authored shield",boss.boss_phase==2 and boss.health.max_shield>=262.0 and boss.health.max_shield<=263.0)
	check("phase 2 barrage escalates to a nine-shot fan",boss.start_attack(1))
	await frames(100)
	check("nine real armour shards hang in phase 2",projectiles().size()==9)
	check("the phase 2 middle pair homes on the player",projectiles().filter(func(p):return is_instance_valid(p.homing_target)).size()==2)
	clear_attack(boss)
	for p in projectiles():
		p.queue_free()
	await frames(4)
	player.health.health = 100
	player.position = Vector3(0,0,8)
	boss.start_attack(0)
	var double_wave: int = 0
	var phase_two_wave := boss.active_attack
	for i in 260:
		if is_instance_valid(phase_two_wave):
			double_wave = maxi(double_wave,phase_two_wave.hit_count)
		await get_tree().physics_frame
	check("phase 2 slam adds a faster second wave (%d hits, %.0f HP)" % [double_wave,player.health.health],player.health.health==56 and double_wave==2)
	# Leave one hazard and one suspended shell alive so death has to clear both.
	boss.start_attack(3)
	await frames(120)
	check("phase 2 mortar widens to three pools",resin_pools().size()==3)
	boss.start_attack(1)
	await frames(90)
	boss.health.apply_damage(5000,Hitbox.BodyPart.BODY,player)
	check("boss death is emitted exactly once",death_events==1)
	boss.health.apply_damage(5000,Hitbox.BodyPart.BODY,player)
	check("repeat damage cannot repeat the realm-clear event",death_events==1)
	check("death cancels whatever attack was running",not is_instance_valid(boss.active_attack))
	check("death takes every owned resin pool with it",resin_pools().is_empty())
	check("death takes every suspended armour shard with it",projectiles().is_empty())
	check("all Rest Zones become dark immediately",not bench.geometry.rest_enabled and bench.geometry.rest_lights.all(func(l):return l.light_energy==0))
	check("the world clock accelerates beyond 140bpm",bench.geometry.clock_bpm==148)
	check("the Colossus bursts into 56 authored rigid pieces",is_instance_valid(boss.visual.realm_shatter) and boss.visual.realm_shatter.pieces.size()==56)
	var ticks: int = bench.geometry.clock_ticks
	await frames(122)
	check("the running clock produces real timed ticks",bench.geometry.clock_ticks>=ticks+4)
	check("boss death creates a real unconsumed Slumber pickup",is_instance_valid(bench.shard) and not player.fragments.has_shard(0))
	player.global_position = bench.shard.global_position
	await frames(3)
	check("walking to the dropped shard acquires its independent ability",player.fragments.has_shard(0))
	check("collecting Slumber does not relight lost Rest Zones",bench.geometry.deprived and not bench.geometry.rest_enabled)
	player.health.health = 60
	player.health.apply_damage(5,Hitbox.BodyPart.BODY,boss)
	var injured := player.health.health
	await frames(240)
	check("Slumber cannot heal before five seconds out of combat",player.health.health==injured)
	await frames(120)
	check("Slumber heals after the actual combat timeout",player.health.health>injured+1.0)
	bench.queue_free()
	await frames(5)
	OS.delay_msec(250)
	await get_tree().process_frame
	print("SLOTH COLOSSUS: %s (%d checks, %d failed)" % ["ALL PASSED" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func projectiles() -> Array[SlothRealmProjectile]:
	var result: Array[SlothRealmProjectile] = []
	for child in bench.get_children():
		if child is SlothRealmProjectile and not child.is_queued_for_deletion():
			result.append(child)
	return result

func resin_pools() -> Array[SlothResinPool]:
	var result: Array[SlothResinPool] = []
	for child in bench.get_children():
		if child is SlothResinPool and not child.is_queued_for_deletion():
			result.append(child)
	return result

func clear_attack(boss: SlothColossus) -> void:
	if is_instance_valid(boss.active_attack):
		boss.active_attack.cancel()
	boss.active_attack = null

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func check(label: String,value: bool) -> void:
	checks += 1
	if not value:
		failures += 1
	print("%s %s" % ["PASS" if value else "FAIL",label])
