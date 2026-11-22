extends CanvasLayer
## Death or victory screen (Scheme B: Architectural Editorial).
## Pauses the game; the button asks for a new run.

signal restart_pressed

@onready var _title: Label = $Center/Box/Title
@onready var _subtitle: Label = $Center/Box/Subtitle
@onready var _button: Button = $Center/Box/Restart


func setup(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle


func _ready() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EditorialStyle.style_label(_title, 54, EditorialStyle.PAPER, 800, false, 4)
	EditorialStyle.style_label(_subtitle, 24, EditorialStyle.GOLD_BRIGHT, 600, false, 1)
	# The restart key follows the player's reload binding.
	_button.text = "重新开始（%s）" % KeyHint.of("reload")
	EditorialStyle.style_button(_button, true, false, 24)
	_button.pressed.connect(_on_restart)
	_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		_on_restart()


func _on_restart() -> void:
	get_tree().paused = false
	restart_pressed.emit()
