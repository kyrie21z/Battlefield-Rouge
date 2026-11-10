class_name FixtureBot
extends Node
## Plays a run with no human, for the AC-07 check (docs/adr/0005): fights the
## nearest enemy, walks to the capture point, swings the blade on the beat and
## takes the first buff offered. On a small zone's blade phase it stays at the
## building and only shoots enemies that reach it, so the reinforcement waves
## cannot pull it off the objective. After the flag it walks to the buff
## pedestal and presses interact; it does not chase enemies that are already
## retreating. It moves, aims down the sights and strikes through the real
## input actions. It turns with Player.aim_at(), the way a mouse would, and
## shoots with Weapon.try_fire(): the `fire` action only works while the mouse
## is captured, and a headless run cannot capture it.
## It decides from what is in the scene and from its own tick count and nothing
## else (no clock, no random numbers), so the same fixture gives the same bot run.
## It sits on the root, so the scene changes between zones do not free it.

## Farthest shot it will take, metres.
const FIRE_RANGE := 40.0
## It stops walking at this distance when it can see the enemy, and sidesteps.
const STAND_OFF := 12.0
const STRAFE_TICKS := 40
## It looks down the sights beyond this distance, for the tighter spread.
const AIM_FROM := 8.0
## Blade swing duration in physics ticks, plus a tick of margin.
const SWING_GAP_TICKS := 23
## Seconds from a hit moment within which it presses the blade. One tick is
## 1/60 s, so a window of this half-width catches one tick per beat.
const BEAT_TOLERANCE := 0.009
## North of a small-zone building, still inside the capture Area, so the
## bot can see reinforcements coming from -z without standing in the mesh.
const POINT_STAND_OFFSET := Vector3(0.0, 0.0, -2.2)
## While walking to the building, fight only an enemy this close. Farther ones
## are left for the hold at the building, or they never pull the bot backwards.
const SELF_DEFENCE_RANGE := 12.0
const MOVE_ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right"]

## Physics ticks since the zone being played appeared. Counted from the zone,
## not from the start of the run: a restart waits a frame longer than a first
## load, and a count from the run would then be a tick out of step.
var _ticks := 0
var _last_swing_tick := -1000
var _blade_down := false
var _interact_down := false
var _zone_id := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Before the player and the weapon, so what it presses is read on this tick.
	process_physics_priority = -1000


## Let go of everything pressed, between runs.
func reset() -> void:
	_zone_id = 0
	_release_all()


func _physics_process(_delta: float) -> void:
	if _blade_down:
		Input.action_release(&"melee")
		_blade_down = false
	if _interact_down:
		Input.action_release(&"interact")
		_interact_down = false
	var director := get_tree().get_first_node_in_group("zone_director") as ZoneDirector
	var player := get_tree().get_first_node_in_group("player") as Player
	if director == null or player == null:
		return
	if director.get_instance_id() != _zone_id:
		_zone_id = director.get_instance_id()
		_ticks = 0
		_last_swing_tick = -1000
	_ticks += 1
	if get_tree().paused:
		_release_all()
		_take_first_buff(director)
		return
	if player.health.is_dead():
		_release_all()
		return
	# Small zones hold the building under reinforcements, then walk to the pedestal.
	# The boss zone ignores the ring of minions: shoot the boss, then one blade strike.
	if director.is_boss_zone:
		var boss := director.boss
		if boss != null and is_instance_valid(boss) and not boss.health.is_dead():
			_fight(player, boss)
			return
		# The core is open. Clear whoever is still shooting, then walk over for
		# the one blade strike. Chasing the ring before the boss is down never happens.
		if director.phase == ZoneDirector.Phase.CLOCK_POINT:
			var threat := _nearest_enemy(player)
			if threat != null:
				_fight(player, threat)
				return
			_blade(player, director.capture_point)
			return
		_release_all()
		return
	if director.phase == ZoneDirector.Phase.FLAG_PLANTED:
		_claim_pedestal(player, director)
		return
	if director.phase == ZoneDirector.Phase.CLOCK_POINT:
		_hold_point(player, director.capture_point)
		return
	var target := _nearest_enemy(player)
	if target != null:
		_fight(player, target)
	elif director.phase == ZoneDirector.Phase.CLOCK_POINT:
		_blade(player, director.capture_point)
	else:
		_release_all()


func _fight(player: Player, enemy: Enemy) -> void:
	var head := enemy.global_position + Vector3.UP * enemy.eye_height
	player.aim_at(head)
	var seen := _line_clear(player, head)
	var distance := player.global_position.distance_to(enemy.global_position)
	if seen and distance <= FIRE_RANGE:
		player.weapon.try_fire()
	_set_action(&"aim", 1.0 if seen and distance > AIM_FROM else 0.0)
	if seen and distance <= STAND_OFF:
		var side := 1.0 if (_ticks / STRAFE_TICKS) % 2 == 0 else -1.0
		_move(player, player.global_basis.x * side)
	else:
		_walk_toward(player, enemy.global_position)


## Stay on the building. Shoot whoever is in range without walking off, and
## swing on the beat. On the way in, only a very close enemy is worth a detour.
func _hold_point(player: Player, point: CapturePoint) -> void:
	if not point.player_in_reach:
		var close := _nearest_enemy(player, SELF_DEFENCE_RANGE)
		if close != null:
			_fight(player, close)
			return
		_set_action(&"aim", 0.0)
		_walk_toward(player, point.global_position + POINT_STAND_OFFSET)
		return
	_move(player, Vector3.ZERO)
	player.aim_at(point.global_position + Vector3.UP)
	var on_beat := absf(CapturePoint.beat_offset(point.beat_time() + player.melee.scaled_time(player.melee.current().windup + player.melee.current().active * MeleeWeapon.STRIKE_AT))) <= BEAT_TOLERANCE
	if on_beat and _ticks - _last_swing_tick >= SWING_GAP_TICKS:
		Input.action_press(&"melee")
		_blade_down = true
		_last_swing_tick = _ticks
		return
	if player.melee.is_swinging():
		return
	var threat := _nearest_enemy(player, FIRE_RANGE)
	if threat == null:
		_set_action(&"aim", 0.0)
		return
	var head := threat.global_position + Vector3.UP * threat.eye_height
	player.aim_at(head)
	var distance := player.global_position.distance_to(threat.global_position)
	if _line_clear(player, head) and distance <= FIRE_RANGE:
		player.weapon.try_fire()
	_set_action(&"aim", 1.0 if distance > AIM_FROM else 0.0)


func _claim_pedestal(player: Player, director: ZoneDirector) -> void:
	var pedestal := director.buff_pedestal
	if pedestal == null:
		_release_all()
		return
	_set_action(&"aim", 0.0)
	if not pedestal.in_range(player):
		_walk_toward(player, pedestal.global_position)
		return
	_move(player, Vector3.ZERO)
	Input.action_press(&"interact")
	_interact_down = true


func _blade(player: Player, point: CapturePoint) -> void:
	_set_action(&"aim", 0.0)
	if not point.player_in_reach:
		_walk_toward(player, point.global_position)
		return
	_move(player, Vector3.ZERO)
	player.aim_at(point.global_position + Vector3.UP)
	var on_beat := absf(CapturePoint.beat_offset(point.beat_time() + player.melee.scaled_time(player.melee.current().windup + player.melee.current().active * MeleeWeapon.STRIKE_AT))) <= BEAT_TOLERANCE
	if on_beat and _ticks - _last_swing_tick >= SWING_GAP_TICKS:
		Input.action_press(&"melee")
		_blade_down = true
		_last_swing_tick = _ticks


func _take_first_buff(director: ZoneDirector) -> void:
	for child in director.get_children():
		if child.has_signal("chosen"):
			var choices := child.get_node("Center/Box/Choices")
			if choices.get_child_count() > 0:
				(choices.get_child(0) as Button).pressed.emit()
			return


## The nearest enemy that is still fighting. Retreating and dead enemies are
## ignored, so the bot does not chase the shockwave off the pedestal.
func _nearest_enemy(player: Player, max_distance: float = INF) -> Enemy:
	var best: Enemy
	var best_distance := max_distance * max_distance
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy.state == Enemy.State.DEAD or enemy.state == Enemy.State.FLEE:
			continue
		var distance := player.global_position.distance_squared_to(enemy.global_position)
		if distance > max_distance * max_distance:
			continue
		# Strictly closer, so an exact tie keeps the earlier enemy. The boss
		# ring is symmetric; replacing ties would change FX-002.
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## Whether nothing of the level is between the player's eyes and `point`.
func _line_clear(player: Player, point: Vector3) -> bool:
	var eye := player.get_node("Head/Camera3D") as Camera3D
	var query := PhysicsRayQueryParameters3D.create(eye.global_position, point, CollisionLayers.WORLD)
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _walk_toward(player: Player, goal: Vector3) -> void:
	var path := NavigationServer3D.map_get_path(player.get_world_3d().navigation_map,
		player.global_position, goal, true)
	_move(player, (path[1] if path.size() > 1 else goal) - player.global_position)


## Presses the move actions that take the player along `world_direction`.
func _move(player: Player, world_direction: Vector3) -> void:
	var flat := Vector3(world_direction.x, 0.0, world_direction.z)
	var local := player.global_basis.inverse() * flat.normalized() if flat.length() > 0.001 else Vector3.ZERO
	_set_action(&"move_right", maxf(local.x, 0.0))
	_set_action(&"move_left", maxf(-local.x, 0.0))
	_set_action(&"move_back", maxf(local.z, 0.0))
	_set_action(&"move_forward", maxf(-local.z, 0.0))


func _release_all() -> void:
	Input.action_release(&"melee")
	_blade_down = false
	for action in MOVE_ACTIONS:
		_set_action(action, 0.0)
	_set_action(&"aim", 0.0)
	_set_action(&"interact", 0.0)


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
