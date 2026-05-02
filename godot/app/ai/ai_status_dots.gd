extends Node
class_name AIAssistant

@export var fake_thinking_time: float = 0.45
@export var cooldown_seconds: float = 50.0

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var ai_status_dots: Control = $AIStatusDots
@onready var stt: NativeSTTService = $NativeSTTService

var running := false
var speaking := false
var processing := false

var _cooldown_timer: SceneTreeTimer
var _audio := AIAudio.new()


func _ready() -> void:
	_setup_status_dots()

	add_child(_audio)
	_audio.setup(audio_player)

	stt.wake_detected.connect(_on_wake_detected)
	stt.command_result.connect(_on_command_result)
	stt.partial_result.connect(_on_partial_result)
	stt.state_changed.connect(_on_stt_state_changed)
	stt.error.connect(_on_stt_error)

	AIState.ai_enabled_changed.connect(_on_ai_enabled_changed)

	if AIState.enabled:
		start()


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


func start() -> void:
	if running:
		return

	running = true
	speaking = false
	processing = false

	AIState.set_state(AIState.State.IDLE)
	stt.start()


func stop() -> void:
	running = false
	speaking = false
	processing = false

	stt.stop()
	_audio.stop()

	AIState.reset()


func _on_wake_detected(text: String) -> void:
	if not _can_process():
		return

	AIState.set_transcript(text)
	await _play_known_response("wake")


func _on_command_result(text: String) -> void:
	if not _can_process():
		return

	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		return

	AIState.set_transcript(cleaned)

	# For now, Java/addon should send the known command/intent id as text.
	# Example: "navigate/quiz", "action/generate_planet", etc.
	await _play_known_response(cleaned)


func _on_partial_result(text: String) -> void:
	if not running or not AIState.enabled:
		return

	AIState.set_transcript(text)

	if not speaking and not processing:
		AIState.set_state(AIState.State.LISTENING)


func _on_stt_state_changed(state: String) -> void:
	if not running or speaking or processing:
		return

	print("STT state: ", state)

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

	if not speaking and not processing:
		AIState.set_state(AIState.State.IDLE)


func _play_known_response(intent_id: String) -> void:
	processing = true
	speaking = false

	AIState.set_state(AIState.State.THINKING)
	await get_tree().create_timer(fake_thinking_time).timeout

	if not running or not AIState.enabled:
		processing = false
		return

	processing = false
	speaking = true

	AIState.set_state(AIState.State.SPEAKING)

	await _audio.play_random_intent_response(intent_id)

	speaking = false

	if running and AIState.enabled:
		AIState.set_state(AIState.State.LISTENING)
		_start_cooldown()
	else:
		AIState.set_state(AIState.State.IDLE)


func _start_cooldown() -> void:
	_cooldown_timer = get_tree().create_timer(cooldown_seconds)
	_wait_for_cooldown(_cooldown_timer)


func _wait_for_cooldown(timer: SceneTreeTimer) -> void:
	await timer.timeout

	if timer != _cooldown_timer:
		return

	if speaking or processing:
		_start_cooldown()
		return

	AIState.set_state(AIState.State.IDLE)


func _can_process() -> bool:
	if not running:
		return false

	if not AIState.enabled:
		return false

	if speaking:
		return false

	if processing:
		return false

	return true


func _on_ai_enabled_changed(value: bool) -> void:
	if value:
		start()
	else:
		stop()
