class_name Weapon
extends Node3D
## The guns in the player's hands, one in hand at a time. It carries a `data_set`
## of WeaponData (rifle, shotgun, sniper), keeps each one's magazine and reserve
## separately, and cycles them with the mouse wheel. `data` always points at the
## gun in hand, so the owner and the HUD can read it without knowing about slots.
##
## Fires hitscan rays from the camera centre. A shotgun is the same code with
## `pellets > 1`: the trigger pull fires that many rays inside one spread cone.
## Numbers that buffs change are read from Stats.
##
## The weapon never moves the camera itself: it emits `recoil` and the owner
## applies it, and the owner tells it whether it is aiming / moving / airborne.

signal fired
signal ammo_changed(current: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal hit_landed(headshot: bool, killed: bool)
## Degrees of camera kick for this shot. `manual` is the fraction that stays.
signal recoil(pitch: float, yaw: float, manual: float)
## The gun in hand changed, by wheel or by `select()`. The HUD names it.
signal selected(index: int, data: WeaponData)
## Camera shake for this shot, already scaled for aiming / scope: peak degrees,
## FOV punch as a fraction of the current FOV, and its length in seconds. Pure
## presentation; the owner applies it to the view, never to where bullets go.
signal shake(degrees: float, fov_punch: float, duration: float)
## The scope magnification changed. The HUD redraws its readout.
signal zoom_changed(level: float)

const SHOOT_MASK := CollisionLayers.WORLD | CollisionLayers.HITBOXES
## Voices for gunshots. A shot rings on its own voice, so a burst cannot cut the
## tail of the one before it (assigning a new stream to a playing
## AudioStreamPlayer stops it).
const SHOT_VOICES := 6
## Fixed seed for every random thing the player *sees or hears* from the gun
## (kick direction, pitch). Separate from the global generator, which belongs to
## the simulation (ADR 0005).
const FEEL_SEED := 0x6B1CC
## A scope drops the rotation shake and keeps this share of the FOV punch.
const SCOPED_PUNCH_SCALE := 0.5

## The guns carried, in wheel order. Must not be empty.
@export var data_set: Array[WeaponData] = []
@export var stats: Stats
@export var camera: Camera3D
## The shooter's body, excluded from the ray. Its `team` filters friendly fire.
@export var shooter: CollisionObject3D

## The gun in hand; always `data_set[index]`.
var data: WeaponData
var index := 0
var ammo := 0
var reserve := 0
var aiming := false
var moving := false
var airborne := false
## False while a melee swing owns the hands. See set_drawn().
var trigger_enabled := true
## Which of `data.scope_zoom_levels` the scope is on. Kept across switches and
## clamped when the new gun has fewer levels.
var zoom_index := 0

var _cooldown := 0.0
var _spread := 0.0
var _reload_left := 0.0
var _pattern_index := 0
var _views: Array[Node3D] = []
var _view: Node3D
## Optional `Muzzle/Flash` node in the view scene, shown for one frame per shot.
var _flash: Node3D
var _flash_left := 0.0
var _shot_voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
## Reload and dry-fire clicks. Never shares a voice with a gunshot.
var _handling_voice: AudioStreamPlayer
var _spring := ViewSpring.new()
var _view_base := Vector3.ZERO
## Impacts of the current shot that still get the full debris / droplet effect,
## so nine shotgun pellets do not spawn nine full sets.
var _detail_left := 0
## Tracers this shot may still draw (`data.max_tracers`).
var _tracers_left := 0
var _feel_rng := RandomNumberGenerator.new()
var _gunshots: Array[AudioStreamWAV] = []
var _reload_sound: AudioStreamWAV
var _dry_sound: AudioStreamWAV
## Per-slot state, so switching guns does not refill or empty anything.
var _slot_ammo: Array[int] = []
var _slot_reserve: Array[int] = []


func _ready() -> void:
	_reload_sound = ProceduralAudio.generate("reload")
	_dry_sound = ProceduralAudio.generate("dry")
	_feel_rng.seed = FEEL_SEED
	_handling_voice = AudioStreamPlayer.new()
	add_child(_handling_voice)
	for voice in SHOT_VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_shot_voices.append(player)
	for slot in data_set.size():
		var slot_data := data_set[slot]
		var view: Node3D = slot_data.view_scene.instantiate() if slot_data.view_scene != null \
			else _placeholder_view()
		view.visible = false
		add_child(view)
		_views.append(view)
		_slot_ammo.append(ceili(slot_data.magazine_size * _stat(Stats.MAGAZINE_SIZE)))
		_slot_reserve.append(slot_data.reserve_ammo)
		_gunshots.append(ProceduralAudio.generate(slot_data.gunshot_sound))
	if data_set.is_empty():
		push_warning("Weapon has an empty data_set: nothing to fire.")
		return
	select(0)
	if stats != null:
		stats.changed.connect(func(): ammo_changed.emit(ammo, reserve))


## Puts the gun at `new_index` in hand (wraps). Cancels a reload in progress, since
## the hands leave the gun; the magazine keeps whatever it had.
func select(new_index: int) -> void:
	if data_set.is_empty():
		return
	# Nothing to save on the very first call: `data` is still null and `ammo` is
	# just the zero the member was declared with, which must not overwrite the
	# slot's starting magazine.
	if data != null:
		_store_slot()
	_cooldown = 0.0
	_spread = 0.0
	_reload_left = 0.0
	_pattern_index = 0
	index = wrapi(new_index, 0, data_set.size())
	data = data_set[index]
	ammo = _slot_ammo[index]
	reserve = _slot_reserve[index]
	_view = _views[index]
	_spring.reset()
	_spring.stiffness = data.view_spring_stiffness
	_spring.damping = data.view_spring_damping
	zoom_index = clampi(zoom_index, 0, maxi(data.scope_zoom_levels.size() - 1, 0))
	_apply_view_visibility()
	_view_base = data.hip_position
	_view.position = _view_base
	_view.rotation = Vector3.ZERO
	_flash = _view.get_node_or_null("Muzzle/Flash")
	selected.emit(index, data)
	ammo_changed.emit(ammo, reserve)
	zoom_changed.emit(zoom_level())


## Positive steps go up the wheel (rifle -> shotgun -> sniper).
func select_next(step := 1) -> void:
	select(index + step)


## Aiming through a scope: the model goes away, the scope overlay takes over and
## the field of view is divided by the magnification.
func is_scoped() -> bool:
	return data != null and aiming and not data.scope_zoom_levels.is_empty()


func zoom_level() -> float:
	if data == null or data.scope_zoom_levels.is_empty():
		return 1.0
	return data.scope_zoom_levels[clampi(zoom_index, 0, data.scope_zoom_levels.size() - 1)]


## The wheel while scoped picks a magnification instead of another gun.
func cycle_zoom(step := 1) -> void:
	if data == null or data.scope_zoom_levels.is_empty():
		return
	var count := data.scope_zoom_levels.size()
	var next := wrapi(zoom_index + step, 0, count)
	if next == zoom_index:
		return
	zoom_index = next
	zoom_changed.emit(zoom_level())


## Field of view the camera should settle on: base when hip firing, the gun's own
## `ads_fov` for iron sights, and `base / magnification` behind a scope.
func fov_for(base_fov: float) -> float:
	if data == null or not aiming:
		return base_fov
	if is_scoped():
		return base_fov / maxf(zoom_level(), 1.0)
	return data.ads_fov


func magazine_capacity() -> int:
	return ceili(data.magazine_size * _stat(Stats.MAGAZINE_SIZE))


func is_reloading() -> bool:
	return _reload_left > 0.0


func reload_progress() -> float:
	if not is_reloading():
		return 0.0
	return 1.0 - _reload_left / _reload_duration(ammo == 0)


func spread_degrees() -> float:
	var total := (data.ads_spread if aiming else data.hip_spread) + _spread
	if airborne:
		total *= data.airborne_spread_scale
	elif moving:
		total *= data.move_spread_scale
	return total


func _process(delta: float) -> void:
	if data == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _flash != null and _flash_left > 0.0:
		_flash_left -= delta
		_flash.visible = _flash_left > 0.0
	_spread = move_toward(_spread, 0.0, data.spread_recovery * delta)
	var target := data.ads_position if aiming else data.hip_position
	_view_base = _view_base.lerp(target, minf(14.0 * delta, 1.0))
	_apply_view_pose(delta)
	# Behind a scope the model would fill the aperture, so it steps out of the way.
	_apply_view_visibility()

	if Input.is_action_just_pressed("weapon_next"):
		_cycle_wheel(1)
	elif Input.is_action_just_pressed("weapon_prev"):
		_cycle_wheel(-1)

	if is_reloading():
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
		return

	if Input.is_action_just_released("fire"):
		_pattern_index = 0
	if Input.is_action_just_pressed("reload"):
		try_reload()
		return
	var trigger := Input.is_action_pressed("fire") if data.fire_mode == WeaponData.FireMode.AUTO \
		else Input.is_action_just_pressed("fire")
	if trigger and trigger_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_fire()


## ADS / hip position, plus whatever the shot spring is still doing on top.
func _apply_view_pose(delta: float) -> void:
	_spring.step(delta)
	_view.position = _view_base + _spring.position
	_view.rotation = Vector3(deg_to_rad(_spring.rotation.x), deg_to_rad(_spring.rotation.y),
		deg_to_rad(_spring.rotation.z))


## Hides the gun while a melee weapon is swung. `false` also ignores the trigger,
## so no shot comes out of a weapon that is not on screen; the cooldown and
## reload timers keep running, so the swap costs nothing.
func set_drawn(drawn: bool) -> void:
	trigger_enabled = drawn
	_apply_view_visibility()


## Only the gun in hand is shown, and never behind the glass of its own scope.
func _apply_view_visibility() -> void:
	for slot in _views.size():
		_views[slot].visible = trigger_enabled and slot == index and not is_scoped()


## The wheel has two jobs: change magnification behind a scope, and change guns
## everywhere else.
func _cycle_wheel(step: int) -> void:
	if is_scoped():
		cycle_zoom(step)
	else:
		select_next(step)


func try_fire() -> bool:
	if data == null or _cooldown > 0.0 or is_reloading():
		return false
	if ammo <= 0:
		if reserve > 0:
			try_reload()
		elif Input.is_action_just_pressed("fire"):
			_play_handling(_dry_sound, -4.0)
		return false

	ammo -= 1
	_cooldown = data.fire_interval / _stat(Stats.FIRE_RATE)
	var spread := spread_degrees()
	_detail_left = 3
	_tracers_left = data.max_tracers
	for pellet in maxi(data.pellets, 1):
		_shoot_ray(camera.global_position, _spread_direction(-camera.global_basis.z, spread))
	_spread = minf(_spread + data.spread_per_shot, data.max_spread)

	_play_shot(_gunshots[index])
	if _flash != null:
		_flash.rotation.z = randf() * TAU
		_flash.visible = true
		_flash_left = 0.04
	_kick_view()
	recoil.emit(data.camera_kick, data.camera_kick * _next_pattern_value(), data.recoil_manual)
	fired.emit()
	Events.gunshot.emit(global_position)
	ammo_changed.emit(ammo, reserve)
	if ammo == 0 and reserve > 0:
		try_reload()
	return true


func try_reload() -> void:
	if data == null or is_reloading() or reserve <= 0 or ammo >= magazine_capacity():
		return
	_reload_left = _reload_duration(ammo == 0)
	_play_handling(_reload_sound, -2.0)
	reload_started.emit(_reload_left)


func _finish_reload() -> void:
	_reload_left = 0.0
	var taken := mini(magazine_capacity() - ammo, reserve)
	ammo += taken
	reserve -= taken
	reload_finished.emit()
	ammo_changed.emit(ammo, reserve)


func _reload_duration(empty: bool) -> float:
	var base_time := data.reload_time_empty if empty else data.reload_time_tactical
	return base_time / _stat(Stats.RELOAD_SPEED)


## One pellet's ray. Every pellet runs this, so a shotgun is just more of them.
func _shoot_ray(origin: Vector3, direction: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * data.max_range, SHOOT_MASK)
	if shooter != null:
		query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var effects_parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	if _tracers_left > 0:
		_tracers_left -= 1
		Tracer.spawn(effects_parent, _muzzle_position(origin),
			hit.position if not hit.is_empty() else origin + direction * data.max_range)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	Impact.spawn(effects_parent, hit.position, hit.normal, collider is Hitbox, _detail_left > 0)
	_detail_left -= 1
	if collider is Hitbox:
		var hitbox := collider as Hitbox
		var distance := origin.distance_to(hit.position)
		var dealt := hitbox.apply_hit(data.damage * _stat(Stats.DAMAGE) * _falloff(distance), shooter)
		if dealt > 0.0:
			hit_landed.emit(hitbox.body_part == Hitbox.BodyPart.HEAD, hitbox.health.is_dead())


func _falloff(distance: float) -> float:
	if distance <= data.falloff_start:
		return 1.0
	if distance >= data.falloff_end:
		return data.min_damage_scale
	var t := (distance - data.falloff_start) / maxf(data.falloff_end - data.falloff_start, 0.001)
	return lerpf(1.0, data.min_damage_scale, t)


func _spread_direction(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction
	var rad := deg_to_rad(degrees)
	var basis := camera.global_basis
	return direction.rotated(basis.x, randf_range(-rad, rad)).rotated(basis.y, randf_range(-rad, rad)).normalized()


func _next_pattern_value() -> float:
	var value := 0.35 if _pattern_index % 2 == 0 else -0.35
	if not data.recoil_pattern.is_empty():
		value = data.recoil_pattern[_pattern_index % data.recoil_pattern.size()]
	_pattern_index += 1
	return value


func _stat(stat: StringName) -> float:
	return stats.get_value(stat) if stats != null else 1.0


func _store_slot() -> void:
	if _slot_ammo.size() <= index:
		return
	_slot_ammo[index] = ammo
	_slot_reserve[index] = reserve


## Gunshot on the next free voice, with a little pitch and level variation. If
## all voices are busy the oldest one is taken over.
## Where a tracer starts: the model's muzzle, or the eye when the model has none.
func _muzzle_position(fallback: Vector3) -> Vector3:
	return (_flash.get_parent() as Node3D).global_position if _flash != null else fallback


func _play_shot(stream: AudioStream) -> void:
	var voice := _shot_voices[_next_voice]
	for offset in SHOT_VOICES:
		var candidate := _shot_voices[(_next_voice + offset) % SHOT_VOICES]
		if not candidate.playing:
			voice = candidate
			_next_voice = (_next_voice + offset) % SHOT_VOICES
			break
	_next_voice = (_next_voice + 1) % SHOT_VOICES
	if voice.stream != stream:
		voice.stream = stream
	voice.pitch_scale = 1.0 + _feel_rng.randf_range(-0.05, 0.05)
	voice.volume_db = _feel_rng.randf_range(-0.6, 0.0)
	voice.play()


func _play_handling(stream: AudioStream, volume_db := 0.0) -> void:
	_handling_voice.stream = stream
	_handling_voice.volume_db = volume_db
	_handling_voice.play()


## The viewmodel spring and the camera shake for one shot. Both shrink while
## aiming; behind a scope there is no rotation shake, only a small FOV punch.
func _kick_view() -> void:
	var feel := data.aim_feel_scale if aiming else 1.0
	_spring.kick(
		Vector3(0.0, 0.0, data.view_kick_back) * feel,
		Vector3(data.view_kick_pitch, _feel_rng.randf_range(-1.0, 1.0) * data.view_kick_yaw,
			_feel_rng.randf_range(-1.0, 1.0) * data.view_kick_roll) * feel)
	if is_scoped():
		shake.emit(0.0, data.shake_fov_punch * feel * SCOPED_PUNCH_SCALE, data.shake_duration)
	else:
		shake.emit(data.shake_degrees * feel, data.shake_fov_punch * feel, data.shake_duration)


func _placeholder_view() -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.1, 0.5)
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh
