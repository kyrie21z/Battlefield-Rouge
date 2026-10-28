class_name Player
extends CharacterBody3D
## First-person movement, mouse look, aiming and recoil. Speeds are scaled by
## Stats.MOVE_SPEED; health and the weapon are child components. Tuning values
## are taken from origin/sheji/characters/player/player.gd.

@export var jog_speed := 4.4
@export var jump_velocity := 4.8
@export var ground_accel := 14.0
@export var air_accel := 4.0
@export var gravity := 18.0
@export var mouse_sensitivity := 0.0022
@export var base_fov := 75.0
@export var fov_lerp_speed := 14.0
## How fast the self-recovering part of recoil settles, per second.
@export var recoil_recovery := 8.0

## Read by Health to ignore friendly fire.
var team := 0

var _pitch := 0.0
var _visual_kick := Vector2.ZERO
## Leftover forward push from a melee swing, drained over `_lunge_left`.
var _lunge := Vector3.ZERO
var _lunge_left := 0.0
## The dash overwrites horizontal velocity for `_dash_left`, same idea as the lunge.
var _dash_velocity := Vector3.ZERO
var _dash_left := 0.0

@onready var stats: Stats = $Stats
@onready var health: Health = $Health
@onready var dash: PlayerDash = $Dash
@onready var weapon: Weapon = $Head/Camera3D/Weapon
@onready var melee: MeleeWeapon = $Head/Camera3D/Melee
@onready var hammer: Hammer = $Head/Camera3D/Hammer
@onready var shield: PlayerShield = $Shield
@onready var combat_traits: CombatTraits = $CombatTraits
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.fov = base_fov
	weapon.recoil.connect(_on_weapon_recoil)
	melee.recoil.connect(_on_weapon_recoil)
	melee.lunge.connect(_on_melee_lunge)
	melee.swing_started.connect(_on_melee_swing_started)
	melee.swing_finished.connect(_on_melee_swing_finished)
	dash.dashing.connect(_on_dash)
	health.died.connect(_on_died)


## Read-only dash state for the HUD.
func dash_charges() -> int:
	return dash.charges()


func dash_max_charges() -> int:
	return dash.max_charges


func dash_recharge_fraction() -> float:
	return dash.recharge_fraction()


func is_aiming() -> bool:
	return weapon.aiming


## Turns to look at `point` in world space, the way moving the mouse would.
## For bots and replays; a person uses the mouse.
func aim_at(point: Vector3) -> void:
	var to := point - _camera.global_position
	rotation.y = atan2(-to.x, -to.z)
	_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), deg_to_rad(-89.0), deg_to_rad(89.0))
	_apply_look()


func _apply_look() -> void:
	_head.rotation.x = _pitch + deg_to_rad(_visual_kick.x)
	_head.rotation.y = deg_to_rad(_visual_kick.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Look speed follows the magnification, or 8x is just a wobbly picture:
		# the same mouse travel has to move the same number of *targets*.
		var look := mouse_sensitivity / maxf(weapon.zoom_level(), 1.0)
		rotate_y(-event.relative.x * look)
		_pitch = clampf(_pitch - event.relative.y * look, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("fire") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	# The dash owns the whole velocity while it lasts, gravity and jump included,
	# so a pitched dash is a straight line. Its last step still moves at dash
	# speed; only then is the walk speed handed back, so the dash neither ends a
	# frame short nor leaves a 27 m/s slide behind. The vertical is zeroed on the
	# hand-back so a rising dash does not fling the player past its end point.
	var dashing := _dash_left > 0.0
	if dashing:
		_dash_left = maxf(_dash_left - delta, 0.0)
		velocity = _dash_velocity
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

	# A dash drops the sights for its duration: holding aim through it does not
	# keep the player scoped mid-dash. Reloading is left alone.
	var aiming := Input.is_action_pressed("aim") and not weapon.is_reloading() \
		and not dashing
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var speed := jog_speed * stats.get_value(Stats.MOVE_SPEED)
	if aiming:
		speed *= weapon.data.ads_move_scale
	var accel := ground_accel if is_on_floor() else air_accel
	if not dashing:
		velocity.x = move_toward(velocity.x, direction.x * speed, accel * speed * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, accel * speed * delta)
		# A melee swing carries the player: the step overrides the walked velocity
		# for its short duration, so the distance is exactly `speed * duration`
		# instead of building up frame by frame.
		if _lunge_left > 0.0:
			_lunge_left = maxf(_lunge_left - delta, 0.0)
			velocity.x = _lunge.x
			velocity.z = _lunge.z
	move_and_slide()
	if dashing and _dash_left <= 0.0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		velocity.y = 0.0

	weapon.aiming = aiming
	weapon.moving = Vector2(velocity.x, velocity.z).length() > 0.5
	weapon.airborne = not is_on_floor()


func _process(delta: float) -> void:
	# The gun decides: base field of view, its own ADS value, or base/magnification
	# behind a scope. See Weapon.fov_for(). The dash adds a short widening on top
	# without touching that decision.
	var target_fov := weapon.fov_for(base_fov) + dash.fov_offset()
	_camera.fov = lerpf(_camera.fov, target_fov, minf(fov_lerp_speed * delta, 1.0))
	_visual_kick = _visual_kick.lerp(Vector2.ZERO, minf(recoil_recovery * delta, 1.0))
	_apply_look()


## The manual share goes straight into the aim, so the player has to pull the
## mouse down to fight the climb; the rest is a kick that settles by itself.
func _on_weapon_recoil(pitch: float, yaw: float, manual: float) -> void:
	_pitch = clampf(_pitch + deg_to_rad(pitch * manual), deg_to_rad(-89.0), deg_to_rad(89.0))
	rotate_y(deg_to_rad(-yaw * manual))
	_visual_kick += Vector2(pitch, -yaw) * (1.0 - manual)


func _on_died(_source: Node) -> void:
	hammer.set_process(false)
	melee.cancel()
	melee.set_process(false)
	dash.cancel()
	dash.set_physics_process(false)
	shield.cancel()
	shield.set_process(false)
	combat_traits.clear()
	combat_traits.set_process(false)
	weapon.set_process(false)
	Events.player_died.emit()


## Melee swings are short hops, so they go in as a fixed push rather than as an
## impulse the movement code would damp away.
func _on_melee_lunge(direction: Vector3, speed: float, duration: float) -> void:
	_lunge = Vector3(direction.x, 0.0, direction.z).normalized() * speed
	_lunge_left = duration


func _on_dash(direction: Vector3, speed: float, duration: float) -> void:
	_dash_velocity = direction.normalized() * speed
	_dash_left = duration


## Swinging a blade means the rifle is out of the way for that moment.
func _on_melee_swing_started(_index: int, _step: int) -> void:
	weapon.set_drawn(false)


func _on_melee_swing_finished() -> void:
	weapon.set_drawn(true)
