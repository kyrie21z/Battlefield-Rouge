class_name HitReaction
extends Node
## What a body looks like when it is shot: flash, flinch, headshot sparks and,
## on death, a held lean plus a chunk burst. Visual only.
##  - It moves the *mesh nodes* about the body's feet, never the skeleton, the
##    hitboxes or the CharacterBody, so where the next bullet lands is untouched.
##  - It never reads or writes the owner's AI state, velocity, navigation,
##    timers or any random number.
## Put it next to a Health node, as a child of the body that owns a `Model`.

const FLASH_TIME := 0.08
const FLINCH_TIME := 0.14
const FLASH_ALPHA := 0.7
## Death lean: held through the Death animation, so a kill reads as a hit.
const DEATH_LEAN_DEGREES := 23.0
const DEATH_LEAN_TIME := 0.16
const DEATH_LEAN_SHOVE := 0.09
## Death burst sizes; a headshot starts at the head and bursts bigger.
const DEATH_BURST_SCALE := 1.0
const HEAD_BURST_SCALE := 1.6
const SPARK_BURST_SCALE := 1.0
## Short bright light at the burst point; it frees itself after the fade.
const DEATH_LIGHT_TIME := 0.12
const DEATH_LIGHT_ENERGY := 6.0
const DEATH_LIGHT_RANGE := 3.5
const DEATH_LIGHT_COLOR := Color(1.0, 0.86, 0.62)

## Degrees of lean and metres of shove at full strength. A bigger body can ask
## for less with `flinch_scale`.
@export var flinch_degrees := 6.0
@export var flinch_shove := 0.06
@export var flinch_scale := 1.0
@export var flinch_enabled := true
## Multiplies the death burst and its light; the boss sets 2.5.
@export var death_scale := 1.0

var _health: Health
var _body: Node3D
var _model: Node3D
var _meshes: Array[MeshInstance3D] = []
var _rest: Array[Transform3D] = []
var _overlay: StandardMaterial3D
var _flash_left := 0.0
var _flinch_left := 0.0
var _flinch_axis := Vector3.RIGHT
var _flinch_strength := 1.0
var _flinch_push := Vector3.ZERO
## Body part of the last damage, so the death burst knows whether it was a head.
var _last_part := Hitbox.BodyPart.BODY
var _dead := false
var _death_envelope := 0.0
var _death_light: OmniLight3D
var _death_light_energy := 0.0
var _death_light_left := 0.0
## The last death burst, for tests.
var death_burst: DebrisBurst


func _ready() -> void:
	_body = get_parent() as Node3D
	_health = _body.get_node_or_null("Health") as Health if _body != null else null
	if _health != null:
		_health.damaged.connect(_on_damaged)
		_health.died.connect(_on_died)
	set_process(false)
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1.0, 1.0, 1.0, 0.0)


## True while either effect is playing. For tests.
func is_playing() -> bool:
	return _flash_left > 0.0 or _flinch_left > 0.0


func _on_damaged(_amount: float, part: Hitbox.BodyPart, source: Node) -> void:
	_last_part = part
	# Only the player's hits (team 0) show this; being shot by friends or the
	# environment does not matter here.
	if source == null or not ("team" in source) or source.team != 0:
		return
	play(source as Node3D, part == Hitbox.BodyPart.HEAD)


## Starts a flash and, if allowed and the body is alive, a flinch away from `from`.
func play(from: Node3D, heavy := false) -> void:
	if not _acquire_model():
		return
	_flash_left = FLASH_TIME
	_overlay.albedo_color.a = FLASH_ALPHA
	for mesh in _meshes:
		mesh.material_overlay = _overlay
	var away := Vector3.ZERO
	if from != null:
		away = _body.global_position - from.global_position
		away.y = 0.0
		if away.length() > 0.001:
			away = away.normalized()
	if flinch_enabled and not _health.is_dead() and away != Vector3.ZERO:
		_flinch_axis = Vector3.UP.cross(away).normalized()
		_flinch_push = away
		_flinch_strength = flinch_scale * (1.4 if heavy else 1.0)
		_flinch_left = FLINCH_TIME
	if heavy and not _health.is_dead():
		DebrisBurst.spawn_sparks(_body.get_parent(), _part_point(Hitbox.BodyPart.HEAD),
			away if away != Vector3.ZERO else Vector3.UP, SPARK_BURST_SCALE)
	set_process(true)


## Killed: lean the meshes away from the shooter for good and throw the body's
## chunks. The CharacterBody and the collision shapes are not touched.
func _on_died(source: Node) -> void:
	if _dead:
		return
	if not _acquire_model():
		return
	_dead = true
	var away := _body.global_basis.z
	if source is Node3D:
		var from := source as Node3D
		away = _body.global_position - from.global_position
		away.y = 0.0
	if away.length() < 0.001:
		away = _body.global_basis.z
	away.y = 0.0
	away = away.normalized()
	_flinch_axis = Vector3.UP.cross(away).normalized()
	_flinch_push = away
	_death_envelope = 0.0
	_spawn_death_effects(_last_part == Hitbox.BodyPart.HEAD, away)
	set_process(true)


func _process(delta: float) -> void:
	if _model == null or not is_instance_valid(_model):
		_finish()
		return
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_overlay.albedo_color.a = FLASH_ALPHA * (_flash_left / FLASH_TIME)
		if _flash_left <= 0.0:
			_clear_overlay()
	if _dead:
		_death_envelope = minf(_death_envelope + delta / maxf(DEATH_LEAN_TIME, 0.001), 1.0)
		_pose_meshes(_death_envelope, DEATH_LEAN_DEGREES * flinch_scale, DEATH_LEAN_SHOVE)
	elif _flinch_left > 0.0:
		_flinch_left = maxf(_flinch_left - delta, 0.0)
		var fade := _flinch_left / FLINCH_TIME
		_pose_meshes(fade * fade * _flinch_strength, flinch_degrees, flinch_shove)
	_update_death_light(delta)
	if not _dead and _flash_left <= 0.0 and _flinch_left <= 0.0:
		_finish()


## Leans every mesh about the body's feet and shoves it, in world space, whatever
## its parent is doing (a held weapon rides an animated bone).
func _pose_meshes(envelope: float, degrees: float, shove: float) -> void:
	var pivot := _body.global_position
	var tilt := Basis(_flinch_axis, deg_to_rad(degrees) * envelope)
	var delta_world := Transform3D(tilt, pivot - tilt * pivot + _flinch_push * shove * envelope)
	for i in _meshes.size():
		var mesh := _meshes[i]
		if not is_instance_valid(mesh):
			continue
		var parent := mesh.get_parent_node_3d()
		var parent_global := parent.global_transform
		mesh.transform = parent_global.affine_inverse() * delta_world * parent_global * _rest[i]


func _spawn_death_effects(head: bool, away: Vector3) -> void:
	var parent := _body.get_parent()
	if parent == null:
		return
	var point := _part_point(Hitbox.BodyPart.HEAD) if head else _part_point(Hitbox.BodyPart.BODY)
	var scale := death_scale * (HEAD_BURST_SCALE if head else DEATH_BURST_SCALE)
	death_burst = DebrisBurst.spawn_death(parent, point, away, scale)
	_death_light = OmniLight3D.new()
	_death_light.light_color = DEATH_LIGHT_COLOR
	_death_light_energy = DEATH_LIGHT_ENERGY * clampf(scale, 0.6, 3.0)
	_death_light.light_energy = _death_light_energy
	_death_light.omni_range = DEATH_LIGHT_RANGE * clampf(scale, 1.0, 3.0)
	_death_light.shadow_enabled = false
	parent.add_child(_death_light)
	_death_light.global_position = point
	_death_light_left = DEATH_LIGHT_TIME
	# The enemy can outlive the light or be freed first; the timer owns it. The
	# weak reference keeps the timer from holding a freed node.
	var weak: WeakRef = weakref(_death_light)
	get_tree().create_timer(DEATH_LIGHT_TIME * 2.0).timeout.connect(
		func() -> void:
			var light: Object = weak.get_ref()
			if light != null:
				light.queue_free())


func _update_death_light(delta: float) -> void:
	if _death_light == null:
		return
	if not is_instance_valid(_death_light):
		_death_light = null
		return
	_death_light_left = maxf(_death_light_left - delta, 0.0)
	_death_light.light_energy = _death_light_energy * (_death_light_left / DEATH_LIGHT_TIME)
	if _death_light_left <= 0.0:
		_death_light.queue_free()
		_death_light = null


func _part_point(part: Hitbox.BodyPart) -> Vector3:
	for node in _body.find_children("*", "Hitbox", true, false):
		var hitbox := node as Hitbox
		if hitbox.body_part == part:
			return hitbox.global_position
	var height := 1.6 if part == Hitbox.BodyPart.HEAD else 1.0
	return _body.global_position + Vector3(0.0, height, 0.0)


func _clear_overlay() -> void:
	for mesh in _meshes:
		if is_instance_valid(mesh) and mesh.material_overlay == _overlay:
			mesh.material_overlay = null


func _finish() -> void:
	if not _dead:
		for i in _meshes.size():
			if is_instance_valid(_meshes[i]):
				_meshes[i].transform = _rest[i]
	_clear_overlay()
	_flash_left = 0.0
	_flinch_left = 0.0
	set_process(false)


## Finds the body's current Model (the boss swaps it in `_ready`) and remembers
## where each mesh sits at rest. Returns false when there is nothing to show it on.
func _acquire_model() -> bool:
	var model := _body.get_node_or_null("Model") as Node3D if _body != null else null
	if model == null:
		return false
	if model != _model:
		_finish()
		_model = model
		_meshes.clear()
		_rest.clear()
		for node in model.find_children("*", "MeshInstance3D", true, false):
			_meshes.append(node as MeshInstance3D)
			_rest.append((node as MeshInstance3D).transform)
	return true
