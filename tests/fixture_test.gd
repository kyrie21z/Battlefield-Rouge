extends Node
## Starts the AC-07 check (see fixture_session.gd for what it does and how to
## run it). The check goes on the root and this node goes away, because the
## zones change the current scene, and a node in it would be freed with it.


func _ready() -> void:
	var session := Node.new()
	session.set_script(load("res://tests/fixture_session.gd"))
	session.name = "FixtureSession"
	get_tree().root.add_child.call_deferred(session)
	queue_free()
