class_name BoonReplacePrompt
extends ConfirmationDialog
## Optional standalone host. The full picker can own the same manager protocol.
var manager: BoonManager

func bind(value: BoonManager) -> void:
	manager = value
	manager.replacement_requested.connect(_request)
	confirmed.connect(func(): manager.confirm_replace(true))
	canceled.connect(func(): manager.confirm_replace(false))
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "替换核心赐福"
	ok_button_text = "确认替换"
	cancel_button_text = "保留原卡"

func _request(previous: BoonData, replacement: BoonData) -> void:
	dialog_text = "%s → %s\n原核心效果将被移除。" % [previous.name, replacement.name]
	popup_centered(Vector2i(420, 180))
