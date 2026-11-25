class_name SlothRealmProjectile
extends Projectile
## Delayed crystal: its warning remains fixed while hovering. Only Retreater shards home.
var delay := 0.8
var homing_target: Node3D
var homing_time := 1.1
var age := 0.0
var released := false
var warning_visible := true
var _orb: MeshInstance3D

static func launch(parent: Node, origin: Vector3, direction: Vector3, shooter: Enemy,
		amount: float, waiting: float, homing: Node3D = null) -> SlothRealmProjectile:
	var p := SlothRealmProjectile.new()
	p.source = shooter
	p.exclude = shooter._hitbox_rids.duplicate()
	p.damage = amount
	p.speed = 18.0 if homing == null else 13.0
	p.tint = Projectile.realm_tint(&"sloth")
	p.delay = waiting
	p.homing_target = homing
	p.warning_visible = shooter.warnings_enabled if "warnings_enabled" in shooter else true
	parent.add_child(p)
	p.global_position = origin
	p.look_at(origin+direction, Vector3.UP if absf(direction.y)<0.99 else Vector3.RIGHT)
	Events.projectile_registered.emit(p)
	return p

func _ready() -> void:
	super._ready()
	_orb = MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = 0.13
	gem.height = 0.34
	gem.radial_segments = 4
	gem.rings = 2
	_orb.mesh = gem
	_orb.material_override = SlothAttack._material(Color(1,0.62,0.2,0.85))
	add_child(_orb)
	for child in get_children():
		if child != _orb and child is Node3D:
			child.hide()

func _physics_process(delta: float) -> void:
	if boon_time_scale <= 0.0:
		return
	age += delta*boon_time_scale
	if age < delay and not reflected:
		_orb.visible = warning_visible
		_orb.rotation.y += delta*0.6
		_orb.scale = Vector3.ONE*(0.65+age/maxf(delay,0.01)*0.35)
		return
	if not released:
		released = true
		for child in get_children():
			if child is Node3D:
				child.show()
		_orb.hide()
	if not reflected and is_instance_valid(homing_target) and age-delay < homing_time:
		var desired := (homing_target.global_position+Vector3.UP*1.0-global_position).normalized()
		var current := -global_basis.z
		var heading := current.slerp(desired, minf(delta*1.4,1.0)).normalized()
		look_at(global_position+heading, Vector3.UP if absf(heading.y)<0.99 else Vector3.RIGHT)
	super._physics_process(delta)
