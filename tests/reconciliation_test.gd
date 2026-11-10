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
	var corridor:=preload("res://levels/climax/threshold_corridor.tscn").instantiate()
	add_child(corridor)
	var player:Player=corridor.player
	player.set_physics_process(false)
	player.position=Vector3(0,0.1,3)
	BodyReassembly.apply_kintsugi(player)
	var crown:=CrownModel.new()
	corridor.add_child(crown)
	crown.position=Vector3(0,1,0)
	crown.set_emission_strength(16)
	var sequence:=ReconciliationSequence.new()
	sequence.setup(player,crown)
	sequence.finished.connect(RunDirector.finish_campaign)
	corridor.add_child(sequence)
	await frames(45)
	check("fallen crown is actual resting rigid body",sequence.fallen_crown.position.y<0.4 and sequence.fallen_crown.get_child_count()==2)
	check("oppressive crown loses glare",is_equal_approx(crown.emission_strength,0.02))
	check("both weapons holstered",not player.weapon.visible and not player.melee.visible)
	check("distant pickup rejected",not sequence.try_pickup())
	player.position=sequence.fallen_crown.position+Vector3(0,0,1.4)
	var wall:StaticBody3D=corridor._block(sequence.fallen_crown.position+Vector3(0,1,0.6),Vector3(2,3,0.2))
	await frames(3)
	check("wall blocks crown pickup",not sequence.try_pickup())
	wall.queue_free()
	await frames(3)
	get_tree().paused=true
	check("paused interaction rejected",not sequence.try_pickup())
	get_tree().paused=false
	var key:=InputEventAction.new()
	key.action="reconcile"
	key.pressed=true
	sequence._unhandled_input(key)
	check("E action starts gentle coronation",sequence.phase==ReconciliationSequence.Phase.LIFT and player.process_mode==Node.PROCESS_MODE_DISABLED)
	check("carrying suspends the post-animation weapon pose",not sequence._body_pose.active)
	check("duplicate pickup rejected",not sequence.try_pickup())
	await frames(100)
	await get_tree().process_frame
	var body:=player.get_node("ShadowBody")
	var skeleton:Skeleton3D=body._skeleton
	var left:=skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin
	var right:=skeleton.get_bone_global_pose(skeleton.find_bone("RightHand")).origin
	check("both authored skeletal hands move around crown",left.distance_to(right)>0.1 and left.distance_to(right)<1.1)
	var holds_crown:=true
	for side in ["Left","Right"]:
		var side_sign:float=-1 if side=="Left" else 1
		var target:=sequence.fallen_crown.global_position+player.global_basis.x*side_sign*0.105-Vector3.UP*0.025
		var wrist:=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(side+"Hand")).origin)
		print("GRIP ",side," elapsed=",sequence.elapsed," wrist=",wrist," target=",target," error=",wrist.distance_to(target))
		holds_crown=holds_crown and wrist.distance_to(target)<0.06
	check("both real wrists remain on the small crown after animation",holds_crown)
	var elapsed:=sequence.elapsed
	get_tree().paused=true
	await get_tree().create_timer(0.2,true).timeout
	check("pause freezes ending",is_equal_approx(sequence.elapsed,elapsed))
	get_tree().paused=false
	RunDirector.active=true
	var count:=0
	while sequence.phase!=ReconciliationSequence.Phase.CREDITS and count<1500:
		await frames(1)
		count+=1
	check("coronation reuses the fallen crown",crown.get_parent()==player and crown.worn)
	check("physical crown body cleaned",not is_instance_valid(sequence.fallen_crown))
	check("awakening uses same camera in real lecture space",is_instance_valid(sequence.reality_room) and player.position.x==100 and is_equal_approx(player._head.position.y,1.25))
	check("breathing replaces crown voice",sequence._ambience.playing and player.get_node("CrownVoiceSystem").process_mode==Node.PROCESS_MODE_DISABLED and player.get_node("CrownVoiceSystem").find_children("*","AudioStreamPlayer",true,false).all(func(sound):return not sound.playing))
	check("credits stop death loop",sequence.phase==ReconciliationSequence.Phase.CREDITS and RunDirector.completed and not RunDirector.active)
	RunDirector.record_death(&"after_credits")
	RunDirector.restart()
	check("completed run cannot death-restart",RunDirector.completed and not RunDirector.active)
	check("credits return to explicit title menu",sequence._credits.visible and ResourceLoader.exists("res://ui/ending_menu.tscn"))
	var pose:=sequence._body_pose
	sequence.free()
	check("removing the sequence restores player and body processing",pose.active and player.process_mode==Node.PROCESS_MODE_INHERIT)
	corridor.free()
	await frames(4)
	OS.delay_msec(250)
	print("ALL PASSED (%d checks)"%checks if failures==0 else "FAIL (%d)"%failures)
	get_tree().quit(0 if failures==0 else 1)
