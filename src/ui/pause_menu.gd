class_name PauseMenu
extends CanvasLayer

## Pause overlay: Resume, Restart, Main menu (design/ux-and-persistence.md screen
## 5). It reads the run state from the controller's status signal and emits
## intent signals; it never touches the session. Esc itself is owned by
## GameController, which toggles the pause, so opening and closing the menu use
## the same input path.

signal resume_requested
signal restart_requested
signal settings_requested
signal main_menu_requested

@onready var _root: Control = $Root
@onready var _title_label: Label = $Root/Center/Panel/Margin/VBox/TitleLabel
@onready var _resume_button: Button = $Root/Center/Panel/Margin/VBox/ResumeButton
@onready var _restart_button: Button = $Root/Center/Panel/Margin/VBox/RestartButton
@onready var _settings_button: Button = $Root/Center/Panel/Margin/VBox/SettingsButton
@onready var _main_menu_button: Button = $Root/Center/Panel/Margin/VBox/MainMenuButton


func _ready() -> void:
	_root.theme = AppTheme.shared()
	_title_label.text = tr("Paused")
	_resume_button.text = tr("Resume")
	_restart_button.text = tr("Restart")
	_settings_button.text = tr("Settings")
	_main_menu_button.text = tr("Main menu")
	var buttons: Array[Button] = [
		_resume_button, _restart_button, _settings_button, _main_menu_button
	]
	FocusRing.wire_vertical(buttons)
	_set_shown(false)


## The game controller injects the shared audio director after the scene is
## built, so the pause buttons use the same click cue as the menus.
func wire_audio(audio: AudioDirector) -> void:
	if audio == null:
		return
	audio.wire_buttons([
		_resume_button, _restart_button, _settings_button, _main_menu_button
	])


func _on_status_changed(_score: int, state: int, _end_reason: int) -> void:
	var paused := state == SnakeSession.State.PAUSED
	if paused == _root.visible:
		return
	_set_shown(paused)
	if paused:
		_resume_button.grab_focus()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()


func _set_shown(shown: bool) -> void:
	visible = shown
	_root.visible = shown
