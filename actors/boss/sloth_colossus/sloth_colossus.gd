class_name SlothColossus
extends SlothRealmEnemy
## Colossus keeps the Enemy/Health contract and picks one of five authored
## attacks for the range and health it is actually facing. Its identity is
## inertia: it never chases, but it never stops leaning on the player either.
signal realm_defeated(realm_id: int)
signal phase_changed(new_phase: int)
const BASE_HEALTH := 1750.0
const PHASE_SHIELD_RATIO := 0.15
## The amber shell trades offence for 55% mitigation that true damage and the
## blade ignore; bullets still add up until the shell cracks.
const HIBERNATION_MITIGATION := 0.45
const HIBERNATION_SHIELD_RATE := 45.0
const HIBERNATION_BREAK_DAMAGE := 180.0
const STAGGER_TIME := 1.2
const HIBERNATION_COOLDOWN := 8.0
const TURN_SCALE := 2.4
const ATTACK_KINDS := 5
var arena: Node3D
var active_attack: SlothColossusAttack
var attacks_started := 0
var last_attack_kind := -1
var recovery_left := 0.0
var defeated_once := false
var boss_phase := 1
var hibernating := false
var hibernation_damage := 0.0
var hibernation_cooldown_left := 0.0
var stagger_left := 0.0
var _projectiles: Array[SlothRealmProjectile] = []
var _pools: Array[SlothResinPool] = []

func _enter_tree() -> void:
	var visual_node := $Model as SlothRealmVisual
	variant = Variant.RETREATER
	visual_node.boss_form = true
	visual_node.configure(variant)

func _ready() -> void:
	super._ready()
	is_boss = true
	health.max_health = BASE_HEALTH
	health.health = health.max_health
	health.headshot_multiplier = 1.5
	run_speed = 0.0
	eye_height = 3.8
	cooldown_left = 1.2
	visual.play_motion("CowerIdle")
	health.before_damage.connect(_before_damage)
	health.after_damage.connect(_on_phase_damage)
	# Warm the resin shader once so the first mortar never hitches.
	SlothResinPool.prepare_shader(self)

func setup(p_target: CharacterBody3D, p_cover_points: Array[CoverPoint],
		p_firing_board: FiringPositionBoard = null) -> void:
	super.setup(p_target,p_cover_points,p_firing_board)
	_face(target.global_position-global_position,1.0)

func _physics_process(delta: float) -> void:
	if state == State.DEAD or not is_instance_valid(target):
		return
	if boon_stunned or boon_time_scale <= 0:
		return
	delta *= boon_time_scale
	if target.has_node("Health") and (target.get_node("Health") as Health).is_dead():
		_cancel_colossus_attack()
		return
	if is_instance_valid(active_attack):
		return
	stagger_left = maxf(0,stagger_left-delta*effective_attack_scale())
	hibernation_cooldown_left = maxf(0,hibernation_cooldown_left-delta*effective_attack_scale())
	# The titan never walks, but it keeps its shoulders square instead of
	# freezing on the facing it spawned with.
	_face(target.global_position-global_position,delta*TURN_SCALE)
	if stagger_left > 0:
		return
	recovery_left = maxf(0,recovery_left-delta*effective_attack_scale())
	cooldown_left = maxf(0,cooldown_left-delta*effective_attack_scale())
	if cooldown_left <= 0 and recovery_left <= 0:
		start_attack(_choose_next_attack())

## Tactical pick over kinds 0..4. No random source: the order only depends on
## the live distance and health, so a replay keeps the same sequence.
func _choose_next_attack() -> int:
	var offset := target.global_position-global_position
	var distance := Vector2(offset.x,offset.z).length()
	var order: Array[int]
	if health.health <= health.max_health*0.35:
		order = [4,3,1,0,2]
	elif distance <= 9.0:
		order = [0,2,4,1,3]
	elif distance >= 16.0:
		order = [1,3,2,4,0]
	else:
		order = [2,3,1,0,4]
	for kind in order:
		if kind == last_attack_kind:
			continue
		if kind == 4 and hibernation_cooldown_left > 0:
			continue
		return kind
	return 0

func start_attack(kind: int) -> bool:
	if state == State.DEAD or not is_instance_valid(target) or is_instance_valid(active_attack):
		return false
	var value := clampi(kind,0,ATTACK_KINDS-1)
	active_attack = SlothColossusAttack.new()
	active_attack.caster = self
	active_attack.target = target
	active_attack.kind = value
	add_child(active_attack)
	attacks_started += 1
	last_attack_kind = value
	visual.set_cast(1 if warnings_enabled else 0)
	return true

func attack_finished() -> void:
	active_attack = null
	recovery_left = 1.0 if boss_phase >= 2 else 0.95
	cooldown_left = 0.9 if boss_phase >= 2 else 0.85
	visual.set_cast(0)

func _on_phase_damage(_context: Dictionary) -> void:
	if boss_phase != 1 or health.is_dead():
		return
	if health.health > health.max_health*0.50:
		return
	boss_phase = 2
	boss_phase_tempo_scale = 1.20
	health.max_shield = roundf(health.max_health*PHASE_SHIELD_RATIO)
	health.shield_points = health.max_shield
	health.shield_regeneration_rate = 0.0
	health.shield_changed.emit(health.shield_points)
	phase_changed.emit(2)

## The shell turns the titan inward: damage is cut unless it is true damage or
## the blade, which cracks the amber outright.
func _before_damage(context: Dictionary) -> void:
	if not hibernating or context.get("true_damage",false):
		return
	if context.get("kind",&"") == &"blade":
		break_shell()
		return
	var damage := float(context.get("damage",0.0))
	hibernation_damage += damage
	context["damage"] = damage*HIBERNATION_MITIGATION
	if hibernation_damage >= HIBERNATION_BREAK_DAMAGE:
		break_shell()

func hibernation_shield_cap() -> float:
	return roundf(health.max_health*PHASE_SHIELD_RATIO)

func begin_hibernation() -> void:
	hibernating = true
	hibernation_damage = 0.0
	health.max_shield = maxf(health.max_shield,hibernation_shield_cap())

func end_hibernation() -> void:
	hibernating = false
	hibernation_damage = 0.0

func regen_hibernation_shield(delta: float) -> void:
	if not hibernating:
		return
	var cap := hibernation_shield_cap()
	if health.shield_points >= cap:
		return
	var before := health.shield_points
	health.shield_points = minf(health.shield_points+HIBERNATION_SHIELD_RATE*delta,cap)
	if not is_equal_approx(before,health.shield_points):
		health.shield_changed.emit(health.shield_points)

## A cracked shell leaves the titan slumped open, with no attack of its own.
func break_shell() -> void:
	if not hibernating:
		return
	hibernating = false
	hibernation_damage = 0.0
	stagger_left = STAGGER_TIME
	hibernation_cooldown_left = HIBERNATION_COOLDOWN
	var channel := active_attack
	active_attack = null
	if is_instance_valid(channel):
		channel.cancel()
	visual.set_cast(0)

func register_projectile(shot: SlothRealmProjectile) -> void:
	_prune_owned()
	_projectiles.append(shot)

## Lobs a warning footprint that hardens into a damaging resin pool. Returns
## null when there is no walkable floor under the marked point.
func spawn_resin_pool(at: Vector3) -> SlothResinPool:
	var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.2,
		at-Vector3.UP*3.5,CollisionLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).y < SlothResinPool.MIN_FLOOR_NORMAL:
		return null
	var pool := SlothResinPool.new()
	pool.name = "ColossusResinPool"
	pool.victim = target as Player
	pool.attacker = self
	pool.damage_scale = realm_damage_scale
	pool.visible = warnings_enabled
	var parent := get_parent_node_3d()
	pool.position = parent.to_local(hit.position)
	parent.add_child(pool)
	_prune_owned()
	_pools.append(pool)
	return pool

func _prune_owned() -> void:
	var shots: Array[SlothRealmProjectile] = []
	for shot in _projectiles:
		if is_instance_valid(shot) and not shot.is_queued_for_deletion():
			shots.append(shot)
	_projectiles = shots
	var pools: Array[SlothResinPool] = []
	for pool in _pools:
		if is_instance_valid(pool) and not pool.is_queued_for_deletion():
			pools.append(pool)
	_pools = pools

func _clear_owned() -> void:
	for shot in _projectiles:
		if is_instance_valid(shot):
			shot.queue_free()
	_projectiles.clear()
	for pool in _pools:
		if is_instance_valid(pool):
			pool.queue_free()
	_pools.clear()

func _on_damaged(amount: float,part: Hitbox.BodyPart,source: Node) -> void:
	super._on_damaged(amount,part,source)
	retreat_left = 0

func apply_impact(_direction: Vector3,_force: float,_stagger: float) -> void:
	# The grounded titan does not slide; hits still damage its exposed crystal.
	pass

func _on_died(source: Node) -> void:
	if defeated_once:
		return
	defeated_once = true
	_cancel_colossus_attack()
	_clear_owned()
	stagger_left = 0.0
	hibernation_cooldown_left = 0.0
	super._on_died(source)
	if is_instance_valid(arena) and arena.has_method("set_deprivation"):
		arena.call("set_deprivation",true)
	realm_defeated.emit(0)

func _cancel_colossus_attack() -> void:
	if is_instance_valid(active_attack):
		active_attack.cancel()
	active_attack = null

func _exit_tree() -> void:
	_cancel_colossus_attack()
	_clear_owned()
	super._exit_tree()
