extends Node3D
class WarningEnemy extends Enemy:
	var warnings_enabled := true
var checks := 0
var failures := 0
func check(label:String,ok:bool)->void:
	checks += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures += 1
func _ready()->void:
	var player:=preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var foe:=Node3D.new()
	add_child(foe)
	foe.position=Vector3(2,0,-2)
	var indicator:=DamageIndicator.new()
	add_child(indicator)
	indicator.setup(player)
	indicator.add_hit(foe,20)
	check("ordinary direction warning starts enabled",indicator.entry_count()==1)
	var critical:=player.stats.get_value(Stats.CRIT_CHANCE)
	var recharge:=player.stats.get_value(Stats.DASH_RECHARGE)
	player.fragments.configure_deprivation([1])
	await get_tree().process_frame
	await get_tree().process_frame
	check("deprivation removes existing HUD warnings",indicator.entry_count()==0)
	indicator.add_hit(foe,20)
	check("deprivation blocks later HUD warnings",indicator.entry_count()==0)
	check("vigilance pickup activates once",player.fragments.acquire(1) and not player.fragments.acquire(1))
	check("independent vigilance raises critical perception",is_equal_approx(player.stats.get_value(Stats.CRIT_CHANCE),critical+0.15))
	check("independent vigilance improves reaction recharge",is_equal_approx(player.stats.get_value(Stats.DASH_RECHARGE),recharge*1.2))
	check("pickup does not restore ordinary warnings",not player.realm_effects.warnings_enabled)
	player.fragments.restore([1,1])
	check("repeated restoration does not stack modifiers",is_equal_approx(player.stats.get_value(Stats.CRIT_CHANCE),critical+0.15))
	player.fragments.restore([])
	check("restoration removes absent power",is_equal_approx(player.stats.get_value(Stats.CRIT_CHANCE),critical))
	var simulated:=WarningEnemy.new()
	player.fragments._apply_enemy_rules(simulated)
	check("new enemy warnings inherit deprivation",not simulated.warnings_enabled)
	player.fragments.configure_deprivation([])
	player.fragments._apply_enemy_rules(simulated)
	check("fresh run can restore warning rules",simulated.warnings_enabled and player.realm_effects.warnings_enabled)
	simulated.free()
	for child in get_children(): child.free()
	await get_tree().process_frame
	print("ALL PASSED (%d checks)" % checks if failures==0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures==0 else 1)
