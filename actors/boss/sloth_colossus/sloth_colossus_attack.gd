class_name SlothColossusAttack
extends Node3D
## One pausable clock drives five authored attacks. Kind 3 drops resin pools on
## the ground the player is actually standing on; kind 4 trades offence for an
## amber shell that has to be cracked before the titan can be hurt again.
const WARNING_TIMES := [1.3,1.55,1.8,1.4,0.45]
const WAVE_DAMAGE := 22.0
const WAVE_SPEED := 11.0
const WAVE_SECOND_SPEED := 15.0
const WAVE_SECOND_DELAY := 0.55
const WAVE_MAX_RADIUS := 18.0
const WAVE_DURATION := 1.9
const RAY_SWEEP := 0.80
const RAY_RATE := 2.2
const RAY_DURATION := 2.6
const RAY_STASIS_TIME := 0.8
const RESIN_FALL := 0.75
const RESIN_FLANK := 3.6
const HIBERNATION_TIME := 2.6
const HIBERNATION_FIELD_RADIUS := 9.0
const HIBERNATION_MOVE := 0.65
var caster: SlothColossus
var target: CharacterBody3D
var kind := 0
var elapsed := 0.0
var phase := 0
var hit_count := 0
var cancelled := false
var _center := Vector3.ZERO
var _aim := Vector3.FORWARD
var _mat: StandardMaterial3D
var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _audio: AudioStreamPlayer3D
var _waves: Array[Dictionary] = []
var _wave_queue: Array[float] = []
var _ray_damage_left := 0.0
var _resin_left := -1.0
var _pending_pools: Array[SlothResinPool] = []
var _field: SlothTimeField
var _channel_left := 0.0
var _channel_active := false
var _effect_source := StringName()

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func warning_time() -> float:
	return float(WARNING_TIMES[clampi(kind,0,WARNING_TIMES.size()-1)])*caster.boon_windup_scale

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_center = caster.global_position
	_aim = (target.global_position+Vector3.UP-caster._eye()).normalized()
	_mat = SlothAttack._material(Color(1,0.62,0.2,0.55))
	_ring = SlothRealm.torus(self,_center+Vector3.UP*0.08,0.8,0.06,_mat)
	if kind == 2:
		_beam = SlothRealm.line(self,caster._eye(),caster._eye()+_aim*28,0.055,_mat)
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
		_release()
	var active := elapsed-warning_time()
	match kind:
		0:
			_update_waves(active,delta)
		1:
			_ring.scale = Vector3.ONE*(1.6+active*0.8)
			if active>=0.5:
				finish()
		2:
			_ray_damage_left = maxf(0,_ray_damage_left-delta)
			var rate := RAY_RATE*(2.0 if caster.boss_phase>=2 else 1.0)
			var direction := _aim.rotated(Vector3.UP,sin(active*rate)*RAY_SWEEP)
			_update_ray(direction)
			if active>=RAY_DURATION:
				finish()
		3:
			_update_resin(delta)
		4:
			_update_hibernation(delta)

func _release() -> void:
	phase = 1
	_ring.hide()
	if is_instance_valid(_beam):
		_beam.show()
	_audio.stop()
	_audio.stream = SlothAttack._tone(true)
	_audio.play()
	match kind:
		0:
			_spawn_wave(WAVE_SPEED)
			if caster.boss_phase>=2:
				_wave_queue.append(WAVE_SECOND_DELAY)
		1:
			_barrage()
		3:
			_launch_resin()
		4:
			_begin_hibernation()

## Kind 0: every wave is its own front, so phase 2 simply queues a faster one.
func _spawn_wave(speed: float) -> void:
	var ring := SlothRealm.torus(self,_center+Vector3.UP*0.08,0.8,0.06,_mat)
	ring.visible = caster.warnings_enabled
	_waves.append({"radius":0.0,"speed":speed,"hit":false,"ring":ring})

func _update_waves(active: float,delta: float) -> void:
	while not _wave_queue.is_empty() and active>=_wave_queue[0]:
		_spawn_wave(WAVE_SECOND_SPEED)
		_wave_queue.pop_front()
	for index in range(_waves.size()-1,-1,-1):
		var wave: Dictionary = _waves[index]
		var previous: float = wave["radius"]
		wave["radius"] = previous+float(wave["speed"])*delta
		var radius: float = wave["radius"]
		var ring: MeshInstance3D = wave["ring"]
		if is_instance_valid(ring):
			ring.scale = Vector3.ONE*maxf(radius/0.8,0.01)
		_test_wave(wave,previous)
		if radius>=WAVE_MAX_RADIUS:
			if is_instance_valid(ring):
				ring.queue_free()
			_waves.remove_at(index)
	if active>=WAVE_DURATION:
		finish()

func _test_wave(wave: Dictionary,previous: float) -> void:
	if bool(wave["hit"]):
		return
	var offset := target.global_position-_center
	var distance := Vector2(offset.x,offset.z).length()
	var radius: float = wave["radius"]
	if distance<previous-0.6 or distance>radius+0.6 or distance>WAVE_MAX_RADIUS:
		return
	if offset.y>0.35 or offset.y< -0.5:
		return
	if not caster.clear_path(_center+Vector3.UP*0.6,target.global_position+Vector3.UP*0.6):
		return
	wave["hit"] = true
	var dealt := (target.get_node("Health") as Health).apply_damage(WAVE_DAMAGE*caster.realm_damage_scale,Hitbox.BodyPart.BODY,caster,{"tag":&"colossus_slam"})
	if dealt>0:
		hit_count += 1
		if target.has_method("apply_external_impulse"):
			target.call("apply_external_impulse",offset.normalized(),7.0,0.22)

## Kind 1: the phase 2 middle pair homes, so slow strafing no longer clears the
## whole fan by walking sideways.
func _barrage() -> void:
	var phase_two := caster.boss_phase>=2
	var count := 9 if phase_two else 7
	var middle := int(count*0.5)
	var from := caster._eye()+Vector3.UP*0.8
	var point := target.global_position+Vector3.UP
	for i in count:
		var spacing := 0.45 if phase_two else 0.5
		var origin := from+Vector3((i-middle)*spacing,absf(i-middle)*0.12,0)
		var fan := 0.10 if phase_two else 0.065
		var heading := (point-origin).normalized().rotated(Vector3.UP,(i-middle)*fan)
		var homing: Node3D = target if phase_two and (i==3 or i==4) else null
		var waiting := (0.65 if phase_two else 0.9)+i*(0.08 if phase_two else 0.10)
		caster.register_projectile(SlothRealmProjectile.launch(caster.get_parent(),origin,
			heading,caster,12*caster.realm_damage_scale,waiting,homing))

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
				target.call("set_realm_effect",StringName("colossus_ray_%d"%get_instance_id()),{"duration":RAY_STASIS_TIME,"move_multiplier":0.45,"dash_distance_multiplier":0.65})

## Kind 3: marks where the player stands plus the flanks it would strafe into;
## walking out of the footprint is the whole counterplay.
func _launch_resin() -> void:
	var flat := target.global_position-_center
	flat.y = 0.0
	var side := flat.normalized().cross(Vector3.UP).normalized()
	if side.length_squared()<0.001:
		side = Vector3.RIGHT
	var points: Array[Vector3] = [target.global_position]
	var extra := 2 if caster.boss_phase>=2 else 1
	for i in extra:
		var flank_sign := 1.0 if i%2==0 else -1.0
		points.append(target.global_position+side*RESIN_FLANK*flank_sign)
	for point in points:
		var pool := caster.spawn_resin_pool(point)
		if is_instance_valid(pool):
			_pending_pools.append(pool)
	_resin_left = RESIN_FALL

func _update_resin(delta: float) -> void:
	_resin_left -= delta
	if _resin_left>0.0:
		return
	for pool in _pending_pools:
		if is_instance_valid(pool) and not pool.is_queued_for_deletion():
			pool.land()
	_pending_pools.clear()
	_resin_left = -1.0
	finish()

## Kind 4: the shell cuts ordinary damage, trickles shield back and holds the
## player in a stasis dial until true damage, the blade or 180 points crack it.
func _begin_hibernation() -> void:
	_channel_active = true
	_channel_left = HIBERNATION_TIME
	caster.begin_hibernation()
	_effect_source = StringName("colossus_hibernation_%d"%get_instance_id())
	_field = SlothTimeField.new()
	_field.reach = HIBERNATION_FIELD_RADIUS
	_field.position = _center
	add_child(_field)
	_field.visible = caster.warnings_enabled
	_sync_hibernation_field()

func _sync_hibernation_field() -> void:
	if not is_instance_valid(target):
		return
	var inside := is_instance_valid(caster) and caster.global_position.distance_to(target.global_position)<=HIBERNATION_FIELD_RADIUS
	if inside:
		if target.has_method("set_realm_effect"):
			target.call("set_realm_effect",_effect_source,{"dash_blocked":true,"move_multiplier":HIBERNATION_MOVE})
	elif target.has_method("clear_realm_effect") and _effect_source!=StringName():
		target.call("clear_realm_effect",_effect_source)

func _update_hibernation(delta: float) -> void:
	if not caster.hibernating:
		finish()
		return
	_channel_left = maxf(0.0,_channel_left-delta)
	caster.regen_hibernation_shield(delta)
	_sync_hibernation_field()
	if is_instance_valid(_field):
		_field.show_charge(1.0-_channel_left/HIBERNATION_TIME)
	if caster.hibernation_damage>=SlothColossus.HIBERNATION_BREAK_DAMAGE:
		caster.break_shell()
		return
	if _channel_left<=0.0:
		finish()

func _release_channel() -> void:
	if not _channel_active:
		return
	_channel_active = false
	if is_instance_valid(caster):
		caster.end_hibernation()
	if is_instance_valid(target) and target.has_method("clear_realm_effect") and _effect_source!=StringName():
		target.call("clear_realm_effect",_effect_source)

func finish() -> void:
	if is_instance_valid(caster):
		caster.attack_finished()
	cancel()

func cancel() -> void:
	if cancelled:
		return
	cancelled = true
	_release_channel()
	for pool in _pending_pools:
		if is_instance_valid(pool):
			pool.queue_free()
	_pending_pools.clear()
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
	queue_free()

func _exit_tree() -> void:
	_release_channel()
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
