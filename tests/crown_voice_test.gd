extends Node3D
var checks := 0
var failures := 0
func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	check("level four exceeds fifteen without replacing the gameplay camera", crown.strength > 15 and player.view_camera.current)
	var camera_meshes := player.view_camera.find_children("*", "MeshInstance3D", true, false)
	check("the view camera has no crown prisms", camera_meshes.all(func(part: MeshInstance3D) -> bool:
		return not part.mesh is PrismMesh))
	var worn_meshes := crown.model.find_children("*", "MeshInstance3D", true, false)
	check("the worn crown is present as shadow-casting geometry", worn_meshes.size() == 42 and worn_meshes.all(func(part: MeshInstance3D) -> bool:
		return part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY))
	player._pitch = deg_to_rad(-75.0)
	player._apply_look()
	crown._process(0.0)
	check("looking down leaves the crown in body space above the skull", crown.model.global_basis.is_equal_approx(player.global_basis)
		and (crown.model.global_position - player._head.global_position).is_equal_approx(player.global_basis * CrownModel.WEAR_OFFSET))
	check("level four binds the production starburst postprocess",crown.glare.shader==preload("res://ui/shaders/blinding_glare.gdshader") and is_equal_approx(crown.glare.get_shader_parameter("intensity"),1.0) and int(crown.glare.get_shader_parameter("fracture_level"))==4)
	await get_tree().process_frame
	var glare_time:float=crown.glare.get_shader_parameter("visual_time")
	get_tree().paused=true
	await get_tree().create_timer(0.15,true).timeout
	check("paused crown freezes postprocess clock",is_equal_approx(glare_time,crown.glare.get_shader_parameter("visual_time")))
	get_tree().paused=false
	crown.reduced_motion=true
	await get_tree().process_frame
	await get_tree().process_frame
	check("reduced motion reaches the glare shader",crown.glare.get_shader_parameter("reduced_motion"))
	crown.set_cinematic_hidden(true)
	check("cinematics can suppress the Crown overlay and worn model", not crown.layer.visible and not crown.model.is_visible_in_tree())
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
