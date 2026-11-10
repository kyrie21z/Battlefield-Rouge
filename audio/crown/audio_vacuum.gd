class_name AudioVacuum
extends Node
## A scene-owned mute lease. Volume is never changed; pause releases the lease.
signal finished
var remaining := 0.0
var active := false
var _holding := false
static var _leases: Dictionary = {}
static var _original_mute := false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func begin(duration := 0.1) -> void:
	cancel()
	remaining = maxf(duration, 0.0)
	active = remaining > 0
	if active and not get_tree().paused: _acquire()

func _acquire() -> void:
	if _holding: return
	if _leases.is_empty(): _original_mute = AudioServer.is_bus_mute(0)
	_leases[get_instance_id()] = true
	AudioServer.set_bus_mute(0, true)
	_holding = true

func _release() -> void:
	if not _holding: return
	_leases.erase(get_instance_id())
	if _leases.is_empty(): AudioServer.set_bus_mute(0, _original_mute)
	_holding = false

func _process(delta: float) -> void:
	if not active: return
	if get_tree().paused:
		_release()
		return
	_acquire()
	remaining = maxf(0.0, remaining-delta)
	if remaining <= 0:
		active = false
		_release()
		finished.emit()

func cancel() -> void:
	active = false
	remaining = 0.0
	_release()

func _exit_tree() -> void:
	cancel()
