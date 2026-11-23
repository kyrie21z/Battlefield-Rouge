class_name PlayerDash
extends Node
## The Shift dash: a short burst in the input direction, two charges that refill
## one at a time, and a brief window of immunity. It never moves the body itself;
## like MeleeWeapon.lunge it emits a push and the Player applies it, so the
## movement code stays in one place.
##
## A dash overrides the walked velocity for its whole duration at
## `distance / duration`, which makes the distance stable instead of building it
## up frame by frame. The air allows one dash per leave from the ground; landing
## restores it. Death calls cancel(), and the Player stops processing this node.

## The owner should push the body along `direction` at `speed` for `duration`
## seconds. Same contract as MeleeWeapon.lunge.
signal dashing(direction: Vector3, speed: float, duration: float)
## The dash movement is over. The immunity may outlast it if tuned that way.
signal dash_finished
signal charge_changed(charges: int)

@export var distance := 5.0
@export var duration := 0.18
@export var max_charges := 2
## Seconds to refill one charge. Charges refill in order, never in parallel.
@export var recharge_time := 1.5
## Seconds of damage immunity from the start of a dash. Defaults to the dash's
## own 0.18 s; it is a separate flag on Health, see Health.dash_invulnerable.
@export var invulnerable_time := 0.18
## Dashing is allowed this many times per leave from the ground.
@export var air_charges := 1
## Degrees the field of view widens at the start of a dash, then settles back.
@export var fov_kick := 6.0

var boon_hook: Callable
var stats: Stats
var _dash_context: Dictionary = {}
var _charges := 0
var _recharge_left := 0.0
var _dash_left := 0.0
var _invulnerable_left := 0.0
var _air_used := 0
var _player: CharacterBody3D
var _camera: Camera3D
var _health: Health
var _audio: AudioStreamPlayer


func _init() -> void:
	# Before the Player, so a dash pressed on a tick moves on that same tick.
	process_physics_priority = -10


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_camera = _player.get_node("Head/Camera3D") as Camera3D
	_health = _player.get_node("Health") as Health
	_charges = max_charges
	_audio = AudioStreamPlayer.new()
	_audio.stream = ProceduralAudio.generate("dash")
	_audio.volume_db = -3.0
	add_child(_audio)


func _physics_process(delta: float) -> void:
	_tick_recharge(delta * (stats.get_value(Stats.DASH_RECHARGE) if stats != null else 1.0))
	if _health == null or _health.is_dead():
		return
	if _player.is_on_floor():
		_air_used = 0
	if Input.is_action_just_pressed("dash"):
		try_dash()
	# After try_dash(), so a dash started this tick also spends its first tick
	# here and both timers end on the same tick as the Player's copy.
	_tick_invulnerable(delta)
	if _dash_left > 0.0:
		_dash_left = maxf(_dash_left - delta, 0.0)
		if _dash_left <= 0.0:
			dash_finished.emit()
			_finish_boon_dash.call_deferred(_dash_context)


## Starts a dash if a charge is free and the air allows it. Returns whether one
## started, so tests do not have to read the timers back.
func try_dash() -> bool:
	if get_tree().paused or _health == null or _health.is_dead() or _charges <= 0:
		return false
	if _player is Player:
		var player := _player as Player
		if player.stasis_multiplier() < 1.0 or (player.realm_effects != null and player.realm_effects.dash_blocked):
			return false
	if not _player.is_on_floor():
		if _air_used >= air_charges:
			return false
		_air_used += 1
	_charges -= 1
	if _charges < max_charges and _recharge_left <= 0.0:
		_recharge_left = recharge_time
	charge_changed.emit(_charges)

	_dash_left = maxf(duration, 0.0001)
	_invulnerable_left = maxf(invulnerable_time, 0.0)
	_health.dash_invulnerable = _invulnerable_left > 0.0
	_audio.play()
	_dash_context = {"source": _player, "position": _player.global_position,
		"origin": _player.global_position, "direction": _direction(), "duration": duration, "distance": distance}
	if _player is Player and _player.realm_effects != null:
		_dash_context.distance *= _player.realm_effects.dash_distance_multiplier
	if boon_hook.is_valid():
		boon_hook.call(&"dash_started", _dash_context)
	dashing.emit(_dash_context.direction, _dash_context.distance / maxf(_dash_context.duration, 0.01), _dash_context.duration)
	return true


func is_dashing() -> bool:
	return _dash_left > 0.0


func charges() -> int:
	return _charges


## A permanent capacity upgrade preserves the running recharge timer.
func set_max_charges(value: int) -> void:
	var previous := max_charges
	max_charges = maxi(1,value)
	_charges = clampi(_charges+maxi(0,max_charges-previous),0,max_charges)
	charge_changed.emit(_charges)


## How far the next charge has come back, 0..1. 0 when every charge is full.
func recharge_fraction() -> float:
	if _charges >= max_charges or _recharge_left <= 0.0 or recharge_time <= 0.0:
		return 0.0
	return clampf(1.0 - _recharge_left / recharge_time, 0.0, 1.0)


## How much wider the camera should be right now, in degrees. The kick is
## strongest on the first frame and settles by the end of the dash.
func fov_offset() -> float:
	if _dash_left <= 0.0 or duration <= 0.0:
		return 0.0
	var progress := clampf(1.0 - _dash_left / duration, 0.0, 1.0)
	return fov_kick * (1.0 - smoothstep(0.0, 1.0, progress))


## Death stops an active dash and drops its immunity. The Player also stops this
## node's physics, so no later press can start another one.
func cancel() -> void:
	_dash_left = 0.0
	_invulnerable_left = 0.0
	if _health != null:
		_health.dash_invulnerable = false


## The dash follows where the camera is facing, pitch included. W/S follow the
## pitch; A/D stay horizontal because the camera's x axis is not tilted by it.
func _direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length_squared() <= 0.0001:
		return -_camera.global_basis.z
	return (_camera.global_basis * Vector3(input.x, 0.0, input.y)).normalized()


func _tick_recharge(delta: float) -> void:
	if _charges >= max_charges or _recharge_left <= 0.0:
		return
	_recharge_left = maxf(_recharge_left - delta, 0.0)
	if _recharge_left > 0.0:
		return
	_charges += 1
	charge_changed.emit(_charges)
	# Refill one charge at a time: the next one only starts once this one lands.
	if _charges < max_charges:
		_recharge_left += recharge_time


func _tick_invulnerable(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _health != null:
		_health.dash_invulnerable = _invulnerable_left > 0.0


func _finish_boon_dash(context: Dictionary) -> void:
	if _health.is_dead():
		return
	context.position = _player.global_position
	if boon_hook.is_valid():
		boon_hook.call(&"dash_finished", context)
