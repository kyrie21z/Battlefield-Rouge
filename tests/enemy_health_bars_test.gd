extends Node

const REALMS := ["sloth", "fear", "wrath", "sorrow"]
const CAMERA_ORIGIN := Vector3(0, 60, 0)
const PLAYER := preload("res://actors/player/player.tscn")
const WISP := preload("res://actors/enemy/fear/fear_wisp.tscn")

var _checks := 0
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	for realm in REALMS:
		await _room(realm)
		await _boss_room(realm)
	await _legacy_hud()
	await _climax_hud()
	print("ENEMY HEALTH BARS: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _room(realm: String) -> void:
	var room := _load_room(realm + "_1")
	var camera := room.player.view_camera
	var bars := room.hud.find_child("EnemyHealthBars", true, false) as EnemyHealthBars
	_check(realm + " discovers the initial room enemies", bars.tracked_count() == room.enemies.size())
	_check_mount(realm, bars, room.hud.crosshair, room.hud.combat_feedback)
	for i in room.enemies.size():
		room.enemies[i].global_position = CAMERA_ORIGIN + Vector3(float(i) - 2.0, -1.5, -10.0)
	await _settle()
	for enemy in room.enemies:
		_check(realm + " shows " + str(enemy.name), not _bar(bars, enemy).is_empty())
	if realm == "fear":
		await _wisp(room, bars)
	elif realm == "sorrow":
		var walker := room.enemies[0] as SorrowRealmEnemy
		walker.start_dive()
		await _settle()
		_check("sorrow dive hides the bar", _bar(bars, walker).is_empty())
		walker.resurface()
		walker.global_position = CAMERA_ORIGIN + Vector3(0, -1.5, -9)
		await _settle()
		_check("sorrow resurface restores the bar", not _bar(bars, walker).is_empty())
	elif realm == "wrath":
		await _visibility_and_trail(room, bars, room.enemies[0], camera)

	room.queue_free()
	await get_tree().process_frame
	_check(realm + " frees the bars with the room", not is_instance_valid(bars))


func _load_room(room_name: String) -> RealmStage:
	var room := load("res://maps/realms/%s.tscn" % room_name).instantiate() as RealmStage
	add_child(room)
	_hold_player(room.player)
	for enemy in room.enemies:
		enemy.set_physics_process(false)
		enemy.set_process(false)
	return room


func _hold_player(player: Player) -> void:
	player.set_physics_process(false)
	player.set_process(false)
	player.dash.set_physics_process(false)
	player.global_position = CAMERA_ORIGIN - Vector3.UP * 1.5
	player.view_camera.global_transform = Transform3D(Basis.IDENTITY, CAMERA_ORIGIN)
	player.view_camera.make_current()


func _wisp(room: RealmStage, bars: EnemyHealthBars) -> void:
	var reaper: FearReaper
	for enemy in room.enemies:
		if enemy is FearReaper:
			reaper = enemy
	var dormant := room.find_children("*", "FearWisp", false, false)[0] as FearWisp
	var point := CAMERA_ORIGIN + Vector3(2, -1.5, -8)
	dormant.global_position = point
	var initial_count := bars.tracked_count()
	await _settle()
	_check("fear dormant wisp remains hidden", dormant.dormant and _bar(bars, dormant).is_empty())
	dormant.activate(point, reaper, room.player)
	dormant.set_physics_process(false)
	await _settle()
	var expected := room.player.view_camera.unproject_position(point + Vector3.UP * (dormant.eye_height + 0.55))
	var bar := _bar(bars, dormant)
	_check("fear activation registers exactly one wisp", bars.tracked_count() == initial_count + 1)
	_check("fear wisp projects its fallback anchor", not bar.is_empty() and bar.position.is_equal_approx(expected))
	dormant.queue_free()
	await get_tree().process_frame
	_check("freeing a wisp removes its entry", bars.tracked_count() == initial_count)


func _visibility_and_trail(room: RealmStage, bars: EnemyHealthBars, enemy: Enemy, camera: Camera3D) -> void:
	var head := enemy.get_node("HeadHitbox/Shape") as CollisionShape3D
	var sphere := head.shape as SphereShape3D
	var aim_height := head.global_position.y - enemy.global_position.y + sphere.radius
	enemy.global_position = CAMERA_ORIGIN + Vector3(4, -aim_height, -12)
	await _settle()
	var bar := _bar(bars, enemy)
	var head_top := head.global_position + Vector3.UP * sphere.radius
	_check("head hitbox top projects to the HUD", not bar.is_empty()
		and bar.position.is_equal_approx(camera.unproject_position(head_top)))
	bar.health = -1.0
	_check("inspection returns a detached snapshot", _bar(bars, enemy).get("health") == enemy.health.max_health)

	enemy.global_position.z = -17.5
	await _settle()
	_check("full health just within 18 m is visible outside the aim cone", not _bar(bars, enemy).is_empty())
	enemy.global_position.z = -17.6
	await _settle()
	_check("full health just beyond 18 m is hidden outside the aim cone", _bar(bars, enemy).is_empty())

	enemy.global_position = CAMERA_ORIGIN + Vector3(4, -aim_height, -24)
	await _settle()
	_check("full health outside near range and aim cone is hidden", _bar(bars, enemy).is_empty())
	enemy.global_position.x = 3.2
	await _settle()
	_check("full health just inside the aim cone is visible", not _bar(bars, enemy).is_empty())
	enemy.global_position.x = 4.0
	await _settle()
	_check("full health hides when the aim cone leaves", _bar(bars, enemy).is_empty())

	var health := enemy.health
	var initial_health := health.health
	head.get_parent().apply_hit(20.0, room.player, {"true_damage": true})
	await _settle()
	bar = _bar(bars, enemy)
	_check("damage reveals the distant target with immediate HP and a white trail",
		not bar.is_empty() and bar.health == initial_health - 20.0 and bar.delayed == initial_health)

	get_tree().paused = true
	_check("pause hides the projected bars", _bar(bars, enemy).is_empty())
	await get_tree().create_timer(HealthTrail.HOLD + 0.25).timeout
	get_tree().paused = false
	await _settle()
	_check("pause preserves the held trail", _bar(bars, enemy).get("delayed") == initial_health)
	await get_tree().create_timer(HealthTrail.HOLD + 0.25).timeout
	bar = _bar(bars, enemy)
	_check("unpaused trail drains to the current HP",
		not bar.is_empty() and is_equal_approx(bar.delayed, bar.health))

	health.max_shield = 20.0
	health.grant_shield(12.0)
	await _settle()
	bar = _bar(bars, enemy)
	_check("shield capacity and fill follow Health", bar.get("max_shield") == 20.0 and bar.get("shield") == 12.0)
	health.break_shield()
	await _settle()
	bar = _bar(bars, enemy)
	_check("depleted shield retains its track", bar.get("max_shield") == 20.0 and bar.get("shield") == 0.0)
	health.max_shield = 0.0
	health.grant_shield(6.0)
	await _settle()
	bar = _bar(bars, enemy)
	_check("temporary shield works with zero max shield", bar.get("max_shield") == 0.0 and bar.get("shield") == 6.0)
	health.break_shield()

	var blocker := _wall(room, (camera.global_position + head.global_position + Vector3.UP * sphere.radius) * 0.5)
	await _settle()
	_check("world geometry occludes the bar", _bar(bars, enemy).is_empty())
	blocker.collision_layer = CollisionLayers.ENEMIES
	await _settle()
	_check("non-world collision does not occlude the bar", not _bar(bars, enemy).is_empty())
	blocker.queue_free()

	enemy.global_position = CAMERA_ORIGIN + Vector3(0, -aim_height, -31.9)
	await _settle()
	_check("damaged enemy just within 32 m is visible", not _bar(bars, enemy).is_empty())
	enemy.global_position.z = -32.1
	await _settle()
	_check("damaged enemy beyond 32 m is hidden", _bar(bars, enemy).is_empty())
	enemy.global_position.z = 10.0
	await _settle()
	_check("enemy behind the camera is hidden", _bar(bars, enemy).is_empty())
	enemy.global_position = CAMERA_ORIGIN + Vector3(4, -aim_height, -24)
	health.health = health.max_health
	await _settle()
	_check("revealed enemy remains visible after healing", not _bar(bars, enemy).is_empty())

	health.apply_damage(1.0, Hitbox.BodyPart.BODY, room.player, {"true_damage": true})
	bar = _bar(bars, enemy)
	_check("visible bar updates HP in the same damage callback",
		bar.get("health") == health.health and bar.get("delayed") == health.max_health)
	var before := bars.tracked_count()
	health.apply_damage(health.max_health, Hitbox.BodyPart.BODY, room.player, {"true_damage": true})
	_check("enemy death removes the bar synchronously", _bar(bars, enemy).is_empty()
		and bars.tracked_count() == before - 1)
	room.player.health.apply_damage(room.player.health.max_health, Hitbox.BodyPart.BODY, null,
		{"environmental_fatal": true})
	_check("player death hides and releases every enemy bar", bars.visible_entries().is_empty()
		and bars.tracked_count() == 0)
	get_tree().paused = false


func _wall(room: RealmStage, point: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.5)
	shape.shape = box
	wall.position = point
	wall.add_child(shape)
	room.add_child(wall)
	return wall


func _boss_room(realm: String) -> void:
	var room := _load_room(realm + "_boss")
	room.boss.global_position = CAMERA_ORIGIN + Vector3(0, -1.5, -9)
	await _settle()
	var bars := room.hud.find_child("EnemyHealthBars", true, false) as EnemyHealthBars
	_check(realm + " boss has no overhead bar", room.boss.is_boss and bars.tracked_count() == 0
		and _bar(bars, room.boss).is_empty())
	room.queue_free()
	await get_tree().process_frame


func _legacy_hud() -> void:
	var room := preload("res://maps/zone_1.tscn").instantiate()
	add_child(room)
	var hud := room.get_node("HUD")
	var bars := hud.get_node("EnemyHealthBars") as EnemyHealthBars
	_check_mount("legacy", bars, hud.get_node("Crosshair"), hud.get_node("Hitmarker"))
	_check("legacy HUD discovers scene enemies", bars.tracked_count() > 0)
	room.queue_free()
	await get_tree().process_frame
	get_tree().paused = false


func _climax_hud() -> void:
	var player := PLAYER.instantiate() as Player
	add_child(player)
	_hold_player(player)
	var wisp := WISP.instantiate() as FearWisp
	wisp.position = CAMERA_ORIGIN + Vector3(1, -1.5, -8)
	add_child(wisp)
	wisp.set_physics_process(false)
	var hud := ClimaxCombatHUD.new()
	hud.setup(player)
	seed(245)
	var expected := randi()
	seed(245)
	add_child(hud)
	_check_mount("climax", hud.combat_root.get_node("EnemyHealthBars"), hud.crosshair, hud.combat_feedback)
	var bars := hud.combat_root.get_node("EnemyHealthBars") as EnemyHealthBars
	_check("climax hides overhead bars outside combat", bars.visible_entries().is_empty())
	hud.set_combat_visible(true)
	await _settle()
	_check("climax shows the already spawned enemy in combat", not _bar(bars, wisp).is_empty())
	_check("overhead tracking, culling and drawing preserve the global RNG sequence", randi() == expected)
	hud.set_combat_visible(false)
	_check("climax combat hide immediately hides overhead bars", bars.visible_entries().is_empty())
	hud.queue_free()
	wisp.queue_free()
	player.queue_free()
	await get_tree().process_frame


func _check_mount(label: String, bars: EnemyHealthBars, crosshair: Node, hitmarker: Node) -> void:
	_check(label + " mounts a mouse-ignoring layer below crosshair and hitmarker",
		bars.mouse_filter == Control.MOUSE_FILTER_IGNORE and bars.get_parent() == crosshair.get_parent()
		and bars.get_index() < crosshair.get_index() and bars.get_index() < hitmarker.get_index())


func _bar(bars: EnemyHealthBars, enemy: Enemy) -> Dictionary:
	return bars.visible_entries().get(enemy.get_instance_id(), {})


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
