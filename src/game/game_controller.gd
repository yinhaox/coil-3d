class_name GameController
extends Node3D

## Scene-layer drive for one run: loads the start arena, registers input, runs
## the frame accumulator over SnakeSession and pushes cell snapshots to the
## presentation views. It never changes rules state directly: movement, turns,
## collisions, score and speed stay in src/logic/snake_session.gd
## (design/architecture.md rules 12-17).

signal status_changed(score: int, state: int, end_reason: int)

const ARENA_DIRECTORY := "res://assets/data/arenas"
const TURN_ACTIONS := {
	"snake_up": SnakeSession.NORTH,
	"snake_down": SnakeSession.SOUTH,
	"snake_left": SnakeSession.WEST,
	"snake_right": SnakeSession.EAST,
}
const TURN_KEYS := {
	"snake_up": [KEY_W, KEY_UP],
	"snake_down": [KEY_S, KEY_DOWN],
	"snake_left": [KEY_A, KEY_LEFT],
	"snake_right": [KEY_D, KEY_RIGHT],
}
const PAUSE_ACTION := "snake_pause"
const PAUSE_KEYS: Array[int] = [KEY_ESCAPE]

const SCENARIO_INITIAL := "initial"
const SCENARIO_EATEN := "eaten"
const SCENARIO_TURNING := "turning"
const SCENARIO_TURN_PREVIEW := "turn-preview"
const SCENARIO_OVER := "over"
const TURNING_ALPHA := 0.45
const TURNING_TWEEN_PROGRESS := 0.5
const MAX_FOOD_PATH_STEPS := 256
const NO_STAGED_ALPHA := -1.0
const INVALID_STATUS := Vector3i(-1, -1, -1)
const USER_ARGUMENT_KEYS: Array[String] = ["arena", "scenario", "seed"]
const CAPTURE_ARGUMENT := "studio-capture"

@onready var _camera: IsoCamera = $Camera
@onready var _arena_view: ArenaView = $ArenaView
@onready var _snake_view: SnakeView = $SnakeView
@onready var _food_view: FoodView = $FoodView

var _arena: ArenaData
var _session: SnakeSession
var _driver: SessionDriver
var _previous_cells: Array[Vector2i] = []
var _current_cells: Array[Vector2i] = []
var _previous_direction: Vector2i = SnakeSession.EAST
var _direction: Vector2i = SnakeSession.EAST
var _capture_frozen := false
var _staged_alpha := NO_STAGED_ALPHA
var _last_status := INVALID_STATUS


func _ready() -> void:
	_register_actions()
	var arguments := _user_arguments()
	_arena = _load_start_arena(arguments)
	if _arena == null:
		push_error("game_controller: no playable arena in %s" % ARENA_DIRECTORY)
		return
	_session = SnakeSession.new(_arena, _seed_from(arguments))
	_session.start()
	_driver = SessionDriver.new(_session)
	_camera.setup(_arena.columns, _arena.rows)
	_arena_view.build(_arena)
	_snake_view.configure(_arena.columns, _arena.rows)
	_food_view.configure(_arena.columns, _arena.rows)
	_snapshot_initial_state()
	_stage_scenario(str(arguments.get("scenario", SCENARIO_INITIAL)))
	_snake_view.set_interpolation_alpha(_current_alpha())
	_snake_view.update_view(0.0)
	_food_view.update_view(0.0)
	_camera.update_view(0.0)
	_emit_status_if_changed()


func _process(delta: float) -> void:
	if _session == null:
		return
	if not _capture_frozen:
		_driver.advance(delta, _on_logic_step)
	_snake_view.set_interpolation_alpha(_current_alpha())
	_snake_view.update_view(delta)
	_food_view.update_view(delta)
	_camera.update_view(delta)
	_emit_status_if_changed()


func _unhandled_input(event: InputEvent) -> void:
	if _session == null or _capture_frozen:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.is_action_pressed(PAUSE_ACTION):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	for action: String in TURN_ACTIONS.keys():
		if event.is_action_pressed(action):
			var direction: Vector2i = TURN_ACTIONS[action]
			if _session.turn(direction):
				# Start the head turn on this frame; the logic step that consumes
				# the queued turn still decides when the cell advances.
				_snake_view.preview_turn(direction, _session.step_duration_seconds())
			get_viewport().set_input_as_handled()
			return


## The registered pause action toggles between playing and paused. The logic
## state owns the freeze (design/core-rules.md rule 10); the pause menu and the
## scene-tree pause are part of the later UI story.
func _toggle_pause() -> void:
	match _session.state():
		SnakeSession.State.PLAYING:
			_session.pause()
		SnakeSession.State.PAUSED:
			_session.resume()


## Startup arena: the requested id, else the first Classic arena by file name.
static func select_start_arena(loaded: ArenaData.LoadResult, requested_id: String) -> ArenaData:
	if loaded == null:
		return null
	if requested_id.is_empty():
		return loaded.arena_for_mode(ArenaData.MODE_CLASSIC)
	for arena in loaded.arenas:
		if arena.id == requested_id:
			return arena
	return null


func _load_start_arena(arguments: Dictionary) -> ArenaData:
	var loaded := ArenaData.load_directory(ARENA_DIRECTORY)
	for message in loaded.errors:
		push_error("arena load: %s" % message)
	return select_start_arena(loaded, str(arguments.get("arena", "")))


func _register_actions() -> void:
	for action: String in TURN_ACTIONS.keys():
		_register_action(action, TURN_KEYS[action])
	_register_action(PAUSE_ACTION, PAUSE_KEYS)


func _register_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _snapshot_initial_state() -> void:
	_current_cells = _session.body_cells()
	_previous_cells = _current_cells
	_direction = _session.direction()
	_previous_direction = _direction
	_snake_view.apply_step(
		_previous_cells, _current_cells, _direction, _direction,
		_session.step_duration_seconds(), false
	)
	_food_view.set_food_cells(_session.food_cells())


func _on_logic_step(result: SnakeSession.StepResult) -> void:
	_previous_cells = _current_cells
	_previous_direction = _direction
	_current_cells = _session.body_cells()
	_direction = _session.direction()
	_snake_view.apply_step(
		_previous_cells, _current_cells, _previous_direction, _direction,
		_session.step_duration_seconds(), result.ate
	)
	_food_view.set_food_cells(_session.food_cells())


func _current_alpha() -> float:
	if _staged_alpha >= 0.0:
		return _staged_alpha
	if _driver == null:
		return 1.0
	return _driver.alpha()


func _emit_status_if_changed() -> void:
	var status := Vector3i(_session.score(), _session.state(), _session.end_reason())
	if status == _last_status:
		return
	_last_status = status
	status_changed.emit(status.x, status.y, status.z)


# --- Capture staging -------------------------------------------------------
# The capture addon can only take a screenshot at startup, so these scenarios
# fast-forward the real session through logic steps and freeze the real views
# at a chosen interpolation point. No rendering is faked.


func _stage_scenario(scenario_name: String) -> void:
	match scenario_name:
		SCENARIO_EATEN:
			_capture_frozen = true
			_staged_alpha = 1.0
			_stage_eaten()
		SCENARIO_TURNING:
			_capture_frozen = true
			_staged_alpha = TURNING_ALPHA
			_stage_turning()
		SCENARIO_TURN_PREVIEW:
			_capture_frozen = true
			_staged_alpha = TURNING_ALPHA
			_stage_turn_preview()
		SCENARIO_OVER:
			_capture_frozen = true
			_staged_alpha = 1.0
			_stage_over()
		_:
			_capture_frozen = false


func _stage_eaten() -> void:
	_advance_countdown()
	var path := _path_to_nearest_food()
	for index in range(1, mini(path.size(), MAX_FOOD_PATH_STEPS)):
		_session.turn(path[index] - path[index - 1])
		_step_once()
		if _session.state() != SnakeSession.State.PLAYING:
			break
	if _session.food_eaten() == 0:
		push_warning("capture scenario 'eaten' did not reach food")


func _stage_turning() -> void:
	_advance_countdown()
	_step_once()
	_step_once()
	_session.turn(SnakeSession.SOUTH)
	_step_once()
	_snake_view.stage_turn_progress(TURNING_TWEEN_PROGRESS)


## The input frame: the turn is accepted and the head starts turning now, while
## the body is still in the current east step. The tween is held before the step
## ends so a startup capture can show the head already facing the new direction.
func _stage_turn_preview() -> void:
	_advance_countdown()
	_step_once()
	_step_once()
	if _session.turn(SnakeSession.NORTH):
		_snake_view.preview_turn(SnakeSession.NORTH, _session.step_duration_seconds())
	# The preview started at this step's start, so at TURNING_ALPHA it has played
	# alpha x step_duration of its 0.10 s tween.
	var preview_progress := (
		TURNING_ALPHA * _session.step_duration_seconds() / SnakeView.TURN_TWEEN_SECONDS
	)
	_snake_view.stage_turn_progress(clampf(preview_progress, 0.0, 1.0))


func _stage_over() -> void:
	_advance_countdown()
	_session.turn(SnakeSession.NORTH)
	var steps := 0
	while _session.state() == SnakeSession.State.PLAYING and steps < MAX_FOOD_PATH_STEPS:
		_step_once()
		steps += 1


func _advance_countdown() -> void:
	_driver.advance(SnakeSession.START_COUNTDOWN_SECONDS, _on_logic_step)


func _step_once() -> void:
	_on_logic_step(_session.step())


func _path_to_nearest_food() -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var foods := _session.food_cells()
	if foods.is_empty():
		return path
	var target: Vector2i = foods[0]
	var blocked: Dictionary = {}
	for cell in _arena.obstacles:
		blocked[cell] = true
	for cell in _session.body_cells():
		blocked[cell] = true
	blocked.erase(target)
	var start: Vector2i = _session.head_cell()
	var came_from: Dictionary = {start: start}
	var frontier: Array[Vector2i] = [start]
	var found := false
	while not frontier.is_empty() and not found:
		var current: Vector2i = frontier.pop_front()
		for direction in SnakeSession.DIRECTIONS:
			var next: Vector2i = current + direction
			if next == target:
				came_from[next] = current
				found = true
				break
			if not _arena.is_inside(next) or blocked.has(next) or came_from.has(next):
				continue
			came_from[next] = current
			frontier.append(next)
	if not found:
		return path
	var cursor: Vector2i = target
	while cursor != start:
		path.append(cursor)
		cursor = came_from[cursor]
	path.append(start)
	path.reverse()
	return path


# --- User arguments --------------------------------------------------------


func _user_arguments() -> Dictionary:
	var arguments: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var pair := argument.substr(2).split("=", true, 1)
		var key: String = pair[0]
		if key == CAPTURE_ARGUMENT:
			continue
		if not USER_ARGUMENT_KEYS.has(key):
			push_warning("game_controller: ignoring unknown argument '%s'" % key)
			continue
		arguments[key] = pair[1] if pair.size() > 1 else ""
	return arguments


func _seed_from(arguments: Dictionary) -> int:
	var raw := str(arguments.get("seed", ""))
	if raw.is_empty():
		return randi()
	return int(raw)
