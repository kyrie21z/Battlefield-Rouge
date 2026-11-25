class_name GamePointer
extends RefCounted
## Pointer transitions shared by gameplay and modal UI.

static var _click_required := "--free-mouse" in OS.get_cmdline_user_args()


static func release_until_click() -> void:
	_click_required = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func restore(mode: Input.MouseMode, window: Window) -> void:
	if mode == Input.MOUSE_MODE_CAPTURED and (_click_required or not _can_capture(window)):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = mode


static func capture_from_click(window: Window) -> bool:
	if not _can_capture(window):
		return false
	_click_required = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true


static func _can_capture(window: Window) -> bool:
	return is_instance_valid(window) and (window.has_focus() or DisplayServer.get_name() == "headless")
