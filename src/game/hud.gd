class_name Hud
extends CanvasLayer

## Read-only run stats for the corners of the screen: score, length, current
## speed, elapsed time and the best score for this mode
## (design/ux-and-persistence.md screen 4). The controller emits
## `stats_changed`; this node owns the label text, so gameplay code never
## touches UI nodes directly (.dsh/rules/gdscript.md).
##
## Labels are only rewritten when their text actually changes, and the
## controller only emits when a displayed value changes, so nothing flickers.

@onready var _score_label: Label = $Stats/VBox/ScoreLabel
@onready var _length_label: Label = $Stats/VBox/LengthLabel
@onready var _speed_label: Label = $Stats/VBox/SpeedLabel
@onready var _time_label: Label = $Stats/VBox/TimeLabel
@onready var _best_label: Label = $Best/BestLabel


func _ready() -> void:
	# A CanvasLayer is not a CanvasItem, so the HUD installs the theme on the
	# two Controls that own the labels instead of inheriting the window theme.
	$Stats.theme = AppTheme.shared()
	$Best.theme = AppTheme.shared()


func _on_stats_changed(score: int, length: int, speed: float, elapsed: float, best: int) -> void:
	_set_text(_score_label, tr("Score: %d") % score)
	_set_text(_length_label, tr("Length: %d") % length)
	_set_text(_speed_label, tr("Speed: %.1f cells/s") % speed)
	_set_text(_time_label, tr("Time: %s") % format_time(elapsed))
	_set_text(_best_label, tr("Best: %d") % best)


## `m:ss` for the run clock, truncated rather than rounded so it never shows
## more time than the run actually took.
static func format_time(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	var minutes := int(total / 60.0)
	return "%d:%02d" % [minutes, total % 60]


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
