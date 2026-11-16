extends Node
var checks := 0
var failures := 0
var output := ""

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for index in count: await get_tree().process_frame

func interact() -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(1)
	event = InputEventAction.new()
	event.action = &"interact"
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(1)

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(label+" native capture",get_viewport().get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
	get_tree().paused = false

func make_room(index: int) -> RealmStage:
	var room := load("res://maps/realms/fear_%d.tscn" % index).instantiate() as RealmStage
	add_child(room)
	room.player.set_physics_process(false)
	room.player.set_process_unhandled_input(false)
	for actor in room.enemies: actor.set_physics_process(false)
	return room

func clear_room(room: RealmStage) -> void:
	for actor in room.enemies:
		actor.health.apply_damage(100000,Hitbox.BodyPart.BODY,room.player,{"true_damage":true})

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	var room := make_room(1)
	var prepared := room._prepared_orb
	check("reward definitions are resident before any pickup",not BoonCatalog._cards.is_empty())
	print("AUTHORED ORB: pieces=",prepared._pieces.size()," seconds=",prepared.assembly_seconds())
	check("Fear loads one unclaimed standby orb",is_instance_valid(prepared) and room.talent_orb == null and not room.orb_pending())
	check("standby cannot block actors or bullets",prepared._body.collision_layer == CollisionLayers.NONE)
	check("standby clock and animations do not advance",prepared.process_mode == Node.PROCESS_MODE_DISABLED and prepared._pieces.size() == 102)
	check("assembly keeps the imported model's 4.34-second schedule",is_equal_approx(prepared.assembly_seconds(),4.34))
	var warm := room._orb_warm_frames
	get_tree().paused = true
	await frames(6)
	check("pause freezes preparation progress",room._orb_warm_frames == warm)
	get_tree().paused = false
	await frames(8)
	check("standby is hidden after warmup",not prepared.visible and room._orb_warm_frames == 0)
	check("warmup restores all fragments to unrevealed state",prepared._pieces.all(func(p: Dictionary) -> bool: return is_equal_approx((p.node as MeshInstance3D).transparency,1.0)))
	check("warmup does not expose the cube",not prepared._core.visible)
	check("combat still hides the pickup prompt",not room.hud._exit_hint.visible)
	var targets: Array[Transform3D] = []
	var meshes: Array[MeshInstance3D] = []
	for piece in prepared._pieces:
		targets.append(piece.target)
		meshes.append(piece.node)
	clear_room(room)
	await frames(3)
	check("real final kill activates the exact prepared orb",room.cleared and room.talent_orb == prepared and room._prepared_orb == null)
	check("clear stays unpaused and waits for interact",not get_tree().paused and room.selection == null and not room.exit_ready and room.orb_pending())
	check("pickup regains authored size and real WORLD collision",prepared.scale == Vector3.ONE and prepared.visible and prepared._body.collision_layer == CollisionLayers.WORLD)
	check("pickup stands in front of the current gate",prepared.global_position.distance_to(room.gate.global_position) > 1.95 and prepared.global_position.distance_to(room.gate.global_position) < 3.0)
	room.player.position = prepared.position + Vector3(0,-1.28,3.5)
	room.player.aim_at(prepared.global_position)
	await get_tree().create_timer(1.2).timeout
	await capture("fear-orb-assembling")
	get_tree().paused = true
	var pose := meshes[0].transform
	await frames(6)
	check("pause freezes an active assembly tween",meshes[0].transform == pose)
	get_tree().paused = false
	await get_tree().create_timer(4.8).timeout
	var assembled := true
	for index in meshes.size(): assembled = assembled and meshes[index].transform.is_equal_approx(targets[index]) and is_zero_approx(meshes[index].transparency)
	check("all 102 imported fragments reach their original authored poses",assembled)
	check("cube ignites and idle motion resumes",prepared._core.visible and prepared.is_ready() and prepared._core.scale.is_equal_approx(Vector3.ONE))
	await capture("fear-orb-ready")
	room.player.position = prepared.position + Vector3(0,-1.28,2)
	check("player can reach the solid orb within 2.8m",prepared.player_in_range(room.player))
	await interact()
	check("actual F input consumes the orb and opens the paused picker",not room.orb_pending() and is_instance_valid(room.selection) and get_tree().paused)
	check("claim immediately removes its invisible-wall risk",prepared._body.collision_layer == CollisionLayers.NONE)
	var picker := room.selection
	await interact()
	check("repeated F cannot open another picker",room.selection == picker)
	picker._choose(room._reward_offer[0])
	await frames(4)
	check("accepting the actual card unlocks the gate and resumes play",room.exit_ready and not get_tree().paused and room.selection == null)
	await get_tree().create_timer(0.4).timeout
	check("consumed orb fully frees after absorption",not is_instance_valid(prepared))
	var exits := [0]
	room.exit_requested.connect(func(_stage: RealmStage): exits[0] += 1)
	room.player.position = room.gate.position + Vector3(0,0.1,1)
	await interact()
	await interact()
	check("next F requests exactly one next-room transition",exits[0] == 1 and room.transitioning)
	room.queue_free()
	await frames(3)
	room = make_room(2)
	prepared = room._prepared_orb
	clear_room(room)
	await frames(3)
	check("immediate debug clear safely interrupts startup warmup",room.talent_orb == prepared and room._orb_warm_frames == 0 and prepared.scale == Vector3.ONE and prepared.visible)
	room.queue_free()
	await frames(3)
	check("leaving mid-assembly frees the prepared model and tweens",not is_instance_valid(prepared))
	OS.delay_msec(250)
	print("FEAR ORB FLOW: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)
