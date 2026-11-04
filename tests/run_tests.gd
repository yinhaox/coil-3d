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
const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const HOW_TO_PLAY_SCENE_PATH := "res://scenes/ui/how_to_play.tscn"
const CAPTURE_SCRIPT_PATH = "res://addons/studio_capture/capture.gd"
const INPUT_EVENTS := preload("res://tests/input_events.gd")

const ARENAS_DIRECTORY := "res://assets/data/arenas"
const ARENA_IDS: Array[String] = ["classic-12", "classic-16", "maze-01", "time-attack-16"]

const TEST_INPUT_SAVE_DIRECTORY := "user://test_input_events"
const TEST_SAVE_DIRECTORY := "user://test_save_store"
const TEST_SHELL_DIRECTORY := "user://test_app_shell"
const TEST_PANEL_DIRECTORY := "user://test_hud_end"
const MAX_TEST_STEPS := 64

var _passed := 0
var _failed := 0


func _init() -> void:
	# Input events are delivered by the running scene tree, so the checks start
	# on the first processed frame instead of inside the main-loop constructor.
	_run_tests.call_deferred()


func _run_tests() -> void:
	await process_frame
	_test_boot_scene()
	_test_game_scene()
	_test_ui_screens()
	_test_project_settings()
	_test_fps_log()
	_test_grid_space()
	_test_iso_camera()
	_test_session_driver()
	_test_snake_view()
	_test_turn_preview()
	_test_start_arena_selection()
	_test_input_actions()
	_test_real_input_events()
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
	_test_save_store()
	_test_app_shell()
	_test_hud_pause_and_end_panel()

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
	_check(
		MAIN_SCRIPT.main_menu_scene_path() == MAIN_MENU_SCENE_PATH,
		"main.gd boots into the main menu scene"
	)
	_check(ResourceLoader.exists(GAME_SCENE_PATH), "scenes/game.tscn exists")
	_check(ResourceLoader.exists(MAIN_MENU_SCENE_PATH), "scenes/ui/main_menu.tscn exists")
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
	_check(root.get_child_count() == 0, "the boot entry adds no screen before _ready")
	root._add_process_flags(PackedStringArray(["--quit-after=10"]))
	_check(
		root.get_child_count() == 1 and root.get_child(0) is FpsLog,
		"the boot entry still installs the frame sampler from user arguments"
	)
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
		for label_name in ["ScoreLabel", "LengthLabel", "SpeedLabel", "TimeLabel"]:
			_check(
				hud.get_node_or_null("Stats/VBox/" + label_name) != null,
				"HUD has a %s" % label_name
			)
		_check(hud.get_node_or_null("Best/BestLabel") != null, "HUD has the best-score label")
	var pause_menu := root.get_node_or_null("PauseMenu")
	_check(pause_menu != null, "game scene has a PauseMenu")
	if pause_menu != null:
		for button_name in ["ResumeButton", "RestartButton", "MainMenuButton"]:
			_check(
				pause_menu.get_node_or_null("Root/Center/Panel/Margin/VBox/" + button_name) != null,
				"the pause menu has a %s" % button_name
			)
	var end_panel := root.get_node_or_null("EndPanel")
	_check(end_panel != null, "game scene has an EndPanel")
	if end_panel != null:
		for button_name in ["RetryButton", "MainMenuButton"]:
			_check(
				end_panel.get_node_or_null("Root/Center/Panel/Margin/VBox/" + button_name) != null,
				"the end panel has a %s" % button_name
			)
		_check(
			end_panel.get_node_or_null("Root/Center/Panel/Margin/VBox/NewBestLabel") != null,
			"the end panel has the New best label"
		)
	root.free()


func _test_ui_screens() -> void:
	var menu_packed := load(MAIN_MENU_SCENE_PATH) as PackedScene
	if menu_packed == null:
		_check(false, "the main menu scene loads")
		return
	_check(true, "the main menu scene loads")
	var menu := menu_packed.instantiate() as MainMenu
	if menu == null:
		_check(false, "the main menu scene instantiates")
		return
	root.add_child(menu)
	_check(menu.theme == AppTheme.shared(), "the main menu installs the app theme")
	var menu_title := menu.get_node_or_null("Center/Panel/Margin/VBox/TitleLabel") as Label
	_check(menu_title != null and not menu_title.text.is_empty(), "the main menu writes its title")
	var play := menu.get_node_or_null("Center/Panel/Margin/VBox/PlayButton") as Button
	var how_to := menu.get_node_or_null("Center/Panel/Margin/VBox/HowToPlayButton") as Button
	var quit := menu.get_node_or_null("Center/Panel/Margin/VBox/QuitButton") as Button
	_check(play != null and play.text == "Play", "the main menu shows Play")
	_check(how_to != null and how_to.text == "How to play", "the main menu shows How to play")
	_check(quit != null and quit.text == "Quit", "the main menu shows Quit")
	_check(play != null and play.has_focus(), "the main menu focuses Play")
	_check(
		play != null and play.custom_minimum_size.y >= AppTheme.BUTTON_MINIMUM.y,
		"menu buttons keep a 44 px target"
	)
	_check(
		play != null and play.focus_neighbor_bottom == play.get_path_to(how_to),
		"the main menu wires explicit focus neighbours"
	)
	root.remove_child(menu)
	menu.free()

	var page_packed := load(HOW_TO_PLAY_SCENE_PATH) as PackedScene
	if page_packed == null:
		_check(false, "the how-to-play scene loads")
		return
	_check(true, "the how-to-play scene loads")
	var page := page_packed.instantiate() as HowToPlay
	if page == null:
		_check(false, "the how-to-play scene instantiates")
		return
	root.add_child(page)
	var body := page.get_node_or_null("Center/Panel/Margin/VBox/BodyLabel") as Label
	_check(body != null and body.autowrap_mode != TextServer.AUTOWRAP_OFF, "the how-to-play text wraps")
	var back := page.get_node_or_null("Center/Panel/Margin/VBox/BackButton") as Button
	_check(back != null and back.has_focus(), "the how-to-play page focuses Back")
	var back_pressed := {"value": false}
	page.back_requested.connect(func() -> void: back_pressed["value"] = true)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	page._unhandled_input(cancel)
	_check(back_pressed["value"], "Esc leaves How to play")
	root.remove_child(page)
	page.free()


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
	var step_seconds := session.step_duration_seconds()
	_check(driver.advance(0.2) == 1, "0.2 s at the Classic speed runs exactly one step")
	_check(
		session.head_cell() == head_before + SnakeSession.EAST,
		"the driver advanced the session one cell"
	)
	_check(
		absf(driver.alpha() - fmod(0.2, step_seconds) / step_seconds) < 0.01,
		"alpha carries the unused part of the step"
	)

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
	_check(InputMap.has_action("snake_pause"), "the pause action is registered")
	controller.free()


func _test_real_input_events() -> void:
	_remove_temp_directory(TEST_INPUT_SAVE_DIRECTORY)
	var left_key := INPUT_EVENTS.key_for_action("snake_left")
	_check(
		left_key == KEY_A or left_key == KEY_LEFT,
		"the event helper resolves snake_left to a bound key"
	)
	_check(
		INPUT_EVENTS.key_for_action("snake_missing") == KEY_NONE,
		"the event helper reports an unknown action as KEY_NONE"
	)

	var game := _spawn_playing_game()
	if game == null:
		return
	var session: SnakeSession = game._session
	var start: Vector2i = session.head_cell()

	_check(INPUT_EVENTS.tap_key(KEY_UP), "the event helper injects an up-arrow press and release")
	_check(
		game._snake_view.previewed_direction() == SnakeSession.NORTH,
		"the up arrow previews a north turn on its own frame"
	)
	_check(
		session.direction() == SnakeSession.EAST,
		"the accepted turn leaves the logic heading east until the step"
	)
	_advance_game(game, session.step_duration_seconds())
	_check(session.direction() == SnakeSession.NORTH, "the next logic step consumes the up-arrow turn")
	_check(
		session.head_cell() == start + SnakeSession.NORTH,
		"the head moved north on the consumed turn"
	)

	_check(INPUT_EVENTS.tap_key(KEY_LEFT), "the event helper injects a left-arrow press and release")
	_check(
		game._snake_view.previewed_direction() == SnakeSession.WEST,
		"the left arrow previews a west turn on its own frame"
	)
	_advance_game(game, session.step_duration_seconds())
	_check(
		session.direction() == SnakeSession.WEST,
		"the snake head direction becomes west after the left-arrow step"
	)
	_check(
		session.head_cell() == start + SnakeSession.NORTH + SnakeSession.WEST,
		"the head moved west after the left-arrow step"
	)

	_check(INPUT_EVENTS.tap_action("snake_pause"), "the event helper injects the pause action by name")
	_check(session.state() == SnakeSession.State.PAUSED, "the pause action pauses the run")
	var paused_head: Vector2i = session.head_cell()
	_check(_advance_game(game, 1.0) == 0, "a paused run performs no logic steps")
	_check(session.head_cell() == paused_head, "a paused run keeps its head cell")
	_check(INPUT_EVENTS.tap_action("snake_pause"), "the event helper injects the pause action again")
	_check(
		session.state() == SnakeSession.State.COUNTDOWN,
		"pressing pause again resumes with the countdown"
	)
	_release_game(game)

	var reverse_game := _spawn_playing_game()
	if reverse_game == null:
		return
	var reverse_session: SnakeSession = reverse_game._session
	var reverse_start: Vector2i = reverse_session.head_cell()
	_check(INPUT_EVENTS.tap_key(KEY_UP), "the up arrow is injected before the reverse check")
	_check(
		reverse_game._snake_view.previewed_direction() == SnakeSession.NORTH,
		"the up arrow is accepted in the current logic step"
	)
	_check(INPUT_EVENTS.tap_key(KEY_DOWN), "the down arrow is injected inside the same logic step")
	_check(
		reverse_game._snake_view.previewed_direction() == SnakeSession.NORTH,
		"the reverse down arrow does not replace the accepted turn"
	)
	_check(
		reverse_session.direction() == SnakeSession.EAST,
		"the reverse down arrow leaves the logic heading east"
	)
	_advance_game(reverse_game, reverse_session.step_duration_seconds())
	_check(
		reverse_session.direction() == SnakeSession.NORTH,
		"the step follows the accepted up turn, not the reverse"
	)
	_check(
		reverse_session.head_cell() == reverse_start + SnakeSession.NORTH,
		"the snake does not make a 180-degree move"
	)
	_release_game(reverse_game)

	var over_game := _spawn_playing_game()
	if over_game == null:
		return
	var over_session: SnakeSession = over_game._session
	_check(INPUT_EVENTS.tap_key(KEY_UP), "the up arrow steers the snake toward the north wall")
	var steps := 0
	while over_session.state() == SnakeSession.State.PLAYING and steps < SnakeSession.INITIAL_LENGTH * 4:
		_advance_game(over_game, over_session.step_duration_seconds())
		steps += 1
	_check(over_session.state() == SnakeSession.State.OVER, "steering into the north wall ends the run")
	_check(
		over_session.end_reason() == SnakeSession.EndReason.WALL,
		"the ended run reports a wall collision"
	)
	var over_head: Vector2i = over_session.head_cell()
	var over_direction: Vector2i = over_session.direction()
	_check(INPUT_EVENTS.tap_key(KEY_LEFT), "the event helper still injects keys after the run ended")
	_check(
		INPUT_EVENTS.tap_action("snake_pause"),
		"the event helper still injects pause after the run ended"
	)
	_check(over_session.state() == SnakeSession.State.OVER, "keys do not change the over state")
	_check(over_session.head_cell() == over_head, "keys do not move the snake after the run ended")
	_check(
		over_session.direction() == over_direction,
		"keys do not change the heading after the run ended"
	)
	_check(_advance_game(over_game, 1.0) == 0, "an over run performs no more logic steps")
	_release_game(over_game)


## Advance the real game scene the way _process() does, including the controller's
## step callback, so the presentation snapshot keeps up with the logic.
func _advance_game(game: GameController, delta_seconds: float) -> int:
	return game._driver.advance(delta_seconds, game._on_logic_step)


## Instantiate the real game scene inside the running tree and skip its opening
## countdown, so injected keyboard events reach GameController._unhandled_input().
func _spawn_playing_game() -> GameController:
	var game := _spawn_game(TEST_INPUT_SAVE_DIRECTORY + "/save.json")
	if game == null:
		return null
	game._session.advance_time(SnakeSession.START_COUNTDOWN_SECONDS)
	return game


## Instantiate the game with an injected save path, then add it to the tree so
## _ready() builds the session and the UI overlays.
func _spawn_game(save_path: String) -> GameController:
	var packed := load(GAME_SCENE_PATH) as PackedScene
	if packed == null:
		_check(false, "scenes/game.tscn loads for the UI checks")
		return null
	var game := packed.instantiate() as GameController
	if game == null:
		_check(false, "scenes/game.tscn instantiates the game controller")
		return null
	game.save_path = save_path
	root.add_child(game)
	if game._session == null:
		_check(false, "the game controller starts a session for the UI checks")
		_release_game(game)
		return null
	return game


func _release_game(game: GameController) -> void:
	if game == null:
		return
	if game.is_inside_tree():
		root.remove_child(game)
	game.free()


func _test_project_settings() -> void:
	_check(ProjectSettings.get_setting("application/config/name", "") == "Game Studio", "project name is Game Studio")
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == MAIN_SCENE_PATH, "main scene is registered in project.godot")
	_check(ProjectSettings.get_setting("autoload/StudioCapture", "") == "*" + CAPTURE_SCRIPT_PATH, "StudioCapture autoload points at the capture addon")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1152, "viewport width is 1152")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 648, "viewport height is 648")


func _test_fps_log() -> void:
	var no_arguments := FpsLog.parse_args(PackedStringArray())
	_check(FpsLog.from_user_args(PackedStringArray()) == null, "no arguments create no frame sampler")
	_check(
		str(no_arguments["path"]).is_empty() and float(no_arguments["quit_after"]) == 0.0,
		"no arguments ask for no log and no quit timer"
	)
	_check(
		FpsLog.from_user_args(PackedStringArray(["--quit-after=0"])) == null,
		"a zero quit timer alone creates no sampler"
	)

	var options := FpsLog.parse_args(PackedStringArray([
		"--fps-log=production/qa/evidence/perf-fps-log/fps.log",
		"--quit-after=10",
	]))
	_check(
		str(options["path"]) == "production/qa/evidence/perf-fps-log/fps.log",
		"--fps-log carries the log path"
	)
	_check(is_equal_approx(float(options["quit_after"]), 10.0), "--quit-after carries the seconds")

	var line := FpsLog.format_line(123, 16.6667, 60.0)
	_check(line == "123,16.667,60.000", "a sample line is t_ms,frame_ms,fps with three decimals")
	var parsed := FpsLog.parse_line(line)
	_check(int(parsed.get("t_ms", -1)) == 123, "the parser recovers t_ms")
	_check(absf(float(parsed.get("frame_ms", 0.0)) - 16.667) < 0.0005, "the parser recovers frame_ms")
	_check(absf(float(parsed.get("fps", 0.0)) - 60.0) < 0.0005, "the parser recovers fps")
	_check(FpsLog.parse_line("123,16.667").is_empty(), "the parser rejects a line with two fields")
	_check(FpsLog.parse_line("t_ms,frame_ms,fps").is_empty(), "the parser rejects the header line")

	_check(not FpsLog.should_quit(199.0, 0.2), "the quit timer keeps running before its deadline")
	_check(FpsLog.should_quit(200.0, 0.2), "the quit timer fires at its deadline")
	_check(not FpsLog.should_quit(10000.0, 0.0), "a zero quit timer never quits")

	var unwritable := FpsLog.from_user_args(PackedStringArray([
		"--fps-log=res://no_such_directory_for_fps_log/fps.log",
	]))
	_check(unwritable != null, "an unwritable log path still creates the sampler")
	if unwritable != null:
		_check(not unwritable.is_logging(), "an unwritable log path leaves sampling off instead of crashing")
		unwritable.free()

	var summary := FpsLog.summarize(PackedStringArray([
		FpsLog.format_line(0, 16.0, 62.5),
		FpsLog.format_line(16, 20.0, 50.0),
		FpsLog.format_line(36, 24.0, 41.6667),
		"not a sample",
	]))
	_check(int(summary["samples"]) == 3, "the summary counts only parsable sample lines")
	_check(absf(float(summary["min_fps"]) - 41.6667) < 0.001, "the summary reports the minimum FPS")
	_check(absf(float(summary["average_fps"]) - 51.3889) < 0.001, "the summary averages the sample FPS")
	_check(absf(float(summary["p95_frame_ms"]) - 24.0) < 0.001, "the summary reports the p95 frame time")


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
	_check(is_equal_approx(classic.initial_speed, 8.0), "classic-12 starts at 8.0 cells/s")
	_check(is_equal_approx(classic.max_speed, 16.0), "classic-12 caps at 16.0 cells/s")

	var classic16: ArenaData = by_id["classic-16"]
	_check(classic16.columns == 16 and classic16.rows == 16, "classic-16 is a 16x16 board")
	_check(classic16.start_cell == Vector2i(8, 8), "classic-16 starts at [8, 8]")
	_check(classic16.start_direction == SnakeSession.EAST, "classic-16 starts facing east")
	_check(is_equal_approx(classic16.initial_speed, 8.0), "classic-16 starts at 8.0 cells/s")
	_check(is_equal_approx(classic16.max_speed, 16.0), "classic-16 caps at 16.0 cells/s")
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


func _test_save_store() -> void:
	var directory := TEST_SAVE_DIRECTORY
	_remove_temp_directory(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory + "/save.json"

	var empty := SaveStore.new(path)
	_check(not empty.load_from_disk(), "a missing save file falls back to defaults")
	_check(empty.best_score(ArenaData.MODE_CLASSIC) == 0, "default best scores are zero")
	_check(
		is_equal_approx(empty.master_volume(), SaveStore.DEFAULT_MASTER_VOLUME),
		"the default master volume is 0.8"
	)
	_check(
		is_equal_approx(empty.sfx_volume(), SaveStore.DEFAULT_SFX_VOLUME),
		"the default sfx volume is 0.8"
	)
	_check(empty.total_runs() == 0, "a fresh save has no runs")

	_check(empty.record_score(ArenaData.MODE_CLASSIC, 120), "a higher score is a new record")
	_check(not empty.record_score(ArenaData.MODE_CLASSIC, 80), "a lower score is not a record")
	_check(not empty.record_score(ArenaData.MODE_CLASSIC, 120), "an equal score is not a record")
	_check(empty.best_score(ArenaData.MODE_CLASSIC) == 120, "the best score only increases")
	empty.record_run_started()
	empty.set_master_volume(0.4)
	empty.set_sfx_volume(0.6)
	_check(empty.save(), "the save writes to disk")

	var saved_text := _read_text_file(path)
	var schema_index := saved_text.find("\"schema_version\"")
	var scores_index := saved_text.find("\"best_scores\"")
	var runs_index := saved_text.find("\"total_runs\"")
	var settings_index := saved_text.find("\"settings\"")
	_check(
		schema_index >= 0 and scores_index >= 0 and runs_index >= 0 and settings_index >= 0,
		"the save carries schema_version, best_scores, settings and total_runs"
	)
	_check(
		scores_index < schema_index and schema_index < settings_index and settings_index < runs_index,
		"the save writes keys in a stable sorted order"
	)
	_check(not FileAccess.file_exists(directory + "/save.tmp"), "no temp file is left after a write")
	_check(not empty.is_read_only(), "a version 1 save is writable")

	var reloaded := SaveStore.new(path)
	_check(reloaded.load_from_disk(), "a written save loads again")
	_check(reloaded.best_score(ArenaData.MODE_CLASSIC) == 120, "the best score survives a round trip")
	_check(is_equal_approx(reloaded.master_volume(), 0.4), "the master volume survives a round trip")
	_check(is_equal_approx(reloaded.sfx_volume(), 0.6), "the sfx volume survives a round trip")
	_check(reloaded.total_runs() == 1, "the run count survives a round trip")

	_check(reloaded.record_score(ArenaData.MODE_CLASSIC, 150), "a later higher score is a record")
	_check(reloaded.save(), "the second save replaces the first")
	_check(FileAccess.file_exists(directory + "/save.bak"), "the previous save is kept as save.bak")
	_check(
		_read_text_file(directory + "/save.bak").contains("\"classic\": 120"),
		"save.bak holds the previous best score"
	)

	_remove_temp_directory(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	_write_text_file(path, "{ this is not json")
	var corrupt := SaveStore.new(path)
	_check(not corrupt.load_from_disk(), "a corrupt save falls back to defaults")
	_check(corrupt.best_score(ArenaData.MODE_CLASSIC) == 0, "a corrupt save loads default scores")
	var quarantined := ""
	for file_name in _files_in(directory):
		if file_name.begins_with("save.corrupt-") and file_name.ends_with(".json"):
			quarantined = file_name
	_check(not quarantined.is_empty(), "the corrupt file is renamed to save.corrupt-<ts>.json")
	_check(
		_read_text_file(directory + "/" + quarantined) == "{ this is not json",
		"the quarantined file keeps its original text"
	)

	_write_text_file(path, "{ still not json")
	_write_text_file(directory + "/save.bak", JSON.stringify({
		"schema_version": 1,
		"best_scores": {"classic": 90, "maze": 0, "time_attack": 0},
		"total_runs": 4,
		"settings": {"master_volume": 0.5, "sfx_volume": 0.5},
	}))
	var from_backup := SaveStore.new(path)
	_check(from_backup.load_from_disk(), "a corrupt save falls back to save.bak")
	_check(from_backup.best_score(ArenaData.MODE_CLASSIC) == 90, "the backup best score is used")

	_write_text_file(path, JSON.stringify({
		"schema_version": 2,
		"best_scores": {"classic": 500},
		"total_runs": 9,
		"settings": {"master_volume": 0.1, "sfx_volume": 0.1},
	}))
	var read_only := SaveStore.new(path)
	_check(read_only.load_from_disk(), "a newer schema still loads its readable fields")
	_check(read_only.is_read_only(), "a newer schema makes the store read-only")
	_check(read_only.best_score(ArenaData.MODE_CLASSIC) == 500, "the newer schema best score is readable")
	_check(
		is_equal_approx(read_only.master_volume(), SaveStore.DEFAULT_MASTER_VOLUME),
		"a newer schema uses default settings"
	)
	_check(not read_only.save(), "a read-only store refuses to write")
	var newer_data: Variant = JSON.parse_string(_read_text_file(path))
	var newer_version := 0
	if typeof(newer_data) == TYPE_DICTIONARY:
		newer_version = int((newer_data as Dictionary).get("schema_version", 0))
	_check(newer_version == 2, "the newer schema file is not overwritten")

	_remove_temp_directory(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	_write_text_file(path, JSON.stringify({
		"schema_version": 1,
		"best_scores": {},
		"total_runs": -5,
		"settings": {"master_volume": 5.0, "sfx_volume": -1.0},
	}))
	var clamped := SaveStore.new(path)
	clamped.load_from_disk()
	_check(is_equal_approx(clamped.master_volume(), 1.0), "a volume above 1 clamps to 1")
	_check(is_equal_approx(clamped.sfx_volume(), 0.0), "a volume below 0 clamps to 0")
	_check(clamped.total_runs() == 0, "a negative run count clamps to 0")
	_check(SaveStore.SCHEMA_VERSION == 1, "the save schema version is 1")
	_remove_temp_directory(directory)


func _test_app_shell() -> void:
	var directory := TEST_SHELL_DIRECTORY
	_remove_temp_directory(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_check(false, "the main scene loads for the shell checks")
		return
	var shell := packed.instantiate() as AppRoot
	if shell == null:
		_check(false, "the main scene instantiates the app shell")
		return
	shell.save_path = directory + "/save.json"
	root.add_child(shell)
	_check(shell.current_screen() == AppRoot.Screen.MAIN_MENU, "a fresh launch shows the main menu")
	var menu := shell.menu_node()
	_check(menu != null, "the main menu is the first screen")
	_check(shell.game_node() == null, "no game runs behind the main menu")
	var play: Button = null
	if menu != null:
		play = menu.get_node_or_null("Center/Panel/Margin/VBox/PlayButton") as Button
	if play != null:
		play.emit_signal("pressed")
	_check(shell.current_screen() == AppRoot.Screen.GAME, "Play routes to the game")
	var game := shell.game_node()
	_check(game != null, "Play creates the game scene")
	_check(shell.menu_node() == null, "Play releases the main menu")
	if game != null:
		_check(game._arena != null and game._arena.mode == ArenaData.MODE_CLASSIC, "Play starts Classic")

	shell.return_to_main_menu()
	_check(shell.current_screen() == AppRoot.Screen.MAIN_MENU, "Main menu returns to the title screen")
	_check(shell.game_node() == null, "returning to the menu drops the game scene")

	shell.open_how_to_play()
	_check(shell.current_screen() == AppRoot.Screen.HOW_TO_PLAY, "How to play opens its own screen")
	var page := shell.how_to_play_node()
	_check(page != null, "the how-to-play page is loaded")
	if page != null:
		var cancel := InputEventAction.new()
		cancel.action = &"ui_cancel"
		cancel.pressed = true
		page._unhandled_input(cancel)
		_check(
			shell.current_screen() == AppRoot.Screen.MAIN_MENU,
			"Esc leaves How to play for the main menu"
		)

	shell.open_how_to_play()
	var open_page := shell.how_to_play_node()
	if open_page != null:
		var back_button := open_page.get_node_or_null("Center/Panel/Margin/VBox/BackButton") as Button
		if back_button != null:
			back_button.emit_signal("pressed")
	_check(
		shell.current_screen() == AppRoot.Screen.MAIN_MENU,
		"the Back button leaves How to play"
	)
	root.remove_child(shell)
	shell.free()
	_remove_temp_directory(directory)


func _test_hud_pause_and_end_panel() -> void:
	var directory := TEST_PANEL_DIRECTORY
	_remove_temp_directory(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory + "/save.json"
	var game := _spawn_game(path)
	if game == null:
		return
	game._session.advance_time(SnakeSession.START_COUNTDOWN_SECONDS)
	var hud := game.get_node("HUD")
	_check(hud.get_node("Stats/VBox/ScoreLabel").text == "Score: 0", "the HUD shows the score")
	_check(hud.get_node("Stats/VBox/LengthLabel").text == "Length: 4", "the HUD shows the snake length")
	_check(
		hud.get_node("Stats/VBox/SpeedLabel").text == "Speed: 8.0 cells/s",
		"the HUD shows the speed in cells/s"
	)
	_check(hud.get_node("Stats/VBox/TimeLabel").text == "Time: 0:00", "the HUD shows the run time")
	_check(hud.get_node("Best/BestLabel").text == "Best: 0", "the HUD shows the best score")
	_check(Hud.format_time(75.9) == "1:15", "the HUD clock formats minutes and seconds")

	var pause_menu := game.get_node("PauseMenu") as PauseMenu
	var end_panel := game.get_node("EndPanel") as EndPanel
	_check(not pause_menu.visible, "the pause menu starts hidden")
	_check(not end_panel.visible, "the end panel starts hidden")

	game.toggle_pause()
	_check(game._session.state() == SnakeSession.State.PAUSED, "Esc pauses the run")
	_check(pause_menu.visible, "the pause menu opens")
	var resume := game.get_node("PauseMenu/Root/Center/Panel/Margin/VBox/ResumeButton") as Button
	_check(resume.has_focus(), "the pause menu focuses Resume")
	var paused_head: Vector2i = game._session.head_cell()
	_check(_advance_game(game, 1.0) == 0, "a paused run takes no logic steps")
	_check(game._session.head_cell() == paused_head, "a paused snake does not move")
	_check(not game._session.turn(SnakeSession.NORTH), "a paused run ignores turns")
	game.resume_run()
	_check(
		game._session.state() == SnakeSession.State.COUNTDOWN,
		"Resume restarts the countdown from the pause point"
	)
	_check(not pause_menu.visible, "the pause menu closes on resume")
	_check(
		game._session.head_cell() == paused_head,
		"the snake stays on the pause cell during the resume countdown"
	)

	game._session.advance_time(SnakeSession.START_COUNTDOWN_SECONDS)
	_check(game._session.state() == SnakeSession.State.PLAYING, "the resume countdown hands control back")
	_check(_navigate_to_food(game._session, game._arena), "the run reaches food before the end panel")
	game._emit_stats_if_changed()
	_check(hud.get_node("Stats/VBox/ScoreLabel").text == "Score: 10", "the HUD score updates from the stats signal")
	_check(hud.get_node("Stats/VBox/LengthLabel").text == "Length: 5", "the HUD length updates from the stats signal")
	_check(
		hud.get_node("Stats/VBox/SpeedLabel").text == "Speed: 8.2 cells/s",
		"the HUD speed updates from the stats signal"
	)

	game._session.turn(SnakeSession.NORTH)
	var steps := 0
	while game._session.state() == SnakeSession.State.PLAYING and steps < MAX_TEST_STEPS:
		game._session.step()
		steps += 1
	_check(game._session.state() == SnakeSession.State.OVER, "the run ends after turning into the wall")
	game._emit_status_if_changed()
	_check(end_panel.visible, "the end panel opens when the run ends")
	_check(
		end_panel.get_node("Root/Center/Panel/Margin/VBox/ScoreLabel").text == "Score: 10",
		"the end panel shows the run score"
	)
	_check(
		end_panel.get_node("Root/Center/Panel/Margin/VBox/BestLabel").text == "Best: 10",
		"the end panel shows the new best score"
	)
	_check(
		end_panel.get_node("Root/Center/Panel/Margin/VBox/NewBestLabel").visible,
		"a record run is marked New best"
	)
	var retry := game.get_node("EndPanel/Root/Center/Panel/Margin/VBox/RetryButton") as Button
	_check(retry.has_focus(), "the end panel focuses Retry")
	_check(not pause_menu.visible, "the pause menu stays closed after the run ends")
	_check(game._save_store.best_score(ArenaData.MODE_CLASSIC) == 10, "the best score is recorded")
	var reloaded := SaveStore.new(path)
	_check(
		reloaded.load_from_disk() and reloaded.best_score(ArenaData.MODE_CLASSIC) == 10,
		"the best score is persisted to disk"
	)

	var menu_requested := {"value": false}
	game.main_menu_requested.connect(func() -> void: menu_requested["value"] = true)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	end_panel._unhandled_input(cancel)
	_check(menu_requested["value"], "Esc on the end panel asks for the main menu")

	game.restart_run()
	_check(game._session.state() == SnakeSession.State.COUNTDOWN, "Retry starts a fresh countdown")
	_check(game._session.score() == 0, "Retry starts from zero score")
	_check(not end_panel.visible, "Retry hides the end panel")
	_check(game._save_store.best_score(ArenaData.MODE_CLASSIC) == 10, "Retry keeps the best score")
	_release_game(game)
	_remove_temp_directory(directory)


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


func _write_text_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "the test can write %s" % path)
		return
	file.store_string(text)
	file.close()


func _read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _files_in(directory_path: String) -> Array[String]:
	var names: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return names
	for name: String in directory.get_files():
		names.append(name)
	names.sort()
	return names


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
