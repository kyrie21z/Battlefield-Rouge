extends Node
## Headless check of the graphical HUD: vitals, ammo, abilities, world markers,
## objectives and boss health. Run from the project root:
##   godot --headless --path . res://tests/hud_test.tscn
## Prints one line per check. Exits 1 if a check failed or if the run stopped
## before the last check, so it cannot pass by accident.

# 67 original + 29 small-zone + 107 projection + 25 boss + 14 layout checks.
const EXPECTED_CHECKS := 242

var _checks := 0
var _failures := 0
var _finished := false
var _player: Player
var _hud: CanvasLayer
var _vitals: Vitals
var _panel: WeaponPanel
var _shield_slot: AbilitySlot
var _melee_slot: AbilitySlot


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d checks, %d failed%s)" % ["ALL PASSED" if ok else "FAIL", _checks,
		_failures, "" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false

	_player = scene.get_node("Player") as Player
	_hud = scene.get_node("HUD") as CanvasLayer
	_vitals = _hud.get_node("Vitals") as Vitals
	_panel = _hud.get_node("WeaponPanel") as WeaponPanel
	_shield_slot = _hud.get_node("AbilityBar/Shield") as AbilitySlot
	_melee_slot = _hud.get_node("AbilityBar/Melee") as AbilitySlot
	# The test drives every timer itself, so the scene cannot drift between checks.
	_player.set_process(false)
	_player.set_physics_process(false)
	_player.weapon.set_process(false)
	_player.melee.set_process(false)
	_player.shield.set_process(false)
	_player.combat_traits.set_process(false)
	_vitals.set_process(false)
	_panel.set_process(false)
	_shield_slot.set_process(false)
	_melee_slot.set_process(false)

	print("== vitals")
	_vitals.advance(0.0)
	_check("full health reads 100", _vitals.health_number == 100
		and is_equal_approx(_vitals.displayed_health, 100.0))
	_player.health.apply_damage(38.0, Hitbox.BodyPart.BODY, null)
	_vitals.advance(0.016)
	_check("damage moves the number and the bar", _vitals.health_number == 62
		and is_equal_approx(_vitals.displayed_health, 62.0))
	_check("the lost part is held white", _vitals.delayed_health > 99.0)
	var held := _vitals.delayed_health
	_vitals.advance(0.3)
	_check("the white trail still holds after 0.3 s", is_equal_approx(_vitals.delayed_health, held))
	_vitals.advance(0.2)
	_check("the white trail shrinks after the hold", _vitals.delayed_health < held
		and _vitals.delayed_health > 62.0)
	_vitals.advance(1.0)
	_check("the white trail settles on the real health", is_equal_approx(_vitals.delayed_health, 62.0))
	_player.health.apply_damage(32.0, Hitbox.BodyPart.BODY, null)
	_vitals.advance(0.016)
	_check("30% does not turn the border warning red", _vitals.health_number == 30 and not _vitals.warning)
	_player.health.apply_damage(1.0, Hitbox.BodyPart.BODY, null)
	_vitals.advance(0.016)
	_check("29% turns the border warning red", _vitals.health_number == 29 and _vitals.warning)
	_check("the white trail is still held before healing", _vitals.delayed_health > 40.0)
	_player.health.health = 40.0
	_vitals.advance(0.0)
	_check("healing updates health and clears the warning", _vitals.health_number == 40
		and is_equal_approx(_vitals.displayed_health, 40.0) and not _vitals.warning)
	_check("healing immediately resets the white trail", is_equal_approx(_vitals.delayed_health, 40.0))

	print("== ammo and the gun rack")
	_player.weapon.select(0)
	_player.weapon.ammo = 8
	_player.weapon.reserve = 120
	_panel.advance(0.0)
	_check("ammo numbers follow the magazine", _panel.ammo_text == "8 / 120" and not _panel.ammo_low)
	_player.weapon.ammo = 7
	_panel.advance(0.0)
	_check("25% or less turns the ammo red", _panel.ammo_low
		and _panel.ammo_color == HudStyle.WARNING)
	for i in _player.weapon.data_set.size():
		var data: WeaponData = _player.weapon.data_set[i]
		_player.weapon.select(i)
		_panel.advance(0.0)
		_check("%s highlights its gun slot" % data.display_name, _panel.selected_index == i)
		_check("%s shows its gun icon" % data.display_name, _panel.current_icon == data.icon)
		_check("%s shows its gun name" % data.display_name, _panel.gun_name == data.display_name)

	_player.weapon.select(0)
	_player.weapon.ammo = 7
	_player.weapon.reserve = 120
	_player.weapon.try_reload()
	_panel.advance(0.0)
	_check("reloading shows a progress bar instead of text", _panel.reload_visible)
	var before := _panel.reload_fraction
	_player.weapon._process(0.5)
	_panel.advance(0.0)
	_check("the reload bar advances", _panel.reload_fraction > before and _panel.reload_fraction < 1.0)
	_player.weapon._process(10.0)
	_panel.advance(0.0)
	_check("the reload bar goes away when the magazine is full", not _panel.reload_visible
		and _player.weapon.ammo == _player.weapon.magazine_capacity())
	_player.weapon.ammo = 7
	_player.weapon.try_reload()
	_player.weapon._process(0.5)
	_panel.advance(0.0)
	_check("another reload is in progress before switching", _panel.reload_visible
		and _panel.reload_fraction > 0.0 and _panel.reload_fraction < 1.0)
	_player.weapon.select(1)
	_panel.advance(0.0)
	_check("switching guns cancels and hides the reload bar", not _player.weapon.is_reloading()
		and not _panel.reload_visible and is_zero_approx(_panel.reload_fraction))
	_player.weapon.select(0)
	_panel.advance(0.0)
	_check("switching back does not resume or finish the cancelled reload", not _panel.reload_visible
		and _player.weapon.ammo == 7)

	print("== shield slot")
	_shield_slot.advance(0.0)
	_check("G starts locked without a skill buff", _shield_slot.locked and not _shield_slot.slot_ready)
	_player.stats.base[Stats.SKILL_UNLOCKED] = 1.0
	_shield_slot.advance(0.0)
	_check("unlocked G is bright and ready", not _shield_slot.locked and _shield_slot.slot_ready)
	_check("G activates", _player.shield.try_activate())
	_shield_slot.advance(0.0)
	_vitals.advance(0.0)
	_check("active G glows", _shield_slot.active and not _shield_slot.slot_ready)
	_check("the shield strip appears above health", _vitals.shield_visible
		and _vitals.shield_fraction > 0.9)
	var active_duration := _player.shield.active_remaining
	var cooldown_duration := _player.shield.cooldown_duration()
	_player.shield._process(active_duration * 0.5)
	_shield_slot.advance(0.0)
	_vitals.advance(0.0)
	_check("the shield strip is half full halfway through", _vitals.shield_visible
		and is_equal_approx(_vitals.shield_fraction, 0.5) and _shield_slot.active)
	_player.shield._process(active_duration * 0.5)
	_shield_slot.advance(0.0)
	_vitals.advance(0.0)
	_check("cooling G shows a radial countdown", _shield_slot.cooling
		and not _shield_slot.active and not _shield_slot.slot_ready
		and is_equal_approx(_shield_slot.cooldown_fraction, 1.0)
		and is_equal_approx(_shield_slot.cooldown_seconds, cooldown_duration))
	_check("the shield strip hides when inactive", not _vitals.shield_visible
		and is_zero_approx(_vitals.shield_fraction))
	var cooldown_fraction := _shield_slot.cooldown_fraction
	var cooldown_seconds := _shield_slot.cooldown_seconds
	_player.shield._process(cooldown_duration * 0.5)
	_shield_slot.advance(0.0)
	_check("the cooldown fraction halves as time advances", _shield_slot.cooling
		and not _shield_slot.slot_ready and _shield_slot.cooldown_fraction < cooldown_fraction
		and is_equal_approx(_shield_slot.cooldown_fraction, 0.5))
	_check("the cooldown seconds decrease to half", _shield_slot.cooldown_seconds < cooldown_seconds
		and is_equal_approx(_shield_slot.cooldown_seconds, cooldown_duration * 0.5))
	_player.shield._process(cooldown_duration * 0.5)
	_shield_slot.advance(0.0)
	_check("G is ready when cooldown finishes", _shield_slot.slot_ready
		and not _shield_slot.cooling and not _shield_slot.active and not _shield_slot.locked)
	_check("the finished cooldown clears both countdown values", is_zero_approx(_shield_slot.cooldown_fraction)
		and is_zero_approx(_shield_slot.cooldown_seconds))

	print("== melee slot and corner badge")
	for i in MeleePool.ALL.size():
		var data: MeleeData = MeleePool.ALL[i]
		_player.melee.select(i)
		_melee_slot.advance(0.0)
		_check("%s is the selected blade" % data.display_name, _player.melee.index == i
			and _player.melee.current() == data)
		_check("%s shows its melee icon" % data.display_name, _melee_slot.current_icon == data.icon)
	_check("locked parry has no stored-round dots", not _melee_slot.stored_visible
		and _melee_slot.stored_capacity == 0 and not _melee_slot.parry_flash)
	_player.stats.base[Stats.PARRY_CAPACITY] = 2.0
	_player.combat_traits.parry_remaining = 0.2
	_player.combat_traits.stored_rounds = 1
	_melee_slot.advance(0.0)
	_check("the parry window flashes the V border", _melee_slot.parry_flash)
	_check("stored rounds show as dots", _melee_slot.stored_visible
		and _melee_slot.stored_capacity == 2 and _melee_slot.stored_rounds == 1)
	_player.combat_traits._process(0.2)
	_melee_slot.advance(0.0)
	_check("the V border stops flashing when the window expires", not _melee_slot.parry_flash
		and is_zero_approx(_player.combat_traits.parry_remaining))
	_check("stored rounds remain visible after the window expires", _melee_slot.stored_visible
		and _melee_slot.stored_capacity == 2 and _melee_slot.stored_rounds == 1)
	_player.stats.base[Stats.PARRY_CAPACITY] = 0.0
	_melee_slot.advance(0.0)
	_check("removing parry capacity hides the dots", not _melee_slot.stored_visible
		and _melee_slot.stored_capacity == 0)
	_shield_slot.advance(0.0)
	_check("the dangerous-magazine badge starts hidden", not _shield_slot.danger_badge)
	_player.stats.base[Stats.RELOAD_BLAST_DAMAGE] = 30.0
	_shield_slot.advance(0.0)
	_check("the dangerous magazine is a corner badge", _shield_slot.danger_badge)
	_player.stats.base[Stats.RELOAD_BLAST_DAMAGE] = 0.0
	_shield_slot.advance(0.0)
	_check("removing dangerous magazine hides its badge", not _shield_slot.danger_badge)

	print("== every weapon has an icon")
	for data: WeaponData in [load("res://weapons/rifle.tres"), load("res://weapons/shotgun.tres"),
			load("res://weapons/sniper.tres")]:
		_check("%s has an icon" % data.display_name, data.icon != null
			and data.icon.get_size().x > 0.0)
	for data: MeleeData in MeleePool.ALL:
		_check("%s has an icon" % data.display_name, data.icon != null
			and data.icon.get_size().x > 0.0)
	_check("the shield slot has an icon", _shield_slot.icon != null
		and _shield_slot.icon.get_size().x > 0.0 and _shield_slot.current_icon == _shield_slot.icon)

	print("== layout")
	var viewport_rect := _hud.get_viewport().get_visible_rect()
	var vitals_rect := _vitals.get_global_rect()
	var panel_rect := _panel.get_global_rect()
	var ability_rect := (_hud.get_node("AbilityBar") as Control).get_global_rect()
	_check("the vitals panel stays on screen", viewport_rect.encloses(vitals_rect))
	_check("the weapon panel stays on screen", viewport_rect.encloses(panel_rect))
	_check("the ability row stays on screen", viewport_rect.encloses(ability_rect))
	_check("the vitals and weapon panels do not overlap", not vitals_rect.intersects(panel_rect))
	_check("the weapon panel and ability row do not overlap", not panel_rect.intersects(ability_rect))

	scene.queue_free()
	await get_tree().process_frame
	# Keep the original 67 checks above independent of the objective fixtures.
	await _test_world_markers()
	await _test_boss_hud()
	# Audio shutdown needs a mix cycle to consume queued stop commands.
	await get_tree().create_timer(0.15).timeout
	# A helper that aborts early must not let the parent coroutine report success.
	_finished = _checks == EXPECTED_CHECKS


func _test_world_markers() -> void:
	print("== small-zone objectives and world markers")
	var scene := await _load_frozen_zone(1)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	var point := director.capture_point
	var hud := scene.get_node("HUD") as CanvasLayer
	var top := hud.get_node("Top") as ObjectivePanel
	var objective := top.get_node("Objective") as Label
	var detail := top.get_node("Detail") as Label
	var capture := hud.get_node("WorldMarkers/Capture") as WorldMarker
	var pedestal_marker := hud.get_node("WorldMarkers/Pedestal") as WorldMarker
	var boss_marker := hud.get_node("WorldMarkers/Boss") as WorldMarker
	var boss_health := hud.get_node("BossHealth") as BossHealth
	var camera := player.get_node("Head/Camera3D") as Camera3D
	capture.refresh()
	pedestal_marker.refresh()
	boss_marker.refresh()
	_check("HUD creates exactly three typed world markers", hud.get_node("WorldMarkers").get_child_count() == 3
		and capture.kind == WorldMarker.Kind.CAPTURE and pedestal_marker.kind == WorldMarker.Kind.PEDESTAL
		and boss_marker.kind == WorldMarker.Kind.BOSS)
	_check("the short clear objective shows the live guard count", director.phase == ZoneDirector.Phase.CLEAR_GUARDS
		and top.phase == director.phase and objective.visible and objective.text == "清除守卫"
		and top.enemies_alive == director.enemies_total and top.enemies_alive > 1)
	_check("the long director objective rides below as a small subtitle", detail.visible
		and detail.text == director.objective and detail.text == "消灭所有敌人")
	_check("the locked capture marker is visible and grey", capture.visible and capture.target == point
		and point.locked and capture.marker_color == CapturePoint.COLOR_LOCKED)
	_check("clear guards uses a half-opacity weak hint", is_equal_approx(capture.opacity, 0.5))
	_check("the locked capture has no progress ring", not capture.progress_visible
		and is_zero_approx(capture.progress_fraction))
	_check("the pedestal marker waits for a real pedestal", director.buff_pedestal == null
		and pedestal_marker.target == null and not pedestal_marker.visible and not pedestal_marker.highlighted)
	_check("a small zone hides the boss marker", director.boss == null and boss_marker.target == null
		and not boss_marker.visible)
	_check("a small zone hides boss health", not boss_health.visible)
	_check_objective_layout(hud, "small zone")
	_test_marker_projection(capture, point, camera)

	print("== real guard deaths open the capture point")
	var guards: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if scene.is_ancestor_of(node):
			guards.append(node as Enemy)
	guards[0].health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	capture.refresh()
	_check("one guard death decrements the visible count", top.enemies_alive == director.enemies_total - 1)
	_check("remaining guards keep the point grey and weak", point.locked and capture.visible
		and director.phase == ZoneDirector.Phase.CLEAR_GUARDS and objective.text == "清除守卫"
		and capture.marker_color == CapturePoint.COLOR_LOCKED and is_equal_approx(capture.opacity, 0.5))
	for i in range(1, guards.size()):
		guards[i].health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	# Opening the point really spawns a reinforcement wave; freeze those new nodes too.
	_freeze_scene(scene)
	capture.refresh()
	_check("all guard deaths open the point through the director", not point.locked
		and director.phase == ZoneDirector.Phase.HAMMER_POINT and top.phase == director.phase)
	_check("the hammer objective has no stale guard count", objective.text == "锤击据点" and top.enemies_alive == 0
		and detail.text == director.objective and detail.text == "前往据点，按 E 挥锤砸点")
	_check("the open capture marker is blue and fully opaque", capture.visible
		and capture.marker_color == CapturePoint.COLOR_OPEN and is_equal_approx(capture.opacity, 1.0))
	_check("hammering starts with an empty progress ring", capture.progress_visible
		and is_zero_approx(capture.progress_fraction))
	point.add_capture_progress(0.25)
	capture.refresh()
	_check("the outer ring follows actual capture progress", capture.progress_visible
		and is_equal_approx(point.progress, 0.25) and is_equal_approx(capture.progress_fraction, point.progress))
	point.add_capture_progress(0.75)
	capture.refresh()
	pedestal_marker.refresh()
	_check("capture really plants the flag and changes phase", point.is_captured()
		and point.get_node_or_null("Flag") != null and director.phase == ZoneDirector.Phase.FLAG_PLANTED)
	_check("the short planted-flag objective directs the player to F", top.phase == director.phase
		and objective.text == "到增益台按 F")
	_check("the captured marker is green but hidden without a ring", capture.marker_color == CapturePoint.COLOR_CAPTURED
		and not capture.visible and not capture.progress_visible)
	var pedestal := director.buff_pedestal
	_check("refresh discovers the late-created pedestal without setup", is_instance_valid(pedestal)
		and pedestal_marker.target == pedestal and pedestal_marker.visible
		and pedestal_marker.marker_color == CapturePoint.COLOR_CAPTURED)
	_check("the pedestal is spawned next to the captured point",
		pedestal.global_position.is_equal_approx(point.global_position + ZoneDirector.PEDESTAL_OFFSET))

	print("== F range, highlight and inclusive boundary")
	player.global_position = pedestal.global_position + Vector3.RIGHT * (BuffPedestal.INTERACT_RANGE + 0.01)
	pedestal_marker.refresh()
	_check("just outside F range leaves the marker unhighlighted", not pedestal.in_range(player)
		and pedestal_marker.visible and not pedestal_marker.highlighted)
	_check("pedestal distance is camera-to-target in rounded metres",
		pedestal_marker.distance_meters == roundi(camera.global_position.distance_to(pedestal.global_position))
		and pedestal_marker.distance_text == "%d米" % pedestal_marker.distance_meters)
	_press_interact(director)
	_check("F just outside range cannot open a reward", director.selection == null
		and director.selection_context.is_empty() and director.phase == ZoneDirector.Phase.FLAG_PLANTED
		and not get_tree().paused)
	player.global_position = pedestal.global_position + Vector3.RIGHT * (BuffPedestal.INTERACT_RANGE - 0.01)
	pedestal_marker.refresh()
	_check("just inside F range highlights the marker", pedestal.in_range(player) and pedestal_marker.highlighted)
	# Range is three-dimensional and measured from the player, not the camera.
	player.global_position = pedestal.global_position + Vector3.UP * (BuffPedestal.INTERACT_RANGE + 0.01)
	pedestal_marker.refresh()
	_check("vertical separation outside F range removes the highlight", not pedestal.in_range(player)
		and not pedestal_marker.highlighted)
	# A float32 Vector3 cannot land exactly on 2.4 m: +2.4 stores as 2.4000001 m,
	# a hair outside the range. Sit one centimetre inside the boundary instead.
	player.global_position = pedestal.global_position + Vector3.RIGHT * (BuffPedestal.INTERACT_RANGE - 0.01)
	pedestal_marker.refresh()
	_check("just inside the inclusive F boundary stays in range", pedestal.in_range(player)
		and player.global_position.distance_to(pedestal.global_position) < BuffPedestal.INTERACT_RANGE
		and pedestal_marker.highlighted)
	_press_interact(director)
	_check("F just inside the boundary opens the real clear offer", is_instance_valid(director.selection)
		and director.selection_context == "clear" and get_tree().paused)
	_check("opening the reward updates the short objective", director.phase == ZoneDirector.Phase.BUFF_SELECT
		and top.phase == director.phase and objective.text == "选择增益")
	# Do not choose a reward: that would load another gameplay scene over the test.
	get_tree().paused = false
	scene.queue_free()
	await get_tree().process_frame


func _test_marker_projection(marker: WorldMarker, point: CapturePoint, camera: Camera3D) -> void:
	print("== world-marker projection, safe edges and camera plane")
	var saved_point := point.global_position
	var saved_camera := camera.global_transform
	camera.global_transform = Transform3D.IDENTITY
	camera.make_current()
	var view := marker.get_viewport_rect()
	var center := view.get_center()
	var safe := view.grow_individual(-88.0, -100.0, -88.0, -100.0)
	_check("world markers reserve the specified screen inset", WorldMarker.SAFE_INSET == Vector2(88.0, 100.0))
	_place_capture(point, camera, Vector3(0.0, 3.5, -12.4))
	marker.refresh()
	_check("distance rounds down from the target base, not its raised icon", marker.distance_meters == 12
		and marker.distance_text == "12米")
	_place_capture(point, camera, Vector3(0.0, 3.5, -12.6))
	marker.refresh()
	_check("distance refresh rounds up when the target moves", marker.distance_meters == 13
		and marker.distance_text == "13米")
	_place_capture(point, camera, Vector3(0.0, 0.0, -20.0))
	marker.refresh()
	_check_marker_pose("front center", marker, center, Vector2.DOWN, false, false)

	var sides := [
		{"name": "left", "axis": Vector2.LEFT, "edge": Vector2(safe.position.x, center.y)},
		{"name": "right", "axis": Vector2.RIGHT, "edge": Vector2(safe.end.x, center.y)},
		{"name": "top", "axis": Vector2.UP, "edge": Vector2(center.x, safe.position.y)},
		{"name": "bottom", "axis": Vector2.DOWN, "edge": Vector2(center.x, safe.end.y)},
	]
	for side: Dictionary in sides:
		var axis: Vector2 = side.axis
		var edge: Vector2 = side.edge
		# Behind-camera targets must retain left/right/up/down, not mirror the projection.
		for depth: float in [-10.0, 20.0, 0.0]:
			var label := "%s at camera z=%.4f" % [side.name, depth]
			_place_capture(point, camera, Vector3(axis.x * 100.0, -axis.y * 100.0, depth))
			marker.refresh()
			_check_marker_pose(label, marker, edge, axis, true, depth >= 0.0)
		# Project known screen coordinates back to 3D to probe both sides of each inset.
		for outside: bool in [false, true]:
			var screen: Vector2 = edge + axis * (0.5 if outside else -0.5)
			point.global_position = camera.project_position(screen, 20.0) - Vector3.UP * 3.5
			marker.refresh()
			_check_marker_pose("%s just %s safe boundary" % [side.name, "outside" if outside else "inside"],
				marker, edge if outside else screen, axis, outside, false)

	for depth: float in [20.0, 0.0]:
		_place_capture(point, camera, Vector3(0.0, 0.0, depth))
		marker.refresh()
		_check_marker_pose("center fallback at camera z=%.4f" % depth, marker,
			Vector2(center.x, safe.end.y), Vector2.DOWN, true, true)
	# Both signs close to the camera plane use the finite lateral direction.
	for depth: float in [-0.0005, 0.0005]:
		_place_capture(point, camera, Vector3(100.0, 0.0, depth))
		marker.refresh()
		_check_marker_pose("near camera plane z=%.4f" % depth, marker,
			Vector2(safe.end.x, center.y), Vector2.RIGHT, true, true)
	# Both projected axes overflow, but the ray hits the top before the right edge.
	# Independently clamping x/y would incorrectly put this marker in the corner.
	var diagonal_screen := center + Vector2(safe.size.x, -safe.size.y * 2.0)
	point.global_position = camera.project_position(diagonal_screen, 20.0) - Vector3.UP * 3.5
	marker.refresh()
	_check_marker_pose("diagonal clips along its ray", marker,
		Vector2(center.x + safe.size.x * 0.25, safe.position.y),
		(diagonal_screen - center).normalized(), true, false)
	point.global_position = saved_point
	camera.global_transform = saved_camera
	marker.refresh()


func _place_capture(point: CapturePoint, camera: Camera3D, local_icon_position: Vector3) -> void:
	# Capture markers are projected 3.5 m above the actual target, which supplies distance.
	point.global_position = camera.to_global(local_icon_position) - Vector3.UP * 3.5


func _check_marker_pose(label: String, marker: WorldMarker, position: Vector2,
		direction: Vector2, offscreen: bool, behind: bool) -> void:
	_check("%s: visibility and projection flags" % label, marker.visible
		and marker.offscreen == offscreen and marker.behind == behind)
	_check("%s: finite position on the expected safe ray" % label, marker.screen_position.is_finite()
		and marker.screen_position.distance_to(position) < 0.1)
	_check("%s: the arrow points toward the target" % label, marker.direction.is_finite()
		and is_equal_approx(marker.direction.length(), 1.0) and marker.direction.dot(direction) > 0.9999)
	var rect := marker.marker_rect()
	var full_bounds := Rect2(marker.screen_position - Vector2(62.0, 78.0), Vector2(124.0, 156.0))
	_check("%s: the entire border, arrow and distance box stay on screen" % label,
		rect.encloses(full_bounds) and marker.get_viewport_rect().encloses(rect))


func _test_boss_hud() -> void:
	print("== boss health and shared white trail")
	var scene := await _load_frozen_zone(2)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	var boss := director.boss
	var point := director.capture_point
	var hud := scene.get_node("HUD") as CanvasLayer
	var top := hud.get_node("Top") as ObjectivePanel
	var objective := top.get_node("Objective") as Label
	var detail := top.get_node("Detail") as Label
	var bar := hud.get_node("BossHealth") as BossHealth
	var vitals := hud.get_node("Vitals") as Vitals
	var marker := hud.get_node("WorldMarkers/Boss") as WorldMarker
	var capture := hud.get_node("WorldMarkers/Capture") as WorldMarker
	var pedestal_marker := hud.get_node("WorldMarkers/Pedestal") as WorldMarker
	var camera := player.get_node("Head/Camera3D") as Camera3D
	marker.refresh()
	capture.refresh()
	pedestal_marker.refresh()
	_check("the boss objective uses the short text and live count", director.phase == ZoneDirector.Phase.BOSS_STANDING
		and top.phase == director.phase and objective.text == "击倒 Boss" and top.enemies_alive == 7)
	_check("the boss subtitle keeps the long director objective", detail.visible
		and detail.text == director.objective and detail.text == "打倒 Boss")
	_check("boss health starts visible at exactly 900 / 900", bar.visible and not bar.fallen
		and bar.displayed_health == 900.0 and bar.delayed_health == 900.0 and bar.max_health == 900.0
		and bar.health_text == "900 / 900" and bar.fill_color == HudStyle.WARNING)
	_check("the living boss has a red world marker", marker.visible and marker.target == boss
		and marker.marker_color == HudStyle.WARNING and not marker.progress_visible)
	_check("boss distance is camera-to-boss in rounded metres",
		marker.distance_meters == roundi(camera.global_position.distance_to(boss.global_position))
		and marker.distance_text == "%d米" % marker.distance_meters)
	_check("the boss core starts grey without a hammer ring", point.locked and capture.visible
		and capture.marker_color == CapturePoint.COLOR_LOCKED and not capture.progress_visible)
	_check("the boss zone starts without a pedestal marker", director.buff_pedestal == null
		and not pedestal_marker.visible)
	_check_objective_layout(hud, "boss zone")

	boss.health.apply_damage(42.0, Hitbox.BodyPart.BODY)
	_check("damage immediately updates boss health to 858 / 900", boss.health.health == 858.0
		and bar.displayed_health == 858.0 and bar.health_text == "858 / 900" and bar.max_health == 900.0)
	_check("damage immediately leaves the boss white trail at 900", bar.delayed_health == 900.0)
	# Drive Vitals with the same loss and deltas to guard the shared HealthTrail contract.
	player.health.apply_damage(42.0, Hitbox.BodyPart.BODY)
	vitals.advance(0.0)
	bar.advance(0.3)
	vitals.advance(0.3)
	_check("boss and player trails both hold through 0.3 seconds", is_equal_approx(bar.delayed_health, 900.0)
		and is_equal_approx(vitals.delayed_health, 100.0))
	bar.advance(0.1)
	vitals.advance(0.1)
	_check("the full 0.4-second delay is held", is_equal_approx(bar.delayed_health, 900.0)
		and is_equal_approx(vitals.delayed_health, 100.0))
	bar.advance(0.1)
	vitals.advance(0.1)
	_check("both trails drain 12 HP in the next 0.1 seconds", is_equal_approx(bar.delayed_health, 888.0)
		and is_equal_approx(vitals.delayed_health, 88.0))
	_check("trail animation never changes the real boss health or numbers", bar.displayed_health == 858.0
		and boss.health.health == 858.0 and bar.health_text == "858 / 900")
	bar.advance(1.0)
	vitals.advance(1.0)
	_check("both trails settle without undershooting", is_equal_approx(bar.delayed_health, 858.0)
		and is_equal_approx(vitals.delayed_health, 58.0))
	var small: Enemy
	for node in get_tree().get_nodes_in_group("enemy"):
		if scene.is_ancestor_of(node) and node != boss:
			small = node as Enemy
			break
	small.health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	_check("small-enemy death updates the counter but not boss health", top.enemies_alive == 6
		and bar.displayed_health == 858.0 and bar.delayed_health == 858.0)

	print("== fallen boss, open core and planted flag")
	boss.health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	marker.refresh()
	capture.refresh()
	_check("boss death immediately empties and greys the persistent bar", bar.visible and bar.fallen
		and bar.displayed_health == 0.0 and bar.health_text == "已倒下"
		and bar.fill_color == CapturePoint.COLOR_LOCKED)
	_check("boss death hides its world marker", not marker.visible)
	_check("the killing hit starts a fresh held trail", is_equal_approx(bar.delayed_health, 858.0))
	bar.advance(0.3)
	_check("the fallen trail still holds during the death delay", is_equal_approx(bar.delayed_health, 858.0)
		and bar.fill_color == CapturePoint.COLOR_LOCKED)
	bar.advance(10.0)
	_check("the fallen trail eventually drains to zero and stays grey", is_zero_approx(bar.delayed_health)
		and bar.health_text == "已倒下" and bar.fill_color == CapturePoint.COLOR_LOCKED)
	_check("boss death opens the actual core and switches the short objective", not point.locked
		and director.phase == ZoneDirector.Phase.HAMMER_POINT and top.phase == director.phase
		and objective.text == "锤击据点" and top.enemies_alive == 5
		and detail.text == "砸碎城市核心，按 E")
	_check("the unlocked boss core shows the blue progress ring", capture.visible
		and capture.marker_color == CapturePoint.COLOR_OPEN and capture.progress_visible
		and is_zero_approx(capture.progress_fraction))
	point.add_capture_progress(1.0)
	capture.refresh()
	pedestal_marker.refresh()
	_check("capturing the boss core shows the short victory objective", point.is_captured()
		and director.phase == ZoneDirector.Phase.FLAG_PLANTED and top.phase == director.phase
		and objective.text == "城市核心已夺取")
	_check("the captured boss core hides its green marker and ring", not capture.visible
		and capture.marker_color == CapturePoint.COLOR_CAPTURED and not capture.progress_visible)
	_check("capturing a boss core never produces a pedestal marker", director.buff_pedestal == null
		and pedestal_marker.target == null and not pedestal_marker.visible)
	# Dispose before the real flag timer could open the victory UI.
	scene.queue_free()
	await get_tree().process_frame


func _check_objective_layout(hud: CanvasLayer, label: String) -> void:
	var top := hud.get_node("Top") as ObjectivePanel
	var top_rect := top.get_global_rect()
	var buffs_rect := (hud.get_node("Buffs") as Control).get_global_rect()
	var boss_rect := (hud.get_node("BossHealth") as BossHealth).get_global_rect()
	var view := hud.get_viewport().get_visible_rect()
	_check("%s: the objective panel occupies its new rectangle" % label, top.visible
		and top_rect == Rect2(32.0, 326.0, 380.0, 176.0))
	_check("%s: the existing Buffs rectangle is unchanged" % label,
		buffs_rect == Rect2(32.0, 24.0, 588.0, 286.0))
	_check("%s: the objective panel stays on screen" % label, view.encloses(top_rect))
	_check("%s: boss health stays on screen" % label, view.encloses(boss_rect))
	_check("%s: Top never overlaps Buffs" % label, not top_rect.intersects(buffs_rect))
	_check("%s: Top never overlaps BossHealth" % label, not top_rect.intersects(boss_rect))
	_check("%s: no legacy capture or boss bars remain" % label, not hud.has_node("Top/Capture")
		and not hud.has_node("Top/BossBar") and not hud.has_node("Top/BossLabel"))


func _load_frozen_zone(index: int) -> Node:
	# A fresh later zone starts real combat without choosing a buff or touching phases.
	RunState.clear_fixture()
	RunState.start_new_run()
	for _i in index:
		RunState.advance_zone()
	var scene: Node = load(RunState.zone_scene()).instantiate()
	add_child(scene)
	_freeze_scene(scene)
	# Let layout/deferred calls settle while AI, movement and HUD callbacks stay disabled.
	await get_tree().process_frame
	return scene


func _freeze_scene(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_freeze_scene(child)


func _press_interact(director: ZoneDirector) -> void:
	Input.action_press(&"interact")
	director._physics_process(0.0)
	Input.action_release(&"interact")


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
