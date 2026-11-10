extends Node
var corridor:Node3D
var sequence:ReconciliationSequence
var captured:Dictionary={}
func _ready()->void:
	corridor=preload("res://levels/climax/threshold_corridor.tscn").instantiate()
	add_child(corridor)
	var player:Player=corridor.player
	player.position=Vector3(0,0.1,2.2)
	player._pitch=-0.58
	player.set_physics_process(false)
	BodyReassembly.apply_kintsugi(player)
	var crown:=CrownModel.new()
	corridor.add_child(crown)
	crown.position=Vector3(0,0.8,0)
	sequence=ReconciliationSequence.new()
	sequence.setup(player,crown)
	sequence.finished.connect(RunDirector.finish_campaign)
	corridor.add_child(sequence)
	await get_tree().create_timer(2).timeout
	await capture("01-fallen-crown")
	player.position=sequence.fallen_crown.position+Vector3(0,0,1.4)
	print("PICKUP ",sequence.try_pickup())
func _process(_delta:float)->void:
	if sequence==null:return
	if sequence.phase==ReconciliationSequence.Phase.LIFT and sequence.elapsed>1.6 and not captured.has("02-two-handed-coronation"):
		capture("02-two-handed-coronation")
	if sequence.phase==ReconciliationSequence.Phase.REALITY and sequence.elapsed>3.5 and not captured.has("03-reality-awakening"):
		capture("03-reality-awakening")
	if sequence.phase==ReconciliationSequence.Phase.CREDITS and not captured.has("04-credits"):
		await capture("04-credits")
		print("ENDING NATIVE: same camera, two hands, worn=",sequence.crown.worn,", completed=",RunDirector.completed)
		corridor.free()
		sequence=null
		await get_tree().process_frame
		OS.delay_msec(250)
		get_tree().quit()
func capture(label:String)->void:
	captured[label]=true
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path("res://docs/proof/issue-151/"+label+".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	print("IMAGE ",label," ",get_viewport().get_texture().get_image().save_png(path))
