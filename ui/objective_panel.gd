class_name ObjectivePanel
extends Control

const COLLAPSED_HEIGHT := 128.0
const EXPANDED_HEIGHT := 176.0

var director: ZoneDirector
var enemies_alive := 0
var phase := ZoneDirector.Phase.CLEAR_GUARDS

@onready var _zone: Label = $Zone
@onready var _objective: Label = $Objective
@onready var _detail: Label = $Detail


func setup(zone: ZoneDirector) -> void:
	director = zone
	enemies_alive = director.enemies_total
	director.phase_changed.connect(_on_phase_changed)
	director.enemies_changed.connect(_on_enemies_changed)
	_zone.text = "战区 %d/%d" % [director.zone_index + 1, RunState.ZONE_SCENES.size()]
	_on_phase_changed(director.phase)


func _on_phase_changed(value: ZoneDirector.Phase) -> void:
	phase = value
	_detail.visible = false
	_detail.text = ""
	match phase:
		ZoneDirector.Phase.CLEAR_GUARDS:
			_objective.text = "清除守卫"
		ZoneDirector.Phase.HAMMER_POINT:
			_objective.text = "锤击据点"
			_detail.visible = true
			_detail.text = "按 E 砸核心" if director.is_boss_zone else "按 E 挥锤"
		ZoneDirector.Phase.FLAG_PLANTED:
			_objective.text = "城市核心已夺取" if director.is_boss_zone else "到增益台按 F"
		ZoneDirector.Phase.BUFF_SELECT:
			_objective.text = "选择增益"
		ZoneDirector.Phase.BOSS_STANDING:
			_objective.text = "击倒 Boss"
	offset_bottom = offset_top + (EXPANDED_HEIGHT if _detail.visible else COLLAPSED_HEIGHT)
	queue_redraw()


func _on_enemies_changed(alive: int, _total: int) -> void:
	enemies_alive = alive
	queue_redraw()


func _draw() -> void:
	HudStyle.draw_panel(self, Rect2(Vector2.ZERO, size), HudStyle.PANEL_LINE)
	var color := HudStyle.ACCENT
	var center := Vector2(35.0, 65.0)
	match phase:
		ZoneDirector.Phase.HAMMER_POINT:
			draw_line(center + Vector2(-8.0, 14.0), center + Vector2(7.0, -7.0), color, 5.0, true)
			draw_line(center + Vector2(-2.0, -13.0), center + Vector2(15.0, -1.0), color, 9.0, true)
		ZoneDirector.Phase.FLAG_PLANTED, ZoneDirector.Phase.BUFF_SELECT:
			draw_line(center + Vector2(-9.0, 16.0), center + Vector2(-9.0, -16.0), color, 3.0, true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-8.0, -15.0),
				center + Vector2(15.0, -8.0), center + Vector2(-8.0, 0.0)]), color)
		_:
			if phase == ZoneDirector.Phase.BOSS_STANDING:
				color = HudStyle.WARNING
			draw_arc(center, 12.0, 0.0, TAU, 32, color, 2.0, true)
			for axis in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				draw_line(center + axis * 8.0, center + axis * 18.0, color, 2.0, true)
	if phase == ZoneDirector.Phase.CLEAR_GUARDS or phase == ZoneDirector.Phase.BOSS_STANDING:
		draw_circle(Vector2(26.0, 104.0), 4.0, HudStyle.TEXT)
		draw_line(Vector2(26.0, 110.0), Vector2(26.0, 119.0), HudStyle.TEXT, 7.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(43.0, 119.0), "× %d" % enemies_alive,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, HudStyle.TEXT)
