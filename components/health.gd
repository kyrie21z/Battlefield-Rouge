class_name Health
extends Node
## Hit points with body-part multipliers. Hitboxes forward hits here.
## Adapted from origin/sheji/systems/damageable.gd with GameState, money,
## respawn and HUD lookups removed: owners react to the signals instead.

signal damaged(amount: float, body_part: Hitbox.BodyPart, source: Node)
signal died(source: Node)
signal blocked(amount: float, source: Node)
signal parried(amount: float, source: Node)
signal shield_changed(amount: float)
## Runs after the outermost damage/death and blocked callbacks have completed.
signal damage_resolved
## Mutable pre-HP context and complete post-HP result.
signal before_damage(context: Dictionary)
signal after_damage(context: Dictionary)

@export var max_health := 100.0
@export var headshot_multiplier := 2.5
@export var limb_multiplier := 0.6
## 0 = player, 1 = enemy. Damage from the same team is ignored.
@export var team := 1
## Optional. When set, max_health follows Stats.MAX_HEALTH.
@export var stats: Stats
## Optional enemy/intrinsic barrier. Existing actors keep zero capacity/recovery.
@export var max_shield := 0.0
@export var shield_regeneration_rate := 0.0
@export var shield_regeneration_delay := 3.0
var shield_points := 0.0
var _shield_recovery_left := 0.0
var _shield_regen_blockers: Dictionary = {}
var shield_regeneration_blocked: bool:
	get:
		return not _shield_regen_blockers.is_empty()

var health := 0.0
## Temporary invulnerability granted by a component such as PlayerShield.
var invulnerable := false
## Dash immunity. Kept apart from `invulnerable` because PlayerShield rewrites
## that flag every frame and would otherwise erase a dash's protection.
var dash_invulnerable := false
var parrying := false
## Optional component hook: consumes already-scaled damage and returns the rest.
## Health retains team filtering, other immunities, hit points and death order.
var damage_absorber: Callable
var boon_absorber: Callable
var last_damage_context: Dictionary = {}
var _damage_resolution_depth := 0


func _ready() -> void:
	if stats != null:
		max_health = stats.get_value(Stats.MAX_HEALTH)
		stats.changed.connect(_on_stats_changed)
	health = max_health


func is_dead() -> bool:
	return health <= 0.0


## Returns the damage actually dealt. `source` is the attacker's Health owner
## or any node with a `team` property; null means environmental damage.
func apply_damage(amount: float, body_part: Hitbox.BodyPart, source: Node = null, context: Dictionary = {}) -> float:
	if is_dead():
		return 0.0
	if context.get("environmental_fatal", false):
		return _environmental_fatal(source, context)
	if not is_instance_valid(source):
		source = null
	if source != null and "team" in source and source.team == team and not context.get("allow_friendly_fire", false):
		return 0.0
	if parrying and source != null:
		parried.emit(amount, source)
		return 0.0
	if invulnerable or dash_invulnerable:
		blocked.emit(amount, source)
		return 0.0

	var dealt := amount
	if body_part == Hitbox.BodyPart.HEAD and not context.get("true_damage", false):
		dealt *= headshot_multiplier
	elif body_part == Hitbox.BodyPart.LIMB and not context.get("true_damage", false):
		dealt *= limb_multiplier

	var ctx := context.duplicate()
	ctx.merge({"source": source, "target": get_parent(), "health": self,
		"damage": dealt, "dealt": 0.0, "body_part": body_part,
		"cancelled": false, "proc_depth": 0, "tag": &"direct"}, false)
	ctx.merge({"source": source, "target": get_parent(), "health": self, "body_part": body_part, "dealt": 0.0}, true)
	# Damage is post-body-part at this interception boundary.
	ctx.damage = dealt
	var absorbed := 0.0
	# The hook can emit feedback signals whose callbacks apply another hit.
	# Delay completion until every nested hit and this hit's overflow resolve.
	_damage_resolution_depth += 1
	before_damage.emit(ctx)
	dealt = 0.0 if ctx.cancelled else maxf(float(ctx.damage), 0.0)
	if dealt > 0.0 and damage_absorber.is_valid() and not ctx.get("true_damage", false):
		var remainder := clampf(float(damage_absorber.call(dealt)), 0.0, dealt)
		absorbed = dealt - remainder
		dealt = remainder
	if dealt > 0.0 and shield_points > 0.0 and not ctx.get("true_damage", false):
		var caught := minf(dealt, shield_points)
		shield_points -= caught
		dealt -= caught
		absorbed += caught
		shield_changed.emit(shield_points)
	if dealt > 0.0 and boon_absorber.is_valid() and not ctx.get("true_damage", false):
		var remainder := clampf(float(boon_absorber.call(dealt)), 0.0, dealt)
		absorbed += dealt - remainder
		dealt = remainder
	ctx.dealt = minf(dealt, health)
	ctx.absorbed = absorbed
	ctx.resolved_damage = ctx.dealt + absorbed
	if ctx.resolved_damage > 0.0:
		_shield_recovery_left = shield_regeneration_delay
	last_damage_context = ctx
	# Resolve the overflow before signals can release a counter or reenter Health.
	if dealt > 0.0:
		health = maxf(health - dealt, 0.0)
		damaged.emit(dealt, body_part, source)
		if is_dead():
			died.emit(source)
	if absorbed > 0.0:
		blocked.emit(absorbed, source)
	ctx.killed = is_dead()
	after_damage.emit(ctx)
	_damage_resolution_depth -= 1
	if _damage_resolution_depth == 0:
		damage_resolved.emit()
	return float(ctx.dealt)


func _on_stats_changed() -> void:
	# Raising max health heals by the same amount, so a health buff is felt at once.
	var new_max := stats.get_value(Stats.MAX_HEALTH)
	health = clampf(health + new_max - max_health, 0.0, new_max)
	max_health = new_max


## Falling beyond an authored abyss is a lethal boundary, not an absorbable hit.
## It still supplies the same actual-HP/death events, once, for run settlement.
func _environmental_fatal(source: Node, context: Dictionary) -> float:
	var dealt := health
	var ctx := context.duplicate()
	ctx.merge({"source": source, "target": get_parent(), "health": self,
		"damage": dealt, "dealt": dealt, "absorbed": 0.0, "resolved_damage": dealt,
		"body_part": Hitbox.BodyPart.BODY, "cancelled": false, "killed": true,
		"tag": &"abyss", "proc_depth": 0}, true)
	_damage_resolution_depth += 1
	health = 0.0
	last_damage_context = ctx
	damaged.emit(dealt, Hitbox.BodyPart.BODY, source)
	died.emit(source)
	after_damage.emit(ctx)
	_damage_resolution_depth -= 1
	if _damage_resolution_depth == 0:
		damage_resolved.emit()
	return dealt


func grant_shield(amount: float) -> float:
	var before := shield_points
	shield_points = minf(shield_points + maxf(amount, 0.0), max_shield) if max_shield > 0.0 else shield_points + maxf(amount, 0.0)
	shield_changed.emit(shield_points)
	return shield_points - before

func break_shield() -> float:
	var removed := shield_points
	shield_points = 0.0
	_shield_recovery_left = shield_regeneration_delay
	shield_changed.emit(shield_points)
	return removed

func set_shield_regeneration_blocked(source: StringName, blocked_value: bool) -> void:
	if blocked_value:
		_shield_regen_blockers[source] = true
	else:
		_shield_regen_blockers.erase(source)

func regenerate_shield(amount: float) -> float:
	if shield_regeneration_blocked or is_dead() or max_shield <= 0.0:
		return 0.0
	return grant_shield(amount)

func _physics_process(delta: float) -> void:
	if shield_regeneration_rate <= 0.0 or max_shield <= 0.0 or is_dead():
		return
	_shield_recovery_left = maxf(0.0, _shield_recovery_left - delta)
	if _shield_recovery_left <= 0.0:
		regenerate_shield(shield_regeneration_rate * delta)
