class_name MeleeWeapon
extends Node3D
## The melee loadout: three weapons, one swinging at a time, cycled with
## `switch_melee` and swung with `melee`. Each weapon reads as its own attack
## because the data drives everything — a dagger that flicks across the screen in
## a third of a second, a two-handed axe that has to be wound up and slams down
## the centre line, a tachi that cuts the other diagonal and reaches furthest.
##
## The swing is written on screen (see MeleeData): the tip of the blade travels
## the straight line between `cut_from_aim` and `cut_to_aim`, so a slash is a
## slash across the whole frame instead of a weapon wobbling next to the
## crosshair. The hand position supplies the depth the screen cannot.
##
## Every swing snaps onto a body that is already close: the player is pulled a
## short distance toward it (`lunge`, applied by the owner) and the hit arc is
## centred on it, so "face the enemy and press V" lands even off a few degrees and
## even with no movement key held. How far "close" is, how far the dash goes and
## how wide the magnet cone is are per weapon (`MeleeData.magnet_range`, `lunge`,
## `magnet_arc_degrees`), so the dagger stays a short flick and the tachi reaches
## furthest. A swing with nothing in range stays put and keeps the player's aim.
##
## The weapon never touches the camera or the player's body itself: it emits
## `recoil` and `lunge`, and the owner applies them. It only reads `Stats`.
## Gun buffs still scale a swing through `DAMAGE` and `FIRE_RATE`. Blade cards
## multiply `MELEE_DAMAGE`, `MELEE_SPEED` and `MELEE_RANGE`; each base is 1, so
## an unbuffed swing matches the `.tres`.
##
## Hit resolution mirrors weapon.gd: a physics query finds hitboxes, then
## Hitbox.apply_hit() does the damage and Health filters friendly fire.

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
## The swing carries the player forward. `speed` is m/s for `duration` seconds.
signal lunge(direction: Vector3, speed: float, duration: float)
signal selected(index: int, data: MeleeData)

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

var weapons: Array[MeleeData] = []
var index := 0

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
var _views: Array[Node3D] = []
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
	weapons = MeleePool.ALL.duplicate()
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	for data in weapons:
		_views.append(_make_view(data))
	_audio = AudioStreamPlayer.new()
	_audio.max_polyphony = 3
	add_child(_audio)
	_hit_sound = ProceduralAudio.generate("melee_hit")
	select(0)


func current() -> MeleeData:
	return weapons[index] if index >= 0 and index < weapons.size() else null


func is_swinging() -> bool:
	return _phase != Phase.IDLE


## Metres from the grip to the tip of the selected weapon.
func blade_length() -> float:
	var data := current()
	return data.blade_length if data != null else 0.4


func select(new_index: int) -> void:
	if weapons.is_empty():
		return
	if _phase != Phase.IDLE:
		# Switching mid-swing would leave the old viewmodel in the air.
		return
	index = wrapi(new_index, 0, weapons.size())
	# Keep the hidden viewmodel on the selected weapon's rest pose, so the next
	# swing does not start by jumping from wherever the last one ended.
	var data := current()
	if data != null and _pivot != null:
		_rest = Pose.new(data.rest_hand, data.rest_aim, data.rest_roll)
		_pivot.transform = _pose_of(_rest)
	selected.emit(index, current())


func select_next() -> void:
	select(index + 1)


## Starts a swing if the weapon is ready. Returns whether it started, so tests
## do not have to guess at the cooldown.
func swing_now() -> bool:
	var data := current()
	if data == null or _phase != Phase.IDLE or _cooldown > 0.0:
		return false
	_swing_count += 1
	_struck.clear()
	_struck_this_swing = false
	_phase = Phase.WINDUP
	_phase_left = _scaled(data.windup)
	_show_view()
	_make_swing_noise(data)
	_setup_pose(data, _phase_left, _scaled(data.active), _scaled(data.recovery))
	swing_started.emit(index, _swing_count)

	# The snap is decided and taken at the top of the swing, during the wind-up, so
	# the player is already in contact when the blade arrives. A swing with nothing
	# inside `magnet_range` does not move and does not turn: it just cuts where the
	# player was already facing.
	_swing_origin = _eye()
	_swing_forward = _forward()
	_magnet = _magnet_target(data)
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


func view_visible() -> bool:
	for view in _views:
		if view != null and view.visible:
			return true
	return false


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
	if _phase != Phase.IDLE:
		_phase_left -= delta
		if _phase == Phase.ACTIVE and not _struck_this_swing \
				and _phase_left <= _active_len * (1.0 - STRIKE_AT):
			_strike()
		if _phase_left <= 0.0:
			_advance_phase()
		_update_pose()
	# No mouse-capture gate, unlike the gun: the hammer swings with a free cursor
	# too, and a headless run never captures the mouse.
	if Input.is_action_just_pressed("switch_melee"):
		select_next()
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
					_swing_forward = to_body.normalized()
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
	_struck_this_swing = true
	var budget := 0
	if data.max_targets > 0:
		budget = data.max_targets - _struck.size()
		if budget <= 0:
			return
	var origin := _swing_origin
	var forward := _swing_forward
	var found := _candidates(data.reach * _stat(Stats.MELEE_RANGE), data.arc_degrees)
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
	var dealt := hitbox.apply_hit(data.damage * _stat(Stats.DAMAGE) * _stat(Stats.MELEE_DAMAGE), shooter)
	if dealt <= 0.0:
		return false

	var push := hitbox.global_position - origin
	push.y = 0.0
	if push.length_squared() < 0.0001:
		push = Vector3(forward.x, 0.0, forward.z)
	push = push.normalized()

	var body := _body_of(health)
	if body != null and body.has_method("apply_impact"):
		body.apply_impact(push, data.impact_force, data.impact_stagger)

	hit_landed.emit(hitbox.body_part == Hitbox.BodyPart.HEAD, health.is_dead())
	recoil.emit(data.camera_kick, data.camera_kick_yaw * (1.0 if _swing_count % 2 == 0 else -1.0), 0.35)
	_play(_hit_sound, -2.0, randf_range(0.94, 1.06))
	_spawn_impact(hitbox.global_position, push)
	return true


func _line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD)
	return space.intersect_ray(query).is_empty()


func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	Impact.spawn(parent, point, normal, true)


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
	_flat_shade(view, data.view_brightness)
	_pivot.add_child(view)
	return view


## A blade is one flat plate: turned away from the sun its whole face goes to the
## ambient colour, which at half a metre reads as a dark shape filling the corner
## of the screen. The viewmodel is flat-shaded instead: the albedo texture already
## carries the painted shading, and the weapon then looks the same whatever the
## player is facing. Materials are set as per-instance surface overrides, so the
## shared mesh is never modified.
##
## The faces are also forced double sided. The exported blades are single-sided
## plates, so half of every swing looks through the weapon at the world behind it.
## A weapon swinging past the camera must be solid from both sides; that is
## cheaper to fix here than to re-export every prop.
##
## `brightness` lifts the albedo, because unshaded means no light response at all:
## the axe head's charcoal would otherwise stay a dark blob at arm's length.
func _flat_shade(view: Node3D, brightness: float) -> void:
	var lift := Color(brightness, brightness, brightness, 1.0)
	for found in view.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var original := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as BaseMaterial3D
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.albedo_color = material.albedo_color * lift
			mesh_instance.set_surface_override_material(surface, material)


func _placeholder_view() -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.5)
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func _show_view() -> void:
	for i in _views.size():
		_views[i].visible = i == index


func _hide_views() -> void:
	for view in _views:
		view.visible = false


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
			# Even travel through the cut: the blade leaves the wind-up, crosses
			# the frame and arrives without the whip that made the middle of the
			# swing unreadable. The impact lands at STRIKE_AT, by which point the
			# tip is most of the way to its end.
			_pivot.transform = _pose_of(_from.blend(_to, _ease_mid(1.0 - _phase_left / _active_len)))
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
