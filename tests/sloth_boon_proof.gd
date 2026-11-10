extends Node3D
## Rendered evidence; uses the production crystal enemy and its real clock.
var _elapsed := 0.0
var _actor: Enemy
var _clock: LatencyStatus
var _captured := false


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.085, 0.10, 0.13)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.75, 0.82, 0.92)
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 2.0
	add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(4, 3.0, 6)
	add_child(camera)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.current = true
	camera.fov = 48
	_actor = (load("res://actors/enemy/sloth/sloth_enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(_actor)
	_actor.set_physics_process(false)
	_actor.set_process(false)
	_clock = LatencyStatus.new()
	_clock.setup(_actor, 1.5, 60.0)
	_actor.add_child(_clock)
	_clock.detonated.connect(func(_status: LatencyStatus, origin: Vector3, _damage: float): SlothWave.spawn(self, origin - Vector3.UP * 0.8, 3.0))
	SlothWave.spawn(self, Vector3.ZERO, 2.5, 4.0, false)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.35, 0.40)
	floor_mesh.material_override = mat
	add_child(floor_mesh)


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_clock):
		_clock.advance(delta)
	if not _captured and _elapsed >= 0.55:
		_captured = true
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://docs/proof/issue-115/latency-clock.png")
	if _elapsed >= 2.2:
		get_tree().quit()
