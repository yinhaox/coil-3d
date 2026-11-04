class_name AppRoot
extends Node3D

## Application shell: owns only the screen flow
## (design/ux-and-persistence.md rule 1), never gameplay rules. The main scene
## stays res://scenes/main.tscn (design/architecture.md rule 4): it loads the
## main menu first and swaps in the game scene when the player presses Play.
##
## Process-level flags select the starting screen for a capture run
## (`--screen=main-menu|how-to-play|game`), passed by scripts/studio.py after
## `--`. The game controller reads its own `--scenario=` flag from the same list.

const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const HOW_TO_PLAY_SCENE_PATH := "res://scenes/ui/how_to_play.tscn"
const GAME_SCENE_PATH := "res://scenes/game.tscn"

const SCREEN_ARGUMENT := "screen"
const SCREEN_MAIN_MENU := "main-menu"
const SCREEN_HOW_TO_PLAY := "how-to-play"
const SCREEN_GAME := "game"

enum Screen { MAIN_MENU, HOW_TO_PLAY, GAME }

## Tests and capture runs point the game at a temporary save file; empty keeps
## SaveStore.DEFAULT_PATH.
@export var save_path: String = ""

var _screen: int = Screen.MAIN_MENU
var _menu: MainMenu = null
var _how_to_play: HowToPlay = null
var _game: GameController = null


## Scene the boot entry loads first, exposed so headless tests can assert the wiring.
static func main_menu_scene_path() -> String:
	return MAIN_MENU_SCENE_PATH


static func how_to_play_scene_path() -> String:
	return HOW_TO_PLAY_SCENE_PATH


## Scene Play loads, exposed so headless tests can assert the wiring.
static func game_scene_path() -> String:
	return GAME_SCENE_PATH


func _ready() -> void:
	_add_process_flags(OS.get_cmdline_user_args())
	match _requested_screen():
		SCREEN_HOW_TO_PLAY:
			open_how_to_play()
		SCREEN_GAME:
			start_game()
		_:
			show_main_menu()


## Process-level flags are read here, not in gameplay code: --fps-log=<path> and
## --quit-after=<seconds> add src/perf/fps_log.gd. Without them nothing is added.
func _add_process_flags(user_args: PackedStringArray) -> void:
	var fps_log := FpsLog.from_user_args(user_args)
	if fps_log != null:
		add_child(fps_log)


func current_screen() -> int:
	return _screen


func menu_node() -> MainMenu:
	return _menu


func how_to_play_node() -> HowToPlay:
	return _how_to_play


func game_node() -> GameController:
	return _game


## Play starts the standard Classic run. The mode selector is a later story, so
## there is no second route to pick yet.
func start_game() -> void:
	_drop_screens()
	var packed := load(GAME_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("app_root: cannot load %s" % GAME_SCENE_PATH)
		show_main_menu()
		return
	var game := packed.instantiate() as GameController
	if game == null:
		push_error("app_root: %s is not a game scene" % GAME_SCENE_PATH)
		show_main_menu()
		return
	_screen = Screen.GAME
	if not save_path.is_empty():
		game.save_path = save_path
	game.main_menu_requested.connect(return_to_main_menu)
	_game = game
	add_child(game)


func show_main_menu() -> void:
	_drop_screens()
	var packed := load(MAIN_MENU_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("app_root: cannot load %s" % MAIN_MENU_SCENE_PATH)
		return
	var menu := packed.instantiate() as MainMenu
	if menu == null:
		push_error("app_root: %s is not a main menu" % MAIN_MENU_SCENE_PATH)
		return
	_screen = Screen.MAIN_MENU
	menu.play_requested.connect(start_game)
	menu.how_to_play_requested.connect(open_how_to_play)
	menu.quit_requested.connect(quit_game)
	_menu = menu
	add_child(menu)


func open_how_to_play() -> void:
	_drop_screens()
	var packed := load(HOW_TO_PLAY_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("app_root: cannot load %s" % HOW_TO_PLAY_SCENE_PATH)
		return
	var page := packed.instantiate() as HowToPlay
	if page == null:
		push_error("app_root: %s is not a how-to-play page" % HOW_TO_PLAY_SCENE_PATH)
		return
	_screen = Screen.HOW_TO_PLAY
	page.back_requested.connect(show_main_menu)
	_how_to_play = page
	add_child(page)


## Main menu intent from the game (pause menu, end panel, Esc on the end panel).
func return_to_main_menu() -> void:
	show_main_menu()


func quit_game() -> void:
	get_tree().quit()


func _drop_screens() -> void:
	_drop(_menu)
	_drop(_how_to_play)
	_drop(_game)
	_menu = null
	_how_to_play = null
	_game = null


func _drop(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() == self:
		remove_child(node)
	node.queue_free()


func _requested_screen() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var pair := argument.substr(2).split("=", true, 1)
		if pair[0] == SCREEN_ARGUMENT and pair.size() > 1:
			return pair[1]
	return SCREEN_MAIN_MENU
