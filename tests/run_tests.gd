extends SceneTree

## Headless regression checks for Coil 3D.
##
## Run with:
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Prints one PASS line per successful check and exits 0 only when every
## check passes; any failure exits 1.

const MAIN_SCRIPT = preload("res://src/main.gd")
const MAIN_SCENE_PATH = "res://scenes/main.tscn"
const CAPTURE_SCRIPT_PATH = "res://addons/studio_capture/capture.gd"

const ARENAS_DIRECTORY := "res://assets/data/arenas"
const ARENA_IDS: Array[String] = ["classic-12", "classic-16", "maze-01", "time-attack-16"]

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_main_helpers()
	_test_main_scene()
	_test_project_settings()
	_test_arena_directory()
	_test_arena_validation_errors()
	_test_arena_directory_errors()
	_test_snake_start_and_movement()
	_test_turn_queue()
	_test_food_and_growth()
	_test_collisions()
	_test_speed_cap()
	_test_full_board()
	_test_modes_share_one_logic()
	_test_time_attack_clock()

	if _failed == 0:
		print("PASS: %d checks passed" % _passed)
		quit(0)
		return

	printerr("FAIL: %d of %d checks failed" % [_failed, _passed + _failed])
	quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		_failed += 1
		printerr("FAIL: %s" % label)


func _test_main_helpers() -> void:
	_check(MAIN_SCRIPT.title_text() == "Game Studio", "main.title_text() returns the studio title")
	_check(MAIN_SCRIPT.status_text(0) == "Game Studio (0 frames)", "main.status_text(0) formats zero frames")
	_check(MAIN_SCRIPT.status_text(7) == "Game Studio (7 frames)", "main.status_text(7) formats seven frames")
	_check(MAIN_SCRIPT.status_text(-3) == "Game Studio (0 frames)", "main.status_text() clamps negative frames")


func _test_main_scene() -> void:
	_check(ResourceLoader.exists(MAIN_SCENE_PATH), "scenes/main.tscn exists")

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_check(false, "scenes/main.tscn loads as a PackedScene")
		return
	_check(true, "scenes/main.tscn loads as a PackedScene")

	var root := packed.instantiate()
	if root == null:
		_check(false, "scenes/main.tscn instantiates")
		return
	_check(root is Node2D, "main scene root is a Node2D")
	_check(str(root.name) == "Main", "main scene root is named Main")

	var attached := root.get_script() as Script
	_check(attached != null and attached.resource_path == "res://src/main.gd", "main scene root runs src/main.gd")

	var label := root.get_node_or_null("Title") as Label
	_check(label != null, "main scene has a Title label")
	if label != null:
		_check(label.text == "Game Studio", "Title label reads Game Studio")
	root.free()


func _test_project_settings() -> void:
	_check(ProjectSettings.get_setting("application/config/name", "") == "Game Studio", "project name is Game Studio")
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == MAIN_SCENE_PATH, "main scene is registered in project.godot")
	_check(ProjectSettings.get_setting("autoload/StudioCapture", "") == "*" + CAPTURE_SCRIPT_PATH, "StudioCapture autoload points at the capture addon")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1152, "viewport width is 1152")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 648, "viewport height is 648")


# ---------------------------------------------------------------------------
# Arena data
# ---------------------------------------------------------------------------


func _test_arena_directory() -> void:
	var loaded := ArenaData.load_directory(ARENAS_DIRECTORY)
	_check(loaded.is_ok(), "every arena file in assets/data/arenas loads and validates")
	if not loaded.is_ok():
		for message in loaded.errors:
			printerr("arena error: %s" % message)
	_check(loaded.arenas.size() == ARENA_IDS.size(), "the arena directory provides four arenas")

	var ids: Array[String] = []
	for arena in loaded.arenas:
		ids.append(arena.id)
	_check(ids == ARENA_IDS, "arenas load in file-name order")

	var by_id: Dictionary = {}
	var modes: Dictionary = {}
	var classic_count := 0
	for arena in loaded.arenas:
		by_id[arena.id] = arena
		modes[arena.mode] = true
		if arena.mode == ArenaData.MODE_CLASSIC:
			classic_count += 1
	_check(classic_count == 2, "two Classic arenas are provided")
	_check(modes.has(ArenaData.MODE_MAZE), "a Maze arena is provided")
	_check(modes.has(ArenaData.MODE_TIME_ATTACK), "a Time Attack arena is provided")
	_check(
		loaded.arena_for_mode(ArenaData.MODE_CLASSIC).id == "classic-12",
		"arena_for_mode returns the first Classic file by name"
	)
	var duplicate_mode_warned := false
	for warning in loaded.warnings:
		if warning.contains("mode 'classic'"):
			duplicate_mode_warned = true
	_check(duplicate_mode_warned, "a second arena for the same mode is reported as a warning")

	var classic := loaded.arena_for_mode(ArenaData.MODE_CLASSIC)
	_check(classic.columns == 12 and classic.rows == 12, "classic-12 is a 12x12 board")
	_check(classic.obstacles.is_empty(), "classic-12 has no obstacles")
	_check(classic.food_max == 1, "classic-12 spawns one food")

	var classic16: ArenaData = by_id["classic-16"]
	_check(classic16.columns == 16 and classic16.rows == 16, "classic-16 is a 16x16 board")
	_check(classic16.start_cell == Vector2i(8, 8), "classic-16 starts at [8, 8]")
	_check(classic16.start_direction == SnakeSession.EAST, "classic-16 starts facing east")
	_check(is_equal_approx(classic16.initial_speed, 6.0), "classic-16 starts at 6.0 cells/s")
	_check(is_equal_approx(classic16.max_speed, 14.0), "classic-16 caps at 14.0 cells/s")
	_check(not classic16.has_time_limit, "classic-16 has no time limit")

	var maze: ArenaData = by_id["maze-01"]
	_check(maze.obstacles.size() == 16, "maze-01 places sixteen obstacle cells")
	_check(maze.food_max == 2, "maze-01 keeps two food on the board")
	_check(not maze.has_time_limit, "maze-01 has no time limit")
	var maze_obstacles_valid := true
	for obstacle in maze.obstacles:
		if not maze.is_inside(obstacle) or obstacle == maze.start_cell:
			maze_obstacles_valid = false
	_check(maze_obstacles_valid, "maze obstacles are inside the board and off the start cell")

	var time_attack: ArenaData = by_id["time-attack-16"]
	_check(time_attack.food_max == 3, "time-attack-16 keeps three food on the board")
	_check(time_attack.has_time_limit, "time-attack-16 has a time limit")
	_check(is_equal_approx(time_attack.time_limit_seconds, 90.0), "time-attack-16 ends after 90 seconds")
	_check(is_equal_approx(time_attack.initial_speed, 7.0), "time-attack-16 starts at 7.0 cells/s")


func _test_arena_validation_errors() -> void:
	var valid := ArenaData.from_dict(_valid_arena_dict(), "valid.json")
	_check(valid.is_ok() and valid.arena.id == "test-arena", "the reference arena dict passes validation")

	var with_unknown := _valid_arena_dict()
	with_unknown["bonus_key"] = 7
	var unknown_result := ArenaData.from_dict(with_unknown, "extra.json")
	_check(
		unknown_result.is_ok() and not unknown_result.warnings.is_empty(),
		"unknown keys are ignored and reported as a warning"
	)

	var malformed := ArenaData.from_json_text("{\"schema_version\": 1,", "bad.json")
	_check(
		not malformed.is_ok() and malformed.errors.size() == 1
		and malformed.errors[0].begins_with("bad.json:"),
		"malformed JSON reports the file and line"
	)
	var array_json := ArenaData.from_json_text("[]", "list.json")
	_check(
		not array_json.is_ok() and array_json.errors[0].contains("object"),
		"a non-object JSON document is rejected"
	)

	_expect_error(_arena_dict({"schema_version": 2}), "schema_version", "an unknown schema version is rejected")
	_expect_error(_arena_dict({"id": "Bad Id"}), "kebab-case", "a non-kebab-case id is rejected")
	_expect_error(_arena_dict({"mode": "zen"}), "mode", "an unknown mode is rejected")

	_expect_error(_arena_dict({"size": {"columns": "wide", "rows": 16}}), "size.columns", "a non-integer column count is rejected")
	_expect_error(_arena_dict({"size": {"columns": 3, "rows": 16}}), "size.columns", "a board narrower than 4 cells is rejected")
	_expect_error(_arena_dict({"size": {"columns": 16, "rows": 17}}), "size.rows", "a board taller than 16 cells is rejected")
	_expect_error(_arena_dict({"size": "big"}), "size", "a non-object size is rejected")

	_expect_error(_arena_dict({"food_max": 0}), "food_max", "zero food is rejected")
	_expect_error(_arena_dict({"food_max": 1.5}), "food_max", "a fractional food count is rejected")

	_expect_error(_arena_dict({"initial_speed_cells_per_second": 3.0}), "initial_speed", "a starting speed below 4.0 is rejected")
	_expect_error(_arena_dict({"max_speed_cells_per_second": 25.0}), "max_speed", "a speed cap above 20.0 is rejected")
	_expect_error(
		_arena_dict({"initial_speed_cells_per_second": 9.0, "max_speed_cells_per_second": 8.0}),
		"max_speed", "a speed cap below the initial speed is rejected"
	)

	_expect_error(_arena_dict({"time_limit_seconds": 30.0}), "time_attack", "a time limit on a Classic arena is rejected")
	_expect_error(
		_arena_dict({"mode": "time_attack"}), "time_limit_seconds",
		"a Time Attack arena without a time limit is rejected"
	)
	_expect_error(
		_arena_dict({"mode": "time_attack", "time_limit_seconds": 700.0}), "time_limit_seconds",
		"a time limit above 600 seconds is rejected"
	)

	_expect_error(
		_arena_dict({"start": {"cell": [16, 8], "direction": "east"}}), "start.cell",
		"a start cell outside the board is rejected"
	)
	_expect_error(
		_arena_dict({"start": {"cell": [8, 8], "direction": "up"}}), "start.direction",
		"an unknown start direction is rejected"
	)
	_expect_error(
		_arena_dict({"start": {"cell": [1, 8], "direction": "east"}}), "start space",
		"a start cell with no room for the snake body is rejected"
	)

	_expect_error(_arena_dict({"obstacles": [[16, 0]]}), "obstacles[0]", "an obstacle outside the board is rejected")
	_expect_error(_arena_dict({"obstacles": [[4, 4], [4, 4]]}), "duplicated", "a duplicated obstacle is rejected")
	_expect_error(_arena_dict({"obstacles": [[8, 8]]}), "start cell", "an obstacle on the start cell is rejected")
	_expect_error(_arena_dict({"obstacles": [[7, 8]]}), "start space", "an obstacle on the start space is rejected")

	var missing_food := _valid_arena_dict()
	missing_food.erase("food_max")
	_expect_error(missing_food, "food_max", "a missing food_max is rejected")
	var missing_start := _valid_arena_dict()
	missing_start.erase("start")
	_expect_error(missing_start, "start", "a missing start is rejected")
	var missing_obstacles := _valid_arena_dict()
	missing_obstacles.erase("obstacles")
	_expect_error(missing_obstacles, "obstacles", "a missing obstacle list is rejected")


func _test_arena_directory_errors() -> void:
	var temp_directory := "user://test_arena_duplicates"
	_remove_temp_directory(temp_directory)
	DirAccess.make_dir_recursive_absolute(temp_directory)
	_write_temp_arena(temp_directory, "a.json", "shared-id", ArenaData.MODE_CLASSIC)
	_write_temp_arena(temp_directory, "b.json", "shared-id", ArenaData.MODE_MAZE)
	var duplicated := ArenaData.load_directory(temp_directory)
	_check(duplicated.arenas.size() == 1, "a duplicate id keeps only the first file")
	var duplicate_reported := false
	for message in duplicated.errors:
		if message.contains("duplicate id"):
			duplicate_reported = true
	_check(duplicate_reported, "a duplicate id is reported with the file name")

	var broken := FileAccess.open(temp_directory.path_join("broken.json"), FileAccess.WRITE)
	broken.store_string("{ not json")
	broken.close()
	var with_broken := ArenaData.load_directory(temp_directory)
	_check(with_broken.arenas.size() == 1, "a broken file does not hide the valid arenas")
	_check(not with_broken.errors.is_empty(), "a broken file is reported in the load errors")

	var missing := ArenaData.load_directory("user://no_such_arena_directory")
	_check(not missing.is_ok(), "a missing arena directory is a readable error")
	_remove_temp_directory(temp_directory)


func _expect_error(data: Dictionary, fragment: String, label: String) -> void:
	var result := ArenaData.from_dict(data, "test-arena.json")
	var found := false
	for message in result.errors:
		if message.contains(fragment):
			found = true
	_check(not result.is_ok() and found, label)


# ---------------------------------------------------------------------------
# Snake session
# ---------------------------------------------------------------------------


func _test_snake_start_and_movement() -> void:
	var arena := _load_arena("classic-16.json")
	if arena == null:
		return
	var session := SnakeSession.new(arena, 7)
	session.start()
	_check(session.state() == SnakeSession.State.COUNTDOWN, "start() enters the countdown")
	_check(session.body_cells().size() == SnakeSession.INITIAL_LENGTH, "the initial snake has four segments")
	_check(session.head_cell() == arena.start_cell, "the snake head starts on the arena start cell")
	var body := session.body_cells()
	_check(body[1] == arena.start_cell - arena.start_direction, "the second segment sits behind the head")

	var before := session.head_cell()
	session.turn(SnakeSession.NORTH)
	session.step()
	_check(session.head_cell() == before, "turns and steps are ignored during the countdown")

	session.advance_time(SnakeSession.START_COUNTDOWN_SECONDS * 0.5)
	_check(session.state() == SnakeSession.State.COUNTDOWN, "half a second does not finish the countdown")
	session.advance_time(SnakeSession.START_COUNTDOWN_SECONDS * 0.5)
	_check(session.state() == SnakeSession.State.PLAYING, "the countdown hands over to playing")
	_check(session.score() == 0, "a fresh run scores zero")
	_check(session.food_cells().size() == arena.food_max, "a fresh run fills food_max food")
	_check(is_equal_approx(session.speed_cells_per_second(), arena.initial_speed), "a fresh run uses the initial speed")

	var result := session.step()
	_check(result.stepped, "step() reports a movement step")
	_check(session.head_cell() == arena.start_cell + SnakeSession.EAST, "the snake moves one cell east")
	_check(session.body_cells().size() == SnakeSession.INITIAL_LENGTH, "moving without food keeps the length")
	_check(
		session.body_cells()[SnakeSession.INITIAL_LENGTH - 1] == body[SnakeSession.INITIAL_LENGTH - 2],
		"the tail follows the body forward"
	)

	_check(not session.turn(SnakeSession.WEST), "a 180-degree reverse turn is refused")
	session.step()
	_check(session.head_cell() == arena.start_cell + SnakeSession.EAST * 2, "a refused reverse keeps the heading")
	_check(not session.turn(Vector2i(1, 1)), "a diagonal direction is refused")
	_check(not session.turn(SnakeSession.EAST), "a repeat of the current direction is refused")


func _test_turn_queue() -> void:
	var arena := _load_arena("classic-16.json")
	if arena == null:
		return
	var session := _start_session(arena)
	_check(session.turn(SnakeSession.NORTH), "a perpendicular turn is queued")
	_check(not session.turn(SnakeSession.SOUTH), "the opposite of the queued direction is dropped")
	session.step()
	_check(session.direction() == SnakeSession.NORTH, "the queued turn applies on the next step")
	_check(session.head_cell() == arena.start_cell + SnakeSession.NORTH, "the head moved north")

	var queued := _start_session(arena)
	_check(queued.turn(SnakeSession.NORTH), "the first of two queued turns is accepted")
	_check(queued.turn(SnakeSession.WEST), "the second queued turn is accepted")
	_check(not queued.turn(SnakeSession.SOUTH), "a third turn is refused while the queue is full")
	queued.step()
	_check(queued.direction() == SnakeSession.NORTH, "the first queued turn wins the step")
	queued.step()
	_check(queued.direction() == SnakeSession.WEST, "the second queued turn applies on the following step")

	var reversing := _start_session(arena)
	reversing.turn(SnakeSession.NORTH)
	reversing.turn(SnakeSession.SOUTH)
	reversing.step()
	_check(reversing.state() == SnakeSession.State.PLAYING, "two fast reverse inputs do not kill the snake")


func _test_food_and_growth() -> void:
	var arena := _load_arena("classic-16.json")
	if arena == null:
		return
	var session := _start_session(arena, 11)
	var foods := session.food_cells()
	_check(foods.size() == 1, "one food is on the board for a Classic arena")
	_check(arena.is_inside(foods[0]), "food spawns inside the arena")
	_check(not session.body_cells().has(foods[0]), "food never spawns on the snake")
	_check(not arena.has_obstacle(foods[0]), "food never spawns on an obstacle")

	_check(_navigate_to_food(session, arena), "the snake can reach the first food")
	_check(session.food_eaten() == 1, "eating increments the food counter")
	_check(session.score() == SnakeSession.POINTS_PER_FOOD, "eating scores ten points")
	_check(session.body_cells().size() == SnakeSession.INITIAL_LENGTH + 1, "eating grows the snake by one segment")
	_check(
		is_equal_approx(
			session.speed_cells_per_second(),
			arena.initial_speed + SnakeSession.SPEED_GAIN_PER_FOOD
		),
		"eating raises the speed by 0.2 cells/s"
	)
	var refilled := session.food_cells()
	_check(refilled.size() == arena.food_max, "food respawns up to food_max")
	_check(not session.body_cells().has(refilled[0]), "respawned food never lands on the snake")
	_check(refilled[0] != foods[0], "respawned food takes a new cell")

	var spawns_valid := true
	for seed_value in range(10):
		var seeded := _start_session(arena, seed_value)
		for cell in seeded.food_cells():
			if not arena.is_inside(cell) or seeded.body_cells().has(cell):
				spawns_valid = false
	_check(spawns_valid, "food stays inside and off the snake across seeds")

	var maze := _load_arena("maze-01.json")
	if maze != null:
		var maze_spawns_valid := true
		for seed_value in range(10):
			var maze_session := _start_session(maze, seed_value)
			if maze_session.food_cells().size() != maze.food_max:
				maze_spawns_valid = false
			for cell in maze_session.food_cells():
				if maze.has_obstacle(cell) or not maze.is_inside(cell):
					maze_spawns_valid = false
		_check(maze_spawns_valid, "Maze food avoids obstacles and fills food_max")


func _test_collisions() -> void:
	var wall_arena := _arena_from(_arena_dict({
		"start": {"cell": [15, 8], "direction": "east"},
	}))
	if wall_arena != null:
		var wall_session := _start_session(wall_arena)
		var head := wall_session.head_cell()
		wall_session.step()
		_check(wall_session.state() == SnakeSession.State.OVER, "hitting the wall ends the run")
		_check(wall_session.end_reason() == SnakeSession.EndReason.WALL, "a wall hit is reported as wall")
		_check(wall_session.head_cell() == head, "a fatal wall step leaves the head in place")

	var obstacle_arena := _arena_from(_arena_dict({
		"size": {"columns": 8, "rows": 8},
		"mode": "maze",
		"obstacles": [[4, 2]],
		"start": {"cell": [3, 2], "direction": "east"},
	}))
	if obstacle_arena != null:
		var obstacle_session := _start_session(obstacle_arena)
		obstacle_session.step()
		_check(obstacle_session.state() == SnakeSession.State.OVER, "hitting an obstacle ends the run")
		_check(
			obstacle_session.end_reason() == SnakeSession.EndReason.OBSTACLE,
			"an obstacle hit is reported as obstacle"
		)

	var open_arena := _arena_from(_arena_dict({
		"start": {"cell": [3, 2], "direction": "east"},
	}))
	if open_arena != null:
		var tail_session := _start_session(open_arena, _seed_without_food_at(
			open_arena,
			[Vector2i(4, 2), Vector2i(4, 1), Vector2i(3, 1), Vector2i(3, 2)]
		))
		tail_session.step()
		tail_session.turn(SnakeSession.NORTH)
		tail_session.step()
		tail_session.turn(SnakeSession.WEST)
		tail_session.step()
		tail_session.turn(SnakeSession.SOUTH)
		tail_session.step()
		_check(tail_session.state() == SnakeSession.State.PLAYING, "entering the cell the tail vacates is legal")
		_check(tail_session.head_cell() == Vector2i(3, 2), "the head entered the vacated tail cell")

	var turning_arena := _load_arena("classic-16.json")
	if turning_arena != null:
		var self_session := _start_session(turning_arena, 5)
		_check(_navigate_to_food(self_session, turning_arena), "the snake grows before the self-collision check")
		_check(self_session.body_cells().size() == 5, "the snake has five segments before turning back")
		for _turn in range(3):
			self_session.turn(_right_of(self_session.direction()))
			self_session.step()
		_check(self_session.state() == SnakeSession.State.OVER, "turning back into the body ends the run")
		_check(self_session.end_reason() == SnakeSession.EndReason.SELF, "a body hit is reported as self")


func _test_speed_cap() -> void:
	var arena := _arena_from(_arena_dict({
		"size": {"columns": 8, "rows": 8},
		"initial_speed_cells_per_second": 6.0,
		"max_speed_cells_per_second": 6.2,
		"start": {"cell": [3, 3], "direction": "east"},
	}))
	if arena == null:
		return
	var session := _start_session(arena, 2)
	_check(_navigate_to_food(session, arena), "the snake reaches food on the capped arena")
	_check(
		is_equal_approx(session.speed_cells_per_second(), 6.2),
		"the speed curve reaches the 6.2 cap after one food"
	)
	_check(
		is_equal_approx(session.step_duration_seconds(), 1.0 / 6.2),
		"the step duration follows the current speed"
	)
	_check(_navigate_to_food(session, arena), "the snake reaches a second food on the capped arena")
	_check(session.food_eaten() == 2, "the capped arena run ate two food")
	_check(
		is_equal_approx(session.speed_cells_per_second(), 6.2),
		"speed never exceeds max_speed"
	)


func _test_full_board() -> void:
	var full_arena := _arena_from(_arena_dict({
		"size": {"columns": 4, "rows": 4},
		"mode": "maze",
		"obstacles": [
			[0, 0], [1, 0], [2, 0], [3, 0],
			[0, 2], [1, 2], [2, 2], [3, 2],
			[0, 3], [1, 3], [2, 3], [3, 3],
		],
		"food_max": 1,
		"start": {"cell": [3, 1], "direction": "east"},
	}))
	if full_arena != null:
		var full_session := _start_session(full_arena)
		_check(full_session.food_cells().is_empty(), "a board without free cells spawns no food")
		_check(full_session.state() == SnakeSession.State.OVER, "a full board ends the run")
		_check(full_session.end_reason() == SnakeSession.EndReason.CLEARED, "a full board reports cleared")

	var last_food_arena := _arena_from(_arena_dict({
		"size": {"columns": 4, "rows": 4},
		"mode": "maze",
		"obstacles": [
			[0, 0], [1, 0], [2, 0], [3, 0],
			[0, 2], [1, 2],
			[0, 3], [1, 3], [2, 3], [3, 3],
		],
		"food_max": 8,
		"start": {"cell": [3, 1], "direction": "east"},
	}))
	if last_food_arena != null:
		var last_session := _start_session(last_food_arena)
		_check(
			last_session.food_cells().size() == 2,
			"food_max above the free cell count only spawns the available food"
		)
		_check(last_session.state() == SnakeSession.State.PLAYING, "a board with two free cells is playable")
		last_session.turn(SnakeSession.SOUTH)
		last_session.step()
		_check(last_session.score() == SnakeSession.POINTS_PER_FOOD, "the first free-cell food is eaten")
		_check(last_session.body_cells().size() == SnakeSession.INITIAL_LENGTH + 1, "the first food grows the snake")
		_check(last_session.state() == SnakeSession.State.PLAYING, "the board is not cleared while food remains")
		last_session.turn(SnakeSession.WEST)
		last_session.step()
		_check(last_session.score() == SnakeSession.POINTS_PER_FOOD * 2, "the last free-cell food is eaten")
		_check(last_session.body_cells().size() == SnakeSession.INITIAL_LENGTH + 2, "the last food grows the snake")
		_check(last_session.state() == SnakeSession.State.OVER, "filling the board ends the run")
		_check(last_session.end_reason() == SnakeSession.EndReason.CLEARED, "filling the board reports cleared")
		_check(last_session.food_cells().is_empty(), "a cleared board keeps no food")


func _test_modes_share_one_logic() -> void:
	var loaded := ArenaData.load_directory(ARENAS_DIRECTORY)
	if not loaded.is_ok():
		_check(false, "arena directory loads before the mode checks")
		return
	for arena in loaded.arenas:
		var session := _start_session(arena, 3)
		_check(session.state() == SnakeSession.State.PLAYING, "%s starts playing after the countdown" % arena.id)
		_check(
			session.body_cells().size() == SnakeSession.INITIAL_LENGTH,
			"%s starts with the shared four-segment snake" % arena.id
		)
		_check(session.head_cell() == arena.start_cell, "%s starts on its own start cell" % arena.id)
		_check(session.food_cells().size() == arena.food_max, "%s fills its own food_max" % arena.id)
		_check(session.score() == 0, "%s starts at zero score" % arena.id)
		var result := session.step()
		_check(result.stepped, "%s advances a logic step" % arena.id)
		_check(
			session.head_cell() == arena.start_cell + arena.start_direction,
			"%s moves along its own start direction" % arena.id
		)
		_check(session.state() == SnakeSession.State.PLAYING, "%s keeps playing after one step" % arena.id)


func _test_time_attack_clock() -> void:
	var time_attack := _load_arena("time-attack-16.json")
	if time_attack == null:
		return
	var clock := {"seconds": 0.0}
	var session := _session_with_clock(time_attack, clock)
	_check(session.state() == SnakeSession.State.PLAYING, "the injected clock session starts playing")
	clock["seconds"] = 89.0
	session.step()
	_check(session.state() == SnakeSession.State.PLAYING, "Time Attack keeps playing just below 90 seconds")
	_check(session.elapsed_seconds() < 90.0, "elapsed time comes from the injected clock")
	clock["seconds"] = 90.0
	session.step()
	_check(session.state() == SnakeSession.State.OVER, "Time Attack ends at 90 seconds")
	_check(session.end_reason() == SnakeSession.EndReason.TIME_UP, "the 90-second end reason is time_up")

	var paused_clock := {"seconds": 0.0}
	var paused := _session_with_clock(time_attack, paused_clock)
	paused_clock["seconds"] = 20.0
	paused.step()
	paused.pause()
	_check(paused.state() == SnakeSession.State.PAUSED, "pause() stops the session")
	var before_pause := paused.head_cell()
	paused.step()
	_check(paused.head_cell() == before_pause, "a paused session does not move")
	paused_clock["seconds"] = 70.0
	paused.resume()
	_check(paused.state() == SnakeSession.State.COUNTDOWN, "resume() starts the countdown again")
	paused.step()
	_check(paused.state() == SnakeSession.State.COUNTDOWN, "movement waits for the resume countdown")
	paused.advance_time(SnakeSession.START_COUNTDOWN_SECONDS)
	paused_clock["seconds"] = 70.0
	paused.step()
	_check(
		is_equal_approx(paused.elapsed_seconds(), 20.0),
		"paused wall time is not counted by the time limit"
	)

	var classic := _load_arena("classic-16.json")
	if classic != null:
		var classic_clock := {"seconds": 0.0}
		var classic_session := _session_with_clock(classic, classic_clock)
		classic_clock["seconds"] = 200.0
		classic_session.step()
		_check(
			classic_session.state() == SnakeSession.State.PLAYING,
			"a Classic arena ignores the clock and has no time limit"
		)

	var limit_arena := _arena_from(_arena_dict({
		"mode": "time_attack",
		"time_limit_seconds": 90.0,
		"start": {"cell": [15, 8], "direction": "east"},
	}))
	if limit_arena != null:
		var wall_clock := {"seconds": 0.0}
		var wall_session := _session_with_clock(limit_arena, wall_clock)
		wall_clock["seconds"] = 500.0
		wall_session.step()
		_check(
			wall_session.end_reason() == SnakeSession.EndReason.WALL,
			"a collision at the time limit is reported before time_up"
		)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _load_arena(file_name: String) -> ArenaData:
	var result := ArenaData.load_file(ARENAS_DIRECTORY.path_join(file_name))
	if not result.is_ok():
		_check(false, "%s loads: %s" % [file_name, ", ".join(result.errors)])
		return null
	return result.arena


func _arena_from(data: Dictionary) -> ArenaData:
	var result := ArenaData.from_dict(data, "test-arena.json")
	if not result.is_ok():
		_check(false, "a test arena validates: %s" % ", ".join(result.errors))
		return null
	return result.arena


func _valid_arena_dict() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test-arena",
		"mode": "classic",
		"size": {"columns": 16, "rows": 16},
		"obstacles": [],
		"food_max": 1,
		"initial_speed_cells_per_second": 6.0,
		"max_speed_cells_per_second": 14.0,
		"time_limit_seconds": null,
		"start": {"cell": [8, 8], "direction": "east"},
	}


func _arena_dict(overrides: Dictionary) -> Dictionary:
	var data := _valid_arena_dict()
	for key in overrides.keys():
		data[key] = overrides[key]
	return data


func _start_session(arena: ArenaData, seed_value: int = 7) -> SnakeSession:
	var session := SnakeSession.new(arena, seed_value)
	session.start()
	session.advance_time(SnakeSession.START_COUNTDOWN_SECONDS)
	return session


func _session_with_clock(arena: ArenaData, clock: Dictionary, seed_value: int = 1) -> SnakeSession:
	var session := SnakeSession.new(arena, seed_value)
	session.set_time_source(func() -> float: return float(clock["seconds"]))
	session.start()
	session.advance_time(SnakeSession.START_COUNTDOWN_SECONDS)
	return session


func _right_of(direction: Vector2i) -> Vector2i:
	return Vector2i(-direction.y, direction.x)


func _seed_without_food_at(arena: ArenaData, blocked_cells: Array[Vector2i]) -> int:
	for seed_value in range(64):
		var candidate := _start_session(arena, seed_value)
		var clear := true
		for cell in candidate.food_cells():
			if blocked_cells.has(cell):
				clear = false
		if clear:
			return seed_value
	return 0


func _path_between(
	start: Vector2i, target: Vector2i, blocked: Dictionary, arena: ArenaData
) -> Array[Vector2i]:
	var came_from: Dictionary = {start: start}
	var frontier: Array[Vector2i] = [start]
	var found := start == target
	while not frontier.is_empty() and not found:
		var current: Vector2i = frontier.pop_front()
		for direction in SnakeSession.DIRECTIONS:
			var next: Vector2i = current + direction
			if next == target:
				came_from[next] = current
				found = true
				break
			if not arena.is_inside(next) or blocked.has(next) or came_from.has(next):
				continue
			came_from[next] = current
			frontier.append(next)
	if not found:
		return []
	var path: Array[Vector2i] = []
	var cursor := target
	while cursor != start:
		path.append(cursor)
		cursor = came_from[cursor]
	path.append(start)
	path.reverse()
	return path


func _navigate_to_food(session: SnakeSession, arena: ArenaData) -> bool:
	var foods := session.food_cells()
	if foods.is_empty():
		return false
	var blocked: Dictionary = {}
	for cell in arena.obstacles:
		blocked[cell] = true
	for cell in session.body_cells():
		blocked[cell] = true
	var path := _path_between(session.head_cell(), foods[0], blocked, arena)
	if path.size() < 2:
		return false
	for index in range(1, path.size()):
		session.turn(path[index] - path[index - 1])
		session.step()
		if session.state() != SnakeSession.State.PLAYING:
			return false
	return true


func _write_temp_arena(directory_path: String, file_name: String, arena_id: String, mode_name: String) -> void:
	var data := _valid_arena_dict()
	data["id"] = arena_id
	data["mode"] = mode_name
	if mode_name == ArenaData.MODE_TIME_ATTACK:
		data["time_limit_seconds"] = 90.0
	var file := FileAccess.open(directory_path.path_join(file_name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _remove_temp_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(directory_path.path_join(file_name))
	DirAccess.remove_absolute(directory_path)
