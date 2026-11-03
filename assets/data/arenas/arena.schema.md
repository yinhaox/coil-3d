# Arena data schema

One arena per `*.json` file in this directory. `src/logic/arena_data.gd` loads
every file in file-name order, validates it, and rejects invalid input with a
file-prefixed message. The player-facing meaning of each mode is in
[design/game-modes.md](../../../design/game-modes.md).

## Top-level keys

| Key | Type | Unit / values | Rule |
|---|---|---|---|
| `schema_version` | int | `1` | Any other version is rejected. |
| `id` | string | kebab-case | Unique across all arena files; a duplicate id is rejected. |
| `mode` | string | `classic` / `maze` / `time_attack` | Selects the mode card; unknown values are rejected. |
| `size` | object | cells | `columns` and `rows` are each an int in `4..16`; the four borders are walls. |
| `obstacles` | array | `[x, z]` cells | In bounds, no duplicates, not on the start cell or the start space; an int per axis. |
| `food_max` | int | items, `1..8` | Simultaneous food target; fewer are spawned when the arena has fewer free cells. |
| `initial_speed_cells_per_second` | float | cells/s, `4.0..10.0` | Speed of the first logic step. |
| `max_speed_cells_per_second` | float | cells/s, `>=` initial, `<= 20.0` | Cap for the speed curve. |
| `time_limit_seconds` | float or `null` | seconds, `> 0` and `<= 600` | Required for `time_attack`, must be `null` for every other mode. |
| `start.cell` | `[x, z]` | cells | In bounds. |
| `start.direction` | string | `east` / `west` / `north` / `south` | The 3 cells behind the head along this direction must be in bounds and free. |

Unknown keys are ignored and reported as warnings. Missing keys, wrong types,
out-of-range numbers, an obstacle on the start space and an unsupported mode
are hard errors for that file.

## Directory rules

- Files are loaded in file-name order.
- A duplicate `id` is rejected and the later file is not loaded (data rules).
- In 1.0 the UI shows one card per mode and uses the first file by name
  (`ArenaData.LoadResult.arena_for_mode`). Issue #3 requires two Classic arenas,
  so a second file with a mode that already exists is kept and reported as a
  warning rather than rejected.

## Files

| File | Mode | Board | Obstacles | Food | Initial speed |
|---|---|---|---|---|---|
| `classic-12.json` | `classic` | 12×12 | 0 | 1 | 6.0 cells/s |
| `classic-16.json` | `classic` | 16×16 | 0 | 1 | 6.0 cells/s |
| `maze-01.json` | `maze` | 16×16 | 16 | 2 | 5.0 cells/s |
| `time-attack-16.json` | `time_attack` | 16×16 | 0 | 3 | 7.0 cells/s, 90 s |
