class_name WrathEmbers
extends Node3D
## Three-second physical wall scar; damage is local, visible and wall-occluded.
var manager: BoonManager
var remaining := 3.0
var _tick_left := 0.5
var _depth := 2

static func create(owner_manager: BoonManager, point: Vector3, normal: Vector3, depth: int) -> WrathEmbers:
	var patch := WrathEmbers.new()
	patch.manager = owner_manager
	patch._depth = depth
	owner_manager.player.get_parent().add_child(patch)
	patch.global_position = point + normal * 0.08
	return patch

func _ready() -> void:
	for index in 5:
		var mesh := MeshInstance3D.new()
		var shard := PrismMesh.new()
		shard.size = Vector3(0.25, 0.65, 0.15)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.04, 0.008, 0.005)
		material.emission_enabled = true
		material.emission = WrathBoons.COLOR
		material.emission_energy_multiplier = 1.3
		shard.material = material
		mesh.mesh = shard
		mesh.position = Vector3((index - 2) * 0.25, 0.1 * (index % 2), 0.04 * index)
		mesh.rotation.z = (index - 2) * 0.17
		add_child(mesh)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(manager):
		queue_free()
		return
	var active_delta := minf(delta, remaining)
	remaining -= active_delta
	_tick_left -= active_delta
	while _tick_left <= 0.000001:
		_tick_left += 0.5
		manager.aoe(global_position, 2.4, 8.0, {"tag": &"wrath_embers", "proc_depth": _depth})
	if remaining <= 0.000001:
		queue_free()
