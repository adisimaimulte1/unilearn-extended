extends CanvasLayer

@warning_ignore("unused_signal")
signal item_pressed(item_id: String)
signal galaxy_popup_opened(popup)

const PLANET_CARDS_POPUP_SCRIPT := preload("res://app/ui/popups/UnilearnPlanetCardsPopup.gd")
const SETTINGS_POPUP_SCRIPT := preload("res://app/ui/popups/UnilearnSettingsPopup.gd")
const GALAXY_POPUP_SCRIPT := preload("res://app/ui/popups/UnilearnGalaxyPopup.gd")
const ACHIEVEMENTS_POPUP_SCRIPT := preload("res://app/ui/popups/UnilearnAchievementsPopup.gd")
const MULTIPLAYER_POPUP_SCRIPT := preload("res://app/ui/popups/UnilearnMultiplayerPopup.gd")

const BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)
const BUTTON_DOWN_TIME := 0.055
const BUTTON_UP_TIME := 0.11
const BUTTON_SETTLE_TIME := 0.10

const AI_MENU_HANDLE_DOWN_TIME := 0.22
const AI_MENU_ICON_DOWN_TIME := 0.20
const AI_MENU_HANDLE_AFTER_SNAP_WAIT := 0.58
const AI_MENU_ICON_AFTER_TAP_WAIT := 0.46

@export var arrow_texture_path: String = "res://assets/app/buttons/button_arrow.png"
@export var settings_texture_path: String = "res://assets/app/buttons/button_settings.png"
@export var multiplayer_texture_path: String = "res://assets/app/buttons/button_multiplayer.png"
@export var cards_texture_path: String = "res://assets/app/buttons/button_card.png"
@export var achievements_texture_path: String = "res://assets/app/buttons/button_star.png"
@export var playgrounds_texture_path: String = "res://assets/app/buttons/button_galaxy.png"

@export var handle_size: float = 132.0
@export var handle_icon_max_width: int = 118

@export var icon_size: float = 114.0
@export var menu_icon_max_width: int = 100

@export var icon_spacing: float = 18.0
@export var group_horizontal_padding: float = 24.0
@export var group_vertical_padding: float = 20.0

@export var bottom_padding: float = 46.0
@export var open_lift: float = 175.0
@export var arrow_menu_gap: float = 22.0
@export var drag_distance_to_open: float = 175.0
@export var snap_threshold: float = 0.42
@export var drag_deadzone: float = 6.0

@export var group_border_width: int = 6
@export var group_border_color: Color = Color(1.0, 1.0, 1.0, 0.97)
@export var group_background_color: Color = Color(1.0, 1.0, 1.0, 0.015)

@export var icon_hover_color: Color = Color(1.0, 1.0, 1.0, 0.10)
@export var icon_pressed_color: Color = Color(1.0, 0.78, 0.18, 0.20)

@export var snap_duration: float = 0.34

@warning_ignore_start("unused_private_class_variable")

var _drag_started_from_open: bool = false
var is_open: bool = false

var _icons_origin_y: Array[float] = []

var _root: Control
var _panel: Panel
var _handle: Button

var _icon_buttons: Array[Button] = []
var _button_tweens: Dictionary = {}

var _progress: float = -999.0
var _dragging: bool = false
var _drag_started: bool = false
var _drag_start_y: float = 0.0
var _drag_start_progress: float = 0.0
var _active_touch_index: int = -1

var _snap_tween: Tween
var _settings_popup: UnilearnSettingsPopup = null
var _planet_cards_popup: UnilearnPlanetCardsPopup = null
var _galaxy_popup: Node = null
var _achievements_popup: Node = null
var _multiplayer_popup: Node = null
var _galaxy_config: Resource = null

var music_enabled: bool = true
var sfx_enabled: bool = true
var apollo_enabled: bool = false
var reduce_motion_enabled: bool = false

var _settings_node: Node = null
var _sfx_node: Node = null
var _music_node: Node = null

var _texture_cache: Dictionary = {}
var _style_cache: Dictionary = {}

var _last_layout_size := Vector2(-1, -1)
var _last_applied_progress: float = -999.0
var _last_applied_viewport_size := Vector2(-1, -1)

var _ai_navigation_busy := false
var _entry_tween: Tween = null

var _multiplayer_sync_active := false
var _multiplayer_sync_peer_name := ""
var _multiplayer_sync_peer_uid := ""
var _multiplayer_sync_peer_distance_meters := -1.0
var _multiplayer_sync_color_blend := 0.0
var _multiplayer_sync_color_tween: Tween = null
var _multiplayer_sync_stopping := false

const MULTIPLAYER_SYNC_COLOR_TIME := 0.46

const ENTRY_HANDLE_OFFSET_Y := 88.0
const ENTRY_HANDLE_FADE_TIME := 0.28
const ENTRY_HANDLE_SETTLE_TIME := 0.48

@warning_ignore_restore("unused_private_class_variable")



func begin_multiplayer_universe_sync_from_request(peer_name: String = "", peer_uid: String = "", peer_distance_meters: float = -1.0, request_id: String = "") -> void:
	while _ai_navigation_busy and is_inside_tree():
		await get_tree().process_frame
	_ai_navigation_busy = true
	_set_multiplayer_transition_input_blocked(true)

	# Start the same smooth planet disappearance used by logout immediately,
	# so it runs at the same time as the popup/menu go-home transition.
	var planet_exit_started_at := Time.get_ticks_msec()
	var planet_exit_duration := _start_multiplayer_sync_planet_exit_animation()

	await _navigate_home_for_ai()
	if is_open:
		await _simulate_handle_tap_to_state(false)

	# Do not announce this phone as ready until both its home transition and its
	# planet disappearance are complete. The backend barrier then guarantees the
	# new empty shared universe begins only after both phones reached this point.
	var elapsed_seconds := float(Time.get_ticks_msec() - planet_exit_started_at) / 1000.0
	var remaining_planet_exit := maxf(0.0, planet_exit_duration - elapsed_seconds)
	if remaining_planet_exit > 0.0:
		await get_tree().create_timer(remaining_planet_exit, true, false, true).timeout

	var ready_payload: Dictionary = await _wait_for_multiplayer_home_barrier(request_id)
	var start_at: int = int(ready_payload.get("startAt", 0))
	var server_now: int = int(ready_payload.get("serverNow", 0))
	if start_at > 0:
		var wait_seconds: float = maxf(0.0, float(start_at - server_now) / 1000.0)
		if wait_seconds > 0.0:
			await get_tree().create_timer(wait_seconds, true, false, true).timeout
	set_multiplayer_sync_active(true, peer_name, peer_uid, peer_distance_meters)
	_call_multiplayer_sync_scene_clear(peer_name, peer_uid, request_id)
	_set_multiplayer_transition_input_blocked(false)
	_ai_navigation_busy = false


func begin_multiplayer_card_trade_from_request(peer_name: String = "", peer_uid: String = "", request_id: String = "") -> void:
	while _ai_navigation_busy and is_inside_tree():
		await get_tree().process_frame
	_ai_navigation_busy = true
	_set_multiplayer_transition_input_blocked(true)
	await _navigate_home_for_ai()
	if is_open:
		await _simulate_handle_tap_to_state(false)
	var ready_payload: Dictionary = await _wait_for_multiplayer_home_barrier(request_id)
	var start_at: int = int(ready_payload.get("startAt", 0))
	var server_now: int = int(ready_payload.get("serverNow", 0))
	if start_at > 0:
		var wait_seconds: float = maxf(0.0, float(start_at - server_now) / 1000.0)
		if wait_seconds > 0.0:
			await get_tree().create_timer(wait_seconds, true, false, true).timeout
	_open_trade_card_selection_popup(peer_name, peer_uid, request_id)
	_set_multiplayer_transition_input_blocked(false)
	_ai_navigation_busy = false


func _wait_for_multiplayer_home_barrier(request_id: String) -> Dictionary:
	var clean_request_id: String = request_id.strip_edges()
	if clean_request_id.is_empty():
		return {}
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null or not database.has_method("mark_multiplayer_home_ready"):
		return {}
	while is_inside_tree():
		var result: Variant = await database.call("mark_multiplayer_home_ready", clean_request_id)
		if result is Dictionary:
			var payload: Dictionary = result as Dictionary
			if bool(payload.get("success", false)) and int(payload.get("startAt", 0)) > 0:
				return payload
		await get_tree().create_timer(0.10, true, false, true).timeout
	return {}


func _set_multiplayer_transition_input_blocked(blocked: bool) -> void:
	var blocker := get_node_or_null("MultiplayerTransitionInputBlocker") as ColorRect
	if blocked:
		if blocker == null:
			blocker = ColorRect.new()
			blocker.name = "MultiplayerTransitionInputBlocker"
			blocker.color = Color(0, 0, 0, 0)
			blocker.mouse_filter = Control.MOUSE_FILTER_STOP
			blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			blocker.z_index = 100000
			add_child(blocker)
		blocker.visible = true
	elif blocker != null:
		blocker.queue_free()


func set_multiplayer_sync_active(active: bool, peer_name: String = "", peer_uid: String = "", peer_distance_meters: float = -1.0) -> void:
	var clean_name := peer_name.strip_edges()
	var clean_uid := peer_uid.strip_edges()
	if active and clean_name.is_empty():
		clean_name = "PLAYER"

	var clean_distance := peer_distance_meters if active else -1.0
	if _multiplayer_sync_active == active and _multiplayer_sync_peer_name == clean_name and _multiplayer_sync_peer_uid == clean_uid and is_equal_approx(_multiplayer_sync_peer_distance_meters, clean_distance):
		_update_multiplayer_sync_button_colors()
		return

	_multiplayer_sync_active = active
	_multiplayer_sync_peer_name = clean_name if active else ""
	_multiplayer_sync_peer_uid = clean_uid if active else ""
	_multiplayer_sync_peer_distance_meters = clean_distance
	_animate_multiplayer_sync_button_colors(1.0 if active else 0.0)


func is_multiplayer_sync_active() -> bool:
	return _multiplayer_sync_active


func get_multiplayer_sync_peer() -> Dictionary:
	return {
		"uid": _multiplayer_sync_peer_uid,
		"displayName": _multiplayer_sync_peer_name if not _multiplayer_sync_peer_name.is_empty() else "PLAYER",
		"distanceMeters": _multiplayer_sync_peer_distance_meters,
		"syncActive": true,
	}


func stop_multiplayer_sync_ui(notify_peer: bool = true) -> void:
	if not _multiplayer_sync_active or _multiplayer_sync_stopping:
		return

	_multiplayer_sync_stopping = true
	var peer_uid := _multiplayer_sync_peer_uid
	_set_multiplayer_transition_input_blocked(true)

	# Tell the peer immediately so both phones begin the same exit transition
	# at nearly the same time. Keep the local sync UI active until the restored
	# planets have completed their entrance animation.
	if notify_peer and not peer_uid.is_empty():
		var database := get_node_or_null("/root/FirebaseDatabase")
		if database != null and database.has_method("close_multiplayer_universe_sync"):
			database.call("close_multiplayer_universe_sync", peer_uid)

	await _call_multiplayer_sync_scene_restore()
	set_multiplayer_sync_active(false)
	_notify_open_multiplayer_popup_sync_closed()
	_set_multiplayer_transition_input_blocked(false)
	_multiplayer_sync_stopping = false


func _notify_open_multiplayer_popup_sync_closed() -> void:
	var root := get_tree().root if get_tree() != null else null
	var popup := _find_node_with_method_recursive(root, "remote_multiplayer_sync_closed")
	if popup != null:
		popup.call_deferred("remote_multiplayer_sync_closed")


func _connect_multiplayer_sync_close_signal() -> void:
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null or not database.has_signal("multiplayer_sync_closed"):
		return
	var callback := Callable(self, "_on_multiplayer_sync_closed")
	if not database.is_connected("multiplayer_sync_closed", callback):
		database.connect("multiplayer_sync_closed", callback)


func _on_multiplayer_sync_closed(payload: Dictionary) -> void:
	if not _multiplayer_sync_active:
		return

	var sender_uid := str(payload.get("senderUid", "")).strip_edges()
	var target_uid := str(payload.get("targetUid", "")).strip_edges()
	var peer_uid := _multiplayer_sync_peer_uid.strip_edges()
	if not peer_uid.is_empty() and sender_uid != peer_uid and target_uid != peer_uid:
		return

	stop_multiplayer_sync_ui(false)


func _start_multiplayer_sync_planet_exit_animation() -> float:
	var root := get_tree().current_scene if get_tree() != null else null
	var target := _find_node_with_method_recursive(root, "begin_multiplayer_sync_planet_exit_animation")
	if target == null:
		target = _find_node_with_method_recursive(get_tree().root, "begin_multiplayer_sync_planet_exit_animation")
	if target == null:
		return 0.0
	return maxf(0.0, float(target.call("begin_multiplayer_sync_planet_exit_animation")))


func _call_multiplayer_sync_scene_clear(peer_name: String, peer_uid: String, request_id: String = "") -> void:
	var root := get_tree().current_scene if get_tree() != null else null
	var target := _find_node_with_method_recursive(root, "clear_scene_for_multiplayer_sync")
	if target == null:
		target = _find_node_with_method_recursive(get_tree().root, "clear_scene_for_multiplayer_sync")
	if target != null:
		target.call_deferred("clear_scene_for_multiplayer_sync", peer_name, peer_uid, request_id)


func _call_multiplayer_sync_scene_restore() -> void:
	var root := get_tree().current_scene if get_tree() != null else null
	var target := _find_node_with_method_recursive(root, "end_multiplayer_universe_sync")
	if target == null:
		target = _find_node_with_method_recursive(get_tree().root, "end_multiplayer_universe_sync")
	if target != null:
		await target.call("end_multiplayer_universe_sync")


func _find_node_with_method_recursive(node: Node, method_name: String) -> Node:
	if node == null:
		return null
	if node != self and node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method_recursive(child, method_name)
		if found != null:
			return found
	return null


func _animate_multiplayer_sync_button_colors(target_blend: float) -> void:
	if _multiplayer_sync_color_tween != null and _multiplayer_sync_color_tween.is_valid():
		_multiplayer_sync_color_tween.kill()

	if reduce_motion_enabled:
		_multiplayer_sync_color_blend = target_blend
		_update_multiplayer_sync_button_colors()
		return

	_multiplayer_sync_color_tween = create_tween()
	_multiplayer_sync_color_tween.set_trans(Tween.TRANS_SINE)
	_multiplayer_sync_color_tween.set_ease(Tween.EASE_OUT)
	_multiplayer_sync_color_tween.tween_method(
		func(value: float) -> void:
			_multiplayer_sync_color_blend = value
			_update_multiplayer_sync_button_colors(),
		_multiplayer_sync_color_blend,
		target_blend,
		MULTIPLAYER_SYNC_COLOR_TIME
	)


func _update_multiplayer_sync_button_colors() -> void:
	var blend = clamp(_multiplayer_sync_color_blend, 0.0, 1.0)
	var highlight := _get_menu_highlight_color()
	var tint := Color.WHITE.lerp(highlight, blend)

	for button in _icon_buttons:
		_apply_button_icon_tint(button, tint)
	_apply_button_icon_tint(_handle, tint)
	_apply_multiplayer_sync_menu_border_colors(highlight, blend)


func _apply_multiplayer_sync_menu_border_colors(highlight: Color, blend: float) -> void:
	if is_instance_valid(_panel):
		_panel.add_theme_stylebox_override(
			"panel",
			_group_panel_style(group_background_color, group_border_color.lerp(highlight, blend), group_border_width)
		)

	if is_instance_valid(_handle):
		var handle_border := Color(1.0, 1.0, 1.0, 0.0).lerp(highlight, blend)
		var handle_style := _circle_style(Color.TRANSPARENT, handle_border, group_border_width)
		_handle.add_theme_stylebox_override("normal", handle_style)
		_handle.add_theme_stylebox_override("hover", handle_style)
		_handle.add_theme_stylebox_override("pressed", handle_style)


func _apply_button_icon_tint(button: Variant, tint: Color) -> void:
	if not is_instance_valid(button):
		return
	_apply_canvas_item_tint_recursive(button, tint)
	if button is Button:
		# Button icons are not always child CanvasItems in Godot; the arrow handle uses
		# the built-in icon theme path, so tint the icon theme colors too.
		button.add_theme_color_override("icon_normal_color", tint)
		button.add_theme_color_override("icon_hover_color", tint)
		button.add_theme_color_override("icon_pressed_color", tint)
		button.add_theme_color_override("icon_disabled_color", tint)
	button.add_theme_color_override("font_color", tint)
	button.add_theme_color_override("font_hover_color", tint)
	button.add_theme_color_override("font_pressed_color", tint)


func _apply_canvas_item_tint_recursive(node: Variant, tint: Color) -> void:
	if not is_instance_valid(node):
		return
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate = tint
		if child is Node:
			_apply_canvas_item_tint_recursive(child, tint)


func _get_menu_highlight_color() -> Color:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	if _settings_node != null:
		if _settings_node.has_method("get_text_highlighted_color"):
			var highlighted_value: Variant = _settings_node.call("get_text_highlighted_color")
			if highlighted_value is Color:
				return highlighted_value
		if _settings_node.has_method("get_accent_color"):
			var accent_value: Variant = _settings_node.call("get_accent_color")
			if accent_value is Color:
				return accent_value
		for property_name in ["text_highlighted_color", "highlighted_text_color", "text_highlight_color", "highlight_color", "accent_color"]:
			var value: Variant = _settings_node.get(property_name)
			if value is Color:
				return value
	return Color(1.0, 0.82, 0.34, 0.98)


func _connect_bottom_menu_settings_signal() -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	if _settings_node == null or not _settings_node.has_signal("settings_changed"):
		return
	var callable := Callable(self, "_on_bottom_menu_settings_changed")
	if not _settings_node.settings_changed.is_connected(callable):
		_settings_node.settings_changed.connect(callable)


func _on_bottom_menu_settings_changed() -> void:
	_load_local_settings()
	_update_multiplayer_sync_button_colors()


func _ready() -> void:
	layer = 950
	process_mode = Node.PROCESS_MODE_ALWAYS

	_cache_singletons()
	_load_local_settings()
	_connect_bottom_menu_settings_signal()
	_connect_multiplayer_sync_close_signal()
	_build_ui()

	await get_tree().process_frame

	_layout()
	_apply_progress(0.0)


func _cache_singletons() -> void:
	_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	_sfx_node = get_node_or_null("/root/UnilearnSFX")
	_music_node = get_node_or_null("/root/UnilearnMusic")


func _load_local_settings() -> void:
	if _settings_node == null:
		return

	music_enabled = bool(_settings_node.get("music_enabled"))
	sfx_enabled = bool(_settings_node.get("sfx_enabled"))
	apollo_enabled = bool(_settings_node.get("apollo_enabled"))
	reduce_motion_enabled = bool(_settings_node.get("reduce_motion_enabled"))


func get_app_location() -> String:
	if is_instance_valid(_settings_popup):
		return "settings"

	if is_instance_valid(_planet_cards_popup):
		return "planet_cards"

	if is_instance_valid(_galaxy_popup):
		return "galaxy"

	if is_instance_valid(_achievements_popup):
		return "achievements"

	if is_instance_valid(_multiplayer_popup):
		return "multiplayer"

	if is_open:
		return "menu"

	return "home"


func is_menu_open() -> bool:
	return is_open


func has_open_popup() -> bool:
	return is_instance_valid(_settings_popup) or is_instance_valid(_planet_cards_popup) or is_instance_valid(_galaxy_popup) or is_instance_valid(_achievements_popup) or is_instance_valid(_multiplayer_popup)


func simulate_ai_enter_menu() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	await _navigate_home_for_ai()

	if is_open:
		_ai_navigation_busy = false
		return

	await _simulate_handle_tap_to_state(true)

	_ai_navigation_busy = false


func simulate_ai_exit_menu() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	await _navigate_home_for_ai()

	if not is_open:
		_ai_navigation_busy = false
		return

	await _simulate_handle_tap_to_state(false)

	_ai_navigation_busy = false


func simulate_ai_enter_settings() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_settings_popup):
		_ai_navigation_busy = false
		return

	await _navigate_home_for_ai()
	await _ensure_menu_open_for_ai()
	await _simulate_icon_tap("settings")

	_ai_navigation_busy = false


func simulate_ai_exit_settings() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_settings_popup):
		await _close_settings_popup_for_ai()

	_ai_navigation_busy = false


func simulate_ai_enter_planet_cards() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_planet_cards_popup):
		_ai_navigation_busy = false
		return

	await _navigate_home_for_ai()
	await _ensure_menu_open_for_ai()
	await _simulate_icon_tap("cards")

	_ai_navigation_busy = false


func simulate_ai_exit_planet_cards() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_planet_cards_popup):
		await _close_planet_cards_popup_for_ai()

	_ai_navigation_busy = false


func simulate_ai_enter_galaxy() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_galaxy_popup):
		_ai_navigation_busy = false
		return

	await _navigate_home_for_ai()
	await _ensure_menu_open_for_ai()
	await _simulate_icon_tap("playgrounds")

	_ai_navigation_busy = false


func simulate_ai_exit_galaxy() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_galaxy_popup):
		await _close_galaxy_popup_for_ai()

	_ai_navigation_busy = false


func simulate_ai_enter_achievements(category: String = "") -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	var clean_category := category.strip_edges()

	if not is_instance_valid(_achievements_popup):
		await _navigate_home_for_ai()
		await _ensure_menu_open_for_ai()
		await _simulate_icon_tap("achievements")

	if is_instance_valid(_achievements_popup) and not clean_category.is_empty():
		if _achievements_popup.has_method("simulate_ai_open_category"):
			await _achievements_popup.simulate_ai_open_category(clean_category)

	_ai_navigation_busy = false


func simulate_ai_exit_achievements() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_achievements_popup):
		await _close_achievements_popup_for_ai()

	_ai_navigation_busy = false


func simulate_ai_enter_multiplayer() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_multiplayer_popup):
		_ai_navigation_busy = false
		return

	await _navigate_home_for_ai()
	await _ensure_menu_open_for_ai()
	await _simulate_icon_tap("multiplayer")

	_ai_navigation_busy = false


func simulate_ai_exit_multiplayer() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_multiplayer_popup):
		await _close_multiplayer_popup_for_ai()

	_ai_navigation_busy = false


func simulate_ai_go_home() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	await _navigate_home_for_ai()

	if is_open:
		await _simulate_handle_tap_to_state(false)

	_ai_navigation_busy = false


func simulate_ai_create_planet(prompt: String, suppress_details_after_generation: bool = false) -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if prompt.strip_edges().is_empty():
		prompt = "planet"

	if is_instance_valid(_settings_popup):
		await _close_settings_popup_for_ai()

	if not is_instance_valid(_planet_cards_popup):
		await _ensure_menu_open_for_ai()
		await _simulate_icon_tap("cards")

	if is_instance_valid(_planet_cards_popup):
		if _planet_cards_popup.has_method("simulate_ai_create_planet"):
			await _planet_cards_popup.simulate_ai_create_planet(prompt, suppress_details_after_generation)

	_ai_navigation_busy = false


func _navigate_home_for_ai() -> void:
	if is_instance_valid(_settings_popup):
		await _close_settings_popup_for_ai()

	if is_instance_valid(_planet_cards_popup):
		await _close_planet_cards_popup_for_ai()

	if is_instance_valid(_galaxy_popup):
		await _close_galaxy_popup_for_ai()

	if is_instance_valid(_achievements_popup):
		await _close_achievements_popup_for_ai()

	if is_instance_valid(_multiplayer_popup):
		await _close_multiplayer_popup_for_ai()

	await get_tree().process_frame


func _close_settings_popup_for_ai() -> void:
	if not is_instance_valid(_settings_popup):
		return

	var popup := _settings_popup
	popup.close_popup()

	if is_instance_valid(popup):
		await popup.closed

	await get_tree().process_frame


func _close_planet_cards_popup_for_ai() -> void:
	if not is_instance_valid(_planet_cards_popup):
		return

	var popup := _planet_cards_popup
	popup.close_popup()

	if is_instance_valid(popup):
		await popup.closed

	await get_tree().process_frame


func _close_galaxy_popup_for_ai() -> void:
	if not is_instance_valid(_galaxy_popup):
		return

	var popup := _galaxy_popup

	if popup.has_method("close_popup"):
		popup.call("close_popup")
	else:
		popup.queue_free()

	if is_instance_valid(popup):
		await popup.tree_exited

	await get_tree().process_frame


func _close_achievements_popup_for_ai() -> void:
	if not is_instance_valid(_achievements_popup):
		return

	var popup := _achievements_popup

	if popup.has_method("close_popup"):
		popup.call("close_popup")
	else:
		popup.queue_free()

	if is_instance_valid(popup):
		await popup.tree_exited

	await get_tree().process_frame


func _close_multiplayer_popup_for_ai() -> void:
	if not is_instance_valid(_multiplayer_popup):
		return

	var popup := _multiplayer_popup

	if popup.has_method("close_popup"):
		popup.call("close_popup")
	else:
		popup.queue_free()

	if is_instance_valid(popup):
		await popup.tree_exited

	await get_tree().process_frame


func _ensure_menu_open_for_ai() -> void:
	if is_open:
		return

	await _simulate_handle_tap_to_state(true)


func _ensure_menu_closed_for_ai() -> void:
	if not is_open:
		return

	await _simulate_handle_tap_to_state(false)


func _simulate_handle_tap_to_state(open_target: bool) -> void:
	if not is_instance_valid(_handle):
		return

	_dragging = false
	_drag_started = false
	_active_touch_index = -1

	_handle.pivot_offset = _handle.size * 0.5

	if reduce_motion_enabled:
		_snap_to(1.0 if open_target else 0.0)
		return

	_tween_button_scale(_handle, BUTTON_PRESS_SCALE, AI_MENU_HANDLE_DOWN_TIME)

	await get_tree().create_timer(AI_MENU_HANDLE_DOWN_TIME).timeout

	if not is_instance_valid(_handle):
		return

	_snap_to(1.0 if open_target else 0.0)
	_tween_button_release(_handle)

	await get_tree().create_timer(max(snap_duration, AI_MENU_HANDLE_AFTER_SNAP_WAIT)).timeout


func _simulate_icon_tap(item_id: String) -> void:
	if item_id.strip_edges().is_empty():
		return

	var button := _find_icon_button(item_id)

	if not is_instance_valid(button):
		_activate_icon(item_id)
		await get_tree().process_frame
		return

	_dragging = false
	_drag_started = false
	_active_touch_index = -1

	_on_icon_button_down(button)

	await get_tree().create_timer(0.0 if reduce_motion_enabled else AI_MENU_ICON_DOWN_TIME).timeout

	if not is_instance_valid(button):
		return

	_on_icon_button_up(button)
	_activate_icon(item_id)

	await get_tree().create_timer(0.0 if reduce_motion_enabled else AI_MENU_ICON_AFTER_TAP_WAIT).timeout


func _find_icon_button(item_id: String) -> Button:
	var clean_id := item_id.strip_edges().to_lower()

	for button in _icon_buttons:
		if not is_instance_valid(button):
			continue

		var clean_name := button.name.strip_edges().to_lower()

		if clean_name == clean_id:
			return button

		if clean_name == clean_id + "button":
			return button

		if clean_name.contains(clean_id):
			return button

	return null


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_layout()
		_apply_progress(_progress)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventScreenDrag:
		if event.index == _active_touch_index:
			_update_drag(event.position.y)
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		if not event.pressed and event.index == _active_touch_index:
			_finish_drag()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _active_touch_index == -2:
			_update_drag(event.position.y)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _active_touch_index == -2:
			_finish_drag()
			get_viewport().set_input_as_handled()


func is_position_blocking(screen_position: Vector2) -> bool:
	if is_instance_valid(_settings_popup):
		return true

	if is_instance_valid(_planet_cards_popup):
		return true

	if is_instance_valid(_galaxy_popup):
		return true

	if is_instance_valid(_achievements_popup):
		return true

	if is_instance_valid(_multiplayer_popup):
		return true

	if not is_instance_valid(_root):
		return false

	if is_instance_valid(_handle) and _handle.get_global_rect().has_point(screen_position):
		return true

	if is_instance_valid(_panel) and _panel.visible and _panel.get_global_rect().has_point(screen_position):
		return true

	return false


func open_menu() -> void:
	_snap_to(1.0)


func close_menu() -> void:
	_snap_to(0.0)


func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()


func set_galaxy_config(value: Resource) -> void:
	_galaxy_config = value

	if is_instance_valid(_galaxy_popup) and _galaxy_popup.has_method("setup"):
		_galaxy_popup.call("setup", _galaxy_config, reduce_motion_enabled)


func get_galaxy_config() -> Resource:
	return _galaxy_config


# -----------------------------------------------------------------------------
# Split-script virtual method declarations for inherited menu layers.
# -----------------------------------------------------------------------------
func _build_ui() -> void:
	pass

func _layout() -> void:
	pass

func _apply_progress(_value: float) -> void:
	pass

func _snap_to(_target: float) -> void:
	pass

func _update_drag(_current_y: float) -> void:
	pass

func _finish_drag() -> void:
	pass

func _load_texture(_path: String) -> Texture2D:
	return null

func _full_rect(_node: Control) -> void:
	pass

func _group_panel_style(_color: Color, _border_color: Color, _border_width: int) -> StyleBoxFlat:
	return StyleBoxFlat.new()

func _circle_style(_color: Color, _border_color: Color = Color.TRANSPARENT, _border_width: int = 0) -> StyleBoxFlat:
	return StyleBoxFlat.new()

func _play_sfx(_id: String) -> void:
	pass

func _open_settings_popup() -> void:
	pass

func _open_planet_cards_popup() -> void:
	pass

func _open_trade_card_selection_popup(_peer_name: String = "", _peer_uid: String = "", _request_id: String = "") -> void:
	pass

func _open_galaxy_popup() -> void:
	pass

func _open_achievements_popup() -> void:
	pass

func _open_multiplayer_popup() -> void:
	pass

func _add_icon(_item_id: String, _texture_path: String, _fallback_text: String) -> void:
	pass

func _on_icon_button_down(_button: Button) -> void:
	pass

func _on_icon_button_up(_button: Button) -> void:
	pass

func _activate_icon(_item_id: String) -> void:
	pass

func _tween_button_scale(_button: Button, _target_scale: Vector2, _duration: float) -> void:
	pass

func _tween_button_release(_button: Button) -> void:
	pass

func _bounce_button_cancel(_button: Button) -> void:
	pass

func _position_icons_symmetrically() -> void:
	pass

func _update_icon_contents() -> void:
	pass

func _apply_icon_slide(_p: float) -> void:
	pass

func _on_handle_gui_input(_event: InputEvent) -> void:
	pass

func _start_drag(_touch_index: int, _y_position: float) -> void:
	pass

func set_reduce_motion_enabled(enabled: bool) -> void:
	reduce_motion_enabled = enabled
