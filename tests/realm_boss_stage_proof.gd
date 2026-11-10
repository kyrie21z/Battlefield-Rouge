extends Node
var stage: RealmStage

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stage = preload("res://maps/realms/sloth_boss.tscn").instantiate()
	stage.campaign = true
	add_child(stage)
	stage.player.health.invulnerable = true
	stage.player.position = Vector3(0,0.1,3)
	stage.player.aim_at(stage.boss.position+Vector3.UP*2.4)
	await get_tree().create_timer(1.0).timeout
	await capture("boss-stage-combat")
	stage.boss.health.apply_damage(9999,Hitbox.BodyPart.BODY,stage.player)
	await get_tree().create_timer(0.4).timeout
	stage.player.position = stage.shard.position+Vector3(0,0,3)
	stage.player.aim_at(stage.shard.position+Vector3.UP)
	await get_tree().create_timer(0.3).timeout
	await capture("boss-stage-shard")
	stage.player.position = stage.shard.position
	await get_tree().create_timer(0.2).timeout
	stage.player.position = Vector3(7,0.1,-4)
	stage.player.aim_at(Vector3(-11,0,-7))
	await get_tree().create_timer(0.2).timeout
	await capture("boss-stage-deprivation")
	stage.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit()

func capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-139/"+file_name+".png")
	print("BOSS STAGE NATIVE: "+file_name)
