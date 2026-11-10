class_name ObsidianPistolView
extends Node3D
## Four flat-shaded Blender mineral meshes, each with its own local pivot.
## Source: 120 authored triangles/quads; imported GLB: 180 rendering triangles.
## The weapon supplies the clock, so snap and magazine completion agree.

const SOURCE_POLYGONS := 120
const BODY_TRIANGLES := 180
const BLOOM_END := 0.35 / 0.85
const FLOAT_END := 0.65 / 0.85
const OFFSETS := [Vector3(0, 0.07, -0.08), Vector3(0.08, 0.04, 0.02),
	Vector3(0.025, -0.09, 0.025), Vector3(-0.055, 0.035, 0)]

var _pieces: Array[Node3D] = []
var _rest: Array[Transform3D] = []
var _core_material: StandardMaterial3D
var _dust: Array[MeshInstance3D] = []
var reassembly_progress := 1.0


func _ready() -> void:
	for piece_name in ["barrel_block", "slide_block", "grip_block", "core_crystal"]:
		var piece := $Model.find_child(piece_name, true, false) as MeshInstance3D
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pieces.append(piece)
		_rest.append(piece.transform)
	var core := $Model.find_child("core_crystal", true, false) as MeshInstance3D
	_core_material = core.get_active_material(0).duplicate() as StandardMaterial3D
	core.material_override = _core_material
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.015, 0.02, 0.025)
	var shard := PrismMesh.new()
	shard.size = Vector3(0.009, 0.015, 0.008)
	for i in 6:
		var bit := MeshInstance3D.new()
		bit.mesh = shard
		bit.material_override = dust_material
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bit.visible = false
		add_child(bit)
		_dust.append(bit)


func set_reassembly_progress(progress: float) -> void:
	reassembly_progress = clampf(progress, 0.0, 1.0)
	var p := reassembly_progress
	var bloom := smoothstep(0.0, BLOOM_END, p)
	if p > FLOAT_END:
		var snap := (p - FLOAT_END) / (1.0 - FLOAT_END)
		bloom = 1.0 - snap * snap * snap
	if p >= 1.0:
		bloom = 0.0
	for i in _pieces.size():
		var piece := _pieces[i]
		piece.transform = _rest[i]
		piece.position += OFFSETS[i] * bloom
		piece.rotation += Vector3(0.07, 0.09, 0.13) * (1.0 if i % 2 == 0 else -1.0) * bloom
		if i == 3:
			piece.position.y += sin(p * 160.0) * 0.002 * bloom
	if _core_material != null:
		_core_material.emission_energy_multiplier = 1.5 + bloom * (1.5 + 0.4 * sin(p * 160.0))
	for i in _dust.size():
		var bit := _dust[i]
		bit.visible = p >= BLOOM_END and p < FLOAT_END
		var phase := fposmod((p - BLOOM_END) / (FLOAT_END - BLOOM_END) + float(i) / 6.0, 1.0)
		var angle := float(i) * TAU / 6.0
		bit.position = Vector3(cos(angle), sin(angle), -0.2) * (0.2 * (1.0 - phase)) + Vector3(0, 0, -0.08)
