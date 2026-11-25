class_name SlumberTimeWarp
extends CanvasLayer
## 沉睡共鸣的全屏"子弹时间"观感层。
##
## 只做屏幕调色（由 slumber_warp.gdshader 完成），不碰任何玩法时钟——
## 敌人放慢来自 PsycheFragments 给的 boon_time_scale，这一层只负责让玩家看见。

const SHADER := preload("res://assets/shaders/slumber_warp.gdshader")
## 拉起占比：前 15% 快速拉满，随后缓慢回落。
const RISE := 0.15
## 回落的起点：55% 之后开始明显消退。
const FADE_START := 0.55

var material: ShaderMaterial
var _left := 0.0
var _total := 0.0


func _ready() -> void:
	layer = 90
	var overlay := ColorRect.new()
	overlay.name = "SlumberOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = SHADER
	overlay.material = material
	add_child(overlay)
	material.set_shader_parameter("intensity", 0.0)


func play(seconds: float) -> void:
	_total = maxf(seconds, 0.01)
	_left = _total


func is_playing() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		if not is_zero_approx(float(material.get_shader_parameter("intensity"))):
			material.set_shader_parameter("intensity", 0.0)
		return
	_left = maxf(_left - delta, 0.0)
	var progress := 1.0 - _left / _total
	var rise := clampf(progress / RISE, 0.0, 1.0)
	var fade := 1.0 - smoothstep(FADE_START, 1.0, progress)
	material.set_shader_parameter("intensity", rise * fade)
