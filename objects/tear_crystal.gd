class_name TearCrystal
extends Node3D
## A real ray/melee collision target. Pickup and firing are serialized by
## consume(); each crystal may grant shielding OR become a projectile once.
signal struck(crystal: TearCrystal, context: Dictionary)
var consumed := false
var age := 0.0
var visual: MeshInstance3D
var hitbox: Hitbox
var pickup_radius := 0.85

class TearHitbox extends Hitbox:
	func apply_hit(_amount: float, source: Node = null, context: Dictionary = {}) -> float:
		var crystal := get_parent() as TearCrystal
		if is_instance_valid(source) and "team" in source and source.team == 0:
			var ctx := context.duplicate()
			ctx.source = source
			crystal.struck.emit(crystal, ctx)
		return 0.0


func _ready() -> void:
	var health := Health.new()
	health.name = "Health"
	health.team = 0
	add_child(health)
	hitbox = TearHitbox.new()
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.27
	collision.shape = shape
	hitbox.add_child(collision)
	add_child(hitbox)
	visual = MeshInstance3D.new()
	visual.mesh = _crystal_mesh()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.40, 0.72)
	material.metallic = 0.45
	material.roughness = 0.24
	material.emission_enabled = true
	material.emission = ErosionStatus.CYAN
	material.emission_energy_multiplier = 0.7
	visual.material_override = material
	add_child(visual)


func advance(delta: float) -> void:
	age += delta
	visual.rotation.y = age * 0.7
	visual.position.y = sin(age * 2.5) * 0.045


func consume() -> bool:
	if consumed:
		return false
	consumed = true
	visible = false
	hitbox.collision_layer = 0
	queue_free()
	return true


static func _crystal_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var ring := [Vector3(0.19, 0, 0), Vector3(0, 0, 0.19), Vector3(-0.19, 0, 0), Vector3(0, 0, -0.19)]
	for index in 4:
		var next := (index + 1) % 4
		for vertex: Vector3 in [Vector3(0, 0.36, 0), ring[next], ring[index], Vector3(0, -0.18, 0), ring[index], ring[next]]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()
