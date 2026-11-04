extends "res://ui/game_start.gd"
## Exercise the real loading error screen without corrupting a game resource.

var observations: Dictionary = {}


func _load_zone(target: String) -> PackedScene:
	observations["attempts"] = int(observations.get("attempts", 0)) + 1
	observations["loading_visible"].append(is_instance_valid(_fade) and _fade.is_loading())
	if observations["attempts"] == 1:
		return PackedScene.new() if observations.get("empty_scene", false) else null
	return super._load_zone(target)
