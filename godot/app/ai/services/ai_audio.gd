extends Node
class_name AIAudio

const AUDIO_ROOT := "res://assets/audio/ai"

var player: AudioStreamPlayer
var http: HTTPRequest
var backend_url: String = ""


func setup(audio_player: AudioStreamPlayer, http_request: HTTPRequest, url: String) -> void:
	player = audio_player
	http = http_request
	backend_url = url


func play_response(folder_path: String, backend_text: String) -> void:
	var full_folder := "%s/%s" % [AUDIO_ROOT, folder_path.strip_edges()]

	if DirAccess.dir_exists_absolute(full_folder):
		await _play_random_numbered_mp3(full_folder)
		return

	var bytes := await _request_backend_mp3(backend_text)
	await play_mp3_bytes(bytes)


func play_mp3_bytes(bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		return

	var temp_path := "user://ai_response.mp3"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)

	if file == null:
		return

	file.store_buffer(bytes)
	file.close()

	var stream := AudioStreamMP3.load_from_file(temp_path)

	if stream == null:
		return

	player.stream = stream
	player.play()
	await player.finished


func stop() -> void:
	if player:
		player.stop()


func _play_random_numbered_mp3(folder_path: String) -> void:
	var number := randi_range(1, 20)
	var file_path := "%s/%d.mp3" % [folder_path, number]

	if not FileAccess.file_exists(file_path):
		push_warning("Missing AI response file: %s" % file_path)
		return

	var stream := load(file_path)

	if stream == null:
		push_warning("Could not load AI response file: %s" % file_path)
		return

	player.stream = stream
	player.play()
	await player.finished


func _request_backend_mp3(text: String) -> PackedByteArray:
	if http == null or backend_url.is_empty():
		return PackedByteArray()

	var body := JSON.stringify({
		"message": text
	})

	var headers := [
		"Content-Type: application/json"
	]

	var err := http.request(
		backend_url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		push_warning("AI backend request failed to start.")
		return PackedByteArray()

	var result = await http.request_completed
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if response_code < 200 or response_code >= 300:
		push_warning("AI backend returned HTTP %d" % response_code)
		return PackedByteArray()

	return response_body
