extends Health
## Only this reserve actor has evasion. Base Health still owns team filtering,
## shields, damage multipliers and death; a dodge never heals damage afterward.


func apply_damage(amount: float, body_part: Hitbox.BodyPart, source: Node = null) -> float:
	var hostile: bool = is_instance_valid(source) and "team" in source and source.team != team
	if amount > 0.0 and not is_dead() and hostile and not invulnerable \
			and not dash_invulnerable and not parrying:
		var actor := get_parent() as SlothEnemy
		if actor != null and actor.try_cloak_evade():
			return 0.0
	return super.apply_damage(amount, body_part, source)
