extends CanvasLayer
## Health, ammo, crosshair and hit feedback for the player in the scene.
## UI may read actors (see ARCHITECTURE.md); actors never read the UI.

const HIT_BODY := preload("res://assets/audio/hit_body.ogg")
const HIT_HEAD := preload("res://assets/audio/hit_head.ogg")

var _player: Player
var _director: ZoneDirector

@onready var _crosshair: Control = $Crosshair
@onready var _hitmarker: Label = $Hitmarker
@onready var _health_label: Label = $Health
@onready var _ammo_label: Label = $Ammo
@onready var _audio: AudioStreamPlayer = $HitAudio
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _zone_label: Label = $Top/Zone
@onready var _objective_label: Label = $Top/Objective
@onready var _capture_bar: ProgressBar = $Top/Capture
@onready var _buffs_label: Label = $Buffs
@onready var _strike_bar: StrikeBar = $StrikeBar
@onready var _debug: CaptureDebug = $CaptureDebug


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_player.weapon.ammo_changed.connect(_on_ammo_changed)
	_player.weapon.reload_started.connect(func(_t): _ammo_label.text = "换弹中…")
	_player.weapon.hit_landed.connect(_on_hit_landed)
	_player.health.damaged.connect(_on_player_damaged)
	_on_ammo_changed(_player.weapon.ammo, _player.weapon.reserve)

	_director = get_tree().get_first_node_in_group("zone_director") as ZoneDirector
	_zone_label.text = "战区 %d / %d" % [_director.zone_index + 1, RunState.ZONE_SCENES.size()]
	_director.objective_changed.connect(_on_objective_changed)
	_director.phase_changed.connect(_on_phase_changed)
	_director.enemies_changed.connect(_on_enemies_changed)
	_strike_bar.setup(_director.capture_point)
	_debug.setup(_director)
	_director.capture_point.progress_changed.connect(func(p: float): _capture_bar.value = p * 100.0)
	_objective_label.text = _director.objective
	_on_enemies_changed(_director.enemies_total, _director.enemies_total)
	_capture_bar.visible = _director.phase != ZoneDirector.Phase.CLEAR_GUARDS
	var titles: PackedStringArray = []
	for buff: Buff in RunState.buffs:
		titles.append(buff.title)
	_buffs_label.text = "增益：" + "、".join(titles) if not titles.is_empty() else ""


func _process(_delta: float) -> void:
	var health := _player.health
	_health_label.text = "生命 %d / %d" % [ceili(health.health), ceili(health.max_health)]
	# Project the spread angle onto the screen so the gap matches where bullets can land.
	var camera := get_viewport().get_camera_3d()
	var half_height := get_viewport().get_visible_rect().size.y * 0.5
	var spread := deg_to_rad(_player.weapon.spread_degrees())
	_crosshair.gap = 4.0 + half_height * tan(spread) / tan(deg_to_rad(camera.fov) * 0.5)
	_crosshair.visible = not _player.is_aiming()
	_crosshair.queue_redraw()


func _on_ammo_changed(current: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [current, reserve]


func _on_hit_landed(headshot: bool, killed: bool) -> void:
	_hitmarker.modulate = Color(1, 0.25, 0.2) if killed else (Color(1, 0.85, 0.3) if headshot else Color.WHITE)
	_hitmarker.scale = Vector2.ONE * (1.4 if killed else 1.0)
	var tween := create_tween()
	tween.tween_property(_hitmarker, "modulate:a", 0.0, 0.25).from(1.0)
	_audio.stream = HIT_HEAD if headshot else HIT_BODY
	_audio.play()


func _on_player_damaged(amount: float, _part: Hitbox.BodyPart, _source: Node) -> void:
	var tween := create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.4).from(clampf(amount / 40.0, 0.15, 0.45))


func _on_enemies_changed(alive: int, total: int) -> void:
	if alive > 0 and _director.phase == ZoneDirector.Phase.CLEAR_GUARDS:
		_objective_label.text = "消灭所有敌人（剩余 %d / %d）" % [alive, total]


func _on_objective_changed(text: String) -> void:
	_objective_label.text = text


func _on_phase_changed(phase: ZoneDirector.Phase) -> void:
	_capture_bar.visible = phase != ZoneDirector.Phase.CLEAR_GUARDS
