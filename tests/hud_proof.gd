extends Node

const ZONE := "res://maps/zone_1.tscn"

var _out_dir := "res://docs/proof/hud"
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("HUD proof requires a native display")
		get_tree().quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		push_error("Cannot create HUD proof output directory")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	RunState.start_fixture(RunFixture.by_id("FX-001"))
	var scene: Node = load(ZONE).instantiate()
	add_child(scene)
	var player := scene.get_node("Player") as Player
	var hud := scene.get_node("HUD") as CanvasLayer
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var vitals := hud.get_node("Vitals") as Vitals
	var panel := hud.get_node("WeaponPanel") as WeaponPanel
	var shield_slot := hud.get_node("AbilityBar/Shield") as AbilitySlot
	var melee_slot := hud.get_node("AbilityBar/Melee") as AbilitySlot
	player.set_process(false)
	player.set_physics_process(false)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_process(false)
		enemy.set_physics_process(false)
	await _frames(3)
	var choose := InputEventKey.new()
	choose.physical_keycode = KEY_1
	choose.pressed = true
	Input.parse_input_event(choose)
	await _frames(2)
	choose.pressed = false
	Input.parse_input_event(choose)
	await _frames(2)
	_check("entry choice closes the modal", not is_instance_valid(director.selection)
		and not get_tree().paused)
	player.stats.clear_buffs()
	RunState.start_fixture(RunFixture.by_id("FX-001"))

	# Freeze staged states so capture latency cannot consume a short visual window.
	for actor: Node in [player.weapon, player.melee, player.shield, player.combat_traits]:
		actor.set_process(false)
	for slot: Control in [vitals, panel, shield_slot, melee_slot]:
		slot.set_process(false)
	player.stats.base[Stats.SKILL_UNLOCKED] = 1.0
	player.health.health = player.health.max_health
	player.weapon.select(0)
	player.weapon.ammo = player.weapon.magazine_capacity()
	player.weapon.reserve = 240
	_refresh(vitals, panel, shield_slot, melee_slot)
	await _shot("01_full_health")
	await _report_layout("1920x1080", hud, vitals, panel, shield_slot)

	player.health.health = 22.0
	_refresh(vitals, panel, shield_slot, melee_slot)
	await _shot("02_low_health")
	vitals.advance(1.2)
	await _shot("07_damage_settled")

	player.health.health = player.health.max_health
	player.weapon.ammo = 4
	player.weapon.try_reload()
	player.weapon._process(0.5)
	_refresh(vitals, panel, shield_slot, melee_slot)
	await _shot("03_reloading")
	player.weapon.select(0)
	player.weapon.ammo = player.weapon.magazine_capacity()
	player.weapon.reserve = 240
	player.shield.try_activate()
	player.shield._process(0.5)
	_refresh(vitals, panel, shield_slot, melee_slot)
	await _shot("04_shield_active")

	player.shield._process(4.5)
	_refresh(vitals, panel, shield_slot, melee_slot)
	await _shot("05_shield_cooldown")
	player.shield.cancel()
	player.stats.base[Stats.SKILL_UNLOCKED] = 0.0
	_refresh(vitals, panel, shield_slot, melee_slot)
	await _shot("08_shield_locked")

	player.stats.base[Stats.PARRY_CAPACITY] = 2.0
	player.combat_traits.parry_remaining = 0.2
	player.combat_traits.stored_rounds = 1
	_refresh(vitals, panel, shield_slot, melee_slot)
	await _shot("09_parry_rounds")
	player.combat_traits.clear()
	player.stats.base[Stats.PARRY_CAPACITY] = 0.0
	player.stats.base[Stats.RELOAD_BLAST_DAMAGE] = 30.0
	_refresh(vitals, panel, shield_slot, melee_slot)
	await _shot("10_danger_badge")
	player.stats.base[Stats.RELOAD_BLAST_DAMAGE] = 0.0

	for actor: Node in [player.weapon, player.melee, player.shield, player.combat_traits]:
		actor.set_process(true)
	for slot: Control in [vitals, panel, shield_slot, melee_slot]:
		slot.set_process(true)
	await _tap("weapon_next")
	await _tap("switch_melee")
	_check("wheel selects shotgun and Q selects axe", panel.selected_index == 1
		and melee_slot.current_icon == player.melee.current().icon and player.melee.index == 1)
	await _shot("11_shotgun_axe")
	await _tap("weapon_next")
	await _tap("switch_melee")
	_check("wheel selects sniper and Q selects tachi", panel.selected_index == 2
		and melee_slot.current_icon == player.melee.current().icon and player.melee.index == 2)
	await _shot("12_sniper_tachi")
	await _tap("weapon_next")
	_check("wheel wraps to rifle", panel.selected_index == 0)

	player.weapon.ammo = 4
	await _tap("reload")
	await get_tree().create_timer(0.4).timeout
	_check("R advances the live reload bar", panel.reload_visible and panel.reload_fraction > 0.0)
	await _shot("13_live_reload")
	await _tap("weapon_next")
	_check("switching during reload removes the progress bar", not panel.reload_visible)
	await _tap("weapon_prev")
	_check("interrupted rifle still has four rounds", player.weapon.ammo == 4)
	await _tap("reload")
	await get_tree().create_timer(3.0).timeout
	_check("live reload completes", not panel.reload_visible
		and player.weapon.ammo == player.weapon.magazine_capacity())

	player.stats.base[Stats.SKILL_UNLOCKED] = 1.0
	await _tap("shield")
	_check("G activates the live shield and strip", shield_slot.active and vitals.shield_visible)
	await get_tree().create_timer(1.1).timeout
	_check("live shield transitions to cooldown", shield_slot.cooling and not vitals.shield_visible)
	await get_tree().create_timer(8.1).timeout
	_check("live shield returns to ready", shield_slot.slot_ready and not shield_slot.cooling)
	player.stats.base[Stats.PARRY_CAPACITY] = 2.0
	await _tap("melee")
	_check("V opens the live parry window", melee_slot.parry_flash)
	await get_tree().create_timer(1.0).timeout
	_check("live parry window closes", not melee_slot.parry_flash)
	player.stats.base[Stats.PARRY_CAPACITY] = 0.0
	player.melee.select(0)

	player.health.apply_damage(78.0, Hitbox.BodyPart.BODY)
	await _frames(2)
	_check("live damage changes health and keeps a white trail", vitals.health_number == 22
		and vitals.delayed_health > vitals.displayed_health)
	await get_tree().create_timer(1.2).timeout
	_check("live white trail settles", is_equal_approx(vitals.delayed_health, 22.0))
	player.health.health = player.health.max_health
	await _frames(2)

	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(5)
	await _shot("06_layout_1280x720")
	await _report_layout("1280x720", hud, vitals, panel, shield_slot)
	player.weapon.ammo = 4
	await _tap("reload")
	await get_tree().create_timer(0.4).timeout
	await _shot("14_reload_1280x720")
	await _tap("weapon_next")
	await _tap("switch_melee")
	await _shot("15_switch_1280x720")
	await _world_proof(scene, player, hud, director)
	print("HUD PROOF %s" % ("PASSED" if _failures == 0 else "FAILED"))
	get_tree().quit(0 if _failures == 0 else 1)


func _world_proof(scene: Node, player: Player, hud: CanvasLayer, director: ZoneDirector) -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _frames(5)
	var point := director.capture_point
	var marker := hud.get_node("WorldMarkers/Capture") as WorldMarker
	var pedestal_marker := hud.get_node("WorldMarkers/Pedestal") as WorldMarker
	_check("guard phase keeps a weak grey capture marker", marker.visible
		and marker.marker_color == CapturePoint.COLOR_LOCKED and marker.opacity < 1.0)
	await _shot("16_clear_guards_1920x1080")
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	director.set_physics_process(false)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_process(false)
		enemy.set_physics_process(false)
	player.global_position = point.global_position + Vector3(0.0, 0.0, 3.0)
	player.aim_at(point.global_position + Vector3.UP * 2.0)
	for i in 6:
		await get_tree().physics_frame
	_check("walking to the open building enables hammer reach", point.player_in_reach and not point.locked)
	for i in 4:
		await _tap("hammer")
		await get_tree().create_timer(1.0).timeout
	_check("E swings advance the on-target progress ring", point.progress > 0.0
		and point.progress < 1.0 and marker.progress_visible
		and is_equal_approx(marker.progress_fraction, point.progress))
	await _shot("17_hammer_ring_1920x1080")
	player.aim_at(player.global_position + Vector3(10.0, 1.5, 12.0))
	await _frames(3)
	_check("turning away clamps the marker and arrow to the edge", marker.behind
		and marker.offscreen and marker.get_viewport_rect().encloses(marker.marker_rect()))
	await _shot("18_behind_edge_1920x1080")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(5)
	_check("edge marker remains enclosed at 720p", marker.get_viewport_rect().encloses(marker.marker_rect()))
	await _shot("19_behind_edge_1280x720")
	player.aim_at(point.global_position + Vector3.UP * 2.0)
	var swings := 0
	while not point.is_captured() and swings < 20:
		await _tap("hammer")
		await get_tree().create_timer(1.0).timeout
		swings += 1
	await _frames(3)
	_check("flag hides the capture marker and reveals the pedestal", point.is_captured()
		and not marker.visible and pedestal_marker.visible and is_instance_valid(director.buff_pedestal))
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(director.buff_pedestal):
		player.global_position = director.buff_pedestal.global_position + Vector3(0.0, 0.0, 2.1)
		player.aim_at(director.buff_pedestal.global_position + Vector3.UP * 1.3)
		await _frames(3)
		_check("nearby F marker highlights within interaction range", pedestal_marker.highlighted)
		await _shot("20_pedestal_F_1280x720")
		director.set_physics_process(true)
		await _tap("interact")
		_check("F opens the real reward choice", is_instance_valid(director.selection)
			and director.selection_context == "clear")
	get_tree().paused = false
	scene.queue_free()
	await _frames(2)
	RunState.start_fixture(RunFixture.by_id("FX-002"))
	var boss_scene: Node = load("res://maps/boss.tscn").instantiate()
	add_child(boss_scene)
	var boss := boss_scene.get_node("Boss") as Enemy
	var boss_player := boss_scene.get_node("Player") as Player
	var boss_hud := boss_scene.get_node("HUD") as CanvasLayer
	var boss_health := boss_hud.get_node("BossHealth") as BossHealth
	var boss_marker := boss_hud.get_node("WorldMarkers/Boss") as WorldMarker
	boss_player.set_process(false)
	boss_player.set_physics_process(false)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_process(false)
		enemy.set_physics_process(false)
	boss_player.global_position = boss.global_position + Vector3(0.0, 0.0, 14.0)
	boss_player.aim_at(boss.global_position + Vector3.UP * 2.0)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _frames(5)
	_check("boss starts with red marker and 900 / 900", boss_marker.visible
		and boss_marker.marker_color == HudStyle.WARNING and boss_health.health_text == "900 / 900")
	var core_marker := boss_hud.get_node("WorldMarkers/Capture") as WorldMarker
	_check("aligned boss and core markers do not overlap", not core_marker.marker_rect().intersects(boss_marker.marker_rect()))
	await _shot("21_boss_full_1920x1080")
	boss_health.set_process(false)
	boss.health.apply_damage(42.0, Hitbox.BodyPart.BODY)
	_check("boss damage immediately leaves a white trail", boss_health.health_text == "858 / 900"
		and boss_health.delayed_health == 900.0)
	await _shot("22_boss_trail_1920x1080")
	boss_health.set_process(true)
	await get_tree().create_timer(1.2).timeout
	_check("boss white trail naturally settles", is_equal_approx(boss_health.delayed_health, 858.0))
	boss.health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(5)
	_check("dead boss turns grey and loses its target marker", boss_health.fallen
		and boss_health.health_text == "已倒下" and not boss_marker.visible
		and boss_health.fill_color == CapturePoint.COLOR_LOCKED)
	await _shot("23_boss_fallen_1280x720")
	boss_scene.queue_free()
	await _frames(2)
	await get_tree().create_timer(0.15).timeout


func _tap(action: String) -> void:
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _refresh(vitals: Vitals, panel: WeaponPanel, shield_slot: AbilitySlot,
		melee_slot: AbilitySlot) -> void:
	vitals.advance(0.0)
	panel.advance(0.0)
	shield_slot.advance(0.0)
	melee_slot.advance(0.0)


func _report_layout(label: String, hud: CanvasLayer, vitals: Control, panel: Control,
		shield_slot: Control) -> void:
	var view := hud.get_viewport().get_visible_rect()
	print("== layout %s (viewport %s)" % [label, view.size])
	var rects := {
		"Vitals": vitals.get_global_rect(),
		"WeaponPanel": panel.get_global_rect(),
		"AbilityBar": (shield_slot.get_parent() as Control).get_global_rect(),
	}
	for key: String in rects:
		var rect: Rect2 = rects[key]
		print("   %-12s %s" % [key, rect])
		_check("%s stays on screen" % key, view.encloses(rect))
	_check("Vitals and WeaponPanel do not overlap",
		not rects["Vitals"].intersects(rects["WeaponPanel"]))
	_check("WeaponPanel and AbilityBar do not overlap",
		not rects["WeaponPanel"].intersects(rects["AbilityBar"]))
	_check("Vitals and AbilityBar do not overlap",
		not rects["Vitals"].intersects(rects["AbilityBar"]))
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.jpg" % [_out_dir, shot_name]
	_check("saved " + shot_name, image.save_jpg(path, 0.85) == OK)
	print("== %s -> %s (%s)" % [shot_name, path, image.get_size()])
