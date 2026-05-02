extends Node
class_name NativeSTTService

signal wake_detected(text: String)
signal command_result(text: String)
signal partial_result(text: String)
signal state_changed(state: String)
signal error(message: String)

var speech_plugin: Object = null
var is_ready := false
var is_running := false

var _paused_by_app := false
var _waiting_for_permission := false
var _resume_pending := false


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
	_waiting_for_permission = false
	_resume_pending = false

	speech_plugin.setWakeName("apollo")
	speech_plugin.setActiveCooldownMs(120000)
	speech_plugin.startWakeLoop()

	state_changed.emit("starting")


func stop() -> void:
	if not is_ready:
		return

	is_running = false
	_paused_by_app = false
	_waiting_for_permission = false
	_resume_pending = false

	speech_plugin.stopWakeLoop()
	state_changed.emit("stopped")


func force_activate() -> void:
	if not is_ready:
		return

	speech_plugin.forceActivate()


func _on_focus_out() -> void:
	if not is_ready or not is_running:
		return

	# IMPORTANT:
	# Android permission popup causes focus out.
	# Do NOT stop STT while waiting for permission.
	if _waiting_for_permission:
		print("Focus lost during permission request. Not stopping STT.")
		return

	_paused_by_app = true
	speech_plugin.stopWakeLoop()
	state_changed.emit("paused")


func _on_focus_in() -> void:
	if not is_ready or not is_running:
		return

	if _resume_pending:
		return

	if not _paused_by_app and not _waiting_for_permission:
		return

	_resume_pending = true

	await get_tree().create_timer(1.2).timeout

	_resume_pending = false

	if not is_running or speech_plugin == null:
		return

	_paused_by_app = false

	print("Starting STT after focus/permission return...")
	speech_plugin.startWakeLoop()


func _on_wake_detected(text: String) -> void:
	_waiting_for_permission = false
	_paused_by_app = false
	wake_detected.emit(text)


func _on_command_result(text: String) -> void:
	command_result.emit(text)


func _on_partial_result(text: String) -> void:
	_waiting_for_permission = false
	_paused_by_app = false
	partial_result.emit(text)


func _on_state_changed(state: String) -> void:
	state_changed.emit(state)

	match state:
		"requesting_permission":
			_waiting_for_permission = true

		"permission_granted":
			_waiting_for_permission = false

		"wake_listening", "active_listening":
			_waiting_for_permission = false
			_paused_by_app = false

		"permission_denied":
			_waiting_for_permission = false
			_paused_by_app = false


func _on_error(message: String) -> void:
	error.emit(message)
