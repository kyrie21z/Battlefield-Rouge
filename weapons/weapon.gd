class_name Weapon
extends Node3D
## Single obsidian pistol. Hitscan and Stats stay here; its four-piece view
## receives the same normalized reload clock as the magazine. No loadout slots.

signal fired
signal ammo_changed(current: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
## Emitted exactly once, on the frame the crystal closes and ammo becomes full.
signal ammo_refilled
signal hit_landed(headshot: bool, killed: bool)
## A shield or barrier cancelled the hit; listeners answer with a block cue and
## the world gets deflect sparks instead of ordinary crystal shards.
signal hit_blocked(point: Vector3, normal: Vector3)
## A target evaded the shot before damage applied.
signal hit_evaded(point: Vector3)
## Degrees of camera kick for this shot. `manual` is the fraction that stays.
signal recoil(pitch: float, yaw: float, manual: float)
## Camera shake for this shot, already scaled for aiming: peak degrees,
## FOV punch as a fraction of the current FOV, and its length in seconds. Pure
## presentation; the owner applies it to the view, never to where bullets go.
signal shake(degrees: float, fov_punch: float, duration: float)
const CRYSTAL_IMPACT := preload("res://weapons/effects/crystal_impact.gd")
const SNAP_FLASH_TIME := 0.06
const SHOOT_MASK := CollisionLayers.WORLD | CollisionLayers.HITBOXES
## Voices for gunshots. A shot rings on its own voice, so a burst cannot cut the
## tail of the one before it (assigning a new stream to a playing
## AudioStreamPlayer stops it).
const SHOT_VOICES := 6
## Fixed seed for every random thing the player *sees or hears* from the gun
## (kick direction, pitch). Separate from the global generator, which belongs to
## the simulation (ADR 0005).
const FEEL_SEED := 0x6B1CC
## Per-shot playback variation: pitch and level, from the private feel generator.
const SHOT_PITCH_JITTER := 0.05
const SHOT_VOLUME_JITTER_DB := 1.0
## A burst overlaps several voices; from this count on the incoming shot is
## quieter, so rapid pistol fire does not grow louder and harsher.
const SHOT_VOICE_DUCK_COUNT := 3
const SHOT_VOICE_DUCK_DB := -2.0

@export var data: WeaponData = preload("res://weapons/obsidian_pistol/obsidian_pistol.tres")
@export var stats: Stats
@export var camera: Camera3D
## The shooter's body, excluded from the ray. Its `team` filters friendly fire.
@export var shooter: CollisionObject3D

var ammo := 0
## Negative reserve means energy is regenerated, not taken from an ammo bag.
var reserve := -1
var aiming := false
var moving := false
var airborne := false
## Gameplay can disable the trigger while keeping presentation alive.
var trigger_enabled := true
var _cooldown := 0.0
var _spread := 0.0
var _reload_left := 0.0
var _reload_total := 0.85
var _melee_active := false
var _view: Node3D
## Optional `Muzzle/Flash` node in the view scene, shown for one frame per shot.
var _flash: Node3D
var _flash_left := 0.0
var _shot_voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
## Reload and dry-fire clicks. Never shares a voice with a gunshot.
var _handling_voice: AudioStreamPlayer
## Low-ammo crystal tick. Its own voice, so it layers over a gunshot tail.
var _low_ammo_sound: AudioStreamWAV
var _low_ammo_voice: AudioStreamPlayer
var _spring := ViewSpring.new()
var _view_base := Vector3.ZERO
## Impacts of the current shot that still get the full debris / droplet effect,
## so effects have a bounded cost.
var _detail_left := 0
## Tracers this shot may still draw (`data.max_tracers`).
var _tracers_left := 0
var _feel_rng := RandomNumberGenerator.new()
var _gunshot: AudioStreamWAV
var _reload_sound: AudioStreamWAV
var _dry_sound: AudioStreamWAV
func _ready() -> void:
	_reload_sound = ProceduralAudio.generate("hit_tink")
	_dry_sound = ProceduralAudio.generate("dry")
	_feel_rng.seed = FEEL_SEED
	_handling_voice = AudioStreamPlayer.new()
	add_child(_handling_voice)
	_low_ammo_sound = ProceduralAudio.generate("pistol_low_ammo")
	_low_ammo_voice = AudioStreamPlayer.new()
	_low_ammo_voice.stream = _low_ammo_sound
	add_child(_low_ammo_voice)
	for voice in SHOT_VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_shot_voices.append(player)
	if data == null:
		push_error("Weapon requires pistol data")
		return
	_view = data.view_scene.instantiate() if data.view_scene != null else _placeholder_view()
	add_child(_view)
	ammo = magazine_capacity()
	reserve = data.reserve_ammo
	_gunshot = ProceduralAudio.generate(data.gunshot_sound)
	_spring.stiffness = data.view_spring_stiffness
	_spring.damping = data.view_spring_damping
	_view_base = data.hip_position
	_view.position = _view_base
	_flash = _view.get_node_or_null("Muzzle/Flash")
	ammo_changed.emit(ammo, reserve)
	if stats != null:
		stats.changed.connect(func(): ammo_changed.emit(ammo, reserve))


func _exit_tree() -> void:
	for voice in _shot_voices:
		voice.stop()
		voice.stream = null
	if _handling_voice != null:
		_handling_voice.stop()
		_handling_voice.stream = null
	if _low_ammo_voice != null:
		_low_ammo_voice.stop()
		_low_ammo_voice.stream = null


## World-space grip frame for the owning player's hand rig. The imported
## pistol root is centred on the grip; internal reassembly pieces stay separate.
func grip_transform() -> Transform3D:
	return _view.global_transform if is_instance_valid(_view) else global_transform


func fov_for(base_fov: float) -> float:
	return data.ads_fov if data != null and aiming else base_fov


func magazine_capacity() -> int:
	return ceili(data.magazine_size * _stat(Stats.MAGAZINE_SIZE))


func is_reloading() -> bool:
	return _reload_left > 0.0


func reload_progress() -> float:
	if not is_reloading():
		return 0.0
	return clampf(1.0 - _reload_left / _reload_total, 0.0, 1.0)


func spread_degrees() -> float:
	var total := (data.ads_spread if aiming else data.hip_spread) + _spread
	if airborne:
		total *= data.airborne_spread_scale
	elif moving:
		total *= data.move_spread_scale
	return total


func _process(delta: float) -> void:
	if get_tree().paused or data == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _flash != null and _flash_left > 0.0:
		_flash_left -= delta
		_flash.visible = _flash_left > 0.0
	_spread = move_toward(_spread, 0.0, data.spread_recovery * delta)
	var target := data.ads_position if aiming else data.hip_position
	if _melee_active:
		target += Vector3(0.07, -0.015, 0.015)
	_view_base = _view_base.lerp(target, minf(14.0 * delta, 1.0))
	_apply_view_pose(delta)
	if is_reloading():
		_reload_left = maxf(_reload_left - delta * _stat(Stats.RELOAD_SPEED) / _reload_start_speed, 0.0)
		_update_reassembly(1.0 - _reload_left / _reload_total)
		if _reload_left <= 0.000001:
			_finish_reload()
		return

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


## Quick blade attacks keep the pistol in hand and only make room to the right.
func set_melee_active(active: bool) -> void:
	_melee_active = active


## Death/teardown cancels recharge without granting a magazine or snap signal.
func deactivate() -> void:
	trigger_enabled = false
	_reload_left = 0.0
	_melee_active = false
	_update_reassembly(1.0)
	if _view.has_method("reset_fire_feedback"):
		_view.reset_fire_feedback()
	_spring.reset()
	if _flash != null:
		_flash.hide()
	if _low_ammo_voice != null:
		_low_ammo_voice.stop()
	if _handling_voice != null:
		_handling_voice.stop()
	set_process(false)


func _update_reassembly(progress: float) -> void:
	if _view.has_method("set_reassembly_progress"):
		_view.set_reassembly_progress(progress)


var boon_hook: Callable
var _shot_context: Dictionary = {}
var _reload_empty := false
var _reload_start_speed := 1.0

func _boon(event: StringName, context: Dictionary) -> void:
	if boon_hook.is_valid():
		boon_hook.call(event, context)

func try_fire() -> bool:
	if get_tree().paused or data == null or not trigger_enabled or _cooldown > 0.0 or is_reloading():
		return false
	if ammo <= 0:
		if reserve != 0:
			try_reload()
		elif Input.is_action_just_pressed("fire"):
			_play_handling(_dry_sound, -4.0)
		return false

	_shot_context = {"weapon": self, "source": shooter, "origin": camera.global_position,
		"direction": -camera.global_basis.z, "damage_multiplier": 1.0, "proc_depth": 0, "tag": &"gun"}
	_boon(&"shoot_before", _shot_context)
	ammo -= 1
	_cooldown = data.fire_interval / _stat(Stats.FIRE_RATE)
	var spread := spread_degrees()
	_detail_left = 3
	_tracers_left = data.max_tracers
	if not _shot_context.get("cancel_primary", false):
		for pellet in maxi(data.pellets, 1):
			_shoot_ray(_shot_context.origin, _spread_direction(_shot_context.direction, spread))
	_spread = minf(_spread + data.spread_per_shot, data.max_spread)

	_play_shot(_gunshot)
	if ammo <= 2:
		_low_ammo_voice.play()
	if _flash != null:
		_flash.rotation.z = _feel_rng.randf() * TAU
		_flash.visible = true
		_flash_left = 0.04
	_kick_view()
	if _view.has_method("kick_fire"):
		_view.kick_fire()
	recoil.emit(data.camera_kick, _feel_rng.randf_range(-data.camera_yaw, data.camera_yaw), data.recoil_manual)
	fired.emit()
	_boon(&"shoot_fired", _shot_context)
	Events.gunshot.emit(global_position)
	ammo_changed.emit(ammo, reserve)
	if ammo == 0 and reserve != 0:
		try_reload(true)
	return true


func try_reload(keep_muzzle_light := false) -> void:
	if get_tree().paused or data == null or not trigger_enabled or is_reloading() or reserve == 0 or ammo >= magazine_capacity():
		return
	_reload_empty = ammo == 0
	_reload_start_speed = maxf(_stat(Stats.RELOAD_SPEED), 0.001)
	_reload_total = _reload_duration(_reload_empty)
	_reload_left = _reload_total
	_update_reassembly(0.0)
	if _view.has_method("reset_fire_feedback"):
		_view.reset_fire_feedback(keep_muzzle_light)
	reload_started.emit(_reload_left)
	_boon(&"reload_started", {"source": shooter, "weapon": self, "empty": _reload_empty, "ammo": ammo})


func _finish_reload() -> void:
	_reload_left = 0.0
	_update_reassembly(1.0)
	var taken := magazine_capacity() - ammo
	if reserve >= 0:
		taken = mini(taken, reserve)
		reserve -= taken
	ammo += taken
	_play_handling(_reload_sound, -4.0)
	if _flash != null:
		_flash.visible = true
		_flash_left = SNAP_FLASH_TIME
	ammo_refilled.emit()
	reload_finished.emit()
	_boon(&"reload_finished", {"source": shooter, "weapon": self, "empty": _reload_empty, "ammo": ammo})
	ammo_changed.emit(ammo, reserve)


func _reload_duration(empty: bool) -> float:
	var base_time := data.reload_time_empty if empty else data.reload_time_tactical
	return base_time / _stat(Stats.RELOAD_SPEED)


## One hit ray, separate from the visual recoil camera.
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
	if collider is Hitbox:
		var hitbox := collider as Hitbox
		var distance := origin.distance_to(hit.position)
		var damage := data.damage * _stat(Stats.DAMAGE) * _falloff(distance) * float(_shot_context.get("damage_multiplier", 1.0))
		var ctx := {"kind": &"gun", "tag": &"gun", "proc_depth": 0, "source": shooter,
			"target": hitbox.health.get_parent(), "health": hitbox.health, "hitbox": hitbox,
			"position": hit.position, "direction": direction, "damage": damage, "base_damage": damage,
			"body_part": hitbox.body_part, "critical": false, "critical_multiplier": 1.0, "cancelled": false,
			"damage_scaled": true}
		_boon(&"hit_before", ctx)
		var hp_before := hitbox.health.health
		var dealt := 0.0 if ctx.cancelled else hitbox.apply_hit_at(maxf(ctx.damage, 0.0), shooter, hit.position, direction, true, ctx)
		ctx.dealt = minf(dealt, hp_before)
		ctx.killed = hitbox.health.is_dead()
		_boon(&"hit_after", ctx)
		if hitbox.surface_blocked:
			CRYSTAL_IMPACT.spawn_deflect(effects_parent, hit.position, hit.normal)
			hit_blocked.emit(hit.position, hit.normal)
		elif hitbox.surface_evaded:
			hit_evaded.emit(hit.position)
		else:
			CRYSTAL_IMPACT.spawn(effects_parent, hit.position, hit.normal,
				hitbox.body_part == Hitbox.BodyPart.HEAD)
		if dealt > 0.0:
			hit_landed.emit(hitbox.body_part == Hitbox.BodyPart.HEAD, hitbox.health.is_dead())
	else:
		Impact.spawn(effects_parent, hit.position, hit.normal, false, _detail_left > 0)
	_detail_left -= 1


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


func _stat(stat: StringName) -> float:
	return stats.get_value(stat) if stats != null else 1.0


## Gunshot on the next free voice, with a little pitch and level variation. If
## all voices are busy the oldest one is taken over.
## Where a tracer starts: the model's muzzle, or the eye when the model has none.
func _muzzle_position(fallback: Vector3) -> Vector3:
	return (_flash.get_parent() as Node3D).global_position if _flash != null else fallback


func _play_shot(stream: AudioStream) -> void:
	var voice := _shot_voices[_next_voice]
	var playing := 0
	for player in _shot_voices:
		if player.playing:
			playing += 1
	for offset in SHOT_VOICES:
		var candidate := _shot_voices[(_next_voice + offset) % SHOT_VOICES]
		if not candidate.playing:
			voice = candidate
			_next_voice = (_next_voice + offset) % SHOT_VOICES
			break
	_next_voice = (_next_voice + 1) % SHOT_VOICES
	if voice.stream != stream:
		voice.stream = stream
	voice.pitch_scale = 1.0 + _feel_rng.randf_range(-SHOT_PITCH_JITTER, SHOT_PITCH_JITTER)
	voice.volume_db = _feel_rng.randf_range(-SHOT_VOLUME_JITTER_DB, SHOT_VOLUME_JITTER_DB)
	if playing >= SHOT_VOICE_DUCK_COUNT:
		voice.volume_db += SHOT_VOICE_DUCK_DB
	voice.play()


func _play_handling(stream: AudioStream, volume_db := 0.0) -> void:
	_handling_voice.stream = stream
	_handling_voice.volume_db = volume_db
	_handling_voice.play()


## The viewmodel spring and the camera shake for one shot. Both shrink while
## aiming; both effects are presentation only.
func _kick_view() -> void:
	var feel := data.aim_feel_scale if aiming else 1.0
	_spring.kick(
		Vector3(0.0, 0.0, data.view_kick_back) * feel,
		Vector3(data.view_kick_pitch, _feel_rng.randf_range(-1.0, 1.0) * data.view_kick_yaw,
			_feel_rng.randf_range(-1.0, 1.0) * data.view_kick_roll) * feel)
	shake.emit(data.shake_degrees * feel, data.shake_fov_punch * feel, data.shake_duration)


func _placeholder_view() -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.1, 0.5)
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## Abilities may finish the current reassembly through the normal refill path.
func complete_reload() -> bool:
	if not is_reloading():
		return false
	_finish_reload()
	return true
