extends "res://tests/flawless_bench.gd"
var checks := 0
var failed := 0
var boss: FlawlessDoppelganger
func _ready() -> void:
	await _run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("FLAWLESS COMBAT: %d checks, %d failed" % [checks,failed])
	get_tree().quit(0 if failed == 0 else 1)
func _run() -> void:
	build_arena()
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0,0,8)
	add_child(player)
	player.health.max_health = 10000
	player.health.health = 10000
	player.fragments.configure_deprivation([0,1,2,3])
	for realm in 4:
		player.fragments.acquire(realm)
	boss = preload("res://actors/boss/flawless_doppelganger/flawless_doppelganger.tscn").instantiate()
	add_child(boss)
	boss.setup(player,[])
	player.boons.register_enemy(boss)
	boss.set_combat_active(true)
	await frames(3)
	check("final shell enters with the 3600 HP endgame body",boss.health.max_health==3600.0 and boss.health.health==3600.0)
	check("white humanoid retains 24 bones and real original gun/blade",boss.visual.skeleton.get_bone_count()==24 and boss.visual.gun != null and boss.visual.blade != null)
	check("final loadout preserves all four ordinary deprivations",player.health.unbuffered and not boss.ordinary_impacts_enabled and not player.realm_effects.warnings_enabled)
	boss.begin_move(FlawlessDoppelganger.Move.GUN)
	var hp := player.health.health
	await frames(75)
	check("fast gun burst launches four real swept bullets",boss.shots==4)
	check("Tenderness absorbs real burst without restoring ordinary shield",is_zero_approx(player.fragments.barrier) and player.health.health<hp and hp-player.health.health<16.5 and player.health.unbuffered)
	boss.locked_point = player.global_position+Vector3.UP
	player.fragments.barrier = 0
	hp = player.health.health
	boss._fire()
	await frames(18)
	check("a real gun round deals its final 14 damage",is_equal_approx(hp-player.health.health,14.0))
	boss.begin_move(FlawlessDoppelganger.Move.DASH_BLADE)
	var start := boss.position
	var lock := boss.locked_direction
	await frames(37)
	player.position += Vector3.RIGHT*5
	await frames(21)
	check("fast slide physically crosses arena",boss.position.distance_to(start)>4)
	check("slide commits to direction and permits dodge",boss.locked_direction.is_equal_approx(lock) and boss.slashes==1)
	var wave: FlawlessBullet
	for ref in boss._owned:
		var live := ref.get_ref() as FlawlessBullet
		if is_instance_valid(live) and live.crescent:
			wave = live
	check("dash blade leaves a short parryable crescent",boss.crescents==1 and wave != null
		and is_equal_approx(wave.damage,16.0) and is_equal_approx(wave.speed,24.0) and is_equal_approx(wave.max_distance,14.0))
	boss.position = Vector3.ZERO
	player.position = Vector3(0,0,8)
	player.fragments.barrier = 0
	boss.begin_move(FlawlessDoppelganger.Move.DASH_BLADE)
	hp = player.health.health
	await frames(60)
	check("dash blade and crescent land for 28 + 16 when not dodged",is_equal_approx(hp-player.health.health,44.0) and boss.slashes==2)
	await frames(35)
	player.position = boss.position+Vector3(5,0,4)

	boss.position = Vector3(0,0,2)
	player.position = Vector3(0,0,8)
	boss.phase = FlawlessDoppelganger.Phase.WINDUP
	boss.move_kind = FlawlessDoppelganger.Move.GUN
	boss.phase_left = 10
	boss.locked_direction = Vector3.BACK
	boss.health.health = boss.health.max_health
	player.fragments.barrier = 0
	var parry_hp := player.health.health
	var parry_boss_hp := boss.health.health
	player.melee.swing_now()
	boss._slash()
	var crescent: FlawlessBullet
	for ref in boss._owned:
		var live := ref.get_ref() as FlawlessBullet
		if is_instance_valid(live) and live.crescent:
			crescent = live
	check("slash launches the parryable crescent round",crescent != null and is_equal_approx(crescent.damage,16.0))
	await frames(20)
	check("Mind-Blade parries the crescent and reflects it",player.health.health==parry_hp and boss.health.health<parry_boss_hp and boss.slashes==3)

	boss.position = Vector3(0,0,0)
	player.position = Vector3(0,0,8)
	boss.health.health = boss.health.max_health
	boss.phase = FlawlessDoppelganger.Phase.WINDUP
	boss.move_kind = FlawlessDoppelganger.Move.GUN
	boss.phase_left = 5
	boss._evade_cooldown = 0
	boss._evade_left = 0
	player.fragments.barrier = 0
	await frames(2)
	var evade_start := boss.position
	var evade_hp := boss.health.health
	player.weapon._shoot_ray(boss.position+Vector3(0,1.15,6),Vector3.FORWARD)
	check("incoming gunfire triggers a mirror side-dash",boss._evade_left>0 and boss._evade_cooldown>4.4
		and is_equal_approx(boss.phase_left,0.05) and boss.health.health<evade_hp)
	await frames(14)
	check("the side-dash physically leaves the firing lane",boss.position.distance_to(evade_start)>2.0)
	var evade_cd := boss._evade_cooldown
	player.weapon._shoot_ray(boss.position+Vector3(0,1.15,6),Vector3.FORWARD)
	check("the mirror dash respects its cooldown",boss._evade_left<=0 and boss._evade_cooldown<=evade_cd and boss._evade_cooldown>0)

	boss.health.health = boss.health.max_health
	boss._recover()
	check("readable recover window holds above 55% HP",boss.phase==FlawlessDoppelganger.Phase.RECOVER and is_equal_approx(boss.phase_left,0.85))
	boss.phase_left = 0
	await frames(1)
	check("readable wait gap holds above 55% HP",boss.phase==FlawlessDoppelganger.Phase.WAIT and is_equal_approx(boss.phase_left,0.25))
	boss.health.health = boss.health.max_health*0.6
	boss._recover()
	check("60% HP still keeps the readable recover window",is_equal_approx(boss.phase_left,0.85))
	boss.health.health = boss.health.max_health*0.5
	boss._recover()
	check("high pressure compresses the recover window to 0.55 s",boss.phase==FlawlessDoppelganger.Phase.RECOVER and is_equal_approx(boss.phase_left,0.55))
	boss.phase_left = 0
	await frames(1)
	check("high pressure compresses the wait gap to 0.15 s",boss.phase==FlawlessDoppelganger.Phase.WAIT and is_equal_approx(boss.phase_left,0.15))
	boss.health.health = boss.health.max_health
	boss.phase_left = 1
	await frames(1)
	var calm_clock := boss.phase_left
	await frames(10)
	calm_clock -= boss.phase_left
	boss.health.health = boss.health.max_health*0.5
	boss.phase_left = 1
	await frames(1)
	var pressure_clock := boss.phase_left
	await frames(10)
	pressure_clock -= boss.phase_left
	check("high pressure advances the boss clock at 1.30x",absf(pressure_clock/calm_clock-1.30)<0.02)
	boss.move_kind = FlawlessDoppelganger.Move.GUN
	boss.phase = FlawlessDoppelganger.Phase.FIRING
	boss._burst_left = 1
	boss._shot_left = 0
	boss._chained = false
	var chain_shots := boss.shots
	await frames(2)
	check("high pressure chains the fourth round into a dash",boss.move_kind==FlawlessDoppelganger.Move.DASH_BLADE
		and boss.phase==FlawlessDoppelganger.Phase.WINDUP)
	check("high pressure fourth round splits into three bullets",boss.shots>=chain_shots+3)
	boss.health.health = boss.health.max_health

	boss.phase = FlawlessDoppelganger.Phase.GUARD
	boss.phase_left = 5
	var before := boss.health.health
	player.weapon._shoot_ray(boss.position+Vector3(0,1.15,6),Vector3.FORWARD)
	check("perfect guard intercepts actual pistol ray",boss.health.health==before and boss.guard_blocks>0)
	player.position = boss.position+Vector3(0,0,5)
	check("equipped Slumber Q activates through shared live API",player.fragments.try_slumber_resonance())
	check("Slumber breaks guard and slows independent boss clock",boss.phase==FlawlessDoppelganger.Phase.EXPOSED and boss.tempo_multiplier()==0.25)
	var deadline := boss.phase_left
	await frames(12)
	check("boss exposed timer advances at slowed rate",deadline-boss.phase_left<0.07 and deadline>boss.phase_left)
	check("Q has real cooldown, not a repeated free interrupt",not player.fragments.try_slumber_resonance() and player.fragments.resonance_cooldown>9)
	var frozen := boss.resonance_left
	get_tree().paused = true
	for i in 4:
		await get_tree().process_frame
	check("pause preserves resonance and boss clock",is_equal_approx(boss.resonance_left,frozen))
	get_tree().paused = false
	player.position = boss.position+Vector3(4,0,3)
	await frames(2)
	player.stats.set_modifier(&"forced_crit_probe",{Stats.CRIT_CHANCE:{"add":1.0}})
	before = boss.health.health
	player.weapon._shoot_ray(boss.position+Vector3(0,1.15,6),Vector3.FORWARD)
	check("real critical weapon hit exploits exposed shell",boss.health.health<before-60 and boss.critical_weak_hits>0)
	player.stats.remove_modifier(&"forced_crit_probe")
	check("Vigilance remains the independent crit modifier",player.stats.get_value(Stats.CRIT_CHANCE)>=0.15 and player.fragments.has_shard(1))

	boss.resonance_left = 0
	boss.phase = FlawlessDoppelganger.Phase.GUARD
	boss.phase_left = 20
	boss.guard_hits_taken = 0
	for i in 120:
		if boss._impact_left <= 0 and player.fragments._counter_left <= 0:
			break
		await frames(1)
	boss.position = Vector3(11,0,0)
	player.position = Vector3(9,0,0)
	var wall := FlawlessFractureWall.new()
	wall.position = Vector3(13.5,1.5,0)
	add_child(wall)
	await frames(3)
	boss.apply_impact(Vector3.RIGHT,25,1)
	check("ordinary knockback cannot push the final shell",boss._impact_left<=0)
	player.fragments.barrier = 0
	player.health.apply_damage(5,Hitbox.BodyPart.BODY,boss)
	check("actual incoming damage starts independent Spite motion",boss._impact_left>0 and player.fragments.counterpushes>0)
	await frames(30)
	check("Spite drives real WORLD collision and breaks wall",wall.broken and wall.pieces==12 and boss.wall_breaks==1)
	check("wall impact opens shield without restoring ordinary knockback",boss.phase==FlawlessDoppelganger.Phase.EXPOSED and not boss.ordinary_impacts_enabled)

	boss.position = Vector3(0,0,0)
	player.position = Vector3(0,0,7)
	await frames(3)
	boss.health.health = boss.health.max_health
	boss.phase = FlawlessDoppelganger.Phase.GUARD
	boss.phase_left = 10
	boss.guard_hits_taken = 0
	boss.guard_blocks = 0
	player.fragments.barrier = 0
	player.health.health = player.health.max_health
	var riposte_hp := player.health.health
	var guarded_hp := boss.health.health
	boss.boon_stunned = true
	player.weapon._shoot_ray(boss.position+Vector3(0,1.15,6),Vector3.FORWARD)
	player.weapon._shoot_ray(boss.position+Vector3(0,1.15,6),Vector3.FORWARD)
	await frames(6)
	check("stunned doppelganger cannot guard-riposte gunfire",boss.ripostes==0 and is_equal_approx(player.health.health,riposte_hp))
	boss.boon_stunned = false
	boss.health.health = guarded_hp
	boss.phase = FlawlessDoppelganger.Phase.GUARD
	boss.phase_left = 10
	boss.guard_hits_taken = 0
	boss.guard_blocks = 0
	player.weapon._shoot_ray(boss.position+Vector3(0,1.15,6),Vector3.FORWARD)
	check("first blocked round keeps the perfect guard",boss.health.health==guarded_hp and boss.guard_hits_taken==1 and boss.ripostes==0)
	player.weapon._shoot_ray(boss.position+Vector3(0,1.15,6),Vector3.FORWARD)
	check("second blocked round triggers the pride riposte",boss.ripostes==1
		and boss.phase==FlawlessDoppelganger.Phase.WAIT and boss.move_kind==FlawlessDoppelganger.Move.DASH_BLADE)
	await frames(16)
	check("riposte round lands its 18 damage",is_equal_approx(riposte_hp-player.health.health,18.0))
	var killed := 0
	boss.defeated.connect(func(): killed+=1)
	boss.health.apply_damage(99999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	check("real death scatters white crystal into 56 rigid fragments",boss.health.is_dead() and boss.visual.shatter.fragments.size()==56)
	await frames(130)
	check("final dust and all bullets clean up",not is_instance_valid(boss.visual.shatter) and boss._owned.is_empty())
func frames(count:int) -> void:
	for i in count:
		await get_tree().physics_frame
func check(label:String,ok:bool) -> void:
	checks+=1
	failed+=0 if ok else 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
