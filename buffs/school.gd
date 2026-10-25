class_name School
extends Resource
## One buff school's identity: silhouette, colors, and the direction in words.
## Effect numbers stay Design-TBD and are not stored here.


@export var id: StringName = &""
@export var title := ""
## 近战 / 弹药特性 / 爆头收益. Words only — not a multiplier.
@export var direction := ""
@export var accent := Color.WHITE
@export var shade := Color.BLACK
@export var icon: Texture2D
