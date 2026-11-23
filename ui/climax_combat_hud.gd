class_name ClimaxCombatHUD
extends CanvasLayer
## The climax composition root injects the player (and optionally the final boss)
## and owns visibility/lifetime. Styled in Scheme B (Architectural Editorial).

class ScopedPauseMenu extends PauseMenu:
	func _exit_tree() -> void:
		if is_open():
			close()

const SLOT_SHORT: Array[String] = ["枪", "刃", "步", "域"]

var player: Player
var boss: Enemy
var settings: GameSettings
var crosshair: Crosshair
var vitals: Vitals
var weapon_panel: EditorialWeaponPanel
var ammo: Label
var combat_root: Control
var combat_feedback: CombatFeedbackLayer
var pause_layer: CanvasLayer
var inspector: BuildInspector
var pause_menu: PauseMenu
var _boss_header: PanelContainer
var _boss_name: Label
var _boss_hp: Label
var _boss_state: Label
var _boss_bar: RealmBossBar
var _slot_badges: Array[Label] = []
var _trait_count_badge: Label
var _tab_badge: Label
var _resonance: Label
var combat_visible := false
var _finished := false
var _base_sensitivity := 0.0022


func setup(value: Player, boss_target: Enemy = null) -> void:
	player = value
	boss = boss_target


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_PAUSABLE
	combat_root = Control.new()
	combat_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	EditorialStyle.apply_theme(combat_root)
	add_child(combat_root)

	var enemy_bars := EnemyHealthBars.new()
	combat_root.add_child(enemy_bars)
	enemy_bars.setup(player, player.get_parent())

	_build_top_left_plaque()
	_build_boss_ruler()
	_build_top_right_slots()

	crosshair = Crosshair.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_root.add_child(crosshair)

	vitals = Vitals.new()
	vitals.size = Vector2(360, 88)
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.offset_left = 28
	vitals.offset_top = -114
	vitals.offset_right = 388
	vitals.offset_bottom = -26
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_root.add_child(vitals)
	vitals.setup(player)

	BoonHitstop.attach(self, player)

	weapon_panel = EditorialWeaponPanel.new()
	weapon_panel.name = "EditorialWeaponPanel"
	weapon_panel.size = Vector2(280, 88)
	weapon_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_panel.offset_left = -308
	weapon_panel.offset_top = -114
	weapon_panel.offset_right = -28
	weapon_panel.offset_bottom = -26
	combat_root.add_child(weapon_panel)
	weapon_panel.setup(player.weapon)

	_resonance = EditorialStyle.make_label("", 15, EditorialStyle.GOLD_BRIGHT, 700, true, 1)
	_resonance.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_resonance.offset_left = -240
	_resonance.offset_right = 240
	_resonance.offset_top = -64
	_resonance.offset_bottom = -26
	_resonance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resonance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_resonance.add_theme_stylebox_override("normal",
		EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.GOLD, 2, Vector2(3, 3), Color(EditorialStyle.INK, 0.78), 14, 6))
	combat_root.add_child(_resonance)

	# Kept hidden for compatibility with callers inspecting `ammo.text`.
	ammo = Label.new()
	ammo.visible = false
	ammo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_root.add_child(ammo)

	combat_feedback = CombatFeedbackLayer.new()
	combat_feedback.name = "CombatFeedbackLayer"
	combat_root.add_child(combat_feedback)
	combat_feedback.setup(player)

	settings = GameSettings.new()
	if DisplayServer.get_name() != "headless":
		settings.load_from(GameSettings.settings_path)
	_base_sensitivity = player.mouse_sensitivity
	settings.changed.connect(_apply_settings)
	_apply_settings()

	# Keep Esc above the print/nova flash, and outside the hidden combat panel.
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 90
	add_child(pause_layer)
	pause_menu = ScopedPauseMenu.new()
	pause_layer.add_child(pause_menu)
	pause_menu.setup(settings, player, null)
	inspector = preload("res://ui/codex/build_inspector.tscn").instantiate() as BuildInspector
	inspector.player = player
	inspector.can_open = func(): return combat_visible and not _finished
	pause_layer.add_child(inspector)
	if is_instance_valid(player.boons):
		player.boons.changed.connect(_refresh_boons)
		_refresh_boons()
	set_combat_visible(false)


func _build_top_left_plaque() -> void:
	var plaque := HBoxContainer.new()
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_theme_constant_override("separation", 0)
	plaque.position = Vector2(28, 24)
	combat_root.add_child(plaque)

	var idx_box := PanelContainer.new()
	idx_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	idx_box.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.INK, 2, Vector2(4, 4), Color(EditorialStyle.INK, 0.78), 14, 10))
	plaque.add_child(idx_box)
	idx_box.add_child(EditorialStyle.make_label("05", 22, EditorialStyle.GOLD_BRIGHT, 800, true))

	var info_box := PanelContainer.new()
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style := EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(4, 4), Color(EditorialStyle.INK, 0.78), 16, 8)
	info_style.border_width_left = 0
	info_style.border_width_right = 5
	info_box.add_theme_stylebox_override("panel", info_style)
	plaque.add_child(info_box)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	info_box.add_child(row)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(EditorialStyle.make_label("CLIMAX  /  心智终局", 12, EditorialStyle.SLATE, 700, true, 1))
	col.add_child(EditorialStyle.make_label("减速破盾 · 破绽暴击 · 撞墙", 16, EditorialStyle.INK, 700))

	var strip := ColorRect.new()
	strip.color = EditorialStyle.GOLD
	strip.custom_minimum_size = Vector2(5, 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(strip)


func _build_boss_ruler() -> void:
	_boss_header = PanelContainer.new()
	_boss_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_header.offset_left = -260
	_boss_header.offset_right = 260
	_boss_header.offset_top = 20
	_boss_header.offset_bottom = 56
	_boss_header.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.INK, 2, Vector2(4, 4), Color(EditorialStyle.INK, 0.78), 14, 5))
	combat_root.add_child(_boss_header)

	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 10)
	_boss_header.add_child(header_row)

	var accent_tag := ColorRect.new()
	accent_tag.color = EditorialStyle.GOLD
	accent_tag.custom_minimum_size = Vector2(5, 18)
	accent_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	accent_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(accent_tag)

	_boss_name = EditorialStyle.make_label("完美替身", 18, EditorialStyle.PAPER, 800, false, 3)
	_boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(_boss_name)

	_boss_state = EditorialStyle.make_label("", 12, EditorialStyle.PAPER, 800, false, 1)
	_boss_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_state.hide()
	header_row.add_child(_boss_state)

	_boss_hp = EditorialStyle.make_label("", 15, EditorialStyle.PAPER, 700, true, 1)
	_boss_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(_boss_hp)

	var code := EditorialStyle.make_label("FINAL // 05", 12, EditorialStyle.ASH, 700, true, 2)
	code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(code)

	_boss_bar = RealmBossBar.new()
	_boss_bar.name = "BossBar"
	combat_root.add_child(_boss_bar)
	_boss_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.offset_left = -260
	_boss_bar.offset_right = 260
	_boss_bar.offset_top = 56
	_boss_bar.offset_bottom = 74
	_boss_bar.setup(boss.health if is_instance_valid(boss) else null, EditorialStyle.GOLD)

	_boss_header.visible = _boss_bar.visible
	_boss_bar.visibility_changed.connect(func() -> void: _boss_header.visible = _boss_bar.visible)
	_update_boss_readout()


func _build_top_right_slots() -> void:
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	strip.offset_left = -246
	strip.offset_right = -28
	strip.offset_top = 24
	strip.offset_bottom = 64
	strip.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.INK, 2, Vector2(-4, 4), Color(EditorialStyle.PAPER, 0.85), 8, 6))
	combat_root.add_child(strip)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	strip.add_child(row)

	_slot_badges.clear()
	for i in 4:
		var badge := EditorialStyle.make_label(SLOT_SHORT[i], 13, EditorialStyle.SLATE, 700)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(28, 26)
		badge.add_theme_stylebox_override("normal",
			EditorialStyle.plaque(EditorialStyle.INK_TRACK, EditorialStyle.INK_TRACK, 0, Vector2.ZERO, Color.TRANSPARENT, 0, 0))
		row.add_child(badge)
		_slot_badges.append(badge)

	_trait_count_badge = EditorialStyle.make_label("", 12, EditorialStyle.GOLD_BRIGHT, 700, true)
	_trait_count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trait_count_badge.hide()
	row.add_child(_trait_count_badge)

	_tab_badge = EditorialStyle.make_label(KeyHint.of("inspect_build"), 12, EditorialStyle.PAPER, 700, true, 1)
	_tab_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tab_badge.add_theme_stylebox_override("normal",
		EditorialStyle.plaque(EditorialStyle.INK_SOFT, Color(EditorialStyle.PAPER, 0.35), 1, Vector2.ZERO, Color.TRANSPARENT, 8, 3))
	row.add_child(_tab_badge)


func _refresh_boons() -> void:
	if not is_instance_valid(player) or player.boons == null:
		return
	for i in mini(_slot_badges.size(), player.boons.slots.size()):
		var badge := _slot_badges[i]
		var card: BoonData = player.boons.slots[i].data
		if card != null:
			var accent := EditorialStyle.GOLD_BRIGHT if card.rarity == BoonData.Rarity.DUAL else EditorialStyle.realm_accent(card.sin)
			var text_col := EditorialStyle.INK if card.sin == PsycheFragments.SLOTH or card.rarity == BoonData.Rarity.DUAL else EditorialStyle.PAPER
			badge.add_theme_color_override("font_color", text_col)
			badge.add_theme_stylebox_override("normal",
				EditorialStyle.plaque(accent, accent, 0, Vector2.ZERO, Color.TRANSPARENT, 0, 0))
		else:
			badge.add_theme_color_override("font_color", EditorialStyle.SLATE)
			badge.add_theme_stylebox_override("normal",
				EditorialStyle.plaque(EditorialStyle.INK_TRACK, EditorialStyle.INK_TRACK, 0, Vector2.ZERO, Color.TRANSPARENT, 0, 0))
	var trait_count := player.boons.traits.size()
	_trait_count_badge.visible = trait_count > 0
	if trait_count > 0:
		_trait_count_badge.text = "+%d" % trait_count


func _update_boss_readout() -> void:
	if _boss_hp == null:
		return
	if not is_instance_valid(boss) or boss.health == null or boss.health.is_dead():
		_boss_hp.text = ""
		_boss_state.text = ""
		_boss_state.hide()
		return
	var h := boss.health
	var cur := maxi(0, ceili(h.health))
	var max_h := maxi(1, ceili(h.max_health))
	var pct := clampi(roundi(100.0 * h.health / maxf(h.max_health, 1.0)), 0, 100)
	_boss_hp.text = "%d / %d  ·  %d%%" % [cur, max_h, pct]
	if boss is FlawlessDoppelganger:
		var dop := boss as FlawlessDoppelganger
		match dop.phase:
			FlawlessDoppelganger.Phase.GUARD:
				if _boss_state.text != "护盾":
					_boss_state.text = "护盾"
					_boss_state.add_theme_color_override("font_color", EditorialStyle.PAPER)
					_boss_state.add_theme_stylebox_override("normal",
						EditorialStyle.plaque(EditorialStyle.SHIELD, EditorialStyle.SHIELD, 0, Vector2.ZERO, Color.TRANSPARENT, 7, 2))
				_boss_state.show()
			FlawlessDoppelganger.Phase.EXPOSED:
				if _boss_state.text != "破绽":
					_boss_state.text = "破绽"
					_boss_state.add_theme_color_override("font_color", EditorialStyle.PAPER)
					_boss_state.add_theme_stylebox_override("normal",
						EditorialStyle.plaque(EditorialStyle.WARNING, EditorialStyle.WARNING, 0, Vector2.ZERO, Color.TRANSPARENT, 7, 2))
				_boss_state.show()
			_:
				_boss_state.text = ""
				_boss_state.hide()


func set_combat_visible(value: bool) -> void:
	combat_visible = value and not _finished
	combat_root.visible = combat_visible and not player.health.is_dead()
	combat_feedback.set_enabled(combat_root.visible)


func _process(_delta: float) -> void:
	if _finished or not is_instance_valid(player):
		return
	combat_root.visible = combat_visible and not player.health.is_dead()
	if not combat_root.visible:
		return
	_update_boss_readout()
	if player.fragments != null:
		var cooldown := player.fragments.resonance_cooldown
		var res_text := "[ %s ] 沉睡共鸣 %s" % [KeyHint.of("psyche_resonance"), "就绪" if cooldown <= 0 else "%.1f s" % cooldown]
		var bar_text := "温润屏障 %d" % int(roundf(player.fragments.barrier))
		_resonance.text = "%s   //   %s" % [res_text, bar_text]
		_resonance.visible = true
	else:
		_resonance.visible = false
	ammo.text = "%d / %d\n%s" % [player.weapon.ammo, player.weapon.magazine_capacity(), "晶体重组…" if player.weapon.is_reloading() else "黑晶手枪"]
	var half_height := get_viewport().get_visible_rect().size.y * 0.5
	crosshair.gap = 2.0 + half_height * tan(deg_to_rad(player.weapon.spread_degrees())) / tan(deg_to_rad(player.view_camera.fov) * 0.5) if settings.dynamic_gap else crosshair.min_gap
	crosshair.show_lines = not player.is_aiming()
	crosshair.focused = player.is_aiming()
	crosshair.queue_redraw()


func _apply_settings() -> void:
	crosshair.style = settings.crosshair_style
	crosshair.line_length = 5 * settings.crosshair_size
	crosshair.thickness = settings.crosshair_thickness
	crosshair.color = Color(settings.crosshair_color, settings.crosshair_alpha)
	player.set_look_sensitivity(_base_sensitivity * settings.mouse_sensitivity, settings.ads_sensitivity)
	KeyBindings.apply(settings.bindings)
	if _tab_badge != null:
		_tab_badge.text = KeyHint.of("inspect_build")
	var bus := AudioServer.get_bus_index(MusicDirector.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, settings.music_volume <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(settings.music_volume, 0.001)))


func finish() -> void:
	if is_instance_valid(inspector):
		inspector.close(true)
		inspector.queue_free()
	_finished = true
	set_combat_visible(false)
	vitals.set_process(false)
	if is_instance_valid(weapon_panel):
		weapon_panel.set_process(false)
	if is_instance_valid(pause_menu):
		pause_menu.close()
		pause_menu.set_process_input(false)
		pause_menu.set_process_unhandled_input(false)
		pause_menu.queue_free()
	pause_layer.hide()
	set_process(false)
