class_name PanicFlawStatus
extends Node3D
## Enemy-local panic lifetime and physical, front/back crystal hit surfaces.
## The combat router owns damage; this component owns geometry and contact tests.

signal flaw_broken(index: int, position: Vector3)
signal expired

const COLOR := Color(0.50, 0.24, 0.94)
const BASE_HALF_SIZE := Vector2(0.22, 0.29)
const SURFACE_DEPTH := 0.085

@export var front_offset := 0.32
## Back cloth/armour sits outside the torso capsule on the production enemy.
@export var back_offset := 0.44

var actor: Node3D
var health: Health
var remaining := 0.0
var permanent := false
var area_multiplier := 1.0
var area_sources: Dictionary = {}
var facets: Array[Hitbox] = []


func _ready() -> void:
	if actor == null:
		actor = get_parent() as Node3D
	if health == null and actor != null:
		health = actor.get_node_or_null("Health") as Health
	if health != null:
		health.died.connect(_on_died)


func apply(duration: float, forever := false, count := 1) -> void:
	if health == null or health.is_dead():
		return
	remaining = maxf(remaining, duration)
	permanent = permanent or forever
	if facets.is_empty():
		facets.resize(2)
	if count >= 2:
		_ensure_facet(0)
		_ensure_facet(1)
	elif facet_count() == 0:
		_ensure_facet(0)


func is_active() -> bool:
	return (permanent or remaining > 0.0) and is_instance_valid(health) and not health.is_dead()


func facet_count() -> int:
	var count := 0
	for facet in facets:
		if is_instance_valid(facet) and not facet.is_queued_for_deletion():
			count += 1
	return count


func set_area_multiplier(value: float) -> void:
	area_multiplier = maxf(value, 0.01)
	for facet in facets:
		if is_instance_valid(facet):
			facet.scale = Vector3(sqrt(area_multiplier), sqrt(area_multiplier), 1.0)


func set_area_modifier(source: StringName, value: float) -> void:
	if is_equal_approx(float(area_sources.get(source, 1.0)), value):
		return
	if is_equal_approx(value, 1.0):
		area_sources.erase(source)
	else:
		area_sources[source] = maxf(value, 0.01)
	var product := 1.0
	for multiplier in area_sources.values():
		product *= float(multiplier)
	set_area_multiplier(product)


## Direct facets and body contacts use the same diamond-shaped physical bounds.
## A projectile travelling away from a face cannot trigger its far-side flaw.
func contact_index(point: Vector3, direction: Vector3, graze := 0.0) -> int:
	if not is_active():
		return -1
	for i in facets.size():
		var facet := facets[i]
		if not is_instance_valid(facet) or facet.is_queued_for_deletion():
			continue
		var normal := -facet.global_basis.z.normalized()
		if direction.length_squared() > 0.001 and direction.normalized().dot(normal) > 0.1:
			continue
		var local := facet.to_local(point)
		var margin := graze / sqrt(area_multiplier)
		if absf(local.z) <= SURFACE_DEPTH + graze + 0.035 \
				and absf(local.x) / (BASE_HALF_SIZE.x + margin) \
				+ absf(local.y) / (BASE_HALF_SIZE.y + margin) <= 1.10:
			return i
	return -1


func is_backstab(from: Vector3) -> bool:
	if not is_instance_valid(actor):
		return false
	var toward := from - actor.global_position
	toward.y = 0.0
	return toward.length_squared() > 0.0001 and toward.normalized().dot(actor.global_basis.z.normalized()) > 0.5


func facet_position(index: int) -> Vector3:
	if index >= 0 and index < facets.size() and is_instance_valid(facets[index]):
		return facets[index].global_position
	return global_position + Vector3.UP * 1.2


func break_facet(index: int, relocate_to_back := false) -> bool:
	if index < 0 or index >= facets.size() or not is_instance_valid(facets[index]):
		return false
	var point := facets[index].global_position
	facets[index].collision_layer = 0
	facets[index].visible = false
	facets[index].queue_free()
	facets[index] = null
	if relocate_to_back:
		_ensure_facet(1)
	flaw_broken.emit(index, point)
	return true


func clear() -> void:
	remaining = 0.0
	permanent = false
	for facet in facets:
		if is_instance_valid(facet):
			facet.collision_layer = 0
			facet.visible = false
			facet.queue_free()
	facets.clear()


func _process(delta: float) -> void:
	if get_tree().paused or not is_active() or permanent:
		return
	remaining = maxf(remaining - delta, 0.0)
	if remaining == 0.0:
		clear()
		expired.emit()


func _ensure_facet(index: int) -> void:
	if is_instance_valid(facets[index]):
		return
	var facet := Hitbox.new()
	facet.name = "FrontFlaw" if index == 0 else "BackFlaw"
	facet.set_meta("fear_flaw_index", index)
	facet.position = Vector3(0.0, 1.22, -front_offset if index == 0 else back_offset)
	facet.rotation.y = 0.0 if index == 0 else PI
	facet.scale = Vector3(sqrt(area_multiplier), sqrt(area_multiplier), 1.0)
	var points := PackedVector3Array([
		Vector3(-BASE_HALF_SIZE.x, 0, 0), Vector3(0, BASE_HALF_SIZE.y, 0),
		Vector3(BASE_HALF_SIZE.x, 0, 0), Vector3(0, -BASE_HALF_SIZE.y, 0),
		Vector3(0, 0, -SURFACE_DEPTH), Vector3(0, 0, SURFACE_DEPTH * 0.4)])
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	facet.add_child(collision)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4],
			[1, 0, 5], [2, 1, 5], [3, 2, 5], [0, 3, 5]]:
		for vertex in triangle:
			surface.add_vertex(points[vertex])
	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.metallic = 0.6
	material.roughness = 0.23
	material.emission_enabled = true
	material.emission = COLOR
	material.emission_energy_multiplier = 2.5
	visual.material_override = material
	facet.add_child(visual)
	add_child(facet)
	# Resolve_health walks through this component to the actor; explicit keeps
	# this component compatible with actors that inject Health from another node.
	facet.health = health
	facets[index] = facet


func _on_died(_source: Node) -> void:
	clear()


func _exit_tree() -> void:
	if is_instance_valid(health) and health.died.is_connected(_on_died):
		health.died.disconnect(_on_died)
