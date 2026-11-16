extends Node
var checks := 0
var failures := 0
var native := false
var deadline := 0.0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	native = OS.get_cmdline_user_args().has("--native-proof")
	_run.call_deferred()
func _process(delta: float) -> void:
	deadline += delta
	if deadline > 180:
		push_error("Meta campaign integration timed out")
		get_tree().quit(2)
func check(label: String,passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ")+label)
func frames(count := 2) -> void:
	for frame in count: await get_tree().process_frame
func _run() -> void:
	check("registered autoload automatically uses an isolated test profile",MetaProgression.isolated_profile and MetaProgression.save_path()!=MetaProgression.SAVE_PATH)
	MetaProgression.settle_run("test-fixture-budget",2000,30)
	RunState.clear_fixture()
	RunDirector.run_count = 0
	RunDirector.begin_run(152)
	RunDirector.order.assign([0,1,2,3])
	get_tree().change_scene_to_file("res://ui/game_start.tscn")
	await get_tree().scene_changed
	await frames()
	var opening: OpeningSequence = get_tree().current_scene.opening
	opening.skip()
	opening.player.position.z = -13.2
	opening.advance(0.1)
	var forge := get_tree().current_scene.get_node_or_null("CrownForge") as CrownForge
	check("walking through the cinematic gate opens the real starting Forge",forge!=null and RunDirector.current_stage==null and get_tree().paused)
	await capture("campaign-forge-start.png")
	for id in ["resolve","resolve","reflex","reflex","reflex","focus","focus","focus","reroll","reroll","keepsake_slots","keepsake_slots","defiance","first_edge"]:
		(forge._cards[id].button as Button).pressed.emit()
	check("real Forge button transactions unlock talents and deduct saved currency",MetaProgression.maximum_health()==120 and MetaProgression.level("first_edge")==1 and MetaProgression.slots_used()==2 and MetaProgression.will_shards<2000 and MetaProgression.reality_anchors<30)
	await capture("campaign-forge-upgraded.png")
	forge.close()
	while not is_instance_valid(RunDirector.current_stage): await frames(1)
	await frames(4)
	var stage: RealmStage = RunDirector.current_stage
	check("talents and exactly one starting boon are prepared before first room",stage.player.health.max_health>=120 and stage.player.health.health==120 and RunDirector.boons.size()==1 and stage.player.boons.all_equipped().size()==1 and RunDirector.rerolls==3)
	check("production pistol and dash receive capacity upgrades",stage.player.weapon.magazine_capacity()==11 and stage.player.dash.max_charges==3)
	# the opening three-card gift was removed, so the borrowed first boon above is
	# the only card a fresh run starts with and nothing is waiting to be chosen
	check("no opening card offer is waiting",not is_instance_valid(stage.selection))
	await frames()
	stage.player.set_physics_process(false)
	var crown := stage.player.get_node("CrownVoiceSystem") as CrownVoiceSystem
	check("first real run receives the injected historical spoken line",crown.current_key=="first" or crown.played_keys.has("first"))
	var victim: Enemy = stage.enemies[0]
	victim.health.apply_damage(99999,Hitbox.BodyPart.BODY,stage.player)
	check("actual Health death grants five pending will without bank deposit",RunDirector.earned_will==5)
	RunDirector._enemy_defeated(stage,victim)
	check("same corpse cannot pay twice",RunDirector.earned_will==5)
	for enemy in stage.enemies:
		if is_instance_valid(enemy) and not enemy.health.is_dead(): enemy.health.apply_damage(99999,Hitbox.BodyPart.BODY,stage.player)
	await frames(3)
	check("actual room clearance grants one twenty-will reward",stage.cleared and RunDirector.earned_will==stage.enemies.size()*5+20)
	var earned := RunDirector.earned_will
	RunDirector._stage_cleared(stage)
	check("duplicate clearance cannot pay twice",RunDirector.earned_will==earned)
	if is_instance_valid(stage.selection): stage.selection._buttons[0].pressed.emit()
	await frames()
	stage.player.health.health = 100
	stage.player.health.apply_damage(99999,Hitbox.BodyPart.BODY)
	check("real fatal combat uses one revival without settling or recording death",MetaProgression.defiance_consumed and not RunDirector._dead and stage.player.health.health==stage.player.health.max_health*0.4)
	stage.player.health.health = 37
	RunDirector.capture_player(stage.player)
	RunDirector.room_index=1
	RunDirector.install_stage(load(RunDirector.scene_path()))
	await frames(4)
	stage=RunDirector.current_stage
	stage.player.set_physics_process(false)
	check("room transfer retains 37 HP and spent revival without talent stacking",stage.player.health.health==37 and MetaProgression.defiance_consumed and stage.player.weapon.magazine_capacity()==11)
	check("ordinary room transition suppresses historical voice repetition",stage.player.get_node("CrownVoiceSystem").played_keys.is_empty())
	# Enter the actual boss map, then use its real Health death and pickup signals.
	RunDirector.capture_player(stage.player)
	RunDirector.room_index=2
	RunDirector.install_stage(load(RunDirector.scene_path()))
	await frames(4)
	stage=RunDirector.current_stage
	stage.player.set_physics_process(false)
	stage.boss.health.apply_damage(99999,Hitbox.BodyPart.BODY,stage.player)
	await frames(3)
	check("actual Boss defeat awards exactly one pending reality anchor",stage.boss_defeated and RunDirector.earned_anchors==1)
	var anchors := RunDirector.earned_anchors
	RunDirector._realm_defeated(stage)
	check("duplicate Boss settlement cannot create more anchors",RunDirector.earned_anchors==anchors)
	stage.player.global_position = stage.shard.global_position + Vector3(0.2,0,0)
	stage.shard.try_collect()
	await frames(3)
	check("physical core pickup clears Boss room and grants room income",stage.cleared and RunDirector.earned_will==earned+5+20)
	var wallet := MetaProgression.will_shards
	var bank_anchors := MetaProgression.reality_anchors
	var run_id := RunDirector.run_id
	earned=RunDirector.earned_will
	stage.player.health.apply_damage(1,Hitbox.BodyPart.BODY,null,{"environmental_fatal":true,"tag":&"abyss"})
	await frames()
	check("real abyss death atomically banks every earned currency and cause",RunDirector._dead and MetaProgression.will_shards==wallet+earned and MetaProgression.reality_anchors==bank_anchors+1 and MetaProgression.history.death_cause=="abyss" and MetaProgression.settled_runs.has(run_id))
	RunDirector.settle_rewards()
	check("repeated death settlement cannot increase wallet",MetaProgression.will_shards==wallet+earned)
	RunDirector.restart()
	await get_tree().scene_changed
	await frames(3)
	forge=get_tree().current_scene.get_node_or_null("CrownForge") as CrownForge
	check("death returns directly to funded Forge with old history intact",forge!=null and forge._wallet.text.contains(str(wallet+earned)) and RunDirector.run_count==2 and MetaProgression.history.death_cause=="abyss")
	await capture("campaign-death-bank.png")
	forge.close()
	while not is_instance_valid(RunDirector.current_stage): await frames(1)
	await frames(4)
	stage=RunDirector.current_stage
	check("new run refreshes one revival and maximum HP without duplicate starter",not MetaProgression.defiance_consumed and stage.player.health.health==120 and stage.player.boons.all_equipped().size()==1)
	check("re-entry uses actual persisted abyss response",stage.player.get_node("CrownVoiceSystem").played_keys.has("early_abyss"))
	if is_instance_valid(stage.selection): stage.selection._buttons[0].pressed.emit()
	await frames()
	stage.enemies[0].health.apply_damage(99999,Hitbox.BodyPart.BODY,stage.player)
	wallet=MetaProgression.will_shards
	RunDirector.finish_campaign()
	check("ending path banks the run once before campaign completion",RunDirector.completed and not RunDirector.active and MetaProgression.will_shards==wallet+5)
	RunDirector.finish_campaign()
	check("repeated ending cannot pay twice",MetaProgression.will_shards==wallet+5)
	get_tree().paused=false
	get_tree().current_scene.queue_free()
	get_tree().current_scene=null
	await frames(4)
	OS.delay_msec(250)
	await get_tree().process_frame
	print("META CAMPAIGN: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
func capture(file_name: String) -> void:
	if not native or DisplayServer.get_name()=="headless": return
	# Let the production transition overlay finish before inspecting the Forge.
	await get_tree().create_timer(0.8,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-152/"+file_name)
	print("META CAMPAIGN NATIVE: "+file_name)
