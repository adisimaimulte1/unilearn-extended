extends Node
class_name AIAssistant

@export var backend_url: String = "https://optima-livekit-token-server.onrender.com/apollo-chat"
@export var fake_thinking_time: float = 0.9
@export var speaking_hold_time: float = 0.2
@export var quit_app_from_permission_popups: bool = true

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var ai_status_dots: Control = $AIStatusDots
@onready var stt: NativeSTTService = $ApolloSpeechService

var running: bool = false
var speaking: bool = false
var processing: bool = false
var active_window: bool = false
var sleep_response_active: bool = false

var _audio := AIAudio.new()
var _permission_popup: AIPermissionPopup = null


func _ready() -> void:
	_setup_status_dots()

	add_child(_audio)
	_audio.setup(audio_player, http_request, backend_url)
	_audio.playback_started.connect(_on_audio_playback_started)
	_audio.playback_finished.connect(_on_audio_playback_finished)

	stt.wake_detected.connect(_on_wake_detected)
	stt.sleep_detected.connect(_on_sleep_detected)
	stt.command_result.connect(_on_command_result)
	stt.partial_result.connect(_on_partial_result)
	stt.state_changed.connect(_on_stt_state_changed)
	stt.error.connect(_on_stt_error)

	stt.permission_restart_required.connect(_on_permission_restart_required)
	stt.permission_required_denied.connect(_on_permission_required_denied)

	AIState.ai_enabled_changed.connect(_on_ai_enabled_changed)

	if AIState.enabled:
		start()


func _setup_status_dots() -> void:
	ai_status_dots.set_anchors_preset(Control.PRESET_CENTER_TOP, false)
	ai_status_dots.size = Vector2(270, 125)
	ai_status_dots.position = Vector2(
		(get_viewport().get_visible_rect().size.x - ai_status_dots.size.x) * 0.5,
		110.0
	)

	ai_status_dots.z_index = 999
	ai_status_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ai_status_dots.clip_contents = false


func start() -> void:
	if running:
		return

	running = true
	speaking = false
	processing = false
	active_window = false
	sleep_response_active = false

	AIState.set_state(AIState.State.IDLE)
	stt.start()


func stop() -> void:
	running = false
	speaking = false
	processing = false
	active_window = false
	sleep_response_active = false

	stt.stop()
	_audio.stop()
	AIState.reset()


func _on_wake_detected(text: String) -> void:
	if not _can_process():
		return

	print("Apollo wake: ", text)

	active_window = true
	AIState.set_command(text, "wake")
	AIState.set_state(AIState.State.LISTENING)

	await _respond()


func _on_sleep_detected(text: String) -> void:
	if not running or not AIState.enabled:
		return

	if processing:
		return

	print("Apollo sleep: ", text)

	_audio.stop()
	speaking = false

	await _respond_sleep(text)


func _respond_sleep(text: String) -> void:
	sleep_response_active = true
	processing = true
	speaking = false
	active_window = false

	_pause_stt_for_response()

	AIState.set_command(text, "sleep")
	AIState.set_state(AIState.State.THINKING)

	await get_tree().create_timer(fake_thinking_time).timeout

	if not running or not AIState.enabled:
		sleep_response_active = false
		processing = false
		speaking = false
		active_window = false
		AIState.set_state(AIState.State.IDLE)
		_resume_stt_wake_only()
		return

	var played: bool = await _audio.play_response(
		"sleep",
		text
	)

	if played:
		await get_tree().create_timer(speaking_hold_time).timeout

	processing = false
	speaking = false
	active_window = false
	sleep_response_active = false

	AIState.set_command("", "")
	AIState.set_state(AIState.State.IDLE)

	_resume_stt_wake_only()


func _on_command_result(raw: String) -> void:
	if not _can_process():
		return

	var payload: Dictionary = _parse_command_payload(raw)

	var text: String = payload["text"]
	var folder: String = payload["folder"]

	if text.strip_edges().is_empty():
		return

	print("Apollo command: ", text, " | folder: ", folder)

	active_window = true
	AIState.set_command(text, folder)

	await _respond()


func _respond() -> void:
	processing = true
	speaking = false

	_pause_stt_for_response()

	AIState.set_state(AIState.State.THINKING)
	await get_tree().create_timer(fake_thinking_time).timeout

	if not running or not AIState.enabled:
		processing = false
		_resume_stt_after_response()
		return

	var played: bool = await _audio.play_response(
		AIState.response_folder,
		AIState.transcript
	)

	if played:
		await get_tree().create_timer(speaking_hold_time).timeout

	processing = false
	speaking = false

	if running and AIState.enabled:
		active_window = true
		AIState.set_state(AIState.State.LISTENING)
		_resume_stt_after_response()
	else:
		active_window = false
		AIState.set_state(AIState.State.IDLE)
		_resume_stt_after_response()


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


func _on_partial_result(text: String) -> void:
	if not running or not AIState.enabled:
		return

	AIState.set_transcript(text)

	if not speaking and not processing and active_window:
		AIState.set_state(AIState.State.LISTENING)


func _on_stt_state_changed(state: String) -> void:
	if not running:
		return

	print("STT state: ", state)

	if sleep_response_active:
		match state:
			"idle", "wake_listening", "stopped", "active_listening":
				return

	if speaking or processing:
		return

	match state:
		"active_listening":
			active_window = true
			AIState.set_state(AIState.State.LISTENING)

		"wake_listening":
			active_window = false
			AIState.set_state(AIState.State.IDLE)

		"idle":
			active_window = false
			AIState.set_state(AIState.State.IDLE)

		"stopped":
			active_window = false
			AIState.set_state(AIState.State.IDLE)


func _on_stt_error(message: String) -> void:
	print("STT error: ", message)

	if speaking or processing or sleep_response_active:
		return

	if active_window:
		AIState.set_state(AIState.State.LISTENING)
	else:
		AIState.set_state(AIState.State.IDLE)


func _on_permission_restart_required() -> void:
	_stop_assistant_for_permission_popup()

	_show_permission_popup(
		"Microphone Ready",
		"Restart once so Apollo can listen correctly.",
		"Close App",
		true,
		false
	)


func _on_permission_required_denied() -> void:
	_stop_assistant_for_permission_popup()

	_show_permission_popup(
		"Microphone Required",
		"Enable microphone access to continue.",
		"Close App",
		true,
		true
	)


func _show_permission_popup(
	title_text: String,
	body_text: String,
	button_text: String,
	quit_on_confirm: bool,
	is_permission_rejected: bool
) -> void:
	_clear_permission_popup()

	var popup := AIPermissionPopup.new()
	_permission_popup = popup

	popup.setup(
		title_text,
		body_text,
		button_text,
		quit_on_confirm,
		is_permission_rejected
	)

	popup.closed.connect(_on_permission_popup_closed)

	add_child(popup)


func _stop_assistant_for_permission_popup() -> void:
	running = false
	speaking = false
	processing = false
	active_window = false
	sleep_response_active = false

	_audio.stop()
	AIState.set_state(AIState.State.IDLE)


func _on_permission_popup_closed(should_quit: bool) -> void:
	_permission_popup = null

	if should_quit and quit_app_from_permission_popups:
		get_tree().quit()


func _clear_permission_popup() -> void:
	if _permission_popup != null and is_instance_valid(_permission_popup):
		_permission_popup.queue_free()

	_permission_popup = null


func _can_process() -> bool:
	return running and AIState.enabled and not speaking and not processing and not sleep_response_active


func cancel_playback() -> void:
	_audio.stop()

	speaking = false
	processing = false
	sleep_response_active = false

	if running and AIState.enabled:
		active_window = true
		AIState.set_state(AIState.State.LISTENING)
		_resume_stt_after_response()
	else:
		active_window = false
		AIState.set_state(AIState.State.IDLE)
		_resume_stt_after_response()


func _on_ai_enabled_changed(value: bool) -> void:
	if value:
		start()
	else:
		stop()


func _on_audio_playback_started() -> void:
	if not running or not AIState.enabled:
		return

	processing = false
	speaking = true
	AIState.set_state(AIState.State.SPEAKING)


func _on_audio_playback_finished() -> void:
	speaking = false


func _pause_stt_for_response() -> void:
	stt.stop()


func _resume_stt_after_response() -> void:
	if not running or not AIState.enabled:
		return

	stt.start()
	stt.start_active_timeout()


func _resume_stt_wake_only() -> void:
	if not running or not AIState.enabled:
		return

	stt.start()
