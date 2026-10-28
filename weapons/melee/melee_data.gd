class_name MeleeData
extends Resource
## One .tres per melee weapon. The numbers are the whole read of the weapon:
## `windup` is how long the swing is committed before it can cut, `active` is
## the window where the arc cuts, `recovery` is the follow-through that still
## locks the attack. Together they decide whether a weapon feels fast or heavy.
##
## Cut-001b AC-05 fixes only the qualitative spread; the numbers below are
## playtest defaults, not locked design:
##   匕首 快 / 近 / 低   -> knife, rising cut: screen lower-left to upper-right
##   斧   慢 / 中 / 高   -> axe, two-handed chop: straight down the centre line
##   太刀 中 / 远 / 中   -> tachi, falling cut: screen upper-left to lower-right,
##                          and the only one that steps toward a nearby body
##
## The swing itself is written on screen, not as rotations: `cut_from_aim` and
## `cut_to_aim` are where the tip of the blade points when the cut starts and
## ends, in normalised screen coordinates where (-1, -1) is the bottom-left
## corner, (1, 1) the top-right corner and (0, 0) the crosshair. The tip travels
## the straight screen line between the two, so a slash written as
## (-0.95, -0.9) -> (0.95, 0.9) crosses the whole screen on the diagonal.
##
## `*_hand` is where the grip sits in camera space (x right, y up, -z forward),
## which decides the silhouette and whether the tip can even reach the requested
## screen point: a 40 cm dagger has to cut close to the eye, a 1 m tachi does
## not. The grip also decides how much of the blade's flat can face the eye at
## all, because the flat is perpendicular to the shaft: a two-handed chop down the
## centre line with the hands on the centre line leaves the shaft pointing away,
## so the head can only be turned broadside by lying about the chop.
##
## `*_roll` turns the blade around its own long axis, and for an axe that is what
## decides whether it *chops* or *slaps*: the head's plate has to stand in the
## swing's own (sagittal) plane, which from the eye means nearly edge on — the
## axe comes down on its blades. Turned broadside the same chop reads as pressing
## the flat of the axe onto the ground. The axe's `*_roll` is therefore 75°, i.e.
## 15° off pure edge-on, which keeps a little of the head's mass on screen.

## How the viewmodel travels through the swing, which is also how the grip
## reads. Every style is one signature on screen, and the .tres data has to
## match it: the headless test checks that the aim points agree with the enum.
enum SwingStyle {
	## Two-handed overhead, straight down the middle of the screen.
	CHOP,
	## Right hand, blade across the body: lower-left corner to upper-right.
	RISING_CUT,
	## Right hand, forward grip: upper-left corner to lower-right.
	FALLING_CUT,
}

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
## Brightness of the first-person model, as a multiplier on its albedo. The
## exported atlas is painted for the scene's lighting, but the viewmodel is drawn
## unshaded (see melee_weapon.gd), so a dark prop stays dark at arm's length: the
## axe head's charcoal reads as a shadow-shaped blob against the ground. 1.0
## leaves the model exactly as exported; the axe lifts it to a legible grey.
@export var view_brightness := 1.0

@export_category("Hit")
@export var damage := 40.0
## How many metres in front of the eye the arc reaches. "近 / 中 / 远".
@export var reach := 1.9
## Full width of the hit cone in degrees.
@export var arc_degrees := 70.0
## Bodies one swing can damage; 0 means everything inside the arc.
@export var max_targets := 1

@export_category("Timing (seconds)")
@export var windup := 0.07
@export var active := 0.08
@export var recovery := 0.15
## Extra lockout after recovery before the next swing may start.
@export var extra_cooldown := 0.0

@export_category("Feel")
@export var swing_style := SwingStyle.RISING_CUT
## Degrees of camera kick applied when the swing connects.
@export var camera_kick := 1.5
@export var camera_kick_yaw := 0.6
## Metres the swing may carry the player, and how long that dash lasts. It is not
## a teleport: it only happens when a body is already inside `magnet_range`, it
## aims at that body rather than at the crosshair, and it is a fixed distance over
## `lunge_time` however far away the body is. The dash overrides the player's
## velocity, so it lands even with no movement key held.
##
## Every weapon has one; the length is what makes them feel different: 匕首 0.35,
## 斧 0.45, 太刀 0.55.
@export var lunge := 0.55
@export var lunge_time := 0.12
## How far away a body can still pull the swing toward itself, and the cone it has
## to be in. 0 turns the magnet off. Each weapon sets it just under its own
## `reach`, so the pull only happens when the body is already close — that is the
## "距离敌人较近" condition — while a swing at range still cuts without moving the
## player. The dash is only half of it: the hit arc is also centred on that body.
@export var magnet_range := 2.6
@export var magnet_arc_degrees := 100.0
## If the nearest body is already closer than this, the swing does not dash:
## there is nothing left to close, only a shove.
@export var stop_distance := 0.85
## Shove applied to whatever the swing hits, and how long it staggers them.
@export var impact_force := 2.0
@export var impact_stagger := 0.15

@export_category("Swing path")
## Metres from the grip to the tip. The pose turns the blade so that the tip
## lands on the requested screen point, which only works if this matches the
## exported model (see tools/export_melee_models.py).
@export var blade_length := 0.405
## Which side of the blade the cutting edge is on, as the model's local +Y / -Y.
## The pose puts the blade's flat toward the camera, and that still leaves the
## blade free to be turned 180°; this value picks the turn that leads with the
## edge instead of the spine. 0 means a symmetric head (the double axe), which
## has no one edge: there the roll only keeps a broad face toward the camera.
##
## Do not read this off the geometry: these props are a few hundred vertices, so
## the blade's midline drifts by millimetres and the exporter's belly rule cannot
## find the curve. Read it off the *paint* — lay the model flat, render each face
## with the model's +Y marked, and see which side carries the bright bevel. The
## tachi's bright line is on +Y, so it is `+1`. Worth the trouble: the automated
## edge check reads positive for either sign (it flips the roll to match), so a
## wrong value only shows up as "cuts with the back" in play.
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
