class_name CombatTraits
extends Node
## Three small action-changing traits. Buffs only supply Stats modifiers;
## this component connects the player's existing combat actions and feedback.

signal reload_charge_thrown(charge: Node3D)
signal reload_charge_stored
signal rounds_released(count: int)
signal shield_pulsed

const PARRY_WINDOW := 0.24
const BLAST_RADIUS := 6.0
const SHIELD_PULSE_RADIUS := 7.0
const COLLECTED_ROUND_DAMAGE := 18.0

@export var stats: Stats
@export var health: Health
@export var weapon: Weapon
@export var melee: MeleeWeapon
@export var shield: PlayerShield
@export var camera: Camera3D
@export var shooter: CharacterBody3D

var stored_rounds := 0
var parry_remaining := 0.0
var feedback := ""
var feedback_remaining := 0.0
var _reload_charge_stored := false
var _held_magazine: Node3D
var _shield_absorbed := false
var _orbit_time := 0.0
var _orbs: Array[MeshInstance3D] = []
var _audio := AudioStreamPlayer.new()


func _ready() -> void:
	weapon.fired.connect(_on_fired)
	melee.swing_started.connect(_on_swing_started)
	health.parried.connect(_on_parried)
	health.blocked.connect(_on_blocked)
	shield.activated.connect(func(): _shield_absorbed = false)
	shield.expired.connect(_on_shield_expired)
	add_child(_audio)
	_audio.stream = ProceduralAudio.generate("hammer_perfect")
	_audio.volume_db = -10.0
	_held_magazine = ReloadCharge.create_model()
	_held_magazine.name = "HeldReloadCharge"
	_held_magazine.position = Vector3(-0.33, -0.25, -0.55)
	_held_magazine.rotation = Vector3(-0.15, 0.4, -0.2)
	_held_magazine.visible = false
	camera.add_child(_held_magazine)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("73f1ff")
	for index in 5:
		var orb := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.027
		mesh.height = 0.054
		orb.mesh = mesh
		orb.material_override = material
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.visible = false
		camera.add_child(orb)
		_orbs.append(orb)


func capacity() -> int:
	return clampi(roundi(stats.get_value(Stats.PARRY_CAPACITY)), 0, 5)


## Nothing stored or primed should remain visible after the player dies.
func clear() -> void:
	stored_rounds = 0
	_reload_charge_stored = false
	_held_magazine.visible = false
	parry_remaining = 0.0
	health.parrying = false
	_shield_absorbed = false
	feedback = ""
	feedback_remaining = 0.0
	_audio.stop()
	for orb in _orbs:
		orb.visible = false


func _process(delta: float) -> void:
	_held_magazine.visible = _reload_charge_stored and not health.is_dead() and not weapon.is_scoped()
	if Input.is_action_just_pressed("throw_magazine") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_throw_reload_charge()
	parry_remaining = maxf(0.0, parry_remaining - delta)
	feedback_remaining = maxf(0.0, feedback_remaining - delta)
	health.parrying = parry_remaining > 0.0 and not health.is_dead()
	_orbit_time += delta * 2.0
	for index in _orbs.size():
		_orbs[index].visible = index < stored_rounds
		var angle := _orbit_time + float(index) * TAU / maxf(float(stored_rounds), 1.0)
		_orbs[index].position = Vector3(sin(angle) * 0.34, cos(angle) * 0.16 - 0.08, -0.65)


## Only an accepted final shot can grant a charge. No reload callback may
## manufacture one, and an already-held charge is never replaced.
func _store_empty_magazine() -> void:
	if weapon.ammo != 0 or _reload_charge_stored or get_tree().paused or health.is_dead() \
			or stats.get_value(Stats.RELOAD_BLAST_DAMAGE) <= 0.0:
		return
	_reload_charge_stored = true
	_held_magazine.visible = not weapon.is_scoped()
	reload_charge_stored.emit()
	_notify("危险弹匣已储存：按 %s 投出" % KeyHint.of("throw_magazine"))


func has_reload_charge() -> bool:
	return _reload_charge_stored


## The held magazine has no running fuse. Damage is sampled when it is thrown,
## and the inventory is consumed before emitting so repeated input cannot copy it.
func try_throw_reload_charge() -> bool:
	var damage := stats.get_value(Stats.RELOAD_BLAST_DAMAGE)
	if get_tree().paused or not _reload_charge_stored or damage <= 0.0 or health.is_dead():
		return false
	_reload_charge_stored = false
	_held_magazine.visible = false
	var direction := -camera.global_basis.z
	var charge := ReloadCharge.spawn(shooter.get_parent(), _ejection_origin(direction),
		direction, shooter, damage, BLAST_RADIUS)
	reload_charge_thrown.emit(charge)
	_notify("危险弹匣投出！")
	return true


func _on_swing_started(_index: int, _step: int) -> void:
	_on_swung()


func _on_swung() -> void:
	if capacity() == 0 or health.is_dead():
		return
	parry_remaining = PARRY_WINDOW
	health.parrying = true
	_notify("迎击窗口：用刀接住敌方弹丸")


func _on_parried(_amount: float, _source: Node) -> void:
	if stored_rounds < capacity():
		stored_rounds += 1
		_notify("弹反成功：收藏 %d / %d 发，开枪释放" % [stored_rounds, capacity()])
	else:
		_notify("弹反成功：弹头已存满，开枪释放")
	_audio.play()


func _on_fired() -> void:
	if get_tree().paused or health.is_dead():
		return
	# fired runs once after ammo is consumed, before automatic reload starts.
	_store_empty_magazine()
	if stored_rounds == 0:
		return
	var count := stored_rounds
	stored_rounds = 0
	var excluded: Array[RID] = [shooter.get_rid()]
	for hitbox in shooter.find_children("*", "Hitbox", true, false):
		excluded.append((hitbox as Hitbox).get_rid())
	for index in count:
		var yaw := (float(index) - float(count - 1) * 0.5) * 0.035
		var direction := (-camera.global_basis.z).rotated(camera.global_basis.y, yaw)
		Projectile.spawn(shooter.get_parent(), _ejection_origin(direction), direction,
			shooter, COLLECTED_ROUND_DAMAGE * stats.get_value(Stats.MELEE_DAMAGE), 40.0,
			excluded, Color("45e4f5"))
	rounds_released.emit(count)
	_notify("弹头回敬：额外发射 %d 发" % count)


## A visible launch offset must stay on the camera's side of nearby cover.
## Check every direction, including the fan of collected rounds.
func _ejection_origin(direction: Vector3) -> Vector3:
	var origin := camera.global_position + direction * 0.4
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, origin, CollisionLayers.WORLD)
	query.hit_from_inside = true
	var obstruction := shooter.get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty():
		origin = obstruction.position + obstruction.normal * 0.04
	return origin


func _on_blocked(amount: float, _source: Node) -> void:
	if shield.is_active() and amount > 0.0:
		_shield_absorbed = true
		if stats.get_value(Stats.SHIELD_PULSE_DAMAGE) > 0.0:
			_notify("护盾已蓄能：结束时释放反击")


func _on_shield_expired() -> void:
	var damage := stats.get_value(Stats.SHIELD_PULSE_DAMAGE)
	if not _shield_absorbed or damage <= 0.0 or health.is_dead():
		return
	_shield_absorbed = false
	ReloadCharge.blast(shooter.get_parent(), shooter.global_position + Vector3.UP,
		shooter, damage, SHIELD_PULSE_RADIUS, PlayerShield.ACCENT)
	shield.show_counter_pulse()
	shield_pulsed.emit()
	_notify("护盾反击！周围敌人受到冲击")


func _notify(text: String) -> void:
	feedback = text
	feedback_remaining = 1.7
