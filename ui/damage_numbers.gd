class_name DamageNumbers
extends Control
## Screen-space projected floating damage numbers for player hits on every
## enemy, boss and destructible Health target. Pure presentation: uses its own
## fixed-seed RNG (ADR 0005), freezes on pause and never touches combat state.

enum Kind { NORMAL, HEADSHOT, CRITICAL, FEAR_CRITICAL, SHIELD }

const MAX_ACTIVE := 48
const FEEL_SEED := 0xDA4A6E
const GRAVITY := 250.0
const GROW_BURST_TIME := 0.24
const START_SCALE := 0.36
const MID_SCALE := 0.96
const END_SCALE := 1.14
const FADE_TIME := 0.24
const SHAKE_TIME := 0.085
const STACK_WINDOW := 0.12
const STACK_RADIUS_SQ := 1.0

const COLOR_NORMAL := Color("f7f8fa")
const COLOR_HEADSHOT := Color("ffd84d")
const COLOR_CRITICAL := Color("ff8c2e")
const COLOR_FEAR_CRIT := Color("de8cff")
const COLOR_SHIELD := Color("73f1ff")
const COLOR_KILL := Color("ff4742")
const OUTLINE_DARK := Color(0.04, 0.05, 0.08, 0.96)
const OUTLINE_KILL := Color(0.28, 0.03, 0.04, 0.98)
const SHADOW_COLOR := Color(0.02, 0.02, 0.04, 0.65)

class Entry:
	var text := ""
	var world_pos := Vector3.ZERO
	var screen_offset := Vector2.ZERO
	var velocity := Vector2.ZERO
	var elapsed := 0.0
	var lifetime := 0.78
	var font_size := 28
	var end_scale := END_SCALE
	var color := Color.WHITE
	var outline := Color.BLACK
	var shake_amp := 0.0
	var shake_phase := 0.0
	var kind := Kind.NORMAL
	var killed := false

var _player: Player
var _room: Node
var _enabled := true
var _configured := false
var _registered_overlay := false
var _tracked: Dictionary[int, bool] = {}
var _entries: Array[Entry] = []
var _rng := RandomNumberGenerator.new()
var _seq := 0
var _font: Font


func _init() -> void:
	name = "DamageNumbers"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = FEEL_SEED


func setup(player: Player, room: Node = null) -> void:
	_player = player
	_room = room if room != null else (player.get_parent() if is_instance_valid(player) else null)
	_configured = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = EditorialStyle.font_mono(800)
	_set_overlay_registered(_enabled and is_inside_tree())
	if not Events.enemy_registered.is_connected(_on_enemy_registered):
		Events.enemy_registered.connect(_on_enemy_registered)
	if is_instance_valid(_player) and _player.health != null \
			and not _player.health.died.is_connected(_on_player_died):
		_player.health.died.connect(_on_player_died)
	_scan_room()


func _enter_tree() -> void:
	if _configured:
		_set_overlay_registered(_enabled)


func set_enabled(value: bool) -> void:
	_enabled = value
	set_process(value)
	_set_overlay_registered(value and is_inside_tree())
	if not value:
		clear()


func clear() -> void:
	if not _entries.is_empty():
		_entries.clear()
		queue_redraw()


func active_count() -> int:
	return _entries.size()


func latest_entry() -> Entry:
	return _entries.back() if not _entries.is_empty() else null


func _exit_tree() -> void:
	_set_overlay_registered(false)
	if Events.enemy_registered.is_connected(_on_enemy_registered):
		Events.enemy_registered.disconnect(_on_enemy_registered)


func _set_overlay_registered(want: bool) -> void:
	if want == _registered_overlay:
		return
	_registered_overlay = want
	if want:
		FearCriticalFeedback.register_2d_overlay()
	else:
		FearCriticalFeedback.unregister_2d_overlay()


func _scan_room() -> void:
	if not is_instance_valid(_room) or not is_instance_valid(_player):
		return
	for node in _room.find_children("*", "Node", true, false):
		if node is Health:
			_track_health(node as Health)


func _on_enemy_registered(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(_player):
		return
	if is_instance_valid(_room) and not _room.is_ancestor_of(enemy):
		return
	var health := enemy.get_node_or_null("Health") as Health
	if health != null:
		_track_health(health)


func _track_health(health: Health) -> void:
	if not is_instance_valid(health) or not is_instance_valid(_player):
		return
	if health.team == _player.team:
		return
	var id := health.get_instance_id()
	if _tracked.has(id):
		return
	_tracked[id] = true
	health.after_damage.connect(_on_after_damage)
	health.tree_exiting.connect(_untrack_health.bind(id), CONNECT_ONE_SHOT)


func _untrack_health(id: int) -> void:
	_tracked.erase(id)


func _on_player_died(_source: Node) -> void:
	clear()


func _can_show() -> bool:
	return _enabled and is_inside_tree() and not get_tree().paused and is_visible_in_tree() \
		and is_instance_valid(_player) and not _player.health.is_dead()


func _on_after_damage(context: Dictionary) -> void:
	if not _can_show():
		return
	var source: Node = context.get("source")
	if not is_instance_valid(source):
		return
	var from_player := source == _player or ("team" in source and int(source.team) == _player.team)
	if not from_player:
		return
	var dealt := float(context.get("dealt", 0.0))
	var absorbed := float(context.get("absorbed", 0.0))
	var total := float(context.get("resolved_damage", dealt + absorbed))
	if total <= 0.0:
		return
	var target := context.get("target") as Node3D
	if not context.has("position") and not is_instance_valid(target):
		return
	var point: Vector3 = context.get("position",
		target.global_position + Vector3.UP * 1.35 if is_instance_valid(target) else Vector3.ZERO)
	var body_part: Hitbox.BodyPart = context.get("body_part", Hitbox.BodyPart.BODY)
	var hitbox := context.get("hitbox") as Hitbox
	var headshot := body_part == Hitbox.BodyPart.HEAD \
		or (is_instance_valid(hitbox) and hitbox.body_part == Hitbox.BodyPart.HEAD)
	var fear_crit := bool(context.get("fear_critical", false))
	var critical := bool(context.get("critical", false)) or fear_crit
	var killed := bool(context.get("killed", false))
	var shield_only := dealt <= 0.001 and absorbed > 0.0
	spawn_number(point, total, headshot, critical, fear_crit, shield_only, killed)


func spawn_number(world_pos: Vector3, amount: float, headshot := false, critical := false,
		fear_critical := false, shield_only := false, killed := false) -> Entry:
	var entry := Entry.new()
	var value := maxi(1, roundi(amount))
	var dmg_bonus := clampi(int(amount / 28.0) * 2, 0, 10)
	entry.world_pos = world_pos + Vector3.UP * 0.14
	entry.killed = killed
	if shield_only:
		entry.kind = Kind.SHIELD
		entry.text = "%d" % value
		entry.font_size = 24 + mini(dmg_bonus, 4)
		entry.color = COLOR_SHIELD
		entry.outline = OUTLINE_DARK
		entry.end_scale = 1.06
		entry.lifetime = 0.68
	elif fear_critical:
		entry.kind = Kind.FEAR_CRITICAL
		entry.text = "%d!" % value
		entry.font_size = 48 + mini(dmg_bonus, 8)
		entry.color = COLOR_FEAR_CRIT
		entry.outline = OUTLINE_KILL if killed else OUTLINE_DARK
		entry.end_scale = 1.24
		entry.lifetime = 0.96
		entry.shake_amp = 4.5
	elif critical:
		entry.kind = Kind.CRITICAL
		entry.text = "%d!" % value
		entry.font_size = 44 + mini(dmg_bonus, 8)
		entry.color = COLOR_CRITICAL
		entry.outline = OUTLINE_KILL if killed else OUTLINE_DARK
		entry.end_scale = 1.22
		entry.lifetime = 0.94
		entry.shake_amp = 4.0
	elif headshot:
		entry.kind = Kind.HEADSHOT
		entry.text = "%d" % value
		entry.font_size = 38 + mini(dmg_bonus, 6)
		entry.color = COLOR_HEADSHOT
		entry.outline = OUTLINE_KILL if killed else OUTLINE_DARK
		entry.end_scale = 1.18
		entry.lifetime = 0.88
		entry.shake_amp = 2.6
	else:
		entry.kind = Kind.NORMAL
		entry.text = "%d" % value
		entry.font_size = 28 + dmg_bonus
		entry.color = COLOR_KILL if killed else COLOR_NORMAL
		entry.outline = OUTLINE_DARK
		entry.end_scale = 1.12
		entry.lifetime = 0.78
	if killed:
		entry.font_size += 6
		entry.end_scale += 0.08
		entry.lifetime = maxf(entry.lifetime, 0.94)
		entry.shake_amp = maxf(entry.shake_amp, 3.2)

	_seq += 1
	var side := -1.0 if (_seq % 2 == 0) else 1.0
	var vx := side * _rng.randf_range(28.0, 74.0)
	var vy := -_rng.randf_range(108.0, 152.0) * (1.14 if (headshot or critical or killed) else 1.0)
	entry.velocity = Vector2(vx, vy)
	entry.shake_phase = _rng.randf() * TAU

	# Slight stagger when rapid hits or multi-procs land on the same spot.
	var nearby := 0
	for other in _entries:
		if other.elapsed < STACK_WINDOW and other.world_pos.distance_squared_to(entry.world_pos) < STACK_RADIUS_SQ:
			nearby += 1
	if nearby > 0:
		entry.screen_offset = Vector2(side * minf(nearby * 14.0, 42.0), -minf(nearby * 16.0, 48.0))

	if _entries.size() >= MAX_ACTIVE:
		_entries.pop_front()
	_entries.append(entry)
	queue_redraw()
	return entry


func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	if not _enabled or get_tree().paused:
		return
	for i in range(_entries.size() - 1, -1, -1):
		var entry := _entries[i]
		entry.elapsed += delta
		if entry.elapsed >= entry.lifetime:
			_entries.remove_at(i)
			continue
		entry.velocity.y += GRAVITY * delta
		entry.screen_offset += entry.velocity * delta
		entry.velocity.x *= exp(-2.4 * delta)
	queue_redraw()


## Monotonic growth curve so every number visibly expands from small to large
## as it arcs upward, with a punchy opening expansion and gentle follow-through.
static func growth_scale(entry: Entry) -> float:
	if entry.elapsed < GROW_BURST_TIME:
		var t := clampf(entry.elapsed / GROW_BURST_TIME, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 2.4)
		return lerpf(START_SCALE, MID_SCALE, eased)
	var tail := maxf(entry.lifetime - GROW_BURST_TIME, 0.001)
	var u := clampf((entry.elapsed - GROW_BURST_TIME) / tail, 0.0, 1.0)
	return lerpf(MID_SCALE, entry.end_scale, u)


func _draw() -> void:
	if _entries.is_empty() or not _can_show():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var font := _font if _font != null else ThemeDB.fallback_font
	var canvas_inv := get_global_transform_with_canvas().affine_inverse()
	var view_rect := get_viewport_rect().grow(64.0)
	var cam_pos := camera.global_position
	for entry in _entries:
		if camera.is_position_behind(entry.world_pos):
			continue
		var projected := camera.unproject_position(entry.world_pos)
		if not view_rect.has_point(projected):
			continue
		var pos := canvas_inv * projected + entry.screen_offset
		if entry.shake_amp > 0.0 and entry.elapsed < SHAKE_TIME:
			var decay := 1.0 - entry.elapsed / SHAKE_TIME
			pos.x += sin(entry.elapsed * 95.0 + entry.shake_phase) * entry.shake_amp * decay
		var dist := cam_pos.distance_to(entry.world_pos)
		var dist_scale := clampf(10.0 / maxf(dist, 3.0), 0.80, 1.12)
		var scale_value := dist_scale * growth_scale(entry)
		var alpha := clampf((entry.lifetime - entry.elapsed) / FADE_TIME, 0.0, 1.0)
		var text_size := font.get_string_size(entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, entry.font_size)
		var baseline := Vector2(-text_size.x * 0.5, text_size.y * 0.32)
		var outline_w := 8 if entry.font_size >= 40 else 6
		draw_set_transform(pos, 0.0, Vector2.ONE * scale_value)
		draw_string(font, baseline + Vector2(2.0, 2.5), entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			entry.font_size, Color(SHADOW_COLOR, SHADOW_COLOR.a * alpha))
		draw_string_outline(font, baseline, entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			entry.font_size, outline_w, Color(entry.outline, entry.outline.a * alpha))
		draw_string(font, baseline, entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			entry.font_size, Color(entry.color, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
