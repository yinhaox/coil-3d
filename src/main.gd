class_name AppRoot
extends Node3D

## Application shell: owns only the screen flow
## (design/ux-and-persistence.md rule 1), never gameplay rules. The main scene
## stays res://scenes/main.tscn (design/architecture.md rule 4): it loads the
## main menu first and swaps in the game scene when the player presses Play.
##
## Process-level flags select the starting screen for a capture run
## (`--screen=main-menu|how-to-play|settings|game`), passed by scripts/studio.py
## after `--`. `--audio-log` starts a game directly for the cue-order evidence
## run. The game controller reads its own `--scenario=` flag from the same list.

const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const HOW_TO_PLAY_SCENE_PATH := "res://scenes/ui/how_to_play.tscn"
const SETTINGS_SCENE_PATH := "res://scenes/ui/settings.tscn"
const GAME_SCENE_PATH := "res://scenes/game.tscn"

const SCREEN_ARGUMENT := "screen"
const SCREEN_MAIN_MENU := "main-menu"
const SCREEN_HOW_TO_PLAY := "how-to-play"
const SCREEN_SETTINGS := "settings"
const SCREEN_GAME := "game"

const AUDIO_LOG_ARGUMENT := "audio-log"
const SAVE_PATH_ARGUMENT := "save-path"
const FRESH_SAVE_ARGUMENT := "fresh-save"

enum Screen { MAIN_MENU, HOW_TO_PLAY, GAME }

## Tests and capture runs point the game at a temporary save file; empty keeps
## SaveStore.DEFAULT_PATH.
@export var save_path: String = ""

var _screen: int = Screen.MAIN_MENU
var _menu: MainMenu = null
var _how_to_play: HowToPlay = null
var _settings: SettingsScreen = null
var _game: GameController = null
var _save_store: SaveStore = null
var _audio: AudioDirector = null


## Scene the boot entry loads first, exposed so headless tests can assert the wiring.
static func main_menu_scene_path() -> String:
	return MAIN_MENU_SCENE_PATH


static func how_to_play_scene_path() -> String:
	return HOW_TO_PLAY_SCENE_PATH


static func settings_scene_path() -> String:
	return SETTINGS_SCENE_PATH


## Scene Play loads, exposed so headless tests can assert the wiring.
static func game_scene_path() -> String:
	return GAME_SCENE_PATH


func _ready() -> void:
	var arguments := _user_arguments()
	_init_audio()
	_init_save_store(arguments)
	_add_process_flags(OS.get_cmdline_user_args())
	match _requested_screen():
		SCREEN_HOW_TO_PLAY:
			open_how_to_play()
		SCREEN_SETTINGS:
			open_settings()
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


func settings_node() -> SettingsScreen:
	return _settings


func game_node() -> GameController:
	return _game


func audio_node() -> AudioDirector:
	return _audio


func save_store() -> SaveStore:
	return _save_store


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
	game.shared_save_store = _save_store
	game.shared_audio = _audio
	game.main_menu_requested.connect(return_to_main_menu)
	game.settings_requested.connect(open_settings)
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
	menu.audio = _audio
	menu.play_requested.connect(start_game)
	menu.how_to_play_requested.connect(open_how_to_play)
	menu.settings_requested.connect(open_settings)
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
	page.audio = _audio
	page.back_requested.connect(show_main_menu)
	_how_to_play = page
	add_child(page)


## The settings overlay sits on top of whatever screen opened it (main menu or
## the paused game), so closing it returns to the same place. It is a
## CanvasLayer above the pause and end panels.
func open_settings() -> void:
	if _settings != null or _save_store == null:
		return
	var packed := load(SETTINGS_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("app_root: cannot load %s" % SETTINGS_SCENE_PATH)
		return
	var screen := packed.instantiate() as SettingsScreen
	if screen == null:
		push_error("app_root: %s is not a settings screen" % SETTINGS_SCENE_PATH)
		return
	screen.store = _save_store
	screen.audio = _audio
	screen.closed.connect(_on_settings_closed)
	_settings = screen
	add_child(screen)


func _on_settings_closed() -> void:
	_drop(_settings)
	_settings = null


## Main menu intent from the game (pause menu, end panel, Esc on the end panel).
func return_to_main_menu() -> void:
	show_main_menu()


func quit_game() -> void:
	get_tree().quit()


func _drop_screens() -> void:
	_drop(_menu)
	_drop(_how_to_play)
	_drop(_settings)
	_drop(_game)
	_menu = null
	_how_to_play = null
	_settings = null
	_game = null


func _drop(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() == self:
		remove_child(node)
	node.queue_free()


## One audio director for the whole app: menus, settings and the game share the
## buses, the repeat throttles and the cue log.
func _init_audio() -> void:
	AudioDirector.ensure_buses()
	_audio = AudioDirector.new()
	_audio.name = "AudioDirector"
	add_child(_audio)


func _init_save_store(arguments: Dictionary) -> void:
	var path := save_path
	if arguments.has(SAVE_PATH_ARGUMENT):
		var requested := str(arguments[SAVE_PATH_ARGUMENT])
		if not requested.is_empty():
			path = requested
	if path.is_empty():
		path = SaveStore.DEFAULT_PATH
	_save_store = SaveStore.new(path)
	if arguments.has(FRESH_SAVE_ARGUMENT):
		_save_store.erase_files()
	_save_store.load_from_disk()
	AudioDirector.apply_volumes(_save_store.master_volume(), _save_store.sfx_volume())


func _requested_screen() -> String:
	var requested := ""
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var pair := argument.substr(2).split("=", true, 1)
		if pair[0] == SCREEN_ARGUMENT and pair.size() > 1:
			requested = pair[1]
		elif pair[0] == AUDIO_LOG_ARGUMENT:
			# The cue-order evidence run starts a real game without a menu.
			if requested.is_empty():
				requested = SCREEN_GAME
	return requested if not requested.is_empty() else SCREEN_MAIN_MENU


func _user_arguments() -> Dictionary:
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var pair := argument.substr(2).split("=", true, 1)
		var key: String = pair[0]
		if key == "studio-capture":
			continue
		arguments[key] = pair[1] if pair.size() > 1 else ""
	return arguments
