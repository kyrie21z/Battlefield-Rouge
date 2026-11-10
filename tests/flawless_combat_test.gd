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
	check("white humanoid retains 24 bones and real original gun/blade",boss.visual.skeleton.get_bone_count()==24 and boss.visual.gun != null and boss.visual.blade != null)
	check("final loadout preserves all four ordinary deprivations",player.health.unbuffered and not boss.ordinary_impacts_enabled and not player.realm_effects.warnings_enabled)
	boss.begin_move(FlawlessDoppelganger.Move.GUN)
	var hp := player.health.health
	await frames(75)
	check("fast gun burst launches four real swept bullets",boss.shots==4)
	check("Tenderness absorbs real burst without restoring ordinary shield",player.fragments.barrier<60 and player.health.health==hp and player.health.unbuffered)
	boss.begin_move(FlawlessDoppelganger.Move.DASH_BLADE)
	var start := boss.position
	var lock := boss.locked_direction
	await frames(37)
	player.position += Vector3.RIGHT*5
	await frames(21)
	check("fast slide physically crosses arena",boss.position.distance_to(start)>4)
	check("slide commits to direction and permits dodge",boss.locked_direction.is_equal_approx(lock) and boss.slashes==1)
	boss.position = Vector3.ZERO
	player.position = Vector3(0,0,8)
	player.fragments.barrier = 0
	boss.begin_move(FlawlessDoppelganger.Move.DASH_BLADE)
	hp = player.health.health
	await frames(60)
	check("dash blade deals actual HP damage when not dodged",player.health.health<hp and boss.slashes==2)
	await frames(35)
	player.position = boss.position+Vector3(5,0,4)

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
