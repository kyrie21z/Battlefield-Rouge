class_name SlothEnemy
extends Enemy
## Crystal Sloth variants keep the Enemy contract used by zones and weapons.
## No soldier skeleton, gun, random spread or last-second homing is involved.

enum Kind { LINGERER, ANCHOR, RECLUSE }
@export_enum("Lingerer", "Anchor", "Recluse") var kind: int = Kind.LINGERER
## A short authored offset keeps the larger opening wave from casting in unison.
@export_range(0.0, 2.0) var opening_delay := 0.25
var visual: SlothVisual
var active_attack: SlothAttack
var cooldown_left := 1.3
var _exposed_left := 0.0
var last_hit_point := Vector3.INF
var last_hit_direction := Vector3.ZERO
var cloak_recover_left := 0.0
@export_range(0.0, 1.0) var evade_chance := 0.30
@export_range(0.1, 10.0) var evade_cooldown := 2.5
var evade_cooldown_left := 0.0
var evade_count := 0



func _enter_tree() -> void:
	# Child _ready runs first; choose its outfit before it builds any meshes.
	($Model as SlothVisual).configure(kind)


func _ready() -> void:
	visual = $Model as SlothVisual
	visual.configure(kind)
	visual.play_motion("CowerIdle" if kind == Kind.RECLUSE else "idle")
	run_speed = [2.8, 2.1, 2.4][kind]
	cooldown_left = opening_delay
	eye_height = 1.65
	min_engage_distance = 4.0
	engage_range = [24.0, 18.0, 6.0][kind]
	_hitbox_rids.append(get_rid())
	for hitbox in find_children("*", "Hitbox", true, false):
		_hitbox_rids.append((hitbox as Hitbox).get_rid())
	health.max_health = [90.0, 140.0, 180.0][kind]
	health.health = health.max_health
	health.headshot_multiplier = 2.0
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	Events.gunshot.connect(_on_gunshot)
	Events.clock_struck.connect(_on_clock_struck)
	# A visible chest aperture rewards aim without making the shell invulnerable.
	set_core_exposed(false)


func setup(p_target: CharacterBody3D, p_cover_points: Array[CoverPoint],
		p_firing_board: FiringPositionBoard = null) -> void:
	super.setup(p_target, p_cover_points, p_firing_board)
	# The director binds targets only after the entry card is committed. Start
	# searching at that combat boundary, rather than waiting to hear a gunshot.
	if state not in [State.DEAD, State.FLEE] and is_instance_valid(target):
		begin_hunt()


func begin_hunt() -> void:
	if is_instance_valid(target) and state != State.DEAD and state != State.FLEE:
		_last_known = target.global_position
		if kind == Kind.LINGERER:
			_start_seek(_last_known)
		else:
			_alert(_last_known)


func begin_retreat(goal: Vector3, timeout: float) -> void:
	_cancel_attack()
	super.begin_retreat(goal, timeout)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	evade_cooldown_left = maxf(0.0, evade_cooldown_left - delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	if state == State.FLEE:
		_process_flee(delta)
		if not _departed:
			move_and_slide()
			visual.play_motion("run")
		return
	if _impact_left > 0.0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO, IMPACT_DECAY * delta)
		move_and_slide()
		return
	_stop()
	if not is_instance_valid(target) or (target is Player and target.health.is_dead()):
		_cancel_attack()
		move_and_slide()
		return
	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = 0.1
		_update_sight()
	if state == State.IDLE and _sees_target:
		_alert(target.global_position)
	if state == State.IDLE:
		move_and_slide()
		return
	cooldown_left = maxf(0.0, cooldown_left - delta)
	cloak_recover_left = maxf(0.0, cloak_recover_left - delta)
	_seek_retry = maxf(0.0, _seek_retry - delta)
	_exposed_left = maxf(0.0, _exposed_left - delta)
	_face(_target_point() - global_position, delta)
	if is_instance_valid(active_attack):
		visual.set_cast(clampf(active_attack.elapsed / active_attack.warning_time(), 0.0, 1.0))
		move_and_slide()
		return
	visual.set_cast(0.0)
	visual.set_mantle_open(0.0 if cloak_recover_left <= 0.0 else 1.0)
	visual.set_shell_open(1.0 if _exposed_left > 0.0 else 0.0)
	set_core_exposed(_exposed_left > 0.0 or cloak_recover_left > 0.0)
	# A clear shot should not wait for a distant cover marker. Reserve the
	# actual stopping place, retaining the shared 3.5 m separation contract.
	if _sees_target and _distance_to_target() <= engage_range and _can_fight_here():
		if state != State.ENGAGE:
			firing_position = global_position
			if _firing_board != null:
				_firing_board.claim(self, firing_position)
		state = State.ENGAGE
		if cooldown_left <= 0.0 and cloak_recover_left <= 0.0:
			cast_attack()
	elif state == State.SEEK and kind == Kind.LINGERER:
		_process_seek(delta)
	else:
		# A deterministic path toward the last observed position also brings a
		# cloaked reinforcement around cover instead of shooting through it.
		state = State.CHASE
		if kind == Kind.LINGERER and _seek_retry <= 0.0:
			_start_seek(_last_known)
		else:
			_move_to(_last_known, run_speed)
	visual.play_motion("walk" if Vector2(velocity.x, velocity.z).length() > 0.2 else
		("CowerIdle" if kind == Kind.RECLUSE and _exposed_left <= 0.0 else "idle"))
	move_and_slide()


func _can_fight_here() -> bool:
	if kind == Kind.LINGERER and _distance_to_target() < min_engage_distance:
		return false
	return _firing_board == null or not _firing_board.is_taken(global_position, seek_spacing, self)


func cast_attack() -> bool:
	if state == State.DEAD or state == State.FLEE or not is_instance_valid(target) \
			or is_instance_valid(active_attack) or cloak_recover_left > 0.0:
		return false
	active_attack = SlothAttack.new()
	active_attack.caster = self
	active_attack.target = target
	active_attack.kind = kind
	# Owned by the caster, while the telegraph uses locked world coordinates.
	add_child(active_attack)
	cooldown_left = [3.6, 4.4, 3.6][kind]
	visual.play_motion("cast" if kind == Kind.LINGERER else "EnterCower")
	return true


func attack_finished() -> void:
	active_attack = null
	cloak_recover_left = 1.0 if kind == Kind.LINGERER else 0.0
	_exposed_left = 1.6 if kind == Kind.RECLUSE else 0.0
	visual.set_cast(0.0)
	set_core_exposed(_exposed_left > 0.0 or cloak_recover_left > 0.0)


func set_core_exposed(exposed: bool) -> void:
	$CoreHitbox.collision_layer = CollisionLayers.HITBOXES if exposed and kind in [Kind.RECLUSE, Kind.LINGERER] else 0


func apply_impact(direction: Vector3, force: float, stagger: float) -> void:
	if is_instance_valid(active_attack) and active_attack.phase == 0:
		_cancel_attack()
		cooldown_left = maxf(cooldown_left, 1.6)
		_exposed_left = 1.6 if kind == Kind.RECLUSE else 0.0
		cloak_recover_left = 1.0 if kind == Kind.LINGERER else 0.0
		set_core_exposed(_exposed_left > 0.0 or cloak_recover_left > 0.0)
	super.apply_impact(direction, force, stagger)


func _cancel_attack() -> void:
	if is_instance_valid(active_attack):
		active_attack.cancel()
	active_attack = null
	if is_instance_valid(visual):
		visual.set_cast(0.0)


func _on_damaged(_amount: float, _part: Hitbox.BodyPart, source: Node) -> void:
	last_hit_point = global_position + Vector3.UP * (1.75 if _part == Hitbox.BodyPart.HEAD else 1.0)
	last_hit_direction = (last_hit_point - source.global_position).normalized() if source is Node3D else Vector3.FORWARD
	for node in find_children("*", "Hitbox", true, false):
		var hitbox := node as Hitbox
		if hitbox.resolving_surface_hit:
			last_hit_point = hitbox.surface_point
			last_hit_direction = hitbox.surface_direction
			break
	if state == State.IDLE:
		_alert(source.global_position if source is Node3D else global_position)


func _on_died(_source: Node) -> void:
	_cancel_attack()
	_leave_cover()
	_release_firing_position()
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	for hitbox in find_children("*", "Hitbox", true, false):
		(hitbox as Hitbox).collision_layer = 0
	visual.die(last_hit_point, last_hit_direction)
	Events.enemy_killed.emit(self)


func _exit_tree() -> void:
	_cancel_attack()


func try_cloak_evade() -> bool:
	if kind != Kind.LINGERER or state in [State.DEAD, State.FLEE] \
			or evade_cooldown_left > 0.0 or evade_chance <= 0.0 \
			or cloak_recover_left > 0.0 or $CoreHitbox.collision_layer != 0:
		return false
	var contact: Hitbox
	for node in find_children("*", "Hitbox", true, false):
		var hitbox := node as Hitbox
		if hitbox.resolving_surface_hit and hitbox.surface_can_evade:
			contact = hitbox
			break
	if contact == null or randf() >= evade_chance:
		return false
	evade_count += 1
	evade_cooldown_left = evade_cooldown
	contact.surface_evaded = true
	visual.play_evade(-1.0 if evade_count % 2 == 0 else 1.0)
	if state == State.IDLE:
		_alert(global_position - contact.surface_direction * 6.0)
	return true
