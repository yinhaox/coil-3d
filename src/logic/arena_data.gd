class_name ArenaData
extends RefCounted

## Immutable arena definition and loader for `assets/data/arenas/*.json`.
##
## Owns the data contract of design/game-modes.md and
## `assets/data/arenas/arena.schema.md`: parsing, validation and readable,
## file-prefixed errors. Pure data: no scene tree, no input, no rendering and
## no disk writes.

const SCHEMA_VERSION := 1

const MODE_CLASSIC := "classic"
const MODE_MAZE := "maze"
const MODE_TIME_ATTACK := "time_attack"
const SUPPORTED_MODES: Array[String] = [MODE_CLASSIC, MODE_MAZE, MODE_TIME_ATTACK]

const MIN_SIZE := 4
const MAX_SIZE := 16
const MIN_FOOD_MAX := 1
const MAX_FOOD_MAX := 8
const MIN_INITIAL_SPEED := 4.0
const MAX_INITIAL_SPEED := 10.0
const MAX_SPEED_LIMIT := 20.0
const MAX_TIME_LIMIT_SECONDS := 600.0

## Core-rules initial snake length, in segments. SnakeSession reads the same
## constant so the start-space check and the first body always agree.
const INITIAL_SNAKE_LENGTH := 4
const START_SPACE_CELLS := INITIAL_SNAKE_LENGTH - 1

const DIRECTION_VECTORS := {
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
}

const TOP_LEVEL_KEYS: Array[String] = [
	"schema_version",
	"id",
	"mode",
	"size",
	"obstacles",
	"food_max",
	"initial_speed_cells_per_second",
	"max_speed_cells_per_second",
	"time_limit_seconds",
	"start",
]
const SIZE_KEYS: Array[String] = ["columns", "rows"]
const START_KEYS: Array[String] = ["cell", "direction"]

const ID_PATTERN := "^[a-z0-9]+(?:-[a-z0-9]+)*$"

var schema_version: int = SCHEMA_VERSION
var id: String = ""
var mode: String = ""
var columns: int = 0
var rows: int = 0
var obstacles: Array[Vector2i] = []
var food_max: int = 0
var initial_speed: float = 0.0
var max_speed: float = 0.0
var has_time_limit: bool = false
var time_limit_seconds: float = 0.0
var start_cell: Vector2i = Vector2i.ZERO
var start_direction: Vector2i = Vector2i(1, 0)
var start_direction_name: String = "east"


class ParseResult:
	var arena: ArenaData = null
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	func is_ok() -> bool:
		return errors.is_empty() and arena != null


class LoadResult:
	var arenas: Array[ArenaData] = []
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	func is_ok() -> bool:
		return errors.is_empty()

	## First arena for the mode in file-name order, as the mode cards expect.
	func arena_for_mode(mode_name: String) -> ArenaData:
		for arena in arenas:
			if arena.mode == mode_name:
				return arena
		return null


class _Validator:
	var source: String
	var data: Dictionary
	var field_prefix: String
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	func _init(source_name: String, source_data: Dictionary, prefix: String = "") -> void:
		source = source_name
		data = source_data
		field_prefix = prefix

	func fail(message: String) -> void:
		errors.append("%s: %s" % [source, message])

	func warn(message: String) -> void:
		warnings.append("%s: %s" % [source, message])

	func has_errors() -> bool:
		return not errors.is_empty()

	func field(key: String) -> String:
		return field_prefix + key

	func absorb(other: _Validator) -> void:
		errors.append_array(other.errors)
		warnings.append_array(other.warnings)

	func read_int(key: String) -> int:
		if not data.has(key):
			fail("missing required key '%s'" % field(key))
			return 0
		var value: Variant = data[key]
		if typeof(value) == TYPE_INT:
			return int(value)
		if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))):
			return int(roundf(float(value)))
		fail("'%s' must be an integer, got %s" % [field(key), str(value)])
		return 0

	func read_float(key: String) -> float:
		if not data.has(key):
			fail("missing required key '%s'" % field(key))
			return 0.0
		var value: Variant = data[key]
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			fail("'%s' must be a number, got %s" % [field(key), str(value)])
			return 0.0
		return float(value)

	func read_string(key: String) -> String:
		if not data.has(key):
			fail("missing required key '%s'" % field(key))
			return ""
		var value: Variant = data[key]
		if typeof(value) != TYPE_STRING:
			fail("'%s' must be a string, got %s" % [field(key), str(value)])
			return ""
		return String(value)


## Parse one JSON text. `source` labels the errors and is usually a file name.
static func from_json_text(text: String, source: String) -> ParseResult:
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		var malformed := ParseResult.new()
		malformed.errors.append(
			"%s:%d: %s" % [source, json.get_error_line(), json.get_error_message()]
		)
		return malformed
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		var not_an_object := ParseResult.new()
		not_an_object.errors.append(
			"%s: top-level JSON value must be an object, got %s" % [source, str(parsed)]
		)
		return not_an_object
	return from_dict(parsed, source)


## Validate one already parsed JSON object.
static func from_dict(source_data: Dictionary, source: String) -> ParseResult:
	var result := ParseResult.new()
	var validator := _Validator.new(source, source_data)
	var arena := ArenaData.new()
	_warn_unknown_keys(validator, source_data, TOP_LEVEL_KEYS, "")
	_parse_schema_version(validator, arena)
	_parse_identity(validator, arena)
	if _parse_size(validator, arena):
		_parse_speed(validator, arena)
		_parse_food_limit(validator, arena)
		_parse_time_limit(validator, arena)
		if _parse_start(validator, arena):
			_parse_obstacles(validator, arena)
			_validate_start_space(validator, arena)
	result.errors = validator.errors
	result.warnings = validator.warnings
	if not validator.has_errors():
		result.arena = arena
	return result


## Load one arena file. Missing or unreadable files become readable errors.
static func load_file(path: String) -> ParseResult:
	if not FileAccess.file_exists(path):
		var missing := ParseResult.new()
		missing.errors.append("%s: file not found" % path)
		return missing
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var unreadable := ParseResult.new()
		unreadable.errors.append(
			"%s: cannot read file (error %d)" % [path, FileAccess.get_open_error()]
		)
		return unreadable
	var text := file.get_as_text()
	file.close()
	return from_json_text(text, path.get_file())


## Load every `*.json` in the directory in file-name order.
##
## A bad file is reported in `errors` and does not stop the others. Duplicate
## ids are rejected (data rules); a mode provided by more than one file only
## warns, because issue #3 requires two Classic arenas in 1.0.
static func load_directory(directory_path: String) -> LoadResult:
	var result := LoadResult.new()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		result.errors.append(
			"%s: cannot open arena directory (error %d)"
			% [directory_path, DirAccess.get_open_error()]
		)
		return result
	var ids_by_file: Dictionary = {}
	var files_by_mode: Dictionary = {}
	for file_name in _arena_file_names(directory):
		_merge_arena_file(result, directory_path, file_name, ids_by_file, files_by_mode)
	return result


static func _arena_file_names(directory: DirAccess) -> Array[String]:
	var file_names: Array[String] = []
	for file_name: String in directory.get_files():
		if file_name.ends_with(".json"):
			file_names.append(file_name)
	file_names.sort()
	return file_names


static func _merge_arena_file(
	result: LoadResult,
	directory_path: String,
	file_name: String,
	ids_by_file: Dictionary,
	files_by_mode: Dictionary
) -> void:
	var parsed := load_file(directory_path.path_join(file_name))
	for warning in parsed.warnings:
		result.warnings.append(warning)
	if not parsed.is_ok():
		for message in parsed.errors:
			result.errors.append(message)
		return
	var arena: ArenaData = parsed.arena
	if ids_by_file.has(arena.id):
		result.errors.append(
			"%s: duplicate id '%s'; already defined by %s"
			% [file_name, arena.id, ids_by_file[arena.id]]
		)
		return
	ids_by_file[arena.id] = file_name
	result.arenas.append(arena)
	if files_by_mode.has(arena.mode):
		result.warnings.append(
			"%s: mode '%s' is also provided by %s; the mode list uses the first file by name"
			% [file_name, arena.mode, files_by_mode[arena.mode]]
		)
	else:
		files_by_mode[arena.mode] = file_name


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows


func has_obstacle(cell: Vector2i) -> bool:
	return obstacles.has(cell)


func total_cells() -> int:
	return columns * rows


static func _parse_schema_version(validator: _Validator, arena: ArenaData) -> void:
	var version := validator.read_int("schema_version")
	if version == 0 and validator.has_errors():
		return
	arena.schema_version = version
	if version != SCHEMA_VERSION:
		validator.fail(
			"'schema_version' must be %d, got %d" % [SCHEMA_VERSION, version]
		)


static func _parse_identity(validator: _Validator, arena: ArenaData) -> void:
	arena.id = validator.read_string("id")
	if not arena.id.is_empty() and not _is_kebab_case(arena.id):
		validator.fail(
			"'id' must be kebab-case (lowercase letters, digits, single dashes), got '%s'"
			% arena.id
		)
	arena.mode = validator.read_string("mode")
	if not arena.mode.is_empty() and not SUPPORTED_MODES.has(arena.mode):
		validator.fail(
			"'mode' must be one of %s, got '%s'"
			% [", ".join(SUPPORTED_MODES), arena.mode]
		)


static func _parse_size(validator: _Validator, arena: ArenaData) -> bool:
	if not validator.data.has("size"):
		validator.fail("missing required key 'size'")
		return false
	var value: Variant = validator.data["size"]
	if typeof(value) != TYPE_DICTIONARY:
		validator.fail("'size' must be an object with columns and rows, got %s" % str(value))
		return false
	var size_data: Dictionary = value
	var size_validator := _Validator.new(validator.source, size_data, "size.")
	_warn_unknown_keys(size_validator, size_data, SIZE_KEYS, "size.")
	arena.columns = size_validator.read_int("columns")
	arena.rows = size_validator.read_int("rows")
	if not size_validator.has_errors():
		_validate_size_axis(size_validator, "columns", arena.columns)
		_validate_size_axis(size_validator, "rows", arena.rows)
	validator.absorb(size_validator)
	return not size_validator.has_errors()


static func _validate_size_axis(validator: _Validator, key: String, value: int) -> void:
	if value < MIN_SIZE or value > MAX_SIZE:
		validator.fail(
			"'%s' must be between %d and %d cells, got %d"
			% [validator.field(key), MIN_SIZE, MAX_SIZE, value]
		)


static func _parse_speed(validator: _Validator, arena: ArenaData) -> void:
	arena.initial_speed = validator.read_float("initial_speed_cells_per_second")
	arena.max_speed = validator.read_float("max_speed_cells_per_second")
	if validator.has_errors():
		return
	if arena.initial_speed < MIN_INITIAL_SPEED or arena.initial_speed > MAX_INITIAL_SPEED:
		validator.fail(
			"'initial_speed_cells_per_second' must be between %.1f and %.1f cells/s, got %s"
			% [MIN_INITIAL_SPEED, MAX_INITIAL_SPEED, str(arena.initial_speed)]
		)
	if arena.max_speed > MAX_SPEED_LIMIT:
		validator.fail(
			"'max_speed_cells_per_second' must be at most %.1f cells/s, got %s"
			% [MAX_SPEED_LIMIT, str(arena.max_speed)]
		)
	elif arena.max_speed < arena.initial_speed:
		validator.fail(
			"'max_speed_cells_per_second' (%s) must be at least the initial speed (%s)"
			% [str(arena.max_speed), str(arena.initial_speed)]
		)


static func _parse_food_limit(validator: _Validator, arena: ArenaData) -> void:
	arena.food_max = validator.read_int("food_max")
	if validator.has_errors():
		return
	if arena.food_max < MIN_FOOD_MAX or arena.food_max > MAX_FOOD_MAX:
		validator.fail(
			"'food_max' must be between %d and %d items, got %d"
			% [MIN_FOOD_MAX, MAX_FOOD_MAX, arena.food_max]
		)


static func _parse_time_limit(validator: _Validator, arena: ArenaData) -> void:
	if not validator.data.has("time_limit_seconds"):
		validator.fail("missing required key 'time_limit_seconds' (seconds or null)")
		return
	var raw: Variant = validator.data["time_limit_seconds"]
	if raw == null:
		if arena.mode == MODE_TIME_ATTACK:
			validator.fail("mode 'time_attack' requires a time_limit_seconds value")
		return
	if arena.mode != MODE_TIME_ATTACK:
		validator.fail("'time_limit_seconds' is only allowed for mode 'time_attack'")
		return
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		validator.fail(
			"'time_limit_seconds' must be a number of seconds or null, got %s" % str(raw)
		)
		return
	var seconds := float(raw)
	if seconds <= 0.0 or seconds > MAX_TIME_LIMIT_SECONDS:
		validator.fail(
			"'time_limit_seconds' must be between 0 and %d seconds, got %s"
			% [int(MAX_TIME_LIMIT_SECONDS), str(seconds)]
		)
		return
	arena.has_time_limit = true
	arena.time_limit_seconds = seconds


static func _parse_start(validator: _Validator, arena: ArenaData) -> bool:
	if not validator.data.has("start"):
		validator.fail("missing required key 'start'")
		return false
	var value: Variant = validator.data["start"]
	if typeof(value) != TYPE_DICTIONARY:
		validator.fail("'start' must be an object with cell and direction, got %s" % str(value))
		return false
	var start_data: Dictionary = value
	var start_validator := _Validator.new(validator.source, start_data, "start.")
	_warn_unknown_keys(start_validator, start_data, START_KEYS, "start.")
	if not start_data.has("cell"):
		start_validator.fail("missing required key 'start.cell'")
	else:
		arena.start_cell = _read_cell(start_validator, start_data["cell"], "start.cell")
	arena.start_direction_name = start_validator.read_string("direction")
	if not arena.start_direction_name.is_empty():
		if DIRECTION_VECTORS.has(arena.start_direction_name):
			arena.start_direction = DIRECTION_VECTORS[arena.start_direction_name]
		else:
			start_validator.fail(
				"'start.direction' must be one of %s, got '%s'"
				% [", ".join(DIRECTION_VECTORS.keys()), arena.start_direction_name]
			)
	if not start_validator.has_errors() and not arena.is_inside(arena.start_cell):
		start_validator.fail("'start.cell' [%d, %d] is outside the %dx%d arena" % [
			arena.start_cell.x, arena.start_cell.y, arena.columns, arena.rows
		])
	validator.absorb(start_validator)
	return not start_validator.has_errors()


static func _parse_obstacles(validator: _Validator, arena: ArenaData) -> void:
	if not validator.data.has("obstacles"):
		validator.fail("missing required key 'obstacles' (array of [x, z] cells)")
		return
	var value: Variant = validator.data["obstacles"]
	if typeof(value) != TYPE_ARRAY:
		validator.fail("'obstacles' must be an array of [x, z] cells, got %s" % str(value))
		return
	var items: Array = value
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}
	var obstacle_validator := _Validator.new(validator.source, {})
	for index in range(items.size()):
		var label := "obstacles[%d]" % index
		var cell := _read_cell(obstacle_validator, items[index], label)
		if obstacle_validator.has_errors():
			continue
		if not arena.is_inside(cell):
			obstacle_validator.fail(
				"%s [%d, %d] is outside the %dx%d arena"
				% [label, cell.x, cell.y, arena.columns, arena.rows]
			)
			continue
		if cell == arena.start_cell:
			obstacle_validator.fail(
				"%s [%d, %d] covers the start cell" % [label, cell.x, cell.y]
			)
			continue
		if seen.has(cell):
			obstacle_validator.fail(
				"%s [%d, %d] is duplicated" % [label, cell.x, cell.y]
			)
			continue
		seen[cell] = true
		cells.append(cell)
	arena.obstacles = cells
	validator.absorb(obstacle_validator)


static func _validate_start_space(validator: _Validator, arena: ArenaData) -> void:
	for offset in range(1, START_SPACE_CELLS + 1):
		var cell: Vector2i = arena.start_cell - arena.start_direction * offset
		if not arena.is_inside(cell):
			validator.fail(
				"start space for a %d-cell snake does not fit: [%d, %d] is outside the arena"
				% [INITIAL_SNAKE_LENGTH, cell.x, cell.y]
			)
			return
		if arena.has_obstacle(cell):
			validator.fail(
				"start space for a %d-cell snake is blocked: obstacle at [%d, %d]"
				% [INITIAL_SNAKE_LENGTH, cell.x, cell.y]
			)
			return


static func _read_cell(validator: _Validator, value: Variant, label: String) -> Vector2i:
	if typeof(value) != TYPE_ARRAY:
		validator.fail("%s must be an array [x, z], got %s" % [label, str(value)])
		return Vector2i.ZERO
	var pair: Array = value
	if pair.size() != 2:
		validator.fail("%s must contain exactly two integers [x, z], got %s" % [label, str(value)])
		return Vector2i.ZERO
	var x := _read_axis(validator, pair[0], "%s[0]" % label)
	var z := _read_axis(validator, pair[1], "%s[1]" % label)
	return Vector2i(x, z)


static func _read_axis(validator: _Validator, value: Variant, label: String) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))):
		return int(roundf(float(value)))
	validator.fail("%s must be an integer cell coordinate, got %s" % [label, str(value)])
	return 0


static func _warn_unknown_keys(
	validator: _Validator, data: Dictionary, known: Array[String], prefix: String
) -> void:
	for key: String in data.keys():
		var name := str(key)
		if not known.has(name):
			validator.warn("unknown key '%s%s' ignored" % [prefix, name])


static func _is_kebab_case(value: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(ID_PATTERN) != OK:
		return false
	return regex.search(value) != null
