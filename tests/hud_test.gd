extends Node
## Headless check of the graphical HUD: vitals, ammo, abilities, world markers,
## objectives and boss health. Run from the project root:
##   godot --headless --path . res://tests/hud_test.tscn
## Prints one line per check. Exits 1 if a check failed or if the run stopped
## before the last check, so it cannot pass by accident.

# Existing HUD coverage plus eight capacity-shield state/feedback checks.
const EXPECTED_CHECKS := 286

var _checks := 0
var _failures := 0
var _finished := false
var _player: Player
var _hud: CanvasLayer
var _vitals: Vitals
var _panel: WeaponPanel
var _shield_slot: AbilitySlot
var _melee_slot: AbilitySlot
var _magazine_slot: AbilitySlot
var _buff_bar: BuffBar


func _ready() -> void:
	await _run()
	for voice in find_children("*", "AudioStreamPlayer", true, false):
		voice.stop()
		voice.stream = null
	for child in get_children():
		child.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
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
	_magazine_slot = _hud.get_node("AbilityBar/Magazine") as AbilitySlot
	_buff_bar = _hud.get_node("BuffBar") as BuffBar
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
	_magazine_slot.set_process(false)

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

	print("== pistol magazine and crystal reconstruction")
	_player.weapon.ammo = 8
	_panel.advance(0.0)
	_check("ammo numbers show capacity", _panel.ammo_text == "8 / 8" and not _panel.ammo_low)
	_player.weapon.ammo = 2
	_panel.advance(0.0)
	_check("25% or less turns the ammo red", _panel.ammo_low
		and _panel.ammo_color == HudStyle.WARNING)
	_check("the panel shows the single pistol", _panel.gun_name == _player.weapon.data.display_name)
	_check("there is no obsolete rack or selected slot", not ("selected_index" in _panel)
		and not _panel.has_method("slot_rect"))
	_check("ammo and name fit a compact panel", _panel.size.x >= 210.0 and _panel.size.x <= 300.0)
	_player.weapon.ammo = 7
	_player.weapon.try_reload()
	_panel.advance(0.0)
	_check("reload shows a progress bar", _panel.reload_visible)
	var before := _panel.reload_fraction
	_player.weapon._process(0.5)
	_panel.advance(0.0)
	_check("the reload bar advances", _panel.reload_fraction > before and _panel.reload_fraction < 1.0)
	_player.weapon._process(10.0)
	_panel.advance(0.0)
	_check("the bar goes away when reload finishes", not _panel.reload_visible
		and _player.weapon.ammo == _player.weapon.magazine_capacity())
	_player.weapon.try_reload()
	_check("full magazine refuses another reload", not _player.weapon.is_reloading())
	_player.weapon.ammo = 7
	_player.weapon.try_reload()
	_player.weapon._process(0.5)
	_panel.advance(0.0)
	_check("a second reload is in progress", _panel.reload_visible
		and _panel.reload_fraction > 0.0 and _panel.reload_fraction < 1.0)
	var remaining := _player.weapon._reload_left
	_player.weapon.try_reload()
	_check("pressing R again does not restart it", _player.weapon._reload_left == remaining)
	_player.weapon._process(0.35)
	_panel.advance(0.0)
	_check("repeated R completes at 0.85 seconds", not _panel.reload_visible
		and _player.weapon.ammo == _player.weapon.magazine_capacity())

	print("== buff icon bar")
	RunState.start_new_run()
	_check("the buff bar hides when the run has no buffs", RunState.buffs.is_empty()
		and not _buff_bar.visible)
	RunState.add_buff(BuffPool.ALL[0])
	RunState.add_buff(BuffPool.ALL[0])
	_check("one buff kind appears as a single icon", _buff_bar.visible
		and _buff_bar.entries.size() == 1 and _buff_bar.icon_at(0) == BuffPool.ALL[0].icon)
	_check("two picks of one buff show a ×2 badge", _buff_bar.stack_count(&"firearm_damage") == 2
		and _buff_bar.count_label(0) == "×2")
	RunState.add_buff(BuffPool.ALL[3])
	_check("a second school adds a second icon", _buff_bar.entries.size() == 2
		and _buff_bar.icon_at(1) == BuffPool.ALL[3].icon)
	var firearm_accent := SchoolCatalog.find(&"firearm").accent
	var blade_accent := SchoolCatalog.find(&"blade").accent
	_check("borders use the school accents", _buff_bar.accent_for(&"firearm_damage") == firearm_accent
		and _buff_bar.accent_for(&"blade_damage") == blade_accent
		and firearm_accent != blade_accent)
	RunState.start_new_run()
	_check("the bar hides again after the run resets", RunState.buffs.is_empty()
		and not _buff_bar.visible)

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
	_test_counter_shield_ui(scene)

	print("== melee slot")
	var blade_data := _player.melee.current()
	_melee_slot.advance(0.0)
	_check("single mind blade equipped", blade_data.resource_path.ends_with("mind_blade.tres"))
	_check("mind blade icon reaches the ability slot", _melee_slot.current_icon == blade_data.icon)
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
	_test_magazine_slot()

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
	_check("C uses its own dangerous-magazine icon", _magazine_slot.icon == BuffPool.ALL[0].icon
		and _magazine_slot.current_icon == _magazine_slot.icon and _magazine_slot.icon != _shield_slot.icon)

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
	_check("the ability row has independent G, V and C slots", _hud.get_node("AbilityBar").get_child_count() == 3
		and _shield_slot.get_global_rect().end.x < _melee_slot.get_global_rect().position.x
		and _melee_slot.get_global_rect().end.x < _magazine_slot.get_global_rect().position.x)

	scene.queue_free()
	await get_tree().process_frame
	# Keep the combat HUD checks above independent of the objective fixtures.
	await _test_world_markers()
	await _test_boss_hud()
	# Audio shutdown needs a mix cycle to consume queued stop commands.
	await get_tree().create_timer(0.15).timeout
	# A helper that aborts early must not let the parent coroutine report success.
	_finished = _checks == EXPECTED_CHECKS


func _test_counter_shield_ui(scene: Node) -> void:
	print("== persistent counter-shield HUD")
	_player.stats.apply_buff(load("res://buffs/skill_unlock.tres") as Buff)
	_check("counter card selects the capacity mode and activates", _player.shield.is_counter_mode()
		and _player.shield.try_activate())
	_player.shield._process(12.0)
	_shield_slot.advance(0.0)
	_vitals.advance(0.0)
	_check("empty counter shield stays visible after twelve seconds", _shield_slot.active
		and _vitals.shield_visible and is_equal_approx(_vitals.shield_fraction, 1.0)
		and _shield_slot.count_text == "0/100" and _player.shield._overlay.visible)
	var health_before := _player.health.health
	_player.health.apply_damage(35.0, Hitbox.BodyPart.BODY, scene.get_node("Enemy1"))
	_shield_slot.advance(0.0)
	_vitals.advance(0.0)
	_check("HUD reads actual absorbed damage while health is protected", _player.health.health == health_before
		and _shield_slot.count_text == "35/100" and is_equal_approx(_shield_slot.shield_charge_fraction, 0.35))
	_check("vitals show remaining shield capacity instead of an expired timer", _vitals.shield_counter_mode
		and _vitals.shield_visible and is_equal_approx(_vitals.shield_fraction, 0.65))
	_player.shield._process(12.0)
	_vitals.advance(0.0)
	_check("partially charged shield does not drain with time", _vitals.shield_visible
		and is_equal_approx(_vitals.shield_fraction, 0.65) and _player.shield._overlay.visible)
	var released := _player.shield.try_activate()
	_shield_slot.advance(0.0)
	_vitals.advance(0.0)
	_check("second G releases the shield and changes HUD to cooldown", released
		and _shield_slot.cooling and not _shield_slot.active and not _vitals.shield_visible
		and _shield_slot.count_text.is_empty())
	_player.shield.cancel()
	_player.stats.apply_buff(load("res://buffs/skill_duration.tres") as Buff)
	_player.shield.try_activate()
	_shield_slot.advance(0.0)
	_check("duration upgrade displays its counter-mode capacity benefit", _shield_slot.count_text == "0/125")
	_player.shield.cancel()
	_player.stats.clear_buffs()
	_shield_slot.advance(0.0)
	_vitals.advance(0.0)
	_check("clearing counter mode removes capacity-specific HUD", not _shield_slot.shield_counter_mode
		and _shield_slot.count_text.is_empty() and not _vitals.shield_visible)


func _test_magazine_slot() -> void:
	print("== C dangerous-magazine slot")
	var weapon := _player.weapon
	var traits := _player.combat_traits
	_player.stats.base[Stats.SKILL_UNLOCKED] = 0.0
	_magazine_slot.advance(0.0)
	_check("C starts locked without the dangerous-magazine buff", _magazine_slot.locked
		and not _magazine_slot.slot_ready and _magazine_slot.count_text.is_empty())
	_check("C has its own magazine mode and key", _magazine_slot.mode == AbilitySlot.Mode.MAGAZINE
		and _magazine_slot.key_text == "C")
	_player.stats.apply_buff(BuffPool.ALL[0])
	_magazine_slot.advance(0.0)
	_shield_slot.advance(0.0)
	_check("unlocked empty C is dark and reads 0/1", not _magazine_slot.locked
		and not _magazine_slot.slot_ready and _magazine_slot.count_text == "0/1")
	_check("unlocking C does not unlock G", _shield_slot.locked and not _shield_slot.slot_ready)
	_check("the shield no longer carries a duplicate magazine badge", not ("danger_badge" in _shield_slot)
		and not ("corner_icon" in _shield_slot))
	weapon.ammo = 0
	weapon.reserve = 120
	weapon.try_reload()
	_magazine_slot.advance(0.0)
	_check("empty reload alone leaves C dark", weapon.is_reloading()
		and not traits.has_reload_charge() and not _magazine_slot.slot_ready
		and _magazine_slot.count_text == "0/1")
	weapon._process(10.0)
	weapon.ammo = 1
	weapon._cooldown = 0.0
	weapon.try_fire()
	_magazine_slot.advance(0.0)
	_check("last shot lights C before reload completes and reads 1/1", traits.has_reload_charge()
		and weapon.is_reloading()
		and not _magazine_slot.locked and _magazine_slot.slot_ready and _magazine_slot.count_text == "1/1")
	traits._process(ReloadCharge.FUSE_TIME + 0.1)
	_magazine_slot.advance(0.0)
	_check("the stored magazine keeps C ready past its flight fuse", _magazine_slot.slot_ready
		and _magazine_slot.count_text == "1/1")
	weapon.select_next()
	_magazine_slot.advance(0.0)
	_check("switching guns keeps the stored C slot lit", _magazine_slot.slot_ready
		and _magazine_slot.count_text == "1/1")
	var thrown: Array[Node3D] = []
	traits.reload_charge_thrown.connect(func(charge: Node3D): thrown.append(charge))
	_check("throwing C launches one real stored magazine", traits.try_throw_reload_charge()
		and thrown.size() == 1)
	_magazine_slot.advance(0.0)
	_check("throwing C returns its unlocked slot to dark 0/1", not traits.has_reload_charge()
		and not _magazine_slot.locked and not _magazine_slot.slot_ready
		and _magazine_slot.count_text == "0/1")
	_check("C cannot throw again while its slot is empty", not traits.try_throw_reload_charge()
		and thrown.size() == 1)
	for charge in thrown:
		charge.queue_free()
	weapon._reload_left = 0.0
	weapon._cooldown = 0.0
	weapon.ammo = 1
	weapon.reserve = 120
	weapon.try_fire()
	_magazine_slot.advance(0.0)
	_check("a later final shot can ready C again", _magazine_slot.slot_ready
		and _magazine_slot.count_text == "1/1")
	traits.clear()
	_magazine_slot.advance(0.0)
	_check("clearing combat inventory returns C to dark 0/1", not _magazine_slot.locked
		and not _magazine_slot.slot_ready and _magazine_slot.count_text == "0/1")
	_player.stats.clear_buffs()
	_magazine_slot.advance(0.0)
	_check("removing the buff locks C again", _magazine_slot.locked
		and not _magazine_slot.slot_ready and _magazine_slot.count_text.is_empty())


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
	_check("the clear objective has no redundant subtitle", not detail.visible
		and detail.text.is_empty())
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
		and director.phase == ZoneDirector.Phase.CLOCK_POINT and top.phase == director.phase)
	_check("the hammer objective keeps only a short E hint", objective.text == "挥刃敲钟"
		and top.enemies_alive == 0 and detail.visible and detail.text == "按 V 挥刃"
		and top.size.y == ObjectivePanel.EXPANDED_HEIGHT)
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
		and objective.text == "到增益台按 F" and not detail.visible)
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

	_place_capture(point, camera, Vector3(100.0, -30.0, -20.0))
	marker.refresh()
	var target_screen := camera.unproject_position(point.global_position + Vector3.UP * 3.5)
	var target_direction := (target_screen - center).normalized()
	_check("an off-screen target aims its edge arrow at the projected target", marker.offscreen
		and marker.arrow_visible and marker.direction.dot(target_direction) > 0.9999
		and marker.arrow_tip().distance_to(marker.screen_position
			+ target_direction * WorldMarker.ARROW_TIP) < 0.1)

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
	_check("%s: the edge arrow appears only on clamped markers" % label,
		marker.arrow_visible == offscreen and (not offscreen or marker.arrow_tip().distance_to(
			marker.screen_position + direction.normalized() * WorldMarker.ARROW_TIP) < 0.1))
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
		and top.phase == director.phase and objective.text == "击倒 Boss" and top.enemies_alive == 10)
	_check("the boss objective has no redundant subtitle", not detail.visible
		and detail.text.is_empty())
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
	_check("small-enemy death updates the counter but not boss health", top.enemies_alive == 9
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
		and director.phase == ZoneDirector.Phase.CLOCK_POINT and top.phase == director.phase
		and objective.text == "挥刃敲钟" and top.enemies_alive == 8
		and detail.visible and detail.text == "按 V 砸核心")
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
	var buff_rect := (hud.get_node("BuffBar") as Control).get_global_rect()
	var boss_rect := (hud.get_node("BossHealth") as BossHealth).get_global_rect()
	var view := hud.get_viewport().get_visible_rect()
	_check("%s: the objective panel occupies its collapsed rectangle" % label, top.visible
		and top_rect == Rect2(32.0, 24.0, 280.0, 128.0))
	_check("%s: the buff bar stacks right below the objective panel" % label,
		buff_rect.position == Vector2(32.0, 162.0) and not top_rect.intersects(buff_rect))
	_check("%s: the objective panel stays on screen" % label, view.encloses(top_rect))
	_check("%s: boss health stays on screen" % label, view.encloses(boss_rect))
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
