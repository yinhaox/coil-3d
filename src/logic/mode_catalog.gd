class_name ModeCatalog
extends RefCounted

## Logic-layer catalog of the 1.0 modes: the card order, the default arena file
## each mode starts on and the display name its card shows. This is data, not
## rules: a run still reads only the loaded ArenaData, and an unknown mode
## resolves to Classic instead of failing (design/game-modes.md rules 1, 12).

const MODES: Array[String] = [
	ArenaData.MODE_CLASSIC,
	ArenaData.MODE_MAZE,
	ArenaData.MODE_TIME_ATTACK,
]

const DEFAULT_MODE := ArenaData.MODE_CLASSIC

const DEFAULT_ARENA_FILE_BY_MODE := {
	ArenaData.MODE_CLASSIC: "classic-12.json",
	ArenaData.MODE_MAZE: "maze-01.json",
	ArenaData.MODE_TIME_ATTACK: "time-attack-16.json",
}

const DISPLAY_NAME_BY_MODE := {
	ArenaData.MODE_CLASSIC: "Classic",
	ArenaData.MODE_MAZE: "Maze",
	ArenaData.MODE_TIME_ATTACK: "Time Attack",
}


## The mode id a request resolves to; anything unknown becomes Classic.
static func resolve_mode(mode_name: String) -> String:
	return mode_name if DEFAULT_ARENA_FILE_BY_MODE.has(mode_name) else DEFAULT_MODE


## File name under assets/data/arenas/ that supplies the mode's default arena.
static func default_arena_file(mode_name: String) -> String:
	return str(DEFAULT_ARENA_FILE_BY_MODE[resolve_mode(mode_name)])


## Arena id of that file, which is what GameController.select_start_arena()
## matches against the loaded arenas.
static func default_arena_id(mode_name: String) -> String:
	return default_arena_file(mode_name).get_basename()


## Name a mode card shows.
static func display_name(mode_name: String) -> String:
	return str(DISPLAY_NAME_BY_MODE[resolve_mode(mode_name)])
