extends Node3D
## The player's body, drawn only into shadows: the camera sits inside its head,
## so it is never seen directly, but the ground shows a running figure. Purely
## visual; it holds no hitbox and draws no random numbers.

## Horizontal speed above which the body runs instead of standing.
const RUN_SPEED := 0.5

@export var held_weapon := "AK"

@onready var _anim: AnimationPlayer = $Model/AnimationPlayer


func _ready() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for mesh in $Model/CharacterArmature/Skeleton3D/Index1_R.get_children():
		mesh.visible = mesh.name == held_weapon
	for anim in ["Idle", "Run_Gun"]:
		_anim.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")


func _process(_delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var anim := "Run_Gun" if Vector2(body.velocity.x, body.velocity.z).length() > RUN_SPEED else "Idle"
	if _anim.current_animation != anim:
		_anim.play(anim, 0.15)
