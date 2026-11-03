class_name Minimap
extends Control
## Top-right circular minimap. Player-centred, so "up" is where the player
## faces; the map turns with the player instead of the player icon. Reads the
## zone director and actors (ui -> zone -> actors) and never writes them.
##
## Level geometry is read once in setup(): every StaticBody3D under the map's
## Geometry node with a BoxShape3D becomes a world XZ quad. The floor is
## skipped. Each frame only transforms and clips those cached quads.

## Map radius in metres. Enemies farther than this are not drawn.
const RANGE_METERS := 28.0
const DISC_COLOR := Color(0.02, 0.04, 0.06, 0.62)
const RIM_COLOR := Color(0.78, 0.86, 0.92, 0.5)
const RIM_WIDTH := 2.0
const GEOMETRY_COLOR := Color(0.85, 0.89, 0.93, 0.8)
const PLAYER_COLOR := Color(0.96, 0.98, 1.0)
const ENEMY_RADIUS := 4.0
const ENEMY_COLOR := Color(0.95, 0.2, 0.15)
## Retreating minions stay on the map, just fainter.
const ENEMY_FLEE_ALPHA := 0.4
const BOSS_RADIUS := 9.0
const BOSS_COLOR := Color(0.75, 0.08, 0.1)
const MARKER_RADIUS := 5.0
const PEDESTAL_RADIUS := 4.5
const PULSE_TIME := 1.2
const PULSE_COLOR := Color(1.0, 0.2, 0.15)
const VIEW_CONE_RADIUS := 0.55
const VIEW_CONE_ALPHA := 0.12
## A box this large on both XZ sides is floor, not cover.
const MAX_FOOTPRINT := 60.0
const CIRCLE_SEGMENTS := 32
const OUTLINE_WIDTH := 1.2

var _director: ZoneDirector
var _player: Player
var _geometry: Array[PackedVector2Array] = []
var _pulses: Array[Dictionary] = []
var _circle := PackedVector2Array()
var _circle_radius := 0.0
var _circle_center := Vector2.ZERO


## The HUD calls this once. Geometry is read here, not every frame.
func setup(director: ZoneDirector, player: Player) -> void:
	_director = director
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_read_geometry()
	if not director.reinforcement_spawned.is_connected(add_reinforcement):
		director.reinforcement_spawned.connect(add_reinforcement)
	queue_redraw()


func _process(delta: float) -> void:
	for i in range(_pulses.size() - 1, -1, -1):
		_pulses[i]["age"] = float(_pulses[i]["age"]) + delta
		if float(_pulses[i]["age"]) >= PULSE_TIME:
			_pulses.remove_at(i)
	queue_redraw()


## Screen position of a world point on this control. The player is the centre
## and their forward is up.
func to_map(world: Vector3) -> Vector2:
	var centre := size * 0.5
	if _player == null:
		return centre
	var to := Vector2(world.x - _player.global_position.x, world.z - _player.global_position.z)
	var right := Vector2(_player.global_basis.x.x, _player.global_basis.x.z).normalized()
	var forward := Vector2(-_player.global_basis.z.x, -_player.global_basis.z.z).normalized()
	return centre + Vector2(to.dot(right), -to.dot(forward)) * _map_scale()


## Where an out-of-range objective's arrow sits: just inside the rim.
func rim_position(world: Vector3) -> Vector2:
	var centre := size * 0.5
	var at := to_map(world)
	var offset := at - centre
	var limit := _map_scale() * RANGE_METERS - MARKER_RADIUS - 2.0
	if offset.length() <= limit:
		return at
	return centre + offset.normalized() * limit


## Living enemies within map range. For tests and proofs.
func visible_enemy_count() -> int:
	if _director == null:
		return 0
	var count := 0
	for enemy in _director.living_enemies():
		if is_instance_valid(enemy) and _flat_distance(enemy.global_position) <= RANGE_METERS:
			count += 1
	return count


func geometry_count() -> int:
	return _geometry.size()


func pulse_count() -> int:
	return _pulses.size()


## A reinforcement appeared: pulse at its spot, or on the rim if it is far.
func add_reinforcement(position: Vector3) -> void:
	_pulses.append({"position": position, "age": 0.0})


func _read_geometry() -> void:
	_geometry.clear()
	if _director == null:
		return
	var root := _director.get_parent()
	var geometry := root.get_node_or_null("Geometry") if root != null else null
	if geometry == null:
		return
	for node in geometry.get_children():
		var body := node as StaticBody3D
		if body == null:
			continue
		if String(body.name) == "Floor":
			continue
		for child in body.get_children():
			var shape_node := child as CollisionShape3D
			if shape_node == null or not (shape_node.shape is BoxShape3D):
				continue
			var box_size := (shape_node.shape as BoxShape3D).size
			if box_size.x > MAX_FOOTPRINT and box_size.z > MAX_FOOTPRINT:
				break
			var xform := shape_node.global_transform
			var quad := PackedVector2Array()
			for corner in [Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, -0.5),
					Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5)]:
				var world := xform * Vector3(corner.x * box_size.x, 0.0, corner.z * box_size.z)
				quad.append(Vector2(world.x, world.z))
			_geometry.append(quad)
			break


func _map_scale() -> float:
	return (minf(size.x, size.y) * 0.5 - RIM_WIDTH) / RANGE_METERS


func _flat_distance(world: Vector3) -> float:
	if _player == null:
		return INF
	return Vector2(world.x - _player.global_position.x, world.z - _player.global_position.z).length()


func _draw() -> void:
	if _director == null or _player == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	draw_circle(centre, radius, DISC_COLOR)
	_draw_geometry(centre, radius)
	draw_arc(centre, radius - RIM_WIDTH * 0.5, 0.0, TAU, 64, RIM_COLOR, RIM_WIDTH, true)
	_draw_view_cone(centre, radius)
	# Enemies first: the boss and the objectives always stay on top of a crowd.
	_draw_enemies(centre)
	_draw_objectives()
	_draw_pulses(centre, radius)
	_draw_player(centre)


func _draw_geometry(centre: Vector2, radius: float) -> void:
	var clip := _circle_polygon(centre, radius - RIM_WIDTH)
	for quad in _geometry:
		var mapped := PackedVector2Array()
		for point in quad:
			mapped.append(to_map(Vector3(point.x, 0.0, point.y)))
		for piece in Geometry2D.intersect_polygons(mapped, clip):
			if piece.size() >= 3:
				draw_colored_polygon(piece, GEOMETRY_COLOR)


## Cached convex polygon for the circular clip; rebuilt only when the size moves.
func _circle_polygon(centre: Vector2, radius: float) -> PackedVector2Array:
	if _circle.size() == CIRCLE_SEGMENTS and is_equal_approx(_circle_radius, radius) \
			and _circle_center.is_equal_approx(centre):
		return _circle
	_circle = PackedVector2Array()
	for i in CIRCLE_SEGMENTS:
		var angle := TAU * float(i) / float(CIRCLE_SEGMENTS)
		_circle.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	_circle_radius = radius
	_circle_center = centre
	return _circle


func _draw_view_cone(centre: Vector2, radius: float) -> void:
	var fov := deg_to_rad(_player.view_camera.fov)
	var reach := radius * VIEW_CONE_RADIUS
	var points := PackedVector2Array([centre])
	for i in 9:
		var angle := -fov * 0.5 + fov * float(i) / 8.0
		points.append(centre + Vector2(sin(angle), -cos(angle)) * reach)
	points.append(centre)
	draw_colored_polygon(points, Color(PLAYER_COLOR, VIEW_CONE_ALPHA))


func _draw_objectives() -> void:
	var point := _director.capture_point
	if point != null and not point.is_captured():
		var color := CapturePoint.COLOR_LOCKED if point.locked else CapturePoint.COLOR_OPEN
		_draw_objective(point.global_position, color, point.locked)
	var pedestal := _director.buff_pedestal
	if is_instance_valid(pedestal):
		_draw_objective(pedestal.global_position, CapturePoint.COLOR_CAPTURED, false, PEDESTAL_RADIUS)
	var boss := _director.boss
	if is_instance_valid(boss) and not boss.health.is_dead():
		_draw_boss(boss.global_position)


## In range: filled dot, or a hollow ring while the building is locked.
## Out of range: a small triangle on the rim pointing that way.
func _draw_objective(world: Vector3, color: Color, hollow: bool, radius := MARKER_RADIUS) -> void:
	if _flat_distance(world) > RANGE_METERS:
		_draw_rim_arrow(world, color)
		return
	var at := to_map(world)
	if hollow:
		draw_arc(at, radius, 0.0, TAU, 20, color, OUTLINE_WIDTH + 0.6, true)
	else:
		draw_circle(at, radius + 1.0, Color(0.0, 0.0, 0.0, 0.5))
		draw_circle(at, radius, color)


func _draw_boss(world: Vector3) -> void:
	if _flat_distance(world) > RANGE_METERS:
		_draw_rim_arrow(world, BOSS_COLOR)
		return
	var at := to_map(world)
	var diamond := PackedVector2Array([at + Vector2(0.0, -BOSS_RADIUS), at + Vector2(BOSS_RADIUS, 0.0),
		at + Vector2(0.0, BOSS_RADIUS), at + Vector2(-BOSS_RADIUS, 0.0)])
	draw_colored_polygon(diamond, BOSS_COLOR)
	var outline := diamond.duplicate()
	outline.append(diamond[0])
	draw_polyline(outline, Color(1.0, 0.44, 0.28, 0.9), 1.6, true)


func _draw_rim_arrow(world: Vector3, color: Color) -> void:
	var centre := size * 0.5
	var at := to_map(world)
	var direction := (at - centre).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var base := centre + direction * (minf(size.x, size.y) * 0.5 - RIM_WIDTH - 12.0)
	var tip := base + direction * 9.0
	var side := direction.orthogonal() * 4.5
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), color)


func _draw_enemies(centre: Vector2) -> void:
	var limit := _map_scale() * RANGE_METERS
	for enemy in _director.living_enemies():
		if not is_instance_valid(enemy) or enemy.is_boss:
			continue
		if _flat_distance(enemy.global_position) > RANGE_METERS:
			continue
		var at := to_map(enemy.global_position)
		if at.distance_to(centre) > limit:
			continue
		var alpha := ENEMY_FLEE_ALPHA if enemy.state == Enemy.State.FLEE else 1.0
		draw_circle(at, ENEMY_RADIUS + 1.2, Color(0.0, 0.0, 0.0, 0.5 * alpha))
		draw_circle(at, ENEMY_RADIUS, Color(ENEMY_COLOR, alpha))


func _draw_pulses(centre: Vector2, radius: float) -> void:
	for pulse in _pulses:
		var t := float(pulse.age) / PULSE_TIME
		var color := Color(PULSE_COLOR, (1.0 - t) * 0.85)
		var world: Vector3 = pulse.position
		if _flat_distance(world) <= RANGE_METERS:
			draw_arc(to_map(world), 4.0 + 12.0 * t, 0.0, TAU, 24, color, 2.0, true)
		else:
			var direction := (to_map(world) - centre).normalized()
			if direction.is_zero_approx():
				direction = Vector2.UP
			var rim := centre + direction * (radius - RIM_WIDTH - 6.0)
			draw_circle(rim, 3.0 + 3.0 * (1.0 - t), color)


func _draw_player(centre: Vector2) -> void:
	var chevron := PackedVector2Array([centre + Vector2(0.0, -9.0), centre + Vector2(6.0, 6.0),
		centre + Vector2(0.0, 3.0), centre + Vector2(-6.0, 6.0)])
	var outline := chevron.duplicate()
	outline.append(chevron[0])
	draw_polyline(outline, Color(0.0, 0.0, 0.0, 0.8), 2.0, true)
	draw_colored_polygon(chevron, PLAYER_COLOR)
