class_name MainMenu
extends Control

## Title screen: the three mode entries, Play, How to play, Settings and Quit
## (design/ux-and-persistence.md screen 2, design/game-modes.md rule 7).
## Emits intent signals only; AppRoot owns the navigation between screens and
## decides which mode a run starts on.

signal play_requested(mode_name: String)
signal mode_requested(mode_name: String)
signal how_to_play_requested
signal settings_requested
signal quit_requested

const VERSION_SETTING := "application/config/version"
const FOOTER_HINT := "Arrows / WASD steer — Esc pauses"
const FOOTER_VERSION_SEPARATOR := "  ·  "
const VERSION_PREFIX := "v"

## Injected by AppRoot before the menu enters the tree; a standalone instance
## (tests) simply plays no click cue.
var audio: AudioDirector = null

## Mode the buttons highlight and Play starts. AppRoot injects the mode the last
## run used; a standalone instance (tests) opens on the catalog default.
var current_mode: String = ModeCatalog.DEFAULT_MODE

var _mode_group: ButtonGroup = ButtonGroup.new()

@onready var _title_label: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var _subtitle_label: Label = $Center/Panel/Margin/VBox/SubtitleLabel
@onready var _play_button: Button = $Center/Panel/Margin/VBox/PlayButton
@onready var _classic_button: Button = $Center/Panel/Margin/VBox/ModeRow/ClassicButton
@onready var _maze_button: Button = $Center/Panel/Margin/VBox/ModeRow/MazeButton
@onready var _time_attack_button: Button = $Center/Panel/Margin/VBox/ModeRow/TimeAttackButton
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
	_footer_label.text = _footer_text()
	var mode_buttons: Array[Button] = [
		_classic_button, _maze_button, _time_attack_button
	]
	for index in range(mode_buttons.size()):
		_wire_mode_button(mode_buttons[index], ModeCatalog.MODES[index])
	var buttons: Array[Button] = [
		_play_button,
		_classic_button,
		_maze_button,
		_time_attack_button,
		_how_to_play_button,
		_settings_button,
		_quit_button,
	]
	FocusRing.wire_vertical(buttons)
	_wire_mode_row(mode_buttons)
	if audio != null:
		audio.wire_buttons(buttons)
	_play_button.grab_focus()


## The version declared in project.godot; empty when the project sets none.
static func project_version() -> String:
	return str(ProjectSettings.get_setting(VERSION_SETTING, "")).strip_edges()


func _footer_text() -> String:
	var hint := tr(FOOTER_HINT)
	var version := project_version()
	if version.is_empty():
		return hint
	return hint + FOOTER_VERSION_SEPARATOR + VERSION_PREFIX + version


## One mode entry: its catalog name, its toggle state and its pressed intent.
## The highlight follows current_mode, so the menu opens on the mode Play starts.
func _wire_mode_button(button: Button, mode_name: String) -> void:
	button.text = tr(ModeCatalog.display_name(mode_name))
	button.toggle_mode = true
	button.button_group = _mode_group
	button.button_pressed = ModeCatalog.resolve_mode(current_mode) == mode_name
	button.pressed.connect(_on_mode_pressed.bind(mode_name))


## The three mode entries share one row, so Left and Right walk that row while
## Up and Down leave it for Play or How to play. FocusRing keeps the Tab chain
## on the visual order from Play through the row and the rest of the menu.
func _wire_mode_row(buttons: Array[Button]) -> void:
	var count := buttons.size()
	for index in range(count):
		var button: Button = buttons[index]
		button.focus_neighbor_left = button.get_path_to(buttons[(index - 1 + count) % count])
		button.focus_neighbor_right = button.get_path_to(buttons[(index + 1) % count])
		button.focus_neighbor_top = button.get_path_to(_play_button)
		button.focus_neighbor_bottom = button.get_path_to(_how_to_play_button)


func _on_play_pressed() -> void:
	play_requested.emit(current_mode)


## A mode entry starts that mode directly and becomes the current mode, so
## coming back to the menu opens with it highlighted.
func _on_mode_pressed(mode_name: String) -> void:
	current_mode = mode_name
	mode_requested.emit(mode_name)


func _on_how_to_play_pressed() -> void:
	how_to_play_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
