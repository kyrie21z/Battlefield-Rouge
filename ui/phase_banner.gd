class_name PhaseBanner
extends Control
## Big centre-screen prompt for the current objective: a title and a subtitle
## that pop in, hold and fade out. The HUD feeds it on phase changes; a new
## prompt replaces the current one, unless the caller asks for a short queue.
## Purely presentational: it never reads or writes run state.

const TITLE_SIZE := 54
const SUBTITLE_SIZE := 30
const POP_TIME := 0.15
const FADE_TIME := 0.4
const SHOW_TIME := 2.8
## A prompt arriving while the current one is younger than this is queued
## instead of cutting it short (the reinforcement warning uses this).
const QUEUE_MIN_HOLD := 1.2
const POP_SCALE := 1.15
const TITLE_OUTLINE := 8
const SUBTITLE_OUTLINE := 8
const TITLE_WHITE := Color(0.94, 0.97, 1.0)
const TITLE_GOLD := Color(1.0, 0.82, 0.25)
const TITLE_RED := Color(1.0, 0.32, 0.27)
const TITLE_GREEN := Color(0.42, 0.95, 0.55)
const SUBTITLE_COLOR := Color(0.97, 0.98, 1.0)

var _title: Label
var _subtitle: Label
var _active := false
var _hidden := false
var _age := 0.0
## One pending prompt, started when the current one finishes.
var _queued: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = _make_label(TITLE_SIZE, TITLE_OUTLINE)
	_subtitle = _make_label(SUBTITLE_SIZE, SUBTITLE_OUTLINE)
	_subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	box.add_child(_title)
	box.add_child(_subtitle)
	resized.connect(_recenter)
	_recenter()
	visible = false


## Shows a prompt at once, or queues it when `min_hold` says to let the current
## one breathe. A later call always wins over an older queued prompt.
func play(title: String, subtitle: String, color: Color, min_hold := 0.0) -> void:
	if _active and _age < min_hold:
		_queued = {"title": title, "subtitle": subtitle, "color": color}
		return
	# A real replacement also drops an older queued prompt: the new phase wins.
	_queued.clear()
	_start(title, subtitle, color)


func is_showing() -> bool:
	return _active


func title_text() -> String:
	return _title.text if _title != null else ""


func subtitle_text() -> String:
	return _subtitle.text if _subtitle != null else ""


func title_color() -> Color:
	return _title.get_theme_color("font_color") if _title != null else Color.WHITE


func queued_title() -> String:
	return String(_queued["title"]) if not _queued.is_empty() else ""


func age() -> float:
	return _age


## The HUD hides the banner behind the scope, overlays and death; the fade
## keeps running, so it resumes where it was when the view comes back.
func set_hidden(hidden: bool) -> void:
	_hidden = hidden
	visible = _active and not _hidden


func clear() -> void:
	_active = false
	_queued.clear()
	visible = false
	modulate.a = 0.0


func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	var pop := clampf(_age / POP_TIME, 0.0, 1.0)
	var fade := clampf((SHOW_TIME - _age) / FADE_TIME, 0.0, 1.0)
	modulate.a = minf(pop, fade)
	scale = Vector2.ONE * lerpf(POP_SCALE, 1.0, pop)
	visible = not _hidden
	if _age >= SHOW_TIME:
		_active = false
		visible = false
		if not _queued.is_empty():
			var next := _queued
			_queued = {}
			var color: Color = next["color"]
			_start(String(next["title"]), String(next["subtitle"]), color)


func _start(title: String, subtitle: String, color: Color) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_subtitle.text = subtitle
	_active = true
	_age = 0.0
	modulate.a = 0.0
	scale = Vector2.ONE * POP_SCALE
	visible = not _hidden


func _make_label(font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _recenter() -> void:
	pivot_offset = size * 0.5
