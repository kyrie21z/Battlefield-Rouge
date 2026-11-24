extends Node3D
## Ticket 03 guard: every realm attack clock compresses exactly once by
## 1 / realm_tempo_scale (never tempo²), and FearWisp inherits the summoner's
## hp, damage and tempo axes.

const WRATH := preload("res://actors/enemy/wrath/wrath_realm_enemy.tscn")
const SLOTH_REALM := preload("res://actors/enemy/sloth/sloth_realm_enemy.tscn")
const FEAR := preload("res://actors/enemy/fear/fear_realm_enemy.tscn")
const WISP := preload("res://actors/enemy/fear/fear_wisp.tscn")
const PLAYER := preload("res://actors/player/player.tscn")
const FAST_TEMPO := 1.4

var checks := 0
var failures := 0
var player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	get_tree().paused = false
	print("REALM TEMPO WIRING: %s (%d checks, %d failed)" % [
		"ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _run() -> void:
	_build_floor()
	player = PLAYER.instantiate() as Player
	add_child(player)
	player.position = Vector3(0, 0.05, -12)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.health.max_health = 100000
	player.health.health = 100000
	await _frames(3)

	# Clock already multiplied by attack_scale: windup basis stays boon-only.
	var sloth_normal := await _measure_sloth_cast(1.0)
	var sloth_fast := await _measure_sloth_cast(FAST_TEMPO)
	_check("sloth realm volley keeps its authored 1.2 s cast at 1.0x (%d frames)" % sloth_normal,
		sloth_normal >= 68 and sloth_normal <= 77)
	_check("sloth realm volley compresses once at 1.4x (%d frames)" % sloth_fast,
		sloth_fast >= 48 and sloth_fast <= 57)
	_check("sloth realm cast ratio is 1.4x, not tempo² (%.2f)" % (float(sloth_normal) / float(sloth_fast)),
		absf(float(sloth_normal) / float(sloth_fast) - FAST_TEMPO) < 0.12)

	var wrath_normal := await _measure_wrath_windup(1.0)
	var wrath_fast := await _measure_wrath_windup(FAST_TEMPO)
	_check("wrath piercer keeps its authored 0.75 s windup at 1.0x (%d frames)" % wrath_normal,
		wrath_normal >= 42 and wrath_normal <= 48)
	_check("wrath piercer windup compresses once at 1.4x (%d frames)" % wrath_fast,
		wrath_fast >= 30 and wrath_fast <= 36)
	_check("wrath windup ratio is 1.4x, not tempo² (%.2f)" % (float(wrath_normal) / float(wrath_fast)),
		absf(float(wrath_normal) / float(wrath_fast) - FAST_TEMPO) < 0.12)

	var wisp_normal := await _measure_wisp_windup(1.0, 1.35, 1.0)
	var wisp_fast := await _measure_wisp_windup(1.28, 1.35, 1.15)
	_check("fear wisp keeps its authored 0.55 s windup at 1.0x (%d frames)" % wisp_normal,
		wisp_normal >= 30 and wisp_normal <= 36)
	_check("fear wisp windup compresses once at 1.28x (%d frames)" % wisp_fast,
		wisp_fast >= 22 and wisp_fast <= 29)
	_check("fear wisp windup ratio is 1.28x, not tempo² (%.2f)" % (float(wisp_normal) / float(wisp_fast)),
		absf(float(wisp_normal) / float(wisp_fast) - 1.28) < 0.14)

	# A boon windup and the room tempo compose once each, multiplicatively.
	var watcher := FEAR.instantiate() as FearRealmEnemy
	watcher.variant = FearRealmEnemy.Variant.WATCHER
	watcher.position = Vector3(6, 0.05, -6)
	add_child(watcher)
	watcher.apply_realm_scaling(1.0, 1.0, FAST_TEMPO)
	watcher.boon_windup_scale = 1.3
	_check("fear windup is base * boon / tempo (%.3f)" % watcher.windup(),
		is_equal_approx(watcher.windup(), 1.6 * 1.3 / FAST_TEMPO))
	watcher.boon_windup_scale = 1.0
	_check("clearing the boon windup keeps realm tempo intact",
		is_equal_approx(watcher.realm_tempo_scale, FAST_TEMPO)
		and is_equal_approx(watcher.windup(), 1.6 / FAST_TEMPO))
	watcher.queue_free()
	await _frames(2)

func _measure_sloth_cast(tempo: float) -> int:
	var actor := SLOTH_REALM.instantiate() as SlothRealmEnemy
	actor.variant = SlothRealmEnemy.Variant.LAGGARD
	actor.warnings_enabled = false
	actor.position = Vector3(0, 0.05, -6)
	player.position = Vector3(0, 0.05, -12)
	add_child(actor)
	actor.apply_realm_scaling(1.0, 1.0, tempo)
	actor.setup(player, [])
	await _frames(1)
	actor.start_volley()
	var frames := 0
	while actor.cast_left > 0.0 and frames < 400:
		await get_tree().physics_frame
		frames += 1
	for child in get_children():
		if child is SlothRealmProjectile:
			child.queue_free()
	actor.queue_free()
	await _frames(2)
	return frames

func _measure_wrath_windup(tempo: float) -> int:
	var actor := WRATH.instantiate() as WrathRealmEnemy
	actor.variant = WrathRealmEnemy.Variant.PIERCER
	actor.warnings_enabled = false
	actor.position = Vector3(0, 0.05, -6)
	player.position = Vector3(0, 0.05, -12)
	add_child(actor)
	actor.apply_realm_scaling(1.0, 1.0, tempo)
	actor.setup(player, [])
	var frames := 0
	while actor.attack_phase != WrathRealmEnemy.Attack.WINDUP and frames < 10:
		await get_tree().physics_frame
		frames += 1
	frames = 0
	while actor.attack_phase == WrathRealmEnemy.Attack.WINDUP and frames < 400:
		await get_tree().physics_frame
		frames += 1
	actor.queue_free()
	await _frames(1)
	return frames

func _measure_wisp_windup(tempo: float, hp_scale: float, damage_scale: float) -> int:
	var summoner := WRATH.instantiate() as WrathRealmEnemy
	summoner.variant = WrathRealmEnemy.Variant.PIERCER
	summoner.position = Vector3(14, 0.05, -12)
	add_child(summoner)
	summoner.apply_realm_scaling(hp_scale, damage_scale, tempo)
	summoner.set_physics_process(false)
	var wisp := WISP.instantiate() as FearWisp
	add_child(wisp)
	wisp.activate(Vector3(0, 1.4, -4), summoner, player)
	player.position = Vector3(0, 0.05, -3.0)
	_check("wisp max health follows realm_hp_scale, not damage (%.2f)" % wisp.health.max_health,
		is_equal_approx(wisp.health.max_health, 18.0 * hp_scale))
	_check("wisp inherits damage scale %.2f and tempo %.2f" % [wisp.realm_damage_scale, wisp.realm_tempo_scale],
		is_equal_approx(wisp.realm_damage_scale, damage_scale)
		and is_equal_approx(wisp.realm_tempo_scale, tempo))
	_check("wisp chase speed follows half-strength tempo (%.3f)" % wisp.run_speed,
		is_equal_approx(wisp.run_speed, FearWisp.SPEED * (1.0 + (tempo - 1.0) * 0.5)))
	_check("wisp windup scales from effective windup (%.3f)" % (FearWisp.WINDUP * wisp.effective_windup_scale()),
		is_equal_approx(FearWisp.WINDUP * wisp.effective_windup_scale(), FearWisp.WINDUP / tempo))
	var frames := 0
	while wisp.attack_elapsed < 0.0 and frames < 20:
		await get_tree().physics_frame
		frames += 1
	frames = 0
	var windup_time := FearWisp.WINDUP * wisp.effective_windup_scale()
	while is_instance_valid(wisp) and wisp.attack_elapsed < windup_time and frames < 200:
		await get_tree().physics_frame
		frames += 1
	if is_instance_valid(wisp):
		wisp.set_physics_process(false)
		wisp.queue_free()
	summoner.queue_free()
	await _frames(1)
	return frames

func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = CollisionLayers.NONE
	body.position = Vector3(0, -0.5, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	body.add_child(shape)
	add_child(body)

func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame

func _check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])