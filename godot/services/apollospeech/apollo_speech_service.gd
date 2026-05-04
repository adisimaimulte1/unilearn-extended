extends Node
class_name NativeSTTService

signal wake_detected(text: String)
signal sleep_detected(text: String)
signal command_result(text: String)
signal partial_result(text: String)
signal state_changed(state: String)
signal error(message: String)

signal permission_restart_required
signal permission_required_denied

var speech_plugin: Object = null
var is_ready := false
var is_running := false

var _paused_by_app := false
var _resume_pending := false
var _permission_flow := false


func _ready() -> void:
	_setup_plugin()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_focus_out()

	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_on_focus_in()


func _setup_plugin() -> void:
	if not Engine.has_singleton("ApolloSpeech"):
		error.emit("ApolloSpeech plugin not found.")
		return

	speech_plugin = Engine.get_singleton("ApolloSpeech")

	speech_plugin.wake_detected.connect(_on_wake_detected)

	if speech_plugin.has_signal("sleep_detected"):
		speech_plugin.sleep_detected.connect(_on_sleep_detected)

	speech_plugin.command_result.connect(_on_command_result)
	speech_plugin.partial_result.connect(_on_partial_result)
	speech_plugin.state_changed.connect(_on_state_changed)
	speech_plugin.error.connect(_on_error)

	is_ready = true
	state_changed.emit("ready")


func start() -> void:
	if not is_ready:
		error.emit("Native STT is not ready.")
		return

	if is_running:
		return

	is_running = true
	_paused_by_app = false
	_resume_pending = false
	_permission_flow = false

	if speech_plugin.has_method("setAssistantName"):
		speech_plugin.setAssistantName("apollo")
	else:
		speech_plugin.setWakeName("apollo")

	speech_plugin.setActiveCooldownMs(40000)
	speech_plugin.startWakeLoop()

	state_changed.emit("starting")


func stop() -> void:
	if not is_ready:
		return

	is_running = false
	_paused_by_app = false
	_resume_pending = false
	_permission_flow = false

	speech_plugin.stopWakeLoop()
	state_changed.emit("stopped")


func force_activate() -> void:
	if not is_ready:
		return

	speech_plugin.forceActivate()


func start_active_timeout() -> void:
	if not is_ready or speech_plugin == null:
		return

	speech_plugin.startActiveTimeout()


func _on_focus_out() -> void:
	if not is_ready or not is_running:
		return

	if _permission_flow:
		return

	_paused_by_app = true
	speech_plugin.stopWakeLoop()
	state_changed.emit("paused")


func _on_focus_in() -> void:
	if not is_ready or not is_running:
		return

	if _resume_pending:
		return

	if _permission_flow:
		print("Focus returned during permission flow. Java plugin will handle it.")
		return

	if not _paused_by_app:
		return

	_resume_pending = true
	await get_tree().create_timer(1.2).timeout
	_resume_pending = false

	if not is_running or speech_plugin == null:
		return

	_paused_by_app = false
	speech_plugin.startWakeLoop()


func _on_wake_detected(text: String) -> void:
	_paused_by_app = false
	_permission_flow = false
	wake_detected.emit(text)


func _on_sleep_detected(text: String) -> void:
	_paused_by_app = false
	_permission_flow = false
	sleep_detected.emit(text)


func _on_command_result(text: String) -> void:
	command_result.emit(text)


func _on_partial_result(text: String) -> void:
	_paused_by_app = false
	_permission_flow = false
	partial_result.emit(text)


func _on_state_changed(state: String) -> void:
	state_changed.emit(state)

	match state:
		"requesting_permission":
			_permission_flow = true
			_paused_by_app = false

		"permission_granted_restart_required":
			is_running = false
			_permission_flow = false
			_paused_by_app = false
			_resume_pending = false
			permission_restart_required.emit()

		"permission_denied_required", "permission_denied", "permission_missing":
			is_running = false
			_permission_flow = false
			_paused_by_app = false
			_resume_pending = false
			permission_required_denied.emit()

		"wake_listening", "active_listening":
			_permission_flow = false
			_paused_by_app = false

		"idle":
			_permission_flow = false
			_paused_by_app = false

		"stopped":
			if _paused_by_app:
				return

			_resume_pending = false


func _on_error(message: String) -> void:
	error.emit(message)
