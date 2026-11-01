extends Control
## Painted cel atlas, kept inside a padded transparent render surface.
const ATLAS = preload("res://ui/pride_opening/assets/pride-atlas.png")
var pose: String = "waiting"
var speaking: bool = false
var motion_enabled: bool = true
var clock: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if motion_enabled:
		clock += delta
	queue_redraw()

func _draw() -> void:
	var cell := 4
	match pose:
		"greeting": cell = 0 if int(clock * 2.5) % 2 == 0 else 1
		"explaining": cell = 2
		"encouraging": cell = 3
		"waiting": cell = 4 if not speaking else 5
	var source := Rect2((cell % 2) * 512, (cell / 2) * 512, 512, 512)
	# The sheet has complete silhouettes. Additional outer padding protects the
	# gloves from viewport clipping, including the larger raised wave frame.
	var edge := minf(size.x, size.y) * 0.86
	var target := Rect2((size - Vector2.ONE * edge) / 2.0, Vector2.ONE * edge)
	draw_texture_rect_region(ATLAS, target, source)
