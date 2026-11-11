extends Node
var checks := 0
var failures := 0
var output := ""
var rendered_checks := 0
var rooms_finished := 0

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for index in count: await get_tree().physics_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	for realm in ["fear","sorrow","sloth","wrath"]:
		await _room(realm)
	check("all four production room scenarios finish",rooms_finished == 4)
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		check("both production views complete their rendered checks",rendered_checks == 2)
	OS.delay_msec(250)
	print("REALM FEEDBACK: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _room(realm: String) -> void:
	var room := load("res://maps/realms/"+realm+"_1.tscn").instantiate() as RealmStage
	add_child(room)
	var player := room.player
	player.set_physics_process(false)
	player.set_process(false)
	player.dash.set_physics_process(false)
	for enemy in room.enemies: enemy.set_physics_process(false)
	player.health.health = player.health.max_health
	var feedback := room.hud.hurt_feedback
	await frames(3)
	check(realm+" production HUD starts with a clear border",feedback != null and not feedback.visible and feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var before: Image
	if realm in ["fear","sorrow"] and DisplayServer.get_name() != "headless" and not output.is_empty():
		await RenderingServer.frame_post_draw
		before = get_viewport().get_texture().get_image()
	player.health.apply_damage(10,Hitbox.BodyPart.BODY,room.enemies[0])
	check(realm+" real HP hit immediately lights the border",feedback.visible and feedback.color.a >= 0.30)
	if before != null:
		await _render_check(realm,before,feedback)
	var strength := feedback.color.a
	get_tree().paused = true
	await frames(5)
	check(realm+" pause freezes the existing pulse",feedback.color.a == strength)
	get_tree().paused = false
	await frames(40)
	check(realm+" pulse fades back to clear within 0.55 seconds",not feedback.visible and feedback.color.a == 0)
	player.health.invulnerable = true
	player.health.apply_damage(10,Hitbox.BodyPart.BODY,room.enemies[0])
	check(realm+" blocked hits do not fake HP loss feedback",not feedback.visible)
	player.health.invulnerable = false
	player.health.grant_shield(50)
	player.health.apply_damage(10,Hitbox.BodyPart.BODY,room.enemies[0])
	check(realm+" shield-only absorption does not flash red",not feedback.visible)
	player.health.shield_points = 0
	player.fragments.configure_deprivation([1])
	player.health.apply_damage(1,Hitbox.BodyPart.BODY,room.enemies[0])
	check(realm+" warning deprivation preserves non-directional HP feedback",not player.realm_effects.warnings_enabled and feedback.visible)
	for index in 5: player.health.apply_damage(5,Hitbox.BodyPart.BODY,room.enemies[0])
	check(realm+" a burst merges and stays under its opacity cap",feedback.color.a <= RealmHurtFeedback.MAX_ALPHA and feedback.color.a > 0.65)
	player.health.apply_damage(9999,Hitbox.BodyPart.BODY,null,{"true_damage":true})
	check(realm+" death clears the border for retry UI",player.health.is_dead() and not feedback.visible)
	room.queue_free()
	await frames(3)
	rooms_finished += 1

func _render_check(realm: String, before: Image, feedback: RealmHurtFeedback) -> void:
	await RenderingServer.frame_post_draw
	var after := get_viewport().get_texture().get_image()
	var width := after.get_width()
	var height := after.get_height()
	var edge := Vector2i(int(width*0.02),int(height*0.5))
	var middle := Vector2i(int(width*0.5),int(height*0.5))
	var old_edge := before.get_pixelv(edge)
	var new_edge := after.get_pixelv(edge)
	check(realm+" rendered edge gains visible red tint",new_edge.r-new_edge.g > old_edge.r-old_edge.g+0.1)
	var center_difference := (Vector3(after.get_pixelv(middle).r,after.get_pixelv(middle).g,after.get_pixelv(middle).b)-Vector3(before.get_pixelv(middle).r,before.get_pixelv(middle).g,before.get_pixelv(middle).b)).length()
	check(realm+" rendered aiming center stays clear",center_difference < 0.08 and feedback.size.x > 0)
	DirAccess.make_dir_recursive_absolute(output)
	check(realm+" native image saves",after.save_png(output.path_join(realm+"-red-edge.png")) == OK)
	rendered_checks += 1
