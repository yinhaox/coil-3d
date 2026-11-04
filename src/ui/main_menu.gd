class_name MainMenu
extends Control

## Title screen: Play, How to play, Quit (design/ux-and-persistence.md screen 2).
## Emits intent signals only; AppRoot owns the navigation between screens.

signal play_requested
signal how_to_play_requested
signal settings_requested
signal quit_requested

## Injected by AppRoot before the menu enters the tree; a standalone instance
## (tests) simply plays no click cue.
var audio: AudioDirector = null

@onready var _title_label: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var _subtitle_label: Label = $Center/Panel/Margin/VBox/SubtitleLabel
@onready var _play_button: Button = $Center/Panel/Margin/VBox/PlayButton
@onready var _how_to_play_button: Button = $Center/Panel/Margin/VBox/HowToPlayButton
@onready var _settings_button: Button = $Center/Panel/Margin/VBox/SettingsButton
@onready var _quit_button: Button = $Center/Panel/Margin/VBox/QuitButton
@onready var _footer_label: Label = $FooterLabel


func _ready() -> void:
	theme = AppTheme.shared()
	_title_label.text = tr("COIL 3D")
	_subtitle_label.text = tr("Eat. Grow. Do not hit the walls.")
	_play_button.text = tr("Play")
	_how_to_play_button.text = tr("How to play")
	_settings_button.text = tr("Settings")
	_quit_button.text = tr("Quit")
	_footer_label.text = tr("Arrows / WASD steer — Esc pauses")
	var buttons: Array[Button] = [
		_play_button, _how_to_play_button, _settings_button, _quit_button
	]
	FocusRing.wire_vertical(buttons)
	if audio != null:
		audio.wire_buttons(buttons)
	_play_button.grab_focus()


func _on_play_pressed() -> void:
	play_requested.emit()


func _on_how_to_play_pressed() -> void:
	how_to_play_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
