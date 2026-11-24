extends Node
var failures:=0
var checks:=0
func check(label:String,ok:bool)->void:
	checks+=1
	print("%s %s"%["PASS" if ok else "FAIL",label])
	if not ok:failures+=1
func frames(count:int)->void:
	for i in count:await get_tree().physics_frame
func _ready()->void:
	# the realm intro panel is a UI concern; these tests only care about the flow
	MetaProgression.introduced_realms.assign([0,1,2,3])
	process_mode=Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# The test driver stays at root while actual campaign scenes replace each other.
	get_tree().current_scene=null
	RunDirector.begin_run(190146)
	# Fixed route so the lost-Sloth haste is observable in later rooms; the
	# shuffled distribution itself is covered by run_director_test.
	RunDirector.order.assign([0,1,2,3])
	check("first production room installs",RunDirector.install_stage(load(RunDirector.scene_path()))==OK)
	var visited:Array[String]=[]
	var depth_waves:Array[int]=[0,0,0,0]
	var depth_elites:Array[int]=[0,0,0,0]
	for index in 12:
		await frames(8)
		var stage:=RunDirector.current_stage as RealmStage
		if stage==null:
			check("production stage exists at room %d"%index,false)
			break
		visited.append(stage.scene_file_path)
		stage.player.set_physics_process(false)
		for enemy in stage.enemies:enemy.set_physics_process(false)
		check("room %d has baked traversable geometry"%index,stage._region.navigation_mesh.get_polygon_count()>0)
		var vector_ok:=stage.enemies.all(func(enemy):
			return is_equal_approx(enemy.realm_hp_scale,RunDirector.hp_scale()) \
				and is_equal_approx(enemy.realm_damage_scale,RunDirector.damage_scale()) \
				and is_equal_approx(enemy.realm_tempo_scale,RunDirector.tempo_scale()) \
				and is_equal_approx(enemy.health.max_health,enemy._base_max_health*RunDirector.hp_scale()))
		check("room %d injects the three-axis depth vector"%index,vector_ok)
		check("room %d inherits all previous losses"%index,stage.player.fragments.deprivations==RunDirector.deprivations)
		if RunDirector.deprivations.has(0):
			check("room %d keeps the lost-Sloth global haste"%index,stage.enemies.all(func(enemy):return is_equal_approx(enemy.realm_tempo_scale,RunDirector.tempo_scale()) and enemy.realm_tempo_scale>RunDirector.tempo_scale(-1,[])))
		if not stage.enemies.is_empty():
			var sample:=stage.enemies[0]
			var base_tempo:=sample.realm_tempo_scale
			var layer:=sample.elite_tempo_scale if sample.is_elite else 1.0
			var windup_cap:=BoonManager.BOSS_MAX_WINDUP_SCALE if sample.is_boss else 2.0
			stage.player.boons.set_status(sample,&"test_realm_tempo",10.0,0.5,1.0,false,2.0,false,0.6)
			var status_ok:=is_equal_approx(sample.realm_tempo_scale,base_tempo) \
				and is_equal_approx(sample.effective_attack_scale(),0.6*base_tempo*layer) \
				and is_equal_approx(sample.effective_windup_scale(),minf(2.0,windup_cap)/(base_tempo*layer))
			stage.player.boons.clear_status(sample,&"test_realm_tempo")
			check("room %d keeps realm tempo orthogonal to boon status"%index,status_ok and is_equal_approx(sample.realm_tempo_scale,base_tempo) and is_equal_approx(sample.effective_attack_scale(),base_tempo*layer) and is_equal_approx(sample.effective_windup_scale(),1.0/(base_tempo*layer)))
		if not stage.boss_room:
			check("depth %d room %d authors %d waves" % [stage.depth+1,stage.room_index+1,_wave_total_expectation(stage.depth,stage.room_index).size()],
				stage.total_waves()==_wave_total_expectation(stage.depth,stage.room_index).size())
			check("depth %d room %d opens with the authored first density" % [stage.depth+1,stage.room_index+1],
				stage.enemies.size()==_wave_total_expectation(stage.depth,stage.room_index)[0])
		else:
			var phases:=[0]
			stage.boss.phase_changed.connect(func(_p:int):phases[0]+=1)
			stage.boss.health.apply_damage(stage.boss.health.health-stage.boss.health.max_health*0.5,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
			await frames(2)
			check("depth %d boss crosses into phase 2 exactly once" % [stage.depth+1],
				int(stage.boss.get("boss_phase"))==2 and phases[0]==1)
			check("depth %d campaign boss phase 2 spawns two real escorts" % [stage.depth+1],
				stage.boss_escorts.size()==2 and stage.boss_escorts.all(func(enemy:Enemy):return not enemy.health.is_dead()))
		if is_instance_valid(stage.selection):
			var picker:=stage.selection
			picker._choose(picker._offered[0])
			picker.confirm_replacement(true)
			await frames(2)
		if stage.boss_room:
			for enemy in stage.enemies:
				enemy.health.apply_damage(100000,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
			await frames(4)
			check("depth %d boss death clears the escorts without blocking the shard" % [stage.depth+1],
				stage.boss_defeated and stage.boss_escorts.is_empty() and stage.living_enemies()==0)
		else:
			await _clear_all_waves(stage)
			var authoring:=_wave_total_expectation(stage.depth,stage.room_index)
			var total:=0
			for count in authoring:total+=count
			check("depth %d room %d spawns every authored reinforcement" % [stage.depth+1,stage.room_index+1],
				stage.enemies.size()==total and stage.cleared)
			check("depth %d room %d keeps the authored elite quota" % [stage.depth+1,stage.room_index+1],
				stage.enemies.filter(func(enemy:Enemy):return enemy.is_elite).size()==_elite_expectation(stage.depth,stage.room_index))
			depth_waves[stage.depth]+=stage.total_waves()
			depth_elites[stage.depth]+=stage.enemies.filter(func(enemy:Enemy):return enemy.is_elite).size()
		if stage.boss_room:
			check("boss %d records death before pickup"%stage.realm,RunDirector.defeated.has(stage.realm) and not stage.exit_ready)
			check("boss %d drops actual shard"%stage.realm,is_instance_valid(stage.shard))
			if is_instance_valid(stage.shard):stage.player.position=stage.shard.position
			await frames(4)
			check("boss %d pickup activates independent core"%stage.realm,stage.player.fragments.has_shard(stage.realm) and stage.exit_ready)
		else:
			if stage.orb_pending():
				stage.claim_talent()
				for _f in 4:
					await get_tree().physics_frame
			check("normal room clear opens actual reward choice",is_instance_valid(stage.selection) and get_tree().paused)
			if is_instance_valid(stage.selection):
				var picker:=stage.selection
				if not picker._offered.is_empty():
					picker._choose(picker._offered[0])
					picker.confirm_replacement(true)
				else:picker._skip_empty()
			await frames(3)
		check("room %d unlocks only after completion"%index,stage.exit_ready and not get_tree().paused)
		stage.player.position=stage.gate.position+Vector3(0,0.1,1.4)
		await frames(2)
		check("room %d physical gate advances"%index,stage.request_exit())
		var loops:=0
		while RunDirector.current_stage==stage and loops<180:
			await frames(1)
			loops+=1
		check("room %d loads next scene without duplicate exit"%index,RunDirector.current_stage!=stage)
	check("deeper floors add reinforcement waves (2/3/4/5)",depth_waves==[2,3,4,5])
	check("elite quotas escalate with depth (0/1/3/5)",depth_elites==[0,1,3,5])
	check("all twelve actual rooms visited without repetition",visited.size()==12 and _unique(visited)==12)
	check("final destination is the real return corridor",RunDirector.current_stage.scene_file_path==RunDirector.THRESHOLD)
	var final_player:Player=RunDirector.current_stage.player
	check("final player owns all four cores and losses",final_player.fragments.shards.size()==4 and final_player.fragments.deprivations.size()==4)
	check("threshold keeps equipped combat boons",not RunDirector.boons.is_empty() and final_player.boons.all_equipped()==RunDirector.boons)
	check("final body has actual fourth fracture level",final_player.get_node("ShadowBody").fracture_level==4)
	RunDirector.current_stage.free()
	RunDirector.current_stage=null
	get_tree().current_scene=null
	RunDirector.finish_campaign()
	await frames(4)
	OS.delay_msec(250)
	print("ALL PASSED (%d checks)"%checks if failures==0 else "FAIL (%d)"%failures)
	get_tree().quit(0 if failures==0 else 1)
func _unique(values:Array[String])->int:
	var result:Dictionary={}
	for value in values:result[value]=true
	return result.size()

func _wave_total_expectation(depth:int,room:int)->Array:
	var table:Array=RealmEncounter.SLOTH_WAVES if RunDirector.current_realm()==0 else RealmEncounter.WAVES
	return table[depth][room]

func _elite_expectation(depth:int,room:int)->int:
	var total:=0
	for count in RealmEncounter.ELITES[depth][room]:total+=count
	return total

func _clear_all_waves(stage:RealmStage)->void:
	stage.wave_spawned.connect(func(s:RealmStage,_wave:int,_total:int)->void:
		for actor in s.enemies:actor.set_physics_process(false))
	var guard:=0
	while (stage.living_enemies()>0 or stage.has_pending_waves()) and guard<16:
		for actor in stage.enemies:
			actor.set_physics_process(false)
			if is_instance_valid(actor) and not actor.health.is_dead():
				actor.health.apply_damage(100000,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
		await frames(4)
		guard+=1
