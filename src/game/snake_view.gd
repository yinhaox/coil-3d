class_name SnakeView
extends Node3D

## Procedural snake presentation (design/camera-and-presentation.md "蛇"):
## one MultiMeshInstance3D for every body segment plus a separate head sphere
## with two eyes. Positions interpolate between the previous and the current
## logic cells; the head yaw tweens over `min(0.08 s, step_duration)`.
##
## This view only reads snapshots pushed by the controller. It never changes
## logic state (design/architecture.md layer rule 2).

const SEGMENT_SIZE := Vector3(0.72, 0.50, 0.72)
const SEGMENT_HEIGHT := 0.25
const TAIL_SCALE := 0.85
const HEAD_RADIUS := 0.42
const HEAD_HEIGHT := 0.42
const EYE_RADIUS := 0.07
const EYE_FORWARD := 0.36
const EYE_SIDE := 0.16
const EYE_HEIGHT := 0.10
const TURN_TWEEN_SECONDS := 0.10
const EAT_PULSE_SECONDS := 0.15
const EAT_PULSE_SCALE := 0.20

const HEAD_COLOR := Color(0.25, 0.90, 1.0)
const BODY_HEAD_COLOR := Color(0.15, 0.90, 1.0)
const BODY_TAIL_COLOR := Color(0.04, 0.30, 0.48)
const EYE_COLOR := Color(0.02, 0.05, 0.08)

var _columns := 16
var _rows := 16
var _previous_cells: Array[Vector2i] = []
var _current_cells: Array[Vector2i] = []
var _alpha := 1.0
var _previous_yaw := 0.0
var _current_yaw := 0.0
var _turn_elapsed := 0.0
var _turn_duration := TURN_TWEEN_SECONDS
var _turn_held := false
var _pulse_elapsed := 0.0
var _body_multimesh: MultiMesh
var _head: Node3D


func _ready() -> void:
	_build_body()
	_build_head()


func configure(columns: int, rows: int) -> void:
	_columns = columns
	_rows = rows


## Push one logic step: the cells before it, after it, and both directions.
func apply_step(
	previous_cells: Array[Vector2i],
	current_cells: Array[Vector2i],
	previous_direction: Vector2i,
	direction: Vector2i,
	step_duration_seconds: float,
	ate: bool = false
) -> void:
	_previous_cells = previous_cells
	_current_cells = current_cells
	_previous_yaw = yaw_for_direction(previous_direction)
	_current_yaw = yaw_for_direction(direction)
	_turn_duration = turn_tween_seconds(step_duration_seconds)
	_turn_elapsed = _turn_duration if is_equal_approx(_previous_yaw, _current_yaw) else 0.0
	_turn_held = false
	if ate:
		_pulse_elapsed = EAT_PULSE_SECONDS
	_body_multimesh.instance_count = _current_cells.size()
	_apply_segment_colors()


## Set the interpolation fraction for the current logic step, in 0..1.
func set_interpolation_alpha(alpha: float) -> void:
	_alpha = clampf(alpha, 0.0, 1.0)


## Hold the head turn tween at a fixed fraction, for a staged screenshot.
func stage_turn_progress(progress: float) -> void:
	_turn_held = true
	_turn_elapsed = _turn_duration * clampf(progress, 0.0, 1.0)


func update_view(delta_seconds: float) -> void:
	if not _turn_held and _turn_duration > 0.0:
		_turn_elapsed = minf(_turn_elapsed + maxf(delta_seconds, 0.0), _turn_duration)
	if _pulse_elapsed > 0.0:
		_pulse_elapsed = maxf(_pulse_elapsed - maxf(delta_seconds, 0.0), 0.0)
	var turn_ratio := 1.0 if _turn_duration <= 0.0 else _turn_elapsed / _turn_duration
	_update_head(turn_ratio)
	_update_body()


func _update_head(turn_ratio: float) -> void:
	var head_position := segment_world_position(
		0, _previous_cells, _current_cells, _alpha, _columns, _rows
	)
	_head.position = Vector3(head_position.x, HEAD_HEIGHT, head_position.z)
	_head.rotation.y = lerp_angle(_previous_yaw, _current_yaw, turn_ratio)
	var pulse := 1.0
	if _pulse_elapsed > 0.0:
		var phase := 1.0 - _pulse_elapsed / EAT_PULSE_SECONDS
		pulse += EAT_PULSE_SCALE * sin(PI * phase)
	_head.scale = Vector3.ONE * pulse


func _update_body() -> void:
	for index in range(_current_cells.size()):
		var position := segment_world_position(
			index, _previous_cells, _current_cells, _alpha, _columns, _rows
		)
		var scale := Vector3.ONE * _segment_scale(index)
		_body_multimesh.set_instance_transform(
			index,
			Transform3D(Basis.from_scale(scale), position + Vector3(0.0, SEGMENT_HEIGHT, 0.0))
		)


func _apply_segment_colors() -> void:
	var last_index := maxi(_current_cells.size() - 1, 1)
	for index in range(_current_cells.size()):
		var ratio := float(index) / float(last_index)
		_body_multimesh.set_instance_color(index, BODY_HEAD_COLOR.lerp(BODY_TAIL_COLOR, ratio))


func _segment_scale(index: int) -> float:
	if index == _current_cells.size() - 1 and _current_cells.size() > 1:
		return TAIL_SCALE
	return 1.0


func _build_body() -> void:
	_body_multimesh = MultiMesh.new()
	_body_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_body_multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = SEGMENT_SIZE
	_body_multimesh.mesh = box
	var body_instance := MultiMeshInstance3D.new()
	body_instance.multimesh = _body_multimesh
	var body_material := StandardMaterial3D.new()
	body_material.vertex_color_use_as_albedo = true
	body_material.roughness = 0.55
	body_material.metallic = 0.05
	body_instance.material_override = body_material
	add_child(body_instance)


func _build_head() -> void:
	_head = Node3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = HEAD_RADIUS
	sphere.height = HEAD_RADIUS * 2.0
	var head_mesh := MeshInstance3D.new()
	head_mesh.mesh = sphere
	head_mesh.material_override = _emissive_material(HEAD_COLOR, HEAD_COLOR, 0.25)
	_head.add_child(head_mesh)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_sphere := SphereMesh.new()
		eye_sphere.radius = EYE_RADIUS
		eye_sphere.height = EYE_RADIUS * 2.0
		eye.mesh = eye_sphere
		eye.position = Vector3(EYE_SIDE * side, EYE_HEIGHT, -EYE_FORWARD)
		eye.material_override = _emissive_material(EYE_COLOR, EYE_COLOR, 0.0)
		_head.add_child(eye)
	add_child(_head)


func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


## Turn tween duration: the issue's 0.1-0.15 s, shortened to the step duration
## on fast steps so the head never turns past a cell (camera-and-presentation.md
## "Edge cases").
static func turn_tween_seconds(step_duration_seconds: float) -> float:
	if step_duration_seconds <= 0.0:
		return 0.0
	return minf(TURN_TWEEN_SECONDS, step_duration_seconds)


## Local -Z of the head points at this direction (the eyes sit on -Z).
static func yaw_for_direction(direction: Vector2i) -> float:
	return atan2(-float(direction.x), -float(direction.y))


## World position of one segment at `alpha` between its previous and current
## cell. A segment beyond the previous body is the new tail and stays put.
static func segment_world_position(
	index: int,
	previous_cells: Array[Vector2i],
	current_cells: Array[Vector2i],
	alpha: float,
	columns: int,
	rows: int
) -> Vector3:
	if index < 0 or index >= current_cells.size():
		return Vector3.ZERO
	var target := GridSpace.cell_to_world(current_cells[index], columns, rows)
	if index < previous_cells.size():
		var start := GridSpace.cell_to_world(previous_cells[index], columns, rows)
		return start.lerp(target, clampf(alpha, 0.0, 1.0))
	return target
