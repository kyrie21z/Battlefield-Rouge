class_name CombatFeedbackLayer
extends Control

const HIT_BODY := preload("res://assets/audio/hit_body.ogg")
const HIT_HEAD := preload("res://assets/audio/hit_head.ogg")
const BODY_KILL_STOP := 0.05
const HEAD_KILL_STOP := 0.075
const PARRY_STOP := 0.05
const MELEE_HIT_STOP := 0.025
const HIT_PITCH_WINDOW := 1.2
const HIT_PITCH_STEP := 0.03
const HIT_PITCH_CAP := 0.15
const KILL_COMBO_WINDOW := 2.5
const KILL_TEXT_TIME := 0.6
const KILL_TEXT_SCALE := 1.45
const KILL_TEXT_POP_TIME := 0.1
const KILL_TEXT_FADE_TIME := 0.22
const GOLD := Color(1.0, 0.82, 0.25)
const HURT_MERGE_TIME := 0.06
const HURT_HEAVY_FRACTION := 0.20
const LOW_HP_ENTER := 0.30
const LOW_HP_EXIT := 0.35

var hitmarker: Label
var kill_text: Label
var damage_numbers: DamageNumbers
var hit_audio: AudioStreamPlayer
var kill_audio: AudioStreamPlayer
var kill_head_audio: AudioStreamPlayer
var tink_audio: AudioStreamPlayer
var blocked_audio: AudioStreamPlayer
var evaded_audio: AudioStreamPlayer
var hurt_audio: AudioStreamPlayer
var hurt_heavy_audio: AudioStreamPlayer
var heartbeat: AudioStreamPlayer

var kill_combo := 0
var kill_combo_left := 0.0
var kill_text_left := 0.0
var hurt_sound_plays := 0
var low_hp := false
var low_health_alpha := 0.0

var _player: Player
var _enabled := true
var _immediate_hurt := false
var _marker_tween: Tween
var _pitch_boost := 0.0
var _pitch_left := 0.0
var _hurt_pending := 0.0
var _hurt_headshot := false
var _hurt_merge_left := 0.0
var _heartbeat_left := 0.0
var _low_pulse := 0.0


func setup(player: Player, options := {}) -> void:
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_immediate_hurt = options.get("immediate_hurt", false)
	hitmarker = options.get("hitmarker")
	if hitmarker == null:
		hitmarker = _centered_label("Hitmarker", Rect2(-20, -20, 40, 40), 32)
		hitmarker.text = "×"
	kill_text = options.get("kill_text")
	if kill_text == null:
		kill_text = _centered_label("KillText", Rect2(-300, 54, 600, 50), 34)
		kill_text.add_theme_color_override("font_outline_color", Color.BLACK)
		kill_text.add_theme_constant_override("outline_size", 8)
	damage_numbers = DamageNumbers.new()
	add_child(damage_numbers)
	move_child(damage_numbers, 0)
	damage_numbers.setup(player, options.get("room", player.get_parent()))
	hit_audio = options.get("hit_audio")
	if hit_audio == null:
		hit_audio = _voice("HitAudio", HIT_BODY)
	kill_audio = _voice("KillAudio", ProceduralAudio.generate("hit_kill"), -2.0)
	kill_head_audio = _voice("KillHeadAudio", ProceduralAudio.generate("hit_kill_head"), -2.0)
	tink_audio = _voice("TinkAudio", ProceduralAudio.generate("hit_tink"), -7.0)
	blocked_audio = _voice("BlockedAudio", ProceduralAudio.generate("hit_block"), -6.0)
	evaded_audio = _voice("EvadedAudio", ProceduralAudio.generate("melee_swing"), -9.0)
	evaded_audio.pitch_scale = 1.65
	hurt_audio = _voice("HurtAudio", ProceduralAudio.generate("player_hurt"))
	hurt_heavy_audio = _voice("HurtHeavyAudio", ProceduralAudio.generate("player_hurt_heavy"))
	heartbeat = _voice("Heartbeat", ProceduralAudio.generate("heartbeat"), -7.0)
	player.weapon.hit_landed.connect(on_hit_landed)
	player.melee.hit_landed.connect(on_hit_landed.bind(true))
	for emitter: Node in [player.weapon, player.melee]:
		for signal_info in emitter.get_signal_list():
			if signal_info.name == &"hit_blocked":
				var argument_count: int = signal_info.args.size()
				var callback := on_hit_blocked.unbind(argument_count) if argument_count > 0 else on_hit_blocked
				emitter.connect(&"hit_blocked", callback)
			elif signal_info.name == &"hit_evaded":
				var evaded_args: int = signal_info.args.size()
				var evaded_cb := on_hit_evaded.unbind(evaded_args) if evaded_args > 0 else on_hit_evaded
				emitter.connect(&"hit_evaded", evaded_cb)
	Events.blade_parried.connect(_on_blade_parried)
	player.health.damaged.connect(_on_player_damaged)
	player.health.died.connect(_on_player_died)


func _centered_label(node_name: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate.a = 0.0
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = rect.position.x
	label.offset_top = rect.position.y
	label.offset_right = rect.end.x
	label.offset_bottom = rect.end.y
	label.pivot_offset = rect.size * 0.5
	return label


func _voice(node_name: String, stream: AudioStream, volume := 0.0) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.name = node_name
	voice.stream = stream
	voice.volume_db = volume
	add_child(voice)
	return voice


func set_enabled(value: bool) -> void:
	_enabled = value
	set_process(value)
	if is_instance_valid(damage_numbers):
		damage_numbers.set_enabled(value)
	if not value:
		_clear_feedback()


func _can_react() -> bool:
	return _enabled and not get_tree().paused and is_instance_valid(_player) 		and not _player.health.is_dead()


func on_hit_landed(headshot: bool, killed: bool, melee := false) -> void:
	if not _can_react():
		return
	var color := Color(1.0, 0.2, 0.15) if killed else (Color(1.0, 0.85, 0.3) if headshot else Color.WHITE)
	var pop := 2.3 if killed else (1.7 if headshot else 1.45)
	_pop_marker(color, pop, 1.5 if killed else 1.0, 0.5 if killed else 0.25, 0.08 if killed else 0.0)

	_pitch_boost = minf(_pitch_boost + HIT_PITCH_STEP, HIT_PITCH_CAP) if _pitch_left > 0.0 else 0.0
	_pitch_left = HIT_PITCH_WINDOW
	var pitch := 1.0 + _pitch_boost
	hit_audio.stream = HIT_HEAD if headshot else HIT_BODY
	hit_audio.pitch_scale = pitch
	hit_audio.play()
	if headshot:
		tink_audio.pitch_scale = pitch
		tink_audio.play()
	if killed:
		var confirm := kill_head_audio if headshot else kill_audio
		confirm.pitch_scale = pitch
		confirm.play()
		_show_kill_text(headshot)
		_request_hitstop(HEAD_KILL_STOP if headshot else BODY_KILL_STOP)
	elif melee:
		_request_hitstop(MELEE_HIT_STOP)


func on_hit_blocked() -> void:
	if not _can_react():
		return
	_pop_marker(Color(0.57, 0.60, 0.64), 1.25, 1.0, 0.18)
	blocked_audio.play()


func on_hit_evaded() -> void:
	if not _can_react():
		return
	evaded_audio.play()


func _pop_marker(color: Color, pop: float, rest: float, fade: float, hold := 0.0) -> void:
	hitmarker.modulate = color
	hitmarker.scale = Vector2.ONE * pop
	if _marker_tween != null:
		_marker_tween.kill()
	_marker_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_marker_tween.tween_property(hitmarker, "scale", Vector2.ONE * rest, 0.09) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_marker_tween.parallel().tween_property(hitmarker, "modulate:a", 0.0, fade).set_delay(hold)


func _on_blade_parried(_position: Vector3) -> void:
	if _can_react():
		_request_hitstop(PARRY_STOP)


func _request_hitstop(duration: float) -> void:
	if RunState.fixture == null:
		HitStop.request(get_tree(), duration)


func _show_kill_text(headshot: bool) -> void:
	kill_combo = kill_combo + 1 if kill_combo_left > 0.0 else 1
	kill_combo_left = KILL_COMBO_WINDOW
	kill_text_left = KILL_TEXT_TIME
	match kill_combo:
		1: kill_text.text = "爆头击杀" if headshot else "击杀"
		2: kill_text.text = "双杀"
		3: kill_text.text = "三杀"
		_: kill_text.text = "连杀 ×%d" % kill_combo
	kill_text.add_theme_color_override("font_color", GOLD if headshot else Color.WHITE)
	kill_text.modulate.a = 1.0
	kill_text.scale = Vector2.ONE * KILL_TEXT_SCALE


func _process(delta: float) -> void:
	if not _can_react():
		return
	_pitch_left = maxf(_pitch_left - delta, 0.0)
	kill_combo_left = maxf(kill_combo_left - delta, 0.0)
	if kill_combo_left == 0.0:
		kill_combo = 0
	if kill_text_left > 0.0:
		kill_text_left = maxf(kill_text_left - delta, 0.0)
		var pop := minf((KILL_TEXT_TIME - kill_text_left) / KILL_TEXT_POP_TIME, 1.0)
		kill_text.scale = Vector2.ONE * lerpf(KILL_TEXT_SCALE, 1.0, pop)
		kill_text.modulate.a = minf(kill_text_left / KILL_TEXT_FADE_TIME, 1.0)
	if _hurt_merge_left > 0.0:
		_hurt_merge_left = maxf(_hurt_merge_left - delta, 0.0)
		if _hurt_merge_left == 0.0 and not _immediate_hurt:
			_play_hurt_sound(_hurt_pending, _hurt_headshot)
			_hurt_pending = 0.0
			_hurt_headshot = false
	_update_low_health(delta)


func _on_player_damaged(amount: float, part: Hitbox.BodyPart, _source: Node) -> void:
	if amount <= 0.0 or not _can_react():
		return
	var headshot := part == Hitbox.BodyPart.HEAD
	if _hurt_merge_left == 0.0:
		_hurt_merge_left = HURT_MERGE_TIME
		if _immediate_hurt:
			_play_hurt_sound(amount, headshot)
	if not _immediate_hurt:
		_hurt_pending += amount
		_hurt_headshot = _hurt_headshot or headshot


func _play_hurt_sound(amount: float, headshot: bool) -> void:
	var threshold := HURT_HEAVY_FRACTION * maxf(_player.health.max_health, 1.0)
	var voice := hurt_heavy_audio if headshot or amount >= threshold else hurt_audio
	voice.volume_db = lerpf(-5.0, 0.0, minf(amount / threshold, 1.0))
	voice.play()
	hurt_sound_plays += 1


func _update_low_health(delta: float) -> void:
	var health := _player.health
	var fraction := health.health / maxf(health.max_health, 1.0)
	low_hp = fraction <= LOW_HP_EXIT if low_hp else fraction < LOW_HP_ENTER
	if not low_hp:
		_clear_heartbeat()
		return
	var rate := lerpf(1.0, 1.6, clampf((LOW_HP_ENTER - fraction) / LOW_HP_ENTER, 0.0, 1.0))
	_low_pulse += TAU * rate * delta
	_heartbeat_left -= delta
	if _heartbeat_left <= 0.0:
		heartbeat.play()
		_heartbeat_left = 1.0 / rate
	low_health_alpha = 0.35 + 0.20 * (0.5 + 0.5 * sin(_low_pulse))


func _clear_heartbeat() -> void:
	if heartbeat.playing:
		heartbeat.stop()
	low_hp = false
	low_health_alpha = 0.0
	_low_pulse = 0.0
	_heartbeat_left = 0.0


func _on_player_died(_source: Node) -> void:
	_clear_feedback()


func _clear_feedback() -> void:
	_clear_heartbeat()
	for voice: AudioStreamPlayer in [hit_audio, kill_audio, kill_head_audio, tink_audio,
			blocked_audio, evaded_audio, hurt_audio, hurt_heavy_audio]:
		voice.stop()
	if _marker_tween != null:
		_marker_tween.kill()
	if is_instance_valid(damage_numbers):
		damage_numbers.clear()
	hitmarker.modulate.a = 0.0
	hitmarker.scale = Vector2.ONE
	kill_text.modulate.a = 0.0
	kill_text.scale = Vector2.ONE
	kill_text.text = ""
	hit_audio.pitch_scale = 1.0
	kill_combo = 0
	kill_combo_left = 0.0
	kill_text_left = 0.0
	_pitch_boost = 0.0
	_pitch_left = 0.0
	_hurt_pending = 0.0
	_hurt_headshot = false
	_hurt_merge_left = 0.0
