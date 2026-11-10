extends Node3D
var checks := 0
var failures := 0
func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
func _ready() -> void:
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var crown := player.get_node("CrownVoiceSystem") as CrownVoiceSystem
	check("production Player owns one real CrownVoiceSystem and no fallback crown", crown != null and player.get_node_or_null("CrownRadiance") == null)
	check("database contains eleven real spoken audio clips", crown.DATABASE.lines.size() == 11 and crown.DATABASE.lines.values().all(func(row: Dictionary) -> bool: return (row.clip as AudioStream).get_length() > 1.0))
	for item in [[1,0,"","first"],[2,1,"combat","early"],[3,1,"abyss","early_abyss"],[3,3,"combat","deep"],[5,4,"abyss","deep_abyss"],[9,2,"combat","veteran"],[9,1,"environment","veteran_abyss"]]:
		crown.configure_history(item[0],item[1],item[2])
		await get_tree().process_frame
		await get_tree().process_frame
		check("history selects and actually plays " + item[3], crown.current_key == item[3] and crown.audio.playing and not crown.subtitle.text.is_empty())
		check("replacement keeps a single active voice source", crown.find_children("*","AudioStreamPlayer",true,false).size() == 1)
	crown.configure_history(4,3,"combat")
	crown.enter_floor(4)
	await get_tree().process_frame
	check("new floor replaces deferred history without overlapping speech", crown.current_key == "floor4" and crown.audio.stream == crown.DATABASE.lines.floor4.clip)
	var count := crown.played_keys.size()
	crown.enter_floor(4)
	check("duplicate floor notification does not restart a spoken line", crown.played_keys.size() == count)
	crown.configure_history(4,3,"combat",false)
	crown.enter_floor(3)
	await get_tree().process_frame
	check("ordinary room transition can explicitly suppress duplicate speech", not crown.audio.playing and crown.current_key.is_empty())
	var values := [0.5,1.2,2.88,6.912,16.5888]
	for level in 5:
		Events.sin_defeated.emit(level)
		check("fracture %d updates actual emissive material" % level, is_equal_approx(crown.strength, values[level]) and is_equal_approx(float(crown.material.get_shader_parameter("emission_strength")), values[level]))
	check("level four exceeds fifteen without replacing the gameplay camera", crown.strength > 15 and player.view_camera.current and crown.edge_meshes.size() == 2)
	crown.set_cinematic_hidden(true)
	check("opening can suppress every Crown presentation including camera children", not crown.layer.visible and crown.edge_meshes.all(func(m: MeshInstance3D) -> bool: return not m.visible))
	crown.set_cinematic_hidden(false)
	crown.configure_history(5,4,"combat")
	await get_tree().process_frame
	player.health.apply_damage(99999, Hitbox.BodyPart.BODY)
	check("actual Player death stops speech and clears subtitles and glare", not crown.audio.playing and crown.subtitle.text.is_empty() and not crown.layer.visible)
	crown.configure_history(6,4,"abyss")
	await get_tree().process_frame
	check("a dead Player cannot resume a deferred re-entry line", not crown.audio.playing)
	player.queue_free()
	await get_tree().process_frame
	var replacement := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(replacement)
	replacement.set_physics_process(false)
	var returned := replacement.get_node("CrownVoiceSystem") as CrownVoiceSystem
	returned.configure_history(6,4,"abyss")
	await get_tree().process_frame
	check("new living Player speaks the actual historical death response", returned.current_key == "deep_abyss" and returned.audio.playing)
	replacement.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	print("CROWN VOICE: %s (%d checks, %d failures)" % ["ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
