class_name PsycheShardPickup
extends Node3D
## Physical world pickup: injected player, WORLD line of sight, one award only.
signal collected(realm: int)
const TITLES := ["沉睡的碎片", "警醒的碎片", "锋芒的碎片", "温润的碎片"]
@export_enum("Sloth","Fear","Wrath","Sorrow") var realm := 0
@export var pickup_radius := 1.3
var player: Player
var consumed := false
var _visual: MeshInstance3D
var _age := 0.0

func setup(value: Player) -> void:
	player = value

func _ready() -> void:
	var color := BoonIdentity.COLORS[clampi(realm,0,3)]
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.3)
	material.metallic = 0.6
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.0
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.36,0.62,0.28)
	_visual = MeshInstance3D.new()
	_visual.mesh = mesh
	_visual.material_override = material
	_visual.position.y = 0.75
	add_child(_visual)
	var label := Label3D.new()
	label.text = TITLES[clampi(realm,0,3)] + "\n走近拾取"
	label.position.y = 1.5
	label.pixel_size = 0.003
	label.font_size = 38
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(0.25)
	add_child(label)

func _physics_process(delta: float) -> void:
	if consumed or not is_instance_valid(player) or player.health.is_dead():
		return
	_age += delta
	_visual.rotation.y += delta * 0.7
	_visual.position.y = 0.75 + sin(_age * 1.8) * 0.10
	try_collect()

func try_collect() -> bool:
	if consumed or not is_instance_valid(player) or player.health.is_dead() or get_tree().paused:
		return false
	if player.global_position.distance_to(global_position) > pickup_radius:
		return false
	if not player.boons.line_clear(player.global_position + Vector3.UP * 0.8, global_position + Vector3.UP * 0.8):
		return false
	if not player.fragments.acquire(realm):
		return false
	consumed = true
	hide()
	collected.emit(realm)
	queue_free()
	return true
