extends Node
class_name UnilearnMusic

# Put your tracks here:
#   res://assets/audio/music/music_1.mp3
#   res://assets/audio/music/music_2.mp3
#   ...
# The fallback app path is supported too, in case the folder is copied under app/ by mistake.
const MUSIC_DIRS := [
	"res://assets/audio/music",
	"res://app/assets/audio/music"
]
const MUSIC_PREFIX := "music_"
const MUSIC_EXTENSIONS := ["mp3", "ogg", "wav"]
const DEFAULT_TRACK_VOLUME_DB := -18.0
const TRACK_VOLUME_DB := {
	1: -18.5,
	2: -20.0,
	3: -17.5,
}
const MUTED_VOLUME_DB := -80.0
const FIRST_START_FADE_IN_SECONDS := 1.35
const FADE_OUT_SECONDS := 0.85
const UNIVERSE_END_COLLISION_FADE_SECONDS := 0.70
const PAUSE_FADE_SECONDS := 0.28
const START_RETRY_SECONDS := 0.45
const MAX_START_RETRIES := 6
const ACHIEVEMENT_DUCK_EXTRA_DB := -11.0
const ACHIEVEMENT_DUCK_MIN_VOLUME_DB := -34.0
const ACHIEVEMENT_DUCK_FADE_SECONDS := 0.55
const ACHIEVEMENT_UNDUCK_FADE_SECONDS := 0.80


var enabled: bool = true
var auto_start: bool = true

var _player: AudioStreamPlayer = null
var _tracks: Array[String] = []
var _unplayed_track_indices: Array[int] = []
var _rng := RandomNumberGenerator.new()
var _fade_tween: Tween = null
var _fade_token: int = 0
var _starting_new_track := false
var _session_paused := false
var _app_paused := false
var _manual_paused := false
var _has_started_once := false
var _current_track_volume_db := DEFAULT_TRACK_VOLUME_DB
var _start_retry_count := 0
var _achievement_duck_count := 0
var _universe_end_stopped := false



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_player()
	_load_settings()
	_connect_settings_signal()
	_scan_tracks()

	if enabled and auto_start:
		call_deferred("_deferred_auto_start")


func _deferred_auto_start() -> void:
	await get_tree().process_frame
	start()




func _build_player() -> void:
	if _player != null and is_instance_valid(_player):
		return

	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Master"
	_player.volume_db = MUTED_VOLUME_DB
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.finished.connect(_on_track_finished)
	add_child(_player)


func _connect_settings_signal() -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	if settings == null or not settings.has_signal("settings_changed"):
		return

	var callable := Callable(self, "_on_settings_changed")
	if not settings.settings_changed.is_connected(callable):
		settings.settings_changed.connect(callable)


func _on_settings_changed() -> void:
	var was_enabled := enabled
	_load_settings()

	if was_enabled == enabled:
		return

	if enabled:
		resume_music()
	else:
		pause_music()


func _load_settings() -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	if settings == null:
		return

	var value: Variant = settings.get("music_enabled")
	if value != null:
		enabled = bool(value)


func _scan_tracks() -> void:
	_tracks.clear()

	for dir_path in MUSIC_DIRS:
		_scan_tracks_in_dir(dir_path)

	_tracks.sort_custom(Callable(self, "_sort_music_paths"))
	_reset_unplayed_bag()

	if _tracks.is_empty():
		push_warning("No music tracks found. Expected files like res://assets/audio/music/music_1.mp3")
	else:
		print("UnilearnMusic found %d track(s). First track: %s" % [_tracks.size(), _tracks[0]])


func _scan_tracks_in_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue

		var resource_name := _resource_name_from_dir_entry(file_name)
		if resource_name.is_empty():
			continue

		var clean_name := resource_name.to_lower()
		var extension := clean_name.get_extension()
		if not MUSIC_EXTENSIONS.has(extension):
			continue
		if not clean_name.get_basename().begins_with(MUSIC_PREFIX):
			continue

		var path := dir_path + "/" + resource_name
		if not _tracks.has(path):
			_tracks.append(path)

	dir.list_dir_end()


func _resource_name_from_dir_entry(file_name: String) -> String:
	# In editor/exported builds Godot may show either music_1.mp3 or music_1.mp3.import.
	# The actual resource path to load stays music_1.mp3, so strip the .import suffix.
	var name := file_name.strip_edges()
	if name.to_lower().ends_with(".import"):
		name = name.substr(0, name.length() - 7)
	return name


func _sort_music_paths(a: String, b: String) -> bool:
	var ai := _music_path_index(a)
	var bi := _music_path_index(b)
	if ai == bi:
		return a < b
	return ai < bi


func _music_path_index(path: String) -> int:
	var base := path.get_file().get_basename().to_lower()
	var suffix := base.trim_prefix(MUSIC_PREFIX)
	return int(suffix) if suffix.is_valid_int() else 999999


func rescan_and_start() -> void:
	_scan_tracks()
	if enabled:
		start()


func set_enabled(value: bool) -> void:
	enabled = value
	if enabled:
		resume_music()
	else:
		pause_music()


func start() -> void:
	_manual_paused = false

	if not enabled or _app_paused or _universe_end_stopped:
		return

	if _tracks.is_empty():
		_scan_tracks()

	if _tracks.is_empty():
		_retry_start_later()
		return

	_start_retry_count = 0

	if _player == null or not is_instance_valid(_player):
		_build_player()

	if _player.stream != null and _player.stream_paused:
		_resume_current_track(false)
		return

	if _player.playing:
		_fade_to(_effective_track_volume_db(), FIRST_START_FADE_IN_SECONDS if not _has_started_once else 0.0)
		return

	_play_next_track(true)


func _retry_start_later() -> void:
	if _start_retry_count >= MAX_START_RETRIES:
		return

	_start_retry_count += 1
	var retry_token := _start_retry_count
	await get_tree().create_timer(START_RETRY_SECONDS).timeout
	if retry_token != _start_retry_count:
		return
	if enabled and not _app_paused and (_player == null or not _player.playing):
		start()


func stop_with_fade() -> void:
	# Kept for compatibility with older call sites. For settings OFF we pause instead of
	# destroying the current track, so ON can continue smoothly.
	pause_music()


func pause_for_app() -> void:
	_app_paused = true
	_hard_pause_for_app()


func resume_from_app() -> void:
	_app_paused = false
	if not enabled or _manual_paused or _universe_end_stopped:
		return
	_resume_current_track(false)


func _hard_pause_for_app() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null

	_new_fade_token()
	_session_paused = true

	if _player.stream != null:
		_player.stream_paused = true

	# Keep it silent until AppContentScreen explicitly releases the runtime gate.
	_player.volume_db = MUTED_VOLUME_DB


func pause_music() -> void:
	_manual_paused = true
	_pause_current_track(true)


func resume_music() -> void:
	_manual_paused = false
	if enabled and not _app_paused and not _universe_end_stopped:
		_resume_current_track(false)


func _pause_current_track(with_fade: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	if _player.stream == null:
		return

	if _player.stream_paused:
		return

	_session_paused = true

	if not _player.playing:
		_player.stream_paused = true
		return

	if not with_fade:
		_player.stream_paused = true
		_player.volume_db = MUTED_VOLUME_DB
		return

	var token := _fade_to(MUTED_VOLUME_DB, PAUSE_FADE_SECONDS)
	await get_tree().create_timer(PAUSE_FADE_SECONDS).timeout
	if token != _fade_token:
		return
	if _player != null and is_instance_valid(_player) and _session_paused:
		_player.stream_paused = true


func _resume_current_track(with_fade: bool) -> void:
	if _app_paused or _universe_end_stopped:
		return

	if _tracks.is_empty():
		_scan_tracks()

	if _player == null or not is_instance_valid(_player):
		_build_player()

	if _tracks.is_empty():
		_retry_start_later()
		return

	if _player.stream == null:
		_play_next_track(true)
		return

	_session_paused = false
	_player.volume_db = _effective_track_volume_db()
	_player.stream_paused = false

	if not _player.playing:
		_player.play()

	# App resume should continue immediately at the track's level. Fade-in is only
	# for the first actual start, not resume from OS pause.
	_fade_to(_effective_track_volume_db(), FIRST_START_FADE_IN_SECONDS if with_fade and not _has_started_once else 0.0)


func _on_track_finished() -> void:
	if _starting_new_track or _session_paused or _app_paused or _manual_paused or _universe_end_stopped:
		return
	if enabled:
		_play_next_track(true)


func _play_next_track(fade_in: bool) -> void:
	if _tracks.is_empty():
		return

	_starting_new_track = true

	var attempts := _tracks.size()
	while attempts > 0:
		attempts -= 1
		var index := _take_next_track_index()
		var stream := _load_music_stream(_tracks[index])
		if stream == null:
			push_warning("Could not load music track: %s" % _tracks[index])
			continue

		if _fade_tween != null:
			_fade_tween.kill()
			_fade_tween = null

		_player.stop()
		_player.stream = stream
		_current_track_volume_db = _volume_for_track_path(_tracks[index])
		var should_fade_in := fade_in and not _has_started_once
		var target_volume_db := _effective_track_volume_db()
		_player.volume_db = MUTED_VOLUME_DB if should_fade_in else target_volume_db
		_player.stream_paused = false
		_session_paused = false
		_player.play()
		var is_first_music_start := not _has_started_once
		_has_started_once = true
		_starting_new_track = false

		if should_fade_in and is_first_music_start:
			_fade_to(target_volume_db, FIRST_START_FADE_IN_SECONDS)
		else:
			_player.volume_db = target_volume_db
		return

	_starting_new_track = false


func duck_for_achievement() -> void:
	_achievement_duck_count += 1
	_apply_music_context_volume(ACHIEVEMENT_DUCK_FADE_SECONDS)


func release_achievement_duck() -> void:
	_achievement_duck_count = max(0, _achievement_duck_count - 1)
	_apply_music_context_volume(ACHIEVEMENT_UNDUCK_FADE_SECONDS)


func stop_for_universe_end(_fade_seconds: float = 0.0) -> void:
	# Called when the actual universe-end collision begins. The death dance itself
	# keeps music alive; at collision time the track stops immediately and stays
	# silent until THE END? disappears.
	if _universe_end_stopped and _session_paused:
		return

	_universe_end_stopped = true
	session_pause_for_blocking_sequence()


func resume_after_universe_end() -> void:
	if not _universe_end_stopped:
		return
	_universe_end_stopped = false
	_session_paused = false
	if enabled and not _app_paused and not _manual_paused:
		_play_next_track(false)


func session_pause_for_blocking_sequence() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	_new_fade_token()
	_session_paused = true
	_player.stop()
	_player.stream_paused = false
	_player.volume_db = MUTED_VOLUME_DB


func _fade_pause_for_universe_end(fade_seconds: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null

	_session_paused = true

	if _player.stream == null or (not _player.playing and not _player.stream_paused):
		_player.volume_db = MUTED_VOLUME_DB
		return

	if _player.stream_paused:
		_player.volume_db = MUTED_VOLUME_DB
		return

	var token := _fade_to(MUTED_VOLUME_DB, max(fade_seconds, 0.01))
	await get_tree().create_timer(max(fade_seconds, 0.01), true, false, true).timeout
	if token != _fade_token:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if not _universe_end_stopped:
		return
	_player.stream_paused = true
	_player.volume_db = MUTED_VOLUME_DB


func _apply_music_context_volume(duration: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.stream == null or not _player.playing or _player.stream_paused:
		return
	if _app_paused or _manual_paused or _universe_end_stopped:
		return
	_fade_to(_effective_track_volume_db(), duration)


func _effective_track_volume_db() -> float:
	if _achievement_duck_count > 0:
		return max(ACHIEVEMENT_DUCK_MIN_VOLUME_DB, _current_track_volume_db + ACHIEVEMENT_DUCK_EXTRA_DB)
	return _current_track_volume_db


func _volume_for_track_path(path: String) -> float:
	var index := _music_path_index(path)
	if TRACK_VOLUME_DB.has(index):
		return float(TRACK_VOLUME_DB[index])
	return DEFAULT_TRACK_VOLUME_DB


func _load_music_stream(path: String) -> AudioStream:
	var stream := ResourceLoader.load(path) as AudioStream
	if stream != null:
		return stream

	# Fallback for raw files that exist but have not been picked up by ResourceLoader yet.
	if path.to_lower().ends_with(".mp3") and FileAccess.file_exists(path):
		return AudioStreamMP3.load_from_file(path)

	return null


func _take_next_track_index() -> int:
	if _unplayed_track_indices.is_empty():
		_reset_unplayed_bag()

	if _unplayed_track_indices.is_empty():
		return 0

	var bag_position := _rng.randi_range(0, _unplayed_track_indices.size() - 1)
	var track_index := int(_unplayed_track_indices[bag_position])
	_unplayed_track_indices.remove_at(bag_position)
	return track_index


func _reset_unplayed_bag() -> void:
	_unplayed_track_indices.clear()
	for i in _tracks.size():
		_unplayed_track_indices.append(i)


func _new_fade_token() -> int:
	_fade_token += 1
	return _fade_token


func _fade_to(target_db: float, duration: float) -> int:
	var token := _new_fade_token()
	if _player == null or not is_instance_valid(_player):
		return token

	if _fade_tween != null:
		_fade_tween.kill()

	if duration <= 0.0:
		_player.volume_db = target_db
		return token

	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_player, "volume_db", target_db, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	return token
