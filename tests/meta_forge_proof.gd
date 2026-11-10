extends Node
var bench: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bench = preload("res://tests/meta_forge_bench.tscn").instantiate()
	add_child(bench)
	await get_tree().create_timer(0.5,true).timeout
	await capture("forge-before")
	for id in ["resolve","resolve","reflex","focus","reroll","keepsake_slots","defiance"]:
		(bench.forge._cards[id].button as Button).pressed.emit()
	await get_tree().create_timer(0.3,true).timeout
	await capture("forge-after")
	print("META FORGE PURCHASES: wallet=%d/%d HP=%d slots=%d/%d" % [bench.store.will_shards,bench.store.reality_anchors,bench.player.health.max_health,bench.store.slots_used(),bench.store.slots_capacity()])
	bench.queue_free()
	await get_tree().process_frame
	get_tree().paused=false
	OS.delay_msec(250)
	get_tree().quit()

func capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-152/"+file_name+".png")
	print("META FORGE NATIVE: "+file_name)
