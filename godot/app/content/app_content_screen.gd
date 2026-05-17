extends Control

const LOGIN_SCENE := "res://app/auth/LoginScreen.tscn"
const BOTTOM_MENU_SCRIPT := preload("res://app/ui/UnilearnBottomMenu.gd")
const UNIVERSE_PLAYGROUND_SCRIPT := preload("res://app/playground/UniversePlayground.gd")

@onready var ai_assistant: Node = get_node_or_null("AIAssistant")

var _ai_overlay_layer: CanvasLayer = null
var blocked_touch_indices: Dictionary = {}
var planet_touch_indices: Dictionary = {}

var sfx_enabled: bool = true
var apollo_enabled: bool = true
var reduce_motion_enabled: bool = false

var _background_frozen: bool = false
var _saved_navigation_enabled: bool = false

var _space_background_ref: Node = null
var _viewport_center: Vector2 = Vector2.ZERO

var bottom_menu: UnilearnBottomMenu = null

var universe_playground: Node = null
var _planet_popup_scan_pending: bool = false
var _connected_planet_popups: Dictionary = {}


func _ready() -> void:
	_full_rect(self)
	_load_local_settings()

	RenderingServer.set_default_clear_color(Color("#050712"))

	_cache_viewport()
	_cache_space_background()
	_setup_space_background()

	_setup_universe_playground()
	_setup_ai_assistant()
	_setup_bottom_menu()

	child_entered_tree.connect(_on_any_child_entered_tree)

	await get_tree().process_frame

	_prepare_first_frame_layout()
	_animate_in()
	_scan_and_connect_planet_card_popups()


func _prepare_first_frame_layout() -> void:
	_cache_viewport()

	if is_instance_valid(bottom_menu):
		if bottom_menu.has_method("_layout"):
			bottom_menu.call("_layout")

		if bottom_menu.has_method("_apply_progress"):
			bottom_menu.call("_apply_progress", 0.0)

		bottom_menu.visible = true


func _load_local_settings() -> void:
	if not has_node("/root/UnilearnUserSettings"):
		return

	var settings := get_node("/root/UnilearnUserSettings")

	sfx_enabled = settings.sfx_enabled

	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").set_enabled(sfx_enabled)

	apollo_enabled = settings.apollo_enabled
	reduce_motion_enabled = settings.reduce_motion_enabled


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_cache_viewport()


func _input(event: InputEvent) -> void:
	if _background_frozen:
		_clear_planet_touch_state_for_event(event)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_position_over_blocking_ui(event.position):
				blocked_touch_indices[event.index] = true
				get_viewport().set_input_as_handled()
				return

			if _is_touch_over_planet(event.position):
				planet_touch_indices[event.index] = true
				_set_background_external_touch(event.index, event.position, false)

				if _consume_universe_space_input(event):
					get_viewport().set_input_as_handled()
					return

				get_viewport().set_input_as_handled()
				return

		else:
			if planet_touch_indices.has(event.index):
				if _consume_universe_space_input(event):
					planet_touch_indices.erase(event.index)
					_remove_background_external_touch(event.index)
					get_viewport().set_input_as_handled()
					return

				planet_touch_indices.erase(event.index)
				_remove_background_external_touch(event.index)
				get_viewport().set_input_as_handled()
				return

			if blocked_touch_indices.has(event.index):
				blocked_touch_indices.erase(event.index)
				get_viewport().set_input_as_handled()
				return

	elif event is InputEventScreenDrag:
		if planet_touch_indices.has(event.index):
			_set_background_external_touch(event.index, event.position, true)

			if _consume_universe_space_input(event):
				get_viewport().set_input_as_handled()
				return

			get_viewport().set_input_as_handled()
			return

		if blocked_touch_indices.has(event.index):
			get_viewport().set_input_as_handled()
			return

	if _consume_universe_space_input(event):
		get_viewport().set_input_as_handled()
		return

	if _space_background_ref == null:
		return

	if _space_background_ref.get("navigation_enabled") != true:
		return

	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if _space_background_ref.has_method("handle_navigation_input"):
			_space_background_ref.call("handle_navigation_input", event)

	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if _space_background_ref.has_method("handle_navigation_input"):
			_space_background_ref.call("handle_navigation_input", event)


func _clear_planet_touch_state_for_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not event.pressed:
			planet_touch_indices.erase(event.index)
			blocked_touch_indices.erase(event.index)
			_remove_background_external_touch(event.index)

	elif event is InputEventScreenDrag:
		if planet_touch_indices.has(event.index):
			_remove_background_external_touch(event.index)


func _is_touch_over_planet(screen_position: Vector2) -> bool:
	if not is_instance_valid(universe_playground):
		return false

	if universe_playground.has_method("is_screen_position_over_body"):
		return bool(universe_playground.call("is_screen_position_over_body", screen_position))

	return false


func _set_background_external_touch(index: int, screen_position: Vector2, apply_gesture: bool) -> void:
	if _space_background_ref == null:
		return

	if _space_background_ref.has_method("set_external_navigation_touch"):
		_space_background_ref.call("set_external_navigation_touch", index, screen_position, apply_gesture)


func _remove_background_external_touch(index: int) -> void:
	if _space_background_ref == null:
		return

	if _space_background_ref.has_method("remove_external_navigation_touch"):
		_space_background_ref.call("remove_external_navigation_touch", index)


func _consume_universe_space_input(event: InputEvent) -> bool:
	if not is_instance_valid(universe_playground):
		return false

	if not universe_playground.has_method("consume_space_input"):
		return false

	return bool(universe_playground.call("consume_space_input", event))


func _cache_viewport() -> void:
	_viewport_center = get_viewport_rect().size * 0.5


func _cache_space_background() -> void:
	_space_background_ref = get_node_or_null("/root/SpaceBackground")


func _full_rect(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _is_position_over_blocking_ui(pos: Vector2) -> bool:
	if is_instance_valid(bottom_menu) and bottom_menu.is_position_blocking(pos):
		return true

	return false


func _setup_universe_playground() -> void:
	if is_instance_valid(universe_playground):
		return

	universe_playground = UNIVERSE_PLAYGROUND_SCRIPT.new()
	universe_playground.name = "UniversePlayground"
	universe_playground.process_mode = Node.PROCESS_MODE_INHERIT
	
	if universe_playground.has_signal("planet_card_open_requested"):
		var open_callable := Callable(self, "_on_simulation_planet_card_open_requested")

		if not universe_playground.is_connected("planet_card_open_requested", open_callable):
			universe_playground.connect("planet_card_open_requested", open_callable)

	if universe_playground is CanvasItem:
		var canvas_item := universe_playground as CanvasItem
		canvas_item.z_index = 8
		canvas_item.z_as_relative = false

	add_child(universe_playground)
	move_child(universe_playground, 0)


func _on_simulation_planet_card_open_requested(planet_data) -> void:
	if planet_data == null:
		return

	_open_planet_cards_popup_to_card(planet_data)


func _open_planet_cards_popup_to_card(planet_data) -> void:
	if planet_data == null:
		return

	_set_background_frozen(true)

	var popup := _find_planet_cards_popup()

	if popup == null:
		if is_instance_valid(bottom_menu):
			if bottom_menu.has_method("_open_planet_cards_popup"):
				bottom_menu.call("_open_planet_cards_popup")
			elif bottom_menu.has_method("_on_item_pressed"):
				bottom_menu.call("_on_item_pressed", "cards")

		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		popup = _find_planet_cards_popup()

	if popup == null:
		push_warning("Could not find planet cards popup after opening it.")
		return

	_scan_and_connect_planet_card_popups()

	await _open_popup_details_when_ready(popup, planet_data)


func _find_planet_cards_popup() -> Node:
	var scene := get_tree().current_scene

	if scene != null:
		var found := _find_node_with_name_recursive(scene, "UnilearnPlanetCardsPopup")
		if found != null:
			return found

	if is_instance_valid(bottom_menu):
		var found_in_menu := _find_node_with_name_recursive(bottom_menu, "UnilearnPlanetCardsPopup")
		if found_in_menu != null:
			return found_in_menu

	return null


func _find_node_with_name_recursive(node: Node, wanted_name: String) -> Node:
	if node == null:
		return null

	if node.name == wanted_name:
		return node

	for child in node.get_children():
		var result := _find_node_with_name_recursive(child, wanted_name)

		if result != null:
			return result

	return null


func _open_popup_details_when_ready(popup: Node, planet_data) -> void:
	if popup == null or planet_data == null:
		return

	for _i in range(12):
		if not is_instance_valid(popup):
			return

		if popup.has_method("_open_details"):
			popup.call("_open_details", planet_data)
			return

		await get_tree().process_frame

	push_warning("Planet cards popup exists, but _open_details was not ready/found.")
	

func _setup_bottom_menu() -> void:
	if is_instance_valid(bottom_menu):
		return

	bottom_menu = BOTTOM_MENU_SCRIPT.new()
	bottom_menu.name = "BottomMenu"
	bottom_menu.visible = false
	add_child(bottom_menu)

	bottom_menu.sfx_enabled = sfx_enabled
	bottom_menu.apollo_enabled = apollo_enabled
	bottom_menu.set_reduce_motion_enabled(reduce_motion_enabled)

	bottom_menu.item_pressed.connect(_on_bottom_menu_item_pressed)
	bottom_menu.item_pressed.connect(func(_item_id: String) -> void:
		blocked_touch_indices.clear()
	)

	_scan_and_connect_planet_card_popups()


func _on_bottom_menu_item_pressed(item_id: String) -> void:
	match item_id:
		"help":
			print("Open help / tutorial")

		"cards", "popup_cards_opened":
			_set_background_frozen(true)
			_deferred_scan_planet_card_popups()

		"cards_closed", "popup_cards_closed":
			_set_background_frozen(false)

		"achievements":
			print("Open achievements")

		"playgrounds":
			print("Open universe playgrounds")

		"settings", "popup_settings_opened":
			_set_background_frozen(true)

		"settings_closed", "popup_settings_closed":
			_set_background_frozen(false)

		"settings_reset_camera":
			_reset_space_camera()

		"settings_sfx_on":
			_set_sfx_enabled(true)

		"settings_sfx_off":
			_set_sfx_enabled(false)

		"settings_apollo_on":
			_set_apollo_enabled(true)

		"settings_apollo_off":
			_set_apollo_enabled(false)

		"settings_reduce_motion_on":
			_set_reduce_motion_enabled(true)

		"settings_reduce_motion_off":
			_set_reduce_motion_enabled(false)

		"settings_logout":
			_logout_user()

		_:
			print("Unknown bottom menu item: ", item_id)


func _on_any_child_entered_tree(_node: Node) -> void:
	_deferred_scan_planet_card_popups()


func _deferred_scan_planet_card_popups() -> void:
	if _planet_popup_scan_pending:
		return

	_planet_popup_scan_pending = true
	call_deferred("_scan_and_connect_planet_card_popups")


func _scan_and_connect_planet_card_popups() -> void:
	_planet_popup_scan_pending = false

	var root := get_tree().current_scene

	if root == null:
		root = self

	_scan_node_for_planet_card_popup(root)


func _scan_node_for_planet_card_popup(node: Node) -> void:
	if node == null:
		return

	_try_connect_planet_card_popup(node)

	for child in node.get_children():
		_scan_node_for_planet_card_popup(child)


func _try_connect_planet_card_popup(node: Node) -> void:
	if node == null:
		return

	var id := node.get_instance_id()

	if _connected_planet_popups.has(id):
		if is_instance_valid(_connected_planet_popups[id]):
			return

		_connected_planet_popups.erase(id)

	var has_add_signal := node.has_signal("planet_add_requested")
	var has_remove_signal := node.has_signal("planet_remove_requested")

	if not has_add_signal and not has_remove_signal:
		return

	if has_add_signal:
		var add_callable := Callable(self, "_on_planet_card_add_requested")

		if not node.is_connected("planet_add_requested", add_callable):
			node.connect("planet_add_requested", add_callable)

	if has_remove_signal:
		var remove_callable := Callable(self, "_on_planet_card_remove_requested")

		if not node.is_connected("planet_remove_requested", remove_callable):
			node.connect("planet_remove_requested", remove_callable)

	if node.has_signal("closed"):
		var closed_callable := Callable(self, "_on_planet_cards_popup_closed").bind(id)

		if not node.is_connected("closed", closed_callable):
			node.connect("closed", closed_callable)

	_connected_planet_popups[id] = node


func _on_planet_cards_popup_closed(popup_id: int) -> void:
	if _connected_planet_popups.has(popup_id):
		_connected_planet_popups.erase(popup_id)


func _on_planet_card_add_requested(data) -> void:
	if data == null:
		return

	_setup_universe_playground()

	if not is_instance_valid(universe_playground):
		push_warning("Cannot add planet because UniversePlayground is missing.")
		return

	var spawn_position := _get_default_planet_spawn_position()

	if universe_playground.has_method("add_planet_card"):
		var body = universe_playground.call("add_planet_card", data, spawn_position)

		if body != null:
			_focus_spawned_simulation_body(body)

		return

	push_warning("UniversePlayground does not have add_planet_card(data, spawn_position).")


func _on_planet_card_remove_requested(data) -> void:
	if data == null:
		return

	if not is_instance_valid(universe_playground):
		return

	if universe_playground.has_method("remove_planet_card"):
		universe_playground.call("remove_planet_card", data)
		return

	push_warning("UniversePlayground does not have remove_planet_card(data).")


func _get_default_planet_spawn_position() -> Vector2:
	_cache_viewport()

	_setup_universe_playground()

	if is_instance_valid(universe_playground) and universe_playground.has_method("screen_to_space"):
		return universe_playground.call("screen_to_space", _viewport_center)

	return Vector2.ZERO


func is_planet_card_in_scene(data) -> bool:
	if data == null:
		return false

	_setup_universe_playground()

	if not is_instance_valid(universe_playground):
		return false

	if universe_playground.has_method("is_planet_card_added"):
		return bool(universe_playground.call("is_planet_card_added", data))

	return false


func _focus_spawned_simulation_body(body) -> void:
	if body == null:
		return

	if not is_instance_valid(body):
		return

	if body is CanvasItem:
		var canvas_item := body as CanvasItem
		canvas_item.visible = true


func _set_background_frozen(frozen: bool) -> void:
	if _background_frozen == frozen:
		return

	_background_frozen = frozen
	blocked_touch_indices.clear()

	for index in planet_touch_indices.keys():
		_remove_background_external_touch(int(index))

	planet_touch_indices.clear()

	if frozen:
		_freeze_space_background()
		_freeze_scene_objects()
		return

	_unfreeze_space_background()
	_unfreeze_scene_objects()


func _freeze_scene_objects() -> void:
	if not is_instance_valid(universe_playground):
		return

	if universe_playground.has_method("set_scene_objects_paused"):
		universe_playground.call("set_scene_objects_paused", true)


func _unfreeze_scene_objects() -> void:
	if not is_instance_valid(universe_playground):
		return

	if universe_playground.has_method("set_scene_objects_paused"):
		universe_playground.call("set_scene_objects_paused", false)


func _freeze_space_background() -> void:
	if _space_background_ref == null:
		return

	var nav_value = _space_background_ref.get("navigation_enabled")
	if nav_value != null:
		_saved_navigation_enabled = bool(nav_value)

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)

	if _space_background_ref.has_method("set_background_paused"):
		_space_background_ref.call("set_background_paused", true)
	else:
		_space_background_ref.set_process(false)


func _unfreeze_space_background() -> void:
	if _space_background_ref == null:
		return

	if _space_background_ref.has_method("set_background_paused"):
		_space_background_ref.call("set_background_paused", false)
	else:
		_space_background_ref.set_process(true)

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", _saved_navigation_enabled)


func _set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled

	if has_node("/root/UnilearnUserSettings"):
		get_node("/root/UnilearnUserSettings").set_sfx_enabled(enabled)

	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").set_enabled(enabled)


func _set_reduce_motion_enabled(enabled: bool) -> void:
	reduce_motion_enabled = enabled

	if has_node("/root/UnilearnUserSettings"):
		get_node("/root/UnilearnUserSettings").set_reduce_motion_enabled(enabled)

	if is_instance_valid(bottom_menu):
		bottom_menu.set_reduce_motion_enabled(enabled)

	if _space_background_ref != null and _space_background_ref.has_method("set_reduce_motion_enabled"):
		_space_background_ref.call("set_reduce_motion_enabled", enabled)


func _reset_space_camera() -> void:
	if _space_background_ref == null:
		return

	if _space_background_ref.has_method("reset_navigation_view"):
		_space_background_ref.call("reset_navigation_view")
	else:
		if _space_background_ref.get("space_position") is Vector2:
			_space_background_ref.set("space_position", Vector2.ZERO)

		if _space_background_ref.get("target_space_position") is Vector2:
			_space_background_ref.set("target_space_position", Vector2.ZERO)

		if _space_background_ref.get("space_zoom") != null:
			_space_background_ref.set("space_zoom", 1.0)

		if _space_background_ref.get("target_space_zoom") != null:
			_space_background_ref.set("target_space_zoom", 1.0)

		if _space_background_ref.get("space_rotation") != null:
			_space_background_ref.set("space_rotation", 0.0)

		if _space_background_ref.get("target_space_rotation") != null:
			_space_background_ref.set("target_space_rotation", 0.0)

	blocked_touch_indices.clear()


func _logout_user() -> void:
	blocked_touch_indices.clear()
	_set_background_frozen(false)

	if is_instance_valid(bottom_menu):
		bottom_menu.close_menu()

	if is_instance_valid(ai_assistant):
		if ai_assistant.has_method("stop"):
			ai_assistant.call("stop")

	if AIState.has_method("set_enabled"):
		AIState.set_enabled(false)
	else:
		AIState.enabled = false
		AIState.reset()

	if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)

	var firebase_auth := get_node_or_null("/root/FirebaseAuth")
	if firebase_auth != null:
		if firebase_auth.has_method("logout"):
			firebase_auth.call("logout")
		elif firebase_auth.has_method("sign_out"):
			firebase_auth.call("sign_out")
		else:
			if firebase_auth.get("id_token") != null:
				firebase_auth.set("id_token", "")
			if firebase_auth.get("refresh_token") != null:
				firebase_auth.set("refresh_token", "")
			if firebase_auth.get("uid") != null:
				firebase_auth.set("uid", "")
			if firebase_auth.get("email") != null:
				firebase_auth.set("email", "")

	var firebase_service := get_node_or_null("/root/FirebaseService")
	if firebase_service != null:
		if firebase_service.has_method("logout"):
			firebase_service.call("logout")
		elif firebase_service.has_method("sign_out"):
			firebase_service.call("sign_out")

	get_tree().change_scene_to_file(LOGIN_SCENE)


func _setup_space_background() -> void:
	if _space_background_ref == null:
		push_warning("SpaceBackground autoload was not found.")
		return

	if _space_background_ref.has_method("set_space_reveal"):
		_space_background_ref.call("set_space_reveal", 1.0)

	if _space_background_ref.has_method("set_nebula_reveal"):
		_space_background_ref.call("set_nebula_reveal", 0.7)

	_space_background_ref.set("star_reveal", 1.0)
	_space_background_ref.set("travel_speed_multiplier", 0.0)

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)


func _setup_ai_assistant() -> void:
	if not is_instance_valid(ai_assistant):
		return

	_ensure_ai_overlay_layer()

	ai_assistant.process_mode = Node.PROCESS_MODE_ALWAYS

	if ai_assistant.get_parent() != _ai_overlay_layer:
		ai_assistant.reparent(_ai_overlay_layer, true)

	if ai_assistant is CanvasItem:
		var item := ai_assistant as CanvasItem
		item.z_index = 100
		item.z_as_relative = false

	_ai_overlay_layer.layer = 9999

	if AIState.has_method("set_enabled"):
		AIState.set_enabled(apollo_enabled)
	else:
		AIState.enabled = apollo_enabled

	await get_tree().process_frame

	if not is_instance_valid(ai_assistant):
		return

	_ai_overlay_layer.layer = 9999

	if apollo_enabled:
		if ai_assistant.has_method("start"):
			ai_assistant.call("start")
	else:
		if ai_assistant.has_method("stop"):
			ai_assistant.call("stop")


func _ensure_ai_overlay_layer() -> void:
	if is_instance_valid(_ai_overlay_layer):
		_ai_overlay_layer.layer = 9999
		_ai_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		return

	_ai_overlay_layer = CanvasLayer.new()
	_ai_overlay_layer.name = "AIOverlayLayer"
	_ai_overlay_layer.layer = 9999
	_ai_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ai_overlay_layer)


func _animate_in() -> void:
	if _space_background_ref == null:
		return

	blocked_touch_indices.clear()

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", true)


func _set_apollo_enabled(enabled: bool) -> void:
	apollo_enabled = enabled

	if has_node("/root/UnilearnUserSettings"):
		get_node("/root/UnilearnUserSettings").set_apollo_enabled(enabled)

	if is_instance_valid(bottom_menu):
		bottom_menu.apollo_enabled = enabled

	if is_instance_valid(ai_assistant):
		if ai_assistant.has_method("set_apollo_button_enabled"):
			ai_assistant.call("set_apollo_button_enabled", enabled)
		else:
			if enabled and ai_assistant.has_method("start"):
				ai_assistant.call("start")
			elif not enabled and ai_assistant.has_method("stop"):
				ai_assistant.call("stop")


func _set_space_navigation_enabled(enabled: bool) -> void:
	if _background_frozen:
		return

	if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", enabled)
