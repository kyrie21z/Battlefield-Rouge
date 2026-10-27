class_name WeaponData
extends Resource
## One .tres per gun. `Weapon` holds a `data_set` of these and shows one at a time;
## the mouse wheel cycles them. Trimmed from origin/sheji/weapons/weapon_definition.gd:
## no shop, no GameState, no penetration.

enum FireMode { AUTO, SEMI }

@export_category("Identity")
@export var display_name := ""
## First-person model. Null falls back to a placeholder box.
@export var view_scene: PackedScene
## ProceduralAudio sound kind, e.g. "gunshot_ak47".
@export var gunshot_sound := "gunshot_medium"

@export_category("Fire")
@export var fire_mode := FireMode.AUTO
@export var fire_interval := 0.1
## Damage one pellet does. The whole shot is `damage x pellets`.
@export var damage := 34.0
## Rays fired per trigger pull, each one aimed inside the spread cone. 1 is a
## rifle; 9 with small per-pellet damage is a shotgun. Buffs scale the total.
@export var pellets := 1
@export var max_range := 300.0
@export var falloff_start := 50.0
@export var falloff_end := 220.0
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
@export var camera_kick := 0.35
## Horizontal kick per shot in units of camera_kick, cycled shot by shot so
## each weapon has a learnable spray pattern.
@export var recoil_pattern: Array[float] = []
## Fraction of the kick that stays until the player pulls the mouse down.
@export_range(0.0, 1.0) var recoil_manual := 0.7

@export_category("Ammo")
@export var magazine_size := 30
@export var reserve_ammo := 120
@export var reload_time_tactical := 2.2
@export var reload_time_empty := 2.8

@export_category("Handling")
@export var ads_fov := 55.0
@export var ads_move_scale := 0.55
@export var ads_position := Vector3(0.0, -0.16, -0.28)
@export var hip_position := Vector3(0.22, -0.22, -0.45)
## Magnifications the scope offers, e.g. [2, 4, 8]. Empty means iron sights: the
## gun just uses `ads_fov`. With a scope, aiming shows the scope overlay, hides the
## model and sets the field of view to `base_fov / level`; the mouse wheel picks a
## level instead of changing guns.
@export var scope_zoom_levels: Array[float] = []
