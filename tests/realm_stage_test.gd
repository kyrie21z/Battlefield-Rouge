extends Node
var checks := 0
var failures := 0
var stage: RealmStage

func _ready() -> void:
	# the realm intro panel is a UI concern; these tests only care about the flow
	MetaProgression.introduced_realms.assign([0,1,2,3])
	process_mode = Node.PROCESS_MODE_ALWAYS
	stage = preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	stage.campaign = true
	stage.difficulty_multiplier = 1.5
	stage.configure_run(2,[0,1],[],65,[])
	add_child(stage)
	await frames(5)
	stage.player.set_physics_process(false)
	for enemy in stage.enemies:
		enemy.set_physics_process(false)
	check("generated map constructs geometry, player, HUD and three realm variants",stage.geometry != null and stage.player != null and stage.hud != null and stage.enemies.size()==3)
	check("baked WORLD geometry produces a navigation polygon",stage._region.navigation_mesh.get_polygon_count()>0)
	check("injected HP, depth and deprivations survive stage setup",stage.player.health.health==65 and stage.depth==2 and stage.deprivations==[0,1])
	check("inherited loss of Sloth extinguishes all Rest Zones",not stage.geometry.get("rest_enabled"))
	check("inherited loss of Fear removes enemy tells and damage arrows",not stage.enemies[0].get("warnings_enabled") and not stage.player.realm_effects.warnings_enabled)
	check("injected difficulty changes both enemy HP and damage",is_equal_approx(stage.enemies[0].health.max_health,165) and stage.enemies[0].get("realm_damage_scale")==1.5)
	check("locked exit refuses premature progress",not stage.request_exit())
	var rewards := [0]
	var rerolls := [0]
	stage.reward_selected.connect(func(_stage,_card):rewards[0]+=1)
	stage.reroll_spent.connect(func(_stage):rerolls[0]+=1)
	stage.offer_entry_reward()
	check("entry starter offer pauses without unlocking the gate",get_tree().paused and not stage.exit_ready and stage.selection._offered.size()==3)
	var opening: Array[BoonData] = stage.selection._offered.duplicate()
	stage.selection._request_reroll()
	check("real reroll spends one injected charge and refreshes choices",stage.rerolls_remaining==1 and rerolls[0]==1 and stage.selection._offered!=opening)
	stage.selection._choose(stage.selection._offered[0])
	await frames(2)
	check("starter choice resumes combat without awarding a room clear",rewards[0]==1 and not get_tree().paused and not stage.cleared and not stage.exit_ready)
	var deaths := [0]
	stage.stage_cleared.connect(func(_stage): deaths[0]+=1)
	for enemy in stage.enemies:
		enemy.health.apply_damage(9999,Hitbox.BodyPart.BODY,stage.player)
	await frames(3)
	check("actual final Health death clears the room once",stage.cleared and deaths[0]==1)
	check("the talent orb waits in front of the gate",stage.orb_pending())
	stage.claim_talent()
	await frames(2)
	check("claiming the orb opens the real BoonPicker and pauses combat",is_instance_valid(stage.selection) and get_tree().paused)
	check("reward draws three cards belonging to the realm",stage.selection._offered.size()==3 and stage.selection._offered.all(func(card):return card.sin==BoonData.Sin.SLOTH))
	check("exit remains locked before reward choice",not stage.exit_ready and not stage.request_exit())
	var selected := stage.selection._offered[0]
	stage.selection._choose(selected)
	await frames(2)
	check("selecting the actual card equips it and unpauses",stage.player.boons.has(selected.id) and not get_tree().paused)
	check("reward unlocks the gate without skipping to another room",stage.exit_ready and not stage.transitioning)
	check("distant gate cannot be activated",not stage.request_exit())
	stage.player.position = Vector3(0,0.1,-18.5)
	await frames(2)
	var exits := [0]
	stage.exit_requested.connect(func(_stage):exits[0]+=1)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5,4,0.2)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0,2,-19.2)
	stage.add_child(wall)
	await frames(2)
	check("WORLD wall blocks the otherwise nearby exit",not stage.request_exit())
	wall.queue_free()
	await frames(2)
	check("nearby unobstructed gate emits one campaign exit",stage.request_exit() and exits[0]==1)
	check("held or repeated interaction cannot emit twice",not stage.request_exit() and exits[0]==1)
	stage.transitioning = false
	PauseMenu.allow_headless = true
	check("reused pause menu opens and pauses the real room",stage.hud.pause_menu.try_open() and get_tree().paused)
	stage.hud.pause_menu.close()
	check("pause closes without losing captured movement",not get_tree().paused and stage.hud.pause_menu.capture_requests==1)
	PauseMenu.allow_headless = false
	stage.player.set_realm_effect(&"test_mono",{"monochrome":1.0})
	await frames(2)
	# process_frame is emitted before HUD _process; cross two signals so a full
	# idle update has completed even when several physics ticks share one frame.
	await get_tree().process_frame
	await get_tree().process_frame
	check("real realm effect drives the monochrome screen shader",stage.hud._monochrome.visible)
	var carried: Array = stage.player.boons.all_equipped()
	var fall_signals := [0]
	stage.player_fallen.connect(func(_stage,_cause):fall_signals[0]+=1)
	stage.player.health.apply_damage(9999,Hitbox.BodyPart.BODY,null)
	stage.player.health.apply_damage(9999,Hitbox.BodyPart.BODY,null)
	check("actual player death emits one failure and closes exit",stage.fallen and fall_signals[0]==1 and not stage.request_exit())
	stage.queue_free()
	await frames(3)
	var next := preload("res://maps/realms/sloth_2.tscn").instantiate() as RealmStage
	next.campaign = true
	next.configure_run(2,[0,1],[0],47,carried)
	add_child(next)
	next.player.set_physics_process(false)
	for actor in next.enemies:
		actor.set_physics_process(false)
	await frames(2)
	check("second generated room has five live actors",next.enemies.size()==5 and next.living_enemies()==5)
	check("room handoff restores actual HP, boons and independent shard",next.player.health.health==47 and next.player.boons.all_equipped()==carried and next.player.fragments.has_shard(0))
	check("restoring Slumber still preserves inherited dark Rest Zones",not next.geometry.get("rest_enabled"))
	next.queue_free()
	await frames(3)
	OS.delay_msec(250)
	print("REALM STAGE: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func check(label: String,passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(("PASS " if passed else "FAIL ")+label)
