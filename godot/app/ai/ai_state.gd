extends Node

enum State {
	IDLE,
	LISTENING,
	THINKING,
	SPEAKING
}

signal state_changed(new_state: State)
signal transcript_changed(text: String)
signal response_folder_changed(path: String)
signal ai_enabled_changed(enabled: bool)

var current_state: State = State.IDLE
var transcript: String = ""
var response_folder: String = ""

var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value
		ai_enabled_changed.emit(value)

		if not enabled:
			reset()


func set_state(new_state: State) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	state_changed.emit(new_state)


func set_transcript(text: String) -> void:
	if transcript == text:
		return

	transcript = text
	transcript_changed.emit(text)


func set_response_folder(path: String) -> void:
	if response_folder == path:
		return

	response_folder = path
	response_folder_changed.emit(path)


func set_command(text: String, folder_path: String) -> void:
	set_transcript(text)
	set_response_folder(folder_path)


func reset() -> void:
	current_state = State.IDLE
	transcript = ""
	response_folder = ""

	state_changed.emit(current_state)
	transcript_changed.emit(transcript)
	response_folder_changed.emit(response_folder)
