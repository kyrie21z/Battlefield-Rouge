class_name KeyHint
extends RefCounted
## The on-screen name of whatever an input action is bound to right now, so
## prompts such as "按 E 挥锤" follow the player's key bindings. Reads only the
## engine's InputMap.

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "左键", MOUSE_BUTTON_RIGHT: "右键", MOUSE_BUTTON_MIDDLE: "中键",
	MOUSE_BUTTON_XBUTTON1: "侧键1", MOUSE_BUTTON_XBUTTON2: "侧键2",
	MOUSE_BUTTON_WHEEL_UP: "滚轮上", MOUSE_BUTTON_WHEEL_DOWN: "滚轮下",
}


## The first binding of `action`, e.g. "E", "Shift", "右键"; "?" if unbound.
static func of(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	var events := InputMap.action_get_events(action)
	return name_of(events[0]) if not events.is_empty() else "?"


static func name_of(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		return MOUSE_NAMES.get((event as InputEventMouseButton).button_index,
			"鼠标%d" % (event as InputEventMouseButton).button_index)
	return "?"
