extends "res://tests/realm_player_effects_test.gd"
func _ready()->void:
	block(Vector3(0,-0.5,0),Vector3(30,1,30))
	block(Vector3(0,2,-5.5),Vector3(10,4,0.5))
	player=preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	var foe:=preload("res://actors/enemy/enemy.tscn").instantiate() as Enemy
	foe.position=Vector3(0,0,-3)
	add_child(foe)
	foe.health.max_health=1000
	foe.health.health=1000
	player.boons.register_enemy(foe)
	player.boons.equip(preload("res://buffs/resources/wrath/wrath_gun_cannon.tres"))
	await frames(5)
	foe.apply_impact(Vector3.FORWARD,10,0.4)
	check("ordinary force available before deprivation",foe._impact_left>0)
	player.fragments.configure_deprivation([2])
	check("loss clears in-flight ordinary force",foe._impact_left==0 and not foe.ordinary_impacts_enabled)
	# This checks deprivation, so aim at the real body and remove random misses.
	# Duplicate the resource to leave production weapon data unchanged.
	player.aim_at(foe.get_node("Model/CharacterArmature/Skeleton3D/TorsoAttach/TorsoHitbox").global_position)
	player.weapon.data = player.weapon.data.duplicate() as WeaponData
	player.weapon.data.hip_spread = 0.0
	player.weapon.data.spread_per_shot = 0.0
	var hp:=foe.health.health
	check("real weapon still fires after loss",player.weapon.try_fire())
	await frames(3)
	check("actual cannon shot damages without ordinary knockback",foe.health.health<hp and foe._impact_left==0)
	var status:=SpiteStatus.new()
	add_child(status)
	status.legendary=true
	status.arm(foe,Vector3.FORWARD,30,1,{})
	check("deprived knockback cannot arm phantom wall-slam",not status.is_active())
	check("spite pickup is independent",player.fragments.acquire(2) and not foe.ordinary_impacts_enabled)
	var start:=foe.position
	player.health.apply_damage(10,Hitbox.BodyPart.BODY,foe)
	check("incoming HP hit activates separate counterforce",player.fragments.counterpushes==1 and foe._impact_left>0)
	await frames(28)
	check("counterforce moves real enemy",foe.position.distance_to(start)>0.8)
	check("counterforce stops at WORLD wall",foe.position.z>-5.3)
	foe.apply_impact(Vector3.BACK,20,1)
	check("ordinary impacts remain disabled after counterforce",not foe.ordinary_impacts_enabled and foe._impact_left<=0)
	await frames(40)
	for hit in 2:
		foe.health.apply_damage(1,Hitbox.BodyPart.BODY,player,{"kind":&"gun","proc_depth":0})
	check("two weapon hits charge separate pulse without impact",player.fragments.spite_charge==2 and foe._impact_left<=0)
	foe.health.apply_damage(1,Hitbox.BodyPart.BODY,player,{"kind":&"blade","proc_depth":0})
	check("third direct weapon hit discharges independent shard",player.fragments.spite_charge==0 and player.fragments.counterpushes==2 and foe._impact_left>0)
	player.fragments.configure_deprivation([1,2])
	check("cumulative rules retain independent power",player.fragments.has_shard(2) and not player.realm_effects.warnings_enabled)
	for child in get_children(): child.free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("ALL PASSED (%d checks)" % checks if failures==0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures==0 else 1)
