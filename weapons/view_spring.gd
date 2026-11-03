class_name ViewSpring
extends RefCounted
## Damped spring for the first-person gun: a shot kicks the model back and its
## muzzle up, then it rings back to rest. Position is metres, rotation degrees
## (x = pitch, y = yaw, z = roll). Presentation only: nothing here reads or
## feeds gameplay, and it never touches the global random sequence.

## Largest accumulated displacement, as a multiple of a single kick, so a long
## burst piles up into a shove instead of flying off the screen.
const MAX_STACK := 2.2
const SUBSTEP := 1.0 / 240.0

var stiffness := 260.0
var damping := 18.0

var position := Vector3.ZERO
var rotation := Vector3.ZERO
var _position_velocity := Vector3.ZERO
var _rotation_velocity := Vector3.ZERO


## Adds one kick on top of whatever is still ringing.
func kick(position_kick: Vector3, rotation_kick: Vector3) -> void:
	position = _stack(position + position_kick, position_kick)
	rotation = _stack(rotation + rotation_kick, rotation_kick)


func step(delta: float) -> void:
	var remaining := minf(delta, 0.25)
	while remaining > 0.0:
		var h := minf(remaining, SUBSTEP)
		remaining -= h
		# Semi-implicit Euler: stable for the stiffness range the guns use.
		_position_velocity += (-stiffness * position - damping * _position_velocity) * h
		position += _position_velocity * h
		_rotation_velocity += (-stiffness * rotation - damping * _rotation_velocity) * h
		rotation += _rotation_velocity * h


func is_at_rest() -> bool:
	return position.length() < 0.0002 and rotation.length() < 0.01 \
		and _position_velocity.length() < 0.002 and _rotation_velocity.length() < 0.2


func reset() -> void:
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	_position_velocity = Vector3.ZERO
	_rotation_velocity = Vector3.ZERO


func _stack(total: Vector3, one_kick: Vector3) -> Vector3:
	var limit := MAX_STACK * one_kick.abs()
	return total.clamp(-limit, limit) if one_kick != Vector3.ZERO else total
