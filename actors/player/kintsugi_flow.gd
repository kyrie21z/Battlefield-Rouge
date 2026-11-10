class_name KintsugiFlow
extends Node
## Owned by the same body as the authored geometry, outlives the reassembly.
var materials: Array[ShaderMaterial] = []
var crown: CrownVoiceSystem
var visual_time := 0.0
func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
func _process(delta: float) -> void:
	visual_time += delta
	var reduce := is_instance_valid(crown) and crown.reduced_motion
	for material in materials:
		material.set_shader_parameter("visual_time",visual_time)
		material.set_shader_parameter("reduced_motion",reduce)
