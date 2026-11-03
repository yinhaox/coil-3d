extends RefCounted

## Test helper that injects real keyboard events through the Input singleton.
##
## Usage from tests/run_tests.gd:
##
##   InputEvents.tap_key(KEY_LEFT)
##   InputEvents.press_action("snake_pause")
##   InputEvents.release_action("snake_pause")
##
## Every call queues one event with Input.parse_input_event() and delivers it
## with Input.flush_buffered_events(), so the game sees the same InputEventKey
## objects a keyboard would produce. Arrow keys can be passed directly; an
## action name is resolved to the arrow/WASD key bound in InputMap, which keeps
## the test honest about the runtime registration in GameController.

const NO_KEY: Key = KEY_NONE


## Press `keycode` (for example KEY_LEFT) and deliver it immediately.
static func press_key(keycode: Key) -> bool:
	return _send_key(keycode, true)


## Release `keycode` and deliver it immediately.
static func release_key(keycode: Key) -> bool:
	return _send_key(keycode, false)


## Press and release `keycode`, flushing after each event.
static func tap_key(keycode: Key) -> bool:
	return press_key(keycode) and release_key(keycode)


## Press the key currently bound to `action` and deliver it immediately.
static func press_action(action: StringName) -> bool:
	return _send_key(key_for_action(action), true)


## Release the key currently bound to `action` and deliver it immediately.
static func release_action(action: StringName) -> bool:
	return _send_key(key_for_action(action), false)


## Press and release the key currently bound to `action`.
static func tap_action(action: StringName) -> bool:
	return press_action(action) and release_action(action)


## First physical key bound to `action`, or KEY_NONE when the action is unknown
## or only bound to non-keyboard events.
static func key_for_action(action: StringName) -> Key:
	if not InputMap.has_action(action):
		return NO_KEY
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode != NO_KEY:
			return event.physical_keycode
	return NO_KEY


## Flush every event queued so far, so callers can batch parse_input_event().
static func flush() -> void:
	Input.flush_buffered_events()


static func _send_key(keycode: Key, pressed: bool) -> bool:
	if keycode == NO_KEY:
		push_error("input_events: no keyboard key bound for the requested input")
		return false
	Input.parse_input_event(_key_event(keycode, pressed))
	flush()
	return true


static func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	return event
