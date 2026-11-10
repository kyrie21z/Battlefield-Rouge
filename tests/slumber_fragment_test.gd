extends Node3D
var failures := 0
var checks := 0
var player: Player
func check(label:String,ok:bool)->void:
	checks += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures += 1
func frames(count:int)->void:
	for i in count: await get_tree().physics_frame
func block(pos:Vector3,size:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new()
	body.position=pos
	body.collision_layer=CollisionLayers.WORLD
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	add_child(body)
	return body
func _ready()->void:
	block(Vector3(0,-0.5,0),Vector3(50,1,50))
	player=preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	await frames(5)
	player.fragments.configure_deprivation([0])
	var pickup:=PsycheShardPickup.new()
	pickup.position=Vector3(4,0,0)
	pickup.setup(player)
	add_child(pickup)
	check("distant shard cannot be collected",not pickup.try_collect())
	pickup.position=Vector3(1,0,0)
	var wall:=block(Vector3(0.5,1,0),Vector3(0.1,2,2))
	await frames(2)
	check("WORLD wall blocks pickup",not pickup.consumed and not pickup.try_collect())
	wall.queue_free()
	await frames(4)
	check("walking into range collects actual shard once",player.fragments.has_shard(0))
	check("duplicate pickup does not stack",not player.fragments.acquire(0))
	check("independent power retains deprivation",player.fragments.deprivations.has(0))
	player.health.apply_damage(30,Hitbox.BodyPart.BODY)
	var hurt_hp:=player.health.health
	await frames(240)
	check("no healing during five second combat grace",is_equal_approx(player.health.health,hurt_hp))
	await frames(120)
	check("slumber restores HP outside combat",player.health.health>hurt_hp+1.0 and player.health.health<hurt_hp+3.0)
	var before:=player.health.health
	get_tree().paused=true
	await get_tree().create_timer(0.3,true).timeout
	check("pause freezes healing",is_equal_approx(player.health.health,before))
	get_tree().paused=false
	var enemy:=preload("res://actors/enemy/enemy.tscn").instantiate() as Enemy
	enemy.position=Vector3(0,0,-8)
	add_child(enemy)
	player.boons.register_enemy(enemy)
	await frames(5)
	before=player.health.health
	await frames(90)
	check("nearby visible live foe prevents rest healing",is_equal_approx(player.health.health,before))
	enemy.health.apply_damage(10000,Hitbox.BodyPart.BODY,player)
	await frames(330)
	check("healing resumes after foe is dead and combat ends",player.health.health>before)
	player.fragments.restore([0,0])
	check("restoration deduplicates persistent shards",player.fragments.shards.size()==1)
	player.health.apply_damage(1,Hitbox.BodyPart.BODY,null,{"environmental_fatal":true})
	await frames(330)
	check("fragment cannot revive dead player",player.health.is_dead())
	for child in get_children(): child.free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("ALL PASSED (%d checks)" % checks if failures==0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures==0 else 1)
