class_name RealmHUD
extends CanvasLayer
## Reads the injected stage/player. Reuses the existing aiming, vitals and pause UI.
var stage: RealmStage
var settings: GameSettings
var vitals: Vitals
var crosshair: Crosshair
var damage_indicator: DamageIndicator
var inspector: BuildInspector
var pause_menu: PauseMenu
var _objective: Label
var _ammo: Label
var _boons: Label
var _boss_bar: ProgressBar
var _boss_name: Label
var _monochrome: ColorRect
var _base_sensitivity := 0.0022
var _root: Control
var _resonance: Label
var _exit_hint: Label
var _death_panel: PanelContainer
var _death_reason: Label
var _fall_notice: Label
var _fall_notice_left := 0.0

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var title := _label(RealmStage.TITLES[stage.realm],23)
	title.position = Vector2(28,24)
	_objective = _label("",18)
	_objective.position = Vector2(28,58)
	vitals = Vitals.new()
	vitals.size = Vector2(344,92)
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.offset_left = 24
	vitals.offset_top = -116
	vitals.offset_right = 368
	vitals.offset_bottom = -24
	_root.add_child(vitals)
	vitals.setup(stage.player)
	_ammo = _label("",26)
	_ammo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo.offset_left = -300
	_ammo.offset_top = -112
	_ammo.offset_right = -24
	_ammo.offset_bottom = -40
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boons = _label("",16)
	_boons.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_boons.offset_left = -340
	_boons.offset_right = -26
	_boons.offset_top = 28
	_boons.offset_bottom = 160
	_boons.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_resonance = _label("",17)
	_resonance.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_resonance.offset_left = -180
	_resonance.offset_right = 180
	_resonance.offset_top = -62
	_resonance.offset_bottom = -28
	_resonance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair = Crosshair.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(crosshair)
	damage_indicator = DamageIndicator.new()
	damage_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(damage_indicator)
	damage_indicator.setup(stage.player)
	stage.player.health.damaged.connect(_damaged)
	BoonHitstop.attach(self, stage.player)
	_boss_name = _label("",19)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_name.offset_left = -250
	_boss_name.offset_right = 250
	_boss_name.offset_top = 25
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = BoonIdentity.COLORS[stage.realm]
	_boss_bar.add_theme_stylebox_override("fill",fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.06,0.06,0.07,0.85)
	_boss_bar.add_theme_stylebox_override("background",background)
	_boss_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.offset_left = -240
	_boss_bar.offset_right = 240
	_boss_bar.offset_top = 55
	_boss_bar.offset_bottom = 67
	_root.add_child(_boss_bar)
	settings = GameSettings.new()
	if DisplayServer.get_name() != "headless":
		settings.load_from(GameSettings.settings_path)
	_base_sensitivity = stage.player.mouse_sensitivity
	settings.changed.connect(_apply_settings)
	_apply_settings()
	pause_menu = PauseMenu.new()
	_root.add_child(pause_menu)
	pause_menu.setup(settings,stage.player,null)
	inspector = preload("res://ui/codex/build_inspector.tscn").instantiate() as BuildInspector
	inspector.player = stage.player
	_root.add_child(inspector)
	stage.player.boons.changed.connect(_refresh_boons)
	_refresh_boons()
	_build_exit_and_death_feedback()

func _build_exit_and_death_feedback() -> void:
	_fall_notice = _label("",22)
	_fall_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fall_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_fall_notice.offset_left = -260
	_fall_notice.offset_right = 260
	_fall_notice.offset_top = 110
	_fall_notice.offset_bottom = 150
	_fall_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fall_notice.hide()
	_exit_hint = _label("",22)
	_exit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_hint.size = Vector2(280,60)
	_exit_hint.hide()
	_death_panel = PanelContainer.new()
	_death_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_panel.offset_left = -240
	_death_panel.offset_right = 240
	_death_panel.offset_top = -100
	_death_panel.offset_bottom = 100
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",20)
	_death_panel.add_child(column)
	_death_reason = Label.new()
	_death_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_reason.add_theme_font_size_override("font_size",28)
	column.add_child(_death_reason)
	var retry_button := Button.new()
	retry_button.text = "重新挑战 · R"
	retry_button.add_theme_font_size_override("font_size",25)
	retry_button.pressed.connect(stage.retry)
	column.add_child(retry_button)
	_root.add_child(_death_panel)
	_death_panel.hide()

func _update_exit_and_death_feedback() -> void:
	_death_panel.visible = stage.fallen
	if stage.fallen:
		var abyss: bool = stage.player.health.last_damage_context.get("tag",&"") == &"abyss"
		_death_reason.text = "心智破碎\n%s" % ("坠入深渊" if abyss else "本次挑战结束")
	_exit_hint.visible = stage.exit_ready and not stage.fallen and not stage.transitioning
	if not _exit_hint.visible:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var target := stage.gate.global_position + Vector3.UP*2.0
	var viewport_size := get_viewport().get_visible_rect().size
	var location := camera.unproject_position(target)
	if camera.is_position_behind(target):
		var side := 1.0 if camera.global_basis.x.dot(target-camera.global_position) >= 0 else -1.0
		location = Vector2(viewport_size.x*0.5+side*(viewport_size.x*0.5-160),viewport_size.y*0.5)
	_exit_hint.position = Vector2(clampf(location.x-140,24,viewport_size.x-304),clampf(location.y-70,96,viewport_size.y-180))
	var distance := stage.player.global_position.distance_to(stage.gate.global_position)
	_exit_hint.text = "下一关门扉 · %.0f 米\n%s" % [distance,"按 %s 进入" % KeyHint.of("interact") if distance <= 3.0 else "朝标记方向前进"]

func _label(text_value: String,font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("f0ebe1"))
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	_root.add_child(label)
	return label

func _process(_delta: float) -> void:
	if not is_instance_valid(stage) or not is_instance_valid(stage.player):
		return
	var player := stage.player
	_fall_notice_left = maxf(0.0,_fall_notice_left-_delta)
	_fall_notice.visible = _fall_notice_left > 0 and not stage.fallen
	_update_exit_and_death_feedback()
	_resonance.visible = player.fragments.has_shard(PsycheFragments.SLOTH)
	_resonance.text = "%s 沉睡共鸣 · %s" % [KeyHint.of("psyche_resonance"),"就绪" if player.fragments.resonance_cooldown<=0 else "%.1f s" % player.fragments.resonance_cooldown]
	_objective.text = stage.objective_text()
	_ammo.text = "%d / %d\n%s" % [player.weapon.ammo,player.weapon.magazine_capacity(),"晶体重组…" if player.weapon.is_reloading() else "黑晶手枪"]
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var half_height := get_viewport().get_visible_rect().size.y*0.5
		crosshair.gap = 2.0+half_height*tan(deg_to_rad(player.weapon.spread_degrees()))/tan(deg_to_rad(camera.fov)*0.5) if settings.dynamic_gap else crosshair.min_gap
	crosshair.visible = not player.health.is_dead() and not is_instance_valid(stage.selection)
	crosshair.show_lines = not player.is_aiming()
	crosshair.focused = player.is_aiming()
	crosshair.queue_redraw()
	damage_indicator.visible = player.realm_effects.warnings_enabled
	_monochrome.visible = player.realm_effects.monochrome > 0
	(_monochrome.material as ShaderMaterial).set_shader_parameter("amount",player.realm_effects.monochrome)
	var boss_live := is_instance_valid(stage.boss) and not stage.boss.health.is_dead()
	_boss_bar.visible = boss_live
	_boss_name.visible = boss_live
	if boss_live:
		_boss_name.text = ["沉眠巨像","审判之瞳","狂暴尖塔","哀泣巨碑"][stage.realm]
		_boss_bar.max_value = stage.boss.health.max_health
		_boss_bar.value = stage.boss.health.health
	if "unbuffered" in player.health and player.health.get("unbuffered"):
		vitals.delayed_health = player.health.health
		vitals._trail.reset(player.health.health)

func _damaged(amount: float,_part: Hitbox.BodyPart,source: Node) -> void:
	if stage.player.health.last_damage_context.get("environmental_penalty",false):
		_fall_notice.text = "坠落 -%d 生命 · 已返回安全平台" % int(amount)
		_fall_notice_left = 2.5
	if source is Node3D and stage.player.realm_effects.warnings_enabled:
		damage_indicator.add_hit(source,amount)

func _apply_settings() -> void:
	crosshair.style = settings.crosshair_style
	crosshair.line_length = 5*settings.crosshair_size
	crosshair.thickness = settings.crosshair_thickness
	crosshair.color = Color(settings.crosshair_color,settings.crosshair_alpha)
	stage.player.set_look_sensitivity(_base_sensitivity*settings.mouse_sensitivity,settings.ads_sensitivity)
	KeyBindings.apply(settings.bindings)

func _refresh_boons() -> void:
	var names: PackedStringArray = []
	for card in stage.player.boons.all_equipped():
		names.append(card.name)
	_boons.text = "%s 心智矩阵\n%s" % [KeyHint.of("inspect_build"),"\n".join(names)]
