class_name RealmPlayerEffects
extends Node
## Injected, source-scoped realm hazards. No global run state is read here.
signal changed

var player: Player
var effects: Dictionary = {}
## Samples shallow-water motion at the player's feet. XYZ is velocity, W marks a trap core.
var ground_current: Callable
var move_multiplier := 1.0
var jump_multiplier := 1.0
var dash_distance_multiplier := 1.0
var dash_blocked := false
var monochrome := 0.0
var warnings_enabled := true
var _last_stats: Dictionary = {}


func _init() -> void:
	process_physics_priority = -20


func bind(value: Player) -> void:
	player = value
	player.health.died.connect(_on_died)


func set_effect(source: StringName, values: Dictionary) -> void:
	var entry := values.duplicate()
	if entry.has("owner") and entry.owner is Node:
		entry.owner = weakref(entry.owner)
	effects[source] = entry
	_refresh()


func clear_effect(source: StringName) -> void:
	if effects.erase(source):
		_refresh()


func clear_all() -> void:
	effects.clear()
	_refresh()


func _physics_process(delta: float) -> void:
	var dirty := false
	for source in effects.keys():
		var entry: Dictionary = effects[source]
		var owner_ref: WeakRef = entry.get("owner") as WeakRef
		if owner_ref != null and not is_instance_valid(owner_ref.get_ref()):
			effects.erase(source)
			dirty = true
			continue
		if entry.has("duration"):
			entry.duration = maxf(0.0, float(entry.duration) - delta)
			if entry.duration <= 0.0:
				effects.erase(source)
				dirty = true
	if dirty:
		_refresh()


func _refresh() -> void:
	move_multiplier = 1.0
	jump_multiplier = 1.0
	dash_distance_multiplier = 1.0
	dash_blocked = false
	monochrome = 0.0
	var reload := 1.0
	var cooldown := 1.0
	for entry: Dictionary in effects.values():
		move_multiplier = minf(move_multiplier, clampf(float(entry.get("move_multiplier", 1.0)), 0.0, 1.0))
		jump_multiplier = minf(jump_multiplier, clampf(float(entry.get("jump_multiplier", 1.0)), 0.0, 1.0))
		dash_distance_multiplier = minf(dash_distance_multiplier, clampf(float(entry.get("dash_distance_multiplier", 1.0)), 0.0, 1.0))
		dash_blocked = dash_blocked or bool(entry.get("dash_blocked", false))
		monochrome = maxf(monochrome, clampf(float(entry.get("monochrome", 0.0)), 0.0, 1.0))
		reload = minf(reload, clampf(float(entry.get("reload_multiplier", 1.0)), 0.05, 1.0))
		cooldown = maxf(cooldown, clampf(float(entry.get("cooldown_multiplier", 1.0)), 1.0, 10.0))
	if is_instance_valid(player):
		if effects.is_empty():
			if not _last_stats.is_empty():
				player.stats.remove_modifier(&"realm_fields")
				_last_stats.clear()
		else:
			var modifiers := {
				Stats.RELOAD_SPEED: {"mul": reload}, Stats.DASH_RECHARGE: {"mul": 1.0 / cooldown},
				Stats.SHIELD_COOLDOWN: {"mul": cooldown}, Stats.FIRE_RATE: {"mul": 1.0 / cooldown},
			}
			if modifiers != _last_stats:
				_last_stats = modifiers
				player.stats.set_modifier(&"realm_fields", modifiers)
		if dash_blocked:
			player.cancel_forced_movement()
	changed.emit()


func _on_died(_source: Node) -> void:
	clear_all()


func _exit_tree() -> void:
	if is_instance_valid(player) and is_instance_valid(player.stats):
		player.stats.remove_modifier(&"realm_fields")
