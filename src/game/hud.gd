class_name Hud
extends CanvasLayer

## One-line status HUD for the first visible slice: score plus the run-end
## prompt. The controller emits `status_changed`; this node owns the Label text
## so gameplay code never touches UI nodes directly (.dsh/rules/gdscript.md).
## The full HUD, end panel and localized strings belong to a later UI story.

const END_MESSAGES := {
	SnakeSession.EndReason.WALL: "Wall hit — run over",
	SnakeSession.EndReason.OBSTACLE: "Obstacle hit — run over",
	SnakeSession.EndReason.SELF: "Self collision — run over",
	SnakeSession.EndReason.TIME_UP: "Time up — run over",
	SnakeSession.EndReason.CLEARED: "Board cleared",
}

@onready var _score_label: Label = $ScoreLabel
@onready var _end_label: Label = $EndLabel

var _last_score := -1
var _last_state := -1
var _last_reason := -1


## Called through the scene's signal connection when score or state changes.
func _on_status_changed(score: int, state: int, end_reason: int) -> void:
	if score != _last_score:
		_last_score = score
		_score_label.text = tr("Score: %d") % score
	if state == _last_state and end_reason == _last_reason:
		return
	_last_state = state
	_last_reason = end_reason
	if state == SnakeSession.State.OVER:
		var message: String = END_MESSAGES.get(end_reason, "Run over")
		_end_label.text = tr(message)
		_end_label.visible = true
	else:
		_end_label.visible = false
