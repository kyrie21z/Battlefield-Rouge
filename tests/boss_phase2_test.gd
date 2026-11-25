extends Node3D
var checks := 0
var failed := 0
var section: Node3D
var player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _sloth()
	await _fear()
	await _wrath()
	await _sorrow()
	await _campaign_stage()
	await _solo_stage()
	OS.delay_msec(250)
	await get_tree().process_frame
	print("BOSS PHASE2: %d checks, %d failed" % [checks,failed])
	get_tree().quit(0 if failed == 0 else 1)

func _new_section() -> void:
	section = Node3D.new()
	section.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(section)

func _end_section() -> void:
	get_tree().paused = false
	section.queue_free()
	await _frames(3)

func _make_player(at: Vector3) -> void:
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = at
	section.add_child(player)
	player.health.max_health = 10000
	player.health.health = 10000
	player.set_physics_process(false)

func _half_damage(boss: Enemy) -> void:
	boss.health.apply_damage(boss.health.health-boss.health.max_health*0.5,
		Hitbox.BodyPart.BODY,player,{"true_damage":true})

func _sloth() -> void:
	_new_section()
	var realm := SlothRealm.new()
	realm.boss_arena = true
	section.add_child(realm)
	_make_player(Vector3(0,0.1,10))
	realm.set_player(player)
	var boss := preload("res://actors/boss/sloth_colossus/sloth_colossus.tscn").instantiate() as SlothColossus
	boss.arena = realm
	boss.position = Vector3(0,0,-8)
	section.add_child(boss)
	boss.setup(player,[])
	player.boons.register_enemy(boss)
	boss.set_physics_process(false)
	var phases := [0]
	boss.phase_changed.connect(func(_p:int): phases[0]+=1)
	await _frames(3)
	_half_damage(boss)
	_check("colossus crosses half health into irreversible phase 2 once",boss.boss_phase==2 and phases[0]==1 and is_equal_approx(boss.health.health,SlothColossus.BASE_HEALTH*0.5))
	_check("phase 2 grants a 15% non-regenerating shield and 1.2 tempo",boss.health.max_shield==roundf(SlothColossus.BASE_HEALTH*0.15) and boss.health.shield_points==boss.health.max_shield and boss.health.shield_regeneration_rate==0.0 and boss.boss_phase_tempo_scale==1.20)
	boss.health.apply_damage(100,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("further damage never re-triggers the transition",phases[0]==1 and boss.boss_phase==2)
	player.boons.set_status(boss,&"probe",60.0,1.0,1.0,false,1.0,false,0.6)
	boss.set_realm_tempo(1.1)
	_check("slow card, realm tempo and phase tempo stay orthogonal",is_equal_approx(boss.effective_attack_scale(),0.6*1.1*1.2) and is_equal_approx(boss.effective_windup_scale(),1.0/(1.1*1.2)))
	player.boons.set_status(boss,&"probe",60.0,1.0,1.0,false,1.0,false,1.0)
	boss.set_realm_tempo(1.0)
	boss.health.break_shield()
	await _frames(60)
	_check("broken phase shield never regenerates",boss.health.shield_points==0.0)
	boss.start_attack(1)
	await _frames(90)
	var shots := 0
	for child in section.get_children():
		if child is SlothRealmProjectile and not child.is_queued_for_deletion():
			shots += 1
	_check("phase 2 armour barrage escalates to a nine-shot fan",shots==9)
	boss.active_attack.finish()
	_check("phase 2 recovery and cooldown tighten to 1.0/0.9",is_equal_approx(boss.recovery_left,1.0) and is_equal_approx(boss.cooldown_left,0.9))
	var fresh := preload("res://actors/boss/sloth_colossus/sloth_colossus.tscn").instantiate() as SlothColossus
	fresh.arena = realm
	fresh.position = Vector3(6,0,-8)
	section.add_child(fresh)
	fresh.setup(player,[])
	fresh.set_physics_process(false)
	var fresh_phases := [0]
	fresh.phase_changed.connect(func(_p:int): fresh_phases[0]+=1)
	fresh.health.apply_damage(9999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("lethal-from-full never enters phase 2",fresh.boss_phase==1 and fresh_phases[0]==0 and fresh.health.shield_points==0.0)
	await _end_section()

func _fear() -> void:
	_new_section()
	var realm := FearRealm.new()
	realm.boss_arena = true
	section.add_child(realm)
	_make_player(Vector3(0,0.02,8))
	player.dash.set_physics_process(false)
	realm.set_player(player)
	var boss := preload("res://actors/boss/fear_oculus/fear_oculus.tscn").instantiate() as FearOculus
	boss.arena = realm
	boss.position = Vector3(0,0,-8)
	section.add_child(boss)
	boss.setup(player,[])
	player.boons.register_enemy(boss)
	boss.set_physics_process(false)
	var phases := [0]
	boss.phase_changed.connect(func(_p:int): phases[0]+=1)
	await _frames(3)
	_half_damage(boss)
	_check("oculus enters phase 2 with a 15% shield",boss.boss_phase==2 and phases[0]==1 and boss.health.max_shield==roundf(FearOculus.BASE_HEALTH*0.15) and boss.health.shield_points==boss.health.max_shield)
	boss.start_attack(2)
	boss.advance_attack(boss.windup()+0.01)
	_check("phase 2 ring still releases 24 shots and arms a delayed ring",_projectiles()==24 and is_equal_approx(boss._second_ring_left,0.35))
	boss.advance_attack(0.2)
	_check("offset ring stays delayed before 0.35s",_projectiles()==24 and boss._second_ring_left>0.0)
	get_tree().paused = true
	boss.advance_attack(1.0)
	_check("pause freezes the delayed offset ring",_projectiles()==24 and is_equal_approx(boss._second_ring_left,0.15))
	get_tree().paused = false
	boss.advance_attack(0.2)
	_check("delayed offset ring adds 12 real projectiles",_projectiles()==36 and boss._second_ring_left<0.0)
	boss.health.break_shield()
	await _frames(30)
	_check("oculus phase shield does not regenerate",boss.health.shield_points==0.0)
	boss.phase = 0
	var before := boss.health.health
	boss.health.apply_damage(100,Hitbox.BodyPart.BODY,player)
	_check("closed iris keeps 0.4x damage reduction in phase 2",is_equal_approx(before-boss.health.health,40))
	boss.phase = 2
	before = boss.health.health
	boss.health.apply_damage(100,Hitbox.BodyPart.BODY,player)
	_check("exposed recovery keeps full vulnerability in phase 2",is_equal_approx(before-boss.health.health,100))
	boss.phase_time = 0.0
	boss.advance_attack(0.8)
	_check("phase 2 exposure recovery shortens to 1.05/scale",boss.phase==2)
	boss.advance_attack(0.1)
	_check("shortened recovery actually cycles the next attack",boss.phase==0 and boss.attack_kind==0)
	boss.release_ring()
	_check("manual ring re-arms the delayed offset ring",boss._second_ring_left>0.0)
	boss.health.apply_damage(9999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("death cancels the pending offset ring",boss._second_ring_left<0.0)
	await _frames(2)
	boss.advance_attack(1.0)
	_check("death clears owned projectiles and fires nothing later",_projectiles()==0)
	var fresh := preload("res://actors/boss/fear_oculus/fear_oculus.tscn").instantiate() as FearOculus
	fresh.arena = realm
	fresh.position = Vector3(6,0,-8)
	section.add_child(fresh)
	fresh.setup(player,[])
	fresh.set_physics_process(false)
	fresh.health.apply_damage(9999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("lethal-from-full oculus never enters phase 2",fresh.boss_phase==1 and fresh.health.shield_points==0.0)
	await _end_section()

func _wrath() -> void:
	_new_section()
	var realm := WrathRealm.new()
	realm.boss_arena = true
	section.add_child(realm)
	_make_player(Vector3(0,0,12))
	realm.set_player(player)
	var boss := preload("res://actors/boss/wrath_spire/wrath_spire.tscn").instantiate() as WrathSpire
	boss.arena = realm
	boss.position = Vector3.ZERO
	section.add_child(boss)
	boss.setup(player,[])
	player.boons.register_enemy(boss)
	var phases := [0]
	var defeats := [0]
	boss.phase_changed.connect(func(_p:int): phases[0]+=1)
	boss.realm_defeated.connect(func(id:int): defeats[0]+=1 if id==2 else 100)
	await _frames(3)
	_half_damage(boss)
	_check("spire enters phase 2 with a 15% shield",boss.boss_phase==2 and phases[0]==1 and boss.health.max_shield==roundf(WrathSpire.BASE_HEALTH*0.15) and boss.health.shield_points==boss.health.max_shield)
	boss.begin_move(WrathSpire.Move.FISSURE)
	await _frames(60)
	_check("phase 2 fissure releases five directed wave fans",boss.spawned_waves==5)
	boss.begin_move(WrathSpire.Move.ERUPTION)
	_check("phase 2 eruption marks five ground points",boss.spawned_eruptions==5)
	boss.attack_phase = WrathRealmEnemy.Attack.RUSH
	boss.attack_left = 0.001
	boss.move_kind = WrathSpire.Move.FISSURE
	await _frames(1)
	_check("phase 2 punish window shortens to 1.15s",boss.attack_phase==WrathRealmEnemy.Attack.RECOVER and is_equal_approx(boss.attack_left,1.15))
	boss.health.apply_damage(5000,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("spire death emits one clear and cancels owned eruptions",defeats[0]==1 and boss._owned_bullets.is_empty())
	await _frames(2)
	var live := 0
	for child in section.get_children():
		if (child is SpireEruption or child is WrathShockwave) and not child.is_queued_for_deletion():
			live += 1
	_check("death removes live eruption objects",live==0)
	var fresh := preload("res://actors/boss/wrath_spire/wrath_spire.tscn").instantiate() as WrathSpire
	fresh.arena = realm
	fresh.position = Vector3(6,0,0)
	section.add_child(fresh)
	fresh.setup(player,[])
	fresh.set_physics_process(false)
	fresh.health.apply_damage(9999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("lethal-from-full spire never enters phase 2",fresh.boss_phase==1 and fresh.health.shield_points==0.0)
	await _end_section()

func _sorrow() -> void:
	_new_section()
	var realm := SorrowRealm.new()
	realm.boss_arena = true
	section.add_child(realm)
	_make_player(Vector3(0,0,10))
	realm.set_player(player)
	var boss := preload("res://actors/boss/sorrow_monolith/sorrow_monolith.tscn").instantiate() as SorrowMonolith
	boss.arena = realm
	section.add_child(boss)
	boss.setup(player,[])
	player.boons.register_enemy(boss)
	var phases := [0]
	var defeats := [0]
	boss.phase_changed.connect(func(_p:int): phases[0]+=1)
	boss.realm_defeated.connect(func(id:int): defeats[0]+=1 if id==3 else 100)
	await _frames(4)
	_half_damage(boss)
	_check("monolith enters phase 2 with a 15% shield",boss.boss_phase==2 and phases[0]==1 and boss.health.max_shield==roundf(SorrowMonolith.BASE_HEALTH*0.15) and boss.health.shield_points==boss.health.max_shield)
	boss.begin_move(SorrowMonolith.Move.TIDE)
	await _frames(60)
	_check("phase 2 tide releases once and arms a delayed second wave",boss.tides_released==1 and boss._second_tide_left>0.0)
	var frozen := boss._second_tide_left
	get_tree().paused = true
	await _frames(10)
	_check("pause freezes the delayed second tide",boss.tides_released==1 and boss._second_tide_left==frozen)
	get_tree().paused = false
	await _frames(40)
	_check("delayed second tide actually releases",boss.tides_released==2)
	var tears := boss.tears_released
	boss.begin_move(SorrowMonolith.Move.RAIN)
	await _frames(60)
	_check("phase 2 rain adds a 12-tear outer ring to the 25 grid",boss.tears_released-tears==37)
	boss.action = 2
	boss.action_left = 0.001
	await _frames(1)
	_check("phase 2 recover shortens to 1.15s",boss.action==3 and is_equal_approx(boss.action_left,1.15))
	boss.begin_move(SorrowMonolith.Move.TIDE)
	await _frames(60)
	var tides := boss.tides_released
	boss.health.apply_damage(5000,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("death cancels the pending second tide",defeats[0]==1 and boss._second_tide_left<0.0 and boss._owned.is_empty())
	await _frames(40)
	_check("dead monolith never releases the cancelled tide",boss.tides_released==tides)
	var fresh := preload("res://actors/boss/sorrow_monolith/sorrow_monolith.tscn").instantiate() as SorrowMonolith
	fresh.arena = realm
	fresh.position = Vector3(6,0,0)
	section.add_child(fresh)
	fresh.setup(player,[])
	fresh.set_physics_process(false)
	fresh.health.apply_damage(9999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	_check("lethal-from-full monolith never enters phase 2",fresh.boss_phase==1 and fresh.health.shield_points==0.0)
	await _end_section()

func _campaign_stage() -> void:
	var stage := preload("res://maps/realms/sloth_boss.tscn").instantiate() as RealmStage
	stage.campaign = true
	stage.configure_run(1,[1],[],80,[])
	add_child(stage)
	stage.player.set_physics_process(false)
	stage.boss.set_physics_process(false)
	await _frames(4)
	_check("campaign boss room starts with the boss alone",stage.enemies.size()==1 and stage.boss_escorts.is_empty() and stage.boss.health.max_health==SlothColossus.BASE_HEALTH)
	stage.boss.health.apply_damage(SlothColossus.BASE_HEALTH*0.5,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
	await _frames(2)
	_check("phase 2 spawns exactly two real flank escorts",stage.boss_escorts.size()==2 and stage.enemies.size()==3 and stage.boss_escorts.all(func(e:Enemy):return e is SlothEnemy and not e.health.is_dead()))
	_check("escorts inherit the injected warning deprivation",stage.boss_escorts.all(func(e:Enemy):return not e.get("warnings_enabled")))
	await _ui_frame()
	_check("HUD shows the shield badge while the phase shield holds",stage.hud._boss_state.visible and stage.hud._boss_state.text=="护盾")
	stage.boss.health.break_shield()
	await _ui_frame()
	_check("HUD falls back to the phase-2 badge once the shield breaks",stage.hud._boss_state.visible and stage.hud._boss_state.text=="二阶段")
	var escorts := stage.boss_escorts.duplicate()
	stage.boss.health.apply_damage(9999,Hitbox.BodyPart.BODY,stage.player)
	await _frames(3)
	_check("boss defeat force-clears living escorts without blocking settlement",stage.boss_defeated and stage.boss_escorts.is_empty() and escorts.all(func(e:Enemy):return e.health.is_dead()) and stage.living_enemies()==0)
	_check("shard still drops while escorts die",is_instance_valid(stage.shard) and not stage.shard.consumed)
	stage.queue_free()
	await _frames(3)

func _solo_stage() -> void:
	var stage := preload("res://maps/realms/sloth_boss.tscn").instantiate() as RealmStage
	stage.configure_run(1,[1],[],80,[])
	add_child(stage)
	stage.player.set_physics_process(false)
	stage.boss.set_physics_process(false)
	await _frames(4)
	stage.boss.health.apply_damage(SlothColossus.BASE_HEALTH*0.5,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
	await _frames(2)
	_check("non-campaign boss enters phase 2 without escorts",stage.boss.get("boss_phase")==2 and stage.boss_escorts.is_empty() and stage.enemies.size()==1)
	stage.queue_free()
	await _frames(3)

func _projectiles() -> int:
	var count := 0
	for child in section.get_children():
		if child is Projectile and not child.is_queued_for_deletion():
			count += 1
	return count

func _frames(count:int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ui_frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _check(label:String,ok:bool) -> void:
	checks += 1
	failed += 0 if ok else 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])