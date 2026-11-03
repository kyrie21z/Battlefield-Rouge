class_name StrikeBar
extends Control
## Timing bar for the hammer. A marker sweeps across once per beat; the gold
## zone in the middle is the perfect window, so swinging while the marker is
## inside it is a perfect strike. Shown only while a swing would count.
## Perfect and ordinary strikes get different feedback here: gold text, a pop
## and a screen flash for a perfect one, plain grey text for an ordinary one.

const BAR_SIZE := Vector2(420.0, 16.0)
const BAR_OFFSET_Y := 110.0
const COLOR_BACK := Color(0, 0, 0, 0.6)
const COLOR_ZONE := Color(1.0, 0.8, 0.2, 0.55)
const COLOR_PERFECT := Color(1.0, 0.8, 0.2)
const COLOR_NORMAL := Color(0.75, 0.78, 0.85)

var _point: CapturePoint
var _flash_tween: Tween

@onready var _hint: Label = $Hint
@onready var _result: Label = $Result
@onready var _flash: ColorRect = $Flash


func setup(point: CapturePoint) -> void:
	_point = point
	point.struck.connect(_on_struck)


func _process(_delta: float) -> void:
	_hint.visible = _active()
	queue_redraw()


func _draw() -> void:
	if not _active():
		return
	var center := size * 0.5 + Vector2(0.0, BAR_OFFSET_Y)
	var bar := Rect2(center - BAR_SIZE * 0.5, BAR_SIZE)
	draw_rect(bar.grow(2.0), COLOR_BACK)
	# The bar spans half a period either side of a hit moment; the gold zone
	# is the configured window around the middle.
	var half_period := CapturePoint.BEAT_PERIOD * 0.5
	var zone_half := BAR_SIZE.x * 0.5 * clampf(_point.config.perfect_window_ms / 1000.0 / half_period, 0.0, 1.0)
	draw_rect(Rect2(center.x - zone_half, bar.position.y, zone_half * 2.0, BAR_SIZE.y), COLOR_ZONE)
	var x := center.x + BAR_SIZE.x * 0.5 * (CapturePoint.beat_offset(_point.beat_time()) / half_period)
	draw_line(Vector2(x, bar.position.y - 4.0), Vector2(x, bar.end.y + 4.0), Color.WHITE, 4.0)


func _active() -> bool:
	return _point != null and not _point.locked and not _point.is_captured() and _point.player_in_reach


## Only the timing verdict: the progress gained floats above the crosshair.
func _on_struck(perfect: bool, offset_ms: float, _worth: float) -> void:
	if perfect:
		_result.text = "完美打击"
	else:
		_result.text = "%s %d ms" % ["偏早" if offset_ms < 0.0 else "偏晚", roundi(absf(offset_ms))]
	_result.add_theme_color_override("font_color", COLOR_PERFECT if perfect else COLOR_NORMAL)
	_result.pivot_offset = _result.size * 0.5
	_result.scale = Vector2.ONE * (1.5 if perfect else 1.0)
	_result.modulate.a = 1.0
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_result, "scale", Vector2.ONE, 0.2)
	_flash_tween.tween_property(_result, "modulate:a", 0.0, 0.5).set_delay(0.6)
	if perfect:
		_flash_tween.tween_property(_flash, "color:a", 0.0, 0.3).from(0.3)
