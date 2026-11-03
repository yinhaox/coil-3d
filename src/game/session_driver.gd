class_name SessionDriver
extends RefCounted

## Frame accumulator for one SnakeSession (design/architecture.md rules 12 and
## 15). It owns the countdown tick and decides when the frame loop calls
## `step()`; the unused time stays for presentation interpolation.
##
## State handling:
## - COUNTDOWN: advance the countdown only. That delta is consumed; it is never
##   also spent on a step (core-rules.md rule 10).
## - PLAYING: accumulate, run at most MAX_STEPS_PER_FRAME steps, keep the
##   remainder as the interpolation alpha.
## - PAUSED: freeze, keep the remainder (core-rules.md edge case "暂停发生在
##   两步之间").
## - OVER: freeze and drop the remainder, so the renderer cannot slide towards
##   a move that never happened.

const MAX_STEPS_PER_FRAME := 4

var _session: SnakeSession
var _accumulator := 0.0


func _init(session: SnakeSession) -> void:
	assert(session != null, "SessionDriver requires a session")
	_session = session


## Advance one frame. Returns the number of logic steps performed this frame;
## `on_step` receives each StepResult after the step so the presentation can
## snapshot cells and play its tween.
func advance(delta_seconds: float, on_step: Callable = Callable()) -> int:
	if delta_seconds <= 0.0:
		return 0
	match _session.state():
		SnakeSession.State.COUNTDOWN:
			_session.advance_time(delta_seconds)
			return 0
		SnakeSession.State.PLAYING:
			pass
		SnakeSession.State.OVER:
			_accumulator = 0.0
			return 0
		_:
			return 0
	_accumulator += delta_seconds
	var steps := 0
	while steps < MAX_STEPS_PER_FRAME and _session.state() == SnakeSession.State.PLAYING:
		var duration := _session.step_duration_seconds()
		if duration <= 0.0 or _accumulator < duration:
			break
		_accumulator -= duration
		var result := _session.step()
		steps += 1
		if on_step.is_valid():
			on_step.call(result)
	if _session.state() != SnakeSession.State.PLAYING:
		_accumulator = 0.0
	else:
		_accumulator = minf(_accumulator, _session.step_duration_seconds())
	return steps


## Fraction of the next logic step already elapsed, in 0..1.
func alpha() -> float:
	var duration := _session.step_duration_seconds()
	if duration <= 0.0:
		return 0.0
	return clampf(_accumulator / duration, 0.0, 1.0)


func accumulator_seconds() -> float:
	return _accumulator
