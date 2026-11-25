class_name SorrowGlob
extends Projectile
var effect_target: Player
var effect_key: StringName
var caster_ref: WeakRef

func _ready() -> void:
	tint = Projectile.realm_tint(&"sorrow")
	super._ready()
	impacted.connect(_on_hit)

func _on_hit(hit: Node, _point: Vector3) -> void:
	if reflected or not is_instance_valid(effect_target) or caster_ref == null or not is_instance_valid(caster_ref.get_ref()):
		return
	if hit is Hitbox and (hit as Hitbox).health == effect_target.health and not effect_target.health.invulnerable and not effect_target.health.dash_invulnerable:
		effect_target.set_realm_effect(effect_key,{"owner":caster_ref.get_ref(),"duration":2.5,"move_multiplier":0.45})
