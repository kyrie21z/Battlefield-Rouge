extends Node3D
var checks := 0
var failures := 0
func check(label:String,ok:bool)->void:
	checks+=1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
	if not ok:failures+=1
func _ready()->void:
	check("ordinary campaign defaults to seeded random realm order",RunDirector.randomize_realm_order)
	RunDirector.randomize_realm_order = false
	var fixed := true
	for value in 16:
		RunDirector.begin_run(value)
		fixed = fixed and RunDirector.order == [1,0,2,3] and RunDirector.scene_path() == "res://maps/realms/fear_1.tscn"
	check("explicit diagnostic route can still isolate Fear first",fixed)
	RunDirector.randomize_realm_order = true
	var permutations: Dictionary = {}
	var openers: Dictionary = {}
	var valid := true
	for value in 96:
		RunDirector.begin_run(value)
		var sorted:=RunDirector.order.duplicate()
		sorted.sort()
		valid=valid and sorted==[0,1,2,3]
		permutations[str(RunDirector.order)]=true
		openers[RunDirector.order[0]]=int(openers.get(RunDirector.order[0],0))+1
	check("96 seeds always contain each realm exactly once",valid)
	check("new runs distribute across many orders",permutations.size()>=18)
	check("each realm can open a real shuffled run",openers.size()==4)
	print("SHUFFLE seeds=96 unique_orders=%d opener_counts=%s" % [permutations.size(),JSON.stringify(openers)])
	RunDirector.begin_run(91234)
	var first:=RunDirector.order.duplicate()
	RunDirector.begin_run(91234)
	check("same seed reproduces exact order",RunDirector.order==first)
	RunDirector.begin_run(91234)
	check("ordinary room cannot trigger boss deprivation",not RunDirector.defeat_realm(RunDirector.current_realm()))
	check("early floors already raise health and damage on separate curves",is_equal_approx(RunDirector.hp_scale(1),1.35) and is_equal_approx(RunDirector.damage_scale(1),1.15))
	check("scalar difficulty stays the damage multiplier",is_equal_approx(RunDirector.difficulty(3),1.50) and is_equal_approx(RunDirector.damage_scale(3),1.50))
	check("lost Sloth adds exactly one tempo step",is_equal_approx(RunDirector.tempo_scale(3,[]),1.28) and is_equal_approx(RunDirector.tempo_scale(3,[0]),1.40) and is_equal_approx(RunDirector.tempo_scale(0,[0]),1.12))
	var canonical:=RunDirector.difficulty_profile()
	RunDirector.order.assign([3,2,1,0])
	check("depth scaling never depends on realm identity",RunDirector.difficulty_profile()==canonical)
	RunDirector.order.assign([0,1,2,3])
	var levels: Array[int] = []
	var listener:=func(count:int):levels.append(count)
	Events.sin_defeated.connect(listener)
	var hp_curve:= [1.0,1.35,1.85,2.45]
	var damage_curve:=[1.0,1.15,1.32,1.50]
	var tempo_curve:= [1.0,1.08,1.18,1.28]
	for depth in 4:
		var profile:=RunDirector.difficulty_profile()
		var haste:=0.12 if RunDirector.deprivations.has(0) else 0.0
		check("depth %d health scaling follows its own curve" % (depth+1),is_equal_approx(RunDirector.hp_scale(),hp_curve[depth]) and is_equal_approx(float(profile["hp_scale"]),hp_curve[depth]))
		check("depth %d damage scaling stays fair" % (depth+1),is_equal_approx(RunDirector.difficulty(),damage_curve[depth]) and is_equal_approx(float(profile["damage_scale"]),damage_curve[depth]))
		check("depth %d tempo follows the lost Sloth" % (depth+1),is_equal_approx(RunDirector.tempo_scale(),tempo_curve[depth]+haste) and is_equal_approx(float(profile["tempo_scale"]),tempo_curve[depth]+haste))
		check("first combat room advances to second",RunDirector.advance_room() and RunDirector.room_index==1)
		check("second combat room advances to boss",RunDirector.advance_room() and RunDirector.room_index==2)
		check("boss gate blocks before defeat",not RunDirector.advance_room())
		var realm:=RunDirector.current_realm()
		check("boss death records one deprivation",RunDirector.defeat_realm(realm) and RunDirector.deprivations.size()==depth+1)
		check("duplicate boss death is ignored",not RunDirector.defeat_realm(realm))
		check("defeat alone cannot skip core pickup",not RunDirector.advance_room())
		RunDirector.shards.append(realm)
		check("collected core opens next realm",RunDirector.advance_room())
	check("fracture signal exactly follows four unique defeats",levels==[1,2,3,4])
	check("all four losses still cap tempo at one point four",is_equal_approx(RunDirector.tempo_scale(3,RunDirector.deprivations),1.40))
	check("fourth boss routes into real threshold scene",RunDirector.scene_path()==RunDirector.THRESHOLD and ResourceLoader.exists(RunDirector.scene_path()))
	check("all deprivations remain cumulative",RunDirector.deprivations.size()==4 and RunDirector.shards.size()==4)
	check("the fifth-floor return corridor writes a resumable checkpoint",MetaProgression.has_active_run() and int(MetaProgression.active_run.get("floor_index",-1))==4 and int(MetaProgression.active_run.get("room_index",-1))==0 and MetaProgression.active_run.get("defeated",[]).size()==4 and MetaProgression.active_run.get("shards",[]).size()==4)
	check("crown emission grows above fifteen",RunDirector.crown_strength>15.0)
	var player:=preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.fragments.configure_deprivation([0,1,2,3])
	player.fragments.restore([0,1,2,3])
	player.fragments.barrier=17.0
	player.fragments._barrier_recovery=2.5
	player.fragments._counter_left=0.7
	player.fragments.spite_charge=2
	player.fragments.resonance_cooldown=1.5
	player.fragments.room_healed=12.5
	var saved_card:=BoonCatalog.all().filter(func(card:BoonData):return card.core and card.prerequisites.is_empty())[0] as BoonData
	player.boons.equip(saved_card)
	player.health.health=43
	RunDirector.capture_player(player)
	player.free()
	player=preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	RunDirector.restore_player(player)
	check("new player restores equipped boons outside RealmStage",player.boons.has(saved_card.id) and player.boons.all_equipped()==RunDirector.boons)
	check("new player preserves exact HP and fragment balance",player.health.health==43 and player.fragments.barrier==17)
	check("room change cannot reset fragment cooldowns",player.fragments._barrier_recovery==2.5 and is_equal_approx(player.fragments._counter_left,0.7) and player.fragments.spite_charge==2)
	check("same room snapshot keeps the used healing budget",is_equal_approx(player.fragments.room_healed,12.5))
	var saved_floor:=RunDirector.floor_index
	var saved_room:=RunDirector.room_index
	RunDirector.floor_index=0
	RunDirector.room_index=0
	RunDirector.capture_player(player)
	check("advancing a room resets the healing budget",RunDirector.advance_room() and RunDirector.room_index==1 and is_zero_approx(float(RunDirector.fragment_state.get("room_healed",-1.0))))
	check("advancing a room keeps barrier recovery, spite and cooldowns",is_equal_approx(float(RunDirector.fragment_state.get("recovery",-1.0)),2.5) and is_equal_approx(float(RunDirector.fragment_state.get("counter",-1.0)),0.7) and int(RunDirector.fragment_state.get("charge",-1))==2 and is_equal_approx(float(RunDirector.fragment_state.get("resonance",-1.0)),1.5))
	RunDirector.floor_index=saved_floor
	RunDirector.room_index=saved_room
	check("new player retains all deprivation rules",player.health.unbuffered and not player.realm_effects.warnings_enabled and player.fragments.deprivations.size()==4)
	check("new body restores actual fracture level four",player.get_node("ShadowBody").fracture_level==4)
	check("physical crown restores exponential emission",player.get_node("CrownVoiceSystem").strength>15.0)
	check("actual return-corridor Player speaks the fifth-floor line",player.get_node("CrownVoiceSystem").floor_depth==5 and player.get_node("CrownVoiceSystem").current_key=="floor5")
	var death_count: Array[int] = [0]
	var on_failure:=func(_depth,_cause):death_count[0]+=1
	RunDirector.run_failed.connect(on_failure)
	RunDirector.record_death(&"abyss")
	RunDirector.record_death(&"combat")
	check("death history records once and preserves cause",death_count[0]==1 and RunDirector.last_death_depth==4 and RunDirector.last_death_cause==&"abyss")
	RunDirector.begin_run(5)
	check("new run resets temporary powers and losses",RunDirector.shards.is_empty() and RunDirector.deprivations.is_empty() and RunDirector.hp==MetaProgression.maximum_health() and RunDirector.fragment_state.is_empty())
	check("new run keeps previous failure history",RunDirector.last_death_depth==4 and RunDirector.last_death_cause==&"abyss")
	RunDirector.finish_campaign()
	RunDirector.record_death(&"combat")
	check("completed campaign cannot reopen death loop",not RunDirector.active and death_count[0]==1)
	# --- Room-boundary checkpoints, cold-restart resume and S/L guards ---
	check("profile reset prepares a clean resume scenario",MetaProgression.reset_profile() and not MetaProgression.has_profile())
	RunDirector.randomize_realm_order = false
	var departed := RunDirector.begin_run(91234)
	RunDirector.prepare_departure()
	check("departure writes an unclaimed 0:0 checkpoint",departed and MetaProgression.has_active_run())
	check("0:0 checkpoint starts with no claimed card and no pending rewards",int(MetaProgression.active_run.get("floor_index",-1))==0 and int(MetaProgression.active_run.get("room_index",-1))==0 and not bool(MetaProgression.active_run.get("entry_reward_claimed",true)) and int(MetaProgression.active_run.get("earned_will",-1))==0 and int(MetaProgression.active_run.get("earned_anchors",-1))==0)
	var resume_card: BoonData = null
	for card in BoonCatalog.all():
		if card.core:
			resume_card = card
			break
	var resume_player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(resume_player)
	resume_player.set_physics_process(false)
	resume_player.boons.restore([resume_card])
	var stub := StubStage.new()
	stub.player = resume_player
	add_child(stub)
	RunDirector.current_stage = stub
	RunDirector._reward_selected(stub,resume_card)
	check("taking the opening card marks the checkpoint claimed",RunDirector.entry_reward_claimed and bool(MetaProgression.active_run.get("entry_reward_claimed",false)))
	# Simulate a mid-campaign boundary: two lost realms, one core each.
	RunDirector.floor_index = 2
	RunDirector.room_index = 1
	RunDirector.defeated.assign([RunDirector.order[0],RunDirector.order[1]])
	RunDirector.deprivations.assign(RunDirector.defeated)
	RunDirector.shards.assign(RunDirector.defeated)
	RunDirector.earned_will = 25
	RunDirector.earned_anchors = 2
	RunDirector.rerolls = 1
	resume_player.health.health = 37.0
	resume_player.fragments.configure_deprivation(RunDirector.deprivations)
	resume_player.fragments.restore(RunDirector.shards)
	resume_player.fragments.barrier = 12.0
	resume_player.fragments._barrier_recovery = 2.5
	resume_player.fragments._counter_left = 0.7
	resume_player.fragments.spite_charge = 2
	resume_player.fragments.resonance_cooldown = 1.5
	resume_player.fragments.room_healed = 9.0
	RunDirector.capture_player(resume_player)
	MetaProgression.defiance_consumed = true
	RunDirector._revived_for_checkpoint(resume_player)
	check("a spent revival is latched without banking mid-room rewards",bool(MetaProgression.active_run.get("defiance_consumed",false)) and int(MetaProgression.active_run.get("earned_will",-1))==0)
	check("advancing the room writes the next boundary checkpoint",RunDirector.advance_room() and RunDirector.room_index==2 and int(MetaProgression.active_run.get("room_index",-1))==2)
	check("room advance stores cleared rewards and clears the rest budget",int(MetaProgression.active_run.get("earned_will",-1))==25 and is_zero_approx(float(MetaProgression.active_run.get("fragment_state",{}).get("room_healed",-1.0))))
	check("checkpoint stores the spent revival",bool(MetaProgression.active_run.get("defiance_consumed",false)))
	RunDirector.earned_will += 5
	var cold := MetaProgressionStore.new()
	cold.override_path = MetaProgression.save_path()
	add_child(cold)
	check("cold restart reloads the last safe boundary from disk",cold.has_active_run() and str(cold.active_run.get("run_id",""))==RunDirector.run_id and int(cold.active_run.get("earned_will",-1))==25 and int(cold.active_run.get("earned_anchors",-1))==2)
	# Feed the deserialized copy back, exactly like a fresh process would.
	MetaProgression.active_run = cold.active_run.duplicate(true)
	MetaProgression.active_run_id = str(MetaProgression.active_run.get("run_id",""))
	MetaProgression.defiance_consumed = false
	var saved_run_id := RunDirector.run_id
	# The SceneTree root is busy while this scene's _ready runs, so wait one
	# frame before installing a stand-in current scene for install_stage().
	await get_tree().process_frame
	var dummy := Node.new()
	dummy.name = "ResumeDummy"
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	var fake_packed := PackedScene.new()
	var fake_root := Node.new()
	fake_root.name = "ResumeFakeStage"
	fake_packed.pack(fake_root)
	fake_root.free()
	var resumed = load("res://autoload/run_director.gd").new()
	add_child(resumed)
	check("resume_run rebuilds the run from the cold snapshot",resumed.resume_run(fake_packed))
	check("resumed run restores the exact room and realm order",resumed.floor_index==2 and resumed.room_index==2 and resumed.order==RunDirector.order and resumed.run_id==saved_run_id)
	check("resumed run restores HP, rerolls and cursed crown",is_equal_approx(resumed.hp,37.0) and resumed.rerolls==1 and is_equal_approx(resumed.crown_strength,0.5*pow(2.4,2)))
	check("resumed run restores boons, cores and deprivations",resumed.boons.size()==1 and (resumed.boons[0] as BoonData).id==resume_card.id and resumed.shards.size()==2 and resumed.shards.has(RunDirector.order[0]) and resumed.shards.has(RunDirector.order[1]) and resumed.deprivations.size()==2)
	check("resumed run restores fragment state minus the used rest budget",is_equal_approx(float(resumed.fragment_state.get("barrier",-1.0)),12.0) and is_equal_approx(float(resumed.fragment_state.get("counter",-1.0)),0.7) and is_zero_approx(float(resumed.fragment_state.get("room_healed",-1.0))))
	check("resumed run restores pending rewards and the spent revival",resumed.earned_will==25 and resumed.earned_anchors==2 and MetaProgression.defiance_consumed and MetaProgression.active_run_id==saved_run_id)
	check("resumed run restores selections and the claimed opening choice",resumed.entry_reward_claimed and resumed.selections.size()==1 and str(resumed.selections[0].get("boon_id",""))==resume_card.id)
	check("unfinished kills stay out of the resumed run",resumed.earned_will==25 and int(MetaProgression.active_run.get("earned_will",-1))==25)
	var banked := MetaProgression.will_shards
	resumed.record_death(&"combat")
	check("death banks the locked rewards and clears the checkpoint atomically",not MetaProgression.has_active_run() and MetaProgression.will_shards==banked+25 and MetaProgression.reality_anchors>=2 and MetaProgression.settled_runs.has(saved_run_id))
	check("a settled run id cannot be paid a second time",not MetaProgression.settle_run(saved_run_id,25,2) and MetaProgression.will_shards==banked+25)
	# Fifth-floor return corridor is both saved and resumable.
	var corridor_snapshot := {
		"run_id":"corridor-run","run_seed":91234,"order":[1,0,2,3],
		"floor_index":4,"room_index":0,"defeated":[0,1,2,3],"deprivations":[0,1,2,3],"shards":[0,1,2,3],
		"hp":61.0,"boon_ids":[resume_card.id],"fragment_state":{},"rerolls":1,"selections":[],
		"entry_reward_claimed":true,"earned_will":40,"earned_anchors":4,"defiance_consumed":false,
	}
	check("fifth-floor checkpoint snapshot is accepted",MetaProgression.save_active_run(corridor_snapshot))
	var thresholds := [0]
	var on_threshold := func():thresholds[0]+=1
	var corridor = load("res://autoload/run_director.gd").new()
	add_child(corridor)
	corridor.threshold_reached.connect(on_threshold)
	check("resume restores the fifth-floor return corridor",corridor.resume_run(fake_packed) and corridor.floor_index==4 and corridor.room_index==0 and corridor.scene_path()==RunDirector.THRESHOLD and thresholds[0]==1)
	corridor.threshold_reached.disconnect(on_threshold)
	banked = MetaProgression.will_shards
	check("abandoning the corridor run settles its checkpoint once",corridor.abandon_active_run() and not MetaProgression.has_active_run() and MetaProgression.will_shards==banked+40 and MetaProgression.reality_anchors>=6)
	corridor.queue_free()
	var stale_resume = load("res://autoload/run_director.gd").new()
	add_child(stale_resume)
	check("resume refuses to start without a checkpoint",not stale_resume.resume_run(fake_packed))
	stale_resume.queue_free()
	resumed.queue_free()
	check("a run after death departs cleanly",RunDirector.begin_run(777))
	RunDirector.prepare_departure()
	RunDirector.earned_will = 30
	RunDirector.earned_anchors = 1
	check("advance locks the abandoned rewards into the checkpoint",RunDirector.advance_room() and int(MetaProgression.active_run.get("earned_will",-1))==30 and int(MetaProgression.active_run.get("earned_anchors",-1))==1)
	var abandon_id := RunDirector.run_id
	banked = MetaProgression.will_shards
	check("abandon settles the checkpoint rewards and drops the run",RunDirector.abandon_active_run() and not MetaProgression.has_active_run() and MetaProgression.will_shards==banked+30 and MetaProgression.reality_anchors>=3 and not RunDirector.active and RunDirector.run_id.is_empty())
	check("abandon is idempotent and cannot pay twice",not RunDirector.abandon_active_run() and MetaProgression.will_shards==banked+30 and MetaProgression.settled_runs.has(abandon_id))
	check("a post-abandon run departs cleanly",RunDirector.begin_run(888))
	RunDirector.prepare_departure()
	RunDirector.earned_will = 7
	check("finish scenario locks its pending will at the boundary",RunDirector.advance_room() and int(MetaProgression.active_run.get("earned_will",-1))==7)
	banked = MetaProgression.will_shards
	RunDirector.finish_campaign()
	check("finishing the campaign clears the checkpoint and banks once",not MetaProgression.has_active_run() and MetaProgression.will_shards==banked+7 and RunDirector.completed)
	# Real stage seam: a resumed 0:0 run must not re-offer the spent opening card.
	var another := RunDirector.begin_run(4242)
	RunDirector.prepare_departure()
	check("another departure prepares a claimed 0:0 room",another and not RunDirector.entry_reward_claimed)
	RunDirector.current_stage = stub
	RunDirector._reward_selected(stub,resume_card)
	check("the opening choice is checkpointed before the room starts",RunDirector.entry_reward_claimed and bool(MetaProgression.active_run.get("entry_reward_claimed",false)))
	var replay = load("res://autoload/run_director.gd").new()
	add_child(replay)
	check("resume installs the real first room",replay.resume_run())
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var first_stage: RealmStage = replay.current_stage as RealmStage
	check("resumed 0:0 stage skips the spent opening offer",is_instance_valid(first_stage) and first_stage.skip_entry_reward and not is_instance_valid(first_stage.selection))
	check("resumed stage does not replay the historical entry voice",is_instance_valid(first_stage) and first_stage.player.get_node("CrownVoiceSystem").played_keys.is_empty())
	check("resumed stage restores the claimed opening card and health",is_instance_valid(first_stage) and first_stage.player.boons.has(resume_card.id) and is_equal_approx(first_stage.player.health.health,37.0))
	RunDirector.run_failed.disconnect(on_failure)
	Events.sin_defeated.disconnect(listener)
	player.free()
	if is_instance_valid(first_stage):
		first_stage.queue_free()
	get_tree().current_scene = null
	stub.queue_free()
	resume_player.queue_free()
	replay.queue_free()
	cold.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("ALL PASSED (%d checks)" % checks if failures==0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures==0 else 1)

## Minimal stand-in for a room: the reward path only needs the captured player.
class StubStage extends Node:
	var player: Player
