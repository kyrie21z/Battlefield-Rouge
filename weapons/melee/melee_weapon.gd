class_name MeleeWeapon
extends Node3D
## A single mind blade: quick slash, projectile parry and rhythmic clock strike.
## Reads Stats; recoil, movement and presentation are applied by the owner.

## One swing has started. `step` counts up across swings, so tests and the HUD
## can tell a combo apart from the first hit.
signal swing_started(index: int, step: int)
## The swing is over and the viewmodel is out of the way again. The owner puts
## the gun back on screen when this fires.
signal swing_finished
## The active window closed: the blade has finished travelling through the arc
## and is at its furthest point. Proof shots and hit-stop style effects key off
## this rather than a timer, which drifts a frame or two behind the tween.
signal strike_finished
## A swing connected. Same contract as Weapon.hit_landed, so the HUD hitmarker
## works for melee too.
signal hit_landed(headshot: bool, killed: bool)
## Degrees of camera kick when a swing connects. `manual` is the share that stays.
signal recoil(pitch: float, yaw: float, manual: float)
## Camera shake when a cut connects: peak degrees, FOV punch as a fraction of the
## current FOV, and its length in seconds. Same contract as Weapon.shake.
signal shake(degrees: float, fov_punch: float, duration: float)
## The swing carries the player forward. `speed` is m/s for `duration` seconds.
signal lunge(direction: Vector3, speed: float, duration: float)
## One physical clock strike per swing, at the first damage sample.
signal struck

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

const QUERY_LIMIT := 64
## Share of the active window that has to elapse before the arc cuts. The blade
## is shown travelling first and damages when it is most of the way through, so
## a heavy axe does not hit before it has come down.
const STRIKE_AT := 0.8
## Blade points at the camera, where "face the flat toward the viewer" has no
## unique answer. Any reference will do; keep it away from the aim direction.
const AIM_EPSILON := 0.000001
## Closest the tip may come to the eye, in metres. The ray through a corner of the
## screen runs past the eye, so a short blade held near the face can "reach" the
## corner only by pointing backwards; there the blade is clipped and its projected
## point is a lie. See _tip_direction().
const MIN_TIP_DEPTH := 0.28

## One key of the swing: where the grip is, where the tip points on screen and
## how the blade is rolled. Blending two of these keeps the tip on the straight
## screen line between the aims, which a quaternion slerp would not.
class Pose:
	var hand := Vector3.ZERO
	var aim := Vector2.ZERO
	var roll := 0.0

	func _init(p_hand := Vector3.ZERO, p_aim := Vector2.ZERO, p_roll := 0.0) -> void:
		hand = p_hand
		aim = p_aim
		roll = p_roll

	func blend(other: Pose, t: float) -> Pose:
		return Pose.new(hand.lerp(other.hand, t), aim.lerp(other.aim, t), lerpf(roll, other.roll, t))

@export var stats: Stats
@export var camera: Camera3D
## The attacker's body. Its `team` keeps the arc off the player's own hitboxes.
@export var shooter: CollisionObject3D

@export var blade_data: MeleeData = preload("res://weapons/mind_blade/mind_blade.tres")

var _active_enabled := true
var _phase := Phase.IDLE
var _phase_left := 0.0
var _cooldown := 0.0
## Swings since the node was ready. Drives the left / right alternation.
var _swing_count := 0
## Health already damaged by the current swing, so a two-sample arc cannot hit
## the same body twice.
var _struck: Array[Health] = []
## Whether the active window has already cut.
var _struck_this_swing := false
## Where the arc is measured from. Frozen when the swing becomes active: the
## lunge moves the body, but the reach the player was promised does not grow
## with it.
var _swing_origin := Vector3.ZERO
var _swing_forward := Vector3.FORWARD
## The body this swing is snapped onto, picked when the swing starts. It both
## pulls the player toward itself (see _step_toward) and becomes the centre of the
## hit arc (see _advance_phase), so "face the enemy and press V" lands on the enemy
## even when the aim was a little off.
var _magnet: Hitbox = null
var _view: Node3D
var _trail: BladeSlashTrail
var _parry_area: Area3D
var _magnet_forward := Vector3.FORWARD
var _pivot: Node3D
var _audio: AudioStreamPlayer
var _hit_sound: AudioStreamWAV
## Pose keys of the swing in flight, plus how long each of its phases was given.
var _rest := Pose.new()
var _from := Pose.new()
var _to := Pose.new()
var _windup_len := 0.0001
var _active_len := 0.0001
var _recovery_len := 0.0001
## Direction the tip travels through the middle of the cut, in this node's space:
## the swing's own blade maths, a small step past the midpoint. Zero when the
## swing does not move.
var _cut_motion := Vector3.ZERO


func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_view = _make_view(blade_data)
	_audio = AudioStreamPlayer.new()
	_audio.max_polyphony = 3
	add_child(_audio)
	_trail = BladeSlashTrail.new()
	_trail.name = "BladeSlashTrail"
	add_child(_trail)
	_hit_sound = ProceduralAudio.generate("melee_hit")
	_rest = Pose.new(blade_data.rest_hand, blade_data.rest_aim, blade_data.rest_roll)
	_pivot.transform = _pose_of(_rest)
	_parry_area = preload("res://weapons/mind_blade/parry_area.gd").new()
	_parry_area.blade = self
	add_child(_parry_area)


func _exit_tree() -> void:
	# Release any swing still queued on the audio thread when changing scenes.
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
	if is_instance_valid(_trail):
		_trail.clear()


func current() -> MeleeData:
	return blade_data


## The imported blade root is the grip centre. Body IK follows the same
## world-space frame as the rendered blade through wind-up, slash and recovery.
func grip_transform() -> Transform3D:
	return _view.global_transform if is_instance_valid(_view) else global_transform


func is_swinging() -> bool:
	return _phase != Phase.IDLE


## Metres from the grip to the tip of the selected weapon.
func blade_length() -> float:
	var data := current()
	return data.blade_length if data != null else 0.4


## Starts a swing if the weapon is ready. Returns whether it started, so tests
## do not have to guess at the cooldown.
var boon_hook: Callable

func _boon(event: StringName, context: Dictionary) -> void:
	if boon_hook.is_valid():
		boon_hook.call(event, context)

func swing_now() -> bool:
	if not is_inside_tree() or get_tree().paused or not _active_enabled:
		return false
	var data := current()
	if data == null or _phase != Phase.IDLE or _cooldown > 0.0:
		return false
	_boon(&"blade_started", {"source": shooter, "blade": self})
	_swing_count += 1
	_struck.clear()
	_struck_this_swing = false
	_phase = Phase.WINDUP
	_phase_left = _scaled(data.windup)
	_show_view()
	_trail.begin()
	_make_swing_noise(data)
	_setup_pose(data, _phase_left, _scaled(data.active), _scaled(data.recovery))
	swing_started.emit(0, _swing_count)

	# The snap is decided and taken at the top of the swing, during the wind-up, so
	# the player is already in contact when the blade arrives. A swing with nothing
	# inside `magnet_range` does not move and does not turn: it just cuts where the
	# player was already facing.
	_swing_origin = _eye()
	_swing_forward = _forward()
	_magnet = _magnet_target(data)
	_magnet_forward = _swing_forward
	if is_instance_valid(_magnet):
		_magnet_forward = (_magnet.global_position - _swing_origin).normalized()
	_step_toward(data, _magnet)

	if _phase_left <= 0.0:
		_advance_phase()
	return true


## Damage one connection deals right now, after gun and blade damage buffs.
func strike_damage() -> float:
	var data := current()
	if data == null:
		return 0.0
	return data.damage * _stat(Stats.DAMAGE) * _stat(Stats.MELEE_DAMAGE)


## Reach of the current weapon after the blade-range buff.
func strike_reach() -> float:
	var data := current()
	if data == null:
		return 0.0
	return data.reach * _stat(Stats.MELEE_RANGE)


## Phase length after fire-rate and blade-speed buffs. Tests step the swing with this.
func scaled_time(seconds: float) -> float:
	return _scaled(seconds)


## Death hides the blade without playing out a recovery or a counter window.
func cancel() -> void:
	_phase = Phase.IDLE
	_phase_left = 0.0
	_magnet = null
	_hide_views()
	if _trail != null:
		_trail.clear()


## Permanent for this player instance; a respawn constructs a fresh blade.
func deactivate() -> void:
	_active_enabled = false
	cancel()
	set_process(false)


func view_visible() -> bool:
	return _view != null and _view.visible


## Where the tip of the blade is on screen right now, in the same normalised
## coordinates the .tres aims are written in. The proof shots and the headless
## test read this instead of trusting the pose numbers.
func tip_screen_position() -> Vector2:
	var tip := _pivot.global_transform * Vector3(0.0, 0.0, -blade_length())
	if camera == null:
		return Vector2.ZERO
	var pixel := camera.unproject_position(tip)
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(pixel.x / size.x * 2.0 - 1.0, 1.0 - pixel.y / size.y * 2.0)


## How far in front of the eye the tip is, in metres. Screen position alone cannot
## tell a tip that is in the frame from one that is behind the camera and only
## projects there, so the test reads this together with tip_screen_position().
func tip_depth() -> float:
	if camera == null:
		return 0.0
	var tip := _pivot.global_transform * Vector3(0.0, 0.0, -blade_length())
	return -(camera.global_transform.affine_inverse() * tip).z


## How square the flat of the blade is to the camera right now: 0 is edge on,
## where a weapon is a single line on screen, and 1 is full face. AC-05 asks for
## three silhouettes that can be told apart, and this is the number that says
## whether the pose shows one at all.
func blade_facing() -> float:
	if _pivot == null:
		return 0.0
	var flat := _pivot.global_transform.basis.x.normalized()
	# +Z of this node points back at the eye, because it sits on the camera.
	return absf(flat.dot(global_transform.basis.z.normalized()))


## How much the cutting edge leads the cut right now: 1 means the edge points
## straight down the line the tip travels, -1 means the spine does. A single
## screenshot cannot show this reliably and it is easy to get backwards, so the
## headless test reads it at the start of each cut.
func edge_leading() -> float:
	var data := current()
	if data == null or data.edge_side == 0 or _pivot == null:
		return 0.0
	if _cut_motion.length_squared() < 0.000001:
		return 0.0
	var edge := _pivot.transform.basis.y.normalized() * float(data.edge_side)
	return edge.dot(_cut_motion)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var remaining := delta
	# Carry unused frame time across phases, so 80/120/150 ms stays invariant
	# under low frame rates and one large update cannot skip the physical hit.
	while _phase != Phase.IDLE and remaining > 0.000001:
		var step := minf(remaining, _phase_left)
		_phase_left = maxf(0.0, _phase_left - step)
		remaining -= step
		if _phase == Phase.WINDUP or _phase == Phase.ACTIVE:
			_swing_forward = _swing_forward.slerp(_magnet_forward, minf(step * 30.0, 1.0))
		if _phase == Phase.ACTIVE and not _struck_this_swing \
				and _phase_left <= _active_len * (1.0 - STRIKE_AT):
			_strike()
		_update_pose()
		if _phase == Phase.ACTIVE:
			_sample_trail()
		if _phase_left <= 0.000001:
			_advance_phase()
	if Input.is_action_just_pressed("melee"):
		swing_now()


func _advance_phase() -> void:
	var data := current()
	if data == null:
		_phase = Phase.IDLE
		return
	match _phase:
		Phase.WINDUP:
			# The cut starts: freeze the arc where the player stands now and
			# start travelling. The blade cuts at the far end of the window (see
			# _process), not on the frame the wind-up ends.
			_phase = Phase.ACTIVE
			_phase_left = _scaled(data.active)
			_swing_origin = _eye()
			_swing_forward = _forward()
			# The arc turns to the body the swing snapped onto, so "face the enemy
			# and press V" hits the enemy even if the crosshair was a few degrees
			# off. Without a body there is nothing to turn to and the swing keeps
			# the direction the player was looking.
			if _magnet != null and is_instance_valid(_magnet) and _magnet.health != null \
					and not _magnet.health.is_dead():
				var to_body := _magnet.global_position - _swing_origin
				if to_body.length_squared() > 0.0001:
					_magnet_forward = to_body.normalized()
			_swing_forward = _swing_forward.slerp(_magnet_forward, 0.75)
			# The cut starts with the blade loaded on its first pose: seed the
			# ribbon there so the arc is full even on a single-frame window.
			_trail.begin()
			_sample_trail()
			if _phase_left <= 0.0:
				_advance_phase()
		Phase.ACTIVE:
			# Second sample of the same arc, so a body that walks into the sweep
			# during the active window is still cut.
			_strike()
			_phase = Phase.RECOVERY
			_phase_left = _scaled(data.recovery)
			# Land exactly on the end of the cut before announcing it: listeners
			# (proof shots, tests) read the blade's position on the signal, and a
			# frame of drift here would read as the trail being short.
			_pivot.transform = _pose_of(_to)
			_trail.end()
			strike_finished.emit()
			if _phase_left <= 0.0:
				_advance_phase()
		Phase.RECOVERY:
			_phase = Phase.IDLE
			_phase_left = 0.0
			_cooldown = _scaled(data.extra_cooldown)
			# Settle exactly on the rest pose: _update_pose() stops running once
			# the phase is idle, so the last frame of the recovery would
			# otherwise be left a hair off rest.
			_pivot.transform = _pose_of(_rest)
			_hide_views()
			swing_finished.emit()
			_boon(&"blade_finished", {"source": shooter, "blade": self})


## Every hitbox inside `radius` of the swing origin and the frontal cone, sorted
## with the one closest to the aim line first. Shared by the damage arc and the
## magnet that decides whether the swing steps in.
func _candidates(radius: float, arc_degrees: float) -> Array[Dictionary]:
	var origin := _swing_origin
	var forward := _swing_forward
	var space := get_world_3d().direct_space_state

	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), origin)
	query.collision_mask = CollisionLayers.HITBOXES
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var team := _team()
	var half_arc := deg_to_rad(arc_degrees * 0.5)
	var found: Array[Dictionary] = []
	for result in space.intersect_shape(query, QUERY_LIMIT):
		var hitbox := result.collider as Hitbox
		if hitbox == null or hitbox.health == null or hitbox.health.is_dead():
			continue
		if hitbox.health.team == team or _struck.has(hitbox.health):
			continue
		var to := hitbox.global_position - origin
		var distance := to.length()
		if distance < 0.0001 or distance > radius:
			continue
		if forward.angle_to(to) > half_arc:
			continue
		if not _line_of_sight(space, origin, hitbox.global_position):
			continue
		# How far the hitbox sits off the aim line. A body has a head and a torso
		# hitbox, and the one the player is looking at is the part that gets hit,
		# so headshots come from aim rather than from whichever box is nearer.
		var offset := (to - forward * to.dot(forward)).length()
		found.append({"hitbox": hitbox, "distance": distance, "offset": offset})

	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(a.offset - b.offset) > 0.01:
			return a.offset < b.offset
		return a.distance < b.distance)
	return found


## Finds every hitbox inside the cone and damages it. Two samples per swing (most
## of the way through the cut and at its end) so a body that walks into the sweep
## is still cut; `_struck` and the remaining target budget stop doubles.
func _strike() -> void:
	var data := current()
	if data == null:
		return
	if not _struck_this_swing:
		_boon(&"blade_struck", {"source": shooter, "blade": self, "position": _swing_origin, "direction": _swing_forward})
		struck.emit()
	_struck_this_swing = true
	var budget := 0
	if data.max_targets > 0:
		budget = data.max_targets - _struck.size()
		if budget <= 0:
			return
	var origin := _swing_origin
	var forward := _swing_forward
	var found := _candidates(data.reach * _stat(Stats.MELEE_RANGE), data.arc_degrees * _stat(Stats.MELEE_ARC))
	# A body has several hitboxes (head, torso); one swing may damage each body
	# once, so pick the nearest hitbox per body and stop at the target budget.
	var limit := found.size() if data.max_targets <= 0 else budget
	var struck_bodies := 0
	for entry in found:
		if struck_bodies >= limit:
			break
		var hitbox := entry.hitbox as Hitbox
		if _struck.has(hitbox.health):
			continue
		if _strike_one(data, hitbox, origin, forward):
			struck_bodies += 1


## The body the swing snaps onto: the nearest one inside the magnet cone.
## Null means nothing is close enough, and then the swing neither moves the player
## nor turns the arc. `magnet_range` of 0 turns the magnet off for a weapon.
func _magnet_target(data: MeleeData) -> Hitbox:
	var magnet_range := data.magnet_range * _stat(Stats.MELEE_RANGE)
	if magnet_range <= 0.0:
		return null
	var nearest: Hitbox = null
	var nearest_distance := INF
	for entry in _candidates(magnet_range, data.magnet_arc_degrees):
		if entry.distance < nearest_distance:
			nearest_distance = entry.distance
			nearest = entry.hitbox as Hitbox
	return nearest


## The dash into the target, and only then. The direction is the straight line to
## the body, so a swing taken while roughly facing the enemy still closes the gap
## and lands — that pull is the "吸附" part. It overrides the player's velocity for
## `lunge_time`, so it happens even with no movement key held. Nothing close
## enough means no dash at all: lurching through empty air reads as the ground
## moving, not as weight.
func _step_toward(data: MeleeData, target: Hitbox) -> void:
	if target == null or data.lunge <= 0.0:
		return
	var to := target.global_position - _swing_origin
	to.y = 0.0
	# Already on top of them: there is no ground left to close.
	if to.length() < data.stop_distance or to.length() < 0.0001:
		return
	lunge.emit(to.normalized(), data.lunge / maxf(data.lunge_time, 0.01), data.lunge_time)


## Damages one hitbox. Returns whether it actually took damage, so a body that
## ignored the hit does not eat into the swing's target budget.
func _strike_one(data: MeleeData, hitbox: Hitbox, origin: Vector3, forward: Vector3) -> bool:
	var health := hitbox.health
	_struck.append(health)
	var damage := data.damage * _stat(Stats.DAMAGE) * _stat(Stats.MELEE_DAMAGE)
	var ctx := {"kind": &"blade", "tag": &"blade", "proc_depth": 0, "source": shooter,
		"target": health.get_parent(), "health": health, "hitbox": hitbox,
		"position": hitbox.global_position, "direction": forward, "damage": damage, "base_damage": damage,
		"body_part": hitbox.body_part, "critical": false, "critical_multiplier": 1.0, "cancelled": false,
		"damage_scaled": true}
	_boon(&"hit_before", ctx)
	var hp_before := health.health
	var dealt := 0.0 if ctx.cancelled else hitbox.apply_hit_at(maxf(ctx.damage, 0.0), shooter, hitbox.global_position, forward, false, ctx)
	ctx.dealt = minf(dealt, hp_before)
	ctx.killed = health.is_dead()
	_boon(&"hit_after", ctx)
	if dealt <= 0.0:
		return false

	var push := hitbox.global_position - origin
	push.y = 0.0
	if push.length_squared() < 0.0001:
		push = Vector3(forward.x, 0.0, forward.z)
	push = push.normalized()

	var body := _body_of(health)
	if body != null and body.has_method("apply_impact") and not ctx.get("skip_impact", false):
		body.apply_impact(push, data.impact_force, data.impact_stagger)

	hit_landed.emit(hitbox.body_part == Hitbox.BodyPart.HEAD, health.is_dead())
	recoil.emit(data.camera_kick, data.camera_kick_yaw * (1.0 if _swing_count % 2 == 0 else -1.0), 0.35)
	shake.emit(0.65, 0.018, 0.14)
	_play(_hit_sound, 0.0, 1.02)
	_spawn_impact(hitbox.global_position, push)
	return true


func _line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD)
	return space.intersect_ray(query).is_empty()


## Crystal cleave where the edge lands: faceted shards, never the old fleshy
## puff. The burst carries its own private random stream (ADR 0005).
func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	CrystalImpact.spawn(parent, point, normal, true)


## One frame of the cut, taken from the pivot the view is drawn with.
func _sample_trail() -> void:
	if _trail == null or _pivot == null:
		return
	var blade := _pivot.global_transform
	_trail.sample(blade.origin, blade * Vector3(0.0, 0.0, -blade_length()))


## The node that owns `health` and can be shoved. Enemies implement
## apply_impact(); anything without it is simply not pushed.
func _body_of(health: Health) -> Node:
	var node: Node = health.get_parent()
	while node != null:
		if node.has_method("apply_impact"):
			return node
		node = node.get_parent()
	return null


func _make_view(data: MeleeData) -> Node3D:
	var view: Node3D
	if data.view_scene != null:
		view = data.view_scene.instantiate() as Node3D
	else:
		view = _placeholder_view()
	# The pivot sits at the grip, so the swing turns around the hand and the
	# blade sweeps across the frame instead of the whole weapon flying around.
	view.position = Vector3.ZERO
	view.rotation_degrees = Vector3.ZERO
	view.visible = false
	_pivot.add_child(view)
	return view


func _placeholder_view() -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.5)
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func _show_view() -> void:
	_view.visible = true


func _hide_views() -> void:
	_view.visible = false


## Called by the projectile's swept physics ray, so even a fast bullet cannot
## skip the active window by jumping through the blade's collision volume.
func try_parry(projectile: Projectile, point: Vector3) -> bool:
	if get_tree().paused or not _active_enabled:
		return false
	if _phase != Phase.ACTIVE or projectile.reflected or shooter == null:
		return false
	if is_instance_valid(projectile.source) and projectile.source.get("team") == _team():
		return false
	var to := point - _eye()
	if to.length_squared() < 0.0001 or _forward().angle_to(to) > deg_to_rad(40.0):
		return false
	if not _line_of_sight(get_world_3d().direct_space_state, _eye(), point):
		return false
	projectile.reflect(shooter, point)
	projectile.boon_hook = boon_hook
	var ctx := {"source": shooter, "projectile": projectile, "position": point,
		"direction": -projectile.global_basis.z, "damage": projectile.damage}
	_boon(&"parry", ctx)
	projectile.damage = ctx.damage
	if ctx.direction.length_squared() > 0.0001:
		projectile.look_at(projectile.global_position + ctx.direction,
			Vector3.UP if absf(ctx.direction.normalized().y) < 0.99 else Vector3.FORWARD)
	_play(_hit_sound, -1.0, 1.6)
	Events.blade_parried.emit(point)
	return true


## Lays out the swing: the three poses it travels through and how long each
## phase got. The pose is driven from the phase timers (see _update_pose), not
## from a tween: a tween has its own clock and drifts a frame or two behind the
## damage, so the blade would be shown mid-air where the hit already landed.
func _setup_pose(data: MeleeData, windup: float, active: float, recovery: float) -> void:
	_windup_len = maxf(windup, 0.0001)
	_active_len = maxf(active, 0.0001)
	_recovery_len = maxf(recovery, 0.0001)
	_rest = Pose.new(data.rest_hand, data.rest_aim, data.rest_roll)
	_from = Pose.new(data.cut_from_hand, data.cut_from_aim, data.cut_from_roll)
	_to = Pose.new(data.cut_to_hand, data.cut_to_aim, data.cut_to_roll)
	_cut_motion = _motion_of(_from, _to)
	_pivot.transform = _pose_of(_rest)


## Places the pivot for how far the current phase has run. Same clock as the
## damage, so the blade is exactly at the end of the cut when `strike_finished`
## fires, and back at the rest pose when the recovery ends.
func _update_pose() -> void:
	match _phase:
		Phase.WINDUP:
			# Ease out: the blade arrives on the start of the cut and waits there
			# for the rest of the committed wind-up, which is what sells weight.
			_pivot.transform = _pose_of(_rest.blend(_from, _ease_out_sine(1.0 - _phase_left / _windup_len)))
		Phase.ACTIVE:
			# A burst, not an even sweep: the blade is slow to leave the
			# wind-up, snaps across the middle of the cut and settles on the end
			# pose without overshooting. The impact lands at STRIKE_AT, so the
			# fastest part of the travel is already behind it.
			_pivot.transform = _pose_of(_from.blend(_to, _ease_burst(1.0 - _phase_left / _active_len)))
		Phase.RECOVERY:
			_pivot.transform = _pose_of(_to.blend(_rest, _ease_in_quad(1.0 - _phase_left / _recovery_len)))


## Turns a pose key into a pivot transform: the blade points at the requested
## screen point and the grip sits where the pose says.
func _pose_of(pose: Pose) -> Transform3D:
	var direction := _tip_direction(pose.hand, pose.aim)
	var basis := Basis(Quaternion(Vector3(0.0, 0.0, -1.0), direction))
	basis = basis * Basis(Vector3(0.0, 0.0, 1.0), _roll_for(basis, pose.roll))
	return Transform3D(basis, pose.hand)


## How far the blade is rolled around its own long axis. Aiming the tip leaves
## that one degree of freedom open, and it is not cosmetic: the blade's flat can
## face the camera with either the edge or the spine leading, and the wrong one
## turns a cut into a slap.
##
## Two aims pull on that angle, and each is blind exactly where the other works:
##   * flat to the camera, which is what makes a readable silhouette — undefined
##     when the blade points at the eye (a blade edge on has no flat to show);
##   * edge down the line the tip travels, which is what makes it a cut —
##     undefined when the blade travels along itself (a pull, not a sweep).
## The edge wins wherever the swing really sweeps across the frame; the
## camera-facing angle only holds where the blade travels along its own axis.
## Mixing the two half and half was tried first and is too polite: at mid-cut it
## left the spine leading on some frames, which is exactly where it reads.
## No unwrapping against the last frame — that would keep the blade from spinning,
## but it can also lock the spine in front, because the two halves of the turn are
## the edge and the spine.
##
## A symmetric head (edge_side 0, the axe) has no edge to pick, so only the
## camera-facing term applies; the .tres `*_roll` then turns the head away from it,
## which for the axe is what makes the chop chop instead of slap.
func _roll_for(basis: Basis, offset_degrees: float) -> float:
	var data := current()
	if data == null or _cut_motion.length_squared() <= 0.000001:
		return deg_to_rad(offset_degrees)
	var toward_camera := atan2(basis.y.z, basis.x.z)
	# A symmetric head has no edge to lead, but its plate still has a right way
	# round: a two-handed chop straight down puts the plate in the swing's own
	# vertical plane, so from the eye it is nearly edge on. Broadside (offset 0)
	# the same motion reads as pressing the axe's flat onto the ground.
	if data.edge_side == 0:
		return toward_camera + deg_to_rad(offset_degrees)
	var roll := toward_camera
	var edge := float(data.edge_side)
	var blade := -basis.z
	# How much of the motion is across the blade (a sweep) instead of along it.
	var across := sqrt(maxf(1.0 - blade.dot(_cut_motion) * blade.dot(_cut_motion), 0.0))
	if across > 0.001:
		var leading := atan2(-edge * basis.x.dot(_cut_motion), edge * basis.y.dot(_cut_motion))
		# The edge wins as soon as the swing sweeps across the frame; the
		# camera-facing angle only holds where the blade is travelling along its
		# own axis, because there it has no other answer.
		roll = lerpf(toward_camera, leading, smoothstep(0.15, 0.5, across))
	if not is_zero_approx(offset_degrees):
		roll += deg_to_rad(offset_degrees)
	return roll


## Direction the tip travels through the middle of the cut, in this node's space:
## the swing's own blade maths, a small step past the midpoint. Zero when the
## swing does not move.
func _motion_of(from: Pose, to: Pose) -> Vector3:
	var length := blade_length()
	var mid := from.blend(to, 0.5)
	var later := from.blend(to, 0.65)
	var here := mid.hand + _tip_direction(mid.hand, mid.aim) * length
	var there := later.hand + _tip_direction(later.hand, later.aim) * length
	var motion := there - here
	if motion.length_squared() < 0.000001:
		return Vector3.ZERO
	return motion.normalized()


## Unit direction the grip has to point so the tip lands on the requested screen
## point, as seen from the eye. Exact when the blade is long enough to reach the
## ray through that point; otherwise it points at the closest point on the ray,
## which is the best a short weapon can do from that grip.
##
## The tip is then pulled in to MIN_TIP_DEPTH if the solved point sits behind the
## eye. A corner-of-the-screen ray passes very close to the eye, so a short blade
## with the grip near the face "reaches" the corner from behind the camera: the
## blade is drawn clipped, and camera.unproject_position() still returns a picture
## coordinate for it, which reads as a correct cut while nothing is on screen.
## Keeping the point on the same ray means the aim still projects where it was
## asked for; the blade then runs past the corner instead of into the eye.
func _tip_direction(hand: Vector3, aim: Vector2) -> Vector3:
	var along := _screen_direction(aim)
	var length := blade_length()
	var forward_share := hand.dot(along)
	var miss_squared := maxf(hand.length_squared() - forward_share * forward_share, 0.0)
	var distance := forward_share
	if miss_squared <= length * length:
		distance = forward_share + sqrt(length * length - miss_squared)
	if along.z * distance > -MIN_TIP_DEPTH:
		distance = MIN_TIP_DEPTH / maxf(-along.z, 0.05)
	var direction := along * distance - hand
	if direction.length_squared() < AIM_EPSILON:
		return along
	return direction.normalized()


## Unit direction from the eye through a normalised screen point, in this node's
## space. Going through the camera projection keeps the aim honest whatever the
## field of view or aspect ratio is.
func _screen_direction(aim: Vector2) -> Vector3:
	if camera == null:
		return Vector3(aim.x, aim.y, -1.0).normalized()
	var size := get_viewport().get_visible_rect().size
	var pixel := Vector2((aim.x + 1.0) * 0.5 * size.x, (1.0 - aim.y) * 0.5 * size.y)
	var world := camera.project_ray_normal(pixel)
	return global_transform.basis.orthonormalized().inverse() * world


static func _ease_out_sine(t: float) -> float:
	return sin(clampf(t, 0.0, 1.0) * PI * 0.5)


## Smoothstep: how far through the cut the blade is, with no snap at either end.
static func _ease_mid(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The cut: warping smoothstep's input makes the blade hang in the wind-up,
## snap through the middle and settle cleanly on the end pose. Both ends stay
## fixed and the curve never runs backwards, so the tip still lands exactly on
## `cut_to_aim` when the window closes.
static func _ease_burst(t: float) -> float:
	return _ease_mid(pow(clampf(t, 0.0, 1.0), 1.7))


static func _ease_in_quad(t: float) -> float:
	return pow(clampf(t, 0.0, 1.0), 2.0)


func _make_swing_noise(data: MeleeData) -> void:
	_play(ProceduralAudio.generate(data.swing_sound), -3.0, data.swing_pitch)


func _play(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	_audio.stream = stream
	_audio.volume_db = volume_db
	_audio.pitch_scale = pitch
	_audio.play()


func _eye() -> Vector3:
	return camera.global_position if camera != null else global_position


func _forward() -> Vector3:
	return -camera.global_basis.z if camera != null else -global_basis.z


func _team() -> int:
	if shooter != null and "team" in shooter:
		return shooter.team
	return 0


## Swing and recovery speeds scale with gun fire-rate and the blade-speed buff.
## Both bases are 1, so an unbuffed swing keeps the `.tres` timings.
func _scaled(seconds: float) -> float:
	return seconds / maxf(_stat(Stats.FIRE_RATE) * _stat(Stats.MELEE_SPEED), 0.01)


func _stat(stat: StringName) -> float:
	return stats.get_value(stat) if stats != null else 1.0
