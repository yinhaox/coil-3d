class_name ArenaView
extends Node3D

## Procedural arena geometry: floor slab, grid lines, four walls and obstacles
## (design/camera-and-presentation.md "墙体", "障碍", "渲染约束").
##
## Built once from ArenaData when the scene starts. Nothing here changes during
## a run, so there is no per-frame work.

const FLOOR_THICKNESS := 0.2
const OUTER_FLOOR_MARGIN := 12.0
const GRID_LINE_WIDTH := 0.03
const GRID_LINE_HEIGHT := 0.02
const WALL_HEIGHT := 1.0
const WALL_THICKNESS := 0.25
const WALL_TOP_HEIGHT := 0.05
const OBSTACLE_FOOTPRINT := 0.86
const OBSTACLE_HEIGHT := 2.0
const OBSTACLE_TOP_HEIGHT := 0.05

const FLOOR_COLOR := Color(0.05, 0.08, 0.14)
const OUTER_FLOOR_COLOR := Color(0.02, 0.03, 0.06)
const GRID_COLOR := Color(0.10, 0.30, 0.40)
const WALL_COLOR := Color(0.10, 0.20, 0.32)
const WALL_TOP_COLOR := Color(0.35, 0.90, 1.0)
const OBSTACLE_COLOR := Color(0.15, 0.22, 0.34)
const OBSTACLE_TOP_COLOR := Color(0.95, 0.55, 0.20)

var _unit_box: BoxMesh
var _arena: ArenaData


## Build every static mesh for one arena. Safe to call once per view.
func build(arena: ArenaData) -> void:
	assert(arena != null, "ArenaView requires arena data")
	_arena = arena
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_build_floor()
	_build_grid_lines()
	_build_walls()
	_build_obstacles()


func _build_floor() -> void:
	var width := float(_arena.columns) * GridSpace.CELL_SIZE
	var depth := float(_arena.rows) * GridSpace.CELL_SIZE
	_add_box(
		Vector3(width, FLOOR_THICKNESS, depth),
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0),
		FLOOR_COLOR
	)
	_add_box(
		Vector3(width + OUTER_FLOOR_MARGIN * 2.0, FLOOR_THICKNESS, depth + OUTER_FLOOR_MARGIN * 2.0),
		Vector3(0.0, -FLOOR_THICKNESS * 0.5 - 0.15, 0.0),
		OUTER_FLOOR_COLOR
	)


func _build_grid_lines() -> void:
	var width := float(_arena.columns) * GridSpace.CELL_SIZE
	var depth := float(_arena.rows) * GridSpace.CELL_SIZE
	var transforms: Array[Transform3D] = []
	for column in range(_arena.columns + 1):
		var x := (float(column) - float(_arena.columns) * 0.5) * GridSpace.CELL_SIZE
		transforms.append(Transform3D(
			Basis.from_scale(Vector3(GRID_LINE_WIDTH, GRID_LINE_HEIGHT, depth)),
			Vector3(x, GRID_LINE_HEIGHT * 0.5, 0.0)
		))
	for row in range(_arena.rows + 1):
		var z := (float(row) - float(_arena.rows) * 0.5) * GridSpace.CELL_SIZE
		transforms.append(Transform3D(
			Basis.from_scale(Vector3(width, GRID_LINE_HEIGHT, GRID_LINE_WIDTH)),
			Vector3(0.0, GRID_LINE_HEIGHT * 0.5, z)
		))
	_add_multimesh(transforms, GRID_COLOR, GRID_COLOR)


func _build_walls() -> void:
	var width := float(_arena.columns) * GridSpace.CELL_SIZE
	var depth := float(_arena.rows) * GridSpace.CELL_SIZE
	var outer_x := width * 0.5 + WALL_THICKNESS * 0.5
	var outer_z := depth * 0.5 + WALL_THICKNESS * 0.5
	var walls: Array[Transform3D] = []
	var tops: Array[Transform3D] = []
	var footprints: Array[Vector3] = [
		Vector3(width + WALL_THICKNESS * 2.0, WALL_HEIGHT, WALL_THICKNESS),
		Vector3(width + WALL_THICKNESS * 2.0, WALL_HEIGHT, WALL_THICKNESS),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, depth),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, depth),
	]
	var positions: Array[Vector3] = [
		Vector3(0.0, WALL_HEIGHT * 0.5, -outer_z),
		Vector3(0.0, WALL_HEIGHT * 0.5, outer_z),
		Vector3(-outer_x, WALL_HEIGHT * 0.5, 0.0),
		Vector3(outer_x, WALL_HEIGHT * 0.5, 0.0),
	]
	for index in range(footprints.size()):
		var footprint: Vector3 = footprints[index]
		walls.append(Transform3D(Basis.from_scale(footprint), positions[index]))
		tops.append(Transform3D(
			Basis.from_scale(Vector3(footprint.x, WALL_TOP_HEIGHT, footprint.z + 0.02)),
			positions[index] + Vector3(0.0, WALL_HEIGHT * 0.5 + WALL_TOP_HEIGHT * 0.5, 0.0)
		))
	_add_multimesh(walls, WALL_COLOR, WALL_COLOR)
	_add_multimesh(tops, WALL_TOP_COLOR, WALL_TOP_COLOR)


func _build_obstacles() -> void:
	var columns: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	for cell in _arena.obstacles:
		var center := GridSpace.cell_to_world(cell, _arena.columns, _arena.rows)
		columns.append(Transform3D(
			Basis.from_scale(Vector3(OBSTACLE_FOOTPRINT, OBSTACLE_HEIGHT, OBSTACLE_FOOTPRINT)),
			center + Vector3(0.0, OBSTACLE_HEIGHT * 0.5, 0.0)
		))
		caps.append(Transform3D(
			Basis.from_scale(Vector3(OBSTACLE_FOOTPRINT * 0.9, OBSTACLE_TOP_HEIGHT, OBSTACLE_FOOTPRINT * 0.9)),
			center + Vector3(0.0, OBSTACLE_HEIGHT + OBSTACLE_TOP_HEIGHT * 0.5, 0.0)
		))
	_add_multimesh(columns, OBSTACLE_COLOR, OBSTACLE_COLOR)
	_add_multimesh(caps, OBSTACLE_TOP_COLOR, OBSTACLE_TOP_COLOR)


func _add_box(size: Vector3, position: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _unit_box
	mesh_instance.position = position
	mesh_instance.scale = size
	mesh_instance.material_override = _material(color, color)
	add_child(mesh_instance)


func _add_multimesh(transforms: Array[Transform3D], color: Color, emission: Color) -> void:
	var mesh_instance := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _unit_box
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	mesh_instance.multimesh = multimesh
	mesh_instance.material_override = _material(color, emission)
	if transforms.is_empty():
		mesh_instance.visible = false
	add_child(mesh_instance)


func _material(color: Color, emission: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = 0.35
	return material
