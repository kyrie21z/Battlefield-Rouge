extends Node
func _ready() -> void:
	var writing := OS.get_cmdline_user_args().has("--write")
	var valid := MetaProgression.isolated_profile and MetaProgression.save_path().begins_with("user://meta_test_")
	if writing:
		RunDirector.begin_run(152071)
		RunDirector.earned_will=137
		RunDirector.earned_anchors=4
		RunDirector.floor_index=2
		RunDirector.record_death(&"abyss")
		valid=valid and MetaProgression.purchase("resolve") and MetaProgression.will_shards==117 and MetaProgression.reality_anchors==4 and MetaProgression.level("resolve")==1
		print("META HISTORY PROCESS WRITE: %s wallet=%d/%d runs=%d depth=%d cause=%s" % ["PASS" if valid else "FAIL",MetaProgression.will_shards,MetaProgression.reality_anchors,RunDirector.run_count,RunDirector.last_death_depth,RunDirector.last_death_cause])
	else:
		valid=valid and MetaProgression.load_status=="loaded" and MetaProgression.will_shards==117 and MetaProgression.reality_anchors==4 and MetaProgression.level("resolve")==1 and RunDirector.run_count==1 and RunDirector.last_death_depth==3 and RunDirector.last_death_cause==&"abyss"
		RunDirector.begin_run(152072)
		var player:=preload("res://actors/player/player.tscn").instantiate() as Player
		add_child(player)
		player.set_physics_process(false)
		RunDirector.restore_player(player)
		await get_tree().process_frame
		valid=valid and RunDirector.run_count==2 and player.health.max_health==110 and player.health.health==110 and player.get_node("CrownVoiceSystem").played_keys.has("deep_abyss")
		print("META HISTORY PROCESS READ: %s wallet=%d/%d runs=%d depth=%d voice=%s" % ["PASS" if valid else "FAIL",MetaProgression.will_shards,MetaProgression.reality_anchors,RunDirector.run_count,RunDirector.last_death_depth,player.get_node("CrownVoiceSystem").played_keys])
		player.queue_free()
		for suffix in ["",".bak",".tmp"]:
			var path: String = MetaProgression.save_path()+suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for frame in 4: await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	get_tree().quit(0 if valid else 1)
