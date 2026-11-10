extends Node3D
var failures := 0
var checks := 0
var player: Player

func _ready() -> void:
	await run_checks()
	for child in get_children():
		child.free()
	get_tree().paused = false
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("ALL PASSED (%d checks)" % checks if failures == 0 else "FAIL (%d/%d)" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)

func check(label: String, ok: bool) -> void:
	checks += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func block(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = CollisionLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func run_checks() -> void:
	block(Vector3(0,-0.5,0), Vector3(40,1,40))
	block(Vector3(3,2,0), Vector3(1,4,20))
	player = preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	await frames(8)
	check("real player grounded", player.is_on_floor())
	player.set_realm_effect(&"anchor_a", {"dash_blocked":true, "move_multiplier":0.55})
	player.set_realm_effect(&"anchor_b", {"dash_blocked":true, "move_multiplier":0.75})
	var charges := player.dash.charges()
	check("anchor blocks real dash before spending charge", not player.dash.try_dash() and player.dash.charges() == charges)
	player.clear_realm_effect(&"anchor_a")
	check("second anchor remains after first clears", player.realm_effects.dash_blocked and is_equal_approx(player.realm_effects.move_multiplier,0.75))
	player.clear_realm_effect(&"anchor_b")
	check("last source restores mobility", not player.realm_effects.dash_blocked and is_equal_approx(player.realm_effects.move_multiplier,1.0))
	player.set_realm_effect(&"wail", {"duration":0.2, "reload_multiplier":0.25, "cooldown_multiplier":2.0,"monochrome":1.0})
	check("wail reaches actual reload and dash stats", is_equal_approx(player.stats.get_value(Stats.RELOAD_SPEED),0.25) and is_equal_approx(player.stats.get_value(Stats.DASH_RECHARGE),0.5))
	get_tree().paused = true
	await get_tree().create_timer(0.3,true).timeout
	check("pause freezes effect duration", player.realm_effects.effects.has(&"wail"))
	get_tree().paused = false
	await frames(18)
	check("expiry restores stats and monochrome", not player.realm_effects.effects.has(&"wail") and is_equal_approx(player.stats.get_value(Stats.RELOAD_SPEED),1.0) and player.realm_effects.monochrome == 0.0)
	var owner_node := Node.new()
	add_child(owner_node)
	player.set_realm_effect(&"owner", {"owner":owner_node,"dash_blocked":true})
	owner_node.queue_free()
	await frames(3)
	check("freed caster automatically releases constraint", not player.realm_effects.dash_blocked)
	player.set_realm_effect(&"gravity", {"jump_multiplier":0.2, "dash_distance_multiplier":0.4})
	var start := player.position
	check("gravity permits weakened real dash", player.dash.try_dash())
	await frames(18)
	var distance := player.position.distance_to(start)
	check("gravity shortens physical dash to 2m (%.2f)" % distance, distance > 1.6 and distance < 2.4)
	player.clear_realm_effect(&"gravity")
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await frames(8)
	player.apply_external_impulse(Vector3.RIGHT,20,0.4)
	await frames(30)
	check("external impulse respects real WORLD wall", player.position.x > 1.0 and player.position.x < 2.3)
	player.health.invulnerable = true
	player.health.dash_invulnerable = true
	player.health.grant_shield(1000)
	player.health.before_damage.connect(func(ctx): ctx.cancelled = true)
	var hp := player.health.health
	var actual := player.health.apply_damage(1,Hitbox.BodyPart.BODY,null,{"environmental_fatal":true})
	check("abyss ignores shield immunity and cancellation", player.health.is_dead() and is_equal_approx(actual,hp))
	check("abyss stores actual lethal context", player.health.last_damage_context.killed and player.health.last_damage_context.tag == &"abyss")
	check("death is idempotent", player.health.apply_damage(1,Hitbox.BodyPart.BODY,null,{"environmental_fatal":true}) == 0.0)
	check("death releases all temporary realm effects", player.realm_effects.effects.is_empty())
