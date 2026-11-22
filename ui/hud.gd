extends CanvasLayer
## Health, ammo, crosshair and hit feedback for the player in the scene.
## UI may read actors (see ARCHITECTURE.md); actors never read the UI.

## The crosshair line length at size 1.0; the settings menu scales it.
const CROSSHAIR_LINE_LENGTH := 5.0

## Clock-strike feedback: a kick per strike (bigger for perfect), per quarter break
## and at capture, plus the floating progress text above the crosshair.
const STRIKE_SHAKE := 0.45
const STRIKE_PUNCH := 0.012
const STRIKE_SHAKE_TIME := 0.14
const PERFECT_SHAKE := 0.9
const PERFECT_PUNCH := 0.028
const PERFECT_SHAKE_TIME := 0.22
const PERFECT_HITSTOP := 0.035
const FRACTURE_SHAKE := 0.7
const FRACTURE_SHAKE_TIME := 0.2
const CAPTURE_SHAKE := 1.6
const CAPTURE_PUNCH := 0.04
const CAPTURE_SHAKE_TIME := 0.45
const STRIKE_TEXT_TIME := 0.6
const STRIKE_TEXT_RISE := 30.0
const STRIKE_TEXT_TOP := -196.0
const STRIKE_TEXT_BOTTOM := -156.0
const STRIKE_TEXT_POP := 1.35
const STRIKE_TEXT_GOLD := Color(1.0, 0.82, 0.25)

## Taking a hit: red edge vignette alpha, from the dealt damage, capped so the
## picture never goes fully red, and gone in this many seconds.
const HURT_FLASH_BASE := 0.30
const HURT_FLASH_PER_HP := 2.0
const HURT_FLASH_MAX := 0.90
const HURT_FLASH_DECAY := 0.55
const HURT_MERGE_TIME := CombatFeedbackLayer.HURT_MERGE_TIME
var inspector: BuildInspector
var _player: Player
var _director: ZoneDirector
## Loaded from user://settings.cfg in a normal run; defaults in tests/fixtures.
var settings: GameSettings
## Background music; null under fixtures and headless runs.
var music: MusicDirector
var _base_sensitivity := 0.0
var combat_feedback: CombatFeedbackLayer
var _hurt_pending := 0.0
var _hurt_merge_left := 0.0
var _hurt_flash := 0.0

var _kill_audio: AudioStreamPlayer:
	get: return combat_feedback.kill_audio
var _tink_audio: AudioStreamPlayer:
	get: return combat_feedback.tink_audio
var _heartbeat: AudioStreamPlayer:
	get: return combat_feedback.heartbeat
var hurt_sound_plays: int:
	get: return combat_feedback.hurt_sound_plays
var low_hp: bool:
	get: return combat_feedback.low_hp
var _kill_combo: int:
	get: return combat_feedback.kill_combo
	set(value): combat_feedback.kill_combo = value
var _kill_combo_left: float:
	get: return combat_feedback.kill_combo_left
	set(value): combat_feedback.kill_combo_left = value
var _kill_text_left: float:
	get: return combat_feedback.kill_text_left
	set(value): combat_feedback.kill_text_left = value

## Clock strike text and its rise. For tests.
var _strike_text_left := 0.0
var last_strike_shake := 0.0
## The reinforcement warning is one per zone.
var _reinforcement_banner_shown := false

@onready var _crosshair: Crosshair = $Crosshair
@onready var _hitmarker: Label = $Hitmarker
@onready var _kill_text: Label = $KillText
@onready var _strike_text: Label = $StrikeText
@onready var _vitals: Vitals = $Vitals
@onready var _weapon_panel: WeaponPanel = $WeaponPanel
@onready var _shield_slot: AbilitySlot = $AbilityBar/Shield
@onready var _melee_slot: AbilitySlot = $AbilityBar/Melee
@onready var _magazine_slot: AbilitySlot = $AbilityBar/Magazine
@onready var _audio: AudioStreamPlayer = $HitAudio
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _damage_indicator: DamageIndicator = $DamageIndicator
@onready var _objectives: ObjectivePanel = $Top
@onready var _boss_health: BossHealth = $BossHealth
@onready var _markers: Control = $WorldMarkers
@onready var _minimap: Minimap = $Minimap
@onready var _buffs: BuffBar = $BuffBar
@onready var _combat_feedback: Label = $CombatFeedback
@onready var _strike_bar: StrikeBar = $StrikeBar
@onready var _banner: PhaseBanner = $PhaseBanner
@onready var _pause_menu: PauseMenu = $PauseLayer/PauseMenu
@onready var _debug: CaptureDebug = $CaptureDebug


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_base_sensitivity = _player.mouse_sensitivity
	settings = GameSettings.new()
	if DisplayServer.get_name() != "headless" and RunState.fixture == null:
		settings.load_from(GameSettings.settings_path)
	settings.changed.connect(_apply_settings)
	_apply_settings()
	combat_feedback = CombatFeedbackLayer.new()
	combat_feedback.name = "CombatFeedbackLayer"
	add_child(combat_feedback)
	combat_feedback.setup(_player, {
		"hitmarker": _hitmarker, "kill_text": _kill_text, "hit_audio": _audio,
		"immediate_hurt": true,
	})
	_damage_indicator.setup(_player)
	BoonHitstop.attach(self, _player)
	_player.health.damaged.connect(_on_player_damaged)
	_player.health.died.connect(_on_player_died)
	_vitals.setup(_player)
	_weapon_panel.setup(_player.weapon)
	_shield_slot.setup(_player)
	_melee_slot.setup(_player)
	_magazine_slot.setup(_player)

	_director = get_tree().get_first_node_in_group("zone_director") as ZoneDirector
	_objectives.setup(_director)
	_boss_health.setup(_director.boss if _director.is_boss_zone else null)
	for kind in WorldMarker.Kind.values():
		var marker := WorldMarker.new()
		marker.name = ["Capture", "Pedestal", "Boss"][kind]
		_markers.add_child(marker)
		marker.setup(kind, _director, _player)
	_strike_bar.setup(_director.capture_point, _player.stats)
	_minimap.setup(_director, _player)
	_pause_menu.setup(settings, _player, _director)
	inspector = preload("res://ui/codex/build_inspector.tscn").instantiate() as BuildInspector
	inspector.player = _player
	$PauseLayer.add_child(inspector)
	if MusicDirector.enabled():
		music = MusicDirector.new()
		music.name = "Music"
		add_child(music)
		music.setup(_director)
	# The HUD does not process while paused, so hide the banner here; _process
	# decides again once the menu closes.
	_pause_menu.visibility_changed.connect(func() -> void:
		if _pause_menu.visible:
			_banner.set_hidden(true))
	_director.capture_point.struck.connect(_on_capture_struck)
	_director.capture_point.fractured.connect(_on_capture_fractured)
	_director.capture_point.captured.connect(_on_capture_captured)
	_director.phase_changed.connect(_on_phase_changed)
	_director.reinforcement_spawned.connect(_on_banner_reinforcement)
	# Zones 2 and the boss start their phase before this HUD exists; zone 1 shows
	# its CLEAR_GUARDS prompt when the entry card is chosen and phase_changed fires.
	if _director.phase == ZoneDirector.Phase.CLEAR_GUARDS \
			or _director.phase == ZoneDirector.Phase.BOSS_STANDING:
		_on_phase_changed(_director.phase)
	_debug.setup(_director)
	RunState.changed.connect(_refresh_buffs)
	_refresh_buffs()
	_place_buffs()
	_refresh_combat_feedback()


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	for marker: WorldMarker in _markers.get_children():
		marker.refresh()
	(_markers.get_node("Capture") as WorldMarker).avoid(_markers.get_node("Boss") as WorldMarker)
	_place_buffs()
	_refresh_combat_feedback()
	_update_hurt(delta)
	_update_strike_text(delta)
	# Project the spread angle onto the screen so the gap matches where bullets can land.
	var camera := get_viewport().get_camera_3d()
	var half_height := get_viewport().get_visible_rect().size.y * 0.5
	var spread := deg_to_rad(_player.weapon.spread_degrees())
	var spread_gap := 2.0 + half_height * tan(spread) / tan(deg_to_rad(camera.fov) * 0.5)
	_crosshair.gap = spread_gap if settings.dynamic_gap else _crosshair.min_gap
	_crosshair.visible = true
	_crosshair.show_lines = not _player.is_aiming()
	_crosshair.focused = _player.is_aiming()
	_crosshair.queue_redraw()
	_minimap.visible = not _player.health.is_dead() \
		and _director.phase != ZoneDirector.Phase.BUFF_SELECT
	_banner.set_hidden(_player.health.is_dead() \
		or _director.phase == ZoneDirector.Phase.BUFF_SELECT)


## Pushes the settings into the crosshair and the player's mouse look. The
## player never reads the settings file or any UI class (ARCHITECTURE B9).
func _apply_settings() -> void:
	_crosshair.style = settings.crosshair_style
	_crosshair.line_length = CROSSHAIR_LINE_LENGTH * settings.crosshair_size
	_crosshair.thickness = settings.crosshair_thickness
	_crosshair.color = Color(settings.crosshair_color, settings.crosshair_alpha)
	_player.set_look_sensitivity(_base_sensitivity * settings.mouse_sensitivity, settings.ads_sensitivity)
	# Push the player's key overrides into the InputMap, then show the ability
	# keys from whatever is actually bound now.
	KeyBindings.apply(settings.bindings)
	_shield_slot.key_text = KeyHint.of("shield")
	_melee_slot.key_text = KeyHint.of("melee")
	_magazine_slot.key_text = KeyHint.of("throw_magazine")
	for slot: AbilitySlot in [_shield_slot, _melee_slot, _magazine_slot]:
		slot.queue_redraw()
	_crosshair.queue_redraw()
	var bus := AudioServer.get_bus_index(MusicDirector.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, settings.music_volume <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(settings.music_volume, 0.001)))


func _on_hit_landed(headshot: bool, killed: bool) -> void:
	combat_feedback.on_hit_landed(headshot, killed)


## One blade strike landed: kick the view and float the progress it was worth.
func _on_capture_struck(perfect: bool, _offset_ms: float, worth: float) -> void:
	last_strike_shake = PERFECT_SHAKE if perfect else STRIKE_SHAKE
	_player.add_view_shake(last_strike_shake, PERFECT_PUNCH if perfect else STRIKE_PUNCH,
		PERFECT_SHAKE_TIME if perfect else STRIKE_SHAKE_TIME)
	if perfect and RunState.fixture == null and not get_tree().paused:
		HitStop.request(get_tree(), PERFECT_HITSTOP)
	_show_strike_text(worth, perfect)


## A quarter of the building came off.
func _on_capture_fractured(_stage: int) -> void:
	last_strike_shake = FRACTURE_SHAKE
	_player.add_view_shake(FRACTURE_SHAKE, 0.0, FRACTURE_SHAKE_TIME)


## The clock broke open: the big payoff kick.
func _on_capture_captured() -> void:
	last_strike_shake = CAPTURE_SHAKE
	_player.add_view_shake(CAPTURE_SHAKE, CAPTURE_PUNCH, CAPTURE_SHAKE_TIME)


## Big centre prompt on every phase change. The top-left panel stays the
## persistent reminder; this is the headline for the moment.
func _on_phase_changed(phase: ZoneDirector.Phase) -> void:
	match phase:
		ZoneDirector.Phase.CLEAR_GUARDS:
			_banner.play("战斗开始", "消灭所有守卫，据点才会开放", PhaseBanner.TITLE_WHITE)
		ZoneDirector.Phase.CLOCK_POINT:
			if _director.is_boss_zone:
				_banner.play("砸碎城市核心", "按 %s 挥刃" % KeyHint.of("melee"), PhaseBanner.TITLE_GOLD)
			else:
				_banner.play("据点开放", "前往据点，按 %s 挥刃 · 金色区间是完美打击" % KeyHint.of("melee"), PhaseBanner.TITLE_GOLD)
		ZoneDirector.Phase.FLAG_PLANTED:
			# The boss zone wins straight from the core; only small zones have a
			# pedestal to point at.
			if _director.is_boss_zone:
				_banner.play("核心已击碎", "", PhaseBanner.TITLE_GREEN)
			else:
				_banner.play("据点已占领", "增援撤退 · 到旗旁增益台按 %s 领取增益" % KeyHint.of("interact"), PhaseBanner.TITLE_GREEN)
		ZoneDirector.Phase.BOSS_STANDING:
			_banner.play("Boss 现身", "击倒 Boss，城市核心才会打开", PhaseBanner.TITLE_RED)
		ZoneDirector.Phase.BUFF_SELECT:
			pass


## The first reinforcement of a zone gets a warning. If "据点开放" is still
## young, the warning waits for it instead of cutting it short.
func _on_banner_reinforcement(_position: Vector3) -> void:
	if _director.is_boss_zone or _reinforcement_banner_shown:
		return
	_reinforcement_banner_shown = true
	_banner.play("增援来袭", "守住据点，继续砸", PhaseBanner.TITLE_RED, PhaseBanner.QUEUE_MIN_HOLD)


## "+10%" in white or "+20%" in gold (the strike bar already says 完美打击).
func _show_strike_text(worth: float, perfect: bool) -> void:
	var percent := roundi(worth * 100.0)
	_strike_text.text = "+%d%%" % percent
	_strike_text.add_theme_color_override("font_color", STRIKE_TEXT_GOLD if perfect else Color.WHITE)
	_strike_text.modulate.a = 1.0
	_strike_text.scale = Vector2.ONE * STRIKE_TEXT_POP
	_strike_text.offset_top = STRIKE_TEXT_TOP
	_strike_text.offset_bottom = STRIKE_TEXT_BOTTOM
	_strike_text_left = STRIKE_TEXT_TIME


## Pops, rises and fades on frame delta.
func _update_strike_text(delta: float) -> void:
	if _strike_text_left <= 0.0:
		return
	_strike_text_left = maxf(_strike_text_left - delta, 0.0)
	var t := 1.0 - _strike_text_left / STRIKE_TEXT_TIME
	_strike_text.scale = Vector2.ONE * lerpf(STRIKE_TEXT_POP, 1.0, clampf(t / 0.15, 0.0, 1.0))
	_strike_text.modulate.a = clampf(_strike_text_left / 0.25, 0.0, 1.0)
	var rise := STRIKE_TEXT_RISE * t
	_strike_text.offset_top = STRIKE_TEXT_TOP - rise
	_strike_text.offset_bottom = STRIKE_TEXT_BOTTOM - rise


func _on_player_damaged(amount: float, _part: Hitbox.BodyPart, source: Node) -> void:
	if amount <= 0.0 or get_tree().paused or _player.health.is_dead():
		return
	if _hurt_merge_left <= 0.0:
		_hurt_pending = 0.0
		_hurt_merge_left = HURT_MERGE_TIME
	_hurt_pending += amount
	_raise_hurt_flash()
	# The source may die before the arc fades; the indicator keeps the position.
	if source is Node3D:
		_damage_indicator.add_hit(source as Node3D, amount)


func _update_hurt(delta: float) -> void:
	_hurt_merge_left = maxf(_hurt_merge_left - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta / HURT_FLASH_DECAY, 0.0)
	_damage_flash.color.a = maxf(_hurt_flash, combat_feedback.low_health_alpha)


## The vignette follows the damage of the whole impact so far, never shrinking.
func _raise_hurt_flash() -> void:
	var max_health := maxf(_player.health.max_health, 1.0)
	_hurt_flash = maxf(_hurt_flash, clampf(HURT_FLASH_BASE + HURT_FLASH_PER_HP * _hurt_pending / max_health,
		HURT_FLASH_BASE, HURT_FLASH_MAX))
	_damage_flash.color.a = maxf(_damage_flash.color.a, _hurt_flash)


func _on_player_died(_source: Node) -> void:
	_hurt_pending = 0.0
	_hurt_merge_left = 0.0
	_hurt_flash = 0.0
	_damage_flash.color.a = 0.0


func low_hp_active() -> bool:
	return low_hp


func _refresh_buffs() -> void:
	_buffs.refresh()


func _place_buffs() -> void:
	_buffs.position.y = _objectives.position.y + _objectives.size.y + 10.0


func _refresh_combat_feedback() -> void:
	var traits := _player.combat_traits
	_combat_feedback.visible = traits.feedback_remaining > 0.0 and not traits.feedback.is_empty()
	_combat_feedback.text = traits.feedback
	_combat_feedback.add_theme_color_override("font_color",
		PlayerShield.ACCENT if traits.feedback.contains("护盾") else Color("73f1ff"))
	_combat_feedback.modulate.a = clampf(traits.feedback_remaining / 0.25, 0.0, 1.0)
