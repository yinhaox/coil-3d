class_name AudioDirector
extends Node

## Runtime-synthesized cue player for the five rule and UI events
## (design/audio.md): turn, eat, speed_up, crash and ui_click.
##
## No audio file is shipped. Each cue is a table entry (duration, waveform,
## frequency sweep, envelope, gain, minimum repeat interval) and its PCM is
## generated in code into an `AudioStreamGenerator` when the cue is scheduled.
## A small player pool plus the per-cue minimum interval keeps two identical
## cues from stacking into a clipped burst.
##
## Buses are created here because project.godot is out of a story's write
## boundary: `Master -> SFX`, with the settings screen driving both volumes.
##
## The table, the PCM builder, the volume mapping and the schedule decision are
## static so tests can check them without an audio device.

signal cue_scheduled(cue: String)

const CUE_TURN := "turn"
const CUE_EAT := "eat"
const CUE_SPEED_UP := "speed_up"
const CUE_CRASH := "crash"
const CUE_UI_CLICK := "ui_click"
const CUE_NAMES: Array[String] = [CUE_TURN, CUE_EAT, CUE_SPEED_UP, CUE_CRASH, CUE_UI_CLICK]

const WAVEFORM_SINE := "sine"
const WAVEFORM_SQUARE := "square"
const WAVEFORM_TRIANGLE := "triangle"
const WAVEFORM_NOISE := "noise"
const WAVEFORM_NOISE_SINE := "noise_sine"
const WAVEFORMS: Array[String] = [
	WAVEFORM_SINE, WAVEFORM_SQUARE, WAVEFORM_TRIANGLE, WAVEFORM_NOISE, WAVEFORM_NOISE_SINE
]

## One row per cue. Frequencies are Hz, times are seconds, gain is dB and
## `min_interval` is the shortest gap between two plays of the same cue.
const CUE_TABLE: Dictionary = {
	CUE_TURN: {
		"waveform": WAVEFORM_SQUARE,
		"duration": 0.06,
		"base_frequency": 440.0,
		"end_frequency": 520.0,
		"attack": 0.002,
		"release": 0.005,
		"gain_db": -18.0,
		"min_interval": 0.05,
		"priority": 1,
	},
	CUE_EAT: {
		"waveform": WAVEFORM_SINE,
		"duration": 0.12,
		"base_frequency": 660.0,
		"end_frequency": 990.0,
		"attack": 0.005,
		"release": 0.005,
		"gain_db": -9.0,
		"min_interval": 0.10,
		"priority": 2,
	},
	CUE_SPEED_UP: {
		"waveform": WAVEFORM_TRIANGLE,
		"duration": 0.18,
		"base_frequency": 523.0,
		"end_frequency": 784.0,
		"attack": 0.003,
		"release": 0.005,
		"gain_db": -12.0,
		"min_interval": 0.25,
		"priority": 2,
	},
	CUE_CRASH: {
		"waveform": WAVEFORM_NOISE_SINE,
		"duration": 0.25,
		"base_frequency": 110.0,
		"end_frequency": 55.0,
		"attack": 0.005,
		"release": 0.005,
		"gain_db": -6.0,
		"min_interval": 0.50,
		"priority": 3,
	},
	CUE_UI_CLICK: {
		"waveform": WAVEFORM_SINE,
		"duration": 0.09,
		"base_frequency": 520.0,
		"end_frequency": 780.0,
		"attack": 0.005,
		"release": 0.005,
		"gain_db": -15.0,
		"min_interval": 0.08,
		"priority": 1,
	},
}

const MASTER_BUS := "Master"
const SFX_BUS := "SFX"
const SAMPLE_RATE := 44100.0
const PLAYER_POOL_SIZE := 8
const GENERATOR_BUFFER_SECONDS := 0.5
const PLAYBACK_RELEASE_MARGIN_SECONDS := 0.05
const DECAY_CURVE := 4.0
const NOISE_SEED := 424242
const NOISE_MIX := 0.4
const MUTE_VOLUME := 0.0
const MAX_VOLUME := 1.0
const MIN_DB := -80.0
const DEFAULT_CUE_LOG_PATH := "user://audio_cue.log"
const NO_OUTPUT_DRIVER := "Dummy"

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_played_msec: Dictionary = {}
var _play_counts: Dictionary = {}
var _log_file: FileAccess = null
var _pool_ready := false


func _ready() -> void:
	_build_pool()


func _exit_tree() -> void:
	close_cue_log()
	_stop_players()


## Stop every player and drop its generator before the node is freed. A
## playback object still running at exit is reported by Godot as a leaked
## ObjectDB instance, so the pool is torn down explicitly.
func _stop_players() -> void:
	for player in _players:
		if player == null:
			continue
		player.stop()
		player.stream = null
	_players.clear()
	_pool_ready = false


## Creates the `Master -> SFX` buses when the project does not define SFX yet.
## Idempotent: a second call (settings screen, second director) keeps one bus.
static func ensure_buses() -> void:
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, SFX_BUS)
		AudioServer.set_bus_send(index, MASTER_BUS)


## Linear 0..1 volume to bus dB. Zero maps to a hard floor and is muted by
## `apply_volumes`, so a silent game still schedules every cue.
static func volume_to_db(volume: float) -> float:
	var clamped := clamp_volume(volume)
	if clamped <= MUTE_VOLUME:
		return MIN_DB
	return maxf(linear_to_db(clamped), MIN_DB)


static func clamp_volume(volume: float) -> float:
	return clampf(volume, MUTE_VOLUME, MAX_VOLUME)


## Pushes the stored volumes onto the two buses the settings screen owns.
static func apply_volumes(master_volume: float, sfx_volume: float) -> void:
	ensure_buses()
	_apply_bus_volume(MASTER_BUS, master_volume)
	_apply_bus_volume(SFX_BUS, sfx_volume)


## True when `cue` exists in the table; unknown names are ignored, never fatal.
static func is_known_cue(cue: String) -> bool:
	return CUE_TABLE.has(cue)


## True when the AudioServer has a real output device. Headless runs use the
## Dummy driver: cues are still scheduled and logged, but no playback object is
## created (design/audio.md: a run without an audio device stays silent).
static func has_output_device() -> bool:
	return AudioServer.get_driver_name() != NO_OUTPUT_DRIVER


## The generated stereo frames for one cue, peak-normalized and gain-scaled.
## Returns an empty array for an unknown name.
static func build_frames(cue: String) -> PackedVector2Array:
	var frames := PackedVector2Array()
	if not is_known_cue(cue):
		return frames
	var spec: Dictionary = CUE_TABLE[cue]
	var duration := float(spec["duration"])
	var sample_count := maxi(1, roundi(duration * SAMPLE_RATE))
	var base_frequency := float(spec["base_frequency"])
	var end_frequency := float(spec["end_frequency"])
	var attack := float(spec["attack"])
	var release := float(spec["release"])
	var waveform := str(spec["waveform"])
	var noise := RandomNumberGenerator.new()
	noise.seed = NOISE_SEED
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var peak := 0.0
	var phase := 0.0
	for index in range(sample_count):
		var progress := float(index) / float(sample_count)
		var frequency := lerpf(base_frequency, end_frequency, progress)
		phase = fmod(phase + TAU * frequency / SAMPLE_RATE, TAU)
		var seconds := float(index) / SAMPLE_RATE
		var value := _waveform_sample(waveform, phase, noise)
		value *= _envelope(seconds, duration, attack, release)
		samples[index] = value
		peak = maxf(peak, absf(value))
	var scale := db_to_linear(float(spec["gain_db"]))
	if peak > 0.0:
		scale /= peak
	frames.resize(sample_count)
	for index in range(sample_count):
		var sample := samples[index] * scale
		frames[index] = Vector2(sample, sample)
	return frames


## Schedules one cue. `now_msec` is injectable so tests can prove the minimum
## interval without waiting on wall time. Returns false when the name is unknown
## or the cue is still inside its repeat interval.
func try_play(cue: String, now_msec: int = -1) -> bool:
	if not is_known_cue(cue):
		push_warning("audio_director: unknown cue '%s' ignored" % cue)
		return false
	var now := now_msec if now_msec >= 0 else Time.get_ticks_msec()
	var interval_ms := int(round(float(CUE_TABLE[cue]["min_interval"]) * 1000.0))
	if _last_played_msec.has(cue) and now - int(_last_played_msec[cue]) < interval_ms:
		return false
	_last_played_msec[cue] = now
	_play_counts[cue] = int(_play_counts.get(cue, 0)) + 1
	_write_cue_log(cue)
	_start_playback(cue)
	cue_scheduled.emit(cue)
	return true


func cue_count(cue: String) -> int:
	return int(_play_counts.get(cue, 0))


func last_play_msec(cue: String) -> int:
	return int(_last_played_msec.get(cue, -1))


## Writes one cue name per line so a run can prove the event order. A relative
## path is relative to the project root; `user://` is the Godot user directory.
func open_cue_log(raw_path: String) -> void:
	close_cue_log()
	var resolved := resolve_log_path(raw_path)
	if resolved.is_empty():
		return
	_log_file = FileAccess.open(resolved, FileAccess.WRITE)
	if _log_file == null:
		push_warning(
			"audio_director: cannot write cue log '%s' (error %d)"
			% [resolved, FileAccess.get_open_error()]
		)


func close_cue_log() -> void:
	if _log_file == null:
		return
	_log_file.close()
	_log_file = null


func is_logging() -> bool:
	return _log_file != null


static func resolve_log_path(raw_path: String) -> String:
	if raw_path.is_empty():
		return ""
	if raw_path.begins_with("res://") or raw_path.begins_with("user://"):
		return ProjectSettings.globalize_path(raw_path)
	if raw_path.is_absolute_path():
		return raw_path
	return ProjectSettings.globalize_path("res://" + raw_path)


## Connects every button's `pressed` signal to the ui_click cue. Safe to call
## twice: an already connected button is skipped.
func wire_buttons(buttons: Array[Button]) -> void:
	for button in buttons:
		if button == null:
			continue
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	try_play(CUE_UI_CLICK)


func _build_pool() -> void:
	if _pool_ready:
		return
	ensure_buses()
	for _index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = SAMPLE_RATE
		generator.buffer_length = GENERATOR_BUFFER_SECONDS
		player.stream = generator
		add_child(player)
		_players.append(player)
	_pool_ready = true


func _start_playback(cue: String) -> void:
	if not _pool_ready or _players.is_empty() or not has_output_device():
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stop()
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	playback.push_buffer(build_frames(cue))
	_schedule_playback_release(player, float(CUE_TABLE[cue]["duration"]))


## A generator stream never reports `finished`, so the player is stopped after
## the cue's own duration. Leaving players playing until quit makes Godot report
## their generator playback objects as leaked at exit; stopping them keeps the
## mixer idle when the window closes.
func _schedule_playback_release(player: AudioStreamPlayer, duration: float) -> void:
	if not is_inside_tree():
		return
	var timer := get_tree().create_timer(duration + PLAYBACK_RELEASE_MARGIN_SECONDS)
	timer.timeout.connect(_release_player.bind(player))


func _release_player(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		player.stop()


func _write_cue_log(cue: String) -> void:
	if _log_file == null:
		return
	_log_file.store_line(cue)
	_log_file.flush()


static func _apply_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var clamped := clamp_volume(volume)
	AudioServer.set_bus_volume_db(index, volume_to_db(clamped))
	AudioServer.set_bus_mute(index, clamped <= MUTE_VOLUME)


static func _waveform_sample(
	waveform: String, phase: float, noise: RandomNumberGenerator
) -> float:
	match waveform:
		WAVEFORM_SINE:
			return sin(phase)
		WAVEFORM_SQUARE:
			return 1.0 if sin(phase) >= 0.0 else -1.0
		WAVEFORM_TRIANGLE:
			return (2.0 / PI) * asin(sin(phase))
		WAVEFORM_NOISE:
			return noise.randf_range(-1.0, 1.0)
		WAVEFORM_NOISE_SINE:
			return (1.0 - NOISE_MIX) * sin(phase) + NOISE_MIX * noise.randf_range(-1.0, 1.0)
		_:
			return 0.0


## Linear attack, exponential body, linear release. Both ends reach zero, so a
## cue never clicks on or off.
static func _envelope(seconds: float, duration: float, attack: float, release: float) -> float:
	var value := 1.0
	if attack > 0.0 and seconds < attack:
		value = seconds / attack
	var tail_start := duration - release
	if release > 0.0 and seconds > tail_start:
		value = minf(value, (duration - seconds) / release)
	if seconds > attack and duration > attack:
		value *= exp(-DECAY_CURVE * (seconds - attack) / (duration - attack))
	return clampf(value, 0.0, 1.0)
