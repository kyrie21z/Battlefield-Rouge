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
	RunDirector.run_failed.disconnect(on_failure)
	Events.sin_defeated.disconnect(listener)
	player.free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("ALL PASSED (%d checks)" % checks if failures==0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures==0 else 1)
