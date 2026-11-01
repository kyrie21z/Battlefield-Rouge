extends RefCounted
## The single transition owner; independent of rendering and future FPS scenes.
signal changed
signal entry_requested

enum State { TITLE, CINEMATIC, DECISION, OBSERVING, WALKING, COMPLETE }
var state: State = State.TITLE
var step_index: int = 0
var step_elapsed: float = 0.0
var step_count: int = 5
var paused: bool = false
var accepted: bool = false
var skipped: bool = false
var entry_count: int = 0
var play_serial: int = 0

func start() -> void:
	play_serial += 1
	state = State.CINEMATIC
	step_index = 0
	step_elapsed = 0.0
	paused = false
	accepted = false
	skipped = false
	entry_count = 0
	changed.emit()

func tick(delta: float) -> void:
	if paused or state != State.CINEMATIC:
		return
	step_elapsed += maxf(delta, 0.0)

func advance() -> void:
	if paused or state != State.CINEMATIC:
		return
	if step_index + 1 >= step_count:
		state = State.DECISION
	else:
		step_index += 1
	step_elapsed = 0.0
	changed.emit()

func skip() -> void:
	if state != State.CINEMATIC and state != State.TITLE:
		return
	step_index = step_count - 1
	step_elapsed = 0.0
	state = State.DECISION
	paused = false
	skipped = true
	changed.emit()

func observe() -> void:
	if paused or state != State.DECISION:
		return
	state = State.OBSERVING
	changed.emit()

func decision() -> void:
	if paused or state != State.OBSERVING:
		return
	state = State.DECISION
	changed.emit()

func confirm() -> void:
	if paused or state != State.DECISION:
		return
	accepted = true
	state = State.WALKING
	changed.emit()

func enter() -> void:
	if paused or not accepted or state != State.WALKING:
		return
	state = State.COMPLETE
	entry_count += 1
	changed.emit()
	entry_requested.emit()

func toggle_pause() -> void:
	if state == State.TITLE:
		return
	paused = not paused
	changed.emit()

func can_move() -> bool:
	return not paused and state in [State.OBSERVING, State.COMPLETE]
