class_name FocusRing
extends RefCounted

## Explicit focus order for a single-column menu (ui.md): every button wraps its
## top and bottom neighbour, so keyboard navigation never leaves the menu and
## the tab order matches the visual order. The focus style itself comes from
## AppTheme.

const FOCUSABLE := Control.FOCUS_ALL


static func wire_vertical(buttons: Array[Button]) -> void:
	var count := buttons.size()
	if count == 0:
		return
	for index in range(count):
		var button: Button = buttons[index]
		var above: Button = buttons[(index - 1 + count) % count]
		var below: Button = buttons[(index + 1) % count]
		button.focus_mode = FOCUSABLE
		button.custom_minimum_size = AppTheme.BUTTON_MINIMUM
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)
		button.focus_next = button.get_path_to(below)
		button.focus_previous = button.get_path_to(above)
