extends Node3D
## Ticket 06: the mind blade's own feel (arc ribbon, burst curve, hit weight)
## and the shield-block answer, checked through the real weapon and the real
## Wrath Accumulator.

const PLAYER := preload("res://actors/player/player.tscn")
const WRATH := preload("res://actors/enemy/wrath/wrath_realm_enemy.tscn")

class Dummy extends CharacterBody3D:
	var team := 1
	var last_force := 0.0
	var last_stagger := 0.0

	func apply_impact(_direction: Vector3, force: float, stagger: float) -> void:
		last_force = force
		last_stagger = stagger


var _world: Node3D
var _shooter: Dummy
var _blade: MeleeWeapon
var _shakes: Array[Vector3] = []
var _checks := 0
var _failed := 0


func _ready() -> void:
	_world = Node3D.new()
	add_child(_world)
	_shooter = _dummy(Vector3.ZERO, 0)
	var camera := Camera3D.new()
	_shooter.add_child(camera)
	camera.current = true
	_blade = MeleeWeapon.new()
	_blade.camera = camera
	_blade.shooter = _shooter
	camera.add_child(_blade)
	_blade.set_process(false)
	_blade.shake.connect(func(degrees: float, fov_punch: float, duration: float) -> void:
		_shakes.append(Vector3(degrees, fov_punch, duration)))
	await _settle()
	await _test_burst_curve()
	await _test_hit_weight()
	await _test_trail_lifecycle()
	await _test_shield_block()
	_blade.cancel()
	_blade.deactivate()
	_world.free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	print("MIND BLADE FEEL: %d checks, %d failed" % [_checks, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


## The active phase has to read as a committed cut: still while it is loaded,
## fast through the middle, and parked exactly on the end pose.
func _test_burst_curve() -> void:
	var data := _blade.current()
	_check("mind blade shoves with 6.2", is_equal_approx(data.impact_force, 6.2))
	_check("mind blade staggers for 0.22s", is_equal_approx(data.impact_stagger, 0.22))
	var monotonic := true
	var previous := 0.0
	for i in 101:
		var value := MeleeWeapon._ease_burst(i / 100.0)
		monotonic = monotonic and value >= previous - 0.000001
		previous = value
	_check("burst curve never runs backwards and ends exactly on 1",
		monotonic and is_equal_approx(previous, 1.0))
	_check("burst curve holds the wind-in, snaps late and settles",
		MeleeWeapon._ease_burst(0.25) < 0.05
		and MeleeWeapon._ease_burst(0.9) - MeleeWeapon._ease_burst(0.6) > 0.45)
	# Follow the real pivot through one cut and measure how far the tip moves
	# per step. The fastest step has to sit past the middle of the window.
	_blade.cancel()
	_blade._cooldown = 0.0
	_check("swing starts for the curve sample", _blade.swing_now())
	_blade._process(0.08)
	var steps: Array[float] = []
	var previous_tip := _tip()
	while _blade._phase == MeleeWeapon.Phase.ACTIVE and steps.size() < 60:
		_blade._process(0.004)
		var tip := _tip()
		steps.append(previous_tip.distance_to(tip))
		previous_tip = tip
	var total := 0.0
	var peak := 0.0
	var peak_index := 0
	for i in steps.size():
		total += steps[i]
		if steps[i] > peak:
			peak = steps[i]
			peak_index = i
	var opening := 0.0
	for i in mini(6, steps.size()):
		opening += steps[i]
	_check("cut travels across the arc (%.2fm in %d steps)" % [total, steps.size()], total > 0.3)
	_check("cut snaps past the middle, not at it (peak %d/%d)" % [peak_index, steps.size()],
		peak >= 0.0 and peak_index >= steps.size() / 2)
	_check("first sixth of the cut stays under 8% of the travel", opening < total * 0.08)
	_check("cut settles onto the end pose", steps[steps.size() - 1] < peak * 0.5)


func _test_hit_weight() -> void:
	_blade.cancel()
	_blade._cooldown = 0.0
	var target := _dummy(Vector3(0, 0, -3), 1)
	await _settle()
	var shards_before := CrystalImpact.alive
	_check("swing starts for the weight sample", _blade.swing_now())
	var trail := _blade.get_node_or_null("BladeSlashTrail") as BladeSlashTrail
	_check("blade owns a pause-scoped ribbon", trail != null and trail.get_parent() == _blade
		and not trail.is_trailing())
	_check("ribbon is hidden before the cut", not trail.visible)
	_blade._process(0.08)
	_check("ribbon is hidden until the blade has travelled", not trail.is_trailing())
	_blade._process(0.03)
	_check("ribbon opens with the active window", _blade._phase == MeleeWeapon.Phase.ACTIVE
		and trail.is_trailing())
	_shakes.clear()
	_blade._process(0.09)
	_check("hit lands", _health(target).health < 100.0)
	_check("hit pushes with the tuned force and stagger",
		is_equal_approx(target.last_force, 6.2) and is_equal_approx(target.last_stagger, 0.22))
	_check("hit emits the melee camera shake", _shakes.size() == 1
		and _shakes[0].is_equal_approx(Vector3(0.65, 0.018, 0.14)))
	_check("hit plays the upgraded melee cue at full level",
		is_zero_approx(_blade._audio.volume_db) and _blade._audio.stream == _blade._hit_sound)
	_check("hit spawns a crystal cleave, not a fleshy puff",
		CrystalImpact.alive == shards_before + 1)
	var arrays := (trail.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	_check("ribbon is a strip of blade samples with per-vertex glow",
		vertices.size() >= 4 and vertices.size() % 2 == 0 and colors.size() == vertices.size())
	var glow := trail.material_override as StandardMaterial3D
	_check("ribbon is an unshadowed additive crystal glow", glow != null
		and glow.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		and glow.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
		and trail.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_blade._process(0.03)
	_check("ribbon keeps the finished arc while it fades",
		_blade._phase == MeleeWeapon.Phase.RECOVERY and trail.is_trailing())
	_check("ribbon fade is the authored 0.14s", is_equal_approx(trail._fade_left, 0.14))
	target.free()


func _test_trail_lifecycle() -> void:
	var trail := _blade.get_node("BladeSlashTrail") as BladeSlashTrail
	_blade.cancel()
	_blade._cooldown = 0.0
	_blade.swing_now()
	_blade._process(0.08)
	_blade._process(0.13)
	var left := trail._fade_left
	get_tree().paused = true
	trail._process(0.05)
	_check("pause freezes the ribbon fade", is_equal_approx(trail._fade_left, left))
	get_tree().paused = false
	trail._process(0.07)
	trail._process(0.08)
	_check("ribbon is gone inside the fade window",
		not trail.is_trailing() and trail.mesh.get_surface_count() == 0)
	_blade.cancel()
	_check("cancel clears the ribbon at once", not trail.is_trailing())


## The Accumulator's front shield has to answer with its own cue: no HP loss,
## no ordinary crystal impact and no hitmarker, but one hit_blocked and sparks.
func _test_shield_block() -> void:
	var ground := _wall(Vector3(0, -0.5, 0), Vector3(60, 1, 60))
	var player := PLAYER.instantiate() as Player
	player.position = Vector3(0, 0, -6)
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.health.max_health = 10000.0
	player.health.health = 10000.0
	await _settle()
	var shield := WRATH.instantiate() as WrathRealmEnemy
	shield.variant = WrathRealmEnemy.Variant.ACCUMULATOR
	shield.position = Vector3.ZERO
	shield.rotation.y = 0.0
	add_child(shield)
	await _settle()
	_check("player routes melee shake into the view",
		player.melee.shake.is_connected(Callable(player, "_on_weapon_shake")))
	player.melee.shake.emit(0.65, 0.018, 0.14)
	_check("melee shake reaches the player camera", player._shake_left > 0.0)
	var health_before := shield.health.health
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var landed := [0]
	player.weapon.hit_blocked.connect(func(point: Vector3, normal: Vector3) -> void:
		points.append(point)
		normals.append(normal))
	player.weapon.hit_landed.connect(func(_headshot: bool, _killed: bool) -> void:
		landed[0] += 1)
	var shards_before := CrystalImpact.alive
	player.weapon._shoot_ray(Vector3(0, 1.1, -6), Vector3.BACK)
	_check("accumulator eats the frontal shot", is_equal_approx(shield.health.health, health_before)
		and shield.blocked_shots == 1)
	_check("block is marked on the resolved damage context",
		bool(shield.health.last_damage_context.get("blocked_by_shield", false)))
	_check("block fires hit_blocked exactly once", points.size() == 1)
	_check("block suppresses the ordinary hitmarker", landed[0] == 0)
	_check("deflect sparks face the shooter",
		normals.size() == 1 and normals[0].z < -0.5 and not points[0].is_equal_approx(Vector3.ZERO))
	_check("block prints no crystal shards", CrystalImpact.alive == shards_before)
	shield.queue_free()
	player.queue_free()
	ground.queue_free()
	await get_tree().process_frame


func _tip() -> Vector3:
	return _blade.grip_transform() * Vector3(0.0, 0.0, -_blade.blade_length())


func _dummy(at: Vector3, team: int) -> Dummy:
	var body := Dummy.new()
	body.team = team
	body.collision_layer = 0
	body.collision_mask = 0
	body.position = at
	var health := Health.new()
	health.name = "Health"
	health.team = team
	body.add_child(health)
	var hitbox := Hitbox.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	shape.shape = sphere
	hitbox.add_child(shape)
	body.add_child(hitbox)
	_world.add_child(body)
	return body


func _health(body: Dummy) -> Health:
	return body.get_node("Health") as Health


func _wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child(body)
	return body


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failed += 1
	print("[%s] %s" % ["ok" if passed else "FAIL", label])
