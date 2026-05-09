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

@export var pool_size: int = 8
@export var volume_db: float = 1.0

var enabled: bool = true

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_player_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_pool()
	_preload_streams()


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
	player.volume_db = volume_db
	player.play()
