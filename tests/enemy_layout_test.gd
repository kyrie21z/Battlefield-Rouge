extends Node
## Headless check that the first wave is spread over the whole battlefield
## (issue #42). Run from the project root:
##   godot --headless --path . res://tests/enemy_layout_test.tscn
## Prints one line per check. Exits 1 if a check failed or the run stopped
## before the last check, so it cannot pass by accident.
##
## The positions are fixed in tools/gen_zones.py; this test is the contract that
## keeps a regenerated map from quietly putting the whole wave at the back again:
##   * the guard count and the front / middle / point split;
##   * every enemy at least 15 m from the player's spawn;
##   * no idle small guard can see the spawn: outside its 120 degree view cone, or the
##     WORLD ray from its eye is blocked;
##   * every enemy on the baked navigation mesh, reachable, with a clear capsule;
##   * no two enemies closer than 3 m, the Boss included;
##   * every guard beside cover, and on the boss map exactly two escorts 2-6 m
##     from the Boss with the remaining opening guards nearer the player.

const MAPS := [
	{"path": "res://maps/zone_1.tscn", "zone": 0, "guards": 5, "bands": [1, 1, 3]},
	{"path": "res://maps/zone_2.tscn", "zone": 1, "guards": 9, "bands": [2, 2, 5]},
	# The compact 50 m arena restores front/middle/escort progression while
	# the original monumental 92 m shell remains scenery outside the battlefield.
	{"path": "res://maps/boss.tscn", "zone": 2, "guards": 9, "bands": [2, 5, 2], "boss": true},
]
const SPAWN_CLEARANCE := 15.0
const ENEMY_SPACING := 3.0
const NAVMESH_TOLERANCE := 0.5
const COVER_DISTANCE := 3.5
const ESCORT_MIN := 2.0
const ESCORT_MAX := 6.0
## The capture point's blade reach, and the flanks of the approach.
const HAMMER_REACH := 3.2
const BAND_NAMES := ["front", "middle", "point"]

var _checks := 0
var _failures := 0
var _finished := false
var _elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d checks, %d failed%s)" % ["ALL PASSED" if ok else "FAIL", _checks,
		_failures, "" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 60.0 and not _finished:
		push_error("enemy layout test timed out")
		get_tree().quit(1)


func _run() -> void:
	for spec: Dictionary in MAPS:
		await _check_map(spec)
	_finished = true


func _check_map(spec: Dictionary) -> void:
	var file: String = (spec.path as String).get_file()
	var scene := await _open(spec)
	var player := scene.get_node("Player") as Player
	var point := scene.get_node("CapturePoint") as CapturePoint
	var enemies := _enemies(scene)
	var boss := scene.get_node_or_null("Boss") as Enemy
	var small: Array[Enemy] = []
	for enemy in enemies:
		if enemy != boss:
			small.append(enemy)
	var spawn := player.global_position
	print("== %s: %d enemies, spawn %s, point %s" % [file, enemies.size(),
		_vec(spawn), _vec(point.global_position)])

	var expected_total: int = spec.guards + (1 if spec.get("boss", false) else 0)
	_check("%s keeps its %d enemies (%d small%s)" % [file, expected_total, spec.guards,
		" + boss" if spec.get("boss", false) else ""],
		enemies.size() == expected_total and small.size() == spec.guards)

	var counts := [0, 0, 0]
	for enemy in small:
		counts[_band_of(enemy.global_position.z, spawn.z, point.global_position.z)] += 1
	for i in BAND_NAMES.size():
		_check("%s has %d guards in the %s third (%d)" % [file, spec.bands[i], BAND_NAMES[i], counts[i]],
			counts[i] == spec.bands[i])

	print("== %s: small guards leave the spawn clear" % file)
	var too_close: Array[String] = []
	var nearest_spawn := INF
	for enemy in enemies:
		var gap := _flat(enemy.global_position, spawn)
		nearest_spawn = minf(nearest_spawn, gap)
		if gap < SPAWN_CLEARANCE:
			too_close.append("%s %.2f m" % [enemy.name, gap])
	for label in too_close:
		print("     too close to the spawn: " + label)
	_check("%s keeps every enemy at least %.0f m from the spawn (nearest %.2f m)" % [
		file, SPAWN_CLEARANCE, nearest_spawn], too_close.is_empty())

	var seen: Array[String] = []
	for enemy in enemies:
		# The arena deliberately presents its Boss as a visible distant threat.
		# His guards still obey the same safe authored-spawn sight rule.
		if enemy == boss:
			continue
		if _sees_spawn(enemy, spawn):
			seen.append(enemy.name)
	for label in seen:
		print("     sees the spawn: " + label)
	_check("%s puts the spawn outside every idle small guard's sight" % file, seen.is_empty())

	print("== %s: the enemies stand and fight on the map" % file)
	var off_mesh: Array[String] = []
	var worst_mesh := 0.0
	for enemy in enemies:
		var gap := _navmesh_gap(enemy)
		worst_mesh = maxf(worst_mesh, gap)
		if gap > NAVMESH_TOLERANCE:
			off_mesh.append("%s %.2f m" % [enemy.name, gap])
	for label in off_mesh:
		print("     off the navmesh: " + label)
	_check("%s puts every enemy on the baked navmesh (worst %.2f m)" % [file, worst_mesh],
		off_mesh.is_empty())
	var unreachable: Array[String] = []
	for enemy in enemies:
		if not _navmesh_reachable(enemy, spawn):
			unreachable.append(enemy.name)
	_check("%s connects every guard to the entry navigation surface (%s)" % [file, unreachable],
		unreachable.is_empty())
	var region := (scene.get_node("ZoneDirector") as ZoneDirector).navigation_region
	var vertices := region.navigation_mesh.get_vertices()
	var compact := not vertices.is_empty()
	for vertex in vertices:
		var world := region.to_global(vertex)
		if boss!=null:
			compact = compact and Vector2(world.x,world.z).length()<=26.0
		else:
			compact = compact and absf(world.x)<=21.0 and absf(world.z)<=25.0
	_check("%s bakes only the compact combat floor, not monumental scenery" % file,compact)
	for destination in [Vector3(0,0,60),Vector3(0,0,90),Vector3(-50,0,5),Vector3(50,0,5)]:
		var closest := NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map,destination)
		_check("%s keeps distant architectural scenery outside navigation %s" % [file,destination],
			closest.distance_to(destination)>10.0)

	var stuck: Array[String] = []
	for enemy in enemies:
		if _inside_world(enemy):
			stuck.append(enemy.name)
	for label in stuck:
		print("     inside geometry: " + label)
	_check("%s starts no enemy inside geometry" % file, stuck.is_empty())
	var capsules: Array[String] = []
	for enemy in enemies:
		if _capsule_inside_world(enemy):
			capsules.append(enemy.name)
	_check("%s leaves every actual movement capsule clear of WORLD (%s)" % [file, capsules],
		capsules.is_empty())

	var closest_pair := INF
	var tight: Array[String] = []
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			var gap := _flat(enemies[i].global_position, enemies[j].global_position)
			closest_pair = minf(closest_pair, gap)
			if gap < ENEMY_SPACING:
				tight.append("%s/%s %.2f m" % [enemies[i].name, enemies[j].name, gap])
	for label in tight:
		print("     too close together: " + label)
	_check("%s keeps every pair %.0f m apart (closest %.2f m)" % [file, ENEMY_SPACING, closest_pair],
		tight.is_empty())

	var escorts: Array[Enemy] = []
	if boss != null:
		print("== %s: the boss formation" % file)
		for enemy in small:
			var gap := _flat(enemy.global_position, boss.global_position)
			if gap >= ESCORT_MIN and gap <= ESCORT_MAX:
				escorts.append(enemy)
		_check("%s gives the boss exactly two escorts at %.0f-%.0f m" % [
			file, ESCORT_MIN, ESCORT_MAX], escorts.size() == 2)
		var boss_spawn_gap := _flat(boss.global_position, spawn)
		var spread: Array[Enemy] = []
		for enemy in small:
			if enemy not in escorts:
				spread.append(enemy)
		_check("%s puts the other %d small enemies nearer the player than the boss" % [
			file, spec.guards - 2],
			spread.size() == spec.guards - 2
			and spread.all(func(e: Enemy) -> bool: return _flat(e.global_position, spawn) < boss_spawn_gap))
		var behind := spread.filter(func(e: Enemy) -> bool: return e.global_position.z <= point.global_position.z)
		_check("%s keeps the spread guards in front of the core" % file, behind.is_empty())
		_check("%s stands the boss in front of the core" % file,
			boss.global_position.z > point.global_position.z)

	print("== %s: each guard has cover" % file)
	var bare: Array[String] = []
	for enemy in small:
		if enemy in escorts:
			continue
		var cover := _nearest_cover(scene, enemy)
		if cover > COVER_DISTANCE:
			bare.append("%s %.2f m" % [enemy.name, cover])
	for label in bare:
		print("     far from any cover: " + label)
	_check("%s stands every guard within %.1f m of cover (escorts excepted)" % [file, COVER_DISTANCE],
		bare.is_empty())

	await _close(scene)


## Loads one map with its guards frozen before the first physics tick, so the
## positions measured are the ones written in the scene.
func _open(spec: Dictionary) -> Node:
	get_tree().paused = false
	RunState.clear_fixture()
	RunState.zone_index = spec.zone
	RunState.buffs.clear()
	RunState.selection_history.clear()
	RunState.run_seed = 424242
	BuffPool.reset(RunState.run_seed)
	var scene := (load(spec.path) as PackedScene).instantiate()
	add_child(scene)
	for enemy in _enemies(scene):
		enemy.set_physics_process(false)
		enemy.set_process(false)
	get_tree().paused = false
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	if is_instance_valid(director.selection):
		director.selection.free()
		director.selection = null
		director.selection_context = ""
	for i in 8:
		await get_tree().physics_frame
	return scene


func _close(scene: Node) -> void:
	get_tree().paused = false
	scene.free()
	await get_tree().process_frame


func _enemies(scene: Node) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if scene.is_ancestor_of(node):
			found.append(node as Enemy)
	return found


## 0 at the spawn, 1 at the capture point.
func _band_of(z: float, spawn_z: float, point_z: float) -> int:
	var t := inverse_lerp(spawn_z, point_z, z)
	if t < 1.0 / 3.0:
		return 0
	if t < 2.0 / 3.0:
		return 1
	return 2


## Mirrors Enemy._update_sight: range, the idle view cone, then a WORLD ray.
func _sees_spawn(enemy: Enemy, spawn: Vector3) -> bool:
	var eye := enemy.global_position + Vector3.UP * enemy.eye_height
	var target := spawn + Vector3.UP * Enemy.AIM_HEIGHT
	var to_target := target - eye
	if to_target.length() > enemy.sight_range:
		return false
	var forward := -enemy.global_basis.z
	if forward.angle_to(Vector3(to_target.x, 0.0, to_target.z)) > deg_to_rad(enemy.sight_fov_deg * 0.5):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, CollisionLayers.WORLD)
	return enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Horizontal distance. The baked surface sits at y = cell_height (0.5 m) above
## the floor the enemy stands on, a uniform offset; measuring it in 3D would
## only measure that height, not whether the guard is on walkable ground.
func _navmesh_gap(enemy: Enemy) -> float:
	var map := enemy.get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, enemy.global_position)
	return Vector2(closest.x - enemy.global_position.x, closest.z - enemy.global_position.z).length()


func _navmesh_reachable(enemy: Enemy, spawn: Vector3) -> bool:
	var map := enemy.get_world_3d().navigation_map
	return _navmesh_connects(map, spawn, enemy.global_position)


func _navmesh_connects(map: RID, from: Vector3, to: Vector3) -> bool:
	var start := NavigationServer3D.map_get_closest_point(map, from)
	var goal := NavigationServer3D.map_get_closest_point(map, to)
	var path := NavigationServer3D.map_get_path(map, start, goal, true)
	return goal.distance_to(to) < 2.2 and path.size() > 1 and path[-1].distance_to(goal) < 0.2


func _capsule_inside_world(enemy: Enemy) -> bool:
	var capsule := enemy.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	# Ignore intended floor contact; any obstacle at the real capsule's sides
	# or head is still included, including cover taller than the middle sphere.
	query.transform = capsule.global_transform.translated(Vector3.UP * 0.02)
	query.collision_mask = CollisionLayers.WORLD
	query.collide_with_areas = false
	return not enemy.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## A 0.45 m sphere around the body's middle; the enemy's own capsule is on the
## ENEMIES layer, so only level geometry can answer this query.
func _inside_world(enemy: Enemy) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), enemy.global_position + Vector3.UP * 0.9)
	query.collision_mask = CollisionLayers.WORLD
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not enemy.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _nearest_cover(scene: Node, enemy: Enemy) -> float:
	var best := INF
	for node in get_tree().get_nodes_in_group("cover_point"):
		if scene.is_ancestor_of(node):
			# A gallery's marker cannot protect a guard on the lower floor.
			if absf((node as Node3D).global_position.y - enemy.global_position.y) > 0.7:
				continue
			best = minf(best, _flat((node as Node3D).global_position, enemy.global_position))
	return best


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _vec(v: Vector3) -> String:
	return "%.2f,%.2f" % [v.x, v.z]


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
