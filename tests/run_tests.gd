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
const GAME_SCENE_PATH := "res://scenes/game.tscn"
const CAPTURE_SCRIPT_PATH = "res://addons/studio_capture/capture.gd"

const ARENAS_DIRECTORY := "res://assets/data/arenas"
const ARENA_IDS: Array[String] = ["classic-12", "classic-16", "maze-01", "time-attack-16"]

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_boot_scene()
	_test_game_scene()
	_test_project_settings()
	_test_grid_space()
	_test_iso_camera()
	_test_session_driver()
	_test_snake_view()
	_test_turn_preview()
	_test_start_arena_selection()
	_test_input_actions()
	_test_arena_directory()
	_test_arena_validation_errors()
	_test_arena_directory_errors()
	_test_snake_start_and_movement()
	_test_turn_queue()
	_test_immediate_turn_input()
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


func _test_boot_scene() -> void:
	_check(MAIN_SCRIPT.game_scene_path() == GAME_SCENE_PATH, "main.gd loads scenes/game.tscn")
	_check(ResourceLoader.exists(GAME_SCENE_PATH), "scenes/game.tscn exists")
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
	_check(root is Node3D, "main scene root is a Node3D")
	_check(str(root.name) == "Main", "main scene root is named Main")

	var attached := root.get_script() as Script
	_check(attached != null and attached.resource_path == "res://src/main.gd", "main scene root runs src/main.gd")
	_check(root.get_child_count() == 0, "main scene keeps no playfield of its own; it loads game.tscn")
	root.free()


func _test_game_scene() -> void:
	var packed := load(GAME_SCENE_PATH) as PackedScene
	if packed == null:
		_check(false, "scenes/game.tscn loads as a PackedScene")
		return
	_check(true, "scenes/game.tscn loads as a PackedScene")

	var root := packed.instantiate()
	if root == null:
		_check(false, "scenes/game.tscn instantiates")
		return
	_check(root is Node3D, "game scene root is a Node3D")
	_check(str(root.name) == "Game", "game scene root is named Game")

	var controller := root.get_script() as Script
	_check(
		controller != null and controller.resource_path == "res://src/game/game_controller.gd",
		"game scene root runs the game controller"
	)
	var camera := root.get_node_or_null("Camera") as Camera3D
	_check(camera != null, "game scene has a Camera")
	if camera != null:
		var camera_script := camera.get_script() as Script
		_check(
			camera_script != null and camera_script.resource_path == "res://src/game/iso_camera.gd",
			"Camera runs the isometric camera script"
		)
		_check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Camera uses the orthogonal projection")
	for node_path in ["ArenaView", "SnakeView", "FoodView", "HUD"]:
		_check(root.get_node_or_null(node_path) != null, "game scene has a %s node" % node_path)
	var hud := root.get_node_or_null("HUD")
	if hud != null:
		_check(hud.get_node_or_null("ScoreLabel") != null, "HUD has a score label")
		_check(hud.get_node_or_null("EndLabel") != null, "HUD has the one-line end label")
	root.free()


func _test_grid_space() -> void:
	var north_west := GridSpace.cell_to_world(Vector2i(0, 0), 16, 16)
	_check(
		is_equal_approx(north_west.x, -7.5) and is_equal_approx(north_west.z, -7.5),
		"cell (0,0) maps to the arena corner at -7.5"
	)
	_check(is_equal_approx(north_west.y, 0.0), "cells map onto the floor plane")
	var south_east := GridSpace.cell_to_world(Vector2i(15, 15), 16, 16)
	_check(
		is_equal_approx(south_east.x, 7.5) and is_equal_approx(south_east.z, 7.5),
		"cell (15,15) maps to +7.5"
	)
	var center := GridSpace.cell_to_world(Vector2i(8, 8), 16, 16)
	_check(
		is_equal_approx(center.x, 0.5) and is_equal_approx(center.z, 0.5),
		"cell (8,8) sits just east of the arena center"
	)
	var small := GridSpace.cell_to_world(Vector2i(0, 0), 12, 12)
	_check(
		is_equal_approx(small.x, -5.5) and is_equal_approx(small.z, -5.5),
		"a 12x12 arena starts at -5.5"
	)
	var round_trip := true
	for cell in [Vector2i(0, 0), Vector2i(3, 7), Vector2i(15, 15)]:
		var world := GridSpace.cell_to_world(cell, 16, 16)
		if GridSpace.world_to_cell(world, 16, 16) != cell:
			round_trip = false
	_check(round_trip, "world_to_cell inverts cell_to_world")
	_check(
		GridSpace.world_to_cell(Vector3(20, 0, 0), 16, 16) == Vector2i(-1, -1),
		"world_to_cell reports out-of-arena positions as (-1, -1)"
	)


func _test_iso_camera() -> void:
	_check(is_equal_approx(IsoCamera.YAW_DEGREES, 45.0), "camera yaw starts at 45 degrees")
	_check(is_equal_approx(IsoCamera.PITCH_DEGREES, 35.264), "camera pitch is 35.264 degrees")
	var fit := IsoCamera.fit_ortho_size(16, 16)
	_check(absf(fit - 16.07) < 0.05, "16x16 fit ortho size is 16.07")
	var small_fit := IsoCamera.fit_ortho_size(12, 12)
	_check(absf(small_fit - 12.80) < 0.05, "12x12 fit ortho size is 12.80")
	_check(fit > 16.0, "fit leaves a margin around the walls")
	_check(
		is_equal_approx(IsoCamera.clamp_ortho_size(1.0, 16, 16), fit),
		"zoom never goes below the whole-arena fit"
	)
	_check(
		is_equal_approx(
			IsoCamera.clamp_ortho_size(100.0, 16, 16), fit * IsoCamera.MAX_ZOOM_FACTOR
		),
		"zoom is capped at twice the fit"
	)
	_check(
		is_equal_approx(IsoCamera.clamp_ortho_size(fit * 1.5, 16, 16), fit * 1.5),
		"zoom keeps a value inside the range"
	)
	var narrow_fit := IsoCamera.fit_ortho_size(16, 16, 800.0 / 600.0)
	_check(narrow_fit > fit, "a 4:3 viewport needs a larger ortho size than 16:9")
	_check(is_equal_approx(IsoCamera.yaw_degrees_after_turn(45.0, 1), 135.0), "E turns the camera 90 degrees")
	_check(is_equal_approx(IsoCamera.yaw_degrees_after_turn(45.0, -1), 315.0), "Q turns the camera 90 degrees the other way")
	_check(is_equal_approx(IsoCamera.yaw_degrees_after_turn(315.0, 1), 45.0), "the fourth quarter turn wraps back to 45")


func _test_session_driver() -> void:
	var loaded := ArenaData.load_directory(ARENAS_DIRECTORY)
	if not loaded.is_ok():
		_check(false, "arenas load before the driver checks")
		return
	var arena: ArenaData = loaded.arena_for_mode(ArenaData.MODE_CLASSIC)
	if arena == null:
		_check(false, "a Classic arena exists for the driver checks")
		return
	var session := SnakeSession.new(arena, 7)
	session.start()
	var driver := SessionDriver.new(session)
	var head_before := session.head_cell()
	_check(driver.advance(0.5) == 0, "the first half second only ticks the countdown")
	_check(session.state() == SnakeSession.State.COUNTDOWN, "the session is still counting down")
	_check(driver.advance(0.5) == 0, "the second half second finishes the countdown without a step")
	_check(session.state() == SnakeSession.State.PLAYING, "the countdown hands over to playing")
	_check(session.head_cell() == head_before, "the countdown moves nothing")
	_check(driver.alpha() == 0.0, "a fresh step has no interpolation remainder")
	_check(driver.advance(0.2) == 1, "0.2 s at 6 cells/s runs exactly one step")
	_check(
		session.head_cell() == head_before + SnakeSession.EAST,
		"the driver advanced the session one cell"
	)
	_check(absf(driver.alpha() - 0.2) < 0.01, "alpha carries the unused part of the step")

	var burst := SnakeSession.new(arena, 7)
	burst.start()
	var burst_driver := SessionDriver.new(burst)
	burst_driver.advance(SnakeSession.START_COUNTDOWN_SECONDS)
	_check(
		burst_driver.advance(2.0) == SessionDriver.MAX_STEPS_PER_FRAME,
		"a long frame runs at most four steps"
	)
	_check(burst_driver.alpha() <= 1.0, "the dropped time leaves alpha within 0..1")

	var paused := _start_session(arena)
	var paused_driver := SessionDriver.new(paused)
	paused.pause()
	var paused_head := paused.head_cell()
	_check(paused_driver.advance(1.0) == 0, "a paused session runs no steps")
	_check(paused.head_cell() == paused_head, "a paused session does not move")

	var wall_arena := _arena_from(_arena_dict({"start": {"cell": [15, 8], "direction": "east"}}))
	if wall_arena != null:
		var over_session := SnakeSession.new(wall_arena, 3)
		over_session.start()
		over_session.advance_time(SnakeSession.START_COUNTDOWN_SECONDS)
		var over_driver := SessionDriver.new(over_session)
		over_driver.advance(1.0)
		var over_head := over_session.head_cell()
		_check(over_session.state() == SnakeSession.State.OVER, "the run ends on the wall")
		_check(over_driver.advance(1.0) == 0, "an ended session runs no further steps")
		_check(over_session.head_cell() == over_head, "an ended session keeps its last cell")
		_check(over_driver.alpha() == 0.0, "an ended session clears the interpolation remainder")


func _test_snake_view() -> void:
	_check(
		is_equal_approx(SnakeView.turn_tween_seconds(1.0 / 6.0), SnakeView.TURN_TWEEN_SECONDS),
		"a slow step uses the full turn tween"
	)
	_check(
		is_equal_approx(SnakeView.turn_tween_seconds(0.05), 0.05),
		"a fast step shortens the turn tween to the step"
	)
	_check(is_equal_approx(SnakeView.turn_tween_seconds(0.0), 0.0), "a zero step has no turn tween")
	_check(is_equal_approx(SnakeView.yaw_for_direction(SnakeSession.NORTH), 0.0), "north points the head at yaw zero")
	_check(
		is_equal_approx(SnakeView.yaw_for_direction(SnakeSession.EAST), -PI / 2.0),
		"east turns the head to -90 degrees"
	)
	_check(
		is_equal_approx(SnakeView.yaw_for_direction(SnakeSession.WEST), PI / 2.0),
		"west turns the head to +90 degrees"
	)
	_check(
		absf(absf(SnakeView.yaw_for_direction(SnakeSession.SOUTH)) - PI) < 0.001,
		"south turns the head 180 degrees"
	)
	var previous: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 1)]
	var current: Array[Vector2i] = [Vector2i(2, 1), Vector2i(1, 1)]
	var start := GridSpace.cell_to_world(previous[0], 4, 4)
	var target := GridSpace.cell_to_world(current[0], 4, 4)
	var midpoint := SnakeView.segment_world_position(0, previous, current, 0.5, 4, 4)
	_check(midpoint.is_equal_approx(start.lerp(target, 0.5)), "the head segment sits halfway between cells")
	var tail := SnakeView.segment_world_position(1, previous, current, 0.5, 4, 4)
	_check(
		tail.is_equal_approx(
			GridSpace.cell_to_world(previous[1], 4, 4).lerp(
				GridSpace.cell_to_world(current[1], 4, 4), 0.5
			)
		),
		"the tail segment interpolates too"
	)
	_check(
		SnakeView.segment_world_position(0, previous, current, 2.0, 4, 4).is_equal_approx(target),
		"alpha is clamped at the current cell"
	)
	var grown: Array[Vector2i] = [Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1)]
	_check(
		SnakeView.segment_world_position(2, previous, grown, 0.5, 4, 4).is_equal_approx(
			GridSpace.cell_to_world(grown[2], 4, 4)
		),
		"the new tail segment stays on its cell during growth"
	)


func _test_turn_preview() -> void:
	_check(
		is_equal_approx(SnakeView.TURN_TWEEN_SECONDS, 0.10),
		"the turn tween stays at 0.10 seconds"
	)
	var view := SnakeView.new()
	view._build_body()
	var previous: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 1)]
	var current: Array[Vector2i] = [Vector2i(2, 1), Vector2i(1, 1)]
	view.apply_step(previous, current, SnakeSession.EAST, SnakeSession.EAST, 1.0 / 6.0, false)
	var east_yaw := view.displayed_yaw()
	view.preview_turn(SnakeSession.NORTH, 1.0 / 6.0)
	_check(
		view.previewed_direction() == SnakeSession.NORTH,
		"an accepted turn is previewed on the input frame"
	)
	_check(
		is_equal_approx(view.displayed_yaw(), east_yaw),
		"the preview starts from the heading currently on screen"
	)
	_check(is_equal_approx(view.turn_progress(), 0.0), "the preview tween starts at zero progress")
	view.advance_turn(1.0 / 60.0)
	_check(
		view.turn_progress() > 0.0 and view.turn_progress() < 1.0,
		"one 60 Hz frame already shows a visible turn"
	)
	_check(
		absf(view.turn_progress() - (1.0 / 60.0) / SnakeView.TURN_TWEEN_SECONDS) < 0.001,
		"one frame advances the 0.10 s tween by about 1/6"
	)
	view.preview_turn(SnakeSession.WEST, 1.0 / 6.0)
	_check(
		view.previewed_direction() == SnakeSession.NORTH,
		"a second input before the step does not replace the pending preview"
	)
	view.advance_turn(0.10)
	_check(view.turn_progress() == 1.0, "the preview finishes within 0.10 seconds")
	_check(absf(view.displayed_yaw()) < 0.001, "the previewed head faces north before the step")
	var north: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1)]
	view.apply_step(previous, north, SnakeSession.EAST, SnakeSession.NORTH, 1.0 / 6.0, false)
	_check(view.previewed_direction() == Vector2i.ZERO, "the consuming step clears the preview")
	_check(absf(view.displayed_yaw()) < 0.001, "the consuming step does not snap the head back east")
	view.apply_step(north, current, SnakeSession.NORTH, SnakeSession.EAST, 1.0 / 6.0, false)
	_check(
		is_equal_approx(view.turn_progress(), 0.0),
		"a turn seen only at the step still starts its tween from zero"
	)
	view.advance_turn(0.05)
	_check(
		is_equal_approx(view.turn_progress(), 0.5),
		"a step-started turn still completes in 0.10 seconds"
	)
	view.free()


func _test_start_arena_selection() -> void:
	var loaded := ArenaData.load_directory(ARENAS_DIRECTORY)
	if not loaded.is_ok():
		_check(false, "arenas load before the start-arena checks")
		return
	var default_arena := GameController.select_start_arena(loaded, "")
	_check(
		default_arena != null and default_arena.id == "classic-12",
		"startup picks the first Classic arena"
	)
	var maze := GameController.select_start_arena(loaded, "maze-01")
	_check(maze != null and maze.id == "maze-01", "--arena selects another arena by id")
	_check(
		GameController.select_start_arena(loaded, "nope") == null,
		"an unknown arena id is reported as no arena"
	)


func _test_input_actions() -> void:
	var controller := GameController.new()
	controller._register_actions()
	for action: String in ["snake_up", "snake_down", "snake_left", "snake_right"]:
		_check(InputMap.has_action(action), "input action %s is registered" % action)
	_check(
		InputMap.action_get_events("snake_up").size() >= 2,
		"snake_up binds both W and the up arrow"
	)
	_check(InputMap.has_action("snake_pause"), "the pause action is registered for the later UI story")
	controller.free()


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


func _test_immediate_turn_input() -> void:
	var arena := _load_arena("classic-16.json")
	if arena == null:
		return
	var session := _start_session(arena)
	var driver := SessionDriver.new(session)
	_check(driver.advance(0.05) == 0, "0.05 s into a step runs no logic step yet")
	_check(session.direction() == SnakeSession.EAST, "the snake still heads east before the step ends")
	_check(session.turn(SnakeSession.NORTH), "a turn pressed mid-step is accepted immediately")
	_check(
		session.direction() == SnakeSession.EAST,
		"the accepted input does not change the logic direction before the step"
	)
	_check(session.head_cell() == arena.start_cell, "the accepted input moves nothing before the step")
	_check(driver.advance(0.12) == 1, "the next step still runs on the unchanged cadence")
	_check(session.direction() == SnakeSession.NORTH, "the next move follows the pressed direction")
	_check(
		session.head_cell() == arena.start_cell + SnakeSession.NORTH,
		"the next move goes north instead of east"
	)


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
