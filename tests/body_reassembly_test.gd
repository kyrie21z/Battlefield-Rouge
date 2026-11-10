extends Node
var checks:=0
var failures:=0
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
	player.fragments.restore([0,1,2,3])
	player.fragments.configure_deprivation([0,1,2,3])
	player.get_node("ShadowBody").set_fracture_level(4)
	await frames(3)
	check("entry retains controllable body before trigger",player.is_physics_processing() and corridor.reassembly.phase==BodyReassembly.Phase.IDLE)
	player.position.z=-4.2
	await frames(3)
	var sequence:BodyReassembly=corridor.reassembly
	check("walking into threshold triggers exactly 56 actual rigid bodies",sequence.phase==BodyReassembly.Phase.SHATTER and sequence.pieces.size()==56 and sequence.pieces.all(func(piece):return piece is RigidBody3D and not piece.freeze))
	check("sequence prevents duplicate fracture",not sequence.begin())
	check("cinematic locks player and hides actual original body",player.process_mode==Node.PROCESS_MODE_DISABLED and not player.get_node("ShadowBody").visible)
	check("all 56 authored shards receive the flowing gold shader",sequence.seam_materials.size()==56 and sequence.seam_materials.all(func(material):return material.shader==BodyReassembly.KINTSUGI))
	var origin:=sequence.pieces[10].position
	await frames(40)
	check("shards move under actual physics",sequence.pieces[10].position.distance_to(origin)>0.1)
	var elapsed:=sequence.elapsed
	var shard_time:float=sequence.seam_materials[0].get_shader_parameter("visual_time")
	get_tree().paused=true
	await get_tree().create_timer(0.2,true).timeout
	check("pause freezes cinematic and physics",is_equal_approx(sequence.elapsed,elapsed))
	check("pause also freezes shard shader time",is_equal_approx(shard_time,sequence.seam_materials[0].get_shader_parameter("visual_time")))
	get_tree().paused=false
	var timeout:=0
	while sequence.phase!=BodyReassembly.Phase.COMPLETE and timeout<2700:
		await frames(1)
		timeout+=1
	check("four cries and self acceptance play in order",sequence.spoken==[0,1,2,3,4])
	check("sequence completes and returns player movement",sequence.phase==BodyReassembly.Phase.COMPLETE and player.process_mode!=Node.PROCESS_MODE_DISABLED)
	check("reassembled body is real original skinned geometry",player.get_node("ShadowBody").visible and player.get_meta("kintsugi_complete",false))
	var fracture:BodyFracture=player.get_node("ShadowBody").fracture
	check("all original body parts receive kintsugi seam shader",fracture.source_meshes.values().all(func(entry):return entry.node.material_override is ShaderMaterial and entry.node.material_override.shader==BodyReassembly.KINTSUGI))
	var flow:=player.get_node("ShadowBody/KintsugiFlow") as KintsugiFlow
	check("restored rig owns the continuing shader clock",flow.materials.size()==11 and fracture._skeleton.get_bone_count()==24)
	var gold_time:=flow.visual_time
	await frames(4)
	check("gold flows after control and ordinary animation return",flow.visual_time>gold_time and float(flow.materials[0].get_shader_parameter("visual_time"))>gold_time)
	gold_time=flow.visual_time
	get_tree().paused=true
	await get_tree().create_timer(0.15,true).timeout
	check("restored gold freezes with pause",flow.visual_time==gold_time)
	get_tree().paused=false
	(player.get_node("CrownVoiceSystem") as CrownVoiceSystem).reduced_motion=true
	await frames(3)
	check("restored gold obeys reduced motion",flow.materials.all(func(material):return material.get_shader_parameter("reduced_motion")))
	var accents:Array=[]
	for material in flow.materials:
		var color:Color=material.get_shader_parameter("accent")
		if not accents.has(color):accents.append(color)
	check("four human microglow accents are distributed over actual seams",accents.size()==4)
	check("reconstruction frees physical debris",sequence.pieces.is_empty() and sequence.seam_materials.is_empty())
	check("reconstruction opens actual arena passage",corridor.reconstituted and not is_instance_valid(corridor._end_wall))
	check("ordinary deprivation remains after self acceptance",player.health.unbuffered and not player.realm_effects.warnings_enabled)
	sequence._process(3.0)
	check("acceptance subtitle clears before subsequent duel and ending",sequence._subtitle.text.is_empty())
	corridor.free()
	await frames(3)
	OS.delay_msec(250)
	print("ALL PASSED (%d checks)"%checks if failures==0 else "FAIL (%d)"%failures)
	get_tree().quit(0 if failures==0 else 1)
