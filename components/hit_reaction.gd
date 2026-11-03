class_name HitReaction
extends Node
## What a body looks like when it is shot: a white flash over the model for
## ~0.06 s and a small flinch away from the shooter. Visual only.
##  - The flash is a `material_overlay` on the model's meshes; their own
##    materials are untouched.
##  - The flinch moves the *mesh nodes* (a skinned mesh honours its own node
##    transform) about the body's feet and puts them back exactly. The
##    skeleton, the bone attachments and so the hitboxes never move, so where
##    the next bullet lands is exactly what it was.
##  - It never reads or writes the owner's AI state, velocity, navigation,
##    timers or any random number.
## Put it next to a Health node, as a child of the body that owns a `Model`.

const FLASH_TIME := 0.06
const FLINCH_TIME := 0.14
const FLASH_ALPHA := 0.7

## Degrees of lean and metres of shove at full strength. A bigger body can ask
## for less with `flinch_scale`.
@export var flinch_degrees := 3.5
@export var flinch_shove := 0.035
@export var flinch_scale := 1.0
@export var flinch_enabled := true

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


func _ready() -> void:
	_body = get_parent() as Node3D
	_health = _body.get_node_or_null("Health") as Health if _body != null else null
	if _health != null:
		_health.damaged.connect(_on_damaged)
	set_process(false)
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1.0, 1.0, 1.0, 0.0)


## True while either effect is playing. For tests.
func is_playing() -> bool:
	return _flash_left > 0.0 or _flinch_left > 0.0


func _on_damaged(_amount: float, part: Hitbox.BodyPart, source: Node) -> void:
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
	for mesh in _meshes:
		mesh.material_overlay = _overlay
	if flinch_enabled and not _health.is_dead() and from != null:
		var away := _body.global_position - from.global_position
		away.y = 0.0
		if away.length() > 0.001:
			away = away.normalized()
			_flinch_axis = Vector3.UP.cross(away).normalized()
			_flinch_push = away
			_flinch_strength = flinch_scale * (1.4 if heavy else 1.0)
			_flinch_left = FLINCH_TIME
	set_process(true)


func _process(delta: float) -> void:
	if _model == null or not is_instance_valid(_model):
		_finish()
		return
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_overlay.albedo_color.a = FLASH_ALPHA * (_flash_left / FLASH_TIME)
	if _flinch_left > 0.0:
		_flinch_left = maxf(_flinch_left - delta, 0.0)
		var fade := _flinch_left / FLINCH_TIME
		_pose_meshes(fade * fade * _flinch_strength)
	if _flash_left <= 0.0 and _flinch_left <= 0.0:
		_finish()


## Leans every mesh about the body's feet and shoves it, in world space, whatever
## its parent is doing (a held weapon rides an animated bone).
func _pose_meshes(envelope: float) -> void:
	var pivot := _body.global_position
	var tilt := Basis(_flinch_axis, deg_to_rad(flinch_degrees) * envelope)
	var delta_world := Transform3D(tilt, pivot - tilt * pivot + _flinch_push * flinch_shove * envelope)
	for i in _meshes.size():
		var mesh := _meshes[i]
		if not is_instance_valid(mesh):
			continue
		var parent := mesh.get_parent_node_3d()
		var parent_global := parent.global_transform
		mesh.transform = parent_global.affine_inverse() * delta_world * parent_global * _rest[i]


func _finish() -> void:
	for i in _meshes.size():
		if is_instance_valid(_meshes[i]):
			if _meshes[i].material_overlay == _overlay:
				_meshes[i].material_overlay = null
			_meshes[i].transform = _rest[i]
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
