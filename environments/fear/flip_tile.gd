class_name FearFlipTile
extends AnimatableBody3D
## A warned bridge segment physically rotates away; it never teleports actors.
signal flipped
@export var warnings_enabled := true
var elapsed := -1.0
var warning_time := 0.85
var open_time := 2.4
var warning: MeshInstance3D
var alarm: AudioStreamPlayer3D
var size := Vector3(4.0, 0.45, 3.8)

func _ready() -> void:
	collision_layer = CollisionLayers.WORLD
	collision_mask = 0
	add_to_group("navigation_geometry")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	slab.mesh = mesh
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.84, 0.82, 0.9)
	stone.roughness = 0.8
	slab.material_override = stone
	add_child(slab)
	warning = MeshInstance3D.new()
	var edge := BoxMesh.new()
	edge.size = Vector3(size.x, 0.012, size.z)
	warning.mesh = edge
	warning.position.y = size.y * 0.5 + 0.009
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.42, 0.15, 0.7, 0.35)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(0.5, 0.12, 0.9)
	glow.emission_energy_multiplier = 1.8
	warning.material_override = glow
	add_child(warning)
	warning.hide()
	alarm = AudioStreamPlayer3D.new()
	alarm.stream = ProceduralAudio.generate("enemy_shot")
	alarm.pitch_scale = 1.8
	alarm.volume_db = -13.0
	add_child(alarm)

func trigger() -> bool:
	if elapsed >= 0.0:
		return false
	elapsed = 0.0
	warning.visible = warnings_enabled
	if warnings_enabled:
		alarm.play()
	return true

func set_warnings_enabled(enabled: bool) -> void:
	warnings_enabled = enabled
	if is_instance_valid(warning):
		warning.visible = enabled and elapsed >= 0.0 and elapsed < warning_time
	if not enabled and is_instance_valid(alarm):
		alarm.stop()

func _physics_process(delta: float) -> void:
	if elapsed < 0.0:
		return
	var previous := elapsed
	elapsed += delta
	warning.visible = warnings_enabled and elapsed < warning_time
	if previous < warning_time and elapsed >= warning_time:
		flipped.emit()
	if elapsed < warning_time:
		rotation.z = 0.018 * sin(elapsed * 42.0)
	elif elapsed < warning_time + 0.25:
		rotation.z = smoothstep(warning_time, warning_time + 0.25, elapsed) * PI * 0.5
	elif elapsed < warning_time + open_time:
		rotation.z = PI * 0.5
	else:
		rotation.z = (1.0 - smoothstep(warning_time + open_time, warning_time + open_time + 0.55, elapsed)) * PI * 0.5
	if elapsed > warning_time + open_time + 0.55:
		rotation.z = 0.0
		elapsed = -1.0

func _exit_tree() -> void:
	if is_instance_valid(alarm):
		alarm.stop()
		alarm.stream = null
