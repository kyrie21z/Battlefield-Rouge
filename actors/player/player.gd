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
## Multiplier on top of the look speed while aiming (the settings menu sets it).
## 1.0 keeps the game exactly as it was before the menu.
var ads_sensitivity := 1.0
@export var base_fov := 75.0
@export var fov_lerp_speed := 14.0

## Seed of the shake's own random generator: what the player sees must never
## draw from the global sequence (ADR 0005).
const FEEL_SEED := 0x5A4E

## Getting hit flinches the rendering camera. Degrees grow with the share of
## max health taken; the cap keeps a burst from throwing the picture around.
const HURT_SHAKE_BASE := 0.5
const HURT_SHAKE_PER_HP := 8.0
const HURT_SHAKE_MAX := 2.2
const HURT_SHAKE_DURATION := 0.2

## Read by Health to ignore friendly fire.
var team := 0
var boons: BoonManager
var realm_effects: RealmPlayerEffects
var fragments: PsycheFragments
var _external_impulse := Vector3.ZERO
var _external_impulse_left := 0.0

## Independent sources take the strongest field, never multiply. Weak handles
## also restore walking speed if a caster disappears during a scene change.
var _stasis_sources: Dictionary = {}


func set_stasis_source(source: Node, multiplier: float) -> void:
	if is_instance_valid(source):
		_stasis_sources[source.get_instance_id()] = [weakref(source), clampf(multiplier, 0.75, 1.0)]


func clear_stasis_source(source: Node) -> void:
	if is_instance_valid(source):
		_stasis_sources.erase(source.get_instance_id())


func stasis_multiplier() -> float:
	var result := 1.0
	for id in _stasis_sources.keys():
		var entry: Array = _stasis_sources[id]
		var source: Node = entry[0].get_ref()
		if not is_instance_valid(source) or source.is_queued_for_deletion():
			_stasis_sources.erase(id)
		else:
			result = minf(result, entry[1])
	return result

var _pitch := 0.0
var _visual_kick := Vector2.ZERO
var _kick_origin := Vector2.ZERO
var _kick_left := 0.0
## Leftover forward push from a melee swing, drained over `_lunge_left`.
var _lunge := Vector3.ZERO
var _lunge_left := 0.0
## The dash overwrites horizontal velocity for `_dash_left`, same idea as the lunge.
var _dash_velocity := Vector3.ZERO
var _dash_left := 0.0
## Camera shake state, see _on_weapon_shake().
var _shake_degrees := 0.0
var _shake_left := 0.0
var _shake_total := 0.0
var _punch := 0.0
var _punch_left := 0.0
var _punch_total := 0.0
var _shake_phase := Vector3.ZERO
var _shake_time := 0.0
var _feel_rng := RandomNumberGenerator.new()

@onready var stats: Stats = $Stats
@onready var health: Health = $Health
@onready var dash: PlayerDash = $Dash
@onready var weapon: Weapon = $Head/Camera3D/Weapon
@onready var melee: MeleeWeapon = $Head/Camera3D/Melee
@onready var shield: PlayerShield = $Shield
@onready var combat_traits: CombatTraits = $CombatTraits
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
## The camera that actually renders. `_camera` stays exactly where the player
## aims, and everything that reads the aim (rays, melee, throws) keeps reading
## it; shake and FOV punch only ever touch this child.
@onready var view_camera: Camera3D = $Head/Camera3D/ViewCamera


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.fov = base_fov
	_feel_rng.seed = FEEL_SEED
	view_camera.fov = base_fov
	weapon.recoil.connect(_on_weapon_recoil)
	weapon.shake.connect(_on_weapon_shake)
	melee.recoil.connect(_on_weapon_recoil)
	melee.lunge.connect(_on_melee_lunge)
	melee.swing_started.connect(_on_melee_swing_started)
	melee.swing_finished.connect(_on_melee_swing_finished)
	dash.dashing.connect(_on_dash)
	health.died.connect(_on_died)
	health.damaged.connect(_on_hurt)
	boons = BoonManager.new()
	boons.name = "BoonManager"
	add_child(boons)
	boons.bind(self, stats, health, weapon, melee, dash)
	DualBoonManager.install(boons)
	realm_effects = RealmPlayerEffects.new()
	realm_effects.name = "RealmEffects"
	add_child(realm_effects)
	realm_effects.bind(self)
	fragments = PsycheFragments.new()
	fragments.name = "PsycheFragments"
	add_child(fragments)
	fragments.bind(self)
	var focus := ADSFocus.new()
	focus.name = "ADSFocus"
	add_child(focus)
	focus.bind(self)


## Read-only dash state for the HUD.
func dash_charges() -> int:
	return dash.charges()


func dash_max_charges() -> int:
	return dash.max_charges


func dash_recharge_fraction() -> float:
	return dash.recharge_fraction()


func is_aiming() -> bool:
	return weapon.aiming


## Eye position and facing direction, for systems that need to know what the
## player can see (e.g. the reinforcement spawn check).
func eye_position() -> Vector3:
	return _camera.global_position


func view_forward() -> Vector3:
	return -_camera.global_basis.z


## Applied by the settings menu. Only mouse look changes; `aim_at()` and the
## bots keep their fixed behaviour.
func set_look_sensitivity(base: float, ads_scale: float) -> void:
	mouse_sensitivity = maxf(base, 0.0)
	ads_sensitivity = maxf(ads_scale, 0.0)


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
		# Sensitivity tracks the actual interpolated ADS field of view.
		var look := mouse_sensitivity
		if weapon.aiming:
			look *= ads_sensitivity * _camera.fov / base_fov
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
	var lunging := not dashing and _lunge_left > 0.0
	if dashing:
		_dash_left = maxf(_dash_left - delta, 0.0)
		velocity = _dash_velocity
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity * realm_effects.jump_multiplier

	# A dash drops the sights for its duration: holding aim through it does not
	# keep the player scoped mid-dash. Reloading is left alone.
	var aiming := Input.is_action_pressed("aim") and not weapon.is_reloading() \
		and not dashing
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var speed := jog_speed * stats.get_value(Stats.MOVE_SPEED) * stasis_multiplier() * realm_effects.move_multiplier
	if aiming:
		speed *= weapon.data.ads_move_scale
	var accel := ground_accel if is_on_floor() else air_accel
	if not dashing:
		velocity.x = move_toward(velocity.x, direction.x * speed, accel * speed * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, accel * speed * delta)
		# A melee swing carries the player: the step overrides the walked velocity
		# for its short duration, so the distance is exactly `speed * duration`
		# instead of building up frame by frame.
		if lunging:
			var fraction := minf(delta, _lunge_left) / delta
			_lunge_left = maxf(_lunge_left - delta, 0.0)
			velocity.x = _lunge.x * fraction
			velocity.z = _lunge.z * fraction
	if _external_impulse_left > 0.0:
		var impulse_fraction := minf(delta, _external_impulse_left) / maxf(delta, 0.0001)
		_external_impulse_left = maxf(0.0, _external_impulse_left - delta)
		velocity.x = _external_impulse.x * impulse_fraction
		velocity.z = _external_impulse.z * impulse_fraction
		if _external_impulse.y > 0.0:
			velocity.y = maxf(velocity.y, _external_impulse.y * impulse_fraction)
	move_and_slide()
	if lunging and _lunge_left <= 0.0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	if dashing and _dash_left <= 0.0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		velocity.y = 0.0
	weapon.aiming = aiming
	weapon.moving = Vector2(velocity.x, velocity.z).length() > 0.5
	weapon.airborne = not is_on_floor()


func set_realm_effect(source: StringName, data: Dictionary) -> void:
	if realm_effects != null:
		realm_effects.set_effect(source, data)


func clear_realm_effect(source: StringName) -> void:
	if realm_effects != null:
		realm_effects.clear_effect(source)


func cancel_forced_movement() -> void:
	_dash_left = 0.0
	_lunge_left = 0.0
	if is_instance_valid(dash):
		dash.cancel()


func apply_external_impulse(direction: Vector3, speed: float, duration: float) -> void:
	if health.is_dead() or direction.length_squared() < 0.0001:
		return
	cancel_forced_movement()
	_external_impulse = direction.normalized() * maxf(speed, 0.0)
	_external_impulse_left = clampf(duration, 0.0, 2.0)


func _process(delta: float) -> void:
	# ADS is owned by Weapon; dash adds only a temporary widening.
	var target_fov := weapon.fov_for(base_fov) + dash.fov_offset()
	_camera.fov = lerpf(_camera.fov, target_fov, minf(fov_lerp_speed * delta, 1.0))
	_kick_left = maxf(_kick_left - delta, 0.0)
	var recovery := _kick_left / maxf(weapon.data.camera_return_time, 0.001)
	_visual_kick = _kick_origin * recovery * recovery
	_apply_look()
	_update_view_camera(delta)


## The manual share goes straight into the aim, so the player has to pull the
## mouse down to fight the climb; the rest is a kick that settles by itself.
func _on_weapon_recoil(pitch: float, yaw: float, manual: float) -> void:
	_pitch = clampf(_pitch + deg_to_rad(pitch * manual), deg_to_rad(-89.0), deg_to_rad(89.0))
	rotate_y(deg_to_rad(-yaw * manual))
	_visual_kick += Vector2(pitch, -yaw) * (1.0 - manual)
	_kick_origin = _visual_kick
	_kick_left = weapon.data.camera_return_time


## One camera shake and FOV punch (both already scaled by the caller). A new
## kick takes over only if it is stronger than what is left of the last, so a
## burst shudders instead of piling up. Public because getting hurt flinches
## the view through the same path.
func add_view_shake(degrees: float, fov_punch: float, duration: float) -> void:
	var left_fraction := _shake_left / maxf(_shake_total, 0.001)
	if degrees >= _shake_degrees * left_fraction * left_fraction:
		_shake_degrees = degrees
		_shake_left = duration
		_shake_total = duration
		_shake_phase = Vector3(_feel_rng.randf() * TAU, _feel_rng.randf() * TAU, _feel_rng.randf() * TAU)
	var punch_fraction := _punch_left / maxf(_punch_total, 0.001)
	if fov_punch >= _punch * punch_fraction * punch_fraction:
		_punch = fov_punch
		_punch_left = duration
		_punch_total = duration


## A shot's camera shake, straight from the weapon.
func _on_weapon_shake(degrees: float, fov_punch: float, duration: float) -> void:
	add_view_shake(degrees, fov_punch, duration)


## Taking damage knocks the rendering camera only: `$Head/Camera3D` stays where
## the player aims, so rays, melee and the fixture replay do not move.
func _on_hurt(dealt: float, _part: Hitbox.BodyPart, _source: Node) -> void:
	# Armor resists the existing hurt flinch; Health/HUD still report damage.
	if stats.get_value(Stats.ARMOR) > 0.0:
		return
	var max_health := maxf(health.max_health, 1.0)
	add_view_shake(clampf(HURT_SHAKE_BASE + HURT_SHAKE_PER_HP * dealt / max_health,
		HURT_SHAKE_BASE, HURT_SHAKE_MAX), 0.0, HURT_SHAKE_DURATION)


## Poses the rendering camera: shake rotation on its local transform and the FOV
## punch on top of the aimed field of view. Settles back to exactly identity.
func _update_view_camera(delta: float) -> void:
	var rotation_shake := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		_shake_time += delta
		var fade := _shake_left / _shake_total
		var amp := _shake_degrees * fade * fade
		rotation_shake = Vector3(
			sin(_shake_time * 61.0 + _shake_phase.x) * amp,
			sin(_shake_time * 47.0 + _shake_phase.y) * amp * 0.6,
			sin(_shake_time * 38.0 + _shake_phase.z) * amp * 0.9)
	view_camera.transform = Transform3D(Basis.from_euler(Vector3(
		deg_to_rad(rotation_shake.x), deg_to_rad(rotation_shake.y), deg_to_rad(rotation_shake.z))), Vector3.ZERO)
	var punch := 0.0
	if _punch_left > 0.0:
		_punch_left = maxf(_punch_left - delta, 0.0)
		var fade := _punch_left / _punch_total
		punch = _punch * fade * fade
	view_camera.fov = _camera.fov * (1.0 + punch)


## True while the rendering camera is off the aim camera. For tests.
func view_is_shaking() -> bool:
	return _shake_left > 0.0 or _punch_left > 0.0


func _on_died(_source: Node) -> void:
	melee.deactivate()
	dash.cancel()
	dash.set_physics_process(false)
	shield.cancel()
	shield.set_process(false)
	combat_traits.clear()
	combat_traits.set_process(false)
	weapon.deactivate()
	Events.player_died.emit()


## Melee swings are short hops, so they go in as a fixed push rather than as an
## impulse the movement code would damp away.
func _on_melee_lunge(direction: Vector3, speed: float, duration: float) -> void:
	_lunge = Vector3(direction.x, 0.0, direction.z).normalized() * speed
	_lunge_left = duration


func _on_dash(direction: Vector3, speed: float, duration: float) -> void:
	_dash_velocity = direction.normalized() * speed
	_dash_left = duration


## The pistol yields space to the blade without leaving the hand.
func _on_melee_swing_started(_index: int, _step: int) -> void:
	weapon.set_melee_active(true)


func _on_melee_swing_finished() -> void:
	weapon.set_melee_active(false)
