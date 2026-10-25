class_name CapturePoint
extends Area3D
## The objective building. Locked until the zone director calls open(); then
## the player hammers it. Every swing adds progress, and a swing that lands on
## a hit moment (within CaptureConfig.perfect_window_ms) adds more. Progress
## never goes down, so nothing that happens during the capture can undo it. At
## 100% a flag is planted and `captured` fires.
## Rules: docs/Cut-001b.md. Timing choices: docs/adr/0003-hammer-capture-timing.md.

signal progress_changed(progress: float)
## One swing resolved against the building. `offset_ms` is how far from the
## hit moment it landed (negative = early); `worth` is the progress it added.
signal struck(perfect: bool, offset_ms: float, worth: float)
signal captured

## Seconds between hit moments. A rule of the strike rather than a playtest
## knob, so it is not part of CaptureConfig.
const BEAT_PERIOD := 1.0
const COLOR_LOCKED := Color(0.45, 0.45, 0.48)
const COLOR_OPEN := Color(0.25, 0.5, 0.9)
const COLOR_CAPTURED := Color(0.3, 0.85, 0.4)
const FLASH_HIT := Color(0.85, 0.9, 1.0)
const FLASH_PERFECT := Color(1.0, 0.8, 0.2)
const FLAG_HEIGHT := 3.5
## Progress counts as full once it is this close to 1, so float error in the
## configured steps cannot leave a capture stuck at 99.999%.
const FULL_EPSILON := 0.000001

@export var config: CaptureConfig = preload("res://zone/capture_config.tres")

var locked := true
## 0..1. Only add_capture_progress() changes it.
var progress := 0.0
## True while the player is within hammer reach of the building.
var player_in_reach := false

var _opened_at := 0.0
var _material := StandardMaterial3D.new()
var _flash_tween: Tween
var _hit_sound := ProceduralAudio.generate("hammer_hit")
var _perfect_sound := ProceduralAudio.generate("hammer_perfect")
var _audio := AudioStreamPlayer3D.new()
var _light := OmniLight3D.new()

@onready var _building: MeshInstance3D = $Objective/Mesh


func _ready() -> void:
	collision_layer = 0
	collision_mask = CollisionLayers.ACTORS
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_building.material_override = _material
	_audio.position.y = 1.0
	_audio.max_distance = 60.0
	add_child(_audio)
	_light.position.y = 2.5
	_light.omni_range = 10.0
	_light.light_energy = 0.0
	add_child(_light)
	_update_color()


func open() -> void:
	locked = false
	_opened_at = SimClock.now()
	_update_color()


func is_captured() -> bool:
	return progress >= 1.0 - FULL_EPSILON


## Seconds on the beat clock. Hit moments fall on whole multiples of
## BEAT_PERIOD; the first one comes half a period after open().
func beat_time() -> float:
	return SimClock.now() - _opened_at + BEAT_PERIOD * 0.5


## Signed seconds from `time` to the nearest hit moment (negative = early).
static func beat_offset(time: float) -> float:
	return fposmod(time + BEAT_PERIOD * 0.5, BEAT_PERIOD) - BEAT_PERIOD * 0.5


## Adds `amount`, a fraction of the whole capture, and plants the flag at 100%.
## Ignored while locked or once captured.
func add_capture_progress(amount: float) -> void:
	if locked or is_captured() or amount <= 0.0:
		return
	progress = minf(progress + amount, 1.0)
	progress_changed.emit(progress)
	_update_color()
	if is_captured():
		progress = 1.0
		_plant_flag()
		captured.emit()


## Resolves one hammer swing made at `time` on the beat clock. A swing counts
## only while the building is open and the player is within reach.
func resolve_swing(time: float) -> void:
	if locked or is_captured() or not player_in_reach:
		return
	var offset_ms := beat_offset(time) * 1000.0
	var perfect := absf(offset_ms) <= config.perfect_window_ms
	var worth := config.perfect_progress() if perfect else config.normal_progress()
	_play_feedback(perfect)
	struck.emit(perfect, offset_ms, worth)
	add_capture_progress(worth)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_in_reach = true
		var swung := (body as Player).hammer.swung
		if not swung.is_connected(_on_swung):
			swung.connect(_on_swung)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_in_reach = false


func _on_swung() -> void:
	resolve_swing(beat_time())


## A perfect strike and an ordinary one differ in sound, flash colour, flash
## strength and a light burst, so the player can tell them apart without the HUD.
func _play_feedback(perfect: bool) -> void:
	_audio.stream = _perfect_sound if perfect else _hit_sound
	_audio.play()
	if _flash_tween != null:
		_flash_tween.kill()
	_material.emission_enabled = true
	_material.emission = FLASH_PERFECT if perfect else FLASH_HIT
	_light.light_color = FLASH_PERFECT
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_material, "emission_energy_multiplier", 0.0, 0.4 if perfect else 0.12) \
		.from(4.0 if perfect else 0.8)
	_flash_tween.tween_property(_light, "light_energy", 0.0, 0.4).from(8.0 if perfect else 0.0)


func _plant_flag() -> void:
	var top := (_building.global_transform * _building.get_aabb()).end.y - global_position.y
	var flag := Node3D.new()
	flag.name = "Flag"
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.75, 0.78)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.06
	pole_mesh.height = FLAG_HEIGHT
	pole.mesh = pole_mesh
	pole.material_override = metal
	pole.position.y = FLAG_HEIGHT * 0.5
	flag.add_child(pole)
	var cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(1.1, 0.7, 0.05)
	cloth.mesh = cloth_mesh
	var cloth_material := StandardMaterial3D.new()
	cloth_material.albedo_color = COLOR_CAPTURED
	cloth.material_override = cloth_material
	cloth.position = Vector3(0.6, FLAG_HEIGHT - 0.45, 0.0)
	flag.add_child(cloth)
	# Start with the whole pole inside the building and raise it out of the roof.
	flag.position.y = top - FLAG_HEIGHT
	add_child(flag)
	create_tween().tween_property(flag, "position:y", top, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_color() -> void:
	if locked:
		_material.albedo_color = COLOR_LOCKED
	else:
		_material.albedo_color = COLOR_OPEN.lerp(COLOR_CAPTURED, progress)
