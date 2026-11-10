extends Node
var stage: RealmStage

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stage = preload("res://maps/realms/sloth_1.tscn").instantiate()
	stage.campaign = true
	add_child(stage)
	stage.player.health.invulnerable = true
	await get_tree().create_timer(1.2).timeout
	await capture("stage-combat")
	for enemy in stage.enemies:
		enemy.health.apply_damage(9999,Hitbox.BodyPart.BODY,stage.player)
	await get_tree().create_timer(0.8,true).timeout
	await capture("stage-reward")
	stage.selection._choose(stage.selection._offered[0])
	await get_tree().create_timer(0.3).timeout
	stage.player.position = Vector3(0,0.1,-17.5)
	stage.player.aim_at(stage.gate.global_position+Vector3.UP*2)
	await get_tree().create_timer(0.2).timeout
	await capture("stage-exit")
	stage.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit()

func capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-138/"+file_name+".png")
	print("REALM STAGE NATIVE: "+file_name)
