class_name SorrowMonolithVisual
extends SorrowVisual
var slam := 0.0
func _build() -> void:
	kind = 2
	super._build()
	model.scale = Vector3.ONE*3.5
	model.position.y = -0.9
	for child in model.find_children("*","MeshInstance3D",true,false):
		var label := String(child.name).to_lower()
		if "thigh" in label or "shin" in label:
			child.hide()
	var base := MeshInstance3D.new()
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.18
	crystal.bottom_radius = 0.35
	crystal.height = 0.60
	crystal.radial_segments = 7
	base.mesh = crystal
	base.material_override = _crystal
	base.position.y = 0.50
	_outfit.add_child(base)
	if drops != null:
		drops.position = Vector3(0,4.6,-0.8)
		drops.scale = Vector3.ONE * 2.2
		configure_drops(18, 2.4)
func _process(delta: float) -> void:
	super._process(delta)
	if _dead:
		return
	model.position.y = -0.9
	model.rotation.x = slam*0.16
	_outfit.transform = model.transform
	if drops != null:
		drops.position = model.transform*skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin+Vector3(0,-0.1,-0.18)
