class_name SorrowWaterFx
extends MeshInstance3D
var remaining := 1.0
var lifetime := 1.0
var _material: StandardMaterial3D


static func pool(parent: Node, origin: Vector3, radius: float, seconds: float) -> SorrowWaterFx:
	var effect := SorrowWaterFx.new()
	effect.remaining = seconds
	effect.lifetime = seconds
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = 0.025
	disk.radial_segments = 20
	effect.mesh = disk
	parent.add_child(effect)
	effect.global_position = origin + Vector3.UP * 0.035
	return effect


static func streak(parent: Node, origin: Vector3, target: Vector3) -> SorrowWaterFx:
	var effect := SorrowWaterFx.new()
	effect.remaining = 0.12
	effect.lifetime = 0.12
	var spike := PrismMesh.new()
	spike.size = Vector3(0.04, 0.06, origin.distance_to(target))
	effect.mesh = spike
	parent.add_child(effect)
	effect.global_position = (origin + target) * 0.5
	if origin.distance_squared_to(target) > 0.001:
		effect.look_at(target, Vector3.UP if absf((target - origin).normalized().y) < 0.99 else Vector3.FORWARD)
	return effect


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(0.04, 0.35, 0.62, 0.55)
	_material.emission_enabled = true
	_material.emission = ErosionStatus.CYAN
	_material.emission_energy_multiplier = 0.45
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	remaining -= delta
	_material.albedo_color.a = 0.55 * clampf(remaining / lifetime, 0.0, 1.0)
	if remaining <= 0.0:
		queue_free()
