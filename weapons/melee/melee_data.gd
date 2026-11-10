class_name MeleeData
extends Resource
## The mind blade's damage, timing, magnetism and screen-space swing path.
## Tune the resource; only Stats supplies runtime modifiers.

@export_category("Identity")
@export var display_name := ""
## First-person model, hidden except while swinging. See melee_weapon.gd.
@export var view_scene: PackedScene
## HUD silhouette, rendered from the viewmodel by tools/render_icons.tscn.
@export var icon: Texture2D
## ProceduralAudio sound kind for the swing itself. Every weapon shares the same
## impact sound, which melee_weapon.gd generates once.
@export var swing_sound := "melee_swing"
## Pitch of the swing whoosh; a heavy weapon sits lower.
@export var swing_pitch := 1.0
@export_category("Hit")
@export var damage := 55.0
## How many metres in front of the eye the arc reaches. "近 / 中 / 远".
@export var reach := 4.2
## Full width of the hit cone in degrees.
@export var arc_degrees := 70.0
## Bodies one swing can damage; 0 means everything inside the arc.
@export var max_targets := 1

@export_category("Timing (seconds)")
@export var windup := 0.08
@export var active := 0.12
@export var recovery := 0.15
## Extra lockout after recovery before the next swing may start.
@export var extra_cooldown := 0.0

@export_category("Feel")
## Degrees of camera kick applied when the swing connects.
@export var camera_kick := 1.5
@export var camera_kick_yaw := 0.6
## Metres the swing may carry the player, and how long that dash lasts. It is not
## a teleport: it only happens when a body is already inside `magnet_range`, it
## aims at that body rather than at the crosshair, and it is a fixed distance over
## `lunge_time` however far away the body is. The dash overrides the player's
## velocity, so it lands even with no movement key held.
##
## The mind blade closes 0.45 metres during its quick wind-up.
@export var lunge := 0.45
@export var lunge_time := 0.12
## Acquisition radius and full cone width; the lunge and arc target the same body.
@export var magnet_range := 4.5
@export var magnet_arc_degrees := 80.0
## If the nearest body is already closer than this, the swing does not dash:
## there is nothing left to close, only a shove.
@export var stop_distance := 0.85
## Shove applied to whatever the swing hits, and how long it staggers them.
@export var impact_force := 2.0
@export var impact_stagger := 0.15

@export_category("Swing path")
## Metres from the grip to the tip. The pose turns the blade so that the tip
## lands on the requested screen point, which only works if this matches the
## exported Blender model.
@export var blade_length := 0.34
## Cutting edge direction in model space; the glowing spine is opposite it.
@export var edge_side := -1
## Grip position, tip aim and blade roll while the weapon hangs at rest, i.e.
## before the wind-up starts and after the recovery ends.
@export var rest_hand := Vector3(0.3, -0.5, -0.45)
@export var rest_aim := Vector2(0.3, -1.0)
@export var rest_roll := 0.0
## End of the wind-up: the blade is loaded and the tip sits on the start of the
## cut. This is the pose the cut is launched from.
@export var cut_from_hand := Vector3(0.16, -0.26, -0.3)
@export var cut_from_aim := Vector2(-0.95, -0.9)
@export var cut_from_roll := 0.0
## End of the cut: where the tip arrives, and so where the trail ends.
@export var cut_to_hand := Vector3(0.32, 0.0, -0.35)
@export var cut_to_aim := Vector2(0.95, 0.9)
@export var cut_to_roll := 0.0


## Seconds from the start of one swing to the start of the next.
func cycle() -> float:
	return windup + active + recovery + extra_cooldown
