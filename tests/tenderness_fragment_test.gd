extends "res://tests/realm_player_effects_test.gd"
func _ready()->void:
	block(Vector3(0,-0.5,0),Vector3(30,1,30))
	player=preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	await frames(3)
	player.boons.equip(preload("res://buffs/resources/sorrow/sorrow_buffer.tres"))
	var effect:=player.boons.effect_for(preload("res://buffs/effects/sorrow_effect.gd")) as SorrowEffect
	player.health.apply_damage(40,Hitbox.BodyPart.BODY)
	check("ordinary burst initially defers half damage",is_equal_approx(player.health.health,80) and is_equal_approx(effect._traits.pending_damage(),20))
	player.fragments.configure_deprivation([3])
	await frames(3)
	check("existing debt settles after buffering loss",is_equal_approx(player.health.health,60) and is_zero_approx(effect._traits.pending_damage()))
	player.stats.set_modifier(&"test_reduction",{Stats.DAMAGE_TAKEN:{"mul":0.2}})
	player.health.shield_points=100
	player.boons.shield_amount=100
	player.health.damage_absorber=func(_amount):return 0.0
	player.health.invulnerable=true
	player.health.apply_damage(10,Hitbox.BodyPart.BODY)
	check("ordinary mitigation, shield and timed immunity cannot buffer",is_equal_approx(player.health.health,50))
	check("ordinary shield cannot be activated",not player.shield.try_activate())
	check("new damage cannot create deferred debt",is_zero_approx(effect._traits.pending_damage()))
	check("unbuffered HP damage emits brittle glass feedback",player.fragments.brittle_hits>=2)
	check("tenderness activates separate 60 point barrier",player.fragments.acquire(3) and is_equal_approx(player.fragments.barrier,60))
	var before:=player.health.health
	player.health.apply_damage(70,Hitbox.BodyPart.BODY)
	check("independent absorption handles exact overflow",is_equal_approx(before-player.health.health,10) and is_equal_approx(player.fragments.absorption_total,60))
	check("pickup does not restore ordinary defenses",player.health.unbuffered and player.health.shield_points==100 and player.boons.shield_amount==100)
	check("actual Health context accounts for independent absorption",is_equal_approx(player.health.last_damage_context.absorbed,60) and is_equal_approx(player.health.last_damage_context.dealt,10))
	await frames(210)
	check("barrier respects four second recovery delay",is_zero_approx(player.fragments.barrier))
	await frames(90)
	check("barrier recovers without healing lost HP",player.fragments.barrier>4 and player.fragments.barrier<8 and is_equal_approx(player.health.health,before-10))
	var barrier:=player.fragments.barrier
	get_tree().paused=true
	await get_tree().create_timer(0.2,true).timeout
	check("pause freezes fragment recharge",is_equal_approx(player.fragments.barrier,barrier))
	get_tree().paused=false
	player.fragments.barrier=60
	player.health.apply_damage(1,Hitbox.BodyPart.BODY,null,{"environmental_fatal":true})
	check("abyss bypasses all independent defenses",player.health.is_dead())
	for child in get_children(): child.free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("ALL PASSED (%d checks)" % checks if failures==0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures==0 else 1)
