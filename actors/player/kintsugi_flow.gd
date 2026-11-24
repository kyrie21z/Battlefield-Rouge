class_name KintsugiFlow
extends Node
## Owned by the same body as the authored geometry, outlives the reassembly.
var materials: Array[ShaderMaterial] = []
var crown: CrownVoiceSystem
var reduced_motion := false
var visual_time := 0.0

static func attach(body: ProtagonistBody, colors: Array, source: CrownVoiceSystem = null) -> KintsugiFlow:
	body.set_fracture_level(0)
	var fracture := body.fracture as BodyFracture
	var old_flow := body.get_node_or_null("KintsugiFlow")
	if old_flow != null:
		body.remove_child(old_flow)
		old_flow.queue_free()
	var flow := KintsugiFlow.new()
	flow.name = "KintsugiFlow"
	flow.crown = source
	body.add_child(flow)
	var index := 0
	for entry: Dictionary in fracture.source_meshes.values():
		var material := ShaderMaterial.new()
		material.shader = preload("res://actors/player/shaders/kintsugi_gold.gdshader")
		material.set_shader_parameter("accent", colors[index % colors.size()])
		entry.node.mesh = entry.seam_mesh
		entry.node.material_override = material
		entry.node.material_overlay = null
		flow.materials.append(material)
		index += 1
	flow._process(0.0)
	return flow

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
func _process(delta: float) -> void:
	visual_time += delta
	var reduce := reduced_motion or (is_instance_valid(crown) and crown.reduced_motion)
	for material in materials:
		material.set_shader_parameter("visual_time",visual_time)
		material.set_shader_parameter("reduced_motion",reduce)
