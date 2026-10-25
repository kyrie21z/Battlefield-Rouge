class_name CaptureDebug
extends Label
## Debug bar for AC-03. Shows the capture state, which config file is in use
## with the numbers read from it, the live distance to the hit moment and the
## last strike. F3 toggles it.

var _director: ZoneDirector
var _point: CapturePoint
var _last := "—"
var _perfect_count := 0
var _normal_count := 0


func setup(director: ZoneDirector) -> void:
	_director = director
	_point = director.capture_point
	_point.struck.connect(_on_struck)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
	var config := _point.config
	var live := "—"
	if not _point.locked and not _point.is_captured():
		var offset_ms := CapturePoint.beat_offset(_point.beat_time()) * 1000.0
		var inside := absf(offset_ms) <= config.perfect_window_ms
		live = "%+d ms %s" % [roundi(offset_ms), "[窗口内]" if inside else ""]
	text = "\n".join([
		"[占点调试 · F3 隐藏]",
		"阶段 %s   进度 %s%%   在锤程内 %s" % [
			ZoneDirector.Phase.keys()[_director.phase],
			String.num(snappedf(_point.progress * 100.0, 0.1)),
			"是" if _point.player_in_reach else "否"],
		"配置 %s" % config.resource_path,
		"窗口 ±%s ms   普通 +%s%%   完美 ×%s（= +%s%%）" % [
			String.num(config.perfect_window_ms),
			String.num(config.normal_progress_percent),
			String.num(config.perfect_multiplier),
			String.num(snappedf(config.perfect_progress() * 100.0, 0.1))],
		"节拍周期 %s s   与命中时刻相差 %s" % [String.num(CapturePoint.BEAT_PERIOD), live],
		"上一击 %s" % _last,
		"统计 完美 %d / 普通 %d" % [_perfect_count, _normal_count],
	])


func _on_struck(perfect: bool, offset_ms: float, worth: float) -> void:
	if perfect:
		_perfect_count += 1
	else:
		_normal_count += 1
	_last = "%s  %+d ms  +%s%%" % [
		"完美" if perfect else "普通", roundi(offset_ms), String.num(snappedf(worth * 100.0, 0.1))]
