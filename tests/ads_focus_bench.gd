extends Node3D
var player: Player
var frame := 0
func _ready() -> void:
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	player = stage.player
	player.set_physics_process(false)
	player.position = Vector3(0,0,10)
	player.aim_at(Vector3(-8,1.0,2))
	for enemy in stage.enemies:
		enemy.set_physics_process(false)
		if enemy.has_node("Model"): enemy.get_node("Model").set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func _process(_delta: float) -> void:
	frame += 1
	if frame == 60:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-171/white-space-contact-shadows.png")
		player.weapon.aiming = true
	if frame == 120:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-171/ads-target-focus.png")
		print("ADS NATIVE focus=%.3f amount=%.3f"%[player.get_node("ADSFocus").focus_distance,player.get_node("ADSFocus").amount])
	if frame == 125: get_tree().quit()
