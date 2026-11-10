class_name WrathSpire
extends WrathRealmEnemy
## Each attack has a locked telegraph, active period and a gun/blade punish window.
signal realm_defeated(realm_id: int)
enum Move { VORTEX, FISSURE, SHRAPNEL }
var arena: Node3D
var move_kind := Move.VORTEX
var phase_elapsed := 0.0
var cycle_count := 0
var spawned_waves := 0
var spawned_bullets := 0
var _pulse_left := 0.0
var _burst_done := false
var _owned_bullets: Array[WeakRef] = []

func _enter_tree() -> void:
	variant = Variant.AGGRESSOR
	is_boss = true
	super._enter_tree()

func _ready() -> void:
	super._ready()
	health.max_health = 1050
	health.health = health.max_health
	health.headshot_multiplier = 1.3
	attack_phase = Attack.APPROACH
	attack_left = 1.4
	run_speed = 3.0

func _physics_process(delta: float) -> void:
	if state == State.DEAD or boon_time_scale <= 0 or boon_stunned:
		return
	delta *= boon_time_scale
	if not is_on_floor():
		velocity.y -= gravity * delta
	if not is_instance_valid(target):
		_stop()
		_boon_move_and_slide()
		return
	if _impact_left > 0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO, IMPACT_DECAY * delta)
		_boon_move_and_slide()
		return
	var flat := (target.global_position - global_position) * Vector3(1, 0, 1)
	phase_elapsed += delta * boon_attack_scale
	attack_left -= delta * boon_attack_scale
	_pulse_left -= delta
	var model := visual as WrathSpireVisual
	model.speed_factor = 5.0 if attack_phase == Attack.RUSH else 1.0
	model.telegraph = 1.0 if warnings_enabled and attack_phase == Attack.WINDUP else 0.0
	if attack_phase == Attack.APPROACH:
		_stop()
		_face(flat, delta)
		if attack_left <= 0:
			begin_move(move_kind)
	elif attack_phase == Attack.WINDUP:
		_stop()
		if attack_left <= 0:
			attack_phase = Attack.RUSH
			attack_left = 1.8 if move_kind == Move.VORTEX else 0.8
			phase_elapsed = 0
			_burst_done = false
			if move_kind == Move.FISSURE:
				for offset in [-0.42, 0.0, 0.42]:
					var wave := WrathShockwave.new()
					wave.source = self
					wave.target = target
					wave.max_radius = 27
					wave.half_angle = 0.24
					wave.direction = locked_direction.rotated(Vector3.UP, offset)
					wave.damage = 13 * realm_damage_scale
					wave.speed = 20
					get_parent().add_child(wave)
					wave.global_position = global_position
					spawned_waves += 1
			elif move_kind == Move.SHRAPNEL:
				_fire_radial(0.0)
	elif attack_phase == Attack.RUSH:
		if move_kind == Move.VORTEX:
			velocity.x = locked_direction.x * 6.5
			velocity.z = locked_direction.z * 6.5
			if flat.length() < 3.3 and _pulse_left <= 0 and _line_clear(target.global_position + Vector3.UP):
				_pulse_left = 0.45
				var hp := target.get_node_or_null("Health") as Health
				if hp != null:
					hp.apply_damage(13 * realm_damage_scale, Hitbox.BodyPart.BODY, self, {"tag": &"spire_vortex"})
				if target.has_method("apply_external_impulse"):
					target.call("apply_external_impulse", flat.normalized(), 9.0, 0.2)
		else:
			_stop()
			if move_kind == Move.SHRAPNEL and phase_elapsed >= 0.35 and not _burst_done:
				_burst_done = true
				_fire_radial(PI / 12.0)
		if attack_left <= 0:
			attack_phase = Attack.RECOVER
			attack_left = 1.5
	else:
		_stop()
		if attack_left <= 0:
			cycle_count += 1
			move_kind = (move_kind + 1) % 3
			attack_phase = Attack.APPROACH
			attack_left = 0.5
	_boon_move_and_slide()

func begin_move(kind: int) -> void:
	if not is_instance_valid(target) or state == State.DEAD:
		return
	move_kind = kind
	locked_direction = ((target.global_position - global_position) * Vector3(1, 0, 1)).normalized()
	attack_phase = Attack.WINDUP
	attack_left = 1.1 * boon_windup_scale
	phase_elapsed = 0

func _fire_radial(offset: float) -> void:
	for i in 12:
		var angle := i * TAU / 12.0 + offset
		var bullet := WrathRicochet.launch(get_parent(), global_position + Vector3.UP * 1.4 + Vector3(sin(angle), 0, cos(angle)) * 1.5, Vector3(sin(angle), 0, cos(angle)), self, 9.0 * realm_damage_scale, 17.0)
		_owned_bullets.append(weakref(bullet))
		spawned_bullets += 1

func _on_died(source: Node) -> void:
	if state == State.DEAD:
		return
	super._on_died(source)
	_clear_bullets()
	if is_instance_valid(arena) and arena.has_method("set_deprivation"):
		arena.call("set_deprivation", true)
	realm_defeated.emit(2)

func _clear_bullets() -> void:
	for reference in _owned_bullets:
		var bullet := reference.get_ref() as Node
		if is_instance_valid(bullet):
			bullet.queue_free()
	_owned_bullets.clear()

func _exit_tree() -> void:
	_clear_bullets()
