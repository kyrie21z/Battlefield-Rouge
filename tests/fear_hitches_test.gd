extends Node
## Lifecycle assertions; elapsed frame timings belong to fear_hitches_bench.
var checks := 0
var failures := 0

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for index in count: await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stage := load("res://maps/realms/fear_1.tscn").instantiate() as RealmStage
	add_child(stage)
	stage.player.set_physics_process(false)
	stage.player.set_process_unhandled_input(false)
	var master: FearReaper
	for actor in stage.enemies:
		actor.set_physics_process(false)
		if actor is FearReaper: master = actor
	check("three ghosts prepared before the first cast",master._stock.size() == 3)
	var reserve := master._stock.duplicate()
	var ages: Array[float] = []
	for wisp in reserve: ages.append(wisp.elapsed)
	get_tree().paused = true
	var warm := master._warm_frames
	await frames(6)
	check("pause freezes warmup and dormant lifetimes",master._warm_frames == warm and reserve[0].elapsed == ages[0])
	get_tree().paused = false
	await frames(8)
	check("preparation hides all reserved ghosts",not reserve[0].visible and not reserve[1].visible and not reserve[2].visible)
	check("reserves have no physics or shootable layers",reserve[0].process_mode == Node.PROCESS_MODE_DISABLED and reserve[0].collision_layer == 0 and reserve[0].get_node("TorsoHitbox").collision_layer == 0)
	check("reserves never register with boon targeting",not stage.player.boons.enemies().has(reserve[0]))
	check("reserves do not change room kill count",stage.living_enemies() == 4)
	master.position = Vector3(0,0.05,10)
	master.apply_realm_scaling(1.4,1.2,1.15)
	stage.player.fragments.configure_deprivation([1])
	master.warnings_enabled = false
	master._summon()
	var live := master.living_wisps()
	check("cast activates the exact three reserved nodes",live.size() == 3 and reserve.has(live[0]) and reserve.has(live[1]) and reserve.has(live[2]))
	for wisp in live: wisp.set_physics_process(false)
	check("activation restores visibility and shootable layers",live[0].visible and live[0].collision_layer == CollisionLayers.ENEMIES and live[0].get_node("TorsoHitbox").collision_layer == CollisionLayers.HITBOXES)
	check("activation uses current health scale and deprivation",is_equal_approx(live[0].health.health,25.2) and is_equal_approx(live[0].realm_damage_scale,1.2) and is_equal_approx(live[0].realm_tempo_scale,1.15) and not live[0].warnings_enabled)
	check("only activated ghosts join boon targeting",stage.player.boons.enemies().has(live[0]) and stage.living_enemies() == 4)
	master._dismiss_wisps()
	await frames(8)
	check("spent ghosts are freed instead of reusing status-bearing actors",not is_instance_valid(reserve[0]) and not is_instance_valid(reserve[1]) and not is_instance_valid(reserve[2]))
	check("idle frames prepare a fresh reserve",master._stock.size() == 3)
	check("new reserves are hidden and unregistered",not master._stock[0].visible and not stage.player.boons.enemies().has(master._stock[0]))
	var fresh := master._stock.duplicate()
	var visual := (stage.enemies[0] as FearRealmEnemy).visual
	var debris := visual.get_meta(FearShatter.RESERVE_KEY) as FearShatter
	var piece := debris.pieces[0]
	var unused := (stage.enemies[1] as FearRealmEnemy).visual.get_meta(FearShatter.RESERVE_KEY) as FearShatter
	check("death reserves contain all 56 real rigid shards",debris.pieces.size() == 56 and piece is RigidBody3D)
	check("unused debris remains outside the physics world",not debris.is_inside_tree() and piece.freeze and piece.collision_mask == 0)
	check("collision geometry is shared rather than rebuilt per death",(piece.get_child(1) as CollisionShape3D).shape == FearShatter._collision_shapes[0])
	stage.enemies[0].health.apply_damage(100000,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
	check("death activates the exact prepared shard bodies",debris.started and debris.is_inside_tree() and debris.pieces[0] == piece)
	check("shards retain real world collision and outward motion",not piece.freeze and piece.collision_mask == CollisionLayers.WORLD and piece.linear_velocity.length() > 0.1)
	var point := piece.global_position
	await get_tree().create_timer(0.12).timeout
	check("prepared shards really move in native physics",piece.global_position.distance_to(point) > 0.01)
	get_tree().paused = true
	var elapsed := debris.elapsed
	await frames(5)
	check("pause freezes debris lifetime",debris.elapsed == elapsed)
	get_tree().paused = false
	debris.elapsed = 2.4
	debris._physics_process(0)
	check("retirement hides shards and frees only eight this tick",not debris.visible and debris.pieces.size() == 48)
	check("retiring bodies stop colliding immediately",debris.pieces[0].freeze and debris.pieces[0].collision_mask == 0)
	for index in 6: debris._physics_process(0)
	await frames(2)
	check("all retired debris is ultimately freed",not is_instance_valid(debris))
	var catalog := BoonCatalog.all()
	var count := catalog.size()
	catalog.clear()
	check("caller array edits cannot corrupt the catalog cache",count > 0 and BoonCatalog.all().size() == count)
	var card := BoonCatalog.eligible(stage.player.boons,1)[0]
	stage.player.boons.equip(card)
	check("cached definitions still evaluate live ownership",not BoonCatalog.eligible(stage.player.boons,1).has(card))
	stage.queue_free()
	await frames(4)
	check("room exit frees unused off-tree death reserves",not is_instance_valid(unused))
	check("room exit frees hidden ghosts",not is_instance_valid(fresh[0]) and not is_instance_valid(fresh[1]) and not is_instance_valid(fresh[2]))
	OS.delay_msec(250)
	print("FEAR HITCHES: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)
