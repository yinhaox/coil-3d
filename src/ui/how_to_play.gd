class_name HowToPlay
extends Control

## One static page with the controls and the scoring rule. Esc or the Back
## button returns to the main menu (design/ux-and-persistence.md screen 2).

signal back_requested

const HOW_TO_PLAY_TEXT := """Eat the glowing food to grow and score.

Every food you eat makes the snake a little faster.

Touching a wall, a block or your own body ends the run.

Arrows or WASD steer. Esc pauses the run."""

@onready var _title_label: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var _body_label: Label = $Center/Panel/Margin/VBox/BodyLabel
@onready var _back_button: Button = $Center/Panel/Margin/VBox/BackButton


func _ready() -> void:
	theme = AppTheme.shared()
	_title_label.text = tr("How to play")
	_body_label.text = tr(HOW_TO_PLAY_TEXT)
	_back_button.text = tr("Back")
	var buttons: Array[Button] = [_back_button]
	FocusRing.wire_vertical(buttons)
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	back_requested.emit()


func _on_back_pressed() -> void:
	back_requested.emit()
