class_name SorrowMonolith
extends SorrowRealmEnemy
## Grief does not stand and trade. The slab of black crystal sinks under the
## mirror to reappear on your blind side, drags you back into the shallows it
## keeps flooding, and wails until your hands forget how to reload.
signal realm_defeated(realm_id: int)
signal phase_changed(new_phase: int)
enum Move { RAIN, TIDE, SLAP, CRY }

const BASE_HEALTH := 1650.0
## The flood reads the fight: a 0.14m film at full health, a 0.3m shelf under
## water at half health, the 0.6m shelf before the end, and 1.15m as the
## ceiling the basin geometry can show.
const WATER_FLOOR := 0.14
const WATER_GRIEF := 1.35
const WATER_CREEP := 0.008
const WATER_CAP := 1.15
const WINDUP := 1.1
const ACTIVE := 0.8
const RECOVER_QUICK := 0.9
const RECOVER_PHASE_TWO := 1.15
const SLAP_REACH := 3.3
const SLAP_LUNGE := 3.5
const LUNGE_SPEED := 7.0
const CRY_COOLDOWN := 5.0
const SUBMERGE_TIME := 0.85
const AMBUSH_NEAR := 5.5
const AMBUSH_FAR := 7.5
const AMBUSH_PROWL := 13.0
const AMBUSH_TRIES := 16
const UNDERTOW_MOVE := 0.72
const UNDERTOW_PULL := 3.4
const AIM_OFFSET := Vector3.UP * 0.8
const CHEST := Vector3.UP * 2.6

var move_kind := Move.RAIN
var locked_point := Vector3.ZERO
var battle_elapsed := 0.0
var raised_water := WATER_FLOOR
var tears_released := 0
var tides_released := 0
var slaps := 0
var globs_fired := 0
var tell: MeshInstance3D
var boss_phase := 1
var submerged := false
var submerge_left := 0.0
var _second_tide_left := -1.0
var _cry_cooldown := 0.0
var _moves_since_dive := 0
var _lunge_left := 0.0
var _undertow_key: StringName

func _enter_tree() -> void:
	variant = 2
	is_boss = true
	super._enter_tree()
func _ready() -> void:
	super._ready()
	health.max_health = BASE_HEALTH
	health.health = BASE_HEALTH
	health.headshot_multiplier = 1.25
	action_left = 1.4
	# The first wail waits: an opening choke would steal the room's opening beat.
	_cry_cooldown = CRY_COOLDOWN
	_undertow_key = StringName("%s_undertow" % effect_key)
	(get_node("HeadHitbox") as Hitbox).position = to_local(visual.model.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("Head")).origin))
	health.after_damage.connect(_on_phase_damage)

func _on_phase_damage(_context: Dictionary) -> void:
	if boss_phase != 1 or health.is_dead():
		return
	if health.health > health.max_health * 0.50:
		return
	boss_phase = 2
	boss_phase_tempo_scale = 1.20
	health.max_shield = roundf(health.max_health * 0.15)
	health.shield_points = health.max_shield
	health.shield_regeneration_rate = 0.0
	health.shield_changed.emit(health.shield_points)
	phase_changed.emit(2)
func _physics_process(delta: float) -> void:
	if state == State.DEAD or boon_stunned or boon_time_scale <= 0:
		return
	delta *= boon_time_scale
	if _second_tide_left > 0.0:
		_second_tide_left -= delta
		if _second_tide_left <= 0.0:
			_second_tide_left = -1.0
			_spawn_tide()
	battle_elapsed += delta
	_rise_water()
	_cry_cooldown = maxf(0.0,_cry_cooldown-delta)
	if submerged:
		_tick_ambush(delta)
		return
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
	(visual as SorrowMonolithVisual).slam = maxf(0.0,action_left/ACTIVE) if action == 2 and move_kind == Move.SLAP else 0.0
	if move_kind == Move.SLAP:
		_lunge(delta)
	match action:
		0, 3:
			if action_left <= 0:
				if _ambush_due():
					start_submerge()
				else:
					begin_move(_next_move())
		1:
			if action_left <= 0:
				_release()
				action = 2
				action_left = ACTIVE
		_:
			if action_left <= 0:
				action = 3
				action_left = RECOVER_PHASE_TWO if boss_phase >= 2 else RECOVER_QUICK
				_lunge_left = 0.0
	_undertow()
	_boon_move_and_slide()

## Nothing here divides out the tempo twice: the shared action clock already
## runs on effective_attack_scale(), so the windup only carries the boon layer.
func begin_move(kind: int) -> void:
	if state == State.DEAD or submerged or not is_instance_valid(target):
		return
	move_kind = kind
	_moves_since_dive += 1
	locked_point = target.global_position
	action = 1
	action_left = WINDUP*boon_windup_scale
	_lunge_left = SLAP_LUNGE if kind == Move.SLAP else 0.0
	_clear_tell()
	if warnings_enabled:
		var radius := 4.1
		match kind:
			Move.SLAP:
				radius = SLAP_REACH
			Move.TIDE:
				radius = 2.4
			Move.CRY:
				radius = 5.0
		tell = MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 0.035
		mesh.radial_segments = 32
		tell.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.14,0.68,0.83,0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tell.material_override = mat
		get_parent().add_child(tell)
		var center := global_position if kind == Move.CRY else locked_point
		tell.global_position = Vector3(center.x,raised_water+0.06,center.z)

func _next_move() -> int:
	if _cry_cooldown <= 0.0 and (move_kind == Move.RAIN or move_kind == Move.SLAP):
		_cry_cooldown = CRY_COOLDOWN
		return Move.CRY
	match move_kind:
		Move.RAIN:
			return Move.TIDE
		Move.TIDE:
			return Move.SLAP
		_:
			return Move.RAIN

func _release() -> void:
	_clear_tell()
	_clear_undertow()
	if move_kind == Move.RAIN:
		_release_rain()
	elif move_kind == Move.TIDE:
		_spawn_tide()
		if boss_phase >= 2:
			_second_tide_left = 0.55
	elif move_kind == Move.SLAP:
		_release_slap()
	else:
		_release_cry()

func _release_rain() -> void:
	for x in range(-2,3):
		for z in range(-2,3):
			_drop_tear(locked_point+Vector3(x*1.65,9,z*1.65))
	if boss_phase >= 2:
		for index in 12:
			var angle := TAU*index/12.0
			_drop_tear(locked_point+Vector3(cos(angle)*4.5,9,sin(angle)*4.5))
	_fire_aimed_globs()
	_pull_into_water()

func _drop_tear(from: Vector3) -> void:
	var bullet := Projectile.spawn(get_parent(),from,Vector3.DOWN,self,8*realm_damage_scale,13,_hitbox_rids.duplicate(),Color(0.1,0.65,0.88))
	bullet.max_distance = 13
	_owned.append(weakref(bullet))
	tears_released += 1

## The grid punishes standing still; these two bolts aim at where the player
## actually is, so simply walking out of the marked square is not enough.
func _fire_aimed_globs() -> void:
	var aim := target.global_position+AIM_OFFSET
	var origin := global_position+CHEST
	var side := (aim-origin)*Vector3(1,0,1)
	side = side.normalized().cross(Vector3.UP)*0.9
	_fire_glob(origin+side,aim-(origin+side))
	_fire_glob(origin-side,aim-(origin-side))

func _fire_glob(from: Vector3, direction: Vector3) -> void:
	var aim := direction.normalized()
	if aim.length_squared() < 0.0001:
		return
	var bolt := SorrowGlob.new()
	bolt.source = self
	bolt.caster_ref = weakref(self)
	bolt.effect_target = target as Player
	bolt.effect_key = effect_key
	bolt.damage = 10*realm_damage_scale
	bolt.speed = 14
	bolt.max_distance = 40
	bolt.exclude = _hitbox_rids.duplicate()
	get_parent().add_child(bolt)
	bolt.global_position = from
	bolt.look_at(from+aim,Vector3.UP if absf(aim.y) < 0.99 else Vector3.FORWARD)
	_owned.append(weakref(bolt))
	Events.projectile_registered.emit(bolt)
	globs_fired += 1

## Shallow water is a hazard, not cover: it slows the swimmer and, when the
## rain is called, hands them back to the marked square.
func _pull_into_water() -> void:
	var player := target as Player
	if player == null or not _is_wet():
		return
	var inward := (locked_point-player.global_position)*Vector3(1,0,1)
	if inward.length_squared() < 0.25:
		return
	player.apply_external_impulse(inward.normalized(),UNDERTOW_PULL,0.3)

func _release_slap() -> void:
	slaps += 1
	var offset := target.global_position-locked_point
	if Vector2(offset.x,offset.z).length() < SLAP_REACH and _line_clear(target.global_position+Vector3.UP):
		var hp := target.get_node("Health") as Health
		var dealt := hp.apply_damage(24*realm_damage_scale,Hitbox.BodyPart.BODY,self,{"tag":&"monolith_slap"})
		if dealt > 0 and target.has_method("apply_external_impulse"):
			target.call("apply_external_impulse",target.global_position-global_position,12.0,0.25)
	_water_shock(locked_point)
	if is_instance_valid(arena):
		arena.add_ripple(locked_point)

## The palm throws a short ring of basin water. Only feet still standing in
## the mirror get clipped, which is what the ruins are for.
func _water_shock(point: Vector3) -> void:
	var ring := SorrowTide.new()
	ring.source = self
	ring.target = target as Player
	ring.water_level = raised_water
	ring.damage = 8*realm_damage_scale
	ring.speed = 26.0
	ring.max_radius = 3.0
	get_parent().add_child(ring)
	ring.global_position = point
	_owned.append(weakref(ring))

func _release_cry() -> void:
	cries += 1
	var pulse := ChokingCry.new()
	pulse.source = self
	pulse.target = target as Player
	pulse.effect_key = effect_key
	get_parent().add_child(pulse)
	pulse.global_position = global_position
	_owned.append(weakref(pulse))
	if boss_phase < 2:
		return
	for index in 3:
		var angle := TAU*index/3.0+rotation.y
		_fire_glob(global_position+CHEST,Vector3(cos(angle),-0.05,sin(angle)))

func _spawn_tide() -> void:
	var wave := SorrowTide.new()
	wave.source = self
	wave.target = target as Player
	wave.water_level = raised_water
	wave.damage *= realm_damage_scale
	get_parent().add_child(wave)
	wave.global_position = global_position
	_owned.append(weakref(wave))
	tides_released += 1

## Sinks under the mirror. The body and hitboxes leave the fight; the ripple
## is the only tell that the water is about to break somewhere else.
func start_submerge() -> void:
	if state == State.DEAD or submerged:
		return
	submerged = true
	submerge_left = SUBMERGE_TIME
	_moves_since_dive = 0
	_lunge_left = 0.0
	_stop()
	_clear_tell()
	_clear_undertow()
	action = 0
	visual.set_cast(0.0)
	visual.set_submerged(true)
	_set_hitboxes_layer(CollisionLayers.NONE)
	if is_instance_valid(arena):
		arena.add_ripple(global_position,1.8)

func _tick_ambush(delta: float) -> void:
	_stop()
	submerge_left -= delta
	if submerge_left <= 0.0:
		_resurface()

## Breaks the surface 5.5-7.5m from the player and attacks out of the splash:
## a slab that reappears at arm's length needs no second telegraph.
func _resurface() -> void:
	var spot := _ambush_spot()
	submerged = false
	submerge_left = 0.0
	if spot != Vector3.INF:
		global_position = spot
	visual.set_submerged(false)
	_set_hitboxes_layer(CollisionLayers.HITBOXES)
	if is_instance_valid(arena):
		arena.add_ripple(global_position,1.8)
	begin_move(Move.SLAP if boss_phase < 2 else Move.CRY)

## Flanks from the side the monolith already sits on, so the reappearance
## reads as a circle through the mirror rather than a teleport.
func _ambush_spot() -> Vector3:
	if not is_instance_valid(target):
		return Vector3.INF
	var goal := target.global_position
	var heading := (global_position-goal)*Vector3(1,0,1)
	var start := 0.0 if heading.length_squared() < 0.01 else atan2(heading.z,heading.x)
	for index in AMBUSH_TRIES:
		var angle := start+TAU*index/float(AMBUSH_TRIES)
		for radius in [AMBUSH_NEAR,AMBUSH_FAR]:
			var spot := _floor_below(goal+Vector3(cos(angle),0,sin(angle))*radius)
			if spot == Vector3.INF or not _navigable(spot) or _capsule_blocked(spot):
				continue
			return spot
	return Vector3.INF

func _floor_below(at: Vector3) -> Vector3:
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(at+Vector3.UP*6.0,at+Vector3.DOWN*12.0,CollisionLayers.WORLD))
	if hit.is_empty() or hit.normal.y < 0.7:
		return Vector3.INF
	return hit.position+Vector3.UP*0.05

func _navigable(spot: Vector3) -> bool:
	var map := _agent.get_navigation_map()
	if not map.is_valid():
		return true
	# A room without baked polygons cannot answer, and the floor probe above
	# already proved there is ground: only judge points the mesh covers.
	if not NavigationServer3D.map_get_closest_point_owner(map,spot).is_valid():
		return true
	return NavigationServer3D.map_get_closest_point(map,spot).distance_to(spot) <= 1.5

func _capsule_blocked(spot: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.1
	capsule.height = 4.2
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,spot+Vector3.UP*2.2)
	query.collision_mask = CollisionLayers.WORLD
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _ambush_due() -> bool:
	if not is_instance_valid(target):
		return false
	var flat := (target.global_position-global_position)*Vector3(1,0,1)
	return flat.length() > AMBUSH_PROWL or _moves_since_dive >= 2

## Runs while the rain is gathering and while a tide is in the water: standing
## in the shallows costs movement speed for as long as the wave is coming.
func _undertow() -> void:
	var active := (action == 1 and (move_kind == Move.RAIN or move_kind == Move.TIDE)) or (action == 2 and move_kind == Move.TIDE)
	var player: Player = target as Player if is_instance_valid(target) else null
	if player == null or not active or not _is_wet():
		_clear_undertow()
		return
	player.set_realm_effect(_undertow_key,{"owner":self,"duration":0.2,"move_multiplier":UNDERTOW_MOVE})

func _clear_undertow() -> void:
	var player: Player = target as Player if is_instance_valid(target) else null
	if player != null:
		player.clear_realm_effect(_undertow_key)

func _is_wet() -> bool:
	return is_instance_valid(target) and target.global_position.y <= raised_water+0.25

## Closes up to 3.5m on the marked square while the arm is coming down, so a
## dodge has to be a real step and not a wiggle.
func _lunge(delta: float) -> void:
	if _lunge_left <= 0.0:
		return
	var toward := (locked_point-global_position)*Vector3(1,0,1)
	if toward.length() < 0.4:
		_lunge_left = 0.0
		return
	var speed := minf(LUNGE_SPEED,_lunge_left/maxf(delta,0.0001))
	var dir := toward.normalized()
	velocity.x = dir.x*speed
	velocity.z = dir.z*speed
	_lunge_left -= speed*delta

func _rise_water() -> void:
	raised_water = clampf(WATER_FLOOR+(1.0-health.health/health.max_health)*WATER_GRIEF+battle_elapsed*WATER_CREEP,WATER_FLOOR,WATER_CAP)
	if is_instance_valid(arena):
		arena.set_water_level(raised_water)

func _on_died(source: Node) -> void:
	if state == State.DEAD:
		return
	_second_tide_left = -1.0
	submerged = false
	submerge_left = 0.0
	_clear_tell()
	visual.set_submerged(false)
	super._on_died(source)
	if is_instance_valid(arena):
		arena.set_deprivation(true)
	realm_defeated.emit(3)
func _clear_tell() -> void:
	if is_instance_valid(tell):
		tell.queue_free()
	tell = null
func _clear_owned() -> void:
	_clear_undertow()
	super._clear_owned()
func _exit_tree() -> void:
	_second_tide_left = -1.0
	_clear_tell()
	super._exit_tree()

## A mourner's cry only slows the hands. The monolith's own wail replaces that
## entry with the choking version the boss fight is built around.
class ChokingCry extends SorrowCry:
	const DURATION := 2.2
	const RELOAD_MULTIPLIER := 0.55
	const COOLDOWN_MULTIPLIER := 1.6
	var _landed := false

	func _physics_process(delta: float) -> void:
		_landed = hit_player
		super._physics_process(delta)
		if hit_player and not _landed and is_instance_valid(target):
			target.set_realm_effect(effect_key,{"owner":source,"duration":DURATION,"reload_multiplier":RELOAD_MULTIPLIER,"cooldown_multiplier":COOLDOWN_MULTIPLIER,"monochrome":1.0})
