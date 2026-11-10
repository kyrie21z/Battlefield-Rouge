class_name ClimaxCombatHUD
extends CanvasLayer
## The climax composition root injects the player and owns visibility/lifetime.
class ScopedPauseMenu extends PauseMenu:
	func _exit_tree() -> void:
		# Release our own pause while this menu still belongs to the SceneTree.
		# A parent's _exit_tree runs after its children have already detached.
		if is_open():
			close()

var player: Player
var settings: GameSettings
var crosshair: Crosshair
var vitals: Vitals
var ammo: Label
var combat_root: Control
var pause_layer: CanvasLayer
var pause_menu: PauseMenu
var combat_visible := false
var _finished := false
var _base_sensitivity := 0.0022

func setup(value: Player) -> void:
	player = value

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_PAUSABLE
	combat_root = Control.new()
	combat_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combat_root)
	crosshair = Crosshair.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_root.add_child(crosshair)
	vitals = Vitals.new()
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.offset_left = 24
	vitals.offset_top = -116
	vitals.offset_right = 368
	vitals.offset_bottom = -24
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_root.add_child(vitals)
	vitals.setup(player)
	ammo = Label.new()
	ammo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo.offset_left = -320
	ammo.offset_top = -112
	ammo.offset_right = -24
	ammo.offset_bottom = -30
	ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo.add_theme_font_size_override("font_size",26)
	ammo.add_theme_color_override("font_color",Color("f0ebe1"))
	ammo.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95))
	ammo.add_theme_constant_override("shadow_offset_x",2)
	ammo.add_theme_constant_override("shadow_offset_y",2)
	ammo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_root.add_child(ammo)
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
	pause_menu.setup(settings,player,null)
	set_combat_visible(false)

func set_combat_visible(value: bool) -> void:
	combat_visible = value and not _finished
	combat_root.visible = combat_visible and not player.health.is_dead()

func _process(_delta: float) -> void:
	if _finished or not is_instance_valid(player):
		return
	combat_root.visible = combat_visible and not player.health.is_dead()
	if not combat_root.visible:
		return
	ammo.text = "%d / %d\n%s" % [player.weapon.ammo,player.weapon.magazine_capacity(),"晶体重组…" if player.weapon.is_reloading() else "黑晶手枪"]
	var half_height := get_viewport().get_visible_rect().size.y*0.5
	crosshair.gap = 2.0+half_height*tan(deg_to_rad(player.weapon.spread_degrees()))/tan(deg_to_rad(player.view_camera.fov)*0.5) if settings.dynamic_gap else crosshair.min_gap
	crosshair.show_lines = not player.is_aiming()
	crosshair.focused = player.is_aiming()
	crosshair.queue_redraw()

func _apply_settings() -> void:
	crosshair.style = settings.crosshair_style
	crosshair.line_length = 5*settings.crosshair_size
	crosshair.thickness = settings.crosshair_thickness
	crosshair.color = Color(settings.crosshair_color,settings.crosshair_alpha)
	player.set_look_sensitivity(_base_sensitivity*settings.mouse_sensitivity,settings.ads_sensitivity)
	KeyBindings.apply(settings.bindings)
	var bus := AudioServer.get_bus_index(MusicDirector.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus,settings.music_volume <= 0.001)
		AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(settings.music_volume,0.001)))

func finish() -> void:
	_finished = true
	combat_visible = false
	combat_root.hide()
	vitals.set_process(false)
	if is_instance_valid(pause_menu):
		pause_menu.close()
		pause_menu.set_process_input(false)
		pause_menu.set_process_unhandled_input(false)
		pause_menu.queue_free()
	pause_layer.hide()
	set_process(false)
