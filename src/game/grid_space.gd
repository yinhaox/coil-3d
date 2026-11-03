class_name GridSpace
extends RefCounted

## Presentation-layer mapping between logic grid cells and world positions.
##
## Logic cells are unitless `Vector2i` (design/core-rules.md rule 1); this is the
## only place they become world units. Cell (0, 0) is the north-west corner and
## the arena is centered on the world origin, so a 16x16 arena spans
## -8..8 on X and Z. The X axis points east, the Z axis points south.

const CELL_SIZE := 1.0


## Center of one logic cell in world space, at floor height (y = 0).
static func cell_to_world(cell: Vector2i, columns: int, rows: int) -> Vector3:
	return Vector3(
		(float(cell.x) + 0.5 - float(columns) * 0.5) * CELL_SIZE,
		0.0,
		(float(cell.y) + 0.5 - float(rows) * 0.5) * CELL_SIZE
	)


## Cell that contains a world position on the floor plane. Returns (-1, -1)
## when the position is outside the arena.
static func world_to_cell(world: Vector3, columns: int, rows: int) -> Vector2i:
	var cell := Vector2i(
		int(floorf(world.x / CELL_SIZE + float(columns) * 0.5)),
		int(floorf(world.z / CELL_SIZE + float(rows) * 0.5))
	)
	if cell.x < 0 or cell.x >= columns or cell.y < 0 or cell.y >= rows:
		return Vector2i(-1, -1)
	return cell
