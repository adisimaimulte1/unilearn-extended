extends Node
class_name AIAssistant

@export var backend_url: String = "https://optima-livekit-token-server.onrender.com/apollo-chat"
@export var cooldown_seconds: float = 50.0
@export var fake_thinking_time: float = 0.45

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var ai_status_dots: Control = $AIStatusDots
@onready var stt: NativeSTTService = $NativeSTTService

var running := false
var ai_speaking := false
var processing_command := false

var _cooldown_timer: SceneTreeTimer
var _audio := AIAudio.new()


func _ready() -> void:
	_setup_status_dots()

	add_child(_audio)
	_audio.setup(audio_player, http_request, backend_url)

	stt.wake_detected.connect(_on_stt_wake_detected)
	stt.command_result.connect(_on_stt_command_result)
	stt.partial_result.connect(_on_stt_partial_result)
	stt.state_changed.connect(_on_stt_state_changed)
	stt.error.connect(_on_stt_error)

	AIState.ai_enabled_changed.connect(_on_ai_enabled_changed)

	if AIState.enabled:
		start_loop()


func _setup_status_dots() -> void:
	ai_status_dots.set_anchors_preset(Control.PRESET_CENTER_TOP, false)
	ai_status_dots.size = Vector2(330, 165)
	ai_status_dots.position = Vector2(
		(get_viewport().get_visible_rect().size.x - ai_status_dots.size.x) * 0.5,
		110.0
	)

	ai_status_dots.z_index = 999
	ai_status_dots.mouse_filter = Control.MOUSE_FILTER_STOP
	ai_status_dots.clip_contents = false


func start_loop() -> void:
	if running:
		return

	running = true
	ai_speaking = false
	processing_command = false

	AIState.set_state(AIState.State.IDLE)
	stt.start()


func stop_loop() -> void:
	running = false
	ai_speaking = false
	processing_command = false

	stt.stop()
	_audio.stop()
	AIState.reset()


func _on_stt_wake_detected(text: String) -> void:
	if not _can_process():
		return

	print("Apollo woke up: ", text)

	AIState.set_command(text, "wake")
	await _respond()


func _on_stt_command_result(raw: String) -> void:
	if not _can_process():
		return

	var payload := _parse_command_payload(raw)

	var text: String = payload["text"]
	var folder: String = payload["folder"]

	if text.strip_edges().is_empty():
		return

	print("Apollo command: ", text, " | folder: ", folder)

	AIState.set_command(text, folder)
	await _respond()


func _respond() -> void:
	processing_command = true
	ai_speaking = false

	AIState.set_state(AIState.State.THINKING)
	await get_tree().create_timer(fake_thinking_time).timeout

	if not running or not AIState.enabled:
		processing_command = false
		return

	processing_command = false
	ai_speaking = true

	AIState.set_state(AIState.State.SPEAKING)

	await _audio.play_response(
		AIState.response_folder,
		AIState.transcript
	)

	_finish_interaction()


func _finish_interaction() -> void:
	ai_speaking = false
	processing_command = false

	if AIState.enabled and running:
		AIState.set_state(AIState.State.LISTENING)
		_start_cooldown()
	else:
		AIState.set_state(AIState.State.IDLE)


func _on_stt_partial_result(text: String) -> void:
	if not running or not AIState.enabled:
		return

	AIState.set_transcript(text)

	if not ai_speaking and not processing_command:
		AIState.set_state(AIState.State.LISTENING)


func _on_stt_state_changed(state: String) -> void:
	if not running:
		return

	print("STT state: ", state)

	if ai_speaking or processing_command:
		return

	match state:
		"wake_listening":
			AIState.set_state(AIState.State.IDLE)

		"active_listening":
			AIState.set_state(AIState.State.LISTENING)

		"idle":
			AIState.set_state(AIState.State.IDLE)

		"stopped":
			AIState.set_state(AIState.State.IDLE)


func _on_stt_error(message: String) -> void:
	print("STT error: ", message)

	if not ai_speaking and not processing_command:
		AIState.set_state(AIState.State.IDLE)


func _parse_command_payload(raw: String) -> Dictionary:
	var json := JSON.new()

	if json.parse(raw) == OK and typeof(json.data) == TYPE_DICTIONARY:
		return {
			"text": str(json.data.get("text", "")),
			"folder": str(json.data.get("folder", ""))
		}

	return {
		"text": raw.strip_edges(),
		"folder": raw.strip_edges()
	}


func _start_cooldown() -> void:
	_cooldown_timer = get_tree().create_timer(cooldown_seconds)
	_wait_for_cooldown(_cooldown_timer)


func _wait_for_cooldown(timer: SceneTreeTimer) -> void:
	await timer.timeout

	if timer != _cooldown_timer:
		return

	if ai_speaking or processing_command:
		_start_cooldown()
		return

	AIState.set_state(AIState.State.IDLE)


func cancel_playback() -> void:
	_audio.stop()
	ai_speaking = false
	processing_command = false
	AIState.set_state(AIState.State.IDLE)


func _can_process() -> bool:
	return running and AIState.enabled and not ai_speaking and not processing_command


func _on_ai_enabled_changed(value: bool) -> void:
	if value:
		start_loop()
	else:
		stop_loop()
