class_name Buff
extends Resource
## One run-only upgrade. Effects are applied only through Stats.

@export var id: StringName = &""
@export var school_id: StringName = &""
@export var title := ""
@export_multiline var description := ""
@export var icon: Texture2D
## Compact description used beside the number of stacks in the run HUD.
@export var stack_text := ""
@export var stat: StringName = Stats.DAMAGE
@export var add := 0.0
@export var mul := 1.0
## Some upgrades also grant a shared capability, such as unlocking a shield.
@export var extra_adds: Dictionary = {}


func stack_summary() -> String:
	return stack_text if not stack_text.is_empty() else description
