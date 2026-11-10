class_name FearEdgeWarning
extends CanvasLayer
## Edge-only cues for otherwise unseen gunshots; centre aim remains readable.

class Edges extends Control:
	var cues: Array[Dictionary] = []

	func _draw() -> void:
		for cue in cues:
			var direction: Vector2 = cue.direction
			var half := size * 0.5 - Vector2(18, 18)
			var scale_to_edge := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
			var center := size * 0.5 + direction * scale_to_edge
			var tangent := Vector2(-direction.y, direction.x) * 42.0
			var color := PanicFlawStatus.COLOR.lightened(0.22)
			color.a = clampf(float(cue.left) / 0.25, 0.0, 1.0)
			draw_line(center - tangent, center + tangent, Color(color, color.a * 0.2), 24.0, true)
			draw_line(center - tangent, center + tangent, color, 5.0, true)
			draw_colored_polygon(PackedVector2Array([center - direction * 18.0, center + tangent * 0.23, center - tangent * 0.23]), color)

var edges: Edges


func _ready() -> void:
	layer = 18
	edges = Edges.new()
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edges)
	_resize()
	get_viewport().size_changed.connect(_resize)


func _resize() -> void:
	edges.position = Vector2.ZERO
	edges.size = get_viewport().get_visible_rect().size
	edges.queue_redraw()


func warn(camera: Camera3D, point: Vector3) -> void:
	var local := camera.to_local(point)
	var direction := Vector2(local.x, -local.y)
	if direction.length_squared() < 0.001:
		direction = Vector2(0, 1)
	edges.cues.append({"direction": direction.normalized(), "left": 0.8})
	if edges.cues.size() > 8:
		edges.cues.pop_front()
	edges.queue_redraw()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	for cue in edges.cues:
		cue.left -= delta
	edges.cues = edges.cues.filter(func(cue: Dictionary) -> bool: return cue.left > 0.0)
	edges.queue_redraw()
