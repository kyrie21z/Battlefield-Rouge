extends Node

func _ready() -> void:
	var session := Node.new()
	session.set_script(load("res://tests/opening_boot_session.gd"))
	session.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(session)
	queue_free()
