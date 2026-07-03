extends Node
class_name AIAppActionHandler

const ACTION_CHANGE_SETTINGS := "actions/change_settings/"
const ACTION_SIMULATION := "actions/simulation/"
const ACTION_NAVIGATE := "actions/navigate/"
const ACTION_CREATE := "actions/create/"
const ACTION_GALAXY := "actions/galaxy/"
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
		or folder.begins_with(ACTION_SIMULATION)
		or folder.begins_with(ACTION_GALAXY)
		or folder.begins_with(JUST_TALK)
	)


func execute_before_response(_folder: String, _spoken_text: String = "", _params: Dictionary = {}) -> void:
	pass


func execute_on_response_started(folder: String, spoken_text: String = "", params: Dictionary = {}) -> void:
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
		
		"actions/change_settings/music_on":
			await _apply_setting_action("music_on")

		"actions/change_settings/music_off":
			await _apply_setting_action("music_off")
		
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
		
		"actions/navigate/enter_galaxy":
			await _run_navigation_action("enter_galaxy")

		"actions/navigate/exit_galaxy":
			await _run_navigation_action("exit_galaxy")
		
		"actions/navigate/enter_achievements":
			await _run_navigation_action("enter_achievements", params)

		"actions/navigate/exit_achievements":
			await _run_navigation_action("exit_achievements", params)

		"actions/navigate/enter_help":
			await _run_navigation_action("enter_help", params)

		"actions/navigate/exit_help":
			await _run_navigation_action("exit_help", params)

		"actions/create/planet":
			await _run_create_planet_action(spoken_text)

		"actions/create/solar_system":
			_call_app_controller("create_solar_system", spoken_text)

		"actions/create/galaxy":
			_call_app_controller("create_galaxy", spoken_text)

		"just_talk/joke":
			pass
		
		"actions/simulation/add_body":
			await _apply_simulation_add_body(spoken_text)

		"actions/simulation/remove_body":
			_apply_simulation_remove_body(spoken_text)

		"actions/galaxy/center_anchor":
			_apply_galaxy_utility_action("center_anchor")

		"actions/galaxy/reset_orbits":
			_apply_galaxy_utility_action("reset_orbits")

		"actions/galaxy/clear_trails":
			_apply_galaxy_utility_action("clear_trails")
		
		"actions/galaxy/reset_camera":
			_apply_galaxy_utility_action("reset_camera")

		"actions/galaxy/set_simulation_parameter":
			_apply_galaxy_parameter_action(params)

		"actions/galaxy/toggle_setting":
			_apply_galaxy_toggle_action(params)


func execute_after_response(folder: String, _spoken_text: String = "", _params: Dictionary = {}) -> void:
	folder = folder.strip_edges()

	match folder:
		"actions/change_settings/wake_word_detection_off":
			await _apply_setting_action("wake_word_detection_off")

			if assistant != null:
				assistant.stop()


func should_resume_after(folder: String) -> bool:
	return folder.strip_edges() != "actions/change_settings/wake_word_detection_off"


func _run_navigation_action(action_id: String, params: Dictionary = {}) -> void:
	await _show_navigation_input_blocker()

	if AI_ACTION_START_PAUSE > 0.0:
		await get_tree().create_timer(AI_ACTION_START_PAUSE).timeout

	await _apply_navigation_action(action_id, params)

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
		
		"music_on":
			return "music_enabled" in settings and bool(settings.music_enabled)

		"music_off":
			return "music_enabled" in settings and not bool(settings.music_enabled)

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
		
		"music_on":
			_set_music_enabled(true)

		"music_off":
			_set_music_enabled(false)


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


func _set_music_enabled(value: bool) -> void:
	if settings == null:
		settings = get_node_or_null("/root/UnilearnUserSettings")

	if settings == null:
		return

	if "music_enabled" in settings and bool(settings.music_enabled) == value:
		return

	if settings.has_method("set_music_enabled"):
		settings.set_music_enabled(value)

	_update_music_node_live(value)


func _update_music_node_live(value: bool) -> void:
	var music := get_node_or_null("/root/UnilearnMusic")

	if music == null:
		return

	if music.has_method("set_enabled"):
		music.set_enabled(value)
	elif "enabled" in music:
		music.enabled = value
	elif "music_enabled" in music:
		music.music_enabled = value


func _update_sfx_node_live(value: bool) -> void:
	var sfx := get_node_or_null("/root/UnilearnSFX")

	if sfx == null:
		return

	if sfx.has_method("set_enabled"):
		sfx.set_enabled(value)
	elif "enabled" in sfx:
		sfx.enabled = value


func _apply_navigation_action(action_id: String, params: Dictionary = {}) -> void:
	var menu := _get_bottom_menu()
	var category := str(params.get("category", "")).strip_edges()

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

			"enter_galaxy":
				if menu.has_method("simulate_ai_enter_galaxy"):
					await menu.simulate_ai_enter_galaxy()
					return

			"exit_galaxy":
				if menu.has_method("simulate_ai_exit_galaxy"):
					await menu.simulate_ai_exit_galaxy()
					return

			"enter_achievements":
				if menu.has_method("simulate_ai_enter_achievements"):
					await menu.simulate_ai_enter_achievements(category)
					return

			"exit_achievements":
				if menu.has_method("simulate_ai_exit_achievements"):
					await menu.simulate_ai_exit_achievements()
					return

			"enter_help":
				if menu.has_method("simulate_ai_enter_help"):
					await menu.simulate_ai_enter_help()
					return

			"exit_help":
				if menu.has_method("simulate_ai_exit_help"):
					await menu.simulate_ai_exit_help()
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

		"enter_galaxy":
			_call_app_controller("enter_galaxy")

		"exit_galaxy":
			_call_app_controller("exit_galaxy")

		"enter_achievements":
			_call_app_controller("enter_achievements", category)

		"exit_achievements":
			_call_app_controller("exit_achievements")

		"enter_help":
			_call_app_controller("enter_help")

		"exit_help":
			_call_app_controller("exit_help")


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




func _apply_simulation_add_body(spoken_text: String) -> void:
	var query := _extract_planet_query_from_command(spoken_text)

	if query.is_empty():
		query = _extract_planet_creation_prompt(spoken_text)

	if query.is_empty():
		push_warning("Apollo could not understand what planet to add.")
		return

	var card: Variant = _find_planet_card_from_query(query)

	if card != null:
		_add_card_to_simulation(card)
		return

	await _generate_planet_then_add_to_simulation(query)

func _apply_simulation_remove_body(spoken_text: String) -> void:
	var query := _extract_planet_query_from_command(spoken_text)

	if query.is_empty():
		push_warning("Apollo could not understand what planet to remove.")
		return

	var card: Variant = _find_planet_card_from_query(query)

	if card == null:
		push_warning("Apollo could not find a planet card to remove for: " + query)
		return

	var universe := _get_universe_playground()

	if universe == null:
		push_warning("Apollo could not find UniversePlayground.")
		return

	if universe.has_method("remove_planet_card"):
		universe.call("remove_planet_card", card)

func _apply_galaxy_utility_action(action_id: String) -> void:
	var universe := _get_universe_playground()

	if universe == null:
		push_warning("Apollo could not find UniversePlayground for galaxy action: " + action_id)
		return

	match action_id:
		"center_anchor":
			if universe.has_method("center_anchor_body"):
				universe.call("center_anchor_body")

		"reset_orbits":
			if universe.has_method("reset_orbits"):
				universe.call("reset_orbits")

		"clear_trails":
			if universe.has_method("clear_trails"):
				universe.call("clear_trails")

		"reset_camera":
			if _emit_open_galaxy_popup_reset_camera():
				return

			if universe.has_method("reset_camera"):
				universe.call("reset_camera")
			else:
				_reset_camera_fallback()

func _apply_galaxy_parameter_action(params: Dictionary) -> void:
	var parameter := str(params.get("parameter", "")).strip_edges()
	var percent := _safe_percent(params.get("percent", 0))

	if parameter.is_empty():
		return

	var property_name := _map_ai_parameter_to_config_property(parameter)

	if property_name.is_empty():
		push_warning("Apollo unknown simulation parameter: " + parameter)
		return

	var value = _config_value_from_percent(property_name, percent)
	_apply_galaxy_config_value(property_name, value)

func _apply_galaxy_toggle_action(params: Dictionary) -> void:
	var property := str(params.get("property", "")).strip_edges()
	var enabled := _safe_bool(params.get("value", false))
	var property_name := _map_ai_toggle_to_config_property(property)

	if property_name.is_empty():
		push_warning("Apollo unknown galaxy toggle: " + property)
		return

	_apply_galaxy_config_value(property_name, enabled)

func _safe_percent(value: Variant) -> float:
	var percent := 0.0

	if value is float or value is int:
		percent = float(value)
	else:
		percent = float(str(value).to_float())

	return clamp(percent, 0.0, 100.0)

func _safe_bool(value: Variant) -> bool:
	if value is bool:
		return value

	var clean := str(value).strip_edges().to_lower()

	return clean == "true" or clean == "1" or clean == "on" or clean == "yes" or clean == "enabled"

func _map_ai_parameter_to_config_property(parameter: String) -> String:
	match parameter:
		"simulation_speed":
			return "simulation_speed"

		"orbit_speed_multiplier":
			return "orbit_speed_multiplier"

		"center_anchor_strength":
			return "center_anchor_strength"

		"orbit_lock_strength":
			return "orbit_lock_strength"

		"stable_orbit_radius_multiplier":
			return "stable_orbit_radius_multiplier"

		"drag_throw_strength":
			return "drag_throw_strength"

		_:
			return ""

func _map_ai_toggle_to_config_property(property: String) -> String:
	match property:
		"center_largest_bodies":
			return "center_largest_body"

		"stable_orbits":
			return "stable_orbit_mode"

		"trajectories":
			return "trails_enabled"

		_:
			return ""

func _config_value_from_percent(property_name: String, percent: float) -> Variant:
	var ratio = clamp(percent / 100.0, 0.0, 1.0)

	match property_name:
		"simulation_speed":
			return lerp(0.05, 64.0, ratio)

		"orbit_speed_multiplier":
			return lerp(0.05, 32.0, ratio)

		"center_anchor_strength":
			return ratio

		"orbit_lock_strength":
			return ratio

		"stable_orbit_radius_multiplier":
			return lerp(0.1, 1.0, ratio)

		"drag_throw_strength":
			return ratio

		_:
			return ratio

func _apply_galaxy_config_value(property_name: String, value: Variant) -> void:
	var universe := _get_universe_playground()

	if universe != null and universe.has_method("apply_config_value"):
		universe.call("apply_config_value", property_name, value)
		return

	var galaxy_state := get_node_or_null("/root/GalaxyState")

	if galaxy_state == null:
		galaxy_state = get_node_or_null("/root/UnilearnGalaxyState")

	if galaxy_state != null:
		if galaxy_state.has_method("set_config_value"):
			galaxy_state.call("set_config_value", property_name, value)
			return

		if galaxy_state.has_method("apply_config_value"):
			galaxy_state.call("apply_config_value", property_name, value)
			return

	push_warning("Apollo could not apply galaxy config value: " + property_name)

func _add_card_to_simulation(card) -> void:
	if card == null:
		return

	var universe := _get_universe_playground()

	if universe == null:
		push_warning("Apollo could not find UniversePlayground.")
		return

	if universe.has_method("is_planet_card_added"):
		if bool(universe.call("is_planet_card_added", card)):
			return

	var spawn_position := Vector2.ZERO
	var viewport := get_viewport()

	if viewport != null and universe.has_method("screen_to_space"):
		spawn_position = universe.call("screen_to_space", viewport.get_visible_rect().size * 0.5)

	if universe.has_method("add_planet_card"):
		universe.call("add_planet_card", card, spawn_position)

func _generate_planet_then_add_to_simulation(query: String) -> void:
	var menu := _get_bottom_menu()

	if menu != null and menu.has_method("simulate_ai_create_planet"):
		await menu.simulate_ai_create_planet(query)
		await _wait_for_generated_card_and_add(query)
		return

	_call_app_controller("create_planet", query)
	await _wait_for_generated_card_and_add(query)

func _wait_for_generated_card_and_add(query: String) -> void:
	var timeout := 24.0
	var elapsed := 0.0
	var step := 0.25

	while elapsed < timeout:
		var card: Variant = _find_planet_card_from_query(query)

		if card != null:
			_add_card_to_simulation(card)
			return

		await get_tree().create_timer(step).timeout
		elapsed += step

	push_warning("Apollo generated/search requested a planet, but no matching card appeared for: " + query)

func _find_planet_card_from_query(query: String):
	query = query.strip_edges().to_lower()

	if query.is_empty():
		return null

	var cards := _get_cached_planet_cards()

	for card in cards:
		if card == null:
			continue

		if _planet_card_matches_query(card, query):
			return card

	return null

func _get_cached_planet_cards() -> Array:
	var cache := get_node_or_null("/root/PlanetCardsCache")

	if cache == null:
		return []

	if cache.has_method("get_all_cards"):
		var all_cards = cache.call("get_all_cards")

		if all_cards is Array:
			return all_cards

	if cache.has_method("get_cards"):
		var cards = cache.call("get_cards")

		if cards is Array:
			return cards

	if "cards" in cache:
		var direct_cards = cache.get("cards")

		if direct_cards is Array:
			return direct_cards

	return []

func _planet_card_matches_query(card, query: String) -> bool:
	var q := query.strip_edges().to_lower()

	if q.is_empty():
		return false

	var candidates: Array[String] = []

	if "name" in card:
		candidates.append(str(card.name))

	if "instance_id" in card:
		candidates.append(str(card.instance_id))

	if "subtitle" in card:
		candidates.append(str(card.subtitle))

	if "object_category" in card:
		candidates.append(str(card.object_category))

	if "archetype_id" in card:
		candidates.append(str(card.archetype_id))

	if "planet_preset" in card:
		candidates.append(str(card.planet_preset))

	for value in candidates:
		var clean := value.strip_edges().to_lower()

		if clean.is_empty():
			continue

		if clean == q:
			return true

		if clean.contains(q):
			return true

		if q.contains(clean):
			return true

	return false

func _extract_planet_query_from_command(spoken_text: String) -> String:
	var text := spoken_text.strip_edges()

	if text.is_empty():
		return ""

	var lower := text.to_lower()

	var starters := [
		"apollo",
		"please",
		"can you",
		"could you",
		"would you",
		"add",
		"put",
		"place",
		"spawn",
		"insert",
		"bring",
		"show",
		"remove",
		"delete",
		"take out",
		"hide",
		"despawn",
		"clear"
	]

	for starter in starters:
		if lower.begins_with(starter + " "):
			text = text.substr(starter.length()).strip_edges()
			lower = text.to_lower()

	var end_phrases := [
		" to the screen",
		" to screen",
		" to the scene",
		" to scene",
		" to the simulation",
		" to simulation",
		" to the universe",
		" to universe",
		" into the screen",
		" into screen",
		" into the scene",
		" into scene",
		" into the simulation",
		" into simulation",
		" on the screen",
		" on screen",
		" from the screen",
		" from screen",
		" from the scene",
		" from scene",
		" from the simulation",
		" from simulation",
		" from the universe",
		" from universe"
	]

	for phrase in end_phrases:
		var index := lower.find(phrase)

		if index >= 0:
			text = text.substr(0, index).strip_edges()
			lower = text.to_lower()
			break

	if lower.begins_with("a "):
		text = text.substr(2).strip_edges()
	elif lower.begins_with("an "):
		text = text.substr(3).strip_edges()
	elif lower.begins_with("the "):
		text = text.substr(4).strip_edges()

	return text.strip_edges()

func _get_universe_playground() -> Node:
	var tree := get_tree()

	if tree == null:
		return null

	if tree.current_scene != null:
		var found := _find_universe_playground_recursive(tree.current_scene)

		if found != null:
			return found

	if tree.root != null:
		return _find_universe_playground_recursive(tree.root)

	return null

func _find_universe_playground_recursive(node: Node) -> Node:
	if node == null:
		return null

	if node.name == "UniversePlayground":
		return node

	if node.has_method("add_planet_card") and node.has_method("remove_planet_card"):
		return node

	for child in node.get_children():
		var found := _find_universe_playground_recursive(child)

		if found != null:
			return found

	return null


func _emit_open_galaxy_popup_reset_camera() -> bool:
	var popup := _get_open_galaxy_popup()

	if popup == null:
		return false

	if popup.has_method("close_popup"):
		popup.call("close_popup")

	if popup.has_signal("reset_camera_requested"):
		popup.emit_signal("reset_camera_requested")
		return true

	return false

func _get_open_galaxy_popup() -> Node:
	var tree := get_tree()

	if tree == null or tree.root == null:
		return null

	return _find_open_galaxy_popup_recursive(tree.root)

func _find_open_galaxy_popup_recursive(node: Node) -> Node:
	if node == null:
		return null

	if node.has_signal("reset_camera_requested"):
		return node

	if node.name.to_lower().contains("galaxypopup"):
		return node

	for child in node.get_children():
		var found := _find_open_galaxy_popup_recursive(child)

		if found != null:
			return found

	return null

func _reset_camera_fallback() -> void:
	var background := get_node_or_null("/root/SpaceBackground")

	if background == null:
		return

	if background.has_method("reset_camera"):
		background.call("reset_camera")
		return

	if background.has_method("reset_view"):
		background.call("reset_view")
		return

	if "camera_position" in background:
		background.camera_position = Vector2.ZERO

	if "camera_rotation" in background:
		background.camera_rotation = 0.0

	if "camera_zoom" in background:
		background.camera_zoom = 1.0
