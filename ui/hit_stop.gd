class_name HitStop
extends RefCounted
## A few frames of near-freeze on a kill, done by dropping Engine.time_scale and
## restoring it from a timer that ignores time scale. Pure game feel, so:
##  - the caller decides whether it is allowed (the HUD refuses under a fixture,
##    which has to replay identically),
##  - it never runs headless unless a test opts in,
##  - the restore timer lives on the SceneTree, not on a scene node, so a scene
##    change in the middle of a stop cannot leave the game slowed down.

## Tests set this to exercise the real thing without a window.
static var allow_headless := false

static var _active := false
static var _saved_scale := 1.0


## Starts a stop of `duration` real seconds. False when refused (headless,
## already stopping, no tree).
static func request(tree: SceneTree, duration := 0.05, time_scale := 0.04) -> bool:
	if tree == null or _active:
		return false
	if DisplayServer.get_name() == "headless" and not allow_headless:
		return false
	_active = true
	_saved_scale = Engine.time_scale
	Engine.time_scale = time_scale
	# process_always, not in physics, ignoring time scale.
	tree.create_timer(duration, true, false, true).timeout.connect(HitStop.restore)
	return true


static func is_active() -> bool:
	return _active


## Safe to call at any time (also from a scene teardown).
static func restore() -> void:
	if not _active:
		return
	_active = false
	Engine.time_scale = _saved_scale
