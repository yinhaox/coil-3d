class_name EndPanel
extends CanvasLayer

## End-of-run overlay: end reason, run score, best score, a `New best` marker and
## Retry / Main menu buttons (design/ux-and-persistence.md screen 6). It only
## displays what the controller reports through `run_ended`; Retry and Main menu
## are intents, never session changes.

signal retry_requested
signal main_menu_requested

## Confirm input is ignored for a moment after the panel appears, so the key
## that ended the run cannot also trigger Retry (design rule 6).
const INPUT_LOCK_SECONDS := 0.4
const END_MESSAGES := {
	SnakeSession.EndReason.WALL: "Wall hit — run over",
	SnakeSession.EndReason.OBSTACLE: "Block hit — run over",
	SnakeSession.EndReason.SELF: "Self collision — run over",
	SnakeSession.EndReason.TIME_UP: "Time up — run over",
	SnakeSession.EndReason.CLEARED: "Board cleared",
}

@onready var _root: Control = $Root
@onready var _title_label: Label = $Root/Center/Panel/Margin/VBox/TitleLabel
@onready var _reason_label: Label = $Root/Center/Panel/Margin/VBox/ReasonLabel
@onready var _score_label: Label = $Root/Center/Panel/Margin/VBox/ScoreLabel
@onready var _best_label: Label = $Root/Center/Panel/Margin/VBox/BestLabel
@onready var _new_best_label: Label = $Root/Center/Panel/Margin/VBox/NewBestLabel
@onready var _retry_button: Button = $Root/Center/Panel/Margin/VBox/RetryButton
@onready var _main_menu_button: Button = $Root/Center/Panel/Margin/VBox/MainMenuButton

var _unlock_at_milliseconds := 0


func _ready() -> void:
	_root.theme = AppTheme.shared()
	_title_label.text = tr("Run over")
	_retry_button.text = tr("Retry")
	_main_menu_button.text = tr("Main menu")
	_new_best_label.text = tr("New best")
	var buttons: Array[Button] = [_retry_button, _main_menu_button]
	FocusRing.wire_vertical(buttons)
	_set_shown(false)


## The game controller injects the shared audio director so Retry / Main menu
## use the same click cue as the rest of the UI.
func wire_audio(audio: AudioDirector) -> void:
	if audio == null:
		return
	audio.wire_buttons([_retry_button, _main_menu_button])


func _on_run_ended(score: int, best: int, is_new_best: bool, end_reason: int) -> void:
	_reason_label.text = tr(END_MESSAGES.get(end_reason, "Run over"))
	_score_label.text = tr("Score: %d") % score
	_best_label.text = tr("Best: %d") % best
	_new_best_label.visible = is_new_best
	_set_shown(true)
	_unlock_at_milliseconds = Time.get_ticks_msec() + int(INPUT_LOCK_SECONDS * 1000.0)
	_retry_button.grab_focus()


func _on_status_changed(_score: int, state: int, _end_reason: int) -> void:
	if state != SnakeSession.State.OVER:
		_set_shown(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	main_menu_requested.emit()


func _on_retry_pressed() -> void:
	if _input_locked():
		return
	retry_requested.emit()


func _on_main_menu_pressed() -> void:
	if _input_locked():
		return
	main_menu_requested.emit()


func _input_locked() -> bool:
	return Time.get_ticks_msec() < _unlock_at_milliseconds


func _set_shown(shown: bool) -> void:
	visible = shown
	_root.visible = shown
