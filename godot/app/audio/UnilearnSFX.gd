extends Node

const AI_RESPONSE_DUCK_EXTRA_DB := -6.0206
const AI_RESPONSE_DUCK_FADE_SECONDS := 0.55
const AI_RESPONSE_UNDUCK_FADE_SECONDS := 0.80

const SFX_PATHS := {
	"click": "res://assets/audio/sfx/ui_click.wav",
	"toggle": "res://assets/audio/sfx/ui_toggle.wav",
	"open": "res://assets/audio/sfx/ui_open.wav",
	"close": "res://assets/audio/sfx/ui_open.wav",
	"error": "res://assets/audio/sfx/ui_error.wav",
	"success": "res://assets/audio/sfx/ui_success.wav",
	"whoosh": "res://assets/audio/sfx/ui_whoosh.wav",
	"splash_intro": "res://assets/audio/sfx/splash_intro_sfx.wav",
	"achievement": "res://assets/audio/sfx/achievement.mp3",
	"achievement_rare": "res://assets/audio/sfx/achievement_rare.mp3"
}

const SFX_VOLUME_OFFSETS_DB := {
	"click": -11.5,
	"toggle": -11.5,
	"open": 0.0,
	"close": 0.0,
	"error": 0.0,
	"success": 0.0,
	"whoosh": 0.0,
	"splash_intro": -9.0,
	"achievement": -4.0,
	"achievement_rare": -4.0
}

@export var pool_size: int = 8
@export var volume_db: float = 1.0

var enabled: bool = true

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_player_index: int = 0
var _ai_response_duck_count := 0
var _context_volume_tween: Tween = null


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
	var base_volume := _base_volume_for_sfx(id)
	player.set_meta("unilearn_sfx_base_volume_db", base_volume)
	player.volume_db = _effective_sfx_volume_db(base_volume)
	player.play()


func play_stacked(id: String, pitch_min: float = 0.96, pitch_max: float = 1.04) -> void:
	if not enabled:
		return

	if not _streams.has(id):
		return

	var player := AudioStreamPlayer.new()
	player.name = "StackedSFX_%s" % id
	player.bus = "Master"
	player.stream = _streams[id]
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	var base_volume := _base_volume_for_sfx(id)
	player.set_meta("unilearn_sfx_base_volume_db", base_volume)
	player.volume_db = _effective_sfx_volume_db(base_volume)
	player.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)
	add_child(player)
	player.play()


func duck_for_ai_response() -> void:
	_ai_response_duck_count += 1
	_apply_context_volume(AI_RESPONSE_DUCK_FADE_SECONDS)


func release_ai_response_duck() -> void:
	_ai_response_duck_count = max(0, _ai_response_duck_count - 1)
	_apply_context_volume(AI_RESPONSE_UNDUCK_FADE_SECONDS)


func _apply_context_volume(duration: float) -> void:
	if _context_volume_tween != null and _context_volume_tween.is_valid():
		_context_volume_tween.kill()
	_context_volume_tween = create_tween()
	_context_volume_tween.set_parallel(true)
	for player in _players:
		if not is_instance_valid(player) or not player.playing:
			continue
		var base_volume := float(player.get_meta("unilearn_sfx_base_volume_db", volume_db))
		_context_volume_tween.tween_property(player, "volume_db", _effective_sfx_volume_db(base_volume), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for child in get_children():
		if not (child is AudioStreamPlayer) or _players.has(child) or not child.playing:
			continue
		var base_volume := float(child.get_meta("unilearn_sfx_base_volume_db", volume_db))
		_context_volume_tween.tween_property(child, "volume_db", _effective_sfx_volume_db(base_volume), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _effective_sfx_volume_db(base_volume: float) -> float:
	return base_volume + (AI_RESPONSE_DUCK_EXTRA_DB if _ai_response_duck_count > 0 else 0.0)


func _base_volume_for_sfx(id: String) -> float:
	var offset := 0.0

	if SFX_VOLUME_OFFSETS_DB.has(id):
		offset = float(SFX_VOLUME_OFFSETS_DB[id])

	return volume_db + offset
