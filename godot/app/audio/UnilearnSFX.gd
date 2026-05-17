extends Node

const SFX_PATHS := {
	"click": "res://assets/audio/sfx/ui_click.wav",
	"toggle": "res://assets/audio/sfx/ui_toggle.wav",
	"open": "res://assets/audio/sfx/ui_open.wav",
	"close": "res://assets/audio/sfx/ui_open.wav",
	"error": "res://assets/audio/sfx/ui_error.wav",
	"success": "res://assets/audio/sfx/ui_success.wav",
	"whoosh": "res://assets/audio/sfx/ui_whoosh.wav"
}

const SFX_VOLUME_OFFSETS_DB := {
	"click": -11.5,
	"toggle": -11.5,
	"open": 0.0,
	"close": 0.0,
	"error": 0.0,
	"success": 0.0,
	"whoosh": 0.0
}

@export var pool_size: int = 8
@export var volume_db: float = 1.0

var enabled: bool = true

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_player_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_connect_settings_signal()
	_build_pool()
	_preload_streams()


func _connect_settings_signal() -> void:
	if not has_node("/root/UnilearnUserSettings"):
		return

	var settings := get_node("/root/UnilearnUserSettings")

	if settings.has_signal("settings_changed"):
		var callable := Callable(self, "_on_settings_changed")

		if not settings.settings_changed.is_connected(callable):
			settings.settings_changed.connect(callable)


func _on_settings_changed() -> void:
	_load_settings()


func _load_settings() -> void:
	if not has_node("/root/UnilearnUserSettings"):
		return

	var settings := get_node("/root/UnilearnUserSettings")
	enabled = settings.sfx_enabled


func _build_pool() -> void:
	for i in pool_size:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = "Master"
		player.volume_db = volume_db
		add_child(player)
		_players.append(player)


func _preload_streams() -> void:
	for id in SFX_PATHS.keys():
		var path: String = SFX_PATHS[id]

		if not ResourceLoader.exists(path):
			push_warning("Missing SFX file: " + path)
			continue

		var stream := load(path) as AudioStream

		if stream != null:
			_streams[id] = stream


func set_enabled(value: bool) -> void:
	enabled = value


func play(id: String, pitch_min: float = 0.96, pitch_max: float = 1.04) -> void:
	if not enabled:
		return

	if not _streams.has(id):
		return

	if _players.is_empty():
		return

	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()

	player.stop()
	player.stream = _streams[id]
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.volume_db = _get_volume_for_sfx(id)
	player.play()


func _get_volume_for_sfx(id: String) -> float:
	var offset := 0.0

	if SFX_VOLUME_OFFSETS_DB.has(id):
		offset = float(SFX_VOLUME_OFFSETS_DB[id])

	return volume_db + offset
