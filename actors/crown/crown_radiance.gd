class_name CrownRadiance
extends Node3D
## A visible crown and peripheral bloom; later dialogue may compose this node.
var strength := 0.5
var level := 0
var material: StandardMaterial3D
var glow: OmniLight3D
var edge: ColorRect
const EDGE := "shader_type canvas_item; uniform float power=0.0; void fragment(){vec2 p=abs(UV-vec2(0.5))*2.0; float rim=pow(max(p.x,p.y),8.0); COLOR=vec4(1.0,0.91,0.65,rim*power); }"
func _ready()->void:
	material=StandardMaterial3D.new()
	material.albedo_color=Color("f2e9ce")
	material.metallic=0.65
	material.roughness=0.16
	material.emission_enabled=true
	material.emission=Color("ffe5a6")
	var band:=MeshInstance3D.new()
	var ring:=TorusMesh.new()
	ring.inner_radius=0.14
	ring.outer_radius=0.19
	ring.rings=12
	ring.ring_segments=4
	band.mesh=ring
	band.material_override=material
	add_child(band)
	for index in 6:
		var tip:=MeshInstance3D.new()
		var prism:=PrismMesh.new()
		prism.size=Vector3(0.055,0.13,0.035)
		tip.mesh=prism
		tip.position=Vector3(sin(index*TAU/6.0)*0.16,0.07,cos(index*TAU/6.0)*0.16)
		tip.rotation.y=index*TAU/6.0
		tip.material_override=material
		add_child(tip)
	glow=OmniLight3D.new()
	glow.omni_range=2.0
	glow.light_color=Color("fff1c5")
	add_child(glow)
	var overlay:=CanvasLayer.new()
	overlay.layer=7
	add_child(overlay)
	edge=ColorRect.new()
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code=EDGE
	var shader_material:=ShaderMaterial.new()
	shader_material.shader=shader
	edge.material=shader_material
	overlay.add_child(edge)
	Events.sin_defeated.connect(set_fracture_level)
	set_fracture_level(level)

func set_fracture_level(value:int)->void:
	level=clampi(value,0,4)
	strength=0.5*pow(2.4,level)
	if material==null:return
	material.emission_energy_multiplier=strength
	glow.light_energy=minf(strength*0.15,2.5)
	(edge.material as ShaderMaterial).set_shader_parameter("power",0.015+0.35*pow(float(level)/4.0,2.0))
