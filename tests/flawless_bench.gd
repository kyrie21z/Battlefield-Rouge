extends Node3D
var player: Player
var encounter: DoppelgangerSpawn
func _ready() -> void:
	build_arena()
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0,0,12)
	add_child(player)
	player.fragments.configure_deprivation([0,1,2,3])
	for realm in 4:
		player.fragments.acquire(realm)
	encounter = DoppelgangerSpawn.new()
	encounter.setup(player)
	add_child(encounter)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func build_arena() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CollisionLayers.WORLD
	floor_body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(32,1,30)
	collision.shape = box
	floor_body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65,0.69,0.74)
	mat.roughness = 0.3
	visual.material_override = mat
	floor_body.add_child(visual)
	floor_body.position.y = -0.5
	add_child(floor_body)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.12,0.14,0.18)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.75,0.82,0.92)
	world.environment.ambient_light_energy = 0.65
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.glow_enabled = true
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-25,0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
