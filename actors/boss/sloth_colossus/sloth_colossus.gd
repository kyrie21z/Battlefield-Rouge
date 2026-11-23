class_name SlothColossus
extends SlothRealmEnemy
## Colossus keeps the Enemy/Health contract while choosing three authored attacks.
signal realm_defeated(realm_id: int)
var arena: Node3D
var active_attack: SlothColossusAttack
var attack_index := 0
var attacks_started := 0
var recovery_left := 0.0
var defeated_once := false

func _enter_tree() -> void:
	var visual_node := $Model as SlothRealmVisual
	variant = Variant.RETREATER
	visual_node.boss_form = true
	visual_node.configure(variant)

func _ready() -> void:
	super._ready()
	is_boss = true
	health.max_health = 1400.0
	health.health = health.max_health
	health.headshot_multiplier = 1.5
	run_speed = 0.0
	eye_height = 3.8
	cooldown_left = 1.2
	visual.play_motion("CowerIdle")

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
	recovery_left = maxf(0,recovery_left-delta*effective_attack_scale())
	cooldown_left = maxf(0,cooldown_left-delta*effective_attack_scale())
	if cooldown_left <= 0 and recovery_left<=0:
		start_attack(attack_index)
		attack_index = (attack_index+1)%3

func start_attack(kind: int) -> bool:
	if state == State.DEAD or not is_instance_valid(target) or is_instance_valid(active_attack):
		return false
	active_attack = SlothColossusAttack.new()
	active_attack.caster = self
	active_attack.target = target
	active_attack.kind = clampi(kind,0,2)
	add_child(active_attack)
	attacks_started += 1
	visual.set_cast(1 if warnings_enabled else 0)
	return true

func attack_finished() -> void:
	active_attack = null
	recovery_left = 1.4
	cooldown_left = 1.8 if health.health>health.max_health*0.5 else 1.2
	visual.set_cast(0)

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
	super._exit_tree()
