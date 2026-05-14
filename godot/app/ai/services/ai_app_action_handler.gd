extends Node
class_name AIAppActionHandler

const ACTION_CHANGE_SETTINGS := "actions/change_settings/"
const ACTION_NAVIGATE := "actions/navigate/"
const ACTION_CREATE := "actions/create/"
const JUST_TALK := "just_talk/"

var assistant: AIAssistant = null
var settings: Node = null


func setup(owner: AIAssistant) -> void:
	assistant = owner
	settings = get_node_or_null("/root/UnilearnUserSettings")


func handles(folder: String) -> bool:
	folder = folder.strip_edges()

	return (
		folder.begins_with(ACTION_CHANGE_SETTINGS)
		or folder.begins_with(ACTION_NAVIGATE)
		or folder.begins_with(ACTION_CREATE)
		or folder.begins_with(JUST_TALK)
	)


func execute_before_response(_folder: String, _spoken_text: String = "") -> void:
	pass


func execute_on_response_started(folder: String, spoken_text: String = "") -> void:
	folder = folder.strip_edges()

	if settings == null:
		settings = get_node_or_null("/root/UnilearnUserSettings")

	match folder:
		"actions/change_settings/sfx_on":
			await _apply_setting_action("sfx_on")

		"actions/change_settings/sfx_off":
			await _apply_setting_action("sfx_off")

		"actions/change_settings/reduce_motion_on":
			await _apply_setting_action("reduce_motion_on")

		"actions/change_settings/reduce_motion_off":
			await _apply_setting_action("reduce_motion_off")

		"actions/change_settings/theme_dark":
			await _apply_setting_action("theme_dark")

		"actions/change_settings/theme_light":
			await _apply_setting_action("theme_light")

		"actions/change_settings/wake_word_detection_on":
			await _apply_setting_action("wake_word_detection_on")

		"actions/change_settings/wake_word_detection_off":
			pass

		"actions/navigate/enter_menu":
			_call_app_controller("enter_menu")

		"actions/navigate/exit_menu":
			_call_app_controller("exit_menu")

		"actions/navigate/enter_settings":
			_call_app_controller("enter_settings")

		"actions/navigate/exit_settings":
			_call_app_controller("exit_settings")

		"actions/navigate/enter_planet_cards":
			_call_app_controller("enter_planet_cards")

		"actions/navigate/exit_planet_cards":
			_call_app_controller("exit_planet_cards")

		"actions/create/planet":
			_call_app_controller("create_planet", spoken_text)

		"just_talk/joke":
			pass


func execute_after_response(folder: String, _spoken_text: String = "") -> void:
	folder = folder.strip_edges()

	match folder:
		"actions/change_settings/wake_word_detection_off":
			await _apply_setting_action("wake_word_detection_off")

			if assistant != null:
				assistant.stop()

func should_resume_after(folder: String) -> bool:
	return folder.strip_edges() != "actions/change_settings/wake_word_detection_off"


func _apply_setting_action(action_id: String) -> void:
	if _is_setting_action_already_applied(action_id):
		return

	var popup := _get_open_settings_popup()

	if popup != null and popup.has_method("simulate_ai_setting_tap"):
		var handled: bool = await popup.simulate_ai_setting_tap(action_id)

		if handled:
			return

	_apply_setting_direct(action_id)


func _is_setting_action_already_applied(action_id: String) -> bool:
	if settings == null:
		settings = get_node_or_null("/root/UnilearnUserSettings")

	if settings == null:
		return false

	match action_id:
		"sfx_on":
			return "sfx_enabled" in settings and bool(settings.sfx_enabled)

		"sfx_off":
			return "sfx_enabled" in settings and not bool(settings.sfx_enabled)

		"reduce_motion_on":
			return "reduce_motion_enabled" in settings and bool(settings.reduce_motion_enabled)

		"reduce_motion_off":
			return "reduce_motion_enabled" in settings and not bool(settings.reduce_motion_enabled)

		"theme_dark":
			return "theme_dark_mode" in settings and bool(settings.theme_dark_mode)

		"theme_light":
			return "theme_dark_mode" in settings and not bool(settings.theme_dark_mode)

		"wake_word_detection_on":
			return "apollo_enabled" in settings and bool(settings.apollo_enabled)

		"wake_word_detection_off":
			return "apollo_enabled" in settings and not bool(settings.apollo_enabled)

		_:
			return false


func _apply_setting_direct(action_id: String) -> void:
	match action_id:
		"sfx_on":
			_set_sfx_enabled(true)

		"sfx_off":
			_set_sfx_enabled(false)

		"reduce_motion_on":
			_set_reduce_motion_enabled(true)

		"reduce_motion_off":
			_set_reduce_motion_enabled(false)

		"theme_dark":
			_set_theme_dark_mode(true)

		"theme_light":
			_set_theme_dark_mode(false)

		"wake_word_detection_on":
			_set_apollo_enabled(true)

		"wake_word_detection_off":
			_set_apollo_enabled(false)


func _get_open_settings_popup() -> Node:
	var tree := get_tree()

	if tree == null or tree.root == null:
		return null

	return _find_settings_popup_recursive(tree.root)


func _find_settings_popup_recursive(node: Node) -> Node:
	if node == null:
		return null

	if node.has_method("simulate_ai_setting_tap"):
		return node

	if node.name.to_lower().contains("settingspopup"):
		return node

	for child in node.get_children():
		var found := _find_settings_popup_recursive(child)

		if found != null:
			return found

	return null


func _set_sfx_enabled(value: bool) -> void:
	if settings == null:
		settings = get_node_or_null("/root/UnilearnUserSettings")

	if settings == null:
		return

	if "sfx_enabled" in settings and bool(settings.sfx_enabled) == value:
		return

	if settings.has_method("set_sfx_enabled"):
		settings.set_sfx_enabled(value)

	_update_sfx_node_live(value)


func _set_reduce_motion_enabled(value: bool) -> void:
	if settings == null:
		settings = get_node_or_null("/root/UnilearnUserSettings")

	if settings == null:
		return

	if "reduce_motion_enabled" in settings and bool(settings.reduce_motion_enabled) == value:
		return

	if settings.has_method("set_reduce_motion_enabled"):
		settings.set_reduce_motion_enabled(value)


func _set_theme_dark_mode(value: bool) -> void:
	if settings == null:
		settings = get_node_or_null("/root/UnilearnUserSettings")

	if settings == null:
		return

	if "theme_dark_mode" in settings and bool(settings.theme_dark_mode) == value:
		return

	if settings.has_method("set_theme_dark_mode"):
		settings.set_theme_dark_mode(value)


func _set_apollo_enabled(value: bool) -> void:
	if settings == null:
		settings = get_node_or_null("/root/UnilearnUserSettings")

	if settings == null:
		return

	if "apollo_enabled" in settings and bool(settings.apollo_enabled) == value:
		return

	if settings.has_method("set_wake_word_detection_enabled"):
		settings.set_wake_word_detection_enabled(value)
		return

	if settings.has_method("set_apollo_enabled"):
		settings.set_apollo_enabled(value)


func _update_sfx_node_live(value: bool) -> void:
	var sfx := get_node_or_null("/root/UnilearnSFX")

	if sfx == null:
		return

	if sfx.has_method("set_enabled"):
		sfx.set_enabled(value)
	elif "enabled" in sfx:
		sfx.enabled = value


func _call_app_controller(method_name: String, arg: Variant = null) -> void:
	var controller := _get_app_controller()

	if controller == null:
		return

	if not controller.has_method(method_name):
		return

	if arg == null:
		controller.call(method_name)
	else:
		controller.call(method_name, arg)


func _get_app_controller() -> Node:
	var paths := [
		"/root/UnilearnAppController",
		"/root/AppCommandBus",
		"/root/ApolloAppController",
		"/root/UnilearnNavigation"
	]

	for path in paths:
		var node := get_node_or_null(path)

		if node != null:
			return node

	return null
