class_name CombatBenchTarget
extends Node3D
## Reusable practice target: real Health/Hitbox, visible damage and knockback.
var team := 1
var health: Health
var moving := false
var _origin := Vector3.ZERO
var _time := 0.0
var _impact := Vector3.ZERO
var _label: Label3D

func _ready() -> void:
	_origin = position
	health = Health.new()
	health.max_health = 500.0
	health.team = team
	add_child(health)
	var hitbox := Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.position.y = 1.0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	shape.shape = capsule
	hitbox.add_child(shape)
	add_child(hitbox)
	var mesh := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.3
	body.bottom_radius = 0.45
	body.height = 1.8
	body.radial_segments = 5
	mesh.mesh = body
	mesh.position.y = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.23, 0.08, 0.06)
	mesh.material_override = material
	add_child(mesh)
	_label = Label3D.new()
	_label.position.y = 2.4
	_label.font_size = 48
	_label.pixel_size = 0.007
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	health.damaged.connect(func(dealt: float, _part: Hitbox.BodyPart, _source: Node):
		_label.text = "-%d / %d HP" % [dealt, health.health])
	_label.text = "500 HP"

func _physics_process(delta: float) -> void:
	_time += delta
	_impact = _impact.move_toward(Vector3.ZERO, delta * 2.0)
	position = _origin + _impact
	if moving:
		position.x += sin(_time * 0.8) * 3.0
	if health.is_dead():
		health.health = health.max_health
		_label.text = "重置 500 HP"

func apply_impact(direction: Vector3, force: float, _stagger: float) -> void:
	_impact += direction * minf(force * 0.1, 1.0)
