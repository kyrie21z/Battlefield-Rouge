class_name DoorRewardMarker
extends Node3D
## Reward identity is injected by the zone. No run-state access in the marker.

enum Reward { SLOTH, FEAR, WRATH, SORROW, RESONANCE, VITALITY, SHOP }
const EXTRA_ICONS: Array[Texture2D] = [
	preload("res://assets/ui/boons/resonance.svg"),
	preload("res://assets/ui/boons/vitality.svg"), preload("res://assets/ui/boons/shop.svg"),
]
const TITLES: Array[String] = ["怠惰赐福", "恐惧赐福", "暴怒赐福", "悲伤赐福", "心智共振 · 升级 +1", "意志扩容 · 生命上限 +25", "心象商店 · 货币购物"]
@export var reward: Reward = Reward.SLOTH:
	set(value):
		reward = value
		if is_node_ready():
			_refresh()
@export var hint := "按 F 领取门扉馈赠"
@export var show_frame := false
var _age := 0.0
var _icon: Sprite3D
var _title: Label3D


func _ready() -> void:
	_icon = Sprite3D.new()
	_icon.name = "Sigil"
	_icon.pixel_size = 0.008
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = false
	add_child(_icon)
	_title = Label3D.new()
	_title.name = "RewardLabel"
	_title.font_size = 40
	_title.pixel_size = 0.006
	_title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title.outline_size = 10
	_title.position.y = -0.8
	add_child(_title)
	_refresh()
	if show_frame:
		_build_frame()


func _refresh() -> void:
	_icon.texture = BoonIdentity.ICONS[reward] if reward < 4 else EXTRA_ICONS[reward - 4]
	_title.text = TITLES[reward] + "\n" + hint
	_title.modulate = BoonIdentity.COLORS[reward] if reward < 4 else Color("eddfb7")


func _process(delta: float) -> void:
	_age += delta
	_icon.position.y = sin(_age * 1.7) * 0.09
	_icon.modulate.a = 0.88 + sin(_age * 2.0) * 0.12


func _build_frame() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("151821")
	material.roughness = 0.25
	material.metallic = 0.35
	var accent := StandardMaterial3D.new()
	accent.albedo_color = BoonIdentity.COLORS[reward] if reward < 4 else Color("eddfb7")
	accent.emission_enabled = true
	accent.emission = accent.albedo_color
	accent.emission_energy_multiplier = 0.7
	for side in [-1.0, 1.0]:
		_frame_piece(Vector3(side * 1.2, -1.0, 0.12), Vector3(0.18, 2.8, 0.28), material)
		_frame_piece(Vector3(side * 1.09, -1.0, 0.0), Vector3(0.025, 2.65, 0.035), accent)
	_frame_piece(Vector3(0, 0.43, 0.12), Vector3(2.6, 0.16, 0.28), material)


func _frame_piece(origin: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = origin
	add_child(instance)
