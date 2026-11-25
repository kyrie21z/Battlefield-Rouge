extends Node3D
var checks := 0
var failures := 0
var player: Player
var boss: FearOculus
var realm: FearRealm
var victories := 0
var bench: Node3D

func _ready() -> void:
	await run_checks()
	get_tree().paused = false
	for child in get_children():
		stop_audio(child)
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("FEAR OCULUS: %s (%d checks, %d failures)" % ["ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func run_checks() -> void:
	bench = preload("res://tests/fear_oculus_bench.tscn").instantiate()
	add_child(bench)
	realm = bench.realm
	player = bench.player
	boss = bench.boss
	player.position = Vector3(0, 0.02, 8)
	player.set_physics_process(false)
	player.dash.set_physics_process(false)
	boss.set_physics_process(false)
	boss.defeated.connect(func() -> void: victories += 1)
	await frames(3)
	check("three independently rotating rings use 36 actual humanoid limb meshes", boss.visual.rings.size() == 3 and boss.visual.pieces.size() == 36)
	check("boss prepares all collision shapes before any killing shot",FearShatter._collision_shapes.size() == 56)
	var hp := boss.health.health
	boss.health.apply_damage(100, Hitbox.BodyPart.BODY, player)
	check("closed iris reduces actual damage to forty percent", is_equal_approx(hp - boss.health.health, 40))
	boss.phase = 2
	hp = boss.health.health
	boss.health.apply_damage(100, Hitbox.BodyPart.BODY, player)
	check("recovery opens a full-damage vulnerability window", is_equal_approx(hp - boss.health.health, 100))
	boss.start_attack(0)
	var time := boss.phase_time
	get_tree().paused = true
	boss.advance_attack(5)
	check("pause leaves windup and damage unchanged", boss.phase_time == time)
	get_tree().paused = false
	boss.boon_time_scale = 0
	boss._physics_process(3)
	check("Boon time stop freezes the actual boss state machine", boss.phase_time == time)
	boss.boon_time_scale = 1
	boss.advance_attack(boss.windup() + 0.01)
	check("charged scan enters active phase exactly once", boss.phase == 1 and boss.attack_count == 1)
	var direction := (player.global_position + Vector3.UP - boss.eye_position()).normalized()
	hp = player.health.health
	boss.scan_damage(direction)
	check("gaze cone applies real HP damage inside the cone", player.health.health < hp)
	check("staring into the open pupil slows the player", boss.gaze_punishments == 1 and is_equal_approx(player.realm_effects.move_multiplier, 0.62))
	hp = player.health.health
	boss.scan_damage(-direction)
	check("outside gaze cone is safe", player.health.health == hp)
	var wall := block(Vector3(0, 3, 0), Vector3(5, 7, 0.5))
	await frames(2)
	boss.scan_damage(direction)
	check("solid cover blocks gaze damage", player.health.health == hp)
	wall.queue_free()
	await frames(2)
	boss.start_attack(1)
	direction = (player.global_position + Vector3.UP - boss.eye_position()).normalized()
	boss.beam_damage(direction)
	check("cutting beam resolves a real Hitbox ray", player.health.health < hp)
	hp = player.health.health
	wall = block(Vector3(0, 3, 0), Vector3(5, 7, 0.5))
	await frames(2)
	boss.beam_damage(direction)
	check("beam terminates at cover rather than damaging through it", player.health.health == hp)
	wall.queue_free()
	await frames(2)
	boss.start_attack(2)
	boss.advance_attack(boss.windup() + 0.01)
	check("iris contraction releases twenty-four actual swept projectiles", boss._projectiles.size() == 24)
	check("ring contraction drops the bridge tile under the player", realm.tiles.any(func(tile: FearFlipTile) -> bool: return tile.elapsed >= 0.0))
	check("ring contraction releases two living pursuit wisps", boss.living_wisps().size() == 2)
	await frames(80)
	check("ground-height ring reaches and damages the standing player", player.health.health < hp)
	boss.start_attack(1)
	boss.warnings_enabled = false
	boss.advance_attack(0.3)
	check("deprivation hides and silences tell without canceling attack", not boss._beam.visible and not boss._alarm.playing and boss.phase == 0)
	boss.advance_attack(1.3)
	boss.advance_attack(0.1)
	check("actual damaging beam stays visible after warning deprivation", boss._beam.visible and boss.phase == 1)
	boss.advance_attack(1.5)
	check("attack ends in a readable exposed recovery", boss.phase == 2 and not boss._beam.visible)
	var ghost_before := boss.visual.ghost_count
	var blink_from := boss.global_position
	var blinked := boss.try_blink()
	var anchored := false
	for anchor: Vector3 in FearOculus.BLINK_ANCHORS:
		if anchor.distance_to(boss.global_position) < 0.75:
			anchored = true
	check("abyssal blink folds the oculus onto a distant anchor island", blinked and anchored
		and boss.global_position.distance_to(blink_from) >= 6.0
		and boss.global_position.distance_to(player.global_position) >= 6.0
		and boss.blink_count == 1)
	check("blink leaves one violet afterimage at the abandoned position", boss.visual.ghost_count == ghost_before + 1
		and boss.visual.ghosts.size() == 1
		and boss.visual.ghosts[0].global_position.distance_to(blink_from) < 0.5)
	var first_anchor := boss.global_position
	var blinked_again := boss.try_blink()
	check("a second blink crosses to a different distant anchor", blinked_again
		and boss.global_position.distance_to(first_anchor) >= 6.0
		and boss.blink_count == 2
		and boss.visual.ghost_count == ghost_before + 2)
	await frames(36)
	check("faded blink afterimages prune cleanly from the ghost list", boss.visual.ghosts.is_empty())
	boss.boss_phase = 2
	player.position = Vector3(12, 0, 12)
	boss.start_attack(1)
	boss.advance_attack(boss.windup() + 0.01)
	var before_sniper_count := boss._projectiles.size()
	boss.advance_attack(boss.active_duration() + 0.01)
	var sniper := boss._projectiles.back().get_ref() as Projectile if boss._projectiles.size() > before_sniper_count else null
	var to_player := (player.global_position + Vector3.UP * 1.1 - boss.eye_position()).normalized()
	var sniper_dir := -sniper.global_transform.basis.z.normalized() if sniper != null else Vector3.ZERO
	check("phase 2 sniper follow-up aims directly at the standing player", sniper != null and sniper_dir.dot(to_player) > 0.96)
	player.position = Vector3(0, 0, 16)
	var indicator := DamageIndicator.new()
	add_child(indicator)
	indicator.setup(player)
	indicator.add_hit(boss, 15)
	check("ordinary hit direction is visible before boss defeat", indicator.entry_count() == 1)
	var critical := player.stats.get_value(Stats.CRIT_CHANCE)
	var recharge := player.stats.get_value(Stats.DASH_RECHARGE)
	boss.health.apply_damage(9999, Hitbox.BodyPart.BODY, player)
	boss.health.apply_damage(9999, Hitbox.BodyPart.BODY, player)
	check("boss death emits one completion and disables body hitboxes", victories == 1 and boss.state == Enemy.State.DEAD and boss.get_node("EyeHitbox").collision_layer == 0)
	check("local realm warning deprivation activates immediately on defeat", realm.deprivation and realm.tiles.all(func(t: FearFlipTile) -> bool: return not t.warnings_enabled))
	check("defeat cancels beam and every owned ring projectile", not boss._beam.visible and boss._projectiles.is_empty())
	check("defeat dismisses summoned wisps and the dormant stock", boss.living_wisps().is_empty() and boss._stock.is_empty())
	check("defeat clears the blink afterimage", boss.visual.ghosts.is_empty())
	await frames(3)
	check("real boss defeat clears HUD warnings and future enemy tells", indicator.entry_count() == 0 and not player.realm_effects.warnings_enabled and not boss.warnings_enabled)
	var pickup := bench.shard as PsycheShardPickup
	check("real defeat drops one unclaimed Vigilance shard on the arena", is_instance_valid(pickup) and pickup.realm == 1 and not player.fragments.has_shard(1))
	player.position = pickup.position
	await frames(3)
	check("walking into the real pickup awards Vigilance and removes the pickup", player.fragments.has_shard(1) and not is_instance_valid(pickup))
	check("Vigilance independently raises critical chance and reaction recharge", is_equal_approx(player.stats.get_value(Stats.CRIT_CHANCE), critical + 0.15) and is_equal_approx(player.stats.get_value(Stats.DASH_RECHARGE), recharge * 1.2))
	indicator.add_hit(boss, 15)
	check("pickup leaves HUD and trap warnings permanently suppressed", indicator.entry_count() == 0 and not player.realm_effects.warnings_enabled and not realm.tiles[0].warnings_enabled)
	var shards: FearShatter
	for child in bench.get_children():
		if child is FearShatter:
			shards = child as FearShatter
	check("aggregated body explodes into 56 rigid crystalline fragments", shards != null and shards.pieces.size() == 56)
	check("boss death reuses a cooked immutable shape",shards.pieces[0].get_child(1).shape == FearShatter._collision_shapes[0])
	await frames(155)
	check("post-boss physics fragments are fully reclaimed", not is_instance_valid(shards))

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])

func block(point: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = point
	body.collision_layer = CollisionLayers.WORLD
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
