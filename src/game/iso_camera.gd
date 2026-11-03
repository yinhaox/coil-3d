class_name IsoCamera
extends Camera3D

## Fixed isometric camera (design/camera-and-presentation.md).
##
## Orthogonal projection, yaw 45 deg, pitch 35.264 deg, looking at the arena
## center. `Q`/`E` snap the yaw by 90 deg between four fixed positions; the
## wheel changes the ortho size between "whole arena fits" and twice that.
##
## The fit is the larger of the vertical projection and the horizontal
## projection divided by the viewport aspect, taken over all four yaw positions,
## and it is recomputed when the viewport is resized. That is what makes
## "相机始终能看到整个场地" true on narrow windows too, not just at 1152x648.
##
## Follow mode is a settings toggle owned by a later UI story and is not part
## of this slice.

const YAW_DEGREES := 45.0
const PITCH_DEGREES := 35.264
const QUARTER_TURN_DEGREES := 90.0
const ARENA_MARGIN_CELLS := 3.0
const MIN_ZOOM_FACTOR := 1.0
const MAX_ZOOM_FACTOR := 2.0
const ZOOM_WHEEL_STEP := 0.5
const CAMERA_DISTANCE := 40.0
const ROTATE_SMOOTHING := 14.0
const SNAP_DEGREES := 0.5
const DEFAULT_ASPECT := 1152.0 / 648.0

var _columns := 16
var _rows := 16
var _aspect := DEFAULT_ASPECT
var _fit_ortho_size := 16.0
var _ortho_size := 16.0
var _yaw_degrees := YAW_DEGREES
var _target_yaw_degrees := YAW_DEGREES


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	_aspect = _current_aspect()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_transform()


## Fit the camera to an arena and reset yaw/zoom to their defaults.
func setup(columns: int, rows: int) -> void:
	_columns = columns
	_rows = rows
	_aspect = _current_aspect()
	_fit_ortho_size = fit_ortho_size(columns, rows, _aspect)
	_ortho_size = _fit_ortho_size
	_yaw_degrees = YAW_DEGREES
	_target_yaw_degrees = YAW_DEGREES
	_apply_transform()


## Rotate the view by one quarter turn: +1 turns the camera clockwise, -1
## counter-clockwise. Only the four isometric yaws exist.
func rotate_quarter_turn(turns: int) -> void:
	_target_yaw_degrees = yaw_degrees_after_turn(_target_yaw_degrees, turns)


## Zoom by wheel notches: +1 zooms out, -1 zooms in. Values are clamped so the
## whole arena stays visible.
func zoom_notches(notches: int) -> void:
	_ortho_size = clamp_ortho_size(
		_ortho_size + ZOOM_WHEEL_STEP * float(notches), _columns, _rows, _aspect
	)


func update_view(delta_seconds: float) -> void:
	var angular_delta := deg_to_rad(_target_yaw_degrees - _yaw_degrees)
	if absf(angular_delta) > deg_to_rad(SNAP_DEGREES):
		var weight := 1.0 - exp(-ROTATE_SMOOTHING * maxf(delta_seconds, 0.0))
		_yaw_degrees = rad_to_deg(lerp_angle(
			deg_to_rad(_yaw_degrees), deg_to_rad(_target_yaw_degrees), weight
		))
	else:
		_yaw_degrees = _target_yaw_degrees
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			rotate_quarter_turn(-1)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_E:
			rotate_quarter_turn(1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_notches(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_notches(1)
			get_viewport().set_input_as_handled()


func _on_viewport_resized() -> void:
	var was_fit := is_equal_approx(_ortho_size, _fit_ortho_size)
	_aspect = _current_aspect()
	_fit_ortho_size = fit_ortho_size(_columns, _rows, _aspect)
	if was_fit:
		_ortho_size = _fit_ortho_size
	else:
		_ortho_size = clampf(_ortho_size, _fit_ortho_size, _fit_ortho_size * MAX_ZOOM_FACTOR)
	_apply_transform()


func _current_aspect() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return DEFAULT_ASPECT
	var visible := viewport.get_visible_rect().size
	if visible.y <= 0.0:
		return DEFAULT_ASPECT
	return visible.x / visible.y


func _apply_transform() -> void:
	var yaw := deg_to_rad(_yaw_degrees)
	var pitch := deg_to_rad(PITCH_DEGREES)
	var horizontal := cos(pitch) * CAMERA_DISTANCE
	position = Vector3(sin(yaw) * horizontal, sin(pitch) * CAMERA_DISTANCE, cos(yaw) * horizontal)
	look_at(Vector3.ZERO, Vector3.UP)
	size = _ortho_size


## Ortho height that fits the whole arena with `ARENA_MARGIN_CELLS` of margin,
## taken over all four quarter-turn yaws and both viewport axes.
static func fit_ortho_size(columns: int, rows: int, aspect: float = DEFAULT_ASPECT) -> float:
	var safe_aspect := maxf(aspect, 0.1)
	var pitch := deg_to_rad(PITCH_DEGREES)
	var widest := 0.0
	for turn in range(4):
		var yaw := deg_to_rad(YAW_DEGREES + QUARTER_TURN_DEGREES * float(turn))
		var span_x := absf(sin(yaw)) * float(columns) + absf(cos(yaw)) * float(rows)
		var span_y := absf(cos(yaw)) * float(columns) + absf(sin(yaw)) * float(rows)
		var vertical := span_x * sin(pitch) + ARENA_MARGIN_CELLS
		var horizontal := (span_y + ARENA_MARGIN_CELLS) / safe_aspect
		widest = maxf(widest, maxf(vertical, horizontal))
	return widest


## Clamp an ortho size to the zoom range that still shows the whole arena.
static func clamp_ortho_size(
	value: float, columns: int, rows: int, aspect: float = DEFAULT_ASPECT
) -> float:
	var fit := fit_ortho_size(columns, rows, aspect)
	return clampf(value, fit * MIN_ZOOM_FACTOR, fit * MAX_ZOOM_FACTOR)


## Yaw after a number of quarter turns, normalized to 0..360.
static func yaw_degrees_after_turn(current_degrees: float, turns: int) -> float:
	return fposmod(current_degrees + QUARTER_TURN_DEGREES * float(turns), 360.0)
