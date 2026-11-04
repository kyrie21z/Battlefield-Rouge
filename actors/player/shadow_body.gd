extends Node3D
## The player's body, drawn only into shadows: the camera sits inside its head,
## so it is never seen directly, but the ground shows a running figure. The
## model is the grey-white crystal humanoid from protagonist_body.tscn. Purely
## visual; it holds no hitbox and draws no random numbers.

## Horizontal speed above which the body runs instead of standing.
const RUN_SPEED := 0.5
const IDLE_ANIM := "idle"
const RUN_ANIM := "run"
const MATERIAL: Material = preload("res://assets/materials/protagonist_crystal_material.tres")

@onready var _anim: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer


func _ready() -> void:
	# The crystal shader writes ALPHA, and a blended material casts no shadow.
	# An opaque grey base takes the shadow pass; the crystal is drawn over it.
	var shadow_caster := StandardMaterial3D.new()
	shadow_caster.albedo_color = Color(0.80, 0.81, 0.83)
	for mesh in find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		mi.material_override = shadow_caster
		mi.material_overlay = MATERIAL
	for anim in [IDLE_ANIM, RUN_ANIM]:
		_anim.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_anim.play(IDLE_ANIM)


func _process(_delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var anim := RUN_ANIM if Vector2(body.velocity.x, body.velocity.z).length() > RUN_SPEED else IDLE_ANIM
	if _anim.current_animation != anim:
		_anim.play(anim, 0.15)
