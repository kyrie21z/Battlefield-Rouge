class_name RealmHUD
extends CanvasLayer
## Reads the injected stage/player. Architectural Editorial (Scheme B) combat HUD.

const SLOT_SHORT: Array[String] = ["枪", "刃", "步", "域"]

var stage: RealmStage
var settings: GameSettings
var vitals: Vitals
var weapon_panel: EditorialWeaponPanel
var crosshair: Crosshair
var damage_indicator: DamageIndicator
var inspector: BuildInspector
var pause_menu: PauseMenu
var _objective: Label
var _time_warp: SlumberTimeWarp
var _ammo: Label
var _boons: Label
var _boss_bar: RealmBossBar
var _boss_name: Label
var _boss_header: PanelContainer
var _boss_state: Label
var _boss_hp: Label
var _boss_code: Label
var _monochrome: ColorRect
var _stasis: ColorRect
var _stasis_strength := 0.0
var _base_sensitivity := 0.0022
var _root: Control
var _realm_plaque: HBoxContainer
var _boon_strip: PanelContainer
var _slot_badges: Array[Label] = []
var _trait_count_badge: Label
var _tab_badge: Label
var _resonance: Label
var _exit_hint: Label
var _exit_hint_style_gate: StyleBoxFlat
var _exit_hint_style_orb: StyleBoxFlat
var _death_backdrop: ColorRect
var _death_panel: PanelContainer
var _death_reason: Label
var _hub_button: Button
var _fall_notice: Label
var _fall_notice_left := 0.0
var _wave_notice: Label
var _wave_notice_left := 0.0
var hurt_feedback: RealmHurtFeedback
var combat_feedback: CombatFeedbackLayer


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	EditorialStyle.apply_theme(_root)
	add_child(_root)

	_monochrome = ColorRect.new()
	_monochrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monochrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap; uniform float amount=0.; void fragment(){vec4 c=textureLod(screen_texture,SCREEN_UV,0.);float l=dot(c.rgb,vec3(.299,.587,.114));COLOR=vec4(mix(c.rgb,vec3(l),amount),1.);}"
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	_monochrome.material = material_value
	_root.add_child(_monochrome)

	if stage.realm == PsycheFragments.SLOTH:
		_stasis = ColorRect.new()
		_stasis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stasis.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var stasis_material := ShaderMaterial.new()
		stasis_material.shader = preload("res://ui/shaders/sloth_stasis.gdshader")
		_stasis.material = stasis_material
		_stasis.hide()
		_root.add_child(_stasis)

	hurt_feedback = RealmHurtFeedback.new()
	hurt_feedback.health = stage.player.health
	_root.add_child(hurt_feedback)

	var enemy_bars := EnemyHealthBars.new()
	_root.add_child(enemy_bars)
	enemy_bars.setup(stage.player, stage, stage.enemies, EditorialStyle.realm_accent(stage.realm))

	_build_top_left_plaque()
	_build_boss_ruler()
	_build_top_right_slots()
	_build_bottom_chrome()

	crosshair = Crosshair.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(crosshair)

	damage_indicator = DamageIndicator.new()
	damage_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(damage_indicator)
	damage_indicator.setup(stage.player)

	combat_feedback = CombatFeedbackLayer.new()
	combat_feedback.name = "CombatFeedbackLayer"
	_root.add_child(combat_feedback)
	combat_feedback.setup(stage.player)

	stage.player.health.damaged.connect(_damaged)
	BoonHitstop.attach(self, stage.player)

	settings = GameSettings.new()
	if DisplayServer.get_name() != "headless":
		settings.load_from(GameSettings.settings_path)
	_base_sensitivity = stage.player.mouse_sensitivity
	settings.changed.connect(_apply_settings)
	_apply_settings()

	pause_menu = PauseMenu.new()
	_root.add_child(pause_menu)
	pause_menu.setup(settings, stage.player, null)
	pause_menu.configure_exit_button(stage.campaign, "进度已保存至本房间起点")
	pause_menu.return_to_title_requested.connect(stage.request_title)

	inspector = preload("res://ui/codex/build_inspector.tscn").instantiate() as BuildInspector
	inspector.player = stage.player
	_root.add_child(inspector)

	stage.player.boons.changed.connect(_refresh_boons)
	# 沉睡共鸣的全屏观感由 UI 层负责：components 只发 activated 信号，
	# 不反向依赖 ui/（ARCHITECTURE.md 的 ui → zone → actors → components）。
	stage.player.fragments.activated.connect(_on_fragment_activated)
	_refresh_boons()
	_build_exit_and_death_feedback()
	stage.wave_spawned.connect(_on_wave_spawned)


func _build_top_left_plaque() -> void:
	var accent := EditorialStyle.realm_accent(stage.realm)
	_realm_plaque = HBoxContainer.new()
	_realm_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_realm_plaque.add_theme_constant_override("separation", 0)
	_realm_plaque.position = Vector2(28, 24)
	_root.add_child(_realm_plaque)

	var idx_box := PanelContainer.new()
	idx_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	idx_box.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.INK, 2, Vector2(4, 4), Color(EditorialStyle.INK, 0.75), 14, 10))
	_realm_plaque.add_child(idx_box)
	var idx_label := EditorialStyle.make_label("%02d" % (stage.realm + 1), 22, EditorialStyle.PAPER, 800, true)
	idx_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	idx_box.add_child(idx_label)

	var info_box := PanelContainer.new()
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style := EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(4, 4), Color(EditorialStyle.INK, 0.75), 16, 8)
	info_style.border_width_left = 0
	info_style.border_width_right = 5
	info_box.add_theme_stylebox_override("panel", info_style)
	_realm_plaque.add_child(info_box)

	var info_row := HBoxContainer.new()
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_theme_constant_override("separation", 12)
	info_box.add_child(info_row)

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_theme_constant_override("separation", 2)
	info_row.add_child(text_col)

	var realm_caption := "%s  /  %s" % [EditorialStyle.realm_en(stage.realm), RealmStage.TITLES[stage.realm]]
	text_col.add_child(EditorialStyle.make_label(realm_caption, 12, EditorialStyle.SLATE, 700, true, 1))

	_objective = EditorialStyle.make_label("", 18, EditorialStyle.INK, 700)
	text_col.add_child(_objective)

	var accent_strip := ColorRect.new()
	accent_strip.color = accent
	accent_strip.custom_minimum_size = Vector2(5, 0)
	accent_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(accent_strip)


func _build_boss_ruler() -> void:
	var accent := EditorialStyle.realm_accent(stage.realm)
	_boss_header = PanelContainer.new()
	_boss_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_header.offset_left = -260
	_boss_header.offset_right = 260
	_boss_header.offset_top = 20
	_boss_header.offset_bottom = 56
	_boss_header.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.INK, 2, Vector2(4, 4), Color(EditorialStyle.INK, 0.78), 14, 5))
	_root.add_child(_boss_header)

	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 10)
	_boss_header.add_child(header_row)

	var accent_tag := ColorRect.new()
	accent_tag.color = accent
	accent_tag.custom_minimum_size = Vector2(5, 18)
	accent_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	accent_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(accent_tag)

	_boss_name = EditorialStyle.make_label(EditorialStyle.BOSS_NAMES[stage.realm], 18, EditorialStyle.PAPER, 800, false, 3)
	_boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(_boss_name)

	_boss_state = EditorialStyle.make_label("", 12, EditorialStyle.WARNING, 700, true, 1)
	_boss_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_state.hide()
	header_row.add_child(_boss_state)

	_boss_hp = EditorialStyle.make_label("", 15, EditorialStyle.PAPER, 700, true, 1)
	_boss_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(_boss_hp)

	_boss_code = EditorialStyle.make_label("BOSS // %02d" % (stage.realm + 1), 12, EditorialStyle.ASH, 700, true, 2)
	_boss_code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(_boss_code)

	_boss_bar = RealmBossBar.new()
	_boss_bar.name = "BossBar"
	_root.add_child(_boss_bar)
	_boss_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.offset_left = -260
	_boss_bar.offset_right = 260
	_boss_bar.offset_top = 56
	_boss_bar.offset_bottom = 74
	_boss_bar.setup(stage.boss.health if is_instance_valid(stage.boss) else null, accent)

	_sync_boss_header_visibility()
	_update_boss_readout()
	_boss_bar.visibility_changed.connect(_sync_boss_header_visibility)


func _update_boss_readout() -> void:
	if _boss_hp == null:
		return
	if not is_instance_valid(stage.boss) or stage.boss.health == null or stage.boss.health.is_dead():
		_boss_hp.text = ""
		if _boss_state != null:
			_boss_state.hide()
		return
	var h := stage.boss.health
	var cur := maxi(0, ceili(h.health))
	var max_h := maxi(1, ceili(h.max_health))
	var pct := clampi(roundi(100.0 * h.health / maxf(h.max_health, 1.0)), 0, 100)
	if h.shield_points > 0.0:
		_boss_hp.text = "%d / %d (+%d) · %d%%" % [cur, max_h, ceili(h.shield_points), pct]
	else:
		_boss_hp.text = "%d / %d · %d%%" % [cur, max_h, pct]
	if _boss_state != null:
		if stage.boss is FearOculus and (stage.boss as FearOculus).phase == 2:
			if _boss_state.text != "破绽":
				_boss_state.text = "破绽"
				_boss_state.add_theme_color_override("font_color", EditorialStyle.PAPER)
				_boss_state.add_theme_stylebox_override("normal",
					EditorialStyle.plaque(EditorialStyle.WARNING, EditorialStyle.WARNING, 0, Vector2.ZERO, Color.TRANSPARENT, 7, 2))
			_boss_state.show()
		elif h.shield_points > 0.0:
			if _boss_state.text != "护盾":
				_boss_state.text = "护盾"
				_boss_state.add_theme_color_override("font_color", EditorialStyle.PAPER)
				_boss_state.add_theme_stylebox_override("normal",
					EditorialStyle.plaque(EditorialStyle.SHIELD, EditorialStyle.SHIELD, 0, Vector2.ZERO, Color.TRANSPARENT, 7, 2))
			_boss_state.show()
		elif int(stage.boss.get("boss_phase")) >= 2:
			if _boss_state.text != "二阶段":
				_boss_state.text = "二阶段"
				_boss_state.add_theme_color_override("font_color", EditorialStyle.PAPER)
				_boss_state.add_theme_stylebox_override("normal",
					EditorialStyle.plaque(EditorialStyle.GOLD, EditorialStyle.GOLD, 0, Vector2.ZERO, Color.TRANSPARENT, 7, 2))
			_boss_state.show()
		else:
			_boss_state.text = ""
			_boss_state.hide()


func _sync_boss_header_visibility() -> void:
	_boss_header.visible = _boss_bar.visible
	_boss_name.visible = _boss_bar.visible


func _build_top_right_slots() -> void:
	_boon_strip = PanelContainer.new()
	_boon_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boon_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_boon_strip.offset_left = -246
	_boon_strip.offset_right = -28
	_boon_strip.offset_top = 24
	_boon_strip.offset_bottom = 64
	_boon_strip.add_theme_stylebox_override("panel",
		EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.INK, 2, Vector2(-4, 4), Color(EditorialStyle.PAPER, 0.85), 8, 6))
	_root.add_child(_boon_strip)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	_boon_strip.add_child(row)

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

	# Kept hidden for compatibility with any caller reading `_boons.text`.
	_boons = Label.new()
	_boons.visible = false
	_boons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boons)


func _build_bottom_chrome() -> void:
	vitals = Vitals.new()
	vitals.size = Vector2(360, 88)
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.offset_left = 28
	vitals.offset_top = -114
	vitals.offset_right = 388
	vitals.offset_bottom = -26
	_root.add_child(vitals)
	vitals.setup(stage.player)

	weapon_panel = EditorialWeaponPanel.new()
	weapon_panel.name = "EditorialWeaponPanel"
	weapon_panel.size = Vector2(280, 88)
	weapon_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_panel.offset_left = -308
	weapon_panel.offset_top = -114
	weapon_panel.offset_right = -28
	weapon_panel.offset_bottom = -26
	_root.add_child(weapon_panel)
	weapon_panel.setup(stage.player.weapon)

	# Kept hidden for compatibility with any caller reading `_ammo.text`.
	_ammo = Label.new()
	_ammo.visible = false
	_ammo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ammo)

	_resonance = EditorialStyle.make_label("", 15, EditorialStyle.GOLD_BRIGHT, 700, true, 1)
	_resonance.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_resonance.offset_left = -190
	_resonance.offset_right = 190
	_resonance.offset_top = -64
	_resonance.offset_bottom = -26
	_resonance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resonance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_resonance.add_theme_stylebox_override("normal",
		EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.GOLD, 2, Vector2(3, 3), Color(EditorialStyle.INK, 0.75), 14, 6))
	_root.add_child(_resonance)


func _build_exit_and_death_feedback() -> void:
	_fall_notice = EditorialStyle.make_label("", 18, EditorialStyle.PAPER, 700, false, 1)
	_fall_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_fall_notice.offset_left = -260
	_fall_notice.offset_right = 260
	_fall_notice.offset_top = 110
	_fall_notice.offset_bottom = 156
	_fall_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fall_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fall_style := EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.WARNING, 2, Vector2(4, 4), Color(EditorialStyle.INK, 0.8), 16, 8)
	fall_style.border_width_left = 6
	_fall_notice.add_theme_stylebox_override("normal", fall_style)
	_root.add_child(_fall_notice)
	_fall_notice.hide()

	_wave_notice = EditorialStyle.make_label("", 18, EditorialStyle.PAPER, 700, false, 1)
	_wave_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wave_notice.offset_left = -220
	_wave_notice.offset_right = 220
	_wave_notice.offset_top = 96
	_wave_notice.offset_bottom = 136
	_wave_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var wave_style := EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.realm_accent(stage.realm), 2, Vector2(4, 4), Color(EditorialStyle.INK, 0.8), 16, 8)
	wave_style.border_width_left = 6
	_wave_notice.add_theme_stylebox_override("normal", wave_style)
	_root.add_child(_wave_notice)
	_wave_notice.hide()

	_exit_hint_style_gate = EditorialStyle.plaque(EditorialStyle.INK, EditorialStyle.INK, 2, Vector2(4, 4), Color(EditorialStyle.PAPER, 0.85), 18, 10)
	_exit_hint_style_gate.border_width_left = 5
	_exit_hint_style_gate.border_color = EditorialStyle.GOLD

	_exit_hint_style_orb = EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(5, 5), Color(EditorialStyle.INK, 0.88), 22, 12)
	_exit_hint_style_orb.border_width_top = 5

	_exit_hint = EditorialStyle.make_label("", 22, EditorialStyle.PAPER, 700, false, 1)
	_exit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exit_hint.size = Vector2(320, 68)
	_exit_hint.add_theme_stylebox_override("normal", _exit_hint_style_gate)
	_root.add_child(_exit_hint)
	_exit_hint.hide()

	_death_backdrop = ColorRect.new()
	_death_backdrop.color = Color(0.05, 0.06, 0.08, 0.72)
	_death_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_death_backdrop)
	_death_backdrop.hide()

	_death_panel = PanelContainer.new()
	_death_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_panel.offset_left = -270
	_death_panel.offset_right = 270
	_death_panel.offset_top = -150
	_death_panel.offset_bottom = 150
	var death_style := EditorialStyle.plaque(EditorialStyle.PAPER, EditorialStyle.INK, 2, Vector2(8, 8), Color(EditorialStyle.INK, 0.92), 36, 32)
	death_style.border_width_top = 6
	death_style.border_color = EditorialStyle.WARNING
	_death_panel.add_theme_stylebox_override("panel", death_style)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	_death_panel.add_child(column)

	_death_reason = EditorialStyle.make_label("", 28, EditorialStyle.INK, 800, false, 2)
	_death_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_death_reason)

	var retry_button := Button.new()
	retry_button.text = "重新挑战  ·  R"
	retry_button.custom_minimum_size = Vector2(280, 56)
	retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	EditorialStyle.style_button(retry_button, true, true, 22)
	retry_button.pressed.connect(stage.retry)
	column.add_child(retry_button)

	_hub_button = Button.new()
	_hub_button.text = "返回静滞之门"
	_hub_button.custom_minimum_size = Vector2(280, 48)
	_hub_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	EditorialStyle.style_button(_hub_button, false, true, 18)
	_hub_button.pressed.connect(stage.request_hub)
	column.add_child(_hub_button)
	MetaProgression.changed.connect(_refresh_hub_exit)

	_root.add_child(_death_panel)
	_death_panel.hide()


func _refresh_hub_exit() -> void:
	if not stage.fallen:
		return
	var affordable := MetaProgression.has_affordable_upgrade()
	_hub_button.text = "返回静滞之门 · 可锻造" if affordable else "返回静滞之门"


func _update_exit_and_death_feedback() -> void:
	if stage.fallen and not _death_panel.visible:
		_refresh_hub_exit()
	_death_backdrop.visible = stage.fallen
	_death_panel.visible = stage.fallen
	if stage.fallen:
		var abyss: bool = stage.player.health.last_damage_context.get("tag", &"") == &"abyss"
		_death_reason.text = "心智破碎\n%s" % ("坠入深渊" if abyss else "本次挑战结束")

	var orb := stage.talent_orb
	var orb_pending: bool = is_instance_valid(orb) and stage.orb_pending()
	var selecting: bool = is_instance_valid(stage.selection)
	var trapped: bool = stage.player.current_trapped
	_exit_hint.visible = (orb_pending or stage.exit_ready or trapped) and not stage.fallen and not stage.transitioning and not selecting
	if not _exit_hint.visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if trapped:
		_exit_hint.size = Vector2(320, 58)
		_exit_hint.position = Vector2(viewport_size.x * 0.5 - 160.0, viewport_size.y * 0.72)
		_exit_hint.add_theme_stylebox_override("normal", _exit_hint_style_gate)
		_exit_hint.add_theme_font_size_override("font_size", 20)
		_exit_hint.add_theme_color_override("font_color", EditorialStyle.PAPER)
		_exit_hint.text = "[ %s ]  冲刺脱离漩涡" % KeyHint.of("dash")
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var focus: Vector3 = orb.global_position + Vector3.UP * 1.85 if orb_pending else stage.gate.global_position + Vector3.UP * 2.0
	var target := focus
	if orb_pending:
		_exit_hint.size = Vector2(460, 92)
		_exit_hint.position = Vector2(viewport_size.x * 0.5 - 230.0, viewport_size.y * 0.72)
		_exit_hint.add_theme_stylebox_override("normal", _exit_hint_style_orb)
		_exit_hint.add_theme_font_size_override("font_size", 24)
		_exit_hint.add_theme_color_override("font_color", EditorialStyle.INK)
		var orb_distance := stage.player.global_position.distance_to(orb.global_position)
		if orb_distance <= TalentOrb.INTERACT_RANGE:
			_exit_hint.text = "[ %s ]  取回心智天赋" % KeyHint.of("interact")
		else:
			_exit_hint.text = "天赋球  ·  前方 %.0f 米\n朝标记方向前进" % orb_distance
		return

	var location := camera.unproject_position(target)
	if camera.is_position_behind(target):
		var side := 1.0 if camera.global_basis.x.dot(target - camera.global_position) >= 0 else -1.0
		location = Vector2(viewport_size.x * 0.5 + side * (viewport_size.x * 0.5 - 160), viewport_size.y * 0.5)
	_exit_hint.size = Vector2(300, 66)
	_exit_hint.add_theme_stylebox_override("normal", _exit_hint_style_gate)
	_exit_hint.add_theme_font_size_override("font_size", 20)
	_exit_hint.add_theme_color_override("font_color", EditorialStyle.PAPER)
	_exit_hint.position = Vector2(clampf(location.x - 150, 24, viewport_size.x - 324), clampf(location.y - 72, 96, viewport_size.y - 180))
	var distance := stage.player.global_position.distance_to(stage.gate.global_position)
	_exit_hint.text = "下一关门扉  ·  %.0f 米\n%s" % [distance, "[ %s ] 进入" % KeyHint.of("interact") if distance <= 3.0 else "朝标记方向前进"]


func _label(text_value: String, font_size: int) -> Label:
	var label := EditorialStyle.make_label(text_value, font_size, EditorialStyle.PAPER, 600)
	_root.add_child(label)
	return label


func _physics_process(delta: float) -> void:
	if not is_instance_valid(stage) or get_tree().paused:
		return
	if _wave_notice_left > 0.0:
		_wave_notice_left = maxf(0.0, _wave_notice_left - delta)


func _process(delta: float) -> void:
	if not is_instance_valid(stage) or not is_instance_valid(stage.player):
		return
	var player := stage.player
	var selecting := is_instance_valid(stage.selection)
	var show_chrome := not selecting and not stage.fallen
	_realm_plaque.visible = show_chrome
	_boon_strip.visible = show_chrome
	vitals.visible = show_chrome
	weapon_panel.visible = show_chrome

	_fall_notice_left = maxf(0.0, _fall_notice_left - delta)
	_fall_notice.visible = _fall_notice_left > 0 and not stage.fallen and not selecting
	_wave_notice.visible = _wave_notice_left > 0 and not stage.fallen and not selecting
	_update_exit_and_death_feedback()

	_resonance.visible = show_chrome and player.fragments.has_shard(PsycheFragments.SLOTH)
	_resonance.text = "[ %s ]  沉睡共鸣  ·  %s" % [KeyHint.of("psyche_resonance"), "就绪" if player.fragments.resonance_cooldown <= 0 else "%.1f s" % player.fragments.resonance_cooldown]
	_objective.text = stage.objective_text()
	if not stage.boss_room and stage.total_waves() > 1 and not stage.fallen \
		and not stage.transitioning and not stage.exit_ready and not stage.cleared:
		_objective.text = "第 %d/%d 波 · 剩余 %d" % [stage.current_wave(), stage.total_waves(), stage.remaining_encounter_enemies()]
	_update_boss_readout()
	_ammo.text = "%d / %d\n%s" % [player.weapon.ammo, player.weapon.magazine_capacity(), "晶体重组…" if player.weapon.is_reloading() else "黑晶手枪"]

	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var half_height := get_viewport().get_visible_rect().size.y * 0.5
		crosshair.gap = 2.0 + half_height * tan(deg_to_rad(player.weapon.spread_degrees())) / tan(deg_to_rad(camera.fov) * 0.5) if settings.dynamic_gap else crosshair.min_gap
	crosshair.visible = not player.health.is_dead() and not selecting
	crosshair.show_lines = not player.is_aiming()
	crosshair.focused = player.is_aiming()
	crosshair.queue_redraw()

	damage_indicator.visible = player.realm_effects.warnings_enabled
	_monochrome.visible = player.realm_effects.monochrome > 0
	(_monochrome.material as ShaderMaterial).set_shader_parameter("amount", player.realm_effects.monochrome)
	if _stasis != null:
		var strength := 0.0 if player.health.is_dead() else (1.0 - player.stasis_multiplier()) / 0.25
		_stasis_strength = move_toward(_stasis_strength, strength, delta * 7.0)
		_stasis.visible = _stasis_strength > 0.0
		(_stasis.material as ShaderMaterial).set_shader_parameter("amount", _stasis_strength)
	if "unbuffered" in player.health and player.health.get("unbuffered"):
		vitals.delayed_health = player.health.health
		vitals._trail.reset(player.health.health)


func _damaged(amount: float, _part: Hitbox.BodyPart, source: Node) -> void:
	if stage.player.health.last_damage_context.get("environmental_penalty", false):
		_fall_notice.text = "坠落 -%d 生命  ·  已返回安全平台" % int(amount)
		_fall_notice_left = 2.5
	if source is Node3D and stage.player.realm_effects.warnings_enabled:
		damage_indicator.add_hit(source, amount)


func _on_wave_spawned(_stage: RealmStage, wave_index: int, total_waves: int) -> void:
	if wave_index <= 1:
		return
	_wave_notice.text = "增援抵达 · 第 %d/%d 波" % [wave_index, total_waves]
	_wave_notice_left = 2.2


func _apply_settings() -> void:
	crosshair.style = settings.crosshair_style
	crosshair.line_length = 5 * settings.crosshair_size
	crosshair.thickness = settings.crosshair_thickness
	crosshair.color = Color(settings.crosshair_color, settings.crosshair_alpha)
	stage.player.set_look_sensitivity(_base_sensitivity * settings.mouse_sensitivity, settings.ads_sensitivity)
	KeyBindings.apply(settings.bindings)
	if _tab_badge != null:
		_tab_badge.text = KeyHint.of("inspect_build")


## 沉睡共鸣（Q）的"子弹时间"观感。components 只发信号，屏幕效果归 UI 层。
func _on_fragment_activated(realm: int) -> void:
	if realm != PsycheFragments.SLOTH:
		return
	if not is_instance_valid(_time_warp):
		_time_warp = SlumberTimeWarp.new()
		_time_warp.name = "SlumberTimeWarp"
		add_child(_time_warp)
	_time_warp.play(3.0)


func _refresh_boons() -> void:
	var names: PackedStringArray = []
	for card in stage.player.boons.all_equipped():
		names.append(card.name)
	_boons.text = "%s 心智矩阵\n%s" % [KeyHint.of("inspect_build"), "\n".join(names)]

	for i in mini(_slot_badges.size(), stage.player.boons.slots.size()):
		var badge := _slot_badges[i]
		var card: BoonData = stage.player.boons.slots[i].data
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

	var trait_count := stage.player.boons.traits.size()
	_trait_count_badge.visible = trait_count > 0
	if trait_count > 0:
		_trait_count_badge.text = "+%d" % trait_count
