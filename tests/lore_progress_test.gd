extends Node
func _ready() -> void:
	var session := Node.new()
	session.set_script(load("res://tests/lore_progress_session.gd"))
	get_tree().root.add_child.call_deferred(session)
	queue_free()
