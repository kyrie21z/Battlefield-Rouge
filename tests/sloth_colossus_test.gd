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
	check("colossus has boss Health and real crystal skeleton",boss.is_boss and boss.health.max_health==1400 and boss.visual.skeleton.get_bone_count()==24)
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
	if is_instance_valid(boss.active_attack):
		boss.active_attack.cancel()
		boss.active_attack = null
	player.health.health = 100
	player.position = Vector3(0,0,10)
	var wall := SlothRealm.box(bench,Vector3(0,2.5,5),Vector3(8,5,0.5),SlothRealm.material(Color.WHITE,0,1),true)
	boss.start_attack(2)
	await frames(240)
	check("WORLD cover blocks the rotating gravity ray",player.health.health==100)
	wall.queue_free()
	await frames(4)
	if is_instance_valid(boss.active_attack):
		boss.active_attack.cancel()
		boss.active_attack = null
	boss.start_attack(2)
	await frames(112)
	check("pendulum ray activates after a long telegraph",is_instance_valid(boss.active_attack) and boss.active_attack.phase==1)
	# Move the real player onto the current beam, then let its swept ray resolve.
	var ray := boss.active_attack
	var heading := ray._aim.rotated(Vector3.UP,sin((ray.elapsed-ray.warning_time())*2.2)*0.55)
	var at := boss._eye()+heading*8
	player.position = Vector3(at.x,at.y-1.0,at.z)
	await frames(3)
	check("uncovered gravity ray can hit real player Health",player.health.health<100)
	boss.health.apply_damage(5000,Hitbox.BodyPart.BODY,player)
	check("boss death is emitted exactly once",death_events==1)
	boss.health.apply_damage(5000,Hitbox.BodyPart.BODY,player)
	check("repeat damage cannot repeat the realm-clear event",death_events==1)
	check("death cancels the active ray",not is_instance_valid(boss.active_attack))
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

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func check(label: String,value: bool) -> void:
	checks += 1
	if not value:
		failures += 1
	print("%s %s" % ["PASS" if value else "FAIL",label])
