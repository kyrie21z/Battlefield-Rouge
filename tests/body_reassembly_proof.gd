extends Node
var corridor: Node3D
var captured: Dictionary = {}
func _ready()->void:
	corridor=preload("res://levels/climax/threshold_corridor.tscn").instantiate()
	add_child(corridor)
	var player:=corridor.get("player") as Player
	player.fragments.restore([0,1,2,3])
	player.fragments.configure_deprivation([0,1,2,3])
	player.get_node("ShadowBody").set_fracture_level(4)
	for i in 15:await get_tree().physics_frame
	corridor.player.position.z=-4.2
func _process(_delta:float)->void:
	if corridor==null:return
	var sequence:BodyReassembly=corridor.reassembly
	if sequence.phase==BodyReassembly.Phase.SHATTER and sequence.elapsed>0.65 and not captured.has("01-fractured-body"):
		capture("01-fractured-body")
	if sequence.phase==BodyReassembly.Phase.CRIES and sequence.spoken.size()==4 and not captured.has("02-four-cries"):
		capture("02-four-cries")
	if sequence.phase==BodyReassembly.Phase.REBUILD and sequence.elapsed>2.6 and not captured.has("03-kintsugi-reassembly"):
		capture("03-kintsugi-reassembly")
	if sequence.phase==BodyReassembly.Phase.COMPLETE and not captured.has("04-restored-first-person"):
		captured["04-restored-first-person"]=true
		corridor.player._pitch=-1.1
		for i in 10:await get_tree().physics_frame
		await capture_image("04-restored-first-person")
		print("REASSEMBLY NATIVE: four phase images, spoken=%s, kintsugi=%s"%[sequence.spoken,corridor.player.get_meta("kintsugi_complete",false)])
		corridor.free()
		corridor=null
		await get_tree().process_frame
		OS.delay_msec(250)
		get_tree().quit()
func capture(label:String)->void:
	captured[label]=true
	await capture_image(label)
func capture_image(label:String)->void:
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path("res://docs/proof/issue-149/"+label+".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var result:=get_viewport().get_texture().get_image().save_png(path)
	print("IMAGE %s %d"%[label,result])
