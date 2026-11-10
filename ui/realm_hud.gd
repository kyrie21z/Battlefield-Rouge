class_name RealmHUD
extends CanvasLayer
## Reads the injected stage/player. Reuses the existing aiming, vitals and pause UI.
var stage: RealmStage
var settings: GameSettings
var vitals: Vitals
var crosshair: Crosshair
var damage_indicator: DamageIndicator
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
	stage.player.boons.changed.connect(_refresh_boons)
	_refresh_boons()

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
	_boons.text = "\n".join(names)
