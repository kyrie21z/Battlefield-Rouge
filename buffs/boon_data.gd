class_name BoonData
extends Resource
## Immutable authored card. Runtime state belongs to its BoonEffect.
enum Sin { SLOTH, FEAR, WRATH, SORROW }
enum Slot { GUN, BLADE, DASH, OTHER }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, DUAL }

@export var id: String = ""
@export var name: String = ""
@export var sin: Sin = Sin.SLOTH
@export var slot: Slot = Slot.GUN
@export var rarity: Rarity = Rarity.COMMON
@export var core := true
@export var prerequisites: Array[String] = []
@export var prerequisite_any: Array[String] = []
@export var required_trait_sin: int = -1
@export var required_trait_count: int = 0
@export var required_sins: Array[int] = []
@export_multiline var description: String = ""
@export var icon: Texture2D
## {stat: {"add": number, "mul": number}}. Applied by reversible source.
@export var stat_modifiers: Dictionary = {}
@export var script_hook: Script
@export var parameters: Dictionary = {}
