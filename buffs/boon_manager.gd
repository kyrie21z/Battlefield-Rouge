class_name BoonManager
extends Node
## Player-owned action pipeline. Zone injects persistence and seed; effects never
## discover systems through groups and never modify the global simulation clock.
signal changed
signal loadout_changed(cards: Array[BoonData])
signal replacement_requested(previous: BoonData, replacement: BoonData)
signal event_dispatched(event: StringName, context: Dictionary)

var player: CharacterBody3D
var stats: Stats
var health: Health
var weapon: Weapon
var blade: MeleeWeapon
var dash: PlayerDash
var rng := RandomNumberGenerator.new()
var slots: Array[BoonSlot] = []
var traits: Array[BoonData] = []
var shield_amount := 0.0
var _pending: BoonData
var _effects: Dictionary = {}
var _enemies: Dictionary = {}
var _projectiles: Dictionary = {}
var _statuses: Dictionary = {}
var _projectile_statuses: Dictionary = {}
var _modifiers: Dictionary = {}
var _freezes: Dictionary = {}
var _shield_left := 0.0
var _feedback: Array[Node3D] = []
var _active := true

func _init() -> void:
	for index in 4:
		slots.append(BoonSlot.new(index))
	rng.seed = 0xB001

func bind(owner_player: CharacterBody3D, owner_stats: Stats, owner_health: Health,
		owner_weapon: Weapon, owner_blade: MeleeWeapon, owner_dash: PlayerDash) -> void:
	player = owner_player
	stats = owner_stats
	health = owner_health
	weapon = owner_weapon
	blade = owner_blade
	dash = owner_dash
	weapon.boon_hook = dispatch
	blade.boon_hook = dispatch
	dash.boon_hook = dispatch
	dash.stats = stats
	health.before_damage.connect(_before_damage)
	health.after_damage.connect(_after_damage)
	health.died.connect(_on_player_died)
	health.boon_absorber = _absorb
	Events.enemy_registered.connect(register_enemy)
	Events.projectile_registered.connect(register_projectile)
	Events.enemy_killed.connect(_enemy_killed)
	Events.clock_struck.connect(_clock_struck)

func has(id: String) -> bool:
	return get_boon(id) != null

func get_boon(id: String) -> BoonData:
	for card in all_equipped():
		if card.id == id:
			return card
	return null

func all_equipped() -> Array[BoonData]:
	var result: Array[BoonData] = []
	for slot in slots:
		if slot.data != null:
			result.append(slot.data)
	result.append_array(traits)
	return result

## 特性（强化）卡必须已经拥有同系核心卡：先选枪/刃/冲刺定下打法，再深挖该系。
## 双重卡不走这条，它们由 required_sins 自己要求两系核心同时在场。
func has_sin_core(sin: int) -> bool:
	for slot in slots:
		if slot.data != null and slot.data.core and slot.data.sin == sin:
			return true
	return false

func can_equip(card: BoonData) -> bool:
	if card == null or card.id.is_empty() or has(card.id):
		return false
	if not card.core and card.rarity != BoonData.Rarity.DUAL and not has_sin_core(card.sin):
		return false
	for id in card.prerequisites:
		if not has(id):
			return false
	if not card.prerequisite_any.is_empty():
		var found := false
		for id in card.prerequisite_any:
			found = found or has(id)
		if not found:
			return false
	for sin in card.required_sins:
		var found := false
		for slot in slots:
			found = found or (slot.data != null and slot.data.sin == sin)
		if not found:
			return false
	var count := 0
	for trait_card in traits:
		if trait_card.rarity != BoonData.Rarity.DUAL and (card.required_trait_sin < 0 or trait_card.sin == card.required_trait_sin):
			count += 1
	return count >= card.required_trait_count

func request_equip(card: BoonData) -> bool:
	if not can_equip(card):
		return false
	if card.core and slots[card.slot].data != null:
		_pending = card
		replacement_requested.emit(slots[card.slot].data, card)
		return false
	return equip(card)

func confirm_replace(accept: bool) -> bool:
	var card := _pending
	_pending = null
	return equip(card) if accept and card != null else false

## Trusted restore may include traits whose original prerequisite was replaced.
func equip(card: BoonData) -> bool:
	if card == null or card.id.is_empty() or has(card.id):
		return false
	if card.core:
		var previous := slots[card.slot].data
		if previous != null:
			stats.remove_modifier(StringName("boon:" + previous.id))
		slots[card.slot].data = card
	else:
		traits.append(card)
	stats.set_modifier(StringName("boon:" + card.id), card.stat_modifiers)
	_sync_effects()
	_changed()
	return true

func remove(id: String) -> bool:
	var card := get_boon(id)
	if card == null:
		return false
	if card.core:
		slots[card.slot].data = null
	else:
		traits.erase(card)
	stats.remove_modifier(StringName("boon:" + card.id))
	_sync_effects()
	_changed()
	return true

func restore(cards: Array) -> void:
	clear()
	_active = true
	for card in cards:
		if card is BoonData:
			equip(card)

func effect_for(script: Script) -> BoonEffect:
	return _effects.get(script) as BoonEffect

func _sync_effects() -> void:
	var wanted: Array[Script] = []
	for card in all_equipped():
		if card.script_hook != null and not wanted.has(card.script_hook):
			wanted.append(card.script_hook)
	for script in _effects.keys():
		if not wanted.has(script):
			_effects[script].cleanup()
			_effects.erase(script)
	for script in wanted:
		if not _effects.has(script):
			var effect := script.new() as BoonEffect
			if effect != null:
				_effects[script] = effect
				effect.setup(self)

func _changed() -> void:
	changed.emit()
	loadout_changed.emit(all_equipped())

func dispatch(event: StringName, context: Dictionary) -> void:
	if not _active:
		return
	if event == &"hit_before":
		_scale_outgoing_damage(context)
	if event == &"parry":
		_scale_player_projectile(context.get("projectile"))
	for effect: BoonEffect in _effects.values():
		effect.on_event(event, context)
	if event == &"hit_before" and int(context.get("proc_depth", 0)) == 0 and not context.get("critical", false):
		var chance := stats.get_value(Stats.CRIT_CHANCE) + float(context.get("crit_chance_add", 0.0))
		if chance > 0.0 and rng.randf() < chance:
			context.critical = true
			context.critical_multiplier = stats.get_value(Stats.CRIT_MULTIPLIER)
			context.damage *= context.critical_multiplier * float(context.get("critical_damage_scale", 1.0))
	event_dispatched.emit(event, context)

func _before_damage(context: Dictionary) -> void:
	if not context.get("skip_damage_multiplier", false) and not context.get("true_damage", false) and not context.get("unbuffered", false):
		context.damage *= stats.get_value(Stats.DAMAGE_TAKEN)
	dispatch(&"damage_before", context)

func _after_damage(context: Dictionary) -> void:
	dispatch(&"damage_after", context)

func _on_player_died(_source: Node) -> void:
	_active = false
	clear()

func _clock_struck(position: Vector3) -> void:
	dispatch(&"clock_struck", {"source": player, "position": position})

func register_enemy(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or _enemies.has(enemy.get_instance_id()):
		return
	_enemies[enemy.get_instance_id()] = weakref(enemy)
	var target_health := health_of(enemy)
	if target_health != null:
		target_health.before_damage.connect(_enemy_before_damage)
		target_health.after_damage.connect(_enemy_damage)
	for source in _freezes:
		set_status(enemy, source, _freezes[source], 1.0, 0.0)
	dispatch(&"enemy_registered", {"enemy": enemy, "target": enemy, "health": target_health})

func register_projectile(projectile: Node3D) -> void:
	if not is_instance_valid(projectile) or _projectiles.has(projectile.get_instance_id()):
		return
	_projectiles[projectile.get_instance_id()] = weakref(projectile)
	_scale_player_projectile(projectile)
	if is_enemy(projectile.get("source")):
		for source in _freezes:
			set_projectile_scale(projectile, source, 0.0, _freezes[source])
	dispatch(&"projectile_registered", {"projectile": projectile})
	if is_enemy(projectile.get("source")):
		dispatch(&"enemy_shot", {"enemy": projectile.get("source"), "projectile": projectile})

func _scale_player_projectile(projectile: Node) -> void:
	if not is_instance_valid(projectile) or projectile.get("source") != player:
		return
	if "boon_hook" in projectile and not projectile.boon_hook.is_valid():
		projectile.boon_hook = dispatch
	if "speed" in projectile and not projectile.has_meta(&"boon_speed_applied"):
		projectile.speed *= stats.get_value(Stats.PROJECTILE_SPEED)
		projectile.set_meta(&"boon_speed_applied", true)

func _enemy_before_damage(context: Dictionary) -> void:
	# Direct Health callers (reload shockwaves, environmental abilities) still
	# participate, while a context already passed through hit_before cannot double.
	_scale_outgoing_damage(context)
	dispatch(&"enemy_damage_before", context)

func _scale_outgoing_damage(context: Dictionary) -> void:
	if context.get("source") != player or context.get("damage_scaled", false):
		return
	context.damage = float(context.get("damage", 0.0)) * stats.get_value(Stats.DAMAGE)
	context.damage_scaled = true

func _enemy_damage(context: Dictionary) -> void:
	dispatch(&"enemy_damage", context)

func _enemy_killed(enemy: Node3D) -> void:
	var target_health := health_of(enemy)
	var context: Dictionary = target_health.last_damage_context.duplicate() if target_health != null else {}
	context.merge({"enemy": enemy, "target": enemy, "health": target_health}, true)
	dispatch(&"enemy_killed", context)

func _live_nodes(registry: Dictionary) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for id in registry.keys():
		var node = registry[id].get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			registry.erase(id)
		else:
			result.append(node)
	return result

func enemies() -> Array[Node3D]:
	return _live_nodes(_enemies)

func projectiles() -> Array[Node3D]:
	return _live_nodes(_projectiles)

func health_of(node: Node) -> Health:
	if not is_instance_valid(node):
		return null
	if node is Health:
		return node
	if node is Hitbox:
		return node.health
	return node.get_node_or_null("Health") as Health

func hitbox_of(node: Node) -> Hitbox:
	if node is Hitbox:
		return node
	if not is_instance_valid(node):
		return null
	var boxes := node.find_children("*", "Hitbox", true, false)
	for box in boxes:
		if box.body_part == Hitbox.BodyPart.BODY:
			return box as Hitbox
	return boxes[0] as Hitbox if not boxes.is_empty() else null

func is_enemy(node: Node) -> bool:
	if not is_instance_valid(node) or node == player:
		return false
	var target_health := health_of(node)
	return target_health != null and target_health.team != health.team

func line_clear(from: Vector3, to: Vector3) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return false
	if from.distance_squared_to(to) < 0.00001:
		return true
	var query := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD)
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func targets_in_radius(center: Vector3, radius: float, visible: bool = true) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for enemy in enemies():
		var target_health := health_of(enemy)
		if not is_enemy(enemy) or target_health.is_dead():
			continue
		var box := hitbox_of(enemy)
		var point := box.global_position if box != null else enemy.global_position + Vector3.UP
		if point.distance_to(center) <= radius and (not visible or line_clear(center, point)):
			result.append(enemy)
	return result

func apply_damage(target: Node, amount: float, context: Dictionary = {}) -> float:
	var target_health := health_of(target)
	if target_health == null or target_health.is_dead() or int(context.get("proc_depth", 1)) > 4:
		return 0.0
	var ctx := context.duplicate()
	var owner_node := target_health.get_parent()
	var box := hitbox_of(owner_node)
	ctx.merge({"kind": &"proc", "tag": &"boon", "proc_depth": 1, "source": player,
		"target": owner_node, "health": target_health, "hitbox": box, "damage": amount,
		"position": owner_node.global_position, "direction": Vector3.ZERO,
		"body_part": Hitbox.BodyPart.BODY, "critical": false, "cancelled": false}, false)
	ctx.merge({"target": owner_node, "health": target_health, "hitbox": box, "damage": amount}, true)
	dispatch(&"hit_before", ctx)
	var hp_before := target_health.health
	var dealt := 0.0
	if not ctx.cancelled:
		if box != null:
			dealt = box.apply_hit_at(maxf(ctx.damage, 0.0), ctx.source, ctx.position, ctx.direction, false, ctx)
		else:
			dealt = target_health.apply_damage(maxf(ctx.damage, 0.0), ctx.body_part, ctx.source, ctx)
	ctx.dealt = minf(dealt, hp_before)
	ctx.killed = target_health.is_dead()
	dispatch(&"hit_after", ctx)
	return dealt

func aoe(center: Vector3, radius: float, amount: float, context: Dictionary = {}) -> void:
	for target in targets_in_radius(center, radius):
		apply_damage(target, amount, context)

func grant_shield(amount: float, duration: float = 0.0) -> void:
	shield_amount += maxf(amount, 0.0)
	_shield_left = maxf(_shield_left, duration) if duration > 0.0 else -1.0

func _absorb(amount: float) -> float:
	var absorbed := minf(amount, shield_amount)
	shield_amount -= absorbed
	return amount - absorbed

func set_modifier(source: StringName, modifiers: Dictionary, duration: float = 0.0) -> void:
	_modifiers[source] = duration if duration > 0.0 else -1.0
	stats.set_modifier(source, modifiers)

func remove_modifier(source: StringName) -> void:
	_modifiers.erase(source)
	stats.remove_modifier(source)

func set_status(enemy: Node, source: StringName, duration: float, move_scale: float = 1.0,
		time_scale: float = 1.0, stun: bool = false, windup_scale: float = 1.0, block_shield_regen: bool = false, attack_scale: float = 1.0) -> void:
	if not is_instance_valid(enemy) or not "boon_time_scale" in enemy:
		return
	var id := enemy.get_instance_id()
	if not _statuses.has(id):
		_statuses[id] = {"node": weakref(enemy), "sources": {}}
	_statuses[id].sources[source] = {"left": duration if duration > 0.0 else -1.0,
		"move": clampf(move_scale, 0.0, 2.0), "time": clampf(time_scale, 0.0, 2.0), "stun": stun, "windup": maxf(windup_scale, 1.0), "block_regen": block_shield_regen, "attack": maxf(attack_scale, 0.0)}
	_refresh_status(_statuses[id])

func clear_status(enemy: Node, source: StringName) -> void:
	if is_instance_valid(enemy) and _statuses.has(enemy.get_instance_id()):
		var entry: Dictionary = _statuses[enemy.get_instance_id()]
		entry.sources.erase(source)
		_refresh_status(entry)

func _refresh_status(entry: Dictionary) -> void:
	var enemy = entry.node.get_ref()
	if not is_instance_valid(enemy):
		return
	enemy.boon_movement_scale = 1.0
	enemy.boon_time_scale = 1.0
	enemy.boon_stunned = false
	if "boon_attack_scale" in enemy:
		enemy.boon_attack_scale = 1.0
	var block_regen := false
	if "boon_windup_scale" in enemy:
		enemy.boon_windup_scale = 1.0
	for value: Dictionary in entry.sources.values():
		enemy.boon_movement_scale = minf(enemy.boon_movement_scale, value.move)
		enemy.boon_time_scale = minf(enemy.boon_time_scale, value.time)
		enemy.boon_stunned = enemy.boon_stunned or value.stun
		block_regen = block_regen or value.block_regen
		if "boon_attack_scale" in enemy:
			enemy.boon_attack_scale = minf(enemy.boon_attack_scale, value.attack)
		if "boon_windup_scale" in enemy:
			enemy.boon_windup_scale = maxf(enemy.boon_windup_scale, value.windup)
	var target_health := health_of(enemy)
	if target_health != null:
		target_health.set_shield_regeneration_blocked(StringName("boon_status_%s" % get_instance_id()), block_regen)
	if enemy.has_method("set_boon_animation_scale"):
		enemy.set_boon_animation_scale(0.0 if enemy.boon_stunned else enemy.boon_time_scale)

func set_projectile_scale(projectile: Node, source: StringName, scale_value: float, duration: float = 0.0) -> void:
	if not is_instance_valid(projectile) or not "boon_time_scale" in projectile:
		return
	var id := projectile.get_instance_id()
	if not _projectile_statuses.has(id):
		_projectile_statuses[id] = {"node": weakref(projectile), "sources": {}}
	if is_equal_approx(scale_value, 1.0):
		_projectile_statuses[id].sources.erase(source)
	else:
		_projectile_statuses[id].sources[source] = {"left": duration if duration > 0.0 else -1.0, "scale": maxf(scale_value, 0.0)}
	_refresh_projectile(_projectile_statuses[id])

func _refresh_projectile(entry: Dictionary) -> void:
	var projectile = entry.node.get_ref()
	if not is_instance_valid(projectile):
		return
	projectile.boon_time_scale = 1.0
	for value: Dictionary in entry.sources.values():
		projectile.boon_time_scale = minf(projectile.boon_time_scale, value.scale)

func freeze_world(duration: float, source: StringName = &"boon_freeze") -> void:
	if duration <= 0.0:
		return
	_freezes[source] = maxf(float(_freezes.get(source, 0.0)), duration)
	for enemy in enemies():
		set_status(enemy, source, _freezes[source], 1.0, 0.0)
	for projectile in projectiles():
		if is_enemy(projectile.get("source")):
			set_projectile_scale(projectile, source, 0.0, _freezes[source])

func clear_world_freeze(source: StringName) -> void:
	_freezes.erase(source)
	for enemy in enemies():
		clear_status(enemy, source)
	for entry: Dictionary in _projectile_statuses.values():
		entry.sources.erase(source)
		_refresh_projectile(entry)

func feedback(position: Vector3, color: Color, radius: float = 0.5) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 3
	mesh.radius = maxf(radius, 0.01)
	mesh.height = mesh.radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	node.mesh = mesh
	player.get_parent().add_child(node)
	node.global_position = position
	_feedback.append(node)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 1.35, 0.22)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(node.queue_free)

func _physics_process(delta: float) -> void:
	if not _active or get_tree().paused:
		return
	for source in _modifiers.keys():
		if _modifiers[source] > 0.0:
			_modifiers[source] -= delta
			if _modifiers[source] <= 0.0:
				remove_modifier(source)
	for source in _freezes.keys():
		_freezes[source] -= delta
		if _freezes[source] <= 0.0:
			_freezes.erase(source)
	_tick_statuses(_statuses, delta, false)
	_tick_statuses(_projectile_statuses, delta, true)
	if _shield_left > 0.0:
		_shield_left -= delta
		if _shield_left <= 0.0:
			shield_amount = 0.0
	for effect: BoonEffect in _effects.values():
		effect.tick(delta)
	_feedback = _feedback.filter(func(node): return is_instance_valid(node))

func _tick_statuses(registry: Dictionary, delta: float, projectile: bool) -> void:
	for id in registry.keys():
		var entry: Dictionary = registry[id]
		if not is_instance_valid(entry.node.get_ref()):
			registry.erase(id)
			continue
		for source in entry.sources.keys():
			var value: Dictionary = entry.sources[source]
			if value.left > 0.0:
				value.left -= delta
				if value.left <= 0.0:
					entry.sources.erase(source)
		if projectile:
			_refresh_projectile(entry)
		else:
			_refresh_status(entry)
		if entry.sources.is_empty():
			registry.erase(id)

func clear(notify: bool = true) -> void:
	for effect: BoonEffect in _effects.values():
		effect.cleanup()
	_effects.clear()
	for card in all_equipped():
		stats.remove_modifier(StringName("boon:" + card.id))
	for source in _modifiers.keys():
		remove_modifier(source)
	for slot in slots:
		slot.data = null
	traits.clear()
	_pending = null
	shield_amount = 0.0
	_freezes.clear()
	for entry: Dictionary in _statuses.values():
		entry.sources.clear()
		_refresh_status(entry)
	for entry: Dictionary in _projectile_statuses.values():
		entry.sources.clear()
		_refresh_projectile(entry)
	_statuses.clear()
	_projectile_statuses.clear()
	for node in _feedback:
		if is_instance_valid(node):
			node.queue_free()
	_feedback.clear()
	if notify:
		_changed()

func _exit_tree() -> void:
	clear(false)
