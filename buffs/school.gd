class_name School
extends Resource
## One buff school's identity: silhouette, colors, and the direction in words.
## Upgrade effects live in Buff resources, never in the school identity.


@export var id: StringName = &""
@export var title := ""
## 枪伤·射速·弹匣 / 刀伤·刀速·刀距 / 主动护盾. No numeric effects.
@export var direction := ""
@export var accent := Color.WHITE
@export var shade := Color.BLACK
@export var icon: Texture2D
