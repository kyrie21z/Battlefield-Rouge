extends Node
## Compatibility observer entry; the replacement boot harness still checks the
## actual cold realm resource, live scene handoff, real shot, death and re-entry.
func _ready() -> void:
	var observer := Node.new()
	observer.set_script(load("res://tests/opening_boot_session.gd"))
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(observer)
	queue_free()
