extends Node
class_name AIAssistant

@export var backend_url := UnilearnBackendService.APOLLO_CHAT_URL
@export var fake_thinking_time := 1.0
@export var command_sequence_thinking_break := 1.0
@export var speaking_hold_time := 0.2
@export var quit_app_from_permission_popups := true

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var ai_status_dots: Control = $AIStatusDots
@onready var stt: NativeSTTService = $ApolloSpeechService

var _actions := AIAppActionHandler.new()

var _pending_action_folder := ""
var _pending_action_text := ""
var _pending_action_params: Dictionary = {}
var _pending_action_started := false

var running := false
var speaking := false
var processing := false
var active_window := false
var sleep_response_active := false

var _audio := AIAudio.new()
var _permission_popup: AIPermissionPopup = null
var _settings: Node = null

var _external_generation_active := false
var _external_generation_query := ""
var _external_generation_previous_ai_enabled := true
var _external_generation_previous_running := false
var _external_generation_forced_ai_visual := false
var _external_generation_completed_with_new_card := false
var _external_generation_start_ids: Dictionary = {}

var _response_cancel_token := 0
var _paused_by_app_runtime := false
var _was_stt_running_before_app_pause := false


func _ready() -> void:
	_cache_settings()
	_setup_status_dots()
	_setup_audio()
	_setup_actions()
	_connect_signals()
	_connect_planet_generation_signals()

	if AIState.enabled:
		start()
	elif _is_planet_generation_active():
		_enter_external_generation_mode(_get_active_planet_generation_query(), true)


func prepare_entry_animation() -> void:
	if not is_instance_valid(ai_status_dots):
		return

	ai_status_dots.visible = true

	if ai_status_dots.has_method("prepare_entry_animation"):
		ai_status_dots.call("prepare_entry_animation")
	else:
		ai_status_dots.modulate.a = 0.0


func play_entry_animation() -> void:
	if not is_instance_valid(ai_status_dots):
		return

	ai_status_dots.visible = true

	if ai_status_dots.has_method("play_entry_animation"):
		ai_status_dots.call("play_entry_animation")
	else:
		ai_status_dots.modulate.a = 1.0


func play_exit_animation() -> void:
	if not is_instance_valid(ai_status_dots):
		return

	ai_status_dots.visible = true

	if ai_status_dots.has_method("play_exit_animation"):
		ai_status_dots.call("play_exit_animation")
	else:
		ai_status_dots.visible = false


func set_runtime_paused_by_app(paused: bool) -> void:
	if _paused_by_app_runtime == paused:
		return

	_paused_by_app_runtime = paused

	if is_instance_valid(ai_status_dots) and ai_status_dots.has_method("set_app_animation_paused"):
		ai_status_dots.call("set_app_animation_paused", paused)

	if paused:
		_was_stt_running_before_app_pause = is_instance_valid(stt) and stt.is_running
		if _was_stt_running_before_app_pause:
			_stop_stt()
		if is_instance_valid(audio_player) and audio_player.playing:
			audio_player.stream_paused = true
	else:
		if is_instance_valid(audio_player) and audio_player.stream != null:
			audio_player.stream_paused = false
		if _was_stt_running_before_app_pause and running and AIState.enabled and not _external_generation_active:
			_start_stt()
		_was_stt_running_before_app_pause = false


func start() -> void:
	if running and AIState.enabled and is_instance_valid(stt) and stt.is_running:
		return

	# Safety recovery for the wake-word-off flow: the AIState signal used to be able
	# to leave Apollo marked as running while the native STT service was already stopped.
	# In that stale state, a manual ON tap called start(), hit the old early return,
	# and never restarted listening.
	if running and not AIState.enabled:
		running = false

	if not is_apollo_allowed():
		return

	_set_ai_enabled(true)

	running = true
	_reset_runtime_flags()
	active_window = false

	AIState.set_command("", "")

	if _is_planet_generation_active():
		_enter_external_generation_mode(_get_active_planet_generation_query(), true)
		return

	AIState.set_state(AIState.State.IDLE)

	_start_stt()

func stop() -> void:
	if _external_generation_active:
		_external_generation_previous_running = false
		_external_generation_previous_ai_enabled = false
		_external_generation_forced_ai_visual = true

		_response_cancel_token += 1
		_audio.stop()
		_stop_stt()

		running = true
		active_window = false
		speaking = false
		processing = true
		sleep_response_active = false

		_set_ai_enabled(true)
		AIState.set_state(AIState.State.THINKING)
		return

	if not running and not AIState.enabled:
		return

	_response_cancel_token += 1

	running = false
	_reset_runtime_flags()
	active_window = false
	_external_generation_active = false
	_external_generation_query = ""
	_external_generation_forced_ai_visual = false

	_stop_stt()
	_audio.stop()

	_set_ai_enabled(false)

	# _set_ai_enabled(false) emits AIState.ai_enabled_changed synchronously. Keep the
	# final runtime flags authoritative after every signal callback finishes.
	running = false
	_reset_runtime_flags()
	active_window = false
	_clear_pending_action()
	AIState.reset()


func set_apollo_button_enabled(enabled: bool) -> void:
	if _settings != null and _settings.has_method("set_apollo_enabled"):
		_settings.call("set_apollo_enabled", enabled)

	if _external_generation_active:
		_external_generation_previous_ai_enabled = enabled
		_external_generation_previous_running = enabled
		_external_generation_forced_ai_visual = not enabled

		_set_ai_enabled(true)
		running = true
		AIState.set_state(AIState.State.THINKING)
		return

	_set_ai_enabled(enabled)

	if enabled:
		start()
	else:
		stop()


func cancel_playback() -> void:
	_response_cancel_token += 1

	_audio.stop()

	speaking = false
	processing = false
	sleep_response_active = false

	if _external_generation_active:
		active_window = false
		processing = true
		AIState.set_state(AIState.State.THINKING)
		return

	if running and AIState.enabled:
		active_window = true
		AIState.set_state(AIState.State.LISTENING)
	else:
		active_window = false
		AIState.set_state(AIState.State.IDLE)

	_resume_stt_after_response()


func is_apollo_allowed() -> bool:
	if _external_generation_active:
		return true

	if _settings != null:
		return bool(_settings.get("apollo_enabled"))

	return true


func _cache_settings() -> void:
	_settings = get_node_or_null("/root/UnilearnUserSettings")


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

func _setup_audio() -> void:
	if _audio.get_parent() == null:
		add_child(_audio)

	_audio.setup(audio_player, http_request, backend_url)
	_connect_once(_audio.playback_started, _on_audio_playback_started)
	_connect_once(_audio.playback_finished, _on_audio_playback_finished)

func _setup_actions() -> void:
	if _actions.get_parent() == null:
		add_child(_actions)

	_actions.setup(self)


func _connect_signals() -> void:
	_connect_stt_signals()
	_connect_once(AIState.ai_enabled_changed, _on_ai_enabled_changed)

func _connect_stt_signals() -> void:
	_connect_once(stt.wake_detected, _on_wake_detected)
	_connect_once(stt.sleep_detected, _on_sleep_detected)
	_connect_once(stt.command_result, _on_command_result)
	_connect_once(stt.partial_result, _on_partial_result)
	_connect_once(stt.state_changed, _on_stt_state_changed)
	_connect_once(stt.error, _on_stt_error)
	_connect_once(stt.permission_restart_required, _on_permission_restart_required)
	_connect_once(stt.permission_required_denied, _on_permission_required_denied)

func _connect_planet_generation_signals() -> void:
	if not has_node("/root/PlanetCardsCache"):
		return

	if PlanetCardsCache.has_signal("card_generation_started"):
		_connect_once(PlanetCardsCache.card_generation_started, _on_planet_card_generation_started)

	if PlanetCardsCache.has_signal("card_generation_finished"):
		_connect_once(PlanetCardsCache.card_generation_finished, _on_planet_card_generation_finished)

	if PlanetCardsCache.has_signal("card_generation_failed"):
		_connect_once(PlanetCardsCache.card_generation_failed, _on_planet_card_generation_failed)

	if _is_planet_generation_active():
		_enter_external_generation_mode(_get_active_planet_generation_query(), true)

func _connect_once(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _on_planet_card_generation_started(query: String, _predicted_id: String) -> void:
	_snapshot_planet_card_ids_before_generation()
	_external_generation_completed_with_new_card = false
	_enter_external_generation_mode(query, false)

func _on_planet_card_generation_finished(card: PlanetData) -> void:
	_external_generation_completed_with_new_card = _did_generation_add_new_card(card)
	_exit_external_generation_mode()

func _on_planet_card_generation_failed(_query: String, _error: String) -> void:
	_external_generation_completed_with_new_card = false
	_exit_external_generation_mode()


func _enter_external_generation_mode(query: String = "", immediate: bool = false) -> void:
	_response_cancel_token += 1

	if not _external_generation_active:
		_external_generation_previous_ai_enabled = AIState.enabled
		_external_generation_previous_running = running
		_external_generation_forced_ai_visual = not AIState.enabled

		if _external_generation_start_ids.is_empty():
			_snapshot_planet_card_ids_before_generation()

	_external_generation_active = true
	_external_generation_query = query.strip_edges()

	active_window = false
	sleep_response_active = false
	speaking = false
	processing = true

	_audio.stop()
	_stop_stt()

	if not AIState.enabled:
		_set_ai_enabled(true)

	if not running:
		running = true

	AIState.set_command(_external_generation_query, "planet_generation")
	AIState.set_state(AIState.State.THINKING)

	if not immediate:
		print("Apollo paused for planet generation: ", _external_generation_query)

func _exit_external_generation_mode() -> void:
	if not _external_generation_active:
		return

	if _is_planet_generation_active():
		_external_generation_query = _get_active_planet_generation_query()
		AIState.set_command(_external_generation_query, "planet_generation")
		AIState.set_state(AIState.State.THINKING)
		return

	var should_restore_disabled := _external_generation_forced_ai_visual
	var should_restore_running := _external_generation_previous_running
	var should_restore_ai_enabled := _external_generation_previous_ai_enabled
	var added_new_card := _external_generation_completed_with_new_card

	_external_generation_active = false
	_external_generation_query = ""
	_external_generation_forced_ai_visual = false
	_external_generation_completed_with_new_card = false
	_external_generation_start_ids.clear()

	processing = false
	speaking = false
	sleep_response_active = false
	active_window = false

	_play_generation_finished_sfx(added_new_card)

	if should_restore_disabled or not should_restore_ai_enabled:
		running = false
		_set_ai_enabled(false)
		AIState.reset()
		return

	if not should_restore_running:
		running = false
		AIState.set_command("", "")
		AIState.set_state(AIState.State.IDLE)
		return

	if not running or not AIState.enabled or not is_apollo_allowed():
		AIState.set_state(AIState.State.IDLE)
		return

	AIState.set_command("", "")
	AIState.set_state(AIState.State.IDLE)
	_resume_stt_wake_only()


func _play_generation_finished_sfx(added_new_card: bool) -> void:
	if not has_node("/root/UnilearnSFX"):
		return

	var sfx := get_node("/root/UnilearnSFX")

	if sfx == null:
		return

	if "enabled" in sfx and not bool(sfx.enabled):
		return

	if not sfx.has_method("play"):
		return

	sfx.play("success" if added_new_card else "error")


func _snapshot_planet_card_ids_before_generation() -> void:
	_external_generation_start_ids.clear()

	if not has_node("/root/PlanetCardsCache"):
		return

	if not PlanetCardsCache.has_method("get_all_cards"):
		return

	var cards: Array[PlanetData] = PlanetCardsCache.get_all_cards()

	for card in cards:
		if card == null:
			continue

		var id := card.instance_id.strip_edges()

		if not id.is_empty():
			_external_generation_start_ids[id] = true


func _did_generation_add_new_card(card: PlanetData) -> bool:
	if card == null:
		return false

	var id := card.instance_id.strip_edges()

	if id.is_empty():
		return false

	if not _external_generation_start_ids.has(id):
		return true

	if not has_node("/root/PlanetCardsCache"):
		return false

	if not PlanetCardsCache.has_method("get_all_cards"):
		return false

	var cards: Array[PlanetData] = PlanetCardsCache.get_all_cards()

	for existing in cards:
		if existing == null:
			continue

		if existing.instance_id.strip_edges() == id and not _external_generation_start_ids.has(id):
			return true

	return false

func _is_planet_generation_active() -> bool:
	if not has_node("/root/PlanetCardsCache"):
		return false

	if PlanetCardsCache.has_method("is_generating_any_card"):
		return PlanetCardsCache.is_generating_any_card()

	return false

func _get_active_planet_generation_query() -> String:
	if not has_node("/root/PlanetCardsCache"):
		return ""

	if not PlanetCardsCache.has_method("get_active_generation_queries"):
		return ""

	var queries: Array[String] = PlanetCardsCache.get_active_generation_queries()

	if queries.is_empty():
		return ""

	return str(queries[0])


func _on_wake_detected(text: String) -> void:
	if _external_generation_active:
		return

	if not _can_process():
		return

	print("Apollo wake: ", text)

	active_window = true
	AIState.set_command(text, "wake")
	AIState.set_state(AIState.State.LISTENING)

	await _respond()

func _on_sleep_detected(text: String) -> void:
	if _external_generation_active:
		return

	if not running or not AIState.enabled or processing:
		return

	print("Apollo sleep: ", text)

	_audio.stop()
	speaking = false

	await _respond_sleep(text)

func _on_command_result(raw: String) -> void:
	if _external_generation_active:
		return

	if not _can_process():
		return

	var payload := _parse_command_payload(raw)
	var text: String = str(payload.get("text", ""))
	var commands: Array = payload.get("commands", [])

	if text.strip_edges().is_empty():
		return

	if commands.is_empty():
		print("Apollo command/chat: ", text)
		active_window = true
		AIState.set_command(text, "")
		await _respond()
		return

	print("Apollo command: ", text, " | commands: ", commands.size())

	active_window = true

	if _actions != null:
		await _respond_action_sequence(commands, text)
		return

	await _respond()

func _on_partial_result(text: String) -> void:
	if _external_generation_active:
		return

	if not running or not AIState.enabled:
		return

	AIState.set_transcript(text)

	if active_window and not speaking and not processing:
		AIState.set_state(AIState.State.LISTENING)

func _on_stt_state_changed(state: String) -> void:
	if not running:
		return

	print("STT state: ", state)

	if _external_generation_active:
		AIState.set_state(AIState.State.THINKING)
		return

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

		"wake_listening", "idle", "stopped":
			active_window = false
			AIState.set_state(AIState.State.IDLE)

func _on_stt_error(message: String) -> void:
	print("STT error: ", message)

	if _external_generation_active:
		AIState.set_state(AIState.State.THINKING)
		return

	if speaking or processing or sleep_response_active:
		return

	AIState.set_state(AIState.State.LISTENING if active_window else AIState.State.IDLE)

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

func _on_permission_popup_closed(should_quit: bool) -> void:
	_permission_popup = null

	if should_quit and quit_app_from_permission_popups:
		get_tree().quit()

func _on_audio_playback_started() -> void:
	if _external_generation_active:
		_audio.stop()
		speaking = false
		processing = true
		AIState.set_state(AIState.State.THINKING)
		return

	if not running or not AIState.enabled:
		return

	if not _pending_action_started and not _pending_action_folder.strip_edges().is_empty():
		_pending_action_started = true

		if _actions != null and _actions.handles(_pending_action_folder):
			_actions.execute_on_response_started(
				_pending_action_folder,
				_pending_action_text,
				_pending_action_params
			)

	processing = false
	speaking = true
	AIState.set_state(AIState.State.SPEAKING)

func _on_audio_playback_finished() -> void:
	speaking = false

	if _external_generation_active:
		processing = true
		AIState.set_state(AIState.State.THINKING)

func _on_ai_enabled_changed(value: bool) -> void:
	if _external_generation_active:
		if not AIState.enabled:
			_set_ai_enabled(true)

		running = true
		processing = true
		speaking = false
		active_window = false
		_stop_stt()
		_audio.stop()
		AIState.set_state(AIState.State.THINKING)
		return

	if not _pending_action_folder.strip_edges().is_empty():
		var folder := _pending_action_folder.strip_edges()

		if folder == "actions/change_settings/wake_word_detection_off":
			# Do not resurrect the runtime while the OFF action is shutting Apollo down.
			# The old code set running=true here, which made the next manual start skip
			# _start_stt(), leaving the dots idle/thinking but no real microphone session.
			if not value:
				return

	if value:
		start()
	else:
		stop()


func _respond() -> void:
	await _run_response_flow(
		AIState.response_folder,
		AIState.transcript,
		true,
		false
	)

func _respond_action(folder: String, text: String) -> void:
	_response_cancel_token += 1
	var local_token := _response_cancel_token

	processing = true
	speaking = false
	sleep_response_active = false
	active_window = false

	_pending_action_folder = folder
	_pending_action_text = text
	_pending_action_started = false

	_pause_stt_for_response()
	AIState.set_state(AIState.State.THINKING)

	_actions.execute_before_response(folder, text)

	var response_folder := folder
	var response_text := text
	var response_override := _get_action_response_override(folder, text)

	if not response_override.is_empty():
		response_folder = str(response_override.get("folder", folder)).strip_edges()
		response_text = str(response_override.get("text", text)).strip_edges()

	await _wait_fake_thinking()

	if local_token != _response_cancel_token or _external_generation_active:
		_clear_pending_action()
		return

	var played: bool = await _audio.play_response(response_folder, response_text)

	if local_token != _response_cancel_token or _external_generation_active:
		_audio.stop()
		_clear_pending_action()
		return

	if not played:
		_clear_pending_action()
		processing = false
		speaking = false
		active_window = false
		AIState.set_command("", "")
		AIState.set_state(AIState.State.IDLE)
		_resume_stt_wake_only()
		return

	if speaking_hold_time > 0.0:
		await get_tree().create_timer(speaking_hold_time).timeout

	if local_token != _response_cancel_token or _external_generation_active:
		_audio.stop()
		_clear_pending_action()
		return

	await _actions.execute_after_response(folder, text)

	var should_resume := _actions.should_resume_after(folder)

	_clear_pending_action()

	processing = false
	speaking = false
	sleep_response_active = false

	if not should_resume:
		active_window = false
		AIState.set_command("", "")
		AIState.set_state(AIState.State.IDLE)
		return

	if running and AIState.enabled and is_apollo_allowed():
		active_window = true
		AIState.set_state(AIState.State.LISTENING)
		_resume_stt_after_response()
	else:
		active_window = false
		AIState.set_command("", "")
		AIState.set_state(AIState.State.IDLE)

func _respond_action_sequence(commands: Array, text: String) -> void:
	_response_cancel_token += 1
	var local_token := _response_cancel_token

	processing = true
	speaking = false
	sleep_response_active = false
	active_window = false

	_pause_stt_for_response()
	AIState.set_state(AIState.State.THINKING)

	await _wait_fake_thinking()

	if local_token != _response_cancel_token or _external_generation_active:
		_clear_pending_action()
		return

	for command_index in commands.size():
		if local_token != _response_cancel_token or _external_generation_active:
			_audio.stop()
			_clear_pending_action()
			return

		var raw_command: Variant = commands[command_index]

		if not (raw_command is Dictionary):
			continue

		var command: Dictionary = raw_command
		var folder := str(command.get("folder", "")).strip_edges()
		var params: Dictionary = command.get("params", {}) if command.get("params", {}) is Dictionary else {}

		if folder.is_empty():
			continue

		if _actions == null or not _actions.handles(folder):
			continue

		AIState.set_command(text, folder)

		_pending_action_folder = folder
		_pending_action_text = text
		_pending_action_params = params
		_pending_action_started = false

		_actions.execute_before_response(folder, text, params)

		var response_folder := folder
		var response_text := text
		var response_override := _get_action_response_override(folder, text, params)

		if not response_override.is_empty():
			response_folder = str(response_override.get("folder", folder)).strip_edges()
			response_text = str(response_override.get("text", text)).strip_edges()

		var played: bool = await _audio.play_response(response_folder, response_text)

		if local_token != _response_cancel_token or _external_generation_active:
			_audio.stop()
			_clear_pending_action()
			return

		if not played:
			if not _pending_action_started:
				_pending_action_started = true
				await _actions.execute_on_response_started(folder, text, params)

			await _actions.execute_after_response(folder, text, params)
			_clear_pending_action()

			if _has_next_sequence_action(commands, command_index):
				var can_continue_sequence := await _wait_between_sequence_commands(local_token)

				if not can_continue_sequence:
					return

			continue

		if speaking_hold_time > 0.0:
			await get_tree().create_timer(speaking_hold_time).timeout

		if local_token != _response_cancel_token or _external_generation_active:
			_audio.stop()
			_clear_pending_action()
			return

		await _actions.execute_after_response(folder, text, params)
		_clear_pending_action()

		if _has_next_sequence_action(commands, command_index):
			var can_continue_sequence := await _wait_between_sequence_commands(local_token)

			if not can_continue_sequence:
				return

	var should_resume := true

	for raw_command in commands:
		if not (raw_command is Dictionary):
			continue

		var folder := str(raw_command.get("folder", "")).strip_edges()

		if _actions != null and not _actions.should_resume_after(folder):
			should_resume = false
			break

	processing = false
	speaking = false
	sleep_response_active = false

	if not should_resume:
		active_window = false
		AIState.set_command("", "")
		AIState.set_state(AIState.State.IDLE)
		return

	if running and AIState.enabled and is_apollo_allowed():
		active_window = true
		AIState.set_state(AIState.State.LISTENING)
		_resume_stt_after_response()
	else:
		active_window = false
		AIState.set_command("", "")
		AIState.set_state(AIState.State.IDLE)

func _has_next_sequence_action(commands: Array, current_index: int) -> bool:
	if _actions == null:
		return false

	for index in range(current_index + 1, commands.size()):
		var raw_command: Variant = commands[index]

		if not (raw_command is Dictionary):
			continue

		var folder := str(raw_command.get("folder", "")).strip_edges()

		if not folder.is_empty() and _actions.handles(folder):
			return true

	return false


func _wait_between_sequence_commands(local_token: int) -> bool:
	if local_token != _response_cancel_token or _external_generation_active:
		_audio.stop()
		_clear_pending_action()
		return false

	processing = true
	speaking = false
	active_window = false
	AIState.set_state(AIState.State.THINKING)

	if command_sequence_thinking_break > 0.0:
		await get_tree().create_timer(command_sequence_thinking_break).timeout

	if local_token != _response_cancel_token or _external_generation_active:
		_audio.stop()
		_clear_pending_action()
		return false

	return true


func _get_action_response_override(folder: String, text: String, params: Dictionary = {}) -> Dictionary:
	if _actions == null:
		return {}

	if not _actions.has_method("get_response_override"):
		return {}

	var result = _actions.call("get_response_override", folder, text, params)

	if result is Dictionary:
		return result

	return {}


func _respond_sleep(text: String) -> void:
	if _external_generation_active:
		return

	sleep_response_active = true
	active_window = false
	AIState.set_command(text, "sleep")

	await _run_response_flow(
		"sleep",
		text,
		false,
		true
	)


func _run_response_flow(folder: String, text: String, keep_active_after: bool, wake_only_after: bool) -> void:
	if _external_generation_active:
		return

	_response_cancel_token += 1
	var local_token := _response_cancel_token

	processing = true
	speaking = false

	_pause_stt_for_response()
	AIState.set_state(AIState.State.THINKING)

	await _wait_fake_thinking()

	if local_token != _response_cancel_token or _external_generation_active:
		return

	if not running or not AIState.enabled:
		_finish_response_cancelled(wake_only_after)
		return

	var played: bool = await _audio.play_response(folder, text)

	if local_token != _response_cancel_token or _external_generation_active:
		_audio.stop()
		return

	if played and speaking_hold_time > 0.0:
		await get_tree().create_timer(speaking_hold_time).timeout

	if local_token != _response_cancel_token or _external_generation_active:
		_audio.stop()
		return

	processing = false
	speaking = false
	sleep_response_active = false
	active_window = keep_active_after and running and AIState.enabled

	if active_window:
		AIState.set_state(AIState.State.LISTENING)
		_resume_stt_after_response()
	else:
		AIState.set_command("", "")
		AIState.set_state(AIState.State.IDLE)

		if wake_only_after:
			_resume_stt_wake_only()
		else:
			_resume_stt_after_response()


func _wait_fake_thinking() -> void:
	if fake_thinking_time <= 0.0:
		return

	await get_tree().create_timer(fake_thinking_time).timeout


func _finish_response_cancelled(wake_only_after: bool) -> void:
	processing = false
	speaking = false
	sleep_response_active = false
	active_window = false

	if _external_generation_active:
		processing = true
		AIState.set_state(AIState.State.THINKING)
		return

	AIState.set_state(AIState.State.IDLE)

	if wake_only_after:
		_resume_stt_wake_only()
	else:
		_resume_stt_after_response()


func _parse_command_payload(raw: String) -> Dictionary:
	var json := JSON.new()

	if json.parse(raw) == OK and typeof(json.data) == TYPE_DICTIONARY:
		var data: Dictionary = json.data
		var commands: Array = []

		var raw_commands: Variant = data.get("commands", [])

		if raw_commands is Array:
			for item in raw_commands:
				if not (item is Dictionary):
					continue

				var command: Dictionary = item
				var folder := str(command.get("folder", "")).strip_edges()

				if folder.is_empty():
					continue

				var params: Dictionary = {}
				var raw_params: Variant = command.get("params", {})

				if raw_params is Dictionary:
					params = raw_params

				commands.append({
					"folder": folder,
					"confidence": int(command.get("confidence", 0)),
					"params": params
				})

		return {
			"text": str(data.get("text", "")),
			"normalizedText": str(data.get("normalizedText", "")),
			"commandCount": int(data.get("commandCount", commands.size())),
			"commands": commands
		}

	var cleaned := raw.strip_edges()

	return {
		"text": cleaned,
		"normalizedText": cleaned.to_lower(),
		"commandCount": 0,
		"commands": []
	}


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

	_connect_once(popup.closed, _on_permission_popup_closed)
	add_child(popup)


func _clear_permission_popup() -> void:
	if _permission_popup != null and is_instance_valid(_permission_popup):
		_permission_popup.queue_free()

	_permission_popup = null

func _clear_pending_action() -> void:
	_pending_action_folder = ""
	_pending_action_text = ""
	_pending_action_params.clear()
	_pending_action_started = false


func _stop_assistant_for_permission_popup() -> void:
	running = false
	_reset_runtime_flags()
	active_window = false

	_audio.stop()
	_stop_stt()
	AIState.set_state(AIState.State.IDLE)


func _reset_runtime_flags() -> void:
	speaking = false
	processing = false
	sleep_response_active = false


func _set_ai_enabled(enabled: bool) -> void:
	if AIState.has_method("set_enabled"):
		AIState.set_enabled(enabled)
	else:
		AIState.enabled = enabled


func _can_process() -> bool:
	return (
		running
		and AIState.enabled
		and not speaking
		and not processing
		and not sleep_response_active
		and not _external_generation_active
	)


func _pause_stt_for_response() -> void:
	_stop_stt()

func _resume_stt_after_response() -> void:
	if _external_generation_active:
		return

	if not is_apollo_allowed():
		return

	if not running or not AIState.enabled:
		return

	_start_stt()
	stt.start_active_timeout()

func _resume_stt_wake_only() -> void:
	if _external_generation_active:
		return

	if not is_apollo_allowed():
		return

	if not running or not AIState.enabled:
		return

	_start_stt()


func _start_stt() -> void:
	if _paused_by_app_runtime:
		return

	if _external_generation_active:
		return

	if stt.is_running:
		return

	stt.start()

func _stop_stt() -> void:
	if not stt.is_running:
		return

	stt.stop()
