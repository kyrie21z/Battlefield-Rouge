class_name RealmHurtFeedback
extends ColorRect
## Non-directional HP feedback. Fear's lost warnings must not hide actual harm.
const BASE_ALPHA := 0.30
const DAMAGE_SCALE := 2.0
const MAX_ALPHA := 0.82
const FADE_SECONDS := 0.55
const MERGE_SECONDS := 0.06
var health: Health
var _left := 0.0
var _peak := 0.0
var _merged_damage := 0.0
var _merge_left := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(1,1,1,0)
	var tint := ShaderMaterial.new()
	tint.shader = preload("res://ui/damage_vignette.gdshader")
	tint.set_shader_parameter("clear_radius",0.5)
	tint.set_shader_parameter("edge_radius",1.0)
	material = tint
	health.damaged.connect(_on_damage)
	health.died.connect(_on_death)
	hide()

func _on_damage(amount: float, _part: Hitbox.BodyPart, _source: Node) -> void:
	if amount <= 0:
		return
	if _merge_left <= 0:
		_merged_damage = 0
		_merge_left = MERGE_SECONDS
	_merged_damage += amount
	_peak = maxf(color.a,clampf(BASE_ALPHA+DAMAGE_SCALE*_merged_damage/maxf(health.max_health,1),BASE_ALPHA,MAX_ALPHA))
	_left = FADE_SECONDS
	color.a = _peak
	show()

func _on_death(_source: Node) -> void:
	_left = 0
	_merge_left = 0
	color.a = 0
	hide()

func _process(delta: float) -> void:
	_merge_left = maxf(0,_merge_left-delta)
	_left = maxf(0,_left-delta)
	color.a = _peak*_left/FADE_SECONDS
	visible = _left > 0
