extends Node
## Runs real scene changes, UI input, Health deaths, Area entry and blade input.
## Only this test accelerates blade cooldown and protects its walkthrough actor.
## It never assigns a director phase or a later RunState.zone_index.

const BOOT := "res://ui/game_start.tscn"
var checks := 0
var failures: Array[String] = []
var elapsed := 0.0
var finished := false
var proof_dir := ""
var scene_entries: Array[String] = []
var approach_samples: Array[Dictionary] = []
var pressure_samples: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--integration-proof="):
			proof_dir = argument.trim_prefix("--integration-proof=")
	if not proof_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("Native renderer is required for integration proof")
			get_tree().quit(1)
			return
		DirAccess.make_dir_recursive_absolute(proof_dir)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_title("Sloth整合验证（自动结束）")
	_run.call_deferred()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed>190.0 and not finished:
		push_error("Sloth integration test timed out")
		get_tree().quit(1)

func _run() -> void:
	# Keep this harness as a root sibling while the real entry replaces scenes.
	get_tree().current_scene = null
	RunState.clear_fixture()
	RunState.start_new_run()
	RunState.run_seed = 50897
	get_tree().paused = false
	_check(RunState.ZONE_SCENES.size()==3,"Run retains two small zones and one Boss")
	get_tree().change_scene_to_file(BOOT)
	await get_tree().scene_changed
	await get_tree().process_frame
	var boot := get_tree().current_scene
	var opening: Node3D = boot.opening
	opening.proof = true
	opening.proof_wait = -10000
	_check(opening.flow.state==opening.Flow.State.CINEMATIC,"Normal entry starts the Pride opening")
	_check(get_tree().get_nodes_in_group("player").is_empty(),"Combat player is absent behind the opening")
	await _shot("01-pride-opening")
	for index in 5:
		await _key(KEY_ENTER)
	_check(opening.flow.state==opening.Flow.State.DECISION,"Five real advance keys reach the departure choice")
	(opening.panels.decision.get_child(2) as Button).pressed.emit()
	await get_tree().scene_changed
	await _settle()
	_check(_director()!=null and RunState.zone_index==0,"Departure loads the actual first zone")
	_check(_director().selection_context=="enter" and get_tree().paused,"First zone pauses for its opening card")
	await _choose_card(0)
	_check(_director().phase==ZoneDirector.Phase.CLEAR_GUARDS and not get_tree().paused,"Opening card starts guard combat")
	for index in 3:
		await _zone(index)
	var contexts: Array[String] = []
	for entry in RunState.selection_history:
		contexts.append("%d:%s" % [entry.zone_index,entry.context])
	_check(contexts==["0:enter","0:clear","1:clear"],"Three real card selections remain ordered across all scene changes")
	_check(scene_entries==RunState.ZONE_SCENES,"Actual entered scenes match the run's level order")
	await _restart_and_die()
	finished = true
	_release_actions()
	get_tree().paused = false
	_write_approach_report()
	_write_pressure_report()
	print("SLOTH_INTEGRATION_SUMMARY | ",checks," checks | ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func _zone(index: int) -> void:
	var director := _director()
	var zone := get_tree().current_scene
	var player := director.get("_player") as Player
	scene_entries.append(zone.scene_file_path)
	_check(RunState.zone_index==index and director.zone_index==index,"Zone %d index comes from actual progression" % (index+1))
	_check(zone.scene_file_path==RunState.ZONE_SCENES[index],"Zone %d uses its generated playable map" % (index+1))
	_check(zone.get_node_or_null("Geometry")!=null and zone.get_node_or_null("HUD")!=null,"Zone %d has geometry and the real HUD" % (index+1))
	var hud := zone.get_node("HUD") as CanvasLayer
	var minimap := hud.get_node("Minimap") as Minimap
	_check(hud.get("_player")==player and hud.get("_director")==director,"Zone %d HUD reads the actual scene actors" % (index+1))
	_check(minimap.get("_player")==player and minimap.get("_director")==director and minimap.geometry_count()>0,"Zone %d minimap caches the new nested geometry" % (index+1))
	_check(not (director.get("_cover_points") as Array).is_empty(),"Zone %d exposes its new physical cover markers" % (index+1))
	_check(player.weapon.data != null and player.melee!=null and player.shield!=null,"Zone %d retains guns, melee and shield" % (index+1))
	_check(director.capture_point.locked,"Zone %d objective starts locked" % (index+1))
	if index>0:
		_check(director.selection_context.is_empty() and not get_tree().paused,"Later zone starts directly without an extra entry card")
	var guards: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if zone.is_ancestor_of(node): guards.append(node as Enemy)
	_check(guards.size()==director.enemies_total and guards.size()>0,"Zone %d guards are tracked by the director" % (index+1))
	_check(guards.all(func(enemy: Enemy)->bool:return enemy.target==player),"Zone %d guards target the real player" % (index+1))
	var new_minions := guards.filter(func(enemy: Enemy)->bool:return enemy.get_script().resource_path.contains("/sloth/"))
	_check(not new_minions.is_empty(),"Zone %d instantiates the new Sloth enemies" % (index+1))
	_check(new_minions.size()==[5,9,9][index],"Zone %d opening wave has two fewer Sloth enemies than the previous draft" % (index+1))
	# The active-observation phase deliberately lets real AI attack. Persistent
	# external immunity isolates this walkthrough; dash immunity is rewritten by
	# Player physics and therefore cannot protect a several-second observation.
	player.health.invulnerable = true
	player.health.dash_invulnerable = true
	await _opening_pressure(index, new_minions)
	# Freeze enemy decisions during geometry walking, without changing their life
	# or membership. The independent attack tests exercise the active patterns.
	for enemy in guards:
		enemy.set_physics_process(false)
		if enemy is SlothEnemy:enemy._cancel_attack()
	player.health.dash_invulnerable = true
	var entry_position := player.global_position
	if index<2:
		await _normal_approach(index,player,director.capture_point)
		player.global_position = entry_position
		player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	await _settle()
	await _navigation(index,director,player)
	if index==0:
		await _walk_routes(player)
	elif index==2:
		await _boss_route(player)
	player.global_position = entry_position
	player.aim_at(director.capture_point.global_position+Vector3.UP*3.0)
	player.set_physics_process(true)
	player.velocity = Vector3.ZERO
	await _settle()
	await _shot("%02d-zone-%d-combat" % [index*2+2,index+1])
	if director.is_boss_zone:
		_check(director.phase==ZoneDirector.Phase.BOSS_STANDING and director.boss!=null,"Boss uses the existing Boss contract")
		await _enter_clock_reach(player,director.capture_point,true)
		var before := director.capture_point.progress
		await _blade_strike(player)
		_check(director.capture_point.locked and director.capture_point.progress==before,"Real blade input cannot bypass the living Boss")
		director.boss.health.apply_damage(99999,Hitbox.BodyPart.BODY,player)
		_check(director.phase==ZoneDirector.Phase.CLOCK_POINT and not director.capture_point.locked,"Real Boss health death unlocks its core")
		_check(director.living_enemies().any(func(enemy: Enemy)->bool:return not enemy.is_boss),"Living Sloth minions do not block Boss core unlocking")
	else:
		for enemy in guards:
			enemy.health.apply_damage(99999,Hitbox.BodyPart.BODY,player)
		_check(director.phase==ZoneDirector.Phase.CLOCK_POINT and not director.capture_point.locked,"Real guard deaths unlock zone %d objective" % (index+1))
		_check(director.reinforcement_count()==4,"Zone %d opens with four actual reinforcement actors" % (index+1))
		for enemy in director.living_enemies():
			enemy.set_physics_process(false)
			_check(enemy.get_script().resource_path.contains("/sloth/"),"Reinforcement uses the new Sloth actor")
		await _enter_clock_reach(player,director.capture_point,false)
		await _shot("10-zone-%d-reinforcements" % (index+1))
	for attempt in 12:
		if director.capture_point.is_captured(): break
		await _blade_strike(player)
	_check(director.capture_point.is_captured() and director.phase==ZoneDirector.Phase.FLAG_PLANTED,"Zone %d is captured using blade input and Area reach" % (index+1))
	# Step back from the collapsing objective for legible native evidence.
	player.global_position = director.capture_point.global_position+Vector3(0,0.1,8.5 if director.is_boss_zone else 7.0)
	player.velocity = Vector3.ZERO
	player.aim_at(director.capture_point.global_position+Vector3.UP*2.0)
	await get_tree().create_timer(0.35).timeout
	if not director.is_boss_zone:
		_check(director.buff_pedestal!=null and director.selection==null,"Flag creates a pedestal but does not auto-open cards")
		_check(director.living_enemies().all(func(enemy: Enemy)->bool:return enemy.state==Enemy.State.FLEE),"Capture shockwave sends surviving new enemies into retreat")
		_check(director.living_enemies().all(func(enemy: Enemy)->bool:return enemy.get("active_attack")==null),"Retreat clears active new-enemy attacks")
		await _shot("%02d-zone-%d-flag" % [index*2+3,index+1])
		var pedestal := director.buff_pedestal
		player.global_position = pedestal.global_position+Vector3(0,0.05,1.4)
		player.velocity = Vector3.ZERO
		player.aim_at(pedestal.global_position+Vector3.UP)
		await _settle()
		_check(pedestal.in_range(player),"Player actually stands within the new map's pedestal range")
		await _key(KEY_F)
		_check(director.selection_context=="clear" and get_tree().paused,"Physical F input opens exactly one clear reward")
		await _shot("%02d-zone-%d-reward" % [index*2+3,index+1])
		await _choose_card((index+1)%3)
		await _wait_zone(index+1)
		_check(RunState.zone_index==index+1,"Clear card advances to the next real scene")
	else:
		await _shot("07-boss-core-captured")
		await get_tree().create_timer(ZoneDirector.FLAG_RAISE_TIME+0.12).timeout
		var ending := _end_screen(director)
		_check(ending!=null and get_tree().paused,"Captured Boss core reaches the victory screen")
		if ending!=null:
			_check((ending.get_node("Center/Box/Title") as Label).text=="胜利","Final result is victory")
		_check(director.selection_count==0 and director.buff_pedestal==null,"Boss grants no extra card or small-zone pedestal")
		await _shot("08-victory")

## Observe the authored actors without alerting, moving, or forcing their casts.
## The walkthrough player is protected; separate fixture battles keep real HP.
func _opening_pressure(index: int, minions: Array) -> void:
	var starts := {}
	var casting := {}
	var attacks := [0]
	var first_cast := -1.0
	var on_shot := func(_origin: Vector3) -> void: attacks[0] += 1
	Events.gunshot.connect(on_shot)
	for enemy in minions:starts[enemy.get_instance_id()] = enemy.global_position
	for frame in 210:
		await get_tree().physics_frame
		for enemy in minions:
			if is_instance_valid(enemy.active_attack):
				casting[enemy.get_instance_id()] = true
				if first_cast<0.0:first_cast=float(frame+1)/60.0
	Events.gunshot.disconnect(on_shot)
	var active := 0
	var moving_or_casting := 0
	var moved := 0
	for enemy in minions:
		if not enemy.state in [Enemy.State.IDLE,Enemy.State.DEAD,Enemy.State.FLEE]:active += 1
		var travelled: float = enemy.global_position.distance_to(starts[enemy.get_instance_id()])
		if travelled>0.25:moved += 1
		if travelled>0.25 or casting.has(enemy.get_instance_id()):moving_or_casting += 1
	_check(active*4>=minions.size()*3,"Zone %d starts at least 75 percent of the opening wave in active pursuit/combat" % (index+1))
	_check(moving_or_casting*4>=minions.size()*3,"Zone %d opening actors actually move or begin a readable attack within 3.5 seconds" % (index+1))
	_check(first_cast>=0.0 and casting.size()>0,"Zone %d produces a real opening warning/cast without a player shot or manual AI alert" % (index+1))
	pressure_samples.append({"zone":index+1,"seconds":3.5,"sloth_count":minions.size(),
		"active_count":active,"moved_count":moved,"moved_or_cast_count":moving_or_casting,
		"cast_actor_count":casting.size(),"first_observed_cast_seconds":first_cast,"gunshot_events":attacks[0],
		"method":"Authored opening actors observe a stationary protected player; no force-alert, begin_hunt, cast_attack, velocity or target replacement."})
	print("OPENING_PRESSURE | zone=",index+1," | count=",minions.size()," | active=",active,
		" | moved_or_cast=",moving_or_casting," | casts=",casting.size()," | first_cast=",first_cast," | shots=",attacks[0])
	await _shot("09-zone-%d-opening-pressure" % (index+1))
	# Restore authored positions for the separate collision/route walkthrough;
	# the sampled pressure above retains the actual movement and cast evidence.
	for enemy in minions:
		enemy.global_position = starts[enemy.get_instance_id()]
		enemy.velocity = Vector3.ZERO

func _write_pressure_report() -> void:
	var path := "res://artifacts/combat-pressure-report.json" if proof_dir.is_empty() else proof_dir.path_join("pressure-report.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({"samples":pressure_samples},"\t")+"\n")

func _navigation(index: int,director: ZoneDirector,player: Player) -> void:
	var region := director.navigation_region
	_check(region!=null,"Zone %d owns a navigation region" % (index+1))
	if region==null:return
	var map := region.get_navigation_map()
	_check(NavigationServer3D.map_get_iteration_id(map)>0,"Zone %d navigation has synchronized" % (index+1))
	var from := NavigationServer3D.map_get_closest_point(map,player.global_position)
	var goals: Array[Vector3] = [director.capture_point.global_position+Vector3(0,0,3.5)]
	if index<2:
		goals.append_array([_surface_center("SunkenCourt"),_surface_center("LeftGallery"),
			_surface_center("RightGallery"),Vector3(16.5,0,4)])
	var actor: Enemy
	for enemy in director.living_enemies():
		if not enemy.is_boss:
			actor = enemy
			break
	var agent := actor.get_node("Agent") as NavigationAgent3D if actor!=null else null
	_check(agent!=null,"Zone %d Sloth actor owns a real navigation agent" % (index+1))
	var previous_target := agent.target_position if agent!=null else Vector3.ZERO
	for goal in goals:
		var to := NavigationServer3D.map_get_closest_point(map,goal)
		var path := NavigationServer3D.map_get_path(map,from,to,true)
		_check(goal.distance_to(to)<2.2 and not path.is_empty() and path[-1].distance_to(to)<0.2,"Zone %d nav reaches %s at the intended level" % [index+1,goal])
		if agent!=null:
			# NavigationAgent receives the projected walkable point. A raw y=0
			# socket over a slope is not itself on the nav surface.
			agent.target_position = to
			await get_tree().physics_frame
			agent.get_next_path_position()
			_check(agent.is_target_reachable() and not agent.get_current_navigation_path().is_empty() and agent.get_final_position().distance_to(goal)<2.2,"Zone %d actual Sloth Agent reaches %s" % [index+1,goal])
	if agent!=null:agent.target_position = previous_target

func _walk_routes(player: Player) -> void:
	var old_mask := player.collision_mask
	player.collision_mask = CollisionLayers.WORLD | CollisionLayers.BOUNDARY
	var front := _surface("CenterFrontRamp")
	var back := _surface("CenterBackRamp")
	var left := _surface("LeftGalleryFrontRamp")
	var right := _surface("RightGalleryBackRamp")
	var bridge := _surface("CrossCourtBridge")
	var gallery := _surface("LeftGallery")
	var bounds: Vector4 = gallery.get_meta("surface_bounds")
	# The full-size side cover occupies the gallery's middle; the outer lane
	# remains a real capsule-width underpass beside it.
	var lower_x := bounds.x+0.2
	var routes := [
		[player.global_position,front.get_meta("surface_b"),front.get_meta("surface_a"),back.get_meta("surface_b")],
		[left.get_meta("surface_b"),left.get_meta("surface_a"),bridge.get_meta("surface_a"),
			bridge.get_meta("surface_b"),right.get_meta("surface_b"),right.get_meta("surface_a")],
		[Vector3(lower_x,0.1,bounds.w-1.5),Vector3(lower_x,0,bounds.y+1.5)],
	]
	for route_index in routes.size():
		var points: Array = routes[route_index]
		player.global_position = points[0]
		player.velocity = Vector3.ZERO
		await _settle()
		var reached := true
		for index in range(1,points.size()):
			reached = await _walk(player,points[index]) and reached
		_check(reached,"Real player capsule traverses integration route %d" % (route_index+1))
	player.collision_mask = old_mask

func _boss_route(player: Player) -> void:
	var map := player.get_world_3d().navigation_map
	var core_goal := _director().capture_point.global_position
	print("BOSS_DAIS_PATH | ",NavigationServer3D.map_get_path(map,player.global_position,core_goal,true))
	var old_mask := player.collision_mask
	player.collision_mask = CollisionLayers.WORLD | CollisionLayers.BOUNDARY
	player.velocity = Vector3.ZERO
	await _settle()
	var reached := true
	for goal in [Vector3(0,0.46,9),Vector3(0,0.46,-9),core_goal+Vector3(0,0,4.5)]:
		reached = await _walk(player,goal) and reached
	_check(reached,"Real player capsule crosses the Boss dais from entry toward the core")
	player.collision_mask = old_mask

func _surface(title: String) -> MeshInstance3D:
	return get_tree().current_scene.get_node("Geometry/RoomGeometry/WalkableShell/"+title) as MeshInstance3D

func _surface_center(title: String) -> Vector3:
	var surface := _surface(title)
	var bounds: Vector4 = surface.get_meta("surface_bounds")
	return Vector3((bounds.x+bounds.z)*0.5,float(surface.get_meta("surface_top")),(bounds.y+bounds.w)*0.5)

## Measure the user's actual complaint through Player's unchanged input and
## movement code. Enemy decisions are frozen, but collisions, slopes and Area
## detection stay real. No teleport, dash, custom velocity or faster jog is used.
func _normal_approach(index: int,player: Player,point: CapturePoint) -> void:
	_check(is_equal_approx(player.jog_speed,4.4),"Compact route retains the normal 4.4 m/s jog")
	var straight := Vector2(player.global_position.x-point.global_position.x,
		player.global_position.z-point.global_position.z).length()
	_check(straight<=25.0,"Zone %d spawn-to-point distance returns to the former 22/24 m scale" % (index+1))
	var entry := player.global_position
	var nav_map := player.get_world_3d().navigation_map
	var front_socket := point.global_position+Vector3(0,0,3)
	var nav_path := NavigationServer3D.map_get_path(nav_map,
		NavigationServer3D.map_get_closest_point(nav_map,entry),
		NavigationServer3D.map_get_closest_point(nav_map,front_socket),true)
	var nav_length := 0.0
	for item in range(1,nav_path.size()):nav_length += nav_path[item-1].distance_to(nav_path[item])
	_check(not nav_path.is_empty() and nav_length<26.0,
		"Zone %d navigation reaches the same front socket without a long detour" % (index+1))
	var start := Engine.get_physics_frames()
	var travelled := 0.0
	var previous := player.global_position
	player.set_physics_process(true)
	player.aim_at(point.global_position+Vector3.UP*1.5)
	Input.action_press("move_forward")
	for frame in 8*60:
		await get_tree().physics_frame
		travelled += previous.distance_to(player.global_position)
		previous = player.global_position
		if point.player_in_reach:break
	Input.action_release("move_forward")
	var seconds := float(Engine.get_physics_frames()-start)/60.0
	print("COMPACT_APPROACH | zone=",index+1," | straight_m=",straight,
		" | walk_m=",travelled," | normal_jog_seconds=",seconds," | old_straight_m=103")
	approach_samples.append({"zone":index+1,"start":_coordinates(entry),
		"capture":_coordinates(point.global_position),"nav_front_socket":_coordinates(front_socket),
		"actual_reach_position":_coordinates(player.global_position),"jog_speed":player.jog_speed,
		"move_speed_stat":player.stats.get_value(Stats.MOVE_SPEED),"direct_spawn_to_capture_m":straight,
		"nav_to_front_socket_m":nav_length,"normal_input_walk_m":travelled,
		"normal_input_physics_seconds":seconds,"actual_area_reached":point.player_in_reach,
		"previous_direct_spawn_to_capture_m":103.0,
		"previous_nav_to_front_socket_m":100.379 if index==0 else 101.358})
	_check(point.player_in_reach and seconds<8.0 and travelled<30.0,
		"Zone %d real normal-speed player reaches clock reach within eight seconds without a detour" % (index+1))
	_check(straight<103.0*0.25,"Zone %d removes over 75 percent of the previous 103 m approach" % (index+1))
	player.set_physics_process(false)

func _coordinates(at: Vector3) -> Array:
	return [at.x,at.y,at.z]

func _write_approach_report() -> void:
	var path := "res://artifacts/sloth-compact-approach.json" if proof_dir.is_empty() else proof_dir.path_join("approach-report.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"samples":approach_samples,
			"method":"Actual move_forward input through Player physics, unchanged jog and Stats; no teleport/dash/custom velocity during measurement. AI decisions frozen to isolate traversal. Navigation before/after samples use the same point + (0,0,3) front socket; actual Area-reach walk timings use their own explicitly recorded endpoint."},"\t")+"\n")

func _walk(player: Player,goal: Vector3) -> bool:
	var distance := Vector2(goal.x-player.position.x,goal.z-player.position.z).length()
	var budget := ceili((distance+4.0)/8.0*60.0)
	for frame in budget:
		await get_tree().physics_frame
		var delta := Vector3(goal.x-player.position.x,0,goal.z-player.position.z)
		if delta.length()<0.30:
			return absf(player.position.y-goal.y)<0.70
		var direction := delta.normalized()
		player.velocity.x = direction.x*8.0
		player.velocity.z = direction.z*8.0
		if not player.is_on_floor():player.velocity.y-=9.8/60.0
		player.move_and_slide()
	print("TRAVERSE_INCOMPLETE | ",player.position," -> ",goal)
	return false

func _enter_clock_reach(player: Player,point: CapturePoint,boss: bool) -> void:
	player.global_position = point.global_position+Vector3(0,0.1,3.3 if boss else 2.6)
	player.velocity = Vector3.ZERO
	player.aim_at(point.global_position+Vector3.UP)
	await _settle()
	_check(point.player_in_reach,"Objective Area detects the real Player body in clock reach")

func _blade_strike(player: Player) -> void:
	player.melee.set_process(true)
	player.melee.cancel()
	player.melee.set("_cooldown",0.0)
	await _key(KEY_V)
	await get_tree().create_timer(0.36).timeout


func _choose_card(index: int) -> void:
	var director := _director()
	var count := RunState.buffs.size()
	await _key(KEY_1+index)
	_check(RunState.buffs.size()==count+1,"Physical card key commits exactly one buff")
	if is_instance_valid(director) and director.selection!=null:
		_check(false,"Card UI unexpectedly remains after selection")

func _restart_and_die() -> void:
	await _key(KEY_R)
	await _wait_zone(0)
	_check(_director().selection_context=="enter" and RunState.buffs.is_empty() and RunState.selection_history.is_empty(),"Victory restart resets the run and opens one entry choice")
	_check(get_tree().current_scene.scene_file_path==RunState.ZONE_SCENES[0],"Restart goes directly to zone one, not the opening")
	await _choose_card(0)
	var player := _director().get("_player") as Player
	player.health.invulnerable = false
	player.health.dash_invulnerable = false
	player.health.apply_damage(99999,Hitbox.BodyPart.BODY)
	await get_tree().process_frame
	_check(_end_screen(_director())!=null and RunState.buffs.is_empty() and RunState.selection_history.is_empty(),"Real player death opens defeat and clears the build")
	await _key(KEY_R)
	await _wait_zone(0)
	_check(_director().selection_context=="enter" and _director().selection_count==1,"Defeat restart creates one fresh entry choice")

func _wait_zone(index: int) -> void:
	for frame in 180:
		await get_tree().process_frame
		var director := _director()
		if director!=null and director.zone_index==index and RunState.zone_index==index:
			await _settle()
			return
	_check(false,"Scene transition timed out at zone %d" % index)

func _settle() -> void:
	for frame in 4: await get_tree().physics_frame

func _key(code: int) -> void:
	# Timers resume after nodes have processed. Inject on the next frame's
	# pre-process signal, otherwise just_pressed can expire before melee polls.
	await get_tree().process_frame
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in 2:await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in 2:await get_tree().process_frame

func _director() -> ZoneDirector:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("ZoneDirector") as ZoneDirector if scene!=null else null

func _end_screen(director: ZoneDirector) -> Node:
	if director!=null:
		for child in director.get_children():
			if child.has_signal("restart_pressed"):return child
	return null

func _shot(title: String) -> void:
	if proof_dir.is_empty():return
	await RenderingServer.frame_post_draw
	var path := proof_dir.path_join(title+".png")
	_check(get_viewport().get_texture().get_image().save_png(path)==OK,"Native proof saved: "+title)

func _release_actions() -> void:
	for action in ["melee","interact","fire","aim","reload","move_forward"]:
		Input.action_release(action)

func _check(ok: bool,message: String) -> void:
	checks += 1
	print("PASS | " if ok else "FAIL | ",message)
	if not ok:failures.append(message)
