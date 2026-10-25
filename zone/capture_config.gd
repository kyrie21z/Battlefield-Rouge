class_name CaptureConfig
extends Resource
## The three numbers Cut-001b (AC-03) leaves open to playtest tuning. Edit them
## in zone/capture_config.tres; the rules in capture_point.gd stay as they are.

## A swing counts as a perfect strike when it lands within this many
## milliseconds before or after the hit moment.
@export_range(1.0, 400.0, 1.0, "suffix:ms") var perfect_window_ms := 150.0
## Progress an ordinary swing adds, in percent of the whole capture.
@export_range(0.5, 50.0, 0.5, "suffix:%") var normal_progress_percent := 8.0
## A perfect strike adds the ordinary progress times this.
@export_range(1.0, 5.0, 0.1) var perfect_multiplier := 1.5


## Fraction of the whole capture (0..1) added by an ordinary swing.
func normal_progress() -> float:
	return normal_progress_percent / 100.0


## Fraction of the whole capture (0..1) added by a perfect strike.
func perfect_progress() -> float:
	return normal_progress() * perfect_multiplier
