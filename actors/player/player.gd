class_name Player
extends CharacterBody3D
## First-person movement, mouse look, aiming and recoil. Speeds are scaled by
## Stats.MOVE_SPEED; health and the weapon are child components. Tuning values
## are taken from origin/sheji/characters/player/player.gd.

@export var jog_speed := 4.4
@export var sprint_speed := 6.6
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

@onready var stats: Stats = $Stats
@onready var health: Health = $Health
@onready var weapon: Weapon = $Head/Camera3D/Weapon
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.fov = base_fov
	weapon.recoil.connect(_on_weapon_recoil)
	health.died.connect(_on_died)


func is_aiming() -> bool:
	return weapon.aiming


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("fire") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var aiming := Input.is_action_pressed("aim") and not weapon.is_reloading()
	var sprinting := Input.is_action_pressed("sprint") and not aiming
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var speed := (sprint_speed if sprinting else jog_speed) * stats.get_value(Stats.MOVE_SPEED)
	if aiming:
		speed *= weapon.data.ads_move_scale
	var accel := ground_accel if is_on_floor() else air_accel
	velocity.x = move_toward(velocity.x, direction.x * speed, accel * speed * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, accel * speed * delta)
	move_and_slide()

	weapon.aiming = aiming
	weapon.moving = Vector2(velocity.x, velocity.z).length() > 0.5
	weapon.airborne = not is_on_floor()


func _process(delta: float) -> void:
	var target_fov := weapon.data.ads_fov if weapon.aiming else base_fov
	_camera.fov = lerpf(_camera.fov, target_fov, minf(fov_lerp_speed * delta, 1.0))
	_visual_kick = _visual_kick.lerp(Vector2.ZERO, minf(recoil_recovery * delta, 1.0))
	_head.rotation.x = _pitch + deg_to_rad(_visual_kick.x)
	_head.rotation.y = deg_to_rad(_visual_kick.y)


## The manual share goes straight into the aim, so the player has to pull the
## mouse down to fight the climb; the rest is a kick that settles by itself.
func _on_weapon_recoil(pitch: float, yaw: float, manual: float) -> void:
	_pitch = clampf(_pitch + deg_to_rad(pitch * manual), deg_to_rad(-89.0), deg_to_rad(89.0))
	rotate_y(deg_to_rad(-yaw * manual))
	_visual_kick += Vector2(pitch, -yaw) * (1.0 - manual)


func _on_died(_source: Node) -> void:
	Events.player_died.emit()
