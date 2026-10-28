extends Node
## Headless check of the graphical HUD: vitals, ammo block, ability slots and
## their data-driven icons. Run from the project root:
##   godot --headless --path . res://tests/hud_test.tscn
## Prints one line per check. Exits 1 if a check failed or if the run stopped
## before the last check, so it cannot pass by accident.

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
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
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
	# Audio shutdown needs a mix cycle to consume queued stop commands.
	await get_tree().create_timer(0.15).timeout
	_finished = true


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
