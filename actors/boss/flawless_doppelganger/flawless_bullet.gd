class_name FlawlessBullet
extends Projectile
const CRESCENT_SEGMENTS := 10
const CRESCENT_INNER := 0.34
const CRESCENT_OUTER := 0.56
var crescent := false
func _ready() -> void:
	super._ready()
	if crescent:
		_add_crescent()
func _physics_process(delta: float) -> void:
	if is_instance_valid(source) and source.has_method("tempo_multiplier"):
		delta *= source.call("tempo_multiplier")
	super._physics_process(delta)
func _add_crescent() -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in CRESCENT_SEGMENTS+1:
		var angle := lerpf(-0.85,0.85,float(index)/CRESCENT_SEGMENTS)
		var point := Vector3(sin(angle),cos(angle),0)
		vertices.append(point*CRESCENT_INNER)
		vertices.append(point*CRESCENT_OUTER)
	for index in CRESCENT_SEGMENTS:
		var base := index*2
		indices.append_array([base,base+1,base+2,base+1,base+3,base+2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(tint.r,tint.g,tint.b,0.85)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 3.0
	var arc := MeshInstance3D.new()
	arc.mesh = mesh
	arc.material_override = material
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arc)
