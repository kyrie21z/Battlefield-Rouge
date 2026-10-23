extends Node3D
## Stationary target for testing weapons until real enemies arrive in step 3.
## Reports its death on the Events bus like an enemy would, then respawns.

@export var respawn_time := 2.0

var team := 1

@onready var _health: Health = $Health


func _ready() -> void:
	_health.died.connect(_on_died)


func _on_died(_source: Node) -> void:
	Events.enemy_killed.emit(self)
	visible = false
	_set_hitboxes_enabled(false)
	await get_tree().create_timer(respawn_time).timeout
	_health.health = _health.max_health
	visible = true
	_set_hitboxes_enabled(true)


func _set_hitboxes_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is Hitbox:
			child.collision_layer = Hitbox.LAYER if enabled else 0
