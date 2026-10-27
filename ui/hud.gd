extends CanvasLayer
## Health, ammo, crosshair and hit feedback for the player in the scene.
## UI may read actors (see ARCHITECTURE.md); actors never read the UI.

const HIT_BODY := preload("res://assets/audio/hit_body.ogg")
const HIT_HEAD := preload("res://assets/audio/hit_head.ogg")

var _player: Player
var _director: ZoneDirector

@onready var _crosshair: Control = $Crosshair
@onready var _scope: Control = $Scope
@onready var _reticle: ScopeReticle = $Scope/Reticle
@onready var _hitmarker: Label = $Hitmarker
@onready var _health_label: Label = $Health
@onready var _ammo_label: Label = $Ammo
@onready var _gun_label: Label = $Gun
@onready var _melee_label: Label = $Melee
@onready var _audio: AudioStreamPlayer = $HitAudio
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _zone_label: Label = $Top/Zone
@onready var _objective_label: Label = $Top/Objective
@onready var _capture_bar: ProgressBar = $Top/Capture
@onready var _boss_label: Label = $Top/BossLabel
@onready var _boss_bar: ProgressBar = $Top/BossBar
@onready var _buffs_label: Label = $Buffs
@onready var _abilities_label: Label = $Abilities
@onready var _combat_feedback: Label = $CombatFeedback
@onready var _strike_bar: StrikeBar = $StrikeBar
@onready var _debug: CaptureDebug = $CaptureDebug


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_player.weapon.ammo_changed.connect(_on_ammo_changed)
	_player.weapon.reload_started.connect(func(_t): _ammo_label.text = "换弹中…")
	_player.weapon.hit_landed.connect(_on_hit_landed)
	_player.weapon.selected.connect(_on_gun_selected)
	_player.weapon.zoom_changed.connect(_on_zoom_changed)
	_on_gun_selected(_player.weapon.index, _player.weapon.data)
	_player.melee.hit_landed.connect(_on_hit_landed)
	_player.melee.selected.connect(_on_melee_selected)
	_on_melee_selected(_player.melee.index, _player.melee.current())
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
	_on_phase_changed(_director.phase)
	if _director.boss != null:
		_director.boss.health.damaged.connect(func(_amount, _part, _source): _refresh_boss())
		_boss_label.visible = true
		_boss_bar.visible = true
		_refresh_boss()
	RunState.changed.connect(_refresh_buffs)
	_refresh_buffs()
	_refresh_abilities()
	_refresh_combat_feedback()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var health := _player.health
	_health_label.text = "生命 %d / %d" % [ceili(health.health), ceili(health.max_health)]
	_refresh_abilities()
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


func _on_ammo_changed(current: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [current, reserve]


func _on_gun_selected(_index: int, data: WeaponData) -> void:
	_gun_label.text = "%s [滚轮切换]" % data.display_name


func _on_melee_selected(_index: int, data: MeleeData) -> void:
	_melee_label.text = "近战 %s [V] · Q 切换" % data.display_name


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


func _refresh_boss() -> void:
	var health := _director.boss.health
	_boss_bar.max_value = health.max_health
	_boss_bar.value = health.health
	_boss_label.text = "Boss 已倒下" if health.is_dead() \
			else "Boss  %d / %d" % [ceili(health.health), ceili(health.max_health)]


func _on_enemies_changed(alive: int, total: int) -> void:
	if alive > 0 and _director.phase == ZoneDirector.Phase.CLEAR_GUARDS:
		_objective_label.text = "消灭所有敌人（剩余 %d / %d）" % [alive, total]


func _on_objective_changed(text: String) -> void:
	_objective_label.text = text


func _on_phase_changed(phase: ZoneDirector.Phase) -> void:
	_capture_bar.visible = phase == ZoneDirector.Phase.HAMMER_POINT or phase == ZoneDirector.Phase.FLAG_PLANTED


func _refresh_buffs() -> void:
	var counts: Dictionary = {}
	var catalog: Dictionary = {}
	for buff: Buff in RunState.buffs:
		var key := String(buff.id) if buff.id != &"" else buff.resource_path + buff.title
		counts[key] = int(counts.get(key, 0)) + 1
		catalog[key] = buff
	var lines: PackedStringArray = []
	lines.append("本局增益 · 已选择 %d 次" % RunState.buffs.size())
	if counts.is_empty():
		lines.append("选择任意流派开始构筑")
	for key: String in counts:
		var buff: Buff = catalog[key]
		lines.append("%s ×%d  ·  %s" % [buff.title, counts[key], buff.stack_summary()])
	_buffs_label.text = "\n".join(lines)


func _refresh_abilities() -> void:
	var shield := _player.shield
	var traits := _player.combat_traits
	var lines: PackedStringArray = []
	var parry_capacity := _player.stats.get_value(Stats.PARRY_CAPACITY)
	if parry_capacity > 0.0:
		lines.append("V  刀具 · 弹反窗口 %.2f 秒" % traits.parry_remaining if traits.parry_remaining > 0.0 \
			else "V  刀具 · 按 V 开启短时弹反")
		lines.append("收藏弹头 %d / %d 发 · 下一枪发射" % [traits.stored_rounds, traits.capacity()])
	else:
		lines.append("V  挥砍 · Q 切换近战")
	var status := "选择技能增益解锁"
	if shield.is_unlocked():
		if shield.is_active():
			status = "生效中 %.1f 秒" % shield.active_remaining
		elif shield.cooldown_remaining > 0.0:
			status = "冷却 %.1f 秒" % shield.cooldown_remaining
		else:
			status = "就绪 · 按 G 施放"
	var pulse_damage := _player.stats.get_value(Stats.SHIELD_PULSE_DAMAGE)
	var shield_title := "反击护盾" if pulse_damage > 0.0 else "战术护盾"
	lines.append("G  %s：%s" % [shield_title, status])
	if pulse_damage > 0.0:
		lines.append("挡伤后到期反击 · 爆发 %d" % roundi(pulse_damage))
	var reload_damage := _player.stats.get_value(Stats.RELOAD_BLAST_DAMAGE)
	if reload_damage > 0.0:
		lines.append("危险弹匣 · 空仓换弹爆炸 %d" % roundi(reload_damage))
	_abilities_label.text = "\n".join(lines)


func _refresh_combat_feedback() -> void:
	var traits := _player.combat_traits
	_combat_feedback.visible = traits.feedback_remaining > 0.0 and not traits.feedback.is_empty()
	_combat_feedback.text = traits.feedback
	_combat_feedback.add_theme_color_override("font_color",
		PlayerShield.ACCENT if traits.feedback.contains("护盾") else Color("73f1ff"))
	_combat_feedback.modulate.a = clampf(traits.feedback_remaining / 0.25, 0.0, 1.0)
