class_name SceneFade
extends CanvasLayer
## Full-screen black overlay for the opening -> zone handoff. It is added to the
## tree root, so it outlives the scene change, and it never reads RunState or
## gameplay state: the transition is presentation only (ADR 0005).

signal black_reached
signal finished

const LAYER := 100
const HOLD_FRAMES := 3
const LOADING_TEXT := "加载中…"
const LOADING_FONT_SIZE := 30

enum Phase { IDLE, TO_BLACK, READY, HOLD, TO_CLEAR }

var _rect: ColorRect
var _label: Label
var _error_panel: CenterContainer
var _error_label: Label
var _retry_button: Button
var _quit_button: Button
var _phase: Phase = Phase.IDLE
var _duration := 0.0
var _elapsed := 0.0
var _hold_frames := 0
var _reveal_duration := 0.0
var _free_on_finish := false
var _on_step := Callable()


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	_label = Label.new()
	_label.text = LOADING_TEXT
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", LOADING_FONT_SIZE)
	_label.add_theme_color_override("font_color", HudStyle.TEXT)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	_label.add_theme_font_override("font", font)
	add_child(_label)
	_error_panel = CenterContainer.new()
	_error_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_error_panel.hide()
	add_child(_error_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_error_panel.add_child(box)
	_error_label = Label.new()
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_font_override("font", font)
	_error_label.add_theme_font_size_override("font_size", LOADING_FONT_SIZE)
	box.add_child(_error_label)
	_retry_button = Button.new()
	_retry_button.text = "重试加载"
	_retry_button.custom_minimum_size = Vector2(320, 56)
	_retry_button.add_theme_font_override("font", font)
	box.add_child(_retry_button)
	_quit_button = Button.new()
	_quit_button.text = "退出游戏"
	_quit_button.custom_minimum_size = Vector2(320, 56)
	_quit_button.add_theme_font_override("font", font)
	_quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(_quit_button)


func _ready() -> void:
	set_process(false)


func alpha() -> float:
	return _rect.color.a


func is_black() -> bool:
	return _rect.color.a >= 0.999


func is_loading() -> bool:
	return _label.visible


func set_alpha(value: float) -> void:
	_rect.color.a = clampf(value, 0.0, 1.0)


func show_loading() -> void:
	_error_panel.hide()
	_label.visible = true
	_label.text = LOADING_TEXT


## A failed load must release the spinner and give the player a way forward.
func show_error(message: String, retry: Callable) -> void:
	set_process(false)
	_phase = Phase.READY
	set_alpha(1.0)
	_label.hide()
	_error_label.text = message
	_retry_button.pressed.connect(retry, CONNECT_ONE_SHOT)
	_error_panel.show()
	_retry_button.grab_focus()


## Coroutine: goes fully black over `duration` (callbacks get the 0..1 progress)
## and leaves the overlay in place until `reveal()` or `discard()`.
func fade_to_black(duration: float, on_step: Callable = Callable()) -> void:
	_on_step = on_step
	_duration = maxf(duration, 0.0)
	_elapsed = 0.0
	_phase = Phase.TO_BLACK
	set_process(true)
	if _duration <= 0.0:
		set_alpha(1.0)
		_reach_black()
		return
	while _phase == Phase.TO_BLACK:
		await get_tree().process_frame


## Keeps the overlay black for `hold_frames` frames (the new scene's warm-up),
## then fades out over `duration` and frees itself. Works while the tree is
## paused, because the buff screen pauses right after the zone loads.
func reveal(hold_frames: int = HOLD_FRAMES, duration: float = 0.6) -> void:
	_label.visible = false
	_hold_frames = maxi(hold_frames, 0)
	_reveal_duration = maxf(duration, 0.0)
	_free_on_finish = true
	_phase = Phase.HOLD
	set_process(true)


## Removes the overlay immediately, for the fallback entry that has no fade.
func discard() -> void:
	set_process(false)
	_phase = Phase.IDLE
	queue_free()


func _process(delta: float) -> void:
	match _phase:
		Phase.TO_BLACK:
			_elapsed += delta
			var progress := clampf(_elapsed / _duration, 0.0, 1.0)
			set_alpha(progress)
			if _on_step.is_valid():
				_on_step.call(progress)
			if progress >= 1.0:
				_reach_black()
		Phase.HOLD:
			if _hold_frames > 0:
				_hold_frames -= 1
			elif _reveal_duration <= 0.0:
				_finish()
			else:
				_elapsed = 0.0
				_phase = Phase.TO_CLEAR
		Phase.TO_CLEAR:
			_elapsed += delta
			set_alpha(1.0 - clampf(_elapsed / _reveal_duration, 0.0, 1.0))
			if _elapsed >= _reveal_duration:
				_finish()


func _reach_black() -> void:
	_phase = Phase.READY
	set_process(false)
	black_reached.emit()


func _finish() -> void:
	set_process(false)
	_phase = Phase.IDLE
	finished.emit()
	if _free_on_finish:
		queue_free()
