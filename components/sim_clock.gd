class_name SimClock
## Game time in seconds, counted in physics ticks instead of read from the wall
## clock, and from 0 at the start of each zone. Played at a fixed step
## (`--fixed-fps 60`) a zone then runs on the same times on every machine and in
## every run, which is what lets a fixture reproduce it (Cut-001b AC-07,
## docs/adr/0005-reproducible-runs.md). Counting from the zone's start, not from
## when the game was launched, keeps the numbers identical down to the last bit:
## the same difference of two large times does not round the same way.
##
## In normal play the part of the current tick that has gone by is added, so the
## clock moves smoothly between ticks; at the fixed step that part is always 0.
## Read it from `_process` or from signals handled there. Inside a physics
## callback the fraction is left over from the previous frame.

static var _epoch := 0


## Starts the clock at 0. The zone director calls it when a zone begins.
static func restart() -> void:
	_epoch = Engine.get_physics_frames()


static func now() -> float:
	return (Engine.get_physics_frames() - _epoch + Engine.get_physics_interpolation_fraction()) \
		/ float(Engine.physics_ticks_per_second)
