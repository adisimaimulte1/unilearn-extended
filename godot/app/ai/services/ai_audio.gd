extends Node
class_name AIAudio

signal playback_started
signal playback_finished

const AUDIO_ROOT := "res://assets/audio/ai"
const LOCAL_FALLBACK_FOLDER := "fallbacks/command_not_registered"

var player: AudioStreamPlayer
var http: HTTPRequest
var backend_url: String = ""


func setup(audio_player: AudioStreamPlayer, http_request: HTTPRequest, url: String) -> void:
	player = audio_player
	http = http_request
	backend_url = url


func play_response(folder_path: String, _backend_text: String = "") -> bool:
	var clean_folder := folder_path.strip_edges().trim_prefix("/").trim_suffix("/")

	if not clean_folder.is_empty():
		var full_folder := "%s/%s" % [AUDIO_ROOT, clean_folder]

		if DirAccess.dir_exists_absolute(full_folder):
			var played_local: bool = await _play_random_numbered_mp3(full_folder)

			if played_local:
				return true

	return await play_fallback_response()


func play_fallback_response() -> bool:
	var fallback_folder := "%s/%s" % [AUDIO_ROOT, LOCAL_FALLBACK_FOLDER]

	if not DirAccess.dir_exists_absolute(fallback_folder):
		push_warning("Apollo local fallback response folder is missing: %s" % fallback_folder)
		return false

	return await _play_random_numbered_mp3(fallback_folder)

func play_mp3_bytes(bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		return false

	var temp_path := "user://ai_response.mp3"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)

	if file == null:
		return false

	file.store_buffer(bytes)
	file.close()

	var stream := AudioStreamMP3.load_from_file(temp_path)

	if stream == null:
		return false

	player.stream = stream
	player.play()

	playback_started.emit()

	await player.finished

	playback_finished.emit()

	return true

func _play_random_numbered_mp3(folder_path: String) -> bool:
	var files: Array[String] = []

	for i in range(1, 21):
		var file_path: String = "%s/%d.mp3" % [folder_path, i]

		if ResourceLoader.exists(file_path):
			files.append(file_path)

	if files.is_empty():
		push_warning("No AI response resources found in: %s" % folder_path)
		return false

	var selected: String = files.pick_random()
	var stream: AudioStream = load(selected) as AudioStream

	if stream == null:
		push_warning("Could not load AI response file: %s" % selected)
		return false

	player.stream = stream
	player.play()

	playback_started.emit()

	await player.finished

	playback_finished.emit()

	return true


func stop() -> void:
	if player:
		player.stop()


func _request_backend_mp3(_text: String) -> PackedByteArray:
	# Server chat fallback is intentionally disabled for public builds.
	# Voice replies are now fully local: requested folder first, then LOCAL_FALLBACK_FOLDER.
	return PackedByteArray()
