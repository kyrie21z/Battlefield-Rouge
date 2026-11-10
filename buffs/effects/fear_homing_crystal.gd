class_name FearHomingCrystal
extends Node
## Steering attached to the reflected production Projectile. Its swept collision,
## source ownership, parry exclusion and world occlusion remain authoritative.

var projectile: Projectile
var target: Node3D
var target_position: Callable
var impact_callback: Callable


func _ready() -> void:
	process_physics_priority = -5
	projectile = get_parent() as Projectile
	if projectile != null and projectile.has_signal("impacted"):
		projectile.connect("impacted", _on_impact)
	if projectile != null:
		for node in projectile.get_children():
			if node is MeshInstance3D:
				var material := StandardMaterial3D.new()
				material.albedo_color = PanicFlawStatus.COLOR
				material.emission_enabled = true
				material.emission = PanicFlawStatus.COLOR
				material.emission_energy_multiplier = 3.0
				var crystal := PrismMesh.new()
				crystal.size = Vector3(0.13, 0.40, 0.13)
				node.mesh = crystal
				node.material_override = material
			elif node is OmniLight3D:
				node.light_color = PanicFlawStatus.COLOR
			elif node is Sprite3D:
				node.modulate = PanicFlawStatus.COLOR


func _physics_process(_delta: float) -> void:
	if get_tree().paused or not is_instance_valid(projectile) or not is_instance_valid(target):
		return
	var point: Vector3 = target_position.call() if target_position.is_valid() else target.global_position + Vector3.UP
	var direction := point - projectile.global_position
	if direction.length_squared() > 0.00001:
		projectile.look_at(point, Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.FORWARD)


func _on_impact(victim: Node, point: Vector3) -> void:
	if is_instance_valid(victim) and impact_callback.is_valid():
		impact_callback.call(victim, point)
	impact_callback = Callable()
