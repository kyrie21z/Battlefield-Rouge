extends CanvasLayer
## Health, ammo, crosshair and hit feedback for the player in the scene.
## UI may read actors (see ARCHITECTURE.md); actors never read the UI.

const HIT_BODY := preload("res://assets/audio/hit_body.ogg")
const HIT_HEAD := preload("res://assets/audio/hit_head.ogg")

## A kill freezes the game for this many real seconds (see HitStop).
const KILL_HITSTOP := 0.05

var _player: Player
var _director: ZoneDirector
var _hit_tween: Tween
## Kill thud and headshot tink play beside the ogg hit sound on their own
## players, so layering them never cuts the ogg.
var _kill_audio: AudioStreamPlayer
var _tink_audio: AudioStreamPlayer

@onready var _crosshair: Control = $Crosshair
@onready var _scope: Control = $Scope
@onready var _reticle: ScopeReticle = $Scope/Reticle
@onready var _hitmarker: Label = $Hitmarker
@onready var _vitals: Vitals = $Vitals
@onready var _weapon_panel: WeaponPanel = $WeaponPanel
@onready var _shield_slot: AbilitySlot = $AbilityBar/Shield
@onready var _melee_slot: AbilitySlot = $AbilityBar/Melee
@onready var _magazine_slot: AbilitySlot = $AbilityBar/Magazine
@onready var _audio: AudioStreamPlayer = $HitAudio
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _objectives: ObjectivePanel = $Top
@onready var _boss_health: BossHealth = $BossHealth
@onready var _markers: Control = $WorldMarkers
@onready var _buffs: BuffBar = $BuffBar
@onready var _combat_feedback: Label = $CombatFeedback
@onready var _strike_bar: StrikeBar = $StrikeBar
@onready var _debug: CaptureDebug = $CaptureDebug


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_kill_audio = AudioStreamPlayer.new()
	_kill_audio.stream = ProceduralAudio.generate("hit_kill")
	_kill_audio.volume_db = -2.0
	add_child(_kill_audio)
	_tink_audio = AudioStreamPlayer.new()
	_tink_audio.stream = ProceduralAudio.generate("hit_tink")
	_tink_audio.volume_db = -7.0
	add_child(_tink_audio)
	_player.weapon.hit_landed.connect(_on_hit_landed)
	_player.weapon.zoom_changed.connect(_on_zoom_changed)
	_player.melee.hit_landed.connect(_on_hit_landed)
	_player.health.damaged.connect(_on_player_damaged)
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
	_strike_bar.setup(_director.capture_point)
	_debug.setup(_director)
	RunState.changed.connect(_refresh_buffs)
	_refresh_buffs()
	_place_buffs()
	_refresh_combat_feedback()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	for marker: WorldMarker in _markers.get_children():
		marker.refresh()
	(_markers.get_node("Capture") as WorldMarker).avoid(_markers.get_node("Boss") as WorldMarker)
	_place_buffs()
	_refresh_combat_feedback()
	# Project the spread angle onto the screen so the gap matches where bullets can land.
	var camera := get_viewport().get_camera_3d()
	var half_height := get_viewport().get_visible_rect().size.y * 0.5
	var spread := deg_to_rad(_player.weapon.spread_degrees())
	_crosshair.gap = 4.0 + half_height * tan(spread) / tan(deg_to_rad(camera.fov) * 0.5)
	_crosshair.visible = not _player.is_aiming()
	_crosshair.queue_redraw()

	# Sniper scope: the gun hides itself behind the glass, the overlay takes over
	# and has to be redrawn whenever the magnification changes.
	var scoped := _player.weapon.is_scoped()
	if _scope.visible != scoped:
		_scope.visible = scoped
	if scoped:
		_reticle.zoom = _player.weapon.zoom_level()
		_reticle.queue_redraw()


func _on_zoom_changed(level: float) -> void:
	_reticle.zoom = level
	_reticle.queue_redraw()


func _on_hit_landed(headshot: bool, killed: bool) -> void:
	_hitmarker.modulate = Color(1, 0.2, 0.15) if killed else (Color(1, 0.85, 0.3) if headshot else Color.WHITE)
	# Pop big, then settle: a kill ends bigger and holds longer than a plain hit.
	var pop := 2.3 if killed else (1.7 if headshot else 1.45)
	var rest := 1.5 if killed else 1.0
	_hitmarker.scale = Vector2.ONE * pop
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(_hitmarker, "scale", Vector2.ONE * rest, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.parallel().tween_property(_hitmarker, "modulate:a", 0.0, 0.5 if killed else 0.25) \
		.from(1.0).set_delay(0.08 if killed else 0.0)
	_audio.stream = HIT_HEAD if headshot else HIT_BODY
	_audio.play()
	if headshot:
		_tink_audio.play()
	if killed:
		_kill_audio.play()
		# A fixture has to replay identically, so it never takes a hitstop.
		if RunState.fixture == null and not get_tree().paused:
			HitStop.request(get_tree(), KILL_HITSTOP)


func _on_player_damaged(amount: float, _part: Hitbox.BodyPart, _source: Node) -> void:
	var tween := create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.4).from(clampf(amount / 40.0, 0.15, 0.45))


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
