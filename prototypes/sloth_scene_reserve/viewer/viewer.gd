extends CharacterBody3D
## Independent scene viewer. All bindings are local to this preview.

const WALK_SPEED := 8.0
const RUN_SPEED := 15.0
const FLY_SPEED := 14.0
const FLY_RUN_SPEED := 32.0
const JUMP_SPEED := 6.0
const LOOK_SENSITIVITY := 0.0022
const EYE_HEIGHT := 1.7
const WORLD_LAYER := 1 << 0
const VIEWER_LAYER := 1 << 1

var camera: Camera3D
var head: Node3D
var flying := false
var input_enabled := true
var _spawn_transform: Transform3D
var _spawn_pitch := 0.0
var _temporary_capture := false
var _gravity := 9.8


func _ready() -> void:
	name = "Viewer"
	collision_layer = VIEWER_LAYER
	collision_mask = WORLD_LAYER
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(46.0)
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 72.0
	camera.near = 0.08
	camera.far = 18000.0
	camera.current = true
	# Follow the body's interpolated position without interpolating mouse look.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	head.add_child(camera)
	if position.is_zero_approx():
		position = Vector3(0.0, 0.1, 105.0)
	_spawn_transform = global_transform
	_spawn_pitch = head.rotation.x
	snap_camera()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_release_mouse()
			KEY_F1:
				_call_scene("set_room",0)
			KEY_F2:
				_call_scene("set_room",1)
			KEY_F:
				flying = not flying
				velocity = Vector3.ZERO
				_notify_mode()
			KEY_R:
				reset_view()
			KEY_1, KEY_KP_1:
				_call_scene("set_view", 0)
			KEY_2, KEY_KP_2:
				_call_scene("set_view", 1)
			KEY_3, KEY_KP_3:
				_call_scene("set_view", 2)
			KEY_4, KEY_KP_4:
				_call_scene("set_view", 3)
			KEY_M:
				_call_scene("toggle_motion")
			KEY_L:
				_call_scene("toggle_atmosphere")
			KEY_TAB:
				var hud := get_parent().get_node_or_null("ViewerHUD")
				if hud != null and hud.has_method("toggle_visibility"):
					hud.call("toggle_visibility")
			KEY_SPACE:
				if not flying and is_on_floor():
					velocity.y = JUMP_SPEED
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_temporary_capture = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_temporary_capture = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif not event.pressed and _temporary_capture:
				_release_mouse()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * LOOK_SENSITIVITY,
			deg_to_rad(-78.0), deg_to_rad(78.0))


func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction.x += 1.0
	direction = direction.normalized()
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := RUN_SPEED if sprinting else WALK_SPEED
	var movement := global_basis * Vector3(direction.x, 0.0, direction.y)
	if flying:
		speed = FLY_RUN_SPEED if sprinting else FLY_SPEED
		movement = camera.global_basis * Vector3(direction.x, 0.0, direction.y)
		if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E):
			movement.y += 1.0
		if Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_Q):
			movement.y -= 1.0
		velocity = movement.limit_length() * speed
		global_position += velocity * delta
	else:
		velocity.x = movement.x * speed
		velocity.z = movement.z * speed
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		if global_position.y < -35.0:
			reset_view()


func _process(delta: float) -> void:
	if input_enabled:
		var turn := float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))
		var tilt := float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
		rotate_y(turn * delta * 1.15)
		head.rotation.x = clampf(head.rotation.x + tilt * delta * 0.8, deg_to_rad(-78.0), deg_to_rad(78.0))
	_sync_camera(true)


func _sync_camera(interpolated: bool) -> void:
	if not is_instance_valid(camera):
		return
	var body_position := get_global_transform_interpolated().origin if interpolated else global_position
	camera.global_position = body_position + Vector3.UP * EYE_HEIGHT
	camera.global_rotation = Vector3(head.rotation.x, global_rotation.y, 0.0)


func snap_camera() -> void:
	# Use after any teleport so the renderer never blends from the old viewpoint.
	reset_physics_interpolation()
	_sync_camera(false)


func teleport_to(world_position: Vector3, look_target: Vector3) -> void:
	global_position = world_position
	velocity = Vector3.ZERO
	aim_at(look_target)
	snap_camera()


func aim_at(look_target: Vector3) -> void:
	var direction := look_target - (global_position + Vector3.UP * EYE_HEIGHT)
	if direction.length_squared() > 0.001:
		rotation = Vector3(0.0, atan2(-direction.x, -direction.z), 0.0)
		head.rotation.x = clampf(atan2(direction.y, Vector2(direction.x, direction.z).length()),
			deg_to_rad(-78.0), deg_to_rad(78.0))
	_sync_camera(false)


func reset_view() -> void:
	flying = false
	velocity = Vector3.ZERO
	_notify_mode()
	if get_parent().has_method("set_view"):
		get_parent().call("set_view", 0)
	else:
		global_transform = _spawn_transform
		head.rotation.x = _spawn_pitch
		snap_camera()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	velocity = Vector3.ZERO
	if not enabled:
		_release_mouse()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_mouse()


func _release_mouse() -> void:
	_temporary_capture = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _call_scene(method: String, argument: Variant = null) -> void:
	if not get_parent().has_method(method):
		return
	if argument == null:
		get_parent().call(method)
	else:
		get_parent().call(method, argument)


func _notify_mode() -> void:
	var hud := get_parent().get_node_or_null("ViewerHUD")
	if hud != null and hud.has_method("set_mode"):
		hud.call("set_mode", "自由飞行" if flying else "步行漫游")
