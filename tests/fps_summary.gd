extends SceneTree

## Prints the summary of a real `--fps-log` run, so the numbers quoted in
## production/qa/evidence/<story-slug>/index.md can be regenerated from the log
## instead of being counted by hand:
##
##   godot --headless --path . -s res://tests/fps_summary.gd -- --log=<path>
##
## The line parser and the statistics live in src/perf/fps_log.gd, which
## tests/run_tests.gd also asserts; this entry point only reads the log and
## prints them.

const FPS_LOG_SCRIPT := preload("res://src/perf/fps_log.gd")
const LOG_FLAG := "--log="


func _init() -> void:
	var path := _log_path()
	if path.is_empty():
		printerr("fps_summary: pass --log=<path> after --")
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("fps_summary: cannot read '%s' (error %d)" % [path, FileAccess.get_open_error()])
		quit(1)
		return
	var lines := PackedStringArray()
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	var summary: Dictionary = FPS_LOG_SCRIPT.summarize(lines)
	print(
		"fps_summary: path=%s samples=%d average_fps=%.2f min_fps=%.2f p95_frame_ms=%.3f"
		% [
			path,
			int(summary["samples"]),
			float(summary["average_fps"]),
			float(summary["min_fps"]),
			float(summary["p95_frame_ms"]),
		]
	)
	quit(0)


func _log_path() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(LOG_FLAG):
			return argument.substr(LOG_FLAG.length())
	return ""
