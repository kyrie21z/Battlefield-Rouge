class_name KeyBindings
extends RefCounted
## Player key bindings: which actions can be rebound, how a binding is stored
## in settings.cfg, and how a stored set is applied to the InputMap. Only the
## first event of each action is replaced. Esc (pause), F3 (debug) and wheel
## buttons remain reserved; historical weapon actions are discarded on load.

## [action, label] in menu order.
const REBINDABLE := [
	["move_forward", "前进"], ["move_back", "后退"], ["move_left", "左移"], ["move_right", "右移"],
	["jump", "跳跃"], ["dash", "冲刺"], ["fire", "开火"], ["aim", "聚焦瞄准"],
	["reload", "晶体重组"], ["melee", "近战"],
	["psyche_resonance", "沉睡共鸣"],
	["reconcile", "拾起皇冠"],
	["shield", "护盾"], ["throw_magazine", "投掷危险弹匣"], ["interact", "交互（增益台）"],
]
const RESERVED_KEYS := [KEY_ESCAPE, KEY_F3]
const RESERVED_BUTTONS := [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
	MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]


static func actions() -> Array[String]:
	var out: Array[String] = []
	for row in REBINDABLE:
		out.append(row[0])
	return out


## "key:<physical keycode>" or "mouse:<button index>"; "" for anything else.
static func encode(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key:%d" % code
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	return ""


static func decode(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var code := parts[1].to_int()
	if parts[0] == "key" and code > 0:
		var key := InputEventKey.new()
		key.physical_keycode = code as Key
		return key
	if parts[0] == "mouse" and code > 0:
		var button := InputEventMouseButton.new()
		button.button_index = code as MouseButton
		return button
	return null


## Whether `event` may be bound at all (a key or mouse button that is not reserved).
static func can_bind(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return code != KEY_NONE and not RESERVED_KEYS.has(code)
	if event is InputEventMouseButton:
		return not RESERVED_BUTTONS.has((event as InputEventMouseButton).button_index)
	return false


static func default_code(action: String) -> String:
	var loop := Engine.get_main_loop()
	if loop == null:
		return ""
	var setup: Node = (loop as SceneTree).root.get_node_or_null("InputMapSetup")
	if setup == null:
		return ""
	return encode(setup.default_event(action))


## The binding `action` should have under `bindings` (only non-defaults are stored).
static func code_for(bindings: Dictionary, action: String) -> String:
	var stored: String = bindings.get(action, "")
	return stored if decode(stored) != null else default_code(action)


## Binds `action` to `event` in `bindings`. If another rebindable action already
## uses that input, the two swap; returns that other action or "".
static func assign(bindings: Dictionary, action: String, event: InputEvent) -> String:
	var code := encode(event)
	var old := code_for(bindings, action)
	var swapped := ""
	for other in actions():
		if other != action and code_for(bindings, other) == code:
			_store(bindings, other, old)
			swapped = other
			break
	_store(bindings, action, code)
	return swapped


## Puts every rebindable action in the InputMap on its binding. Actions that
## already match are left alone, so the defaults never churn the InputMap.
static func apply(bindings: Dictionary) -> void:
	for action in actions():
		if not InputMap.has_action(action):
			continue
		var code := code_for(bindings, action)
		var event := decode(code)
		if event == null:
			continue
		var events := InputMap.action_get_events(action)
		if not events.is_empty() and encode(events[0]) == code:
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)
		for rest in events.slice(1):
			InputMap.action_add_event(action, rest)


## Keeps only real overrides and drops anything unreadable or unknown.
static func sanitize(bindings: Dictionary) -> Dictionary:
	var clean := {}
	for action in actions():
		var stored: Variant = bindings.get(action, "")
		if stored is String and decode(stored) != null and can_bind(decode(stored)) \
				and stored != default_code(action):
			clean[action] = stored
	return clean


static func _store(bindings: Dictionary, action: String, code: String) -> void:
	if code == default_code(action):
		bindings.erase(action)
	else:
		bindings[action] = code
