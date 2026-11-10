class_name ADSFocus
extends Node
## Rendering-only focus; weapon rays, FOV and movement retain their own clocks.
const MAX_DISTANCE := 80.0
var player: Player
var attributes := CameraAttributesPractical.new()
var focus_distance := 12.0
var target_distance := 12.0
var amount := 0.0
var enabled := true
var ray_count := 0
var _ray_left := 0.0
var _exclude: Array[RID] = []
var _previous: CameraAttributes

func bind(value: Player) -> void:
	player = value
	_previous = player.view_camera.attributes
	player.view_camera.attributes = attributes
	_exclude.append(player.get_rid())
	for node in player.find_children("*","Hitbox",true,false):
		_exclude.append((node as Hitbox).get_rid())
	attributes.dof_blur_near_transition = 2.0
	attributes.dof_blur_far_transition = 5.0
	player.health.died.connect(_died)
	clear()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var aiming := enabled and player.is_aiming() and not player.health.is_dead()
	if aiming:
		_ray_left -= delta
		if _ray_left <= 0.0:
			_ray_left = 0.05
			target_distance = measure_distance()
	focus_distance = lerpf(focus_distance,target_distance,1.0-exp(-delta*12.0))
	amount = move_toward(amount,0.05 if aiming else 0.0,delta*0.8)
	attributes.dof_blur_amount = amount
	attributes.dof_blur_near_enabled = amount > 0.0001
	attributes.dof_blur_far_enabled = amount > 0.0001
	attributes.dof_blur_near_distance = maxf(0.4,focus_distance-1.25)
	attributes.dof_blur_far_distance = focus_distance+2.0

func measure_distance() -> float:
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*MAX_DISTANCE,CollisionLayers.WORLD|CollisionLayers.HITBOXES,_exclude)
	ray_count += 1
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return clampf(origin.distance_to(hit.position),0.65,MAX_DISTANCE) if not hit.is_empty() else MAX_DISTANCE

func clear() -> void:
	amount = 0.0
	attributes.dof_blur_amount = 0.0
	attributes.dof_blur_near_enabled = false
	attributes.dof_blur_far_enabled = false
	_ray_left = 0.0

func _died(_source: Node) -> void:
	clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		clear()

func _exit_tree() -> void:
	if is_instance_valid(player) and is_instance_valid(player.view_camera) and player.view_camera.attributes == attributes:
		player.view_camera.attributes = _previous
