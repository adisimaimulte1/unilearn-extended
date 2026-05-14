extends Node
class_name AIAppActionHandler

const ACTION_CHANGE_SETTINGS := "actions/change_settings/"
const ACTION_NAVIGATE := "actions/navigate/"
const ACTION_CREATE := "actions/create/"
const JUST_TALK := "just_talk/"

const INPUT_BLOCKER_LAYER := 9999
const INPUT_BLOCKER_EXTRA_HOLD_TIME := 0.28

const AI_ACTION_START_PAUSE := 0.22
const AI_ACTION_END_PAUSE := 0.22
const AI_CREATE_BEFORE_TYPING_PAUSE := 0.38
const AI_CREATE_AFTER_TYPING_PAUSE := 0.42
const AI_CREATE_AFTER_PLUS_PAUSE := 0.34

var assistant: AIAssistant = null
var settings: Node = null

var _input_blocker_layer: CanvasLayer = null
var _input_blocker: Control = null


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

		"actions/navigate/go_home":
			await _run_navigation_action("go_home")

		"actions/navigate/enter_menu":
			await _run_navigation_action("enter_menu")

		"actions/navigate/exit_menu":
			await _run_navigation_action("exit_menu")

		"actions/navigate/enter_settings":
			await _run_navigation_action("enter_settings")

		"actions/navigate/exit_settings":
			await _run_navigation_action("exit_settings")

		"actions/navigate/enter_planet_cards":
			await _run_navigation_action("enter_planet_cards")

		"actions/navigate/exit_planet_cards":
			await _run_navigation_action("exit_planet_cards")

		"actions/create/planet":
			await _run_create_planet_action(spoken_text)

		"actions/create/solar_system":
			_call_app_controller("create_solar_system", spoken_text)

		"actions/create/galaxy":
			_call_app_controller("create_galaxy", spoken_text)

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


func _run_navigation_action(action_id: String) -> void:
	await _show_navigation_input_blocker()

	if AI_ACTION_START_PAUSE > 0.0:
		await get_tree().create_timer(AI_ACTION_START_PAUSE).timeout

	await _apply_navigation_action(action_id)

	if AI_ACTION_END_PAUSE > 0.0:
		await get_tree().create_timer(AI_ACTION_END_PAUSE).timeout

	if INPUT_BLOCKER_EXTRA_HOLD_TIME > 0.0:
		await get_tree().create_timer(INPUT_BLOCKER_EXTRA_HOLD_TIME).timeout

	await _hide_navigation_input_blocker()


func _run_create_planet_action(spoken_text: String) -> void:
	await _show_navigation_input_blocker()

	if AI_ACTION_START_PAUSE > 0.0:
		await get_tree().create_timer(AI_ACTION_START_PAUSE).timeout

	var prompt := _extract_planet_creation_prompt(spoken_text)
	await _apply_create_planet_action(prompt)

	if AI_CREATE_AFTER_PLUS_PAUSE > 0.0:
		await get_tree().create_timer(AI_CREATE_AFTER_PLUS_PAUSE).timeout

	if INPUT_BLOCKER_EXTRA_HOLD_TIME > 0.0:
		await get_tree().create_timer(INPUT_BLOCKER_EXTRA_HOLD_TIME).timeout

	await _hide_navigation_input_blocker()


func _show_navigation_input_blocker() -> void:
	_ensure_navigation_input_blocker()

	if not is_instance_valid(_input_blocker_layer) or not is_instance_valid(_input_blocker):
		return

	_input_blocker_layer.visible = true
	_input_blocker_layer.layer = INPUT_BLOCKER_LAYER
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP


func _hide_navigation_input_blocker() -> void:
	if is_instance_valid(_input_blocker_layer):
		_input_blocker_layer.queue_free()

	_input_blocker_layer = null
	_input_blocker = null


func _ensure_navigation_input_blocker() -> void:
	if is_instance_valid(_input_blocker_layer) and is_instance_valid(_input_blocker):
		return

	_input_blocker_layer = CanvasLayer.new()
	_input_blocker_layer.name = "ApolloNavigationInputBlockerLayer"
	_input_blocker_layer.layer = INPUT_BLOCKER_LAYER
	_input_blocker_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_input_blocker_layer.visible = true

	_input_blocker = Control.new()
	_input_blocker.name = "ApolloNavigationInputBlocker"
	_input_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_blocker.offset_left = 0
	_input_blocker.offset_top = 0
	_input_blocker.offset_right = 0
	_input_blocker.offset_bottom = 0
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.process_mode = Node.PROCESS_MODE_ALWAYS
	_input_blocker.modulate.a = 0.0

	_input_blocker.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch:
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			get_viewport().set_input_as_handled()
	)

	_input_blocker_layer.add_child(_input_blocker)

	var root := get_tree().root if get_tree() != null else null

	if root != null:
		root.add_child(_input_blocker_layer)


func _extract_planet_creation_prompt(spoken_text: String) -> String:
	var text := spoken_text.strip_edges()

	if text.is_empty():
		return "planet"

	var lower := text.to_lower()

	var prefixes := [
		"create me ",
		"generate me ",
		"make me ",
		"build me ",
		"add me ",
		"spawn me ",

		"create for me ",
		"generate for me ",
		"make for me ",
		"build for me ",

		"create ",
		"generate ",
		"make ",
		"build ",
		"add ",
		"spawn "
	]

	for prefix in prefixes:
		if lower.begins_with(prefix):
			text = text.substr(prefix.length()).strip_edges()
			break

	text = _strip_polite_creation_prefix(text)

	if text.is_empty():
		return "planet"

	return text


func _strip_polite_creation_prefix(value: String) -> String:
	var text := value.strip_edges()
	var lower := text.to_lower()

	var removable_prefixes := [
		"please ",
		"a new ",
		"an new ",
		"new ",
		"custom ",
		"some ",
		"one ",
		"the object ",
		"an object ",
		"a object "
	]

	for prefix in removable_prefixes:
		if lower.begins_with(prefix):
			text = text.substr(prefix.length()).strip_edges()
			lower = text.to_lower()
			break

	return text


func _apply_create_planet_action(prompt: String) -> void:
	var menu := _get_bottom_menu()

	if menu != null and menu.has_method("simulate_ai_create_planet"):
		await menu.simulate_ai_create_planet(prompt)
		return

	_call_app_controller("create_planet", prompt)


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


func _apply_navigation_action(action_id: String) -> void:
	var menu := _get_bottom_menu()

	if menu != null:
		match action_id:
			"go_home":
				if menu.has_method("simulate_ai_go_home"):
					await menu.simulate_ai_go_home()
					return

			"enter_menu":
				if menu.has_method("simulate_ai_enter_menu"):
					await menu.simulate_ai_enter_menu()
					return

			"exit_menu":
				if menu.has_method("simulate_ai_exit_menu"):
					await menu.simulate_ai_exit_menu()
					return

			"enter_settings":
				if menu.has_method("simulate_ai_enter_settings"):
					await menu.simulate_ai_enter_settings()
					return

			"exit_settings":
				if menu.has_method("simulate_ai_exit_settings"):
					await menu.simulate_ai_exit_settings()
					return

			"enter_planet_cards":
				if menu.has_method("simulate_ai_enter_planet_cards"):
					await menu.simulate_ai_enter_planet_cards()
					return

			"exit_planet_cards":
				if menu.has_method("simulate_ai_exit_planet_cards"):
					await menu.simulate_ai_exit_planet_cards()
					return

	match action_id:
		"go_home":
			_call_app_controller("go_home")

		"enter_menu":
			_call_app_controller("enter_menu")

		"exit_menu":
			_call_app_controller("exit_menu")

		"enter_settings":
			_call_app_controller("enter_settings")

		"exit_settings":
			_call_app_controller("exit_settings")

		"enter_planet_cards":
			_call_app_controller("enter_planet_cards")

		"exit_planet_cards":
			_call_app_controller("exit_planet_cards")


func _get_bottom_menu() -> Node:
	var tree := get_tree()

	if tree == null or tree.root == null:
		return null

	return _find_bottom_menu_recursive(tree.root)


func _find_bottom_menu_recursive(node: Node) -> Node:
	if node == null:
		return null

	if node.has_method("simulate_ai_enter_menu") and node.has_method("simulate_ai_exit_menu"):
		return node

	if node.name.to_lower().contains("bottommenu"):
		return node

	for child in node.get_children():
		var found := _find_bottom_menu_recursive(child)

		if found != null:
			return found

	return null


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
