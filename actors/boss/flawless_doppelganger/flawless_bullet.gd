class_name FlawlessBullet
extends Projectile
func _physics_process(delta: float) -> void:
	if is_instance_valid(source) and source.has_method("tempo_multiplier"):
		delta *= source.call("tempo_multiplier")
	super._physics_process(delta)
