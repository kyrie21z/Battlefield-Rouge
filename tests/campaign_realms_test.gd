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
	process_mode=Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# The test driver stays at root while actual campaign scenes replace each other.
	get_tree().current_scene=null
	RunDirector.begin_run(190146)
	check("first production room installs",RunDirector.install_stage(load(RunDirector.scene_path()))==OK)
	var visited:Array[String]=[]
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
		check("room %d applies current depth to real damage"%index,stage.enemies.all(func(enemy):return is_equal_approx(enemy.realm_damage_scale,RunDirector.difficulty())))
		check("room %d inherits all previous losses"%index,stage.player.fragments.deprivations==RunDirector.deprivations)
		if is_instance_valid(stage.selection):
			var picker:=stage.selection
			picker._choose(picker._offered[0])
			picker.confirm_replacement(true)
			await frames(2)
		for enemy in stage.enemies:
			enemy.health.apply_damage(100000,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
		await frames(4)
		if stage.boss_room:
			check("boss %d records death before pickup"%stage.realm,RunDirector.defeated.has(stage.realm) and not stage.exit_ready)
			check("boss %d drops actual shard"%stage.realm,is_instance_valid(stage.shard))
			if is_instance_valid(stage.shard):stage.player.position=stage.shard.position
			await frames(4)
			check("boss %d pickup activates independent core"%stage.realm,stage.player.fragments.has_shard(stage.realm) and stage.exit_ready)
		else:
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
