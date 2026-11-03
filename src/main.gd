extends Node3D

## Boot entry for the first visible slice.
##
## Keeps no gameplay state and no rules: it only loads scenes/game.tscn, so the
## main scene stays res://scenes/main.tscn (design/architecture.md rule 4). The
## main menu that design rule 24 describes arrives with the UI story; until
## then starting the game goes straight into the arena.

const GAME_SCENE_PATH := "res://scenes/game.tscn"


## Scene the boot entry loads, exposed so headless tests can assert the wiring.
static func game_scene_path() -> String:
	return GAME_SCENE_PATH


func _ready() -> void:
	var packed := load(GAME_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("main: cannot load %s" % GAME_SCENE_PATH)
		return
	add_child(packed.instantiate())
