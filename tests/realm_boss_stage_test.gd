extends Node
var checks := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stage := preload("res://maps/realms/sloth_boss.tscn").instantiate() as RealmStage
	stage.campaign = true
	stage.difficulty_multiplier = 1.25
	stage.configure_run(1,[1],[],80,[])
	add_child(stage)
	stage.player.set_physics_process(false)
	stage.boss.set_physics_process(false)
	await frames(4)
	check("generated boss map creates one actual Colossus and arena",stage.boss is SlothColossus and stage.enemies.size()==1 and stage.geometry.get("boss_arena"))
	check("boss HP and actual attack damage use injected difficulty",stage.boss.health.max_health==1750 and stage.boss.get("realm_damage_scale")==1.25)
	check("boss retains inherited warning deprivation",not stage.boss.get("warnings_enabled") and not stage.player.realm_effects.warnings_enabled)
	(stage.boss as SlothColossus).start_attack(0)
	await frames(2)
	var attack := (stage.boss as SlothColossus).active_attack
	check("hidden tells also suppress boss warning audio",not attack._audio.playing and not attack._ring.visible)
	attack.finish()
	await frames(2)
	check("HUD renders the actual boss bar",stage.hud._boss_bar.visible and stage.hud._boss_bar.max_value==1750)
	check("boss gate starts locked",not stage.exit_ready and not stage.request_exit())
	var deaths := [0]
	var clears := [0]
	stage.realm_defeated.connect(func(_stage):deaths[0]+=1)
	stage.stage_cleared.connect(func(_stage):clears[0]+=1)
	stage.boss.health.apply_damage(9999,Hitbox.BodyPart.BODY,stage.player)
	await frames(3)
	check("actual boss death emits immediate realm defeat only once",deaths[0]==1 and stage.boss_defeated)
	check("new deprivation is cumulative and immediate",stage.deprivations.has(0) and stage.deprivations.has(1) and stage.player.fragments.deprivations==stage.deprivations)
	check("death blackens Rest and accelerates the world clock",not stage.geometry.get("rest_enabled") and stage.geometry.get("clock_bpm")==148)
	check("death creates a real unconsumed world shard",is_instance_valid(stage.shard) and not stage.shard.consumed)
	check("room completion and gate wait for pickup",clears[0]==0 and not stage.cleared and not stage.exit_ready)
	check("boss cannot incorrectly open a BoonPicker",not is_instance_valid(stage.selection) and not get_tree().paused)
	check("dropped shard is on the baked walkable floor",absf(stage.shard.position.y-0.1)<0.4 and absf(stage.shard.position.x)<20 and absf(stage.shard.position.z)<24)
	stage.player.position = stage.shard.position
	await frames(3)
	check("walking onto shard grants independent Slumber",stage.player.fragments.has_shard(0))
	check("real pickup marks completion and unlocks the exit",clears[0]==1 and stage.cleared and stage.exit_ready)
	check("Slumber pickup leaves cumulative deprivation intact",not stage.geometry.get("rest_enabled") and stage.player.fragments.deprivations.has(0))
	stage.boss.health.apply_damage(9999,Hitbox.BodyPart.BODY,stage.player)
	stage._check_clear()
	check("repeat damage cannot duplicate defeat or completion",deaths[0]==1 and clears[0]==1)
	stage.player.position = Vector3(0,0.1,-18.5)
	await frames(2)
	check("only collected shard allows nearby boss exit",stage.request_exit())
	stage.queue_free()
	await frames(3)
	OS.delay_msec(250)
	print("REALM BOSS STAGE: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func check(label: String,passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(("PASS " if passed else "FAIL ")+label)
