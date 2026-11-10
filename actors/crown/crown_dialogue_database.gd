class_name CrownDialogueDatabase
extends Resource
## Authored speech and deterministic history selection. No global run reads.
@export var lines: Dictionary = {}
func history_key(run_count: int, last_depth: int, cause: String) -> String:
	var abyss := cause.to_lower().contains("abyss") or cause.to_lower().contains("fall") or cause.contains("深渊") or cause == "environment"
	if run_count <= 1:
		return "first"
	if last_depth >= 3:
		return "deep_abyss" if abyss else "deep"
	if run_count <= 4:
		return "early_abyss" if abyss else "early"
	return "veteran_abyss" if abyss else "veteran"
func line_for(key: String) -> Dictionary:
	return lines.get(key, {}).duplicate()
