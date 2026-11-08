class_name Hitbox
extends StaticBody3D
## Body-part hitbox: rays hit this body and the damage goes to the nearest
## Health above it, or the one at health_path. Lives on CollisionLayers.HITBOXES.
## Ported from origin/sheji/systems/hitbox.gd.

enum BodyPart { HEAD, BODY, LIMB }

const LAYER := CollisionLayers.HITBOXES

@export var body_part := BodyPart.BODY
@export var health_path: NodePath

var health: Health
## Exact contact is scoped to one synchronous damage application.
var resolving_surface_hit := false
var surface_point := Vector3.ZERO
var surface_direction := Vector3.ZERO
var surface_can_evade := false
var surface_evaded := false


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	health = _resolve_health()


func apply_hit(amount: float, source: Node = null) -> float:
	if health == null:
		return 0.0
	return health.apply_damage(amount, body_part, source)


func apply_hit_at(amount: float, source: Node, point: Vector3, direction: Vector3, can_evade := false) -> float:
	resolving_surface_hit = true
	surface_can_evade = can_evade
	surface_evaded = false
	surface_point = point
	surface_direction = direction
	var dealt := apply_hit(amount, source)
	resolving_surface_hit = false
	return dealt


func _resolve_health() -> Health:
	if not health_path.is_empty():
		return get_node_or_null(health_path) as Health
	var current := get_parent()
	while current != null:
		for child in current.get_children():
			if child is Health:
				return child
		current = current.get_parent()
	return null
