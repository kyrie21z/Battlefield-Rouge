class_name WrathSpireVisual
extends WrathVisual
var storm_rings: Array[Node3D] = []
var speed_factor := 1.0

func _build() -> void:
	if _built:
		return
	kind = 2
	super._build()
	model.scale = Vector3.ONE * 2.6
	model.hide()
	_outfit.hide()
	for level in 3:
		var ring := Node3D.new()
		ring.name = "LimbVortex%d" % level
		ring.position.y = 0.8 + level * 1.45
		add_child(ring)
		storm_rings.append(ring)
		for i in 4:
			var angle := i * TAU / 4.0 + level * 0.35
			var body := BODY.instantiate() as Node3D
			body.position = Vector3(sin(angle), 0, cos(angle)) * [2.0, 1.0, 0.24][level]
			body.rotation = Vector3(0, angle + PI * 0.5, PI * 0.5)
			body.scale = Vector3.ONE * [1.25, 0.85, 0.42][level]
			ring.add_child(body)
			for child in body.find_children("*", "AnimationPlayer", true, false):
				(child as AnimationPlayer).stop()
				child.process_mode = Node.PROCESS_MODE_DISABLED
			for child in body.find_children("*", "MeshInstance3D", true, false):
				var piece := child as MeshInstance3D
				var part := String(piece.name).to_lower()
				piece.visible = "arm" in part or "shin" in part or "thigh" in part
				piece.material_override = _crystal
			var blade := CylinderMesh.new()
			blade.top_radius = 0.0
			blade.bottom_radius = 0.2
			blade.height = [2.2, 1.5, 0.75][level]
			blade.radial_segments = 3
			var edge := MeshInstance3D.new()
			edge.mesh = blade
			edge.material_override = _metal
			edge.position = Vector3(sin(angle), 0.05, cos(angle)) * [2.5, 1.25, 0.42][level]
			edge.rotation = Vector3(PI * 0.5, angle, PI * 0.25)
			ring.add_child(edge)
	var spine := CylinderMesh.new()
	spine.top_radius = 0.0
	spine.bottom_radius = 0.45
	spine.height = 5.0
	spine.radial_segments = 4
	var core := MeshInstance3D.new()
	core.mesh = spine
	core.material_override = _dark
	core.position.y = 2.5
	add_child(core)
	_outfit = core

func _process(delta: float) -> void:
	super._process(delta)
	if _dead:
		return
	var actor := get_parent() as Enemy
	if actor != null:
		delta *= actor.boon_time_scale
		if actor.boon_stunned:
			return
	for i in storm_rings.size():
		storm_rings[i].rotation.y += delta * speed_factor * (0.8 + i * 0.45) * (-1.0 if i % 2 else 1.0)

func die(point := Vector3.INF, direction := Vector3.FORWARD) -> void:
	super.die(point, direction)
	for ring in storm_rings:
		ring.hide()
