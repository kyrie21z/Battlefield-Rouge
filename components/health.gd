class_name Health
extends Node
## Hit points with body-part multipliers. Hitboxes forward hits here.
## Adapted from origin/sheji/systems/damageable.gd with GameState, money,
## respawn and HUD lookups removed: owners react to the signals instead.

signal damaged(amount: float, body_part: Hitbox.BodyPart, source: Node)
signal died(source: Node)
signal blocked(amount: float, source: Node)
signal parried(amount: float, source: Node)
## Runs after the outermost damage/death and blocked callbacks have completed.
signal damage_resolved

@export var max_health := 100.0
@export var headshot_multiplier := 2.5
@export var limb_multiplier := 0.6
## 0 = player, 1 = enemy. Damage from the same team is ignored.
@export var team := 1
## Optional. When set, max_health follows Stats.MAX_HEALTH.
@export var stats: Stats

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
func apply_damage(amount: float, body_part: Hitbox.BodyPart, source: Node = null) -> float:
	if is_dead():
		return 0.0
	if not is_instance_valid(source):
		source = null
	if source != null and "team" in source and source.team == team:
		return 0.0
	if parrying and source != null:
		parried.emit(amount, source)
		return 0.0
	if invulnerable or dash_invulnerable:
		blocked.emit(amount, source)
		return 0.0

	var dealt := amount
	if body_part == Hitbox.BodyPart.HEAD:
		dealt *= headshot_multiplier
	elif body_part == Hitbox.BodyPart.LIMB:
		dealt *= limb_multiplier

	var absorbed := 0.0
	# The hook can emit feedback signals whose callbacks apply another hit.
	# Delay completion until every nested hit and this hit's overflow resolve.
	_damage_resolution_depth += 1
	if dealt > 0.0 and damage_absorber.is_valid():
		var remainder := clampf(float(damage_absorber.call(dealt)), 0.0, dealt)
		absorbed = dealt - remainder
		dealt = remainder
	# Resolve the overflow before signals can release a counter or reenter Health.
	if dealt > 0.0 or absorbed == 0.0:
		health = maxf(health - dealt, 0.0)
		damaged.emit(dealt, body_part, source)
		if is_dead():
			died.emit(source)
	if absorbed > 0.0:
		blocked.emit(absorbed, source)
	_damage_resolution_depth -= 1
	if _damage_resolution_depth == 0:
		damage_resolved.emit()
	return dealt


func _on_stats_changed() -> void:
	# Raising max health heals by the same amount, so a health buff is felt at once.
	var new_max := stats.get_value(Stats.MAX_HEALTH)
	health = clampf(health + new_max - max_health, 0.0, new_max)
	max_health = new_max
