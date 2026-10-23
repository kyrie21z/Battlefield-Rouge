extends CanvasLayer
## Health, ammo, crosshair and hit feedback for the player in the scene.
## UI may read actors (see ARCHITECTURE.md); actors never read the UI.

const HIT_BODY := preload("res://assets/audio/hit_body.ogg")
const HIT_HEAD := preload("res://assets/audio/hit_head.ogg")

var _player: Player

@onready var _crosshair: Control = $Crosshair
@onready var _hitmarker: Label = $Hitmarker
@onready var _health_label: Label = $Health
@onready var _ammo_label: Label = $Ammo
@onready var _audio: AudioStreamPlayer = $HitAudio


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_player.weapon.ammo_changed.connect(_on_ammo_changed)
	_player.weapon.reload_started.connect(func(_t): _ammo_label.text = "换弹中…")
	_player.weapon.hit_landed.connect(_on_hit_landed)
	_on_ammo_changed(_player.weapon.ammo, _player.weapon.reserve)


func _process(_delta: float) -> void:
	var health := _player.health
	_health_label.text = "生命 %d / %d" % [ceili(health.health), ceili(health.max_health)]
	# Spread in degrees to pixels at the current FOV.
	var camera := get_viewport().get_camera_3d()
	var px_per_deg := get_viewport().get_visible_rect().size.y / camera.fov
	_crosshair.gap = 4.0 + _player.weapon.spread_degrees() * px_per_deg
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
