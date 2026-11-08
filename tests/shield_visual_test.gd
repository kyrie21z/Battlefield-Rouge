extends Node
## The raised shield, absorbed hit and outgoing wave must share the real combat
## lifecycle. Native pixel checks live in shield_purple_proof.tscn.

class Source extends Node3D:
	var team := 1

var _checks := 0
var _failures := 0
var _finished := false
var _elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	var ok := _finished and _failures == 0
	print("SHIELD FEEDBACK: %d checks, %d failed%s" % [_checks, _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 20.0 and not _finished:
		push_error("Shield feedback fixture timed out")
		get_tree().quit(1)


func _run() -> void:
	var arena := Node3D.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	arena.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	player.combat_traits.set_process(false)
	var shield := player.shield
	shield.set_process(false)
	var overlay := shield._overlay
	var source := Source.new()
	arena.add_child(source)
	var target := _target(arena, Vector3(6, 1, 0))
	for frame in 3:
		await get_tree().physics_frame
	_check("locked shield has no raised rim", not shield.try_activate() and not overlay.visible)
	player.stats.apply_buff(BuffPool.ALL[6])
	var pulses := [0]
	player.combat_traits.shield_pulsed.connect(func(): pulses[0] += 1)
	_check("real counter card unlocks protection and its rim", shield.try_activate()
		and shield.is_active() and overlay.visible and overlay.active)
	_check("rim cannot intercept gameplay input", overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("uncharged shield does not advertise a counter", not overlay.charged
		and overlay.counter_remaining == 0.0)
	shield._process(3.0)
	_check("unused protection remains beyond the former time limit", shield.is_active() and overlay.visible)
	shield.try_release()
	_check("unused protection can close without a free counter or visual wave", pulses[0] == 0
		and not overlay.visible and overlay.counter_remaining == 0.0 and target.health == 1000.0)
	shield._process(shield.cooldown_remaining + 0.01)
	_check("cooldown allows the next raised shield", shield.try_activate() and overlay.visible)
	shield._process(0.25)
	_check("thick rim remains for the whole protection, beyond its raise flash", shield.is_active()
		and overlay.visible and overlay.activation_remaining == 0.0)
	var health_before := player.health.health
	Projectile.spawn(arena, Vector3(0, 1, -0.8), Vector3.BACK, source, 10.0, 12.0, [])
	for frame in 8:
		await get_tree().physics_frame
	_check("real enemy projectile is absorbed by the raised shield", player.health.health == health_before)
	_check("actual absorbed hit starts the impact feedback and sustained charge", overlay.impact_remaining > 0.0
		and overlay.charged and overlay.visible)
	_check("blocking does not release damage before expiry", pulses[0] == 0 and target.health == 1000.0)
	shield._process(PlayerShield.ShieldFeedback.IMPACT_DURATION + 0.01)
	_check("charge remains readable after the brief hit flash", overlay.impact_remaining == 0.0
		and overlay.charged and overlay.visible)
	player.health.apply_damage(5.0, Hitbox.BodyPart.BODY, source)
	var active_before_pause := shield.active_remaining
	var impact_before_pause := overlay.impact_remaining
	shield.set_process(true)
	get_tree().paused = true
	for frame in 6:
		await get_tree().process_frame
	_check("pausing freezes protection and its impact feedback together",
		is_equal_approx(shield.active_remaining, active_before_pause)
		and is_equal_approx(overlay.impact_remaining, impact_before_pause) and overlay.charged)
	get_tree().paused = false
	shield.set_process(false)
	shield.try_release()
	_check("manual release returns the fifteen absorbed damage once at six metres", pulses[0] == 1
		and is_equal_approx(target.health, 985.0))
	_check("outgoing wave is visible from the first-person view after protection ends",
		not shield.is_active() and not player.health.invulnerable
		and overlay.visible and overlay.counter_remaining > 0.0)
	_check("expiring consumes the primed charge", not overlay.charged)
	var effect := arena.get_node_or_null("BlastPulse") as Node3D
	_check("counter creates the matching world-space wave", effect != null
		and effect.has_node("ShieldWaveFront") and effect.has_node("ShieldWaveRim"))
	if effect == null or not effect.has_node("ShieldWaveFront"):
		arena.queue_free()
		return
	var front := effect.get_node("ShieldWaveFront") as Node3D
	shield._process(0.12)
	_check("outgoing feedback lasts longer than a single rendered frame", overlay.visible
		and overlay.counter_remaining > 0.0)
	var counter_before_pause := overlay.counter_remaining
	var wave_before_pause := front.scale
	shield.set_process(true)
	get_tree().paused = true
	for frame in 6:
		await get_tree().process_frame
	_check("pausing freezes both first-person and world-space outgoing waves",
		is_equal_approx(overlay.counter_remaining, counter_before_pause)
		and front.scale.is_equal_approx(wave_before_pause))
	get_tree().paused = false
	shield.set_process(false)
	player.health.apply_damage(6.0, Hitbox.BodyPart.BODY, source)
	_check("visible outgoing feedback does not prolong invulnerability",
		is_equal_approx(player.health.health, health_before - 6.0))
	shield._process(PlayerShield.ShieldFeedback.COUNTER_DURATION + 0.01)
	_check("outgoing overlay clears while the normal eight-second cooldown continues",
		not overlay.visible and shield.cooldown_remaining > 0.0 and shield.cooldown_duration() == 8.0)
	_check("extra feedback updates cannot deal a second pulse", pulses[0] == 1
		and is_equal_approx(target.health, 985.0))
	shield._process(shield.cooldown_remaining + 0.01)
	shield.try_activate()
	player.health.apply_damage(5.0, Hitbox.BodyPart.BODY, source)
	shield.try_release()
	_check("a later actual block can prime a fresh counter", pulses[0] == 2 and overlay.visible)
	player.health.apply_damage(1000.0, Hitbox.BodyPart.BODY, source)
	_check("real death clears all shield feedback without another counter", player.health.is_dead()
		and not overlay.visible and not overlay.active and not overlay.charged
		and overlay.impact_remaining == 0.0 and overlay.counter_remaining == 0.0 and pulses[0] == 2)
	await get_tree().create_timer(0.9).timeout
	_check("the temporary world wave recycles", not is_instance_valid(effect))
	arena.queue_free()
	await get_tree().create_timer(0.2).timeout
	_finished = true


func _target(parent: Node3D, position: Vector3) -> Health:
	var actor := Node3D.new()
	actor.position = position
	var health := Health.new()
	health.max_health = 1000.0
	actor.add_child(health)
	for index in 2:
		var hitbox := Hitbox.new()
		hitbox.body_part = Hitbox.BodyPart.BODY if index == 0 else Hitbox.BodyPart.HEAD
		hitbox.position.y = float(index) * 0.6
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.25
		collision.shape = sphere
		hitbox.add_child(collision)
		actor.add_child(hitbox)
	parent.add_child(actor)
	return health


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
