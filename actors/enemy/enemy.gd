class_name Enemy
extends CharacterBody3D
## Soldier AI, simplified from origin/sheji/characters/bots/bot.gd.
## Idles until it sees or hears the player or is shot, then looks for a firing
## position with a clear shot, fights in short bursts and falls back to cover
## when hurt. The zone director calls setup() with the target, cover points and
## the zone's firing position board; the enemy never looks them up.

## SEEK is after FLEE so the older state numbers stay put.
enum State { IDLE, CHASE, ENGAGE, COVER, DEAD, FLEE, SEEK }

const AIM_HEIGHT := 1.3

## The zone director reports it as the zone's boss, and the HUD shows its health bar.
@export var is_boss := false

@export_category("Perception")
@export var sight_range := 45.0
## Where it looks and shoots from, above its feet. A taller body raises this.
@export var eye_height := 1.55
@export var sight_fov_deg := 120.0
@export var hearing_range := 35.0

@export_category("Combat")
@export var engage_range := 25.0
@export var reaction_time := 0.7
@export var burst_size := 3
@export var burst_interval := 0.14
@export var burst_pause := 1.4
## Cone half-angle of each shot. At 20 m, 3.0 deg spreads the shots over a
## circle about 2 m across.
@export var accuracy_deg := 3.0
## Enemy bullets are slow, visible projectiles so the player can dodge them.
## Shots aim at where the player is now, with no lead.
@export var projectile_speed := 22.0
## Spread multiplier when the target moves faster than 3 m/s.
@export var moving_target_penalty := 1.6
@export var damage_min := 6.0
@export var damage_max := 9.0
## Closer than this the enemy backs off to a firing position instead of firing.
@export var min_engage_distance := 6.0

@export_category("Firing position")
## Minimum seconds between two position searches, so a failed search cannot
## run every frame.
@export var seek_interval := 0.5
## How long the target may stay out of sight before the enemy repositions.
@export var seek_lost_sight_delay := 0.5
@export var seek_min_player_distance := 8.0
@export var seek_max_player_distance := 20.0
## Ring samples around the player: this many fixed directions, at these radii.
@export var seek_ring_directions := 12
@export var seek_ring_radii := PackedFloat32Array([8.0, 20.0])
## Upper bound on line-of-sight rays per search.
@export var seek_max_rays := 32
## A candidate farther than this from the navigation mesh is not reachable.
@export var seek_nav_snap := 1.5
## Close enough to the picked spot to start fighting from it.
@export var seek_arrive_distance := 0.6
## Walking to a spot for this long without arriving falls back to chasing.
@export var seek_timeout := 8.0
## Another enemy's reserved spot this close counts as taken.
@export var seek_spacing := 3.5
## Score discount for standing next to cover. Lower score wins.
@export var seek_cover_bonus := 6.0
## Cover this close to a candidate counts as cover for it.
@export var seek_cover_near := 2.0

@export_category("Movement")
@export var run_speed := 3.6
@export var strafe_speed := 1.8
@export var turn_speed := 8.0
@export var gravity := 18.0

@export_category("Cover")
@export var cover_search_radius := 18.0
## Cover closer than this to the player is ignored.
@export var cover_min_player_distance := 6.0
@export var cover_time := 2.4
@export var cover_cooldown := 6.0
@export_range(0.0, 1.0) var cover_chance := 0.6

@export_category("Model")
## Which of the model's hand-held meshes to show.
@export var held_weapon := "AK"
## Replaces the default character model when set. The kit's characters share
## one skeleton and one set of animations, so the hitboxes on its bones carry over.
@export var model_scene: PackedScene

## Read by Health to ignore friendly fire.
var team := 1
var state := State.IDLE
var target: CharacterBody3D
var cover_points: Array[CoverPoint] = []
## Spot this enemy picked and reserved, Vector3.INF when it has none.
var firing_position := Vector3.INF

var _last_known := Vector3.ZERO
var _sees_target := false
var _sight_timer := 0.0
var _react_left := 0.0
var _shots_left := 0
var _shot_timer := 0.0
var _cover: CoverPoint
var _cover_left := 0.0
var _cover_ready_at := 0.0
var _strafe_dir := 1.0
var _strafe_left := 0.0
var _hitbox_rids: Array[RID] = []
var _gunshot: AudioStreamWAV
var _firing_board: FiringPositionBoard
var _seek_center := Vector3.ZERO
var _seek_goal := Vector3.ZERO
var _seek_elapsed := 0.0
var _seek_retry := 0.0
var _sight_lost := 0.0
## Knockback from a melee hit. Overrides the AI's own steering while it lasts.
var _impact_velocity := Vector3.ZERO
var _impact_left := 0.0
## Rear spawn the shockwave sent this enemy toward. Arrival removes it
## without a kill. FLEE is after DEAD so older state numbers stay put.
var _flee_goal := Vector3.ZERO
var _flee_left := 0.0
var _departed := false

## Close enough to a rear spawn to count as having left the zone.
const FLEE_ARRIVE := 1.25

## Removed from the scene without Events.enemy_killed. The zone director listens.
signal departed

## How fast a shove bleeds off, in m/s².
const IMPACT_DECAY := 22.0
## Enemy fire uses the softened player rifle sound, quieter than the player's own.
const ENEMY_GUNSHOT_DB := -5.0

@onready var health: Health = $Health
@onready var _agent: NavigationAgent3D = $Agent
@onready var _anim: AnimationPlayer = $Model/AnimationPlayer
@onready var _audio: AudioStreamPlayer3D = $GunAudio


func _ready() -> void:
	if model_scene != null:
		_swap_model()
	for anim in ["Idle", "Run_Gun", "Walk_Shoot", "Idle_Shoot", "Duck"]:
		_anim.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	for mesh in $Model/CharacterArmature/Skeleton3D/Index1_R.get_children():
		mesh.visible = mesh.name == held_weapon
	_hitbox_rids.append(get_rid())
	for hitbox in find_children("*", "Hitbox", true, false):
		_hitbox_rids.append((hitbox as Hitbox).get_rid())
	_gunshot = ProceduralAudio.generate("gun_rifle")
	_audio.stream = _gunshot
	_audio.volume_db = ENEMY_GUNSHOT_DB
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	Events.gunshot.connect(_on_gunshot)
	Events.clock_struck.connect(_on_clock_struck)
	_anim.play("Idle")


func _swap_model() -> void:
	var old: Node3D = $Model
	old.name = "OldModel"
	var model: Node3D = model_scene.instantiate()
	model.name = "Model"
	model.transform = old.transform
	add_child(model)
	move_child(model, old.get_index())
	var skeleton := model.get_node("CharacterArmature/Skeleton3D")
	for child in old.get_node("CharacterArmature/Skeleton3D").get_children():
		if child is BoneAttachment3D:
			child.reparent(skeleton, false)
	old.free()
	_anim = model.get_node("AnimationPlayer")


func setup(p_target: CharacterBody3D, p_cover_points: Array[CoverPoint],
		p_firing_board: FiringPositionBoard = null) -> void:
	target = p_target
	cover_points = p_cover_points
	_firing_board = p_firing_board


## A reinforcement that spawns in already knows where the player is (issue
## #40): skip the idle watch and look for a firing position at once.
func begin_hunt() -> void:
	if state == State.DEAD or state == State.FLEE or target == null:
		return
	_last_known = target.global_position
	_start_seek(_last_known)


## Stop attacking and run to `goal` along the navmesh. Reaching it, or running
## out of `timeout`, removes the body. Neither the shockwave nor the removal
## deals damage or emits Events.enemy_killed. A later bullet can still kill.
func begin_retreat(goal: Vector3, timeout: float) -> void:
	if state == State.DEAD or state == State.FLEE:
		return
	_leave_cover()
	_release_firing_position()
	_impact_left = 0.0
	_impact_velocity = Vector3.ZERO
	_shots_left = 0
	_flee_goal = goal
	_flee_left = timeout
	state = State.FLEE


## Shoved by a melee hit. While the stagger lasts the body keeps the shoved
## velocity instead of its own, so a heavy swing moves it rather than being
## walked off.
func apply_impact(direction: Vector3, force: float, stagger: float) -> void:
	if state == State.DEAD or state == State.FLEE:
		return
	_impact_velocity = Vector3(direction.x, 0.0, direction.z).normalized() * force
	_impact_left = maxf(_impact_left, stagger)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if state == State.FLEE:
		_process_flee(delta)
		if _departed:
			return
		move_and_slide()
		_update_animation()
		return
	if _impact_left > 0.0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO, IMPACT_DECAY * delta)
		move_and_slide()
		return
	if target == null:
		move_and_slide()
		return

	_seek_retry = maxf(_seek_retry - delta, 0.0)
	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = 0.1
		_update_sight()

	match state:
		State.IDLE:
			_stop()
			if _sees_target:
				_alert(_target_point())
		State.CHASE:
			_move_to(_last_known, run_speed)
			if _sees_target and _distance_to_target() <= engage_range:
				_enter_engage()
			elif _agent.is_navigation_finished() and not _sees_target and _seek_retry <= 0.0:
				_start_seek(_last_known)
			_face(_agent.get_next_path_position() - global_position, delta)
		State.SEEK:
			_process_seek(delta)
		State.ENGAGE:
			_process_engage(delta)
		State.COVER:
			_process_cover(delta)

	move_and_slide()
	_update_animation()


func _process_flee(delta: float) -> void:
	_flee_left -= delta
	var flat := Vector2(global_position.x - _flee_goal.x, global_position.z - _flee_goal.z).length()
	if flat <= FLEE_ARRIVE or _flee_left <= 0.0:
		_stop()
		_depart()
		return
	_move_to(_flee_goal, run_speed)
	_face(_agent.get_next_path_position() - global_position, delta)


func _depart() -> void:
	if _departed:
		return
	_departed = true
	departed.emit()
	queue_free()


func _process_seek(delta: float) -> void:
	_seek_elapsed += delta
	var flat := Vector2(global_position.x - _seek_goal.x, global_position.z - _seek_goal.z).length()
	if flat <= seek_arrive_distance:
		_stop()
		_face(_seek_center - global_position, delta)
		if _sees_target:
			_enter_engage()
			return
		_sight_lost += delta
		if _sight_lost >= seek_lost_sight_delay and _seek_retry <= 0.0:
			_start_seek(_last_known)
		return
	if _seek_elapsed >= seek_timeout:
		_alert(target.global_position)
		return
	_move_to(_seek_goal, run_speed)
	_face(_agent.get_next_path_position() - global_position, delta)


func _process_engage(delta: float) -> void:
	var sees := _sees_target
	if sees:
		_sight_lost = 0.0
	else:
		_sight_lost += delta
	var distance := _distance_to_target()
	if distance > engage_range * 1.2:
		_release_firing_position()
		state = State.CHASE
		return
	# A rifle should not be fired from arm's length: back off to a firing spot.
	if distance < min_engage_distance:
		_start_seek(_last_known)
		return
	if not sees and _sight_lost >= seek_lost_sight_delay:
		_start_seek(_last_known)
		return
	var aim := _target_point() if sees else _last_known + Vector3.UP * AIM_HEIGHT
	_face(aim - global_position, delta)

	# Short sidesteps between pauses, so the enemy is not a fixed target.
	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe_dir = [-1.0, 0.0, 1.0].pick_random()
		_strafe_left = randf_range(0.8, 1.6)
	var side := global_basis.x * _strafe_dir * strafe_speed
	velocity.x = side.x
	velocity.z = side.z

	_react_left -= delta
	if _react_left > 0.0 or not sees:
		return
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	if _shots_left <= 0:
		_shots_left = burst_size
	_fire_shot()
	_shots_left -= 1
	_shot_timer = burst_interval if _shots_left > 0 else burst_pause * randf_range(0.8, 1.3)


func _process_cover(delta: float) -> void:
	if global_position.distance_to(_cover.global_position) > 0.6:
		_move_to(_cover.global_position, run_speed)
		_face(_agent.get_next_path_position() - global_position, delta)
		return
	_stop()
	_face(target.global_position - global_position, delta)
	_cover_left -= delta
	if _cover_left <= 0.0:
		_leave_cover()
		if _sees_target:
			_enter_engage()
		else:
			_alert(_last_known)


func _update_sight() -> void:
	var to_target := _target_point() - _eye()
	_sees_target = false
	if to_target.length() > sight_range:
		return
	# Before the first alert the enemy only sees inside its view cone.
	if state == State.IDLE:
		var forward := -global_basis.z
		if forward.angle_to(Vector3(to_target.x, 0.0, to_target.z)) > deg_to_rad(sight_fov_deg * 0.5):
			return
	var query := PhysicsRayQueryParameters3D.create(_eye(), _target_point(), CollisionLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_sees_target = hit.is_empty()
	if _sees_target:
		_last_known = target.global_position


func _alert(position: Vector3) -> void:
	_last_known = position
	_react_left = reaction_time
	_release_firing_position()
	state = State.CHASE


func _enter_engage() -> void:
	state = State.ENGAGE
	_sight_lost = 0.0
	_react_left = maxf(_react_left, reaction_time * 0.5)


## Pick a reachable spot with a clear shot at `center` and reserve it.
## Returns false and falls back to chasing when no candidate passes.
func _start_seek(center: Vector3) -> bool:
	if state == State.DEAD or state == State.FLEE or target == null:
		return false
	_leave_cover()
	_release_firing_position()
	_seek_center = center
	_seek_goal = center
	_seek_elapsed = 0.0
	_sight_lost = 0.0
	_seek_retry = seek_interval
	if not _find_firing_position():
		_alert(target.global_position)
		return false
	state = State.SEEK
	return true


## Candidates: the zone's cover points, then a fixed-direction ring around the
## target. No random numbers, so the same battlefield picks the same spot.
func _find_firing_position() -> bool:
	var map := get_world_3d().navigation_map
	# Authored scenes and tests may alert an actor before the first server sync.
	# Retry through the existing CHASE/seek cadence once the map is available.
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var aim := _seek_center + Vector3.UP * AIM_HEIGHT
	var best := Vector3.INF
	var best_score := INF
	var rays := 0
	for candidate in _candidate_positions():
		if rays >= seek_max_rays:
			break
		var point := NavigationServer3D.map_get_closest_point(map, candidate)
		if point.distance_to(candidate) > seek_nav_snap:
			continue
		var player_gap := Vector2(point.x - _seek_center.x, point.z - _seek_center.z).length()
		if player_gap < seek_min_player_distance or player_gap > seek_max_player_distance:
			continue
		if _firing_board != null and _firing_board.is_taken(point, seek_spacing, self):
			continue
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * eye_height, aim, CollisionLayers.WORLD)
		rays += 1
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		var score := Vector2(point.x - global_position.x, point.z - global_position.z).length()
		if _cover_near(point):
			score -= seek_cover_bonus
		if score < best_score:
			best = point
			best_score = score
	if best == Vector3.INF:
		return false
	_seek_goal = best
	firing_position = best
	if _firing_board != null:
		_firing_board.claim(self, best)
	return true


func _candidate_positions() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for cover in cover_points:
		if is_instance_valid(cover):
			points.append(cover.global_position)
	var directions := maxi(seek_ring_directions, 1)
	for radius in seek_ring_radii:
		for index in directions:
			var angle := TAU * float(index) / float(directions)
			points.append(_seek_center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return points


func _cover_near(point: Vector3) -> bool:
	for cover in cover_points:
		if not is_instance_valid(cover):
			continue
		if Vector2(cover.global_position.x - point.x, cover.global_position.z - point.z).length() <= seek_cover_near:
			return true
	return false


func _release_firing_position() -> void:
	if _firing_board != null:
		_firing_board.release(self)
	firing_position = Vector3.INF


func _fire_shot() -> void:
	var origin := _eye()
	var direction := (_target_point() - origin).normalized()
	var spread := accuracy_deg
	if Vector2(target.velocity.x, target.velocity.z).length() > 3.0:
		spread *= moving_target_penalty
	direction = _random_in_cone(direction, deg_to_rad(spread))

	_audio.pitch_scale = randf_range(0.95, 1.05)
	_audio.play()
	Events.gunshot.emit(global_position)

	var projectile := Projectile.spawn(get_parent(), origin + direction * 0.6, direction, self,
		randf_range(damage_min, damage_max), projectile_speed, _hitbox_rids)
	projectile.max_distance = sight_range


func _try_take_cover() -> bool:
	var best: CoverPoint
	var best_distance := cover_search_radius
	for point in cover_points:
		if point.occupant != null and point.occupant != self:
			continue
		var distance := global_position.distance_to(point.global_position)
		if distance >= best_distance:
			continue
		if point.global_position.distance_to(target.global_position) < cover_min_player_distance:
			continue
		if not _is_hidden_at(point.global_position):
			continue
		best = point
		best_distance = distance
	if best == null:
		return false
	_release_firing_position()
	_cover = best
	_cover.occupant = self
	_cover_left = cover_time
	state = State.COVER
	return true


## Whether a crouching enemy at `point` is out of the target's sight.
func _is_hidden_at(point: Vector3) -> bool:
	var from := point + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, _target_point(), CollisionLayers.WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _leave_cover() -> void:
	if _cover != null and _cover.occupant == self:
		_cover.occupant = null
	_cover = null
	_cover_ready_at = SimClock.now() + cover_cooldown


func _on_damaged(_amount: float, _part: Hitbox.BodyPart, source: Node) -> void:
	if state == State.DEAD or state == State.FLEE:
		return
	if state == State.IDLE:
		_alert(source.global_position if source is Node3D else _target_point())
		return
	var cover_ready := SimClock.now() >= _cover_ready_at
	if state != State.COVER and cover_ready and randf() < cover_chance:
		_try_take_cover()


func _on_gunshot(position: Vector3) -> void:
	if state == State.IDLE and global_position.distance_to(position) <= hearing_range:
		_alert(position)


## Clock strikes at the capture point is a noise like a gunshot (issue #40).
func _on_clock_struck(position: Vector3) -> void:
	if state == State.IDLE and global_position.distance_to(position) <= hearing_range:
		_alert(position)


func _on_died(_source: Node) -> void:
	_leave_cover()
	_release_firing_position()
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	for hitbox in find_children("*", "Hitbox", true, false):
		(hitbox as Hitbox).collision_layer = 0
	_anim.play("Death")
	Events.enemy_killed.emit(self)


func _move_to(position: Vector3, speed: float) -> void:
	if _agent.target_position.distance_to(position) > 0.5:
		_agent.target_position = position
	if _agent.is_navigation_finished():
		_stop()
		return
	var direction := _agent.get_next_path_position() - global_position
	direction.y = 0.0
	direction = direction.normalized() * speed
	velocity.x = direction.x
	velocity.z = direction.z


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(turn_speed * delta, 1.0))


func _update_animation() -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	var anim := "Idle"
	match state:
		State.CHASE, State.SEEK:
			anim = "Run_Gun" if moving else "Idle"
		State.ENGAGE:
			anim = "Walk_Shoot" if moving else "Idle_Shoot"
		State.COVER:
			anim = "Run_Gun" if moving else "Duck"
		State.FLEE:
			anim = "Run_Gun" if moving else "Idle"
	if _anim.current_animation != anim:
		_anim.play(anim, 0.15)


func _eye() -> Vector3:
	return global_position + Vector3.UP * eye_height


func _target_point() -> Vector3:
	return target.global_position + Vector3.UP * AIM_HEIGHT


func _distance_to_target() -> float:
	return global_position.distance_to(target.global_position)


static func _random_in_cone(direction: Vector3, half_angle: float) -> Vector3:
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var tilted := direction.rotated(side, randf() * half_angle)
	return tilted.rotated(direction, randf() * TAU).normalized()
