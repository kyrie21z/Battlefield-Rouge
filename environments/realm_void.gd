class_name RealmVoid
extends Node3D
## 四领域共用的坠落边界。
##
## 玩家掉出战场：扣固定的 30 点真实生命，并送回上一次站得稳的位置；扣到 0 才死。
## 其它角色（敌人）掉出去：直接死亡——走 environmental_fatal，绕过护盾、无敌与
## 伤害缓冲，因此不会出现"掉下去还活着"的敌人。
##
## 恐惧关有一份等价的内联实现（它要驱动翻转板与深渊视觉，测试也直接读那边
## 的内部状态），这里抽出来给其余三关用，规则完全一致。

signal recovered
signal fatal_fall(body: Node3D)

const FALL_DAMAGE := 30.0
## 安全点复检间隔：每 0.15 秒确认一次脚下是否仍然有稳定支撑。
const SAFE_CHECK_INTERVAL := 0.15

## 相对本节点父级原点的高度线；低于它就算坠落。
@export var fall_height := -12.0
## 兜底体积，盖住这条高度线下方，防止高速下坠穿过。
@export var bounds_size := Vector3(180.0, 8.0, 180.0)
@export var bounds_depth := -16.0
## 找不到可用安全点时退回的位置（几何空间坐标）。
@export var spawn_fallback := Vector3(0.0, 0.0, 16.0)

var player: Player
var _safe_position := Vector3.INF
var _safe_check_left := 0.0
var _recover_pending := false
var _recover_cooldown := 0.0
var abyss: Area3D


func _ready() -> void:
	abyss = Area3D.new()
	abyss.name = "FallVoid"
	abyss.collision_layer = 0
	abyss.collision_mask = CollisionLayers.ACTORS | CollisionLayers.ENEMIES
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds_size
	collision.shape = box
	abyss.add_child(collision)
	abyss.position = Vector3(0.0, bounds_depth, 0.0)
	add_child(abyss)
	abyss.body_entered.connect(_on_body_entered)
	_reset_safe_position()


func setup(value: Player) -> void:
	player = value
	_reset_safe_position()


func safe_position() -> Vector3:
	return _safe_position


func _reset_safe_position() -> void:
	_safe_position = _origin() + spawn_fallback + Vector3.UP * 0.12


func _origin() -> Vector3:
	var parent := get_parent() as Node3D
	return parent.global_position if is_instance_valid(parent) else Vector3.ZERO


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_queue_recovery(body as Player)
		return
	_fatal_fall(body)


func _physics_process(delta: float) -> void:
	_recover_cooldown = maxf(0.0, _recover_cooldown - delta)
	if not is_instance_valid(player) or player.health.is_dead():
		return
	_safe_check_left -= delta
	# 高度线兜底：Area 只报一次进入，快速穿过或从侧面掉出去都还能被抓到。
	if player.global_position.y <= _origin().y + fall_height:
		_queue_recovery(player)
	elif _safe_check_left <= 0.0:
		_safe_check_left = SAFE_CHECK_INTERVAL
		_remember_safe_floor()


func _queue_recovery(value: Player) -> void:
	if _recover_pending or _recover_cooldown > 0.0 or value.health.is_dead():
		return
	_recover_pending = true
	_recover_cooldown = 0.3
	value.cancel_forced_movement()
	_recover_player.call_deferred(weakref(value))


func _recover_player(reference: WeakRef) -> void:
	var value := reference.get_ref() as Player
	if is_instance_valid(value) and not value.health.is_dead():
		var landing := _safe_position
		if landing == Vector3.INF or not _landing_clear(landing):
			landing = _origin() + spawn_fallback + Vector3.UP * 0.12
			for offset in [Vector3.ZERO, Vector3(-2, 0, 0), Vector3(2, 0, 0), Vector3(0, 0, -2),
					Vector3(0, 0, 2), Vector3(-2, 0, -2), Vector3(2, 0, -2), Vector3(-2, 0, 2),
					Vector3(2, 0, 2)]:
				var candidate: Vector3 = _origin() + spawn_fallback + offset + Vector3.UP * 0.12
				if _landing_clear(candidate):
					landing = candidate
					break
		value.recover_from_fall(landing)
		value.health.apply_damage(FALL_DAMAGE, Hitbox.BodyPart.BODY, null,
			{"environmental_penalty": true, "true_damage": true, "tag": &"abyss"})
		recovered.emit()
	_recover_pending = false


## 落点必须踩得住：脚下有 WORLD 支撑且法线朝上，胶囊体积不与世界或敌人重叠。
func _landing_clear(point: Vector3) -> bool:
	var support := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2,
		point - Vector3.UP * 0.5, CollisionLayers.WORLD)
	var ground := get_world_3d().direct_space_state.intersect_ray(support)
	if ground.is_empty() or not ground.collider is StaticBody3D or ground.normal.y < 0.8:
		return false
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point + Vector3.UP * 0.9
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.ENEMIES
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## 只记录整块稳定地面：中心与四个方向都有支撑，避免把平台边缘当成安全点。
func _remember_safe_floor() -> void:
	if not is_instance_valid(player) or not player.is_on_floor():
		return
	for offset in [Vector3.ZERO, Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0),
			Vector3(0, 0, 0.6), Vector3(0, 0, -0.6)]:
		var point: Vector3 = player.global_position + offset
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3,
			point - Vector3.UP * 0.5, CollisionLayers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y < 0.8:
			return
	_safe_position = player.global_position + Vector3.UP * 0.12


func _fatal_fall(body: Node3D) -> void:
	var hp := body.get_node_or_null("Health") as Health
	if hp == null or hp.is_dead():
		return
	hp.apply_damage(hp.max_health + hp.health + hp.shield_points + 1000.0,
		Hitbox.BodyPart.BODY, null,
		{"environmental_fatal": true, "true_damage": true, "tag": &"abyss"})
	fatal_fall.emit(body)
