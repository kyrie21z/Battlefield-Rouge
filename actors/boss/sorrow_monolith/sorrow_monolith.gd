class_name SorrowMonolith
extends SorrowRealmEnemy
signal realm_defeated(realm_id: int)
enum Move { RAIN, TIDE, SLAP }
var move_kind := Move.RAIN
var locked_point := Vector3.ZERO
var battle_elapsed := 0.0
var raised_water := 0.14
var tears_released := 0
var tides_released := 0
var slaps := 0
var tell: MeshInstance3D

func _enter_tree() -> void:
	variant = 2
	is_boss = true
	super._enter_tree()
func _ready() -> void:
	super._ready()
	health.max_health = 1300
	health.health = 1300
	health.headshot_multiplier = 1.25
	action_left = 1.4
	(get_node("HeadHitbox") as Hitbox).position = to_local(visual.model.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("Head")).origin))
func _physics_process(delta: float) -> void:
	if state == State.DEAD or boon_stunned or boon_time_scale <= 0:
		return
	delta *= boon_time_scale
	battle_elapsed += delta
	if is_instance_valid(arena):
		raised_water = maxf(raised_water,0.14+(1-health.health/health.max_health)*1.45+battle_elapsed*0.004)
		arena.set_water_level(raised_water)
	if not is_instance_valid(target):
		return
	if not is_on_floor():
		velocity.y -= gravity*delta
	if _impact_left > 0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO,IMPACT_DECAY*delta)
		_boon_move_and_slide()
		return
	_stop()
	action_left -= delta*effective_attack_scale()
	visual.set_cast(1.0 if warnings_enabled and action == 1 else 0.0)
	(visual as SorrowMonolithVisual).slam = maxf(0.0,action_left/0.8) if action == 2 and move_kind == Move.SLAP else 0.0
	if action == 0 or action == 3:
		if action_left <= 0:
			begin_move(move_kind)
	elif action == 1:
		if action_left <= 0:
			_release()
			action = 2
			action_left = 0.8
	else:
		if action_left <= 0:
			action = 3
			action_left = 1.6
			move_kind = (move_kind+1)%3
	_boon_move_and_slide()
func begin_move(kind: int) -> void:
	if state == State.DEAD or not is_instance_valid(target):
		return
	move_kind = kind
	locked_point = target.global_position
	action = 1
	action_left = 1.1*boon_windup_scale
	_clear_tell()
	if warnings_enabled:
		tell = MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 4.1 if kind == Move.RAIN else 2.4
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.035
		mesh.radial_segments = 32
		tell.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.14,0.68,0.83,0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tell.material_override = mat
		get_parent().add_child(tell)
		tell.global_position = Vector3(locked_point.x,raised_water+0.06,locked_point.z)
func _release() -> void:
	_clear_tell()
	if move_kind == Move.RAIN:
		for x in range(-2,3):
			for z in range(-2,3):
				var from := locked_point+Vector3(x*1.65,9,z*1.65)
				var bullet := Projectile.spawn(get_parent(),from,Vector3.DOWN,self,8*realm_damage_scale,13,_hitbox_rids.duplicate(),Color(0.1,0.65,0.88))
				bullet.max_distance = 13
				_owned.append(weakref(bullet))
				tears_released += 1
	elif move_kind == Move.TIDE:
		var wave := SorrowTide.new()
		wave.source = self
		wave.target = target as Player
		wave.water_level = raised_water
		wave.damage *= realm_damage_scale
		get_parent().add_child(wave)
		wave.global_position = global_position
		_owned.append(weakref(wave))
		tides_released += 1
	else:
		slaps += 1
		var offset := target.global_position-locked_point
		if Vector2(offset.x,offset.z).length() < 2.4 and _line_clear(target.global_position+Vector3.UP):
			var hp := target.get_node("Health") as Health
			var dealt := hp.apply_damage(24*realm_damage_scale,Hitbox.BodyPart.BODY,self,{"tag":&"monolith_slap"})
			if dealt > 0 and target.has_method("apply_external_impulse"):
				target.call("apply_external_impulse",target.global_position-global_position,12.0,0.25)
		if is_instance_valid(arena):
			arena.add_ripple(locked_point)
func _on_died(source: Node) -> void:
	if state == State.DEAD:
		return
	_clear_tell()
	super._on_died(source)
	if is_instance_valid(arena):
		arena.set_deprivation(true)
	realm_defeated.emit(3)
func _clear_tell() -> void:
	if is_instance_valid(tell):
		tell.queue_free()
	tell = null
func _exit_tree() -> void:
	_clear_tell()
	super._exit_tree()
