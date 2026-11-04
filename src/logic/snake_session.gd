class_name SnakeSession
extends RefCounted

## Pure-logic Coil session: movement, turns, growth, food, collisions, score,
## speed and the arena-defined time limit.
##
## No Node, no Input, no scene tree and no disk access: tests construct it
## directly. `step()` advances exactly one logic step; the frame loop decides
## when to call it (design/architecture.md). Rules: design/core-rules.md.

const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const DIRECTIONS: Array[Vector2i] = [EAST, WEST, NORTH, SOUTH]

## Core-rules constants (design/core-rules.md "Numbers and tuning").
const INITIAL_LENGTH: int = ArenaData.INITIAL_SNAKE_LENGTH
const POINTS_PER_FOOD := 10
const SPEED_GAIN_PER_FOOD := 0.2
const TURN_QUEUE_LIMIT := 2
const START_COUNTDOWN_SECONDS := 1.0

enum State { IDLE, COUNTDOWN, PLAYING, PAUSED, OVER }
enum EndReason { NONE, WALL, OBSTACLE, SELF, TIME_UP, CLEARED }


class StepResult:
	var stepped: bool = false
	var previous_head: Vector2i = Vector2i.ZERO
	var head: Vector2i = Vector2i.ZERO
	var ate: bool = false
	var score_delta: int = 0
	var speed_changed: bool = false
	var end_reason: int = SnakeSession.EndReason.NONE


var _arena: ArenaData
var _rng := RandomNumberGenerator.new()
var _time_source: Callable = Callable()
var _obstacle_lookup: Dictionary = {}

var _state: int = State.IDLE
var _end_reason: int = EndReason.NONE
var _body: Array[Vector2i] = []
var _foods: Array[Vector2i] = []
var _food_lookup: Dictionary = {}
var _pending_turns: Array[Vector2i] = []
var _step_direction: Vector2i = EAST
var _score: int = 0
var _food_eaten: int = 0
var _speed: float = 0.0
var _countdown_remaining: float = 0.0
var _elapsed_seconds: float = 0.0
var _clock_origin: float = NAN
var _pause_started_at: float = 0.0


func _init(arena: ArenaData, seed_value: int = 0) -> void:
	assert(arena != null, "SnakeSession requires arena data")
	_arena = arena
	_rng.seed = seed_value
	for cell in arena.obstacles:
		_obstacle_lookup[cell] = true
	_reset_run()


## Inject the clock that owns the time-attack timer. Without one, elapsed time
## is accumulated from the logic steps themselves.
func set_time_source(source: Callable) -> void:
	_time_source = source


## Create a fresh run: snake on the start cells, food at food_max, countdown.
func start() -> void:
	_reset_run()
	_step_direction = _arena.start_direction
	_build_initial_body()
	_clock_origin = NAN
	_elapsed_seconds = 0.0
	_state = State.COUNTDOWN
	_countdown_remaining = START_COUNTDOWN_SECONDS
	_refill_food()
	if _is_board_cleared():
		_end_run(EndReason.CLEARED)


## Advance the countdown. Movement time is owned by step(); pause freezes both.
func advance_time(delta_seconds: float) -> void:
	if delta_seconds <= 0.0 or _state != State.COUNTDOWN:
		return
	_countdown_remaining = maxf(_countdown_remaining - delta_seconds, 0.0)
	if _countdown_remaining <= 0.0:
		_enter_playing()


func pause() -> void:
	if _state != State.PLAYING:
		return
	_state = State.PAUSED
	_pause_started_at = _now()


func resume() -> void:
	if _state != State.PAUSED:
		return
	if _time_source.is_valid() and not is_nan(_clock_origin):
		_clock_origin += _now() - _pause_started_at
	_state = State.COUNTDOWN
	_countdown_remaining = START_COUNTDOWN_SECONDS


## Queue a turn. Returns false when the input is ignored (not playing, not an
## axis direction, a 180° reverse, a repeat, or a full queue).
func turn(direction: Vector2i) -> bool:
	if _state != State.PLAYING:
		return false
	if not DIRECTIONS.has(direction):
		return false
	var reference := _step_direction
	if not _pending_turns.is_empty():
		reference = _pending_turns[_pending_turns.size() - 1]
	if direction == reference or direction == -reference:
		return false
	if _pending_turns.size() >= TURN_QUEUE_LIMIT:
		return false
	_pending_turns.append(direction)
	return true


## Advance exactly one logic step. Returns the events of that step; `stepped`
## is false while the session is not playing (countdown, paused, over).
func step() -> StepResult:
	var result := StepResult.new()
	if _state != State.PLAYING:
		return result
	_sample_elapsed()
	_consume_queued_turn()
	var next_head: Vector2i = _body[0] + _step_direction
	var eating: bool = _food_lookup.has(next_head)
	var collision := _collision_reason(next_head, eating)
	if collision != EndReason.NONE:
		_end_run(collision)
		result.end_reason = collision
		return result
	var previous_head: Vector2i = _body[0]
	_advance_body(next_head, eating)
	result.stepped = true
	result.previous_head = previous_head
	result.head = next_head
	result.ate = eating
	if eating:
		result.score_delta = POINTS_PER_FOOD
		result.speed_changed = _eat_food(next_head)
		if _state == State.OVER:
			result.end_reason = _end_reason
			return result
	if _arena.has_time_limit and _elapsed_seconds >= _arena.time_limit_seconds:
		_end_run(EndReason.TIME_UP)
		result.end_reason = EndReason.TIME_UP
	return result


func state() -> int:
	return _state


func end_reason() -> int:
	return _end_reason


func head_cell() -> Vector2i:
	if _body.is_empty():
		return _arena.start_cell
	return _body[0]


func body_cells() -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	copy.assign(_body)
	return copy


func food_cells() -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	copy.assign(_foods)
	return copy


func direction() -> Vector2i:
	return _step_direction


func score() -> int:
	return _score


## Segment count. A plain accessor for the HUD, so the read path allocates no
## array copy the way `body_cells()` does.
func length() -> int:
	return _body.size()


func food_eaten() -> int:
	return _food_eaten


func speed_cells_per_second() -> float:
	return _speed


func step_duration_seconds() -> float:
	return 1.0 / _speed


func elapsed_seconds() -> float:
	return _elapsed_seconds


func _reset_run() -> void:
	_state = State.IDLE
	_end_reason = EndReason.NONE
	_body.clear()
	_foods.clear()
	_food_lookup.clear()
	_pending_turns.clear()
	_score = 0
	_food_eaten = 0
	_speed = _arena.initial_speed
	_countdown_remaining = 0.0
	_elapsed_seconds = 0.0
	_clock_origin = NAN


func _build_initial_body() -> void:
	_body.clear()
	for index in range(INITIAL_LENGTH):
		_body.append(_arena.start_cell - _arena.start_direction * index)


func _enter_playing() -> void:
	if _time_source.is_valid() and is_nan(_clock_origin):
		_clock_origin = _now()
	_state = State.PLAYING


func _consume_queued_turn() -> void:
	if not _pending_turns.is_empty():
		_step_direction = _pending_turns.pop_front()


func _advance_body(next_head: Vector2i, eating: bool) -> void:
	if not eating:
		_body.pop_back()
	_body.push_front(next_head)


func _eat_food(cell: Vector2i) -> bool:
	_food_lookup.erase(cell)
	_foods.erase(cell)
	_score += POINTS_PER_FOOD
	_food_eaten += 1
	var previous_speed := _speed
	_speed = minf(
		_arena.initial_speed + SPEED_GAIN_PER_FOOD * float(_food_eaten),
		_arena.max_speed
	)
	_refill_food()
	if _is_board_cleared():
		_end_run(EndReason.CLEARED)
	return not is_equal_approx(previous_speed, _speed)


## Returns why `next_head` is fatal, or NONE. The tail cell is legal when it
## vacates this step (core-rules.md rule 7); an eating step grows first, so its
## full body stays occupied.
func _collision_reason(next_head: Vector2i, eating: bool) -> int:
	if not _arena.is_inside(next_head):
		return EndReason.WALL
	if _obstacle_lookup.has(next_head):
		return EndReason.OBSTACLE
	var limit := _body.size() if eating else _body.size() - 1
	for index in range(limit):
		if _body[index] == next_head:
			return EndReason.SELF
	return EndReason.NONE


func _refill_food() -> void:
	var wanted := _arena.food_max - _foods.size()
	if wanted <= 0:
		return
	var free_cells := _free_cells()
	var spawn_count := mini(wanted, free_cells.size())
	for _index in range(spawn_count):
		var pick := _rng.randi_range(0, free_cells.size() - 1)
		var cell: Vector2i = free_cells[pick]
		free_cells.remove_at(pick)
		_foods.append(cell)
		_food_lookup[cell] = true


func _free_cells() -> Array[Vector2i]:
	var occupied: Dictionary = {}
	for cell in _body:
		occupied[cell] = true
	for cell in _obstacle_lookup.keys():
		occupied[cell] = true
	for cell in _foods:
		occupied[cell] = true
	var free_cells: Array[Vector2i] = []
	for z in range(_arena.rows):
		for x in range(_arena.columns):
			var cell := Vector2i(x, z)
			if not occupied.has(cell):
				free_cells.append(cell)
	return free_cells


func _is_board_cleared() -> bool:
	return _body.size() + _obstacle_lookup.size() >= _arena.total_cells()


func _end_run(reason: int) -> void:
	_state = State.OVER
	_end_reason = reason


func _sample_elapsed() -> void:
	if _time_source.is_valid() and not is_nan(_clock_origin):
		_elapsed_seconds = maxf(0.0, _now() - _clock_origin)
	else:
		_elapsed_seconds += step_duration_seconds()


func _now() -> float:
	if not _time_source.is_valid():
		return 0.0
	return float(_time_source.call())
