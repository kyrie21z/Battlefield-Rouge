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
var supported: Array[int] = [SLOTH]
var since_combat := 0.0
var healing_total := 0.0

func bind(value: Player) -> void:
	player = value
	player.weapon.fired.connect(mark_combat)
	player.melee.swing_started.connect(func(_index, _step): mark_combat())
	player.health.damaged.connect(func(_amount, _part, _source): mark_combat())
	player.boons.event_dispatched.connect(_on_boon_event)

func configure_deprivation(values: Array[int]) -> void:
	deprivations.assign(values)
	changed.emit()

func has_shard(realm: int) -> bool:
	return shards.has(realm)

func acquire(realm: int) -> bool:
	if not supported.has(realm) or shards.has(realm):
		return false
	shards.append(realm)
	acquired.emit(realm)
	changed.emit()
	return true

func restore(values: Array[int]) -> void:
	shards.clear()
	for realm in values:
		if supported.has(realm) and not shards.has(realm):
			shards.append(realm)
	changed.emit()

func mark_combat() -> void:
	since_combat = 0.0

func _on_boon_event(event: StringName, context: Dictionary) -> void:
	if event == &"enemy_damage" and context.get("source") == player and float(context.get("dealt",0.0)) > 0.0:
		mark_combat()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.health.is_dead():
		return
	since_combat += delta
	if not shards.has(SLOTH) or since_combat < 5.0:
		return
	# A live enemy with a clear nearby line of sight prevents healing by idling.
	if not player.boons.targets_in_radius(player.global_position + Vector3.UP,12.0).is_empty():
		return
	var before := player.health.health
	player.health.health = minf(player.health.max_health, player.health.health + 2.0 * delta)
	healing_total += player.health.health - before
