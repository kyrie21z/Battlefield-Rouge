class_name PsycheFragments
extends Node
## Fragment powers are independent of the permanently lost ordinary mechanisms.
signal changed
signal acquired(realm: int)
signal activated(realm: int)
const SLOTH := 0
const FEAR := 1
const WRATH := 2
const SORROW := 3
var player: Player
var shards: Array[int] = []
var deprivations: Array[int] = []
var supported: Array[int] = [SLOTH, FEAR, WRATH]
var since_combat := 0.0
var healing_total := 0.0
var counterpushes := 0
var spite_charge := 0
var _counter_left := 0.0

func bind(value: Player) -> void:
	player = value
	player.weapon.fired.connect(mark_combat)
	player.melee.swing_started.connect(func(_index, _step): mark_combat())
	player.health.damaged.connect(func(_amount, _part, _source): mark_combat())
	player.health.after_damage.connect(_after_damage)
	player.boons.event_dispatched.connect(_on_boon_event)

func configure_deprivation(values: Array[int]) -> void:
	deprivations.assign(values)
	player.realm_effects.warnings_enabled = not deprivations.has(FEAR)
	for enemy in player.boons.enemies():
		_apply_enemy_rules(enemy)
	if deprivations.has(FEAR):
		player.boons.dispatch(&"warnings_lost", {})
	changed.emit()

func has_shard(realm: int) -> bool:
	return shards.has(realm)

func acquire(realm: int) -> bool:
	if not supported.has(realm) or shards.has(realm):
		return false
	shards.append(realm)
	_refresh_powers()
	acquired.emit(realm)
	changed.emit()
	return true

func restore(values: Array[int]) -> void:
	shards.clear()
	for realm in values:
		if supported.has(realm) and not shards.has(realm):
			shards.append(realm)
	_refresh_powers()
	changed.emit()

func _refresh_powers() -> void:
	if shards.has(FEAR):
		player.stats.set_modifier(&"fragment_vigilance", {Stats.CRIT_CHANCE:{"add":0.15},Stats.DASH_RECHARGE:{"mul":1.2}})
	else:
		player.stats.remove_modifier(&"fragment_vigilance")

func _apply_enemy_rules(enemy: Node) -> void:
	if is_instance_valid(enemy) and "warnings_enabled" in enemy:
		enemy.set("warnings_enabled", not deprivations.has(FEAR))
	if is_instance_valid(enemy) and enemy.has_method("set_ordinary_impacts_enabled"):
		enemy.set_ordinary_impacts_enabled(not deprivations.has(WRATH))

func _after_damage(context: Dictionary) -> void:
	if not shards.has(WRATH) or _counter_left > 0.0 or player.health.is_dead() or float(context.get("dealt",0.0)) <= 0.0:
		return
	var source := context.get("source") as Node3D
	_release_spite(source)

func _release_spite(source: Node3D) -> void:
	if not is_instance_valid(source) or not source.has_method("apply_fragment_impact"):
		return
	if player.global_position.distance_to(source.global_position) > 7.0 or not player.boons.line_clear(player.global_position + Vector3.UP, source.global_position + Vector3.UP):
		return
	source.apply_fragment_impact(source.global_position - player.global_position, 16.0, 0.45)
	_counter_left = 1.0
	counterpushes += 1
	activated.emit(WRATH)
	player.boons.feedback(source.global_position + Vector3.UP, Color("f34535"), 0.65)

func mark_combat() -> void:
	since_combat = 0.0

func _on_boon_event(event: StringName, context: Dictionary) -> void:
	if event == &"enemy_registered":
		_apply_enemy_rules(context.get("enemy"))
	if event == &"enemy_damage" and context.get("source") == player and float(context.get("dealt",0.0)) > 0.0:
		mark_combat()
		# The third direct weapon hit discharges a separate shard pulse. The
		# ordinary weapon impact remains zero on every hit, including this one.
		if shards.has(WRATH) and context.get("kind") in [&"gun", &"blade"] and int(context.get("proc_depth",0)) == 0:
			spite_charge = mini(spite_charge + 1, 3)
			if spite_charge == 3 and _counter_left <= 0.0:
				var before := counterpushes
				_release_spite(context.get("target") as Node3D)
				if counterpushes > before:
					spite_charge = 0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.health.is_dead():
		return
	_counter_left = maxf(0.0, _counter_left - delta)
	since_combat += delta
	if not shards.has(SLOTH) or since_combat < 5.0:
		return
	# A live enemy with a clear nearby line of sight prevents healing by idling.
	if not player.boons.targets_in_radius(player.global_position + Vector3.UP,12.0).is_empty():
		return
	var before := player.health.health
	player.health.health = minf(player.health.max_health, player.health.health + 2.0 * delta)
	healing_total += player.health.health - before
