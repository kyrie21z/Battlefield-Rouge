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
	RunDirector.begin_run(152150)
	var wallet_before:=MetaProgression.will_shards
	var corridor:=preload("res://levels/climax/threshold_corridor.tscn").instantiate()
	add_child(corridor)
	RunDirector.current_stage=corridor
	RunDirector.floor_index=4
	var player:Player=corridor.player
	var camera_id:=player.view_camera.get_instance_id()
	player.fragments.restore([0,1,2,3])
	player.fragments.configure_deprivation([0,1,2,3])
	player.get_node("ShadowBody").set_fracture_level(4)
	player.position.z=-4.2
	var count:=0
	while not corridor.reconstituted and count<3200:
		await frames(1)
		count+=1
	check("real threshold completes original 56 shard reconstruction",corridor.reconstituted and player.get_meta("kintsugi_complete",false))
	player.position.z=-39
	await frames(3)
	var encounter:=corridor.encounter as DoppelgangerSpawn
	check("physical threshold opens final duel",is_instance_valid(encounter) and corridor.duel_started)
	if encounter==null:get_tree().quit(1);return
	count=0
	while encounter.phase!=DoppelgangerSpawn.Phase.COMBAT and count<1200:
		await frames(1)
		count+=1
	check("printing hands same live player into final combat",encounter.phase==DoppelgangerSpawn.Phase.COMBAT and encounter.player==player and player.health.health>0)
	check("final opponent is registered for independent shard targeting",player.boons.enemies().has(encounter.boss) and player.fragments.try_slumber_resonance() and encounter.boss.resonance_left>0)
	var duplicate_ok: Array[bool] = [false]
	corridor.duel_defeated.connect(func(_crown):
		RunDirector.final_duel_defeated(corridor,encounter.boss)
		duplicate_ok[0]=RunDirector.earned_will==25)
	encounter.boss.phase=FlawlessDoppelganger.Phase.RECOVER
	encounter.boss.health.apply_damage(100000,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	await frames(145)
	var ending:=corridor.ending_sequence as ReconciliationSequence
	check("annihilation transfers the same crown to physical ending",is_instance_valid(ending) and ending.crown==encounter.crown and ending.player==player)
	if ending==null:get_tree().quit(1);return
	check("actual final Boss defeat grants kill and clear income once",RunDirector.earned_will==25 and RunDirector.earned_anchors==0)
	check("the same final corpse cannot pay again",duplicate_ok[0] and RunDirector.earned_will==25)
	check("defeating the final opponent does not reveal reconciliation diary",not MetaProgression.reconciled)
	player.position=ending.fallen_crown.global_position+Vector3(0,0,1.35)
	check("actual crown pickup starts after final fight",ending.try_pickup())
	count=0
	while ending.phase!=ReconciliationSequence.Phase.CREDITS and count<1200:
		await frames(1)
		count+=1
	check("single camera survives all three sequences",player.view_camera.get_instance_id()==camera_id)
	check("terminal credits bank the final fight exactly once",MetaProgression.will_shards==wallet_before+25 and MetaProgression.settled_runs.has(RunDirector.run_id))
	check("real reconciliation sequence reveals final diary",MetaProgression.reconciled and LoreEntries.project(MetaProgression.archive_snapshot())[4].unlocked)
	RunDirector.finish_campaign()
	check("repeated ending cannot duplicate final fight income",MetaProgression.will_shards==wallet_before+25)
	check("terminal credits clear active death loop",RunDirector.completed and not RunDirector.active and ending.phase==ReconciliationSequence.Phase.CREDITS)
	check("player retains independent shards and permanent losses through ending",player.fragments.shards.size()==4 and player.fragments.deprivations.size()==4 and player.health.unbuffered)
	corridor.free()
	await frames(4)
	OS.delay_msec(250)
	print("ALL PASSED (%d checks)"%checks if failures==0 else "FAIL (%d)"%failures)
	get_tree().quit(0 if failures==0 else 1)
