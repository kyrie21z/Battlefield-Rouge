extends Node3D
var _elapsed := 0.0
var _saved := false
var _status: ErosionStatus
var _tears: Array[TearCrystal] = []


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.07, 0.10, 0.14)
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
	camera.position = Vector3(4.5, 3.2, 6)
	add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true
	camera.fov = 48
	var actor := (load("res://actors/enemy/sloth/sloth_enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	_status = ErosionStatus.new()
	_status.setup(actor, 5.0, 0.5)
	actor.add_child(_status)
	_status.add_layers(5)
	for point: Vector3 in [Vector3(-0.8, 0.3, 0.5), Vector3(0.6, 0.3, 1.0), Vector3(1.2, 0.3, 0.2)]:
		var tear := (load("res://objects/tear_crystal.tscn") as PackedScene).instantiate() as TearCrystal
		add_child(tear)
		tear.position = point
		_tears.append(tear)
	for point: Vector3 in [Vector3(-1.4, 0, -1.4), Vector3(-0.5, 0, -0.6), Vector3(0.2, 0, 0.4)]:
		SorrowWaterFx.pool(self, point, 1.15, 3.0)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.37, 0.42)
	floor_mesh.material_override = mat
	add_child(floor_mesh)


func _process(delta: float) -> void:
	_elapsed += delta
	for tear: TearCrystal in _tears:
		tear.advance(delta)
	if not _saved and _elapsed >= 0.5:
		_saved = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-121/erosion-tears.png")
	if _elapsed > 1.2:
		get_tree().quit()
