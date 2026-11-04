class_name SettingsScreen
extends CanvasLayer

## Audio settings overlay (design/ux-and-persistence.md screen 7, audio-only
## slice): master volume, SFX volume and a mute switch.
##
## The screen reads and writes the shared `SaveStore` and asks `AudioDirector`
## to push the volumes onto the Master/SFX buses, so a change is audible before
## the save timer fires. `Esc` and the Back button both close the overlay and
## return to whichever screen opened it; the owner frees the node.

signal closed

const SLIDER_MIN := 0.0
const SLIDER_MAX := 100.0
const SAVE_DEBOUNCE_SECONDS := 0.5
const SLIDER_FOCUS := Control.FOCUS_ALL

var store: SaveStore = null
var audio: AudioDirector = null

var _save_timer: Timer
var _syncing := false
var _restore_master := SaveStore.DEFAULT_MASTER_VOLUME
var _restore_sfx := SaveStore.DEFAULT_SFX_VOLUME

@onready var _root: Control = $Root
@onready var _title_label: Label = $Root/Center/Panel/Margin/VBox/TitleLabel
@onready var _focus_hint_label: Label = $Root/Center/Panel/Margin/VBox/FocusHintLabel
@onready var _master_label: Label = $Root/Center/Panel/Margin/VBox/MasterRow/MasterLabel
@onready var _master_slider: HSlider = $Root/Center/Panel/Margin/VBox/MasterRow/MasterSlider
@onready var _master_value: Label = $Root/Center/Panel/Margin/VBox/MasterRow/MasterValueLabel
@onready var _sfx_label: Label = $Root/Center/Panel/Margin/VBox/SfxRow/SfxLabel
@onready var _sfx_slider: HSlider = $Root/Center/Panel/Margin/VBox/SfxRow/SfxSlider
@onready var _sfx_value: Label = $Root/Center/Panel/Margin/VBox/SfxRow/SfxValueLabel
@onready var _mute_check: CheckButton = $Root/Center/Panel/Margin/VBox/MuteCheck
@onready var _back_button: Button = $Root/Center/Panel/Margin/VBox/BackButton


func _ready() -> void:
	if store == null:
		store = SaveStore.new()
	_root.theme = AppTheme.shared()
	_title_label.text = tr("Settings")
	_master_label.text = tr("Master volume")
	_sfx_label.text = tr("SFX volume")
	_mute_check.text = tr("Mute")
	_back_button.text = tr("Back")
	_create_save_timer()
	_sync_from_store()
	_wire_focus()
	_wire_controls()
	if audio != null:
		audio.wire_buttons([_mute_check, _back_button])


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


## Close the overlay: flush the debounced save first, then let the owner drop
## the node so the previous screen is visible again.
func close() -> void:
	_flush_save()
	closed.emit()


func master_percent() -> float:
	return _master_slider.value


func sfx_percent() -> float:
	return _sfx_slider.value


func is_muted() -> bool:
	return _mute_check.button_pressed


func _create_save_timer() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SECONDS
	add_child(_save_timer)
	_save_timer.timeout.connect(_flush_save)


func _wire_controls() -> void:
	_master_slider.value_changed.connect(_on_slider_changed)
	_sfx_slider.value_changed.connect(_on_slider_changed)
	_mute_check.toggled.connect(_on_mute_toggled)
	_back_button.pressed.connect(close)


## Explicit keyboard order: both sliders, the mute switch, then Back, wrapping.
## A slider has no focus stylebox in the default theme, so the accent hint label
## names the focused control: that is the visible keyboard focus state.
func _wire_focus() -> void:
	var chain: Array[Control] = [_master_slider, _sfx_slider, _mute_check, _back_button]
	var keys: Array[String] = ["Master volume", "SFX volume", "Mute", "Back"]
	var count := chain.size()
	for index in range(count):
		var control := chain[index]
		var next := chain[(index + 1) % count]
		var previous := chain[(index - 1 + count) % count]
		control.focus_mode = SLIDER_FOCUS
		control.focus_next = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_entered.connect(_show_focus_hint.bind(keys[index]))
	_master_slider.grab_focus()
	_show_focus_hint(keys[0])


func _show_focus_hint(key: String) -> void:
	if _focus_hint_label != null:
		_focus_hint_label.text = tr(key)


func _sync_from_store() -> void:
	_syncing = true
	_master_slider.value = store.master_volume() * SLIDER_MAX
	_sfx_slider.value = store.sfx_volume() * SLIDER_MAX
	_mute_check.button_pressed = (
		store.master_volume() <= SaveStore.MIN_VOLUME
		and store.sfx_volume() <= SaveStore.MIN_VOLUME
	)
	_syncing = false
	_update_value_labels()
	AudioDirector.apply_volumes(store.master_volume(), store.sfx_volume())


func _on_slider_changed(_value: float) -> void:
	if _syncing:
		return
	_apply(_master_slider.value / SLIDER_MAX, _sfx_slider.value / SLIDER_MAX)
	_mute_check.set_pressed_no_signal(_volumes_are_zero())


func _on_mute_toggled(pressed: bool) -> void:
	if _syncing:
		return
	if pressed:
		_remember_unmuted_volumes()
		_apply(SaveStore.MIN_VOLUME, SaveStore.MIN_VOLUME)
	else:
		_apply(_restore_master, _restore_sfx)


func _apply(master_volume: float, sfx_volume: float) -> void:
	store.set_master_volume(master_volume)
	store.set_sfx_volume(sfx_volume)
	AudioDirector.apply_volumes(store.master_volume(), store.sfx_volume())
	_syncing = true
	_master_slider.value = store.master_volume() * SLIDER_MAX
	_sfx_slider.value = store.sfx_volume() * SLIDER_MAX
	_syncing = false
	_update_value_labels()
	if _save_timer != null:
		_save_timer.start()


func _remember_unmuted_volumes() -> void:
	if store.master_volume() > SaveStore.MIN_VOLUME:
		_restore_master = store.master_volume()
	if store.sfx_volume() > SaveStore.MIN_VOLUME:
		_restore_sfx = store.sfx_volume()


func _volumes_are_zero() -> bool:
	return (
		store.master_volume() <= SaveStore.MIN_VOLUME
		and store.sfx_volume() <= SaveStore.MIN_VOLUME
	)


func _update_value_labels() -> void:
	_master_value.text = "%d" % roundi(_master_slider.value)
	_sfx_value.text = "%d" % roundi(_sfx_slider.value)


## Save on Back/Esc even when the debounce timer has not fired yet.
func _flush_save() -> void:
	if _save_timer != null:
		_save_timer.stop()
	if store == null or store.is_read_only():
		return
	if not store.save():
		push_warning("settings_screen: save failed: %s" % store.last_error())
