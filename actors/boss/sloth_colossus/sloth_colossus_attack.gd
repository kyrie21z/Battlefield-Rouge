class_name SlothColossusAttack
extends Node3D
## Swept wave, suspended armour barrage, or a rotating pendulum ray.
var caster: SlothColossus
var target: CharacterBody3D
var kind := 0
var elapsed := 0.0
var phase := 0
var hit_count := 0
var cancelled := false
var _center := Vector3.ZERO
var _aim := Vector3.FORWARD
var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _audio: AudioStreamPlayer3D
var _last_radius := 0.0
var _ray_damage_left := 0.0
var _wave_hit := false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func warning_time() -> float:
	return [1.3,1.55,1.8][kind]*caster.boon_windup_scale

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_center = caster.global_position
	_aim = (target.global_position+Vector3.UP-caster._eye()).normalized()
	var mat := SlothAttack._material(Color(1,0.62,0.2,0.55))
	_ring = SlothRealm.torus(self,_center+Vector3.UP*0.08,0.8,0.06,mat)
	if kind == 2:
		_beam = SlothRealm.line(self,caster._eye(),caster._eye()+_aim*28,0.055,mat)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = SlothAttack._tone(false)
	_audio.position = _center
	_audio.unit_size = 15
	_audio.volume_db = -8
	add_child(_audio)
	if caster.warnings_enabled:
		_audio.play()

func _physics_process(delta: float) -> void:
	if cancelled:
		return
	if not is_instance_valid(caster) or caster.state==Enemy.State.DEAD \
			or not is_instance_valid(target) or (target.get_node("Health") as Health).is_dead():
		cancel()
		return
	if caster.boon_time_scale<=0 or caster.boon_stunned:
		return
	delta *= caster.boon_time_scale*caster.effective_attack_scale()
	elapsed += delta
	if phase == 0:
		if not caster.warnings_enabled:
			_audio.stop()
		_ring.visible = caster.warnings_enabled
		if is_instance_valid(_beam):
			_beam.visible = caster.warnings_enabled
		if elapsed<warning_time():
			_ring.scale = Vector3.ONE*(1+elapsed/warning_time()*0.6)
			return
		phase = 1
		_ring.show()
		if is_instance_valid(_beam):
			_beam.show()
		_audio.stop()
		_audio.stream = SlothAttack._tone(true)
		_audio.play()
		if kind == 1:
			_barrage()
	var active := elapsed-warning_time()
	match kind:
		0:
			var radius := minf(18,active*11)
			_ring.scale = Vector3.ONE*maxf(radius/0.8,0.01)
			_wave(radius)
			_last_radius = radius
			if active>=1.9:
				finish()
		1:
			_ring.scale = Vector3.ONE*(1.6+active*0.8)
			if active>=0.5:
				finish()
		2:
			_ray_damage_left = maxf(0,_ray_damage_left-delta)
			var angle := sin(active*2.2)*0.55
			var direction := _aim.rotated(Vector3.UP,angle)
			_update_ray(direction)
			if active>=2.6:
				finish()

func _wave(radius: float) -> void:
	if _wave_hit:
		return
	var offset := target.global_position-_center
	var distance := Vector2(offset.x,offset.z).length()
	if distance<_last_radius-0.6 or distance>radius+0.6 or distance>18 or offset.y>0.35 or offset.y< -0.5:
		return
	if not caster.clear_path(_center+Vector3.UP*0.6,target.global_position+Vector3.UP*0.6):
		return
	_wave_hit = true
	var dealt := (target.get_node("Health") as Health).apply_damage(22*caster.realm_damage_scale,Hitbox.BodyPart.BODY,caster,{"tag":&"colossus_slam"})
	if dealt>0:
		hit_count += 1
		if target.has_method("apply_external_impulse"):
			target.call("apply_external_impulse",offset.normalized(),7.0,0.22)

func _barrage() -> void:
	var from := caster._eye()+Vector3.UP*0.8
	var point := target.global_position+Vector3.UP
	if caster.boss_phase >= 2:
		for i in 9:
			var origin := from+Vector3((i-4)*0.45,absf(i-4)*0.12,0)
			var heading := (point-origin).normalized().rotated(Vector3.UP,(i-4)*0.10)
			SlothRealmProjectile.launch(caster.get_parent(),origin,heading,caster,12*caster.realm_damage_scale,0.65+i*0.08)
		return
	for i in 7:
		var origin := from+Vector3((i-3)*0.5,absf(i-3)*0.15,0)
		var heading := (point-origin).normalized().rotated(Vector3.UP,(i-3)*0.065)
		SlothRealmProjectile.launch(caster.get_parent(),origin,heading,caster,12*caster.realm_damage_scale,0.9+i*0.10)

func _update_ray(direction: Vector3) -> void:
	var from := caster._eye()
	var end := from+direction*30
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from,end,CollisionLayers.WORLD|CollisionLayers.HITBOXES,caster._hitbox_rids))
	if not hit.is_empty():
		end = hit.position
	var axis := (end-from).normalized()
	(_beam.mesh as CylinderMesh).height = from.distance_to(end)
	_beam.position = (from+end)*0.5
	var side := axis.cross(Vector3.FORWARD)
	if side.length_squared()<0.001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	_beam.basis = Basis(side,axis,side.cross(axis).normalized())
	if not hit.is_empty() and hit.collider is Hitbox and (hit.collider as Hitbox).health.get_parent()==target \
			and _ray_damage_left<=0:
		var dealt: float = (hit.collider as Hitbox).apply_hit_at(10*caster.realm_damage_scale,caster,end,direction)
		_ray_damage_left = 0.45
		if dealt>0:
			hit_count += 1
			if target.has_method("set_realm_effect"):
				target.call("set_realm_effect",StringName("colossus_ray_%d"%get_instance_id()),{"duration":0.6,"move_multiplier":0.45,"dash_distance_multiplier":0.65})

func finish() -> void:
	if is_instance_valid(caster):
		caster.attack_finished()
	cancel()

func cancel() -> void:
	if cancelled:
		return
	cancelled = true
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
