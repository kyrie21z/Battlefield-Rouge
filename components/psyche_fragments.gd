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
var supported: Array[int] = [SLOTH, FEAR, WRATH, SORROW]
var since_combat := 0.0
var healing_total := 0.0
## Rest healing is budgeted per room so idling after a clear cannot refill.
const SLUMBER_ROOM_HEAL_CAP := 30.0
var room_healed := 0.0
var counterpushes := 0
var spite_charge := 0
var _counter_left := 0.0
const TENDERNESS_CAPACITY := 40.0
const TENDERNESS_RECOVERY_DELAY := 6.5
## 沉睡共鸣的默认作用半径；测试台会把它放大到覆盖全场，正式流程保持 18 米。
const RESONANCE_RADIUS := 18.0
var resonance_radius := RESONANCE_RADIUS
var barrier := 0.0
var absorption_total := 0.0
var brittle_hits := 0
var _barrier_recovery := 0.0
var _glass: AudioStreamPlayer
var resonance_cooldown := 0.0
var resonances := 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("psyche_resonance") and not event.is_echo() and try_slumber_resonance():
		get_viewport().set_input_as_handled()

func try_slumber_resonance() -> bool:
	if not is_instance_valid(player) or player.health.is_dead() or get_tree().paused or not shards.has(SLOTH) or resonance_cooldown > 0.0:
		return false
	var targets := player.boons.targets_in_radius(player.global_position + Vector3.UP,resonance_radius)
	if targets.is_empty():
		return false
	for enemy in targets:
		if enemy.has_method("receive_slumber_resonance"):
			enemy.receive_slumber_resonance(3.0,0.25)
		else:
			player.boons.set_status(enemy,&"fragment_slumber",3.0,1.0,0.25)
	resonance_cooldown = 10.0
	resonances += 1
	mark_combat()
	activated.emit(SLOTH)
	player.boons.feedback(player.global_position+Vector3.UP*0.2,Color("e3a23a"),2.0)
	changed.emit()
	return true

func bind(value: Player) -> void:
	player = value
	player.weapon.fired.connect(mark_combat)
	player.melee.swing_started.connect(func(_index, _step): mark_combat())
	player.health.damaged.connect(func(_amount, _part, _source): mark_combat())
	player.health.after_damage.connect(_after_damage)
	player.health.fragment_absorber = _absorb
	player.boons.event_dispatched.connect(_on_boon_event)
	_glass = AudioStreamPlayer.new()
	_glass.stream = ProceduralAudio.generate("brittle_glass")
	_glass.volume_db = -12.0
	add_child(_glass)

## Replace the existing single damage voice; never add a second damage listener.
func set_brittle_audio(stream: AudioStream) -> void:
	if is_instance_valid(_glass) and stream != null:
		_glass.stream = stream

func configure_deprivation(values: Array[int]) -> void:
	deprivations.assign(values)
	player.health.unbuffered = deprivations.has(SORROW)
	if player.health.unbuffered:
		player.shield.cancel()
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
	if realm == SORROW:
		barrier = TENDERNESS_CAPACITY
	_refresh_powers()
	acquired.emit(realm)
	changed.emit()
	return true

func restore(values: Array[int]) -> void:
	var had_barrier := shards.has(SORROW)
	shards.clear()
	for realm in values:
		if supported.has(realm) and not shards.has(realm):
			shards.append(realm)
	if not shards.has(SORROW):
		barrier = 0.0
	elif not had_barrier:
		barrier = TENDERNESS_CAPACITY
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
	var dealt := float(context.get("dealt",0.0))
	if shards.has(SORROW) and dealt > 0.0:
		_barrier_recovery = TENDERNESS_RECOVERY_DELAY
	if player.health.unbuffered and dealt > 0.0:
		brittle_hits += 1
		_glass.play()
	if not shards.has(WRATH) or _counter_left > 0.0 or player.health.is_dead() or dealt <= 0.0:
		return
	var source := context.get("source") as Node3D
	_release_spite(source)

func _absorb(amount: float) -> float:
	if not shards.has(SORROW) or barrier <= 0.0:
		return amount
	var caught := minf(amount,barrier)
	barrier -= caught
	absorption_total += caught
	_barrier_recovery = TENDERNESS_RECOVERY_DELAY
	activated.emit(SORROW)
	changed.emit()
	return amount - caught

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

## A new room hands the player a fresh rest budget; the same room never does.
func reset_room_healing() -> void:
	room_healed = 0.0

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
	resonance_cooldown = maxf(0.0,resonance_cooldown-delta)
	_barrier_recovery = maxf(0.0, _barrier_recovery - delta)
	if shards.has(SORROW) and _barrier_recovery <= 0.0 and barrier < TENDERNESS_CAPACITY:
		barrier = minf(TENDERNESS_CAPACITY, barrier + 6.0 * delta)
		changed.emit()
	since_combat += delta
	if not shards.has(SLOTH) or since_combat < 5.0:
		return
	# A live enemy with a clear nearby line of sight prevents healing by idling.
	if not player.boons.targets_in_radius(player.global_position + Vector3.UP,12.0).is_empty():
		return
	var budget := maxf(0.0, SLUMBER_ROOM_HEAL_CAP - room_healed)
	if budget <= 0.0:
		return
	var before := player.health.health
	player.health.health = minf(player.health.max_health, player.health.health + minf(2.0 * delta, budget))
	var healed := player.health.health - before
	room_healed += healed
	healing_total += healed
