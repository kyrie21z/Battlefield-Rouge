class_name Hammer
extends Node3D
## The objective hammer. The `hammer` action plays a short swing and emits
## `swung`; whether it hit anything is up to whoever listens (see
## CapturePoint). The model is a placeholder, shown only during a swing.

signal swung

## Minimum seconds between swings. A rule of the strike rather than a playtest
## knob (docs/adr/0003-hammer-capture-timing.md): it keeps mashing the key
## slower than hitting the beat.
const SWING_COOLDOWN := 0.9
const RAISED_POSITION := Vector3(0.32, -0.5, -0.45)
const RAISED_ROTATION_X := 55.0
const STRUCK_POSITION := Vector3(0.12, -0.38, -0.8)
const STRUCK_ROTATION_X := -50.0
const RESTING_POSITION := Vector3(0.42, -0.85, -0.5)

var _cooldown := 0.0
var _tween: Tween
var _model := Node3D.new()
var _audio := AudioStreamPlayer.new()


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.27, 0.15)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.35, 0.36, 0.4)
	iron.metallic = 0.6
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.025
	handle_mesh.bottom_radius = 0.03
	handle_mesh.height = 0.7
	handle.mesh = handle_mesh
	handle.material_override = wood
	handle.position.y = 0.35
	_model.add_child(handle)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.14, 0.16, 0.3)
	head.mesh = head_mesh
	head.material_override = iron
	head.position.y = 0.72
	_model.add_child(head)
	_model.visible = false
	add_child(_model)
	_audio.stream = ProceduralAudio.generate("melee_swing_heavy")
	add_child(_audio)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown <= 0.0 and Input.is_action_just_pressed("hammer"):
		_swing()


func _swing() -> void:
	_cooldown = SWING_COOLDOWN
	_audio.play()
	if _tween != null:
		_tween.kill()
	# The hammer starts already raised, so the blow lands a moment after the
	# press and the feedback does not run ahead of what the player sees.
	_model.position = RAISED_POSITION
	_model.rotation_degrees = Vector3(RAISED_ROTATION_X, 0.0, 0.0)
	_model.visible = true
	_tween = create_tween()
	_tween.tween_property(_model, "position", STRUCK_POSITION, 0.06).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_model, "rotation_degrees:x", STRUCK_ROTATION_X, 0.06).set_ease(Tween.EASE_IN)
	_tween.tween_interval(0.1)
	_tween.tween_property(_model, "position", RESTING_POSITION, 0.25)
	_tween.tween_callback(func(): _model.visible = false)
	swung.emit()
