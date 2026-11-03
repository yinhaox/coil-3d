class_name FoodView
extends Node3D

## Procedural food presentation (design/camera-and-presentation.md "食物"):
## a faceted orange polyhedron that spins and bobs. Positions come from the
## logic session; this view only animates them.

const FOOD_RADIUS := 0.32
const FOOD_BASE_HEIGHT := 0.45
const FOOD_BOB_AMPLITUDE := 0.12
const FOOD_BOB_HZ := 1.0
const FOOD_SPIN_DEGREES_PER_SECOND := 30.0
const FOOD_RADIAL_SEGMENTS := 6
const FOOD_RINGS := 3
const FOOD_COLOR := Color(1.0, 0.55, 0.12)

var _columns := 16
var _rows := 16
var _cells: Array[Vector2i] = []
var _elapsed := 0.0
var _instance: MultiMeshInstance3D
var _multimesh: MultiMesh


func _ready() -> void:
	_build_mesh()


func configure(columns: int, rows: int) -> void:
	_columns = columns
	_rows = rows


## Replace the food cells; empty hides the whole view.
func set_food_cells(cells: Array[Vector2i]) -> void:
	_cells = cells
	_multimesh.instance_count = cells.size()
	_instance.visible = not cells.is_empty()
	if not cells.is_empty():
		update_view(0.0)


func update_view(delta_seconds: float) -> void:
	_elapsed += maxf(delta_seconds, 0.0)
	if _cells.is_empty():
		return
	var bob := sin(TAU * FOOD_BOB_HZ * _elapsed) * FOOD_BOB_AMPLITUDE
	var spin := deg_to_rad(FOOD_SPIN_DEGREES_PER_SECOND * _elapsed)
	for index in range(_cells.size()):
		var center := GridSpace.cell_to_world(_cells[index], _columns, _rows)
		var position := center + Vector3(0.0, FOOD_BASE_HEIGHT + bob, 0.0)
		_multimesh.set_instance_transform(
			index, Transform3D(Basis(Vector3.UP, spin), position)
		)


func _build_mesh() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = FOOD_RADIUS
	mesh.height = FOOD_RADIUS * 2.0
	mesh.radial_segments = FOOD_RADIAL_SEGMENTS
	mesh.rings = FOOD_RINGS
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = mesh
	_instance = MultiMeshInstance3D.new()
	_instance.multimesh = _multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = FOOD_COLOR
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = FOOD_COLOR
	material.emission_energy_multiplier = 1.6
	_instance.material_override = material
	add_child(_instance)
