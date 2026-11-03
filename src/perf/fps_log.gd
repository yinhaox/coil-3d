class_name FpsLog
extends Node

## Per-frame frame-time sampling for a reproducible performance run.
##
## Enabled only by user arguments, i.e. the ones after the engine's `--`:
##   --fps-log=<path>        write one "t_ms,frame_ms,fps" line per frame
##   --quit-after=<seconds>  quit once that much wall time has passed
##
## Without them src/main.gd never creates this node, so a normal run writes no
## file and behaves exactly as before. A path that cannot be opened is reported
## with one warning and sampling stays off; the game keeps running.
##
## The parser and the summary below read a log back. They are what
## tests/fps_summary.gd uses to turn a real run into the numbers the evidence
## index quotes, so the sampled format has a single implementation.

const LOG_FLAG := "--fps-log="
const QUIT_AFTER_FLAG := "--quit-after="
const LINE_FORMAT := "%d,%.3f,%.3f"
const FIELD_COUNT := 3
const MILLISECONDS_PER_SECOND := 1000.0
const P95_PERCENTILE := 0.95
const NO_QUIT_AFTER := 0.0

var _log_path := ""
var _quit_after_seconds := NO_QUIT_AFTER
var _file: FileAccess
var _start_usec := 0


## Builds the sampler from the user arguments, or returns null when neither
## flag is present so a plain run keeps its old behavior.
static func from_user_args(user_args: PackedStringArray) -> FpsLog:
	var options := parse_args(user_args)
	if not is_requested(options):
		return null
	var sampler := FpsLog.new()
	sampler._begin(str(options["path"]), float(options["quit_after"]))
	return sampler


## Returns {"path": String, "quit_after": float}; an unknown value for either
## flag is ignored instead of guessed.
static func parse_args(user_args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {"path": "", "quit_after": NO_QUIT_AFTER}
	for argument: String in user_args:
		if argument.begins_with(LOG_FLAG):
			options["path"] = argument.substr(LOG_FLAG.length()).strip_edges()
		elif argument.begins_with(QUIT_AFTER_FLAG):
			var raw := argument.substr(QUIT_AFTER_FLAG.length()).strip_edges()
			if raw.is_valid_float():
				options["quit_after"] = maxf(raw.to_float(), NO_QUIT_AFTER)
	return options


static func is_requested(options: Dictionary) -> bool:
	return (
		not str(options.get("path", "")).is_empty()
		or float(options.get("quit_after", NO_QUIT_AFTER)) > NO_QUIT_AFTER
	)


## Resolves a log path to an absolute OS path. A relative path is relative to
## the project root, which is the directory every studio command runs in.
static func resolve_path(raw_path: String) -> String:
	if raw_path.is_empty():
		return ""
	if raw_path.begins_with("res://") or raw_path.begins_with("user://"):
		return ProjectSettings.globalize_path(raw_path)
	if raw_path.is_absolute_path():
		return raw_path
	return ProjectSettings.globalize_path("res://" + raw_path)


static func format_line(t_ms: int, frame_ms: float, fps: float) -> String:
	return LINE_FORMAT % [t_ms, frame_ms, fps]


## Returns {"t_ms": int, "frame_ms": float, "fps": float}, or {} when the line
## is not exactly one sample.
static func parse_line(line: String) -> Dictionary:
	var fields := line.strip_edges().split(",")
	if fields.size() != FIELD_COUNT:
		return {}
	if not (fields[0].is_valid_int() and fields[1].is_valid_float() and fields[2].is_valid_float()):
		return {}
	return {
		"t_ms": fields[0].to_int(),
		"frame_ms": fields[1].to_float(),
		"fps": fields[2].to_float(),
	}


## Turns sample lines into the numbers the evidence index quotes. p95 uses the
## ceiling index of the sorted frame times, so a short run reports its slowest
## frame instead of a value between samples.
static func summarize(lines: PackedStringArray) -> Dictionary:
	var frame_times: Array[float] = []
	var total_fps := 0.0
	var min_fps := 0.0
	for line: String in lines:
		var sample := parse_line(line)
		if sample.is_empty():
			continue
		var fps := float(sample["fps"])
		total_fps += fps
		if frame_times.is_empty() or fps < min_fps:
			min_fps = fps
		frame_times.append(float(sample["frame_ms"]))
	var samples := frame_times.size()
	if samples == 0:
		return {"samples": 0, "average_fps": 0.0, "min_fps": 0.0, "p95_frame_ms": 0.0}
	frame_times.sort()
	var index := clampi(ceili(P95_PERCENTILE * samples) - 1, 0, samples - 1)
	return {
		"samples": samples,
		"average_fps": total_fps / samples,
		"min_fps": min_fps,
		"p95_frame_ms": frame_times[index],
	}


## Whether logging is on; false also covers "the requested path was refused".
func is_logging() -> bool:
	return _file != null


## True once the run has lasted at least the requested seconds. A zero timer
## never quits, so the flag cannot turn itself on by accident.
static func should_quit(elapsed_ms: float, quit_after_seconds: float) -> bool:
	if quit_after_seconds <= NO_QUIT_AFTER:
		return false
	return elapsed_ms >= quit_after_seconds * MILLISECONDS_PER_SECOND


func _begin(raw_path: String, quit_after_seconds: float) -> void:
	_quit_after_seconds = quit_after_seconds
	_log_path = resolve_path(raw_path)
	if _log_path.is_empty():
		return
	_file = FileAccess.open(_log_path, FileAccess.WRITE)
	if _file == null:
		push_warning(
			"fps_log: cannot write '%s' (error %d); frame sampling stays off"
			% [_log_path, FileAccess.get_open_error()]
		)


func _ready() -> void:
	_start_usec = Time.get_ticks_usec()
	set_process(_file != null or _quit_after_seconds > NO_QUIT_AFTER)


func _process(delta: float) -> void:
	var elapsed_ms := (Time.get_ticks_usec() - _start_usec) / MILLISECONDS_PER_SECOND
	if _file != null:
		var frame_ms := maxf(delta, 0.0) * MILLISECONDS_PER_SECOND
		var fps := 0.0
		if frame_ms > 0.0:
			fps = MILLISECONDS_PER_SECOND / frame_ms
		_file.store_line(format_line(roundi(elapsed_ms), frame_ms, fps))
	if should_quit(elapsed_ms, _quit_after_seconds):
		_close()
		get_tree().quit(0)


func _exit_tree() -> void:
	_close()


func _close() -> void:
	if _file == null:
		return
	_file.close()
	_file = null
