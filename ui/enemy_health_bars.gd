class_name EnemyHealthBars
extends Control
## Projects room enemies in the HUD without modifying their combat state.

const MAX_RANGE := 32.0
const NEAR_RANGE := 18.0
const AIM_COSINE := 0.9902680687 # cos(8 degrees)
const REVEAL_TIME := 0.10
const BAR_SIZE := Vector2(58, 5)
const TRACK_COLOR := Color(0.06, 0.06, 0.07, 0.85)
const DEFAULT_FILL := Color("f26464")
const SHIELD_COLOR := Color("73f1ff")

class Entry:
	var enemy: WeakRef
	var trail := HealthTrail.new()
	var hitboxes: Array[WeakRef] = []
	var head_shape: WeakRef
	var was_damaged := false
	var unobstructed := false
	var alpha := 0.0

var _player: Player
var _room: Node
var _fill := DEFAULT_FILL
var _tracked: Dictionary[int, Entry] = {}
var _shown: Dictionary[int, Dictionary] = {}
var _ray := PhysicsRayQueryParameters3D.new()


func _init() -> void:
	name = "EnemyHealthBars"
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ray.collision_mask = CollisionLayers.WORLD
	_ray.hit_from_inside = true


func setup(player: Player, room: Node, enemies: Array[Enemy] = [], accent := DEFAULT_FILL) -> void:
	_player = player
	_room = room
	_fill = accent
	_player.health.died.connect(_on_player_died)
	Events.enemy_registered.connect(_track)
	if enemies.is_empty():
		for node in room.find_children("*", "CharacterBody3D", true, false):
			_track(node)
	else:
		for enemy in enemies:
			_track(enemy)


func tracked_count() -> int:
	return _tracked.size()


## Snapshot of the bars being drawn, keyed by enemy instance ID.
func visible_entries() -> Dictionary[int, Dictionary]:
	if not _can_show():
		return {}
	return _shown.duplicate(true)


func _track(node: Node3D) -> void:
	var enemy := node as Enemy
	if enemy == null or enemy.is_boss or enemy.health == null or enemy.health.is_dead() \
			or not is_instance_valid(_player) or _player.health.is_dead() \
			or not _room.is_ancestor_of(enemy):
		return
	var id := enemy.get_instance_id()
	if _tracked.has(id):
		return
	var entry := Entry.new()
	entry.enemy = weakref(enemy)
	entry.trail.reset(enemy.health.health)
	for child in enemy.find_children("*", "StaticBody3D", true, false):
		var hitbox := child as Hitbox
		if hitbox == null or hitbox.health != enemy.health:
			continue
		entry.hitboxes.append(weakref(hitbox))
		if hitbox.name == &"HeadHitbox":
			for shape in hitbox.get_children():
				if shape is CollisionShape3D and shape.shape != null:
					entry.head_shape = weakref(shape)
					break
	_tracked[id] = entry
	enemy.health.damaged.connect(_on_enemy_damaged.bind(id))
	enemy.health.died.connect(_on_enemy_died.bind(id), CONNECT_ONE_SHOT)
	enemy.tree_exiting.connect(_untrack.bind(id), CONNECT_ONE_SHOT)


func _on_enemy_damaged(_amount: float, _part: Hitbox.BodyPart, _source: Node, id: int) -> void:
	var entry := _tracked.get(id) as Entry
	if entry == null:
		return
	var enemy := entry.enemy.get_ref() as Enemy
	var health := enemy.health
	if health.is_dead():
		return
	entry.was_damaged = entry.was_damaged or health.health < health.max_health
	if get_tree().paused:
		return
	entry.trail.advance(health.health, 0.0)
	if _shown.has(id):
		var bar := _shown[id]
		bar.health = entry.trail.current
		bar.delayed = entry.trail.delayed
		bar.max_health = health.max_health
		bar.shield = health.shield_points
		if entry.was_damaged:
			bar.alpha = 1.0
		queue_redraw()


func _on_enemy_died(_source: Node, id: int) -> void:
	_untrack(id)


func _untrack(id: int) -> void:
	_tracked.erase(id)
	if _shown.erase(id):
		queue_redraw()


func _on_player_died(_source: Node) -> void:
	_tracked.clear()
	_shown.clear()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_shown.clear()
		queue_redraw()


func _can_show() -> bool:
	return is_inside_tree() and not get_tree().paused and is_visible_in_tree() \
		and is_instance_valid(_player) and not _player.health.is_dead()


func _can_target(enemy: Enemy, entry: Entry) -> bool:
	if enemy.is_boss or (enemy is FearWisp and enemy.dormant):
		return false
	if entry.hitboxes.is_empty():
		return true
	for reference in entry.hitboxes:
		var hitbox := reference.get_ref() as Hitbox
		if is_instance_valid(hitbox) and (hitbox.collision_layer & CollisionLayers.HITBOXES) != 0:
			return true
	return false


func _anchor(enemy: Enemy, entry: Entry) -> Vector3:
	if entry.head_shape != null:
		var collision := entry.head_shape.get_ref() as CollisionShape3D
		if is_instance_valid(collision):
			var sphere := collision.shape as SphereShape3D
			if sphere != null:
				var local_up := collision.global_basis.transposed() * Vector3.UP
				return collision.global_position + Vector3.UP * sphere.radius * local_up.length()
			var bounds := collision.shape.get_debug_mesh().get_aabb()
			var world_bounds: AABB = collision.global_transform * bounds
			return Vector3(collision.global_position.x, world_bounds.end.y, collision.global_position.z)
	return enemy.global_position + Vector3.UP * (enemy.eye_height + 0.55)


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not _can_show() or _tracked.is_empty():
		return
	var space := camera.get_world_3d().direct_space_state
	_ray.from = camera.get_camera_transform().origin
	for id in _tracked.keys():
		var entry := _tracked[id]
		var enemy := entry.enemy.get_ref() as Enemy
		if not is_instance_valid(enemy) or enemy.health.is_dead():
			_untrack(id)
			continue
		entry.unobstructed = false
		if not _can_target(enemy, entry):
			continue
		_ray.to = _anchor(enemy, entry)
		if _ray.from.distance_squared_to(_ray.to) <= MAX_RANGE * MAX_RANGE \
				and not camera.is_position_behind(_ray.to):
			entry.unobstructed = space.intersect_ray(_ray).is_empty()


func _process(delta: float) -> void:
	var needs_redraw := not _shown.is_empty()
	_shown.clear()
	var camera := get_viewport().get_camera_3d()
	var show_bars := camera != null and _can_show()
	for id in _tracked.keys():
		var entry := _tracked[id]
		var enemy := entry.enemy.get_ref() as Enemy
		if not is_instance_valid(enemy) or enemy.health.is_dead():
			_untrack(id)
			continue
		var health := enemy.health
		entry.trail.advance(health.health, delta)
		entry.was_damaged = entry.was_damaged or health.health < health.max_health
		if show_bars and entry.unobstructed and _can_target(enemy, entry):
			_project(id, entry, enemy, camera, delta)
		else:
			entry.alpha = 0.0
	if needs_redraw or not _shown.is_empty():
		queue_redraw()


func _project(id: int, entry: Entry, enemy: Enemy, camera: Camera3D, delta: float) -> void:
	var anchor := _anchor(enemy, entry)
	var view := camera.get_camera_transform()
	var offset := anchor - view.origin
	var distance_squared := offset.length_squared()
	var in_aim := (-view.basis.z).dot(offset.normalized()) >= AIM_COSINE
	if distance_squared > MAX_RANGE * MAX_RANGE or camera.is_position_behind(anchor) \
			or (not entry.was_damaged and distance_squared > NEAR_RANGE * NEAR_RANGE and not in_aim):
		entry.alpha = 0.0
		return
	var point := camera.unproject_position(anchor)
	if not get_viewport_rect().has_point(point):
		entry.alpha = 0.0
		return
	var health := enemy.health
	entry.alpha = 1.0 if entry.was_damaged else move_toward(entry.alpha, 1.0, delta / REVEAL_TIME)
	_shown[id] = {
		"position": get_global_transform_with_canvas().affine_inverse() * point,
		"health": entry.trail.current,
		"delayed": entry.trail.delayed,
		"max_health": health.max_health,
		"shield": health.shield_points,
		"max_shield": health.max_shield,
		"alpha": entry.alpha,
	}


func _draw() -> void:
	if not _can_show():
		return
	for bar in _shown.values():
		var origin: Vector2 = (bar.position - Vector2(BAR_SIZE.x * 0.5, BAR_SIZE.y)).round()
		var inner := origin + Vector2.ONE
		var interior := BAR_SIZE - Vector2(2, 2)
		var current := _fill_width(bar.health, bar.max_health, interior.x)
		var delayed := _fill_width(bar.delayed, bar.max_health, interior.x)
		draw_rect(Rect2(origin, BAR_SIZE), Color(TRACK_COLOR, TRACK_COLOR.a * bar.alpha))
		draw_rect(Rect2(inner, Vector2(current, interior.y)), Color(_fill, bar.alpha))
		if delayed > current:
			draw_rect(Rect2(inner + Vector2(current, 0), Vector2(delayed - current, interior.y)),
				Color(Color.WHITE, bar.alpha))
		if bar.max_shield > 0.0 or bar.shield > 0.0:
			var shield_origin := origin - Vector2(0, 3)
			var shield_width := _fill_width(bar.shield, maxf(bar.max_shield, bar.shield), BAR_SIZE.x)
			draw_rect(Rect2(shield_origin, Vector2(BAR_SIZE.x, 2)), Color(TRACK_COLOR, TRACK_COLOR.a * bar.alpha))
			draw_rect(Rect2(shield_origin, Vector2(shield_width, 2)), Color(SHIELD_COLOR, bar.alpha))


func _fill_width(value: float, maximum: float, width: float) -> float:
	return roundf(width * clampf(value / maxf(maximum, 0.001), 0.0, 1.0))
