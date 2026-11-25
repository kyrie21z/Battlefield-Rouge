extends "res://tests/realm_player_effects_test.gd"
func _ready()->void:
	block(Vector3(0,-0.5,0),Vector3(40,1,40))
	player=preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	var enemy:=preload("res://actors/enemy/enemy.tscn").instantiate() as Enemy
	enemy.position=Vector3(0,0,-6)
	add_child(enemy)
	player.boons.register_enemy(enemy)
	await frames(3)
	check("Q resonance requires Slumber core",not player.fragments.try_slumber_resonance())
	player.fragments.acquire(0)
	player.fragments.configure_deprivation([0])
	check("independent resonance reaches live foe",player.fragments.try_slumber_resonance())
	check("real actor simulation becomes quarter speed",is_equal_approx(enemy.boon_time_scale,0.25))
	check("repeated use cannot skip cooldown",not player.fragments.try_slumber_resonance())
	var cooldown:=player.fragments.resonance_cooldown
	get_tree().paused=true
	await get_tree().create_timer(0.2,true).timeout
	check("pause freezes ability recovery",is_equal_approx(player.fragments.resonance_cooldown,cooldown))
	get_tree().paused=false
	await frames(190)
	check("temporary slow expires on real actor",is_equal_approx(enemy.boon_time_scale,1.0))
	check("rest deprivation remains active",player.fragments.deprivations.has(0))
	# 冷却现在是 RESONANCE_COOLDOWN（15 秒），等它真正归零再测遮挡，
	# 不要写死帧数——数值一改这里就会误报。
	for i in 1400:
		if player.fragments.resonance_cooldown <= 0.0:
			break
		await frames(1)
	block(Vector3(0,1,-3),Vector3(5,3,0.5))
	await frames(3)
	check("WORLD occlusion prevents resonance without spending cooldown",not player.fragments.try_slumber_resonance() and player.fragments.resonance_cooldown==0)
	for child in get_children():child.free()
	await frames(3)
	print("ALL PASSED (%d checks)" % checks if failures==0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures==0 else 1)
