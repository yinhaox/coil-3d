class_name SaveStore
extends RefCounted

## Local save file: per-mode best scores, run count and the volume settings.
##
## The single `user://` entry of the game (design/architecture.md rule 10). The
## schema follows design/ux-and-persistence.md: version 1, best scores per mode,
## total runs and settings. Writes are atomic (temp file, backup, replace) and a
## corrupt file is quarantined as `save.corrupt-<unix>.json`, never deleted.
##
## Pure disk IO: no Node, no Input, no scene tree. The path is injected so tests
## write to a temporary directory instead of the player's save.

const DEFAULT_PATH := "user://save.json"
const SCHEMA_VERSION := 1
const BACKUP_SUFFIX := ".bak"
const TEMP_SUFFIX := ".tmp"
const CORRUPT_INFIX := ".corrupt-"
const MAX_TOTAL_RUNS := 999999
const DEFAULT_MASTER_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 0.8
const MIN_VOLUME := 0.0
const MAX_VOLUME := 1.0

const SETTING_MASTER_VOLUME := "master_volume"
const SETTING_SFX_VOLUME := "sfx_volume"

var _path: String
var _schema_version: int = SCHEMA_VERSION
var _best_scores: Dictionary = {}
var _settings: Dictionary = {}
var _total_runs: int = 0
var _read_only := false
var _last_error := ""


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	_best_scores = _default_best_scores()
	_settings = default_settings()


## Read `save.json`, then `save.bak`, then fall back to defaults.
## Returns true when a file provided the values; false means defaults are in use.
func load_from_disk() -> bool:
	_schema_version = SCHEMA_VERSION
	_best_scores = _default_best_scores()
	_settings = default_settings()
	_total_runs = 0
	_read_only = false
	_last_error = ""

	var data := _read_candidate(_path)
	if data.is_empty() and FileAccess.file_exists(_path):
		# A readable-but-invalid main file is kept for diagnosis, not deleted.
		_quarantine(_path)
	if data.is_empty():
		data = _read_candidate(_backup_path())
	if data.is_empty():
		return false
	_apply(data)
	return true


## Write the current state atomically: temp file, backup of the old file, then
## replace. Returns false when the directory is not writable; the in-memory
## state stays intact and the caller can keep playing (design rule 15).
func save() -> bool:
	if _read_only:
		return _fail("refusing to overwrite a newer schema (%d)" % _schema_version)
	var directory := _path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var make_error := DirAccess.make_dir_recursive_absolute(directory)
		if make_error != OK:
			return _fail("cannot create %s (error %d)" % [directory, make_error])

	var temp_path := _temp_path()
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _fail("cannot open %s for writing (error %d)" % [temp_path, FileAccess.get_open_error()])
	file.store_string(JSON.stringify(to_dictionary(), "\t", true))
	file.flush()
	file.close()

	if FileAccess.file_exists(_path):
		if not _copy_over(_path, _backup_path()):
			_remove_file(temp_path)
			return _fail("cannot back up %s" % _path)
		if DirAccess.remove_absolute(_path) != OK:
			_remove_file(temp_path)
			return _fail("cannot replace %s" % _path)

	var rename_error := DirAccess.rename_absolute(temp_path, _path)
	if rename_error != OK:
		if FileAccess.file_exists(_backup_path()):
			_copy_over(_backup_path(), _path)
		return _fail("cannot move %s into place (error %d)" % [temp_path, rename_error])
	return true


## Best score for one mode; unknown modes are 0 (the schema has no slot for them).
func best_score(mode: String) -> int:
	return int(_best_scores.get(mode, 0))


## Record a finished run. A lower or equal score is not a record (design rule 17).
## The caller decides when to write; `save()` persists it.
func record_score(mode: String, score: int) -> bool:
	if not ArenaData.SUPPORTED_MODES.has(mode):
		_fail("unknown mode '%s'" % mode)
		return false
	if score <= best_score(mode):
		return false
	_best_scores[mode] = score
	return true


## Every run start counts, including one abandoned mid-run (design rule 17).
func record_run_started() -> void:
	if _total_runs < MAX_TOTAL_RUNS:
		_total_runs += 1


func total_runs() -> int:
	return _total_runs


func schema_version() -> int:
	return _schema_version


## True when the file on disk declares a newer schema: settings fall back to
## defaults and this run never writes over the file (design rule 14).
func is_read_only() -> bool:
	return _read_only


func master_volume() -> float:
	return float(_settings[SETTING_MASTER_VOLUME])


func set_master_volume(value: float) -> void:
	_settings[SETTING_MASTER_VOLUME] = clampf(value, MIN_VOLUME, MAX_VOLUME)


func sfx_volume() -> float:
	return float(_settings[SETTING_SFX_VOLUME])


func set_sfx_volume(value: float) -> void:
	_settings[SETTING_SFX_VOLUME] = clampf(value, MIN_VOLUME, MAX_VOLUME)


func path() -> String:
	return _path


func last_error() -> String:
	return _last_error


## The exact dictionary that `save()` writes, with stable key order.
func to_dictionary() -> Dictionary:
	var scores: Dictionary = {}
	for mode: String in ArenaData.SUPPORTED_MODES:
		scores[mode] = best_score(mode)
	return {
		"schema_version": SCHEMA_VERSION,
		"best_scores": scores,
		"total_runs": _total_runs,
		"settings": {
			SETTING_MASTER_VOLUME: master_volume(),
			SETTING_SFX_VOLUME: sfx_volume(),
		},
	}


## Delete the save, backup and temp files. Used by reproducible capture runs;
## normal play never calls this.
func erase_files() -> void:
	for target: String in [_path, _backup_path(), _temp_path()]:
		_remove_file(target)


static func default_settings() -> Dictionary:
	return {
		SETTING_MASTER_VOLUME: DEFAULT_MASTER_VOLUME,
		SETTING_SFX_VOLUME: DEFAULT_SFX_VOLUME,
	}


static func _default_best_scores() -> Dictionary:
	var scores: Dictionary = {}
	for mode: String in ArenaData.SUPPORTED_MODES:
		scores[mode] = 0
	return scores


func _apply(data: Dictionary) -> void:
	var loaded_version := int(data.get("schema_version", SCHEMA_VERSION))
	if loaded_version > SCHEMA_VERSION:
		_read_only = true
		_schema_version = loaded_version
		_best_scores = _sanitize_best_scores(data.get("best_scores"))
		_total_runs = _sanitize_total_runs(data.get("total_runs"))
		return
	if loaded_version < SCHEMA_VERSION:
		data = _migrate(data, loaded_version)
	_schema_version = SCHEMA_VERSION
	_best_scores = _sanitize_best_scores(data.get("best_scores"))
	_settings = _sanitize_settings(data.get("settings"))
	_total_runs = _sanitize_total_runs(data.get("total_runs"))


## Migration skeleton: upgrade an older dictionary field by field before the
## version 1 fields are read. Schema 1 is the first version, so no step exists
## yet; a future schema adds one branch here and a test for it.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var migrated := data.duplicate(true)
	var version := from_version
	while version < SCHEMA_VERSION:
		version += 1
		migrated["schema_version"] = version
	return migrated


## Parsed data for one file, or {} when the file is missing, unreadable or not
## a versioned JSON object.
func _read_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if not _is_version_number(data.get("schema_version")):
		return {}
	if _version_value(data["schema_version"]) < 1:
		return {}
	data["schema_version"] = _version_value(data["schema_version"])
	return data


func _sanitize_best_scores(raw: Variant) -> Dictionary:
	var scores := _default_best_scores()
	if typeof(raw) != TYPE_DICTIONARY:
		return scores
	var data: Dictionary = raw
	for mode: String in ArenaData.SUPPORTED_MODES:
		if not data.has(mode) or not _is_number(data[mode]):
			continue
		scores[mode] = maxi(0, int(data[mode]))
	return scores


func _sanitize_settings(raw: Variant) -> Dictionary:
	var settings := default_settings()
	if typeof(raw) != TYPE_DICTIONARY:
		return settings
	var data: Dictionary = raw
	settings[SETTING_MASTER_VOLUME] = _clamped_volume(
		data.get(SETTING_MASTER_VOLUME), DEFAULT_MASTER_VOLUME
	)
	settings[SETTING_SFX_VOLUME] = _clamped_volume(
		data.get(SETTING_SFX_VOLUME), DEFAULT_SFX_VOLUME
	)
	return settings


func _sanitize_total_runs(raw: Variant) -> int:
	if not _is_number(raw):
		return 0
	return clampi(int(raw), 0, MAX_TOTAL_RUNS)


func _clamped_volume(raw: Variant, fallback: float) -> float:
	if not _is_number(raw):
		return fallback
	return clampf(float(raw), MIN_VOLUME, MAX_VOLUME)


func _quarantine(source: String) -> void:
	var target := _corrupt_path()
	var error := DirAccess.rename_absolute(source, target)
	if error != OK:
		push_warning("save_store: cannot quarantine %s (error %d)" % [source, error])


func _copy_over(source: String, target: String) -> bool:
	_remove_file(target)
	return DirAccess.copy_absolute(source, target) == OK


func _remove_file(target: String) -> void:
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(target)


func _base_path() -> String:
	return _path.get_basename()


func _backup_path() -> String:
	return _base_path() + BACKUP_SUFFIX


func _temp_path() -> String:
	return _base_path() + TEMP_SUFFIX


func _corrupt_path() -> String:
	var stamp := int(Time.get_unix_time_from_system())
	var candidate := "%s%s%d.json" % [_base_path(), CORRUPT_INFIX, stamp]
	var suffix := 1
	while FileAccess.file_exists(candidate):
		candidate = "%s%s%d-%d.json" % [_base_path(), CORRUPT_INFIX, stamp, suffix]
		suffix += 1
	return candidate


func _fail(message: String) -> bool:
	_last_error = message
	push_warning("save_store: %s" % message)
	return false


static func _is_number(raw: Variant) -> bool:
	return typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT


static func _is_version_number(raw: Variant) -> bool:
	return _is_number(raw)


static func _version_value(raw: Variant) -> int:
	if typeof(raw) == TYPE_INT:
		return int(raw)
	return int(roundf(float(raw)))
