class_name WeaponData
extends Resource
## Tunable obsidian pistol data. The weapon has one magazine and one view.

enum FireMode { AUTO, SEMI }

@export_category("Identity")
@export var display_name := ""
## First-person model. Null falls back to a placeholder box.
@export var view_scene: PackedScene
## HUD silhouette, rendered from the viewmodel by tools/render_icons.tscn.
@export var icon: Texture2D
## ProceduralAudio sound kind, e.g. "gun_pistol".
@export var gunshot_sound := "gun_pistol"

@export_category("Fire")
@export var fire_mode := FireMode.SEMI
@export var fire_interval := 0.18
## Damage one pellet does. The whole shot is `damage x pellets`.
@export var damage := 35.0
## Rays per shot; the pistol uses one.
@export var pellets := 1
@export var max_range := 180.0
@export var falloff_start := 30.0
@export var falloff_end := 90.0
@export var min_damage_scale := 0.5

@export_category("Spread (degrees)")
@export var hip_spread := 2.0
@export var ads_spread := 0.35
@export var spread_per_shot := 0.5
@export var spread_recovery := 7.0
@export var max_spread := 6.0
@export var move_spread_scale := 1.5
@export var airborne_spread_scale := 2.5

@export_category("Recoil")
## Vertical kick per shot, in degrees.
@export var camera_kick := 1.2
@export var camera_yaw := 0.3
@export var camera_return_time := 0.12
## Fraction of the kick that stays until the player pulls the mouse down.
@export_range(0.0, 1.0) var recoil_manual := 0.0

@export_category("Feel")
## Presentation only. None of these move a bullet or change a gameplay number.
## Viewmodel kick per shot: metres pushed back along +Z (towards the eye)...
@export var view_kick_back := 0.04
## ...degrees the muzzle rises, and the random yaw / roll (+-) on top.
@export var view_kick_pitch := 1.5
@export var view_kick_yaw := 0.4
@export var view_kick_roll := 0.6
## The viewmodel spring. Damping ratio = damping / (2 * sqrt(stiffness)); under
## 1 it rings once or twice, which is what gives a heavy gun its weight.
@export var view_spring_stiffness := 260.0
@export var view_spring_damping := 20.0
## Camera shake per shot: peak degrees, FOV punch as a fraction of the current
## FOV, and how long it takes to die away (seconds).
@export var shake_degrees := 0.1
@export var shake_fov_punch := 0.01
@export var shake_duration := 0.12
## Both kick and shake are scaled by this while aiming.
@export_range(0.0, 1.0) var aim_feel_scale := 0.5
## Maximum visual tracers per shot.
@export var max_tracers := 1

@export_category("Ammo")
@export var magazine_size := 8
@export var reserve_ammo := -1
@export var reload_time_tactical := 0.85
@export var reload_time_empty := 0.85

@export_category("Handling")
@export var ads_fov := 58.0
@export var ads_move_scale := 0.55
@export var ads_position := Vector3(0.08, -0.12, -0.33)
@export var hip_position := Vector3(0.23, -0.19, -0.37)
