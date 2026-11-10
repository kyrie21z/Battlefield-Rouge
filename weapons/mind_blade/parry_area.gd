extends Area3D
## A collision-only handoff between projectile sweeps and this blade instance.
var blade: MeleeWeapon


func _ready() -> void:
	collision_layer = CollisionLayers.PARRY
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	shape.shape = sphere
	add_child(shape)


func try_parry(projectile: Projectile, point: Vector3) -> bool:
	return is_instance_valid(blade) and blade.try_parry(projectile, point)
